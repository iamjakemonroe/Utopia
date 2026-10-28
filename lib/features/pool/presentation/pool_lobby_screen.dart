import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/coin_balance_pill.dart';
import '../../../core/widgets/coin_buddy.dart';
import '../../../core/widgets/pop_card.dart';
import '../../../core/widgets/utopia_icons.dart';
import '../../../core/widgets/utopia_toast.dart';
import '../../../l10n/strings.dart';
import '../../coins/presentation/providers/coin_balance_provider.dart';
import '../data/pool_repository.dart';
import 'pool_cue_art.dart';
import 'pool_cue_cards.dart';
import 'pool_names.dart';
import 'pool_providers.dart';

/// 8-ball pool's front door: your cue, the coin tables where you play
/// Chip (the entry in, the pot to the winner), and a game for two on one
/// phone.
class PoolLobbyScreen extends ConsumerStatefulWidget {
  const PoolLobbyScreen({super.key});

  @override
  ConsumerState<PoolLobbyScreen> createState() => _PoolLobbyScreenState();
}

class _PoolLobbyScreenState extends ConsumerState<PoolLobbyScreen> {
  String? _starting;

  Future<void> _sit(PoolTableInfo table) async {
    if (_starting != null) return;
    final waiting = ref.read(activePoolGameProvider).valueOrNull;
    if (waiting != null) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(strings.poolNewGameTitle),
          content: Text(
            strings.poolNewGameBody(poolTableName(waiting.tableId)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(strings.poolKeepIt),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(strings.poolStartNew),
            ),
          ],
        ),
      );
      if (sure != true || !mounted) return;
    }
    setState(() => _starting = table.id);
    try {
      final game = await ref.read(poolRepositoryProvider).start(table.id);
      if (!mounted) return;
      ref.invalidate(activePoolGameProvider);
      await context.push('/pool/${game.id}');
      ref.invalidate(activePoolGameProvider);
    } catch (e) {
      if (mounted) {
        showUtopiaToast(context, friendlyError(e), kind: ToastKind.error);
      }
    } finally {
      if (mounted) setState(() => _starting = null);
    }
  }

  Future<void> _resume(PoolTableGame game) async {
    await context.push('/pool/${game.id}');
    ref.invalidate(activePoolGameProvider);
  }

  @override
  Widget build(BuildContext context) {
    final tables = ref.watch(poolTablesProvider).valueOrNull ?? kPoolTables;
    final waiting = ref.watch(activePoolGameProvider).valueOrNull;
    final balance = ref.watch(coinBalanceProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.poolEightBall),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: CoinBalancePill(),
          ),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  if (waiting != null) ...[
                    _Waiting(game: waiting, onResume: () => _resume(waiting)),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  const _YourCue(),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    strings.poolPlayChipForCoins,
                    style: AppTextStyles.display(fontSize: 22),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    strings.poolTablesHelp,
                    style: AppTextStyles.body(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final table in tables) ...[
                    _TableCard(
                      table: table,
                      balance: balance,
                      busy: _starting == table.id,
                      onPlay: () => _sit(table),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  _Friends(onPlay: () => context.push('/pool/friends')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({required this.game, required this.onResume});

  final PoolTableGame game;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return PopCard(
      borderRadius: 22,
      glow: AppColors.goldBorderBright,
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(
        children: [
          const CoinBuddy(mood: BuddyMood.thinking, size: 46),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              strings.poolYourGameWaits(poolTableName(game.tableId)),
              style: AppTextStyles.body(fontWeight: FontWeight.w800),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: onResume,
            child: Text(strings.poolResume),
          ),
        ],
      ),
    );
  }
}

/// The cue the player plays with: how it moves, its tier, level and
/// stats, and the way to another or to a higher level.
class _YourCue extends ConsumerWidget {
  const _YourCue();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:cue, :level, :upgradable) = ref.watch(myPoolCueProvider);
    final tierColor = cueTierColor(cue.tier);
    return PopCard(
      borderRadius: 24,
      glow: cue.animated ? tierColor : null,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                strings.poolYourCue,
                style: AppTextStyles.body(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              CueTierBadge(tier: cue.tier),
            ],
          ),
          SizedBox(
            height: 86,
            child: CuePreview(cue: cue, level: level, angle: -0.08),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  cueName(cue),
                  style: AppTextStyles.display(fontSize: 20),
                ),
              ),
              CueLevelPips(level: level, max: cue.maxLevel, color: tierColor),
            ],
          ),
          const SizedBox(height: 6),
          CueStatBars(stats: cue.at(level), top: cue.best),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/store?tab=pool'),
                  icon: const Icon(Icons.storefront_rounded, size: 18),
                  label: Text(strings.poolMoreCues),
                ),
              ),
              if (upgradable) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB020),
                    ),
                    onPressed: () => showCueUpgrade(context, cue, level),
                    icon: const Icon(Icons.trending_up_rounded, size: 18),
                    label: Text(strings.poolUpgrade),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// A coin table: its felt, its name, Chip's level there, the entry and the
/// pot, and a seat if the player has the coins.
class _TableCard extends StatelessWidget {
  const _TableCard({
    required this.table,
    required this.balance,
    required this.busy,
    required this.onPlay,
  });

  final PoolTableInfo table;
  final int? balance;
  final bool busy;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final (felt, glow) = poolTableColors(table.id);
    final short = balance != null && balance! < table.entry;
    return PopCard(
      borderRadius: 22,
      glow: glow,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _FeltPainter(felt, glow)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          poolTableName(table.id),
                          style: AppTextStyles.display(
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          strings.poolAgainstChip(
                            poolChipAt(table.id, table.bot),
                          ),
                          style: AppTextStyles.body(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 2,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  strings.poolEntry,
                                  style: AppTextStyles.body(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                CoinAmount(
                                  table.entry,
                                  size: 13,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  strings.poolWin,
                                  style: AppTextStyles.body(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                CoinAmount(
                                  table.prize,
                                  size: 13,
                                  color: const Color(0xFFFFE29A),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: short
                          ? Colors.white24
                          : AppColors.success,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: const BorderSide(
                          color: Colors.white54,
                          width: 1.2,
                        ),
                      ),
                    ),
                    onPressed: busy
                        ? null
                        : short
                        ? () => context.push('/store')
                        : onPlay,
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            short ? strings.poolGetCoins : strings.poolPlay,
                            style: AppTextStyles.body(
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A table's felt behind its card: the cloth, a rail, a few balls.
class _FeltPainter extends CustomPainter {
  _FeltPainter(this.felt, this.glow);

  final Color felt, glow;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.6, -0.2),
          radius: 1.3,
          colors: [
            Color.lerp(felt, Colors.white, 0.12)!,
            felt,
            Color.lerp(felt, Colors.black, 0.45)!,
          ],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );
    // A pocket and a few balls at the right, as if on the table.
    final pocket = Offset(size.width * 0.98, size.height * 0.02);
    canvas.drawCircle(
      pocket,
      size.height * 0.26,
      Paint()..color = Colors.black.withValues(alpha: 0.5),
    );
    final rng = math.Random(felt.toARGB32());
    for (var i = 0; i < 4; i++) {
      final c = Offset(
        size.width * (0.62 + rng.nextDouble() * 0.12),
        size.height * (0.15 + rng.nextDouble() * 0.7),
      );
      canvas.drawCircle(
        c.translate(2, 3),
        7,
        Paint()..color = Colors.black.withValues(alpha: 0.25),
      );
      canvas.drawCircle(
        c,
        7,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.4),
            colors: [
              Colors.white.withValues(alpha: 0.9),
              glow.withValues(alpha: 0.85),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: 7)),
      );
    }
    canvas.drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = Colors.black.withValues(alpha: 0.18),
    );
  }

  @override
  bool shouldRepaint(_FeltPainter old) => old.felt != felt || old.glow != glow;
}

class _Friends extends StatelessWidget {
  const _Friends({required this.onPlay});

  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return PopCard(
      borderRadius: 22,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(
            Icons.people_alt_rounded,
            color: AppColors.textPrimary,
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.poolOnThisPhone,
                  style: AppTextStyles.body(fontWeight: FontWeight.w800),
                ),
                Text(
                  strings.poolOnThisPhoneHelp,
                  style: AppTextStyles.body(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(onPressed: onPlay, child: Text(strings.poolPlay)),
        ],
      ),
    );
  }
}
