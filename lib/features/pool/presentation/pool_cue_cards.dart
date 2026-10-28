import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/layout/responsive.dart';
import '../../../core/profiles/profile_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/confetti_burst.dart';
import '../../../core/widgets/pop_card.dart';
import '../../../core/widgets/utopia_icons.dart';
import '../../../core/widgets/utopia_toast.dart';
import '../../../l10n/strings.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../store/domain/store_catalog.dart';
import '../../store/presentation/store_controller.dart';
import '../data/pool_repository.dart';
import '../domain/pool_cues.dart';
import 'pool_cue_art.dart';
import 'pool_names.dart';

/// Every pool cue (the store), or only the player's own ([ownedOnly],
/// their collection): each moving as it does at the table, its tier, its
/// level and its stats, to buy, equip and upgrade.
class PoolCuesTab extends ConsumerWidget {
  const PoolCuesTab({super.key, this.ownedOnly = false});

  final bool ownedOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeControllerProvider);
    final me = ref.watch(currentUserProvider)?.id;
    final equipped = me == null
        ? kStarterCue
        : (ref.watch(profileByIdProvider(me)).valueOrNull?['equipped_pool_cue']
                  as String? ??
              kStarterCue);
    final levels =
        ref.watch(poolCueLevelsProvider).valueOrNull ?? const <String, int>{};
    return GridView.count(
      padding: const EdgeInsets.all(AppSpacing.md),
      crossAxisCount: context.gridColumns(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 0.56,
      children: [
        for (final cue in kPoolCues)
          if (!ownedOnly || store.isOwned(StoreCatalog.cueItem(cue.id)))
            PoolCueCard(
              cue: cue,
              level: (levels[cue.id] ?? 1).clamp(1, cue.maxLevel),
              equipped: equipped == cue.id,
            ),
      ],
    );
  }
}

/// A tier's badge: "Legendary".
class CueTierBadge extends StatelessWidget {
  const CueTierBadge({super.key, required this.tier});

  final CueTier tier;

  @override
  Widget build(BuildContext context) {
    final color = cueTierColor(tier);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Color.lerp(color, Colors.black, 0.55)!.withValues(alpha: 0.85),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tier.animated) ...[
            Icon(Icons.auto_awesome_rounded, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            cueTierName(tier),
            style: AppTextStyles.body(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// A cue's level as pips: filled up to [level], of [max].
class CueLevelPips extends StatelessWidget {
  const CueLevelPips({
    super.key,
    required this.level,
    required this.max,
    required this.color,
  });

  final int level, max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= max; i++)
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 1.2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i <= level ? color : Colors.white.withValues(alpha: 0.16),
              boxShadow: i <= level
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
          ),
      ],
    );
  }
}

/// A cue's three stats as bars; with [next], what the next level adds
/// shows in green; with [top], how far its levels take it, faintly.
class CueStatBars extends StatelessWidget {
  const CueStatBars({
    super.key,
    required this.stats,
    this.next,
    this.top,
    this.compact = false,
  });

  final CueStats stats;
  final CueStats? next;
  final CueStats? top;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final rows = [
      (strings.poolStatPower, stats.power, next?.power, top?.power),
      (strings.poolStatAim, stats.aim, next?.aim, top?.aim),
      (strings.poolStatSpin, stats.spin, next?.spin, top?.spin),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (label, value, after, most) in rows)
          Padding(
            padding: EdgeInsets.symmetric(vertical: compact ? 1.5 : 3),
            child: Row(
              children: [
                SizedBox(
                  width: compact ? 40 : 52,
                  child: Text(
                    label,
                    style: AppTextStyles.body(
                      fontSize: compact ? 10 : 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: compact ? 6 : 8,
                      child: CustomPaint(
                        painter: _BarPainter(value, after, most),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: compact ? 24 : 44,
                  child: Text(
                    after != null && after > value ? '$value→$after' : '$value',
                    textAlign: TextAlign.right,
                    style: AppTextStyles.body(
                      fontSize: compact ? 10 : 12,
                      fontWeight: FontWeight.w800,
                      color: after != null && after > value
                          ? AppColors.success
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.value, this.after, this.most);

  final int value;
  final int? after, most;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.white.withValues(alpha: 0.1),
    );
    final m = most;
    if (m != null && m > value) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width * m / 100, size.height),
        Paint()..color = Colors.white.withValues(alpha: 0.16),
      );
    }
    final a = after;
    if (a != null && a > value) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width * a / 100, size.height),
        Paint()..color = AppColors.success.withValues(alpha: 0.85),
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width * value / 100, size.height),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF4DA3FF), Color(0xFFB45CFF), Color(0xFFFFB020)],
        ).createShader(Offset.zero & Size(size.width, size.height)),
    );
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.value != value || old.after != after || old.most != most;
}

/// One cue in the store or the collection.
class PoolCueCard extends ConsumerStatefulWidget {
  const PoolCueCard({
    super.key,
    required this.cue,
    required this.level,
    required this.equipped,
  });

  final PoolCue cue;
  final int level;
  final bool equipped;

  @override
  ConsumerState<PoolCueCard> createState() => _PoolCueCardState();
}

class _PoolCueCardState extends ConsumerState<PoolCueCard> {
  bool _equipping = false;

  @override
  Widget build(BuildContext context) {
    final cue = widget.cue;
    final store = ref.watch(storeControllerProvider);
    final item = StoreCatalog.cueItem(cue.id);
    final owned = store.isOwned(item);
    final forever = store.isOwnedForever(item);
    final product = StoreCatalog.productFor(cue.id);
    final tierColor = cueTierColor(cue.tier);
    final canUpgrade = forever && widget.level < cue.maxLevel;

    Widget action;
    if (widget.equipped) {
      action = _Pill(
        label: strings.storeEquipped,
        color: AppColors.success,
        icon: Icons.check_rounded,
      );
    } else if (owned) {
      action = _SmallButton(
        label: _equipping ? strings.storeEquipping : strings.storeEquip,
        color: AppColors.success,
        onPressed: _equipping
            ? null
            : () async {
                setState(() => _equipping = true);
                final error = await ref
                    .read(storeControllerProvider.notifier)
                    .equipPieces(item);
                if (!mounted) return;
                setState(() => _equipping = false);
                if (error != null) {
                  showUtopiaToast(this.context, error, kind: ToastKind.error);
                }
              },
      );
    } else if (product != null) {
      final busy = store.busyProduct == product.id;
      // The server's price, or the catalogue's until that's in.
      final price = store.coinPrices[product.id] ?? cue.price;
      action = _SmallButton(
        label: busy ? '…' : formatCoins(price),
        color: AppColors.accent,
        coin: true,
        onPressed: busy
            ? null
            : () => ref.read(storeControllerProvider.notifier).buy(product),
      );
    } else {
      action = const SizedBox.shrink();
    }

    return PopCard(
      borderRadius: 24,
      glow: widget.equipped
          ? AppColors.success
          : (cue.animated ? tierColor : null),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(21),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.2),
                    radius: 1.1,
                    colors: [
                      Color.lerp(tierColor, Colors.black, 0.62)!,
                      Color.lerp(AppColors.background, Colors.black, 0.35)!,
                    ],
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CuePreview(cue: cue, level: widget.level, angle: -0.78),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: CueTierBadge(tier: cue.tier),
                    ),
                    if (owned)
                      Positioned(
                        top: 10,
                        right: 8,
                        child: Text(
                          strings.poolLevelShort(widget.level),
                          style: AppTextStyles.body(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              children: [
                Text(
                  cueName(cue),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                CueLevelPips(
                  level: owned ? widget.level : 0,
                  max: cue.maxLevel,
                  color: tierColor,
                ),
                const SizedBox(height: 4),
                CueStatBars(
                  stats: cue.at(widget.level),
                  top: cue.best,
                  compact: true,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: Center(child: action)),
                    if (canUpgrade) ...[
                      const SizedBox(width: 4),
                      _SmallButton(
                        label: strings.poolUpgrade,
                        color: const Color(0xFFFFB020),
                        onPressed: () =>
                            showCueUpgrade(context, cue, widget.level),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.readable(color).withValues(alpha: 0.9),
        border: Border.all(color: Colors.white, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: AppTextStyles.body(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({
    required this.label,
    required this.color,
    required this.onPressed,
    this.coin = false,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final bool coin;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: const Size(0, 30),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.goldBorder, width: 1.2),
        ),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (coin) ...[const CoinIcon(size: 13), const SizedBox(width: 3)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body(
                fontSize: 12,
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

/// The upgrade: [cue] from [level] to the next, its new stats in green and
/// what it costs.
Future<void> showCueUpgrade(BuildContext context, PoolCue cue, int level) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UpgradeSheet(cue: cue, level: level),
    );

class _UpgradeSheet extends ConsumerStatefulWidget {
  const _UpgradeSheet({required this.cue, required this.level});

  final PoolCue cue;
  final int level;

  @override
  ConsumerState<_UpgradeSheet> createState() => _UpgradeSheetState();
}

class _UpgradeSheetState extends ConsumerState<_UpgradeSheet> {
  late int _level = widget.level;
  bool _busy = false;
  int _burst = 0;

  Future<void> _upgrade() async {
    setState(() => _busy = true);
    try {
      final level = await ref
          .read(poolRepositoryProvider)
          .upgradeCue(widget.cue.id);
      ref.invalidate(poolCueLevelsProvider);
      ref.read(gameAudioProvider).play(Sfx.purchase);
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _level = level;
          _busy = false;
          _burst++;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showUtopiaToast(context, friendlyError(e), kind: ToastKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cue = widget.cue;
    final cost = cue.upgradeCost(_level);
    final top = cost == null;
    final tierColor = cueTierColor(cue.tier);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: PopCard(
          borderRadius: 28,
          glow: tierColor,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      CueTierBadge(tier: cue.tier),
                      const Spacer(),
                      CueLevelPips(
                        level: _level,
                        max: cue.maxLevel,
                        color: tierColor,
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 120,
                    child: CuePreview(
                      key: ValueKey(_level),
                      cue: cue,
                      level: _level,
                      angle: -0.12,
                    ),
                  ),
                  Text(
                    cueName(cue),
                    style: AppTextStyles.display(fontSize: 24),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    top
                        ? strings.poolTopLevel(_level)
                        : strings.poolLevelUp(_level, _level + 1),
                    style: AppTextStyles.body(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CueStatBars(
                    stats: cue.at(_level),
                    next: top ? null : cue.at(_level + 1),
                  ),
                  if (cue.animated) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      strings.poolLevelGlow,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  if (top)
                    Text(
                      strings.poolMaxedOut,
                      style: AppTextStyles.body(fontWeight: FontWeight.w800),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFFB020),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: _busy ? null : _upgrade,
                        child: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    strings.poolUpgradeFor,
                                    style: AppTextStyles.body(
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  CoinAmount(
                                    cost,
                                    size: 15,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                      ),
                    ),
                ],
              ),
              if (_burst > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ConfettiBurst(key: ValueKey(_burst), pieces: 60),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
