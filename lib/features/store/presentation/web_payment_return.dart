import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/analytics/analytics.dart';
import '../../../core/platform/web_page.dart';
import '../../../core/theme/theme_controller.dart';
import '../../coins/presentation/providers/coin_balance_provider.dart';
import '../../maestro/presentation/maestro_providers.dart';
import '../data/store_repository.dart';
import 'purchase_result.dart';
import 'store_controller.dart';

/// In a browser, back from Flutterwave's checkout (the address says
/// ?status=…&tx_ref=…&transaction_id=…): once the player is signed in and
/// a screen is up, the result modal, which asks whether the payment went
/// through ([WebPaymentSettler]) and shows it: paid, still confirming,
/// didn't go through, or couldn't be confirmed. The coins themselves
/// arrive on their own, whichever of this and the webhook gets there
/// first, and the purchase's notification with them. Nothing in the apps.
class WebPaymentReturn extends ConsumerStatefulWidget {
  const WebPaymentReturn({super.key});

  @override
  ConsumerState<WebPaymentReturn> createState() => _WebPaymentReturnState();
}

class _WebPaymentReturnState extends ConsumerState<WebPaymentReturn> {
  WebPaymentSettler? _settler;
  ProviderSubscription<AsyncValue<int>>? _balance;

  @override
  void initState() {
    super.initState();
    final query = WebPage.query;
    final payment = query['tx_ref'];
    if (!kIsWeb ||
        payment == null ||
        !(payment.startsWith('utopia-') || payment.startsWith('kaivon-sub-'))) {
      return;
    }
    unawaited(_settle(payment, query['transaction_id'], query['status']));
  }

  @override
  void dispose() {
    _balance?.close();
    _settler?.dispose();
    super.dispose();
  }

  Future<void> _settle(
    String payment,
    String? transactionId,
    String? status,
  ) async {
    // Only an account can pay on the web, so wait for one.
    final context = await waitForAppScreen(ref, () => mounted, account: true);
    if (context == null || !context.mounted) return;
    final prefs = ref.read(sharedPreferencesProvider);
    final asked = recallWebCheckout(prefs, payment);
    final plan = payment.startsWith('kaivon-sub-');
    final start = PurchaseResult(
      stage: PurchaseStage.confirming,
      plan: plan,
      coins: asked?.coins,
      paid: asked?.price,
    );
    final repo = ref.read(storeRepositoryProvider);
    final settler = _settler = WebPaymentSettler(
      start: start,
      confirm: transactionId == null
          ? null
          : () => repo.webConfirm(payment, transactionId),
    );
    settler.result.addListener(() => _landed(settler.result.value, plan));
    if (transactionId == null || status == 'cancelled' || status == 'failed') {
      settler.fail();
    } else {
      settler.start();
      // The coins arriving in the live balance say it's paid too.
      _balance = ref.listenManual(
        coinBalanceProvider,
        (_, next) => settler.balanceNow(next.valueOrNull),
        fireImmediately: true,
      );
    }
    // Shown: a refresh won't show it again.
    WebPage.clearPaymentQuery();
    await showPurchaseResult(context, settler.result);
    forgetWebCheckout(prefs);
    _balance?.close();
    _balance = null;
    settler.dispose();
    if (identical(_settler, settler)) _settler = null;
  }

  /// What the rest of the app needs to know once it's settled.
  void _landed(PurchaseResult r, bool plan) {
    if (!mounted || r.stage == PurchaseStage.confirming) return;
    ref.read(analyticsProvider).log('web_payment_result', {
      'stage': r.stage.name,
      'plan': plan,
    });
    if (r.stage != PurchaseStage.paid) return;
    if (plan) ref.invalidate(maestroProvider);
    // The starter pack, bought, is off the shelf.
    unawaited(ref.read(storeControllerProvider.notifier).refresh());
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Asks the payment service whether a web payment went through, every
/// [every] for up to [giveUpAfter], and keeps [result] up to date: paid
/// the moment it is (or the moment the coins show up in the balance),
/// failed, couldn't be confirmed, or, past [giveUpAfter], still waiting
/// on Flutterwave (it's added when it's confirmed, with a notification).
class WebPaymentSettler {
  WebPaymentSettler({
    required PurchaseResult start,
    required this.confirm,
    this.every = const Duration(seconds: 4),
    this.giveUpAfter = const Duration(minutes: 2),
  }) : result = ValueNotifier(start);

  /// One ask (WebConfirmation's statuses); null when there's nothing to
  /// ask about (no transaction came back).
  final Future<WebConfirmation> Function()? confirm;
  final Duration every;
  final Duration giveUpAfter;
  final ValueNotifier<PurchaseResult> result;

  Timer? _next;
  Timer? _deadline;
  bool _done = false;
  int? _balanceAtStart;

  bool get settled => _done;

  void start() {
    if (_done || confirm == null) return;
    _deadline = Timer(giveUpAfter, () => _finish(PurchaseStage.waiting));
    unawaited(_ask());
  }

  /// It came back failed or cancelled: nothing was charged.
  void fail() => _finish(PurchaseStage.failed);

  Future<void> _ask() async {
    if (_done) return;
    WebConfirmation answer;
    try {
      answer = await confirm!();
    } catch (_) {
      answer = const WebConfirmation(status: 'error');
    }
    if (_done) return;
    switch (answer.status) {
      case 'paid':
        _finish(
          PurchaseStage.paid,
          coins: answer.coins > 0 ? answer.coins : null,
          paid: answer.paid,
          balance: answer.balance,
        );
      case 'failed' || 'cancelled':
        _finish(PurchaseStage.failed);
      case 'other':
        _finish(PurchaseStage.unconfirmed, otherAccount: true);
      case 'unknown':
        _finish(PurchaseStage.unconfirmed);
      default:
        // Still pending with Flutterwave, or the service didn't answer:
        // ask again in a moment.
        _next = Timer(every, () => unawaited(_ask()));
    }
  }

  /// The live balance is [balance]: once it's gone up by the pack's coins
  /// since this started, they're in.
  void balanceNow(int? balance) {
    if (_done || balance == null) return;
    final start = _balanceAtStart ??= balance;
    final coins = result.value.coins;
    if (result.value.plan || coins == null || coins <= 0) return;
    if (balance >= start + coins) {
      _finish(PurchaseStage.paid, balance: balance);
    }
  }

  void _finish(
    PurchaseStage stage, {
    int? coins,
    String? paid,
    int? balance,
    bool? otherAccount,
  }) {
    if (_done) return;
    _done = true;
    _next?.cancel();
    _deadline?.cancel();
    result.value = result.value.copyWith(
      stage: stage,
      coins: coins,
      paid: paid,
      balance: balance,
      otherAccount: otherAccount,
    );
  }

  void dispose() {
    _done = true;
    _next?.cancel();
    _deadline?.cancel();
  }
}

const _checkoutKey = 'web.checkout';

/// What a web checkout was for (its coins and the price shown), kept while
/// the player is away paying, to say so when they're back.
void rememberWebCheckout(
  SharedPreferences prefs, {
  required String? ref,
  int? coins,
  String? price,
}) {
  if (ref == null) return;
  prefs
      .setString(
        _checkoutKey,
        jsonEncode({'ref': ref, 'coins': coins, 'price': price}),
      )
      .ignore();
}

/// The checkout [ref] remembered by [rememberWebCheckout], if it's that one.
({int? coins, String? price})? recallWebCheckout(
  SharedPreferences prefs,
  String ref,
) {
  try {
    final kept = jsonDecode(prefs.getString(_checkoutKey) ?? '');
    if (kept is! Map || kept['ref'] != ref) return null;
    return (
      coins: (kept['coins'] as num?)?.toInt(),
      price: kept['price'] as String?,
    );
  } catch (_) {
    return null;
  }
}

void forgetWebCheckout(SharedPreferences prefs) =>
    prefs.remove(_checkoutKey).ignore();
