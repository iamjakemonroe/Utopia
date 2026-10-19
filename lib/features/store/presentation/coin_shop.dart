import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/widgets/pop_card.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/coin_buddy.dart';
import '../../../core/widgets/confetti_burst.dart';
import '../../../core/widgets/utopia_icons.dart';
import '../../../core/widgets/utopia_loader.dart';
import '../../../core/widgets/utopia_toast.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../coins/presentation/providers/coin_balance_provider.dart';
import '../domain/store_catalog.dart';
import 'coin_pack_art.dart';
import 'store_controller.dart';

/// Opens the coin shop. [needed] explains why it opened (a game the player
/// can't afford yet).
Future<void> showCoinShop(BuildContext context, {int? needed}) {
  ProviderScope.containerOf(context).read(gameAudioProvider).play(Sfx.drawer);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CoinShopSheet(needed: needed),
  );
}

class _CoinShopSheet extends ConsumerStatefulWidget {
  const _CoinShopSheet({this.needed});

  final int? needed;

  @override
  ConsumerState<_CoinShopSheet> createState() => _CoinShopSheetState();
}

class _CoinShopSheetState extends ConsumerState<_CoinShopSheet> {
  int? _celebrating;
  int _celebrationKey = 0;

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeControllerProvider);
    final controller = ref.read(storeControllerProvider.notifier);
    final balance = ref.watch(coinBalanceProvider).valueOrNull;
    final packs = controller.packsOnSale;
    final isGuest = ref.watch(isAnonymousProvider);

    ref.listen(storeControllerProvider, (prev, next) {
      final added = next.coinsAdded;
      if (added != null && added != prev?.coinsAdded) {
        setState(() {
          _celebrating = added;
          _celebrationKey++;
        });
        controller.clearCoinsAdded();
        Future.delayed(const Duration(milliseconds: 2600), () {
          if (mounted) setState(() => _celebrating = null);
        });
      }
      final message = next.message;
      if (message != null && message != prev?.message) {
        showUtopiaToast(context, message);
        controller.clearMessage();
      }
    });

    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.surfaceElevated, AppColors.background],
          ),
          border: sheetBorder(AppColors.goldBorder),
        ),
        child: Stack(
          children: [
            SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  _Header(balance: balance, needed: widget.needed),
                  if (controller.canTestUnlock)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.science_rounded,
                            size: 16,
                            color: Color(0xFFFFB020),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Test build: packs are free so you can try them.',
                              style: AppTextStyles.body(
                                fontSize: 12,
                                color: const Color(0xFFFFB020),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (kIsWeb ? !store.webPayments : !Env.realMoneyStore)
                    const _ComingSoon()
                  else ...[
                    if (isGuest)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          AppSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.shield_rounded,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                kIsWeb
                                    ? 'Save your account to buy coins.'
                                    : 'Save your account so your coins are never lost.',
                                style: AppTextStyles.body(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.xs,
                          AppSpacing.md,
                          AppSpacing.md,
                        ),
                        itemCount: packs.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, i) {
                          final pack = packs[i];
                          return _PackCard(
                            pack: pack,
                            price: controller.priceOfPack(pack),
                            busy: store.busyProduct == pack.id,
                            onBuy: () => controller.buyCoins(pack),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
            if (_celebrating != null)
              Positioned.fill(
                child: _Celebration(
                  key: ValueKey(_celebrationKey),
                  coins: _celebrating!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// While real-money top-ups aren't on yet: where coins come from today.
class _ComingSoon extends StatelessWidget {
  const _ComingSoon();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: PopCard(
        borderRadius: 26,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            const CoinBuddy(mood: BuddyMood.excited, size: 84),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Coin top-ups are coming soon',
              textAlign: TextAlign.center,
              style: AppTextStyles.display(fontSize: 20),
            ),
            const SizedBox(height: 6),
            Text(
              'For now, earn them by playing: claim your daily reward every day, and win games with an entry.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.balance, required this.needed});

  final int? balance;
  final int? needed;

  @override
  Widget build(BuildContext context) {
    final short = needed != null && balance != null && balance! < needed!
        ? needed! - balance!
        : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          const CoinBuddy(mood: BuddyMood.happy, size: 72),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Coins', style: AppTextStyles.display(fontSize: 26)),
                const SizedBox(height: 2),
                if (balance != null)
                  CoinAmount(
                    balance!,
                    size: 16,
                    color: AppColors.coinGoldBright,
                  ),
                if (short != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'You need ${formatCoins(short)} more for that game.',
                    style: AppTextStyles.body(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PackCard extends StatefulWidget {
  const _PackCard({
    required this.pack,
    required this.price,
    required this.busy,
    required this.onBuy,
  });

  final CoinPack pack;
  final String price;
  final bool busy;
  final VoidCallback onBuy;

  @override
  State<_PackCard> createState() => _PackCardState();
}

class _PackCardState extends State<_PackCard>
    with SingleTickerProviderStateMixin {
  // One long, steady clock (an hour per loop) so the art's motion,
  // driven by seconds, never jumps.
  late final AnimationController _shine = AnimationController(
    vsync: this,
    duration: const Duration(hours: 1),
  )..repeat();
  bool _pressed = false;

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pack = widget.pack;
    final tier = pack.art;
    final featured = pack.badge != null;
    final accent = featured ? AppColors.goldBorderBright : AppColors.glowRing;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.busy ? null : widget.onBuy,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: tier >= 5 ? 116 : 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(AppColors.surfaceElevated, accent, 0.12)!,
                AppColors.surface,
              ],
            ),
            border: Border.all(
              color: accent.withValues(alpha: featured ? 0.9 : 0.4),
              width: featured ? 2 : 1.2,
            ),
            boxShadow: featured
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.3),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: Stack(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: tier >= 5 ? 124 : 104,
                      // Fill the card's height: a bare CustomPaint in a Row
                      // would otherwise be given no height at all.
                      height: double.infinity,
                      child: AnimatedBuilder(
                        animation: _shine,
                        builder: (context, _) => CustomPaint(
                          painter: CoinPackArtPainter(
                            tier: tier,
                            t: _shine.value * 3600,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Up to 8,000,000: shrinks to fit a narrow phone
                          // next to a long local price.
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              formatCoins(pack.coins),
                              maxLines: 1,
                              style: AppTextStyles.display(fontSize: 24),
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 3,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                pack.name,
                                style: AppTextStyles.body(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (pack.bonusPercent > 0)
                                _BonusTag(percent: pack.bonusPercent),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _PriceButton(
                        price: widget.price,
                        busy: widget.busy,
                      ),
                    ),
                  ],
                ),
                if (pack.badge != null)
                  Positioned(
                    top: 0,
                    right: 18,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 3, 10, 4),
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(10),
                        ),
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF5C9C), Color(0xFFFF8A3D)],
                        ),
                      ),
                      child: Text(
                        pack.badge!,
                        style: AppTextStyles.body(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BonusTag extends StatelessWidget {
  const _BonusTag({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.6)),
      ),
      child: Text(
        '+$percent% extra',
        style: AppTextStyles.body(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: AppColors.success,
        ),
      ),
    );
  }
}

class _PriceButton extends StatelessWidget {
  const _PriceButton({required this.price, required this.busy});

  final String price;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 84, maxWidth: 132),
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(21),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6BF0B0), Color(0xFF1FB877)],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0xFF0E7A4E), offset: Offset(0, 3)),
        ],
      ),
      child: busy
          ? const SizedBox.square(dimension: 22, child: UtopiaLoader(size: 22))
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                price,
                maxLines: 1,
                style: AppTextStyles.display(fontSize: 16, color: Colors.white),
              ),
            ),
    );
  }
}

class _Celebration extends StatelessWidget {
  const _Celebration({super.key, required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          const Positioned.fill(child: ConfettiBurst(pieces: 90)),
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.elasticOut,
              builder: (context, v, child) =>
                  Transform.scale(scale: v, child: child),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: AppColors.goldBorderBright,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.goldBorderBright.withValues(alpha: 0.5),
                      blurRadius: 30,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CoinBuddy(mood: BuddyMood.happy, size: 64),
                    CoinAmount(
                      coins,
                      prefix: '+',
                      size: 28,
                      color: AppColors.coinGoldBright,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
