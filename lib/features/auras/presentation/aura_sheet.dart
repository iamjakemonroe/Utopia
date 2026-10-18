import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/pop_card.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/profiles/profile_providers.dart';
import '../../../core/profiles/profile_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/confetti_burst.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/utopia_icons.dart';
import '../../../core/widgets/utopia_toast.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../coins/presentation/providers/coin_balance_provider.dart';
import '../../store/presentation/coin_shop.dart';
import '../data/aura_repository.dart';
import '../domain/aura.dart';
import 'mythic_badge.dart';

/// The aura up close: a big live preview on your own picture, how long to
/// get it for, and the price.
Future<void> showAuraSheet(BuildContext context, Aura aura) {
  ProviderScope.containerOf(context).read(gameAudioProvider).play(Sfx.drawer);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AuraSheet(aura: aura),
  );
}

class _AuraSheet extends ConsumerStatefulWidget {
  const _AuraSheet({required this.aura});

  final Aura aura;

  @override
  ConsumerState<_AuraSheet> createState() => _AuraSheetState();
}

class _AuraSheetState extends ConsumerState<_AuraSheet> {
  AuraLength _length = AuraLength.week;
  bool _busy = false;
  int _celebrate = 0;

  Future<void> _buy(int price) async {
    final balance = ref.read(coinBalanceProvider).valueOrNull ?? 0;
    if (price > balance) {
      showCoinShop(context, needed: price);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(auraRepositoryProvider).buy(widget.aura.id, _length);
      _refresh();
      ref.read(gameAudioProvider).play(Sfx.purchase);
      if (!mounted) return;
      setState(() => _celebrate++);
      showUtopiaToast(
        context,
        '${widget.aura.name} is yours for ${_length.label}',
        icon: Icons.auto_awesome_rounded,
        kind: ToastKind.success,
      );
    } catch (e) {
      if (mounted) {
        showUtopiaToast(
          context,
          friendlyError(e, fallback: "Couldn't buy that aura. Try again."),
          kind: ToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _wear(bool on) async {
    setState(() => _busy = true);
    try {
      await ref.read(auraRepositoryProvider).equip(on ? widget.aura.id : null);
      _refresh();
      ref.read(gameAudioProvider).play(on ? Sfx.reaction : Sfx.toggleOff);
    } catch (e) {
      if (mounted) {
        showUtopiaToast(
          context,
          friendlyError(e, fallback: "Couldn't change your aura."),
          kind: ToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _refresh() {
    ref.invalidate(myAurasProvider);
    final me = ref.read(currentUserProvider)?.id;
    if (me != null) ref.invalidate(profileByIdProvider(me));
  }

  @override
  Widget build(BuildContext context) {
    final aura = widget.aura;
    final me = ref.watch(currentUserProvider)?.id;
    final profile = me == null
        ? null
        : ref.watch(profileByIdProvider(me)).valueOrNull;
    final name = me == null ? 'You' : profileDisplayName(profile, me);
    final prices = ref.watch(auraPricesProvider).valueOrNull;
    final owned = ref.watch(myAurasProvider).valueOrNull?[aura.id];
    final active = owned != null && owned.isAfter(DateTime.now());
    final wearing = activeAura(profile) == aura.id;
    final balance = ref.watch(coinBalanceProvider).valueOrNull;
    final price = auraPrice(prices, aura, _length);

    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(
              aura.color.withValues(alpha: 0.18),
              AppColors.surfaceElevated,
            ),
            AppColors.background,
          ],
        ),
        border: sheetBorder(aura.color.withValues(alpha: 0.6), width: 1.6),
      ),
      child: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AuraStage(
                    height: 210,
                    color: aura.color,
                    child: UserAvatar.fromProfile(
                      profile,
                      fallbackInitial: name,
                      radius: 56,
                      aura: aura.id,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          aura.name,
                          style: AppTextStyles.display(fontSize: 26),
                        ),
                      ),
                      TierChip(tier: aura.tier),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    aura.tagline,
                    style: AppTextStyles.body(color: AppColors.textSecondary),
                  ),
                  if (active) ...[
                    const SizedBox(height: AppSpacing.md),
                    _OwnedRow(
                      until: owned,
                      wearing: wearing,
                      busy: _busy,
                      onToggle: () => _wear(!wearing),
                    ),
                  ],
                  if (aura.includedWith case final plan?) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      "Comes with $plan. Yours to wear while you're a member.",
                      style: AppTextStyles.body(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ] else if (aura.retired) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'No longer sold. Yours to wear until it runs out.',
                      style: AppTextStyles.body(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        for (final (i, length)
                            in AuraLength.offered.indexed) ...[
                          if (i > 0) const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _LengthTile(
                              length: length,
                              price: auraPrice(prices, aura, length),
                              selected: length == _length,
                              best: length == AuraLength.month,
                              color: aura.color,
                              onTap: () => setState(() => _length = length),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _maybeCharged(
                      mythic: aura.tier == AuraTier.mythic,
                      busy: _busy,
                      child: PrimaryButton(
                        label: active
                            ? 'Add ${_length.label} · ${formatCoins(price)}'
                            : 'Buy for ${formatCoins(price)} coins',
                        color: switch (aura.tier) {
                          AuraTier.mythic => const Color(0xFFFF1F3D),
                          AuraTier.legendary => const Color(0xFFFF8A3D),
                          _ => AppColors.success,
                        },
                        isLoading: _busy,
                        onPressed: () => _buy(price),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  if (balance != null)
                    Center(
                      child: GestureDetector(
                        onTap: () => showCoinShop(context),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'You have ',
                              style: AppTextStyles.body(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            CoinAmount(
                              balance,
                              size: 13,
                              color: AppColors.coinGoldBright,
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.add_circle_rounded,
                              size: 16,
                              color: AppColors.success,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_celebrate > 0)
            Positioned.fill(
              child: ConfettiBurst(key: ValueKey(_celebrate), pieces: 80),
            ),
        ],
      ),
    );
  }
}

class _OwnedRow extends StatelessWidget {
  const _OwnedRow({
    required this.until,
    required this.wearing,
    required this.busy,
    required this.onToggle,
  });

  final DateTime until;
  final bool wearing;
  final bool busy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppColors.success.withValues(alpha: 0.12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.hourglass_bottom_rounded,
            size: 18,
            color: AppColors.success,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Yours · ${auraTimeLeft(until)}',
              style: AppTextStyles.body(fontWeight: FontWeight.w800),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: wearing
                  ? Colors.white.withValues(alpha: 0.12)
                  : AppColors.success,
              minimumSize: const Size(0, 36),
            ),
            onPressed: busy ? null : onToggle,
            child: Text(
              wearing ? 'Take off' : 'Wear',
              style: AppTextStyles.body(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LengthTile extends StatelessWidget {
  const _LengthTile({
    required this.length,
    required this.price,
    required this.selected,
    required this.best,
    required this.color,
    required this.onTap,
  });

  final AuraLength length;
  final int price;
  final bool selected;
  final bool best;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final perDay = (price / length.days).round();
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1 : 0.93,
        duration: const Duration(milliseconds: 420),
        curve: Curves.elasticOut,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Full width of its column, content lined up on the left, so
            // the three tiles sit evenly side by side.
            AnimatedContainer(
              width: double.infinity,
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.fromLTRB(12, 14, 8, 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: selected
                      ? [
                          Color.alphaBlend(
                            color.withValues(alpha: 0.4),
                            AppColors.surfaceElevated,
                          ),
                          Color.alphaBlend(
                            color.withValues(alpha: 0.2),
                            AppColors.surface,
                          ),
                        ]
                      : [AppColors.surfaceElevated, AppColors.surface],
                ),
                border: Border.all(
                  color: selected ? color : Colors.white.withValues(alpha: 0.1),
                  width: selected ? 2.2 : 1.2,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 14,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    switch (length) {
                      AuraLength.days3 => Icons.wb_sunny_rounded,
                      AuraLength.week => Icons.date_range_rounded,
                      AuraLength.month => Icons.calendar_month_rounded,
                    },
                    size: 20,
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    length.label,
                    style: AppTextStyles.body(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  CoinAmount(price, size: 13, color: AppColors.coinGoldBright),
                  const SizedBox(height: 2),
                  Text(
                    '${formatCoins(perDay)} a day',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (best)
              Positioned(
                top: -9,
                left: 10,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF5C9C), Color(0xFFFF8A3D)],
                      ),
                    ),
                    child: Text(
                      'Best value',
                      style: AppTextStyles.body(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A dark, starry little stage with a glow behind whatever stands on it.
class AuraStage extends StatelessWidget {
  const AuraStage({
    super.key,
    required this.child,
    required this.color,
    this.height = 160,
  });

  final Widget child;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: RadialGradient(
          colors: [
            Color.alphaBlend(
              color.withValues(alpha: 0.28),
              const Color(0xFF15102E),
            ),
            const Color(0xFF0B0720),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.infinite,
              painter: _StarsPainter(seed: color.toARGB32()),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _StarsPainter extends CustomPainter {
  _StarsPainter({required this.seed});

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    for (var i = 0; i < 40; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        0.6 + rng.nextDouble() * 1.4,
        Paint()
          ..color = Colors.white.withValues(
            alpha: 0.2 + rng.nextDouble() * 0.6,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarsPainter old) => old.seed != seed;
}

class TierChip extends StatelessWidget {
  const TierChip({super.key, required this.tier, this.small = false});

  final AuraTier tier;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 10,
        vertical: small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: tier.color.withValues(alpha: 0.18),
        border: Border.all(color: tier.color.withValues(alpha: 0.75)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tier.icon, size: small ? 11 : 14, color: tier.color),
          const SizedBox(width: 3),
          Text(
            tier.title,
            style: AppTextStyles.body(
              fontSize: small ? 10 : 12,
              fontWeight: FontWeight.w900,
              color: tier.color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mythic buy buttons crackle with power about to wake up; the rest are
/// plain.
Widget _maybeCharged({
  required bool mythic,
  required bool busy,
  required Widget child,
}) => mythic ? MythicCharge(enabled: !busy, child: child) : child;
