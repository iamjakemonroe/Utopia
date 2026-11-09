import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/bouncy_dialog.dart';
import '../../../core/widgets/coin_buddy.dart';
import '../../../core/widgets/confetti_burst.dart';
import '../../../core/widgets/pop_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/utopia_icons.dart';
import '../../../core/widgets/utopia_loader.dart';
import '../../../l10n/strings.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../coins/presentation/providers/coin_balance_provider.dart';
import '../../maestro/presentation/maestro_sheet.dart';
import 'coin_shop.dart';
import 'store_controller.dart';

/// Where a purchase stands, for the result modal.
enum PurchaseStage {
  /// Back from checkout, asking whether it went through.
  confirming,

  /// Paid: the coins are in, or the plan's on.
  paid,

  /// Not confirmed yet after a long wait (or the store says the money is
  /// still on its way): it'll be added when it is, with a notification.
  waiting,

  /// Failed or cancelled: nothing was charged.
  failed,

  /// The answer couldn't be had: honest about it, and where it'll show.
  unconfirmed,
}

/// Where it was bought: Flutterwave's checkout (a browser), or the App
/// Store or Google Play.
enum PurchaseVia { web, store }

/// A purchase's outcome, as the result modal shows it.
@immutable
class PurchaseResult {
  const PurchaseResult({
    required this.stage,
    this.via = PurchaseVia.web,
    this.plan = false,
    this.coins,
    this.paid,
    this.balance,
    this.otherAccount = false,
  });

  final PurchaseStage stage;
  final PurchaseVia via;

  /// Chip Maestro, rather than coins.
  final bool plan;

  /// A coin pack's coins.
  final int? coins;

  /// What was paid, ready to show ('£3.99', '₦1,000'), when it's known.
  final String? paid;

  /// The coin balance after, when the server said.
  final int? balance;

  /// Paid, but by another account (that account has it).
  final bool otherAccount;

  PurchaseResult copyWith({
    PurchaseStage? stage,
    int? coins,
    String? paid,
    int? balance,
    bool? otherAccount,
  }) => PurchaseResult(
    stage: stage ?? this.stage,
    via: via,
    plan: plan,
    coins: coins ?? this.coins,
    paid: paid ?? this.paid,
    balance: balance ?? this.balance,
    otherAccount: otherAccount ?? this.otherAccount,
  );
}

/// Whether a purchase's result is up, confirming or paid (or was paid a
/// moment ago), so the live banner for the same purchase's notification
/// doesn't pop up over it, saying it twice. The notification is still in
/// the list, and once the modal says to wait for it, it pops up as usual.
abstract final class PurchaseResults {
  static ValueListenable<PurchaseResult>? _showing;
  static DateTime? _paidAt;

  static bool get quiet {
    final stage = _showing?.value.stage;
    return stage == PurchaseStage.confirming ||
        stage == PurchaseStage.paid ||
        (_paidAt != null &&
            DateTime.now().difference(_paidAt!) < const Duration(seconds: 30));
  }
}

/// Shows [result] (which can move on, e.g. from confirming to paid) in a
/// modal over [context]'s navigator, until it's closed.
Future<void> showPurchaseResult(
  BuildContext context,
  ValueListenable<PurchaseResult> result,
) async {
  final nav = Navigator.of(context, rootNavigator: true).context;
  PurchaseResults._showing = result;
  try {
    await showBouncyDialog<void>(
      context: context,
      // A payment still being confirmed is closed with its button, not a
      // stray tap beside it.
      dismissible: false,
      builder: (dialog) => PurchaseResultView(
        result: result,
        onClose: () => Navigator.of(dialog).pop(),
        onTryAgain: () {
          Navigator.of(dialog).pop();
          if (!nav.mounted) return;
          // Back to where it was bought, unless that's still open below.
          if (result.value.plan) {
            if (maestroSheetOpen.value == 0) showMaestroSheet(nav);
          } else if (coinShopOpen.value == 0) {
            showCoinShop(nav);
          }
        },
      ),
    );
  } finally {
    if (identical(PurchaseResults._showing, result)) {
      PurchaseResults._showing = null;
    }
    if (result.value.stage == PurchaseStage.paid) {
      PurchaseResults._paidAt = DateTime.now();
    }
  }
}

/// The result modal's card: a short celebration and what was bought,
/// paid for and now in the balance; a payment still being confirmed; one
/// that didn't go through (and a way to try again); or one that couldn't
/// be confirmed (and where it'll show).
class PurchaseResultView extends ConsumerStatefulWidget {
  const PurchaseResultView({
    super.key,
    required this.result,
    required this.onClose,
    required this.onTryAgain,
  });

  final ValueListenable<PurchaseResult> result;
  final VoidCallback onClose;
  final VoidCallback onTryAgain;

  @override
  ConsumerState<PurchaseResultView> createState() => _PurchaseResultViewState();
}

class _PurchaseResultViewState extends ConsumerState<PurchaseResultView> {
  PurchaseStage? _heard;

  @override
  void initState() {
    super.initState();
    widget.result.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) => _changed());
  }

  @override
  void dispose() {
    widget.result.removeListener(_changed);
    super.dispose();
  }

  /// A sound for the moment it lands: paid, or not.
  void _changed() {
    if (!mounted) return;
    final stage = widget.result.value.stage;
    if (stage == _heard) return;
    _heard = stage;
    final audio = ref.read(gameAudioProvider);
    switch (stage) {
      case PurchaseStage.paid:
        audio.play(Sfx.purchase);
        HapticFeedback.mediumImpact();
      case PurchaseStage.failed:
        audio.play(Sfx.toggleOff);
      case PurchaseStage.confirming ||
          PurchaseStage.waiting ||
          PurchaseStage.unconfirmed:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final live = ref.watch(coinBalanceProvider).valueOrNull;
    return ValueListenableBuilder<PurchaseResult>(
      valueListenable: widget.result,
      builder: (context, r, _) {
        final celebrate = r.stage == PurchaseStage.paid && !still;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Confetti over the whole screen, behind the card.
            if (celebrate)
              Positioned.fill(
                child: ConfettiBurst(
                  key: ValueKey('confetti-${r.plan}'),
                  pieces: 90,
                ),
              ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Material(
                  type: MaterialType.transparency,
                  child: PopCard(
                    borderRadius: 28,
                    glow: _glow(r),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    // One stage gives way to the next with a fade and the
                    // card easing to its new size; at once with reduced
                    // motion.
                    child: still
                        ? _content(r, still, live)
                        : AnimatedSize(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 260),
                              switchInCurve: Curves.easeOutCubic,
                              child: KeyedSubtree(
                                key: ValueKey(r.stage),
                                child: _content(r, still, live),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static Color? _glow(PurchaseResult r) => switch (r.stage) {
    PurchaseStage.paid => r.plan ? _maestroPink : AppColors.coinGold,
    PurchaseStage.failed => AppColors.error,
    _ => null,
  };

  Widget _content(PurchaseResult r, bool still, int? live) {
    switch (r.stage) {
      case PurchaseStage.paid when r.plan:
        return _Body(
          hero: const CoinBuddy(mood: BuddyMood.happy, size: 96, beret: true),
          title: strings.purchaseResultWelcomeToMaestro,
          lines: [
            strings.purchaseResultMaestroBody,
            if (r.paid != null) strings.purchaseResultMaestroPrice(r.paid!),
          ],
          primary: strings.purchaseResultLetsCreate,
          onPrimary: widget.onClose,
          color: _maestroPink,
        );
      case PurchaseStage.paid:
        final balance = live == null
            ? r.balance
            : r.balance == null || live > r.balance!
            ? live
            : r.balance;
        return _Body(
          hero: const CoinBuddy(mood: BuddyMood.happy, size: 88),
          title: strings.purchaseResultPaymentReceived,
          extra: [
            if ((r.coins ?? 0) > 0) _CoinsIn(coins: r.coins!, still: still),
            if (r.paid != null)
              _Line(strings.purchaseResultYouPaid(r.paid!), strong: true),
            if (balance != null) _Balance(balance),
          ],
          primary: strings.purchaseResultLovely,
          onPrimary: widget.onClose,
        );
      case PurchaseStage.confirming:
        return _Body(
          hero: const UtopiaLoader(size: 64),
          title: strings.purchaseResultConfirming,
          lines: [strings.purchaseResultConfirmingBody],
          secondary: strings.purchaseResultClose,
          onSecondary: widget.onClose,
        );
      case PurchaseStage.waiting:
        final web = r.via == PurchaseVia.web;
        return _Body(
          hero: const CoinBuddy(mood: BuddyMood.thinking, size: 84),
          title: web
              ? strings.purchaseResultStillConfirming
              : strings.purchaseResultStillGoingThrough,
          lines: [
            switch ((web, r.plan)) {
              (true, false) => strings.purchaseResultWaitingCoinsWeb,
              (true, true) => strings.purchaseResultWaitingMaestroWeb,
              (false, false) => strings.purchaseResultWaitingCoinsStore,
              (false, true) => strings.purchaseResultWaitingMaestroStore,
            },
          ],
          primary: strings.purchaseResultOk,
          onPrimary: widget.onClose,
        );
      case PurchaseStage.failed:
        return _Body(
          hero: const CoinBuddy(mood: BuddyMood.sad, size: 84),
          title: strings.purchaseResultDidntGoThrough,
          lines: [strings.purchaseResultNothingCharged],
          primary: strings.purchaseResultTryAgain,
          onPrimary: widget.onTryAgain,
          secondary: strings.purchaseResultClose,
          onSecondary: widget.onClose,
        );
      case PurchaseStage.unconfirmed:
        final web = r.via == PurchaseVia.web;
        return _Body(
          hero: const CoinBuddy(mood: BuddyMood.thinking, size: 84),
          title: r.otherAccount
              ? strings.purchaseResultSomewhereElse
              : strings.purchaseResultCouldntConfirm,
          lines: [
            if (r.otherAccount)
              strings.purchaseResultOtherAccount
            else
              switch ((web, r.plan)) {
                (true, false) => strings.purchaseResultCouldntConfirmCoins,
                (true, true) => strings.purchaseResultCouldntConfirmMaestro,
                (false, false) =>
                  strings.purchaseResultCouldntConfirmStoreCoins,
                (false, true) =>
                  strings.purchaseResultCouldntConfirmStoreMaestro,
              },
          ],
          primary: strings.purchaseResultOk,
          onPrimary: widget.onClose,
        );
    }
  }
}

const _maestroPink = Color(0xFFFF5C9C);

class _Body extends StatelessWidget {
  const _Body({
    required this.hero,
    required this.title,
    this.lines = const [],
    this.extra = const [],
    this.primary,
    this.onPrimary,
    this.secondary,
    this.onSecondary,
    this.color,
  });

  final Widget hero;
  final String title;
  final List<String> lines;
  final List<Widget> extra;
  final String? primary;
  final VoidCallback? onPrimary;
  final String? secondary;
  final VoidCallback? onSecondary;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        hero,
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          liveRegion: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.display(fontSize: 22),
          ),
        ),
        for (final line in lines) ...[
          const SizedBox(height: AppSpacing.sm),
          _Line(line),
        ],
        for (final w in extra) ...[const SizedBox(height: AppSpacing.sm), w],
        const SizedBox(height: AppSpacing.lg),
        if (primary != null)
          PrimaryButton(label: primary!, color: color, onPressed: onPrimary),
        if (secondary != null) ...[
          if (primary != null) const SizedBox(height: AppSpacing.xs),
          TextButton(onPressed: onSecondary, child: Text(secondary!)),
        ] else
          const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.text, {this.strong = false});

  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: AppTextStyles.body(
        fontSize: strong ? 15 : 14,
        fontWeight: strong ? FontWeight.w800 : FontWeight.w400,
        color: strong ? AppColors.textPrimary : AppColors.textSecondary,
      ),
    );
  }
}

/// "+20,000" coins, counting up as they land (at once with reduced
/// motion).
class _CoinsIn extends StatelessWidget {
  const _CoinsIn({required this.coins, required this.still});

  final int coins;
  final bool still;

  @override
  Widget build(BuildContext context) {
    final gold = AppColors.readable(AppColors.coinGoldBright);
    // Shrinks to fit a narrow card (or big text) rather than overflow.
    Widget amount(int shown) => FittedBox(
      fit: BoxFit.scaleDown,
      child: CoinAmount(shown, prefix: '+', size: 32, color: gold),
    );
    if (still) return amount(coins);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => Transform.scale(
        scale: 0.85 + 0.15 * Curves.elasticOut.transform(t),
        child: amount((coins * t).round()),
      ),
    );
  }
}

class _Balance extends StatelessWidget {
  const _Balance(this.balance);

  final int balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.coinGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.coinGold.withValues(alpha: 0.4)),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Text(
            strings.purchaseResultNewBalance,
            style: AppTextStyles.body(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          CoinAmount(balance, size: 15),
        ],
      ),
    );
  }
}

/// Shows the result of a purchase made in the App Store or Google Play
/// (the store controller's [StoreState.result]) once a screen is up.
class PurchaseResultHost extends ConsumerStatefulWidget {
  const PurchaseResultHost({super.key});

  @override
  ConsumerState<PurchaseResultHost> createState() => _PurchaseResultHostState();
}

class _PurchaseResultHostState extends ConsumerState<PurchaseResultHost> {
  @override
  Widget build(BuildContext context) {
    ref.listen(storeControllerProvider.select((s) => s.result), (_, next) {
      if (next == null) return;
      ref.read(storeControllerProvider.notifier).clearResult();
      unawaited(_present(next));
    });
    return const SizedBox.shrink();
  }

  Future<void> _present(PurchaseResult result) async {
    final context = await waitForAppScreen(ref, () => mounted);
    if (context == null || !context.mounted) return;
    await showPurchaseResult(context, ValueNotifier(result));
  }
}

/// A context under the app's navigator once the player is signed in (with
/// an account, if [account]) and past the splash, for a modal; null if the
/// widget asking goes first ([alive] says false).
Future<BuildContext?> waitForAppScreen(
  WidgetRef ref,
  bool Function() alive, {
  bool account = false,
}) async {
  final router = ref.read(goRouterProvider);
  while (alive()) {
    final context = router.routerDelegate.navigatorKey.currentContext;
    final user = ref.read(currentUserProvider);
    if (context != null &&
        context.mounted &&
        user != null &&
        !(account && ref.read(isAnonymousProvider)) &&
        currentPath(router) != '/splash') {
      return context;
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }
  return null;
}
