import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/profiles/profile_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/pop_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/utopia_icons.dart';
import '../../../core/widgets/utopia_loader.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../checkers/domain/checkers_engine.dart';
import '../../checkers/presentation/widgets/checkers_disc.dart';
import '../../chess/domain/chess_types.dart';
import '../../chess/presentation/widgets/chess_piece_art.dart';
import '../../chess/presentation/widgets/chess_piece_styles.dart';
import '../data/rankings_repository.dart';
import '../domain/ranking.dart';
import 'hologram/rank_hologram.dart';
import 'rankings_widgets.dart';
import '../../../core/layout/responsive.dart';

/// The chess, checkers and Guess My Doodle boards. At the top, the player: their tier badge,
/// rating (and how it's moved this week), their rating line and record,
/// and the tier ladder. Then the board: the top three on a podium and
/// everyone after, worldwide or among friends, with the player's own place
/// pinned below when they're further down. Ratings come from online games.
class RankingsScreen extends StatefulWidget {
  const RankingsScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen> {
  late String _game =
      rankedGames[widget.initialTab.clamp(0, rankedGames.length - 1)];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rankings'),
        actions: [
          IconButton(
            tooltip: 'How rankings work',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => showTierGuide(context),
          ),
        ],
      ),
      body: AppBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: _GameSwitch(
                game: _game,
                onChanged: (g) => setState(() => _game = g),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _Board(key: ValueKey(_game), game: _game),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _gameName(String game) => rankedGameName(game);

class _Board extends ConsumerStatefulWidget {
  const _Board({super.key, required this.game});

  final String game;

  @override
  ConsumerState<_Board> createState() => _BoardState();
}

class _BoardState extends ConsumerState<_Board> {
  bool _friends = false;

  Future<void> _refresh() async {
    final game = widget.game;
    ref.invalidate(myRecordProvider(game));
    ref.invalidate(ratingHistoryProvider(game));
    ref.invalidate(leaderboardProvider((game, _friends)));
    ref.invalidate(boardMoreProvider((game, _friends)));
    await ref.read(leaderboardProvider((game, _friends)).future);
  }

  void _open(BoardEntry entry) {
    ref.read(gameAudioProvider).play(Sfx.tap);
    showBoardPlayer(
      context,
      entry: entry,
      game: widget.game,
      gameName: _gameName(widget.game),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final key = (game, _friends);
    final board = ref.watch(leaderboardProvider(key));
    final record = ref.watch(myRecordProvider(game)).valueOrNull;
    final history =
        ref.watch(ratingHistoryProvider(game)).valueOrNull ?? const [];
    final me = ref.watch(currentUserProvider)?.id;
    final isGuest = ref.watch(isAnonymousProvider);
    final value = board.valueOrNull;
    // The first page, then the ones brought in while scrolling down.
    final more = ref.watch(boardMoreProvider(key));
    final top = [...?value?.top, ...more.entries];
    final rating = value?.myRating ?? record?.rating ?? 1000;
    final place = value?.myPlace;
    final pinned = place != null && !top.any((e) => e.userId == me);
    final myProfile = me == null
        ? null
        : ref.watch(profileByIdProvider(me)).valueOrNull;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _refresh,
          // Near the end of what's shown: the next page of the board.
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (value != null && n.metrics.extentAfter < 600) {
                ref
                    .read(boardMoreProvider(key).notifier)
                    .loadNext(
                      firstPage: value.top.length,
                      firstMore: value.hasMore,
                    );
              }
              return false;
            },
            child: ListView(
              padding: context.readablePadding(
                top: AppSpacing.md,
                bottom: pinned ? 100 : AppSpacing.xxl,
              ),
              children: [
                switch (board) {
                  AsyncData(:final value) => _MyRankCard(
                    game: game,
                    board: value,
                    record: record,
                    history: history,
                    friends: _friends,
                  ),
                  AsyncError() => _LoadError(
                    onRetry: () => ref.invalidate(leaderboardProvider(key)),
                  ),
                  _ => const SizedBox(
                    height: 220,
                    child: Center(child: UtopiaLoader(size: 48)),
                  ),
                },
                const SizedBox(height: AppSpacing.sm),
                TierLadder(rating: rating),
                const SizedBox(height: AppSpacing.lg),
                // Side by side when there's room; the switch goes under on
                // a narrow phone.
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    Text(
                      'Top players',
                      style: AppTextStyles.display(fontSize: 20),
                    ),
                    if (!isGuest)
                      _ScopeSwitch(
                        friends: _friends,
                        onChanged: (v) {
                          ref.read(gameAudioProvider).play(Sfx.tap);
                          setState(() => _friends = v);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (value != null)
                  if (top.isEmpty)
                    _NobodyYet(game: game, friends: _friends)
                  else ...[
                    Podium(top: top.take(3).toList(), myId: me, onTap: _open),
                    const SizedBox(height: AppSpacing.md),
                    for (final (i, entry) in top.skip(3).indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: BoardRow(
                          entry: entry,
                          me: entry.userId == me,
                          index: i,
                          onTap: () => _open(entry),
                        ),
                      ),
                    if (more.loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                        child: Center(child: UtopiaLoader(size: 32)),
                      ),
                  ],
                const SizedBox(height: AppSpacing.sm),
                if (top.any((e) => e.house))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      "Players tagged House are Utopia's own: they keep the "
                      'board busy until more players join, and never win '
                      'prizes.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                Text(
                  'Ratings come from online games. Pull down to refresh.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (pinned)
          Positioned(
            // In line with the board above.
            left: context.readablePadding().left,
            right: context.readablePadding().right,
            bottom: AppSpacing.md,
            child: SafeArea(
              top: false,
              child: MeBar(place: place, rating: rating, profile: myProfile),
            ),
          ),
      ],
    );
  }
}

/// Chess or checkers, with a piece for each.
class _GameSwitch extends StatelessWidget {
  const _GameSwitch({required this.game, required this.onChanged});

  final String game;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(String id, Widget art) {
      final on = id == game;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: on
                  ? LinearGradient(
                      colors: [
                        Color.lerp(AppColors.accent, Colors.white, 0.2)!,
                        AppColors.accent,
                      ],
                    )
                  : null,
              boxShadow: on
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.45),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox.square(dimension: 28, child: Center(child: art)),
                const SizedBox(width: 6),
                // "Guess My Doodle" shrinks to fit a third of a phone.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _gameName(id),
                      maxLines: 1,
                      style: AppTextStyles.body(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: on ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.black.withValues(alpha: 0.28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          tab(
            'chess',
            ChessPieceArt(
              type: PieceType.knight,
              finish: ChessPieceStyle.byId('classic').white,
              size: 26,
            ),
          ),
          tab(
            'checkers',
            const SizedBox.square(
              dimension: 24,
              child: CustomPaint(painter: _DiscArt()),
            ),
          ),
          tab(
            'doodle',
            const Icon(Icons.brush_rounded, size: 22, color: Color(0xFFFF6FAE)),
          ),
        ],
      ),
    );
  }
}

class _DiscArt extends CustomPainter {
  const _DiscArt();

  @override
  void paint(Canvas canvas, Size size) => paintCheckersDisc(
    canvas,
    size.center(Offset.zero),
    size.width * 0.44,
    finish: checkersFinish('classic', CheckersSide.dark),
  );

  @override
  bool shouldRepaint(covariant _DiscArt old) => false;
}

/// The player at a glance: badge, rating, place, how they're doing lately.
class _MyRankCard extends StatelessWidget {
  const _MyRankCard({
    required this.game,
    required this.board,
    required this.record,
    required this.history,
    required this.friends,
  });

  final String game;
  final Leaderboard board;
  final PlayerRecord? record;
  final List<RatingStep> history;
  final bool friends;

  @override
  Widget build(BuildContext context) {
    final rating = board.myRating;
    final tier = RankTier.of(rating);
    final place = board.myPlace;
    final week = weekChange(history, DateTime.now());
    final line = ratingLine(history);
    final r = record;
    final form = history.reversed.take(6).toList();

    // Tapped: the player's stats as a hologram, in their tier's aura.
    return GestureDetector(
      onTap: () => showRankHologram(
        context,
        game: game,
        rating: rating,
        place: place,
        line: line,
      ),
      child: PopCard(
        borderRadius: 28,
        tint: tier.color,
        glow: tier.color,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Column(
                  children: [
                    TierEmblem(tier: tier, size: 82),
                    const SizedBox(height: 2),
                    Text(
                      tier.label.toUpperCase(),
                      style: AppTextStyles.body(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppColors.readable(tier.color),
                      ).copyWith(letterSpacing: 1.5),
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'YOUR RATING',
                              style: AppTextStyles.body(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textSecondary,
                              ).copyWith(letterSpacing: 1.2),
                            ),
                          ),
                          _InsightsHint(tier: tier),
                        ],
                      ),
                      CountUp(
                        rating,
                        style: AppTextStyles.display(fontSize: 40),
                      ),
                      if (week != 0) ...[
                        TrendChip(week),
                        const SizedBox(height: 6),
                      ],
                      _Where(board: board, friends: friends),
                    ],
                  ),
                ),
              ],
            ),
            if (place == null) ...[
              const SizedBox(height: AppSpacing.md),
              _Placement(games: board.myGames),
            ],
            if (line.length >= 3) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Text(
                    'Last ${history.length} games',
                    style: AppTextStyles.body(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  for (final s in form)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: _FormPip(s.change.delta),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              RatingSparkline(values: line, color: tier.color),
            ],
            if (r != null && r.games > 0) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  _MiniStat('${r.wins}', 'Wins', AppColors.success),
                  _MiniStat('${r.losses}', 'Losses', AppColors.error),
                  _MiniStat('${r.draws}', 'Draws', AppColors.sky),
                  _MiniStat('${r.best}', 'Best', AppColors.coinGold),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Insights": the card opens a hologram.
class _InsightsHint extends StatelessWidget {
  const _InsightsHint({required this.tier});

  final RankTier tier;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: tier.color.withValues(alpha: 0.14),
        border: Border.all(color: tier.color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 13,
            color: AppColors.readable(tier.color),
          ),
          const SizedBox(width: 4),
          Text(
            'Insights',
            style: AppTextStyles.body(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: AppColors.readable(tier.color),
            ),
          ),
        ],
      ),
    );
  }
}

class _Where extends StatelessWidget {
  const _Where({required this.board, required this.friends});

  final Leaderboard board;
  final bool friends;

  @override
  Widget build(BuildContext context) {
    final place = board.myPlace;
    final style = AppTextStyles.body(fontWeight: FontWeight.w800);
    if (place == null) {
      return Text(
        board.myGames == 0 ? 'Not ranked yet' : 'Getting placed',
        style: style.copyWith(color: AppColors.textSecondary),
      );
    }
    return Row(
      children: [
        if (medalFor(place) case final medal?) ...[
          Icon(Icons.emoji_events_rounded, size: 18, color: medal),
          const SizedBox(width: 4),
        ],
        Text(
          friends ? '#$place among friends' : '#$place in Utopia',
          style: style,
        ),
      ],
    );
  }
}

/// The first games, before a player has a place: a dot each.
class _Placement extends StatelessWidget {
  const _Placement({required this.games});

  final int games;

  @override
  Widget build(BuildContext context) {
    final left = (kGamesToRank - games).clamp(0, kGamesToRank);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black.withValues(alpha: 0.22),
      ),
      child: Row(
        children: [
          for (var i = 0; i < kGamesToRank; i++)
            Container(
              margin: const EdgeInsets.only(right: 6),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < games
                    ? AppColors.coinGold
                    : Colors.white.withValues(alpha: 0.12),
                border: Border.all(color: Colors.white24),
              ),
              child: i < games
                  ? const Icon(
                      Icons.check_rounded,
                      size: 12,
                      color: Colors.white,
                    )
                  : null,
            ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              games == 0
                  ? 'Play $kGamesToRank online games to get your place'
                  : '$left more ${left == 1 ? 'game' : 'games'} to get your place',
              style: AppTextStyles.body(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One recent game's change: green up, red down.
class _FormPip extends StatelessWidget {
  const _FormPip(this.delta);

  final int delta;

  @override
  Widget build(BuildContext context) {
    final color = delta > 0
        ? AppColors.success
        : delta < 0
        ? AppColors.error
        : AppColors.sky;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        delta > 0 ? '+$delta' : '$delta',
        style: AppTextStyles.body(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.value, this.label, this.color);

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.display(
              fontSize: 20,
              color: AppColors.readable(color),
            ),
          ),
          Text(
            label,
            style: AppTextStyles.body(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Everyone or friends only.
class _ScopeSwitch extends StatelessWidget {
  const _ScopeSwitch({required this.friends, required this.onChanged});

  final bool friends;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(bool value, IconData icon, String label) {
      final on = value == friends;
      return GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: on ? AppColors.accent : Colors.transparent,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: on ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTextStyles.body(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: on ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        color: Colors.black.withValues(alpha: 0.25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          tab(false, Icons.public_rounded, 'Everyone'),
          tab(true, Icons.people_rounded, 'Friends'),
        ],
      ),
    );
  }
}

class _NobodyYet extends StatelessWidget {
  const _NobodyYet({required this.game, required this.friends});

  final String game;
  final bool friends;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // The podium, waiting.
        Podium(top: const [], myId: null, onTap: (_) {}),
        const SizedBox(height: AppSpacing.md),
        PopCard(
          borderRadius: 22,
          depth: 3,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              GlossyBadge(
                icon: Icons.emoji_events_rounded,
                color: AppColors.coinGold,
                size: 48,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                friends
                    ? 'None of your friends are ranked yet'
                    : 'The podium is empty',
                textAlign: TextAlign.center,
                style: AppTextStyles.display(fontSize: 20),
              ),
              const SizedBox(height: 4),
              Text(
                game == 'doodle'
                    ? 'Play $kGamesToRank public games to the end to get on '
                          'the board. The top spot is waiting!'
                    : 'Play $kGamesToRank online games to get on the board. '
                          'The top spot is waiting!',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: game == 'doodle'
                    ? 'Play Guess My Doodle'
                    : 'Play ${_gameName(game).toLowerCase()} online',
                color: AppColors.success,
                onPressed: () => context.push(rankedGameRoute(game)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return PopCard(
      borderRadius: 22,
      depth: 3,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Text(
            "Couldn't load the rankings.",
            style: AppTextStyles.body(fontWeight: FontWeight.w800),
          ),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
