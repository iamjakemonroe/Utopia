import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/platform/web_page.dart';
import '../../../core/widgets/utopia_icons.dart';
import '../../../core/widgets/utopia_toast.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../notifications/presentation/notification_actions.dart';
import 'store_controller.dart';

/// In a browser, back from Flutterwave's checkout (the address says
/// ?status=…&tx_ref=…&transaction_id=…): once the player is in, asks
/// whether the payment went through and tells them. The coins themselves
/// arrive on their own (the balance is live), whichever of this and the
/// webhook gets there first. Nothing in the apps.
class WebPaymentReturn extends ConsumerStatefulWidget {
  const WebPaymentReturn({super.key});

  @override
  ConsumerState<WebPaymentReturn> createState() => _WebPaymentReturnState();
}

class _WebPaymentReturnState extends ConsumerState<WebPaymentReturn> {
  @override
  void initState() {
    super.initState();
    final query = WebPage.query;
    final payment = query['tx_ref'];
    if (!kIsWeb || payment == null || !payment.startsWith('utopia-')) return;
    unawaited(_settle(payment, query['transaction_id'], query['status']));
  }

  Future<void> _settle(
    String payment,
    String? transactionId,
    String? status,
  ) async {
    // Until they're signed in and a screen is up to say it on.
    for (var i = 0; i < 60; i++) {
      if (ref.read(currentUserProvider) != null &&
          appNavigatorContext(ref) != null) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
    }
    if (transactionId == null || status == 'cancelled' || status == 'failed') {
      _say(
        "The payment didn't go through, so nothing was charged.",
        ToastKind.warning,
      );
      return;
    }
    final result = await ref
        .read(storeRepositoryProvider)
        .webConfirm(payment, transactionId);
    if (!mounted) return;
    switch (result.status) {
      case 'paid':
        ref.read(gameAudioProvider).play(Sfx.purchase);
        _say(
          'Payment received: ${formatCoins(result.coins)} coins added!',
          ToastKind.success,
        );
        unawaited(ref.read(storeControllerProvider.notifier).refresh());
      case 'pending':
        _say(
          'Your payment is being confirmed. Your coins will arrive in a moment.',
          ToastKind.info,
        );
      default:
        _say(
          "We couldn't confirm that payment yet. If you were charged, your coins will arrive shortly.",
          ToastKind.warning,
        );
    }
  }

  void _say(String text, ToastKind kind) {
    final context = appNavigatorContext(ref);
    if (context == null || !context.mounted) return;
    showUtopiaToast(
      context,
      text,
      kind: kind,
      icon: Icons.monetization_on_rounded,
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
