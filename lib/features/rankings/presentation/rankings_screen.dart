import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/profiles/profile_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/pop_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/utopia_icons.dart';
import '../../../core/widgets/utopia_loader.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../data/rankings_repository.dart';
import '../domain/ranking.dart';

/// The chess and checkers boards: the player's rating and tier, and the
/// top players, worldwide or among friends. Ratings come from online games.
class RankingsScreen extends StatelessWidget {
  const RankingsScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: rankedGames.length,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rankings'),
          bottom: TabBar(
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.goldBorder,
            indicatorWeight: 3,
            labelStyle: AppTextStyles.body(
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
            tabs: const [
              Tab(icon: Icon(Icons.extension_rounded), text: 'Chess'),
              Tab(icon: Icon(Icons.blur_circular_rounded), text: 'Checkers'),
            ],
          ),
        ),
        body: const AppBackground(
          child: TabBarView(
            children: [
              _Board(game: 'chess'),
              _Board(game: 'checkers'),
            ],
          ),
        ),
      ),
    );
  }
}

class _Board extends ConsumerStatefulWidget {
  const _Board({required this.game});

  final String game;

  @override
  ConsumerState<_Board> createState() => _BoardState();
}

class _BoardState extends ConsumerState<_Board>
    with AutomaticKeepAliveClientMixin {
  bool _friends = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final key = (widget.game, _friends);
    final board = ref.watch(leaderboardProvider(key));
    final me = ref.watch(currentUserProvider)?.id;
    final isGuest = ref.watch(isAnonymousProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(leaderboardProvider(key).future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          switch (board) {
            AsyncData(:final value) => _MyStanding(
              board: value,
              friends: _friends,
            ),
            AsyncError() => _LoadError(
              onRetry: () => ref.invalidate(leaderboardProvider(key)),
            ),
            _ => const SizedBox(
              height: 140,
              child: Center(child: UtopiaLoader(size: 48)),
            ),
          },
          const SizedBox(height: AppSpacing.md),
          if (!isGuest) ...[
            _ScopeSwitch(
              friends: _friends,
              onChanged: (v) => setState(() => _friends = v),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (board.valueOrNull case final value?)
            if (value.top.isEmpty)
              _NobodyYet(game: widget.game, friends: _friends)
            else
              for (final entry in value.top)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _Row(entry: entry, me: entry.userId == me),
                ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Ratings come from online games. Everyone starts at 1000, and '
            "you're ranked after $kGamesToRank games.",
            textAlign: TextAlign.center,
            style: AppTextStyles.body(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The player's rating, tier and place, and how far it is to the next tier.
class _MyStanding extends StatelessWidget {
  const _MyStanding({required this.board, required this.friends});

  final Leaderboard board;
  final bool friends;

  @override
  Widget build(BuildContext context) {
    final rating = board.myRating;
    final tier = RankTier.of(rating);
    final next = tier.next;
    final place = board.myPlace;
    final where = place == null
        ? board.myGames == 0
              ? 'Play an online game to get started'
              : 'Play ${board.gamesToGo} more '
                    '${board.gamesToGo == 1 ? 'game' : 'games'} to get ranked'
        : friends
        ? '#$place among your friends'
        : '#$place in Utopia';
    // Bronze starts at 0, but nobody's down there: fill from 900.
    final low = tier == RankTier.bronze ? 900 : tier.from;

    return PopCard(
      borderRadius: 26,
      tint: tier.color,
      glow: tier.color,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Column(
            children: [
              GlossyBadge(
                icon: Icons.military_tech_rounded,
                color: tier.color,
                size: 62,
              ),
              const SizedBox(height: 4),
              Text(
                tier.label,
                style: AppTextStyles.body(
                  fontWeight: FontWeight.w800,
                  color: tier.color,
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your rating',
                  style: AppTextStyles.body(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text('$rating', style: AppTextStyles.display(fontSize: 34)),
                Text(
                  where,
                  style: AppTextStyles.body(fontWeight: FontWeight.w700),
                ),
                if (next != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ((rating - low) / (next.from - low)).clamp(
                        0.0,
                        1.0,
                      ),
                      minHeight: 8,
                      color: next.color,
                      backgroundColor: Colors.black.withValues(alpha: 0.3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${next.from - rating} to ${next.label}',
                    style: AppTextStyles.body(
                      fontSize: 12,
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

/// Everyone or friends only.
class _ScopeSwitch extends StatelessWidget {
  const _ScopeSwitch({required this.friends, required this.onChanged});

  final bool friends;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(bool value, IconData icon, String label) {
      final on = value == friends;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: on ? AppColors.accent : Colors.transparent,
              boxShadow: on
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.4),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: on ? Colors.white : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppTextStyles.body(
                    fontWeight: FontWeight.w800,
                    color: on ? Colors.white : AppColors.textSecondary,
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
        borderRadius: BorderRadius.circular(20),
        color: Colors.black.withValues(alpha: 0.25),
      ),
      child: Row(
        children: [
          tab(false, Icons.public_rounded, 'Everyone'),
          tab(true, Icons.people_rounded, 'Friends'),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry, required this.me});

  final BoardEntry entry;
  final bool me;

  @override
  Widget build(BuildContext context) {
    final tier = RankTier.of(entry.rating);
    final name = me ? 'You' : profileDisplayName(entry.profile, entry.userId);
    return PopCard(
      borderRadius: 18,
      depth: 2,
      borderWidth: me ? 2 : 1.2,
      tint: me ? AppColors.accent : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 38, child: _Place(entry.place)),
          const SizedBox(width: 6),
          UserAvatar.fromProfile(
            entry.profile,
            fallbackInitial: name,
            radius: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(fontWeight: FontWeight.w800),
                ),
                Text(
                  '${tier.label} · ${entry.games} games',
                  style: AppTextStyles.body(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${entry.rating}',
            style: AppTextStyles.display(fontSize: 20, color: tier.color),
          ),
        ],
      ),
    );
  }
}

/// 1, 2 and 3 get medals; the rest a number.
class _Place extends StatelessWidget {
  const _Place(this.place);

  final int place;

  @override
  Widget build(BuildContext context) {
    final medal = switch (place) {
      1 => AppColors.coinGold,
      2 => RankTier.silver.color,
      3 => RankTier.bronze.color,
      _ => null,
    };
    if (medal == null) {
      return Text(
        '#$place',
        textAlign: TextAlign.center,
        style: AppTextStyles.body(
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
        ),
      );
    }
    return Center(
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.4),
            colors: [Color.lerp(medal, Colors.white, 0.5)!, medal],
          ),
          border: Border.all(color: Colors.white70, width: 1.5),
        ),
        child: Text(
          '$place',
          style: AppTextStyles.body(
            fontWeight: FontWeight.w900,
            color: AppColors.faceInk,
          ),
        ),
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
    return PopCard(
      borderRadius: 22,
      depth: 3,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          GlossyBadge(
            icon: Icons.emoji_events_rounded,
            color: AppColors.coinGold,
            size: 52,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            friends
                ? 'None of your friends are ranked yet'
                : 'Nobody is ranked yet',
            textAlign: TextAlign.center,
            style: AppTextStyles.display(fontSize: 20),
          ),
          const SizedBox(height: 4),
          Text(
            'Play $kGamesToRank online games to get on the board. '
            'The top spot is waiting!',
            textAlign: TextAlign.center,
            style: AppTextStyles.body(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: 'Play online',
            color: AppColors.success,
            onPressed: () => context.push('/$game'),
          ),
        ],
      ),
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
