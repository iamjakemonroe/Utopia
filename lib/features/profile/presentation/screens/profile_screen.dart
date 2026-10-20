import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/audio/game_audio.dart';
import '../../../../core/profiles/profile_providers.dart';
import '../../../../core/profiles/profile_repository.dart';
import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/theme/utopia_themes.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/doodle_ink.dart';
import '../../../../core/widgets/coin_buddy.dart';
import '../../../../core/widgets/generated_avatar.dart';
import '../../../../core/widgets/pop_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/tilt_3d.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/widgets/utopia_icons.dart';
import '../../../../core/widgets/utopia_loader.dart';
import '../../../../core/widgets/utopia_toast.dart';
import '../../../../core/widgets/utopia_world.dart';
import '../../../auras/domain/aura.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../chess/domain/chess_types.dart';
import '../../../chess/presentation/widgets/chess_piece_art.dart';
import '../../../checkers/domain/checkers_engine.dart';
import '../../../checkers/presentation/widgets/checkers_disc.dart';
import '../../../chess/presentation/widgets/chess_piece_styles.dart';
import '../../../coins/presentation/providers/coin_balance_provider.dart';
import '../../../ludo/domain/ludo_engine.dart';
import '../../../ludo/presentation/controllers/ludo_match_controller.dart';
import '../../../ludo/presentation/widgets/ludo_pieces.dart';
import '../../../rankings/domain/ranking.dart';
import '../../../rankings/presentation/rankings_widgets.dart';
import '../../../store/domain/store_catalog.dart';
import '../../../store/presentation/coin_shop.dart';
import '../username_dialog.dart';
import '../../../../core/widgets/ambient_tick.dart';
import '../../../../core/layout/responsive.dart';
import '../../../../l10n/strings.dart';

final _myStatsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>(
      (ref, userId) => ref.watch(ludoRepositoryProvider).playerStats(userId),
    );

/// One finished game (chess, checkers or Ludo) from my side.
class _RecentGame {
  const _RecentGame({
    required this.game,
    this.ratingDelta,
    required this.endedAt,
    required this.won,
    required this.draw,
    required this.stake,
    required this.players,
    required this.opponents,
  });

  /// 'chess', 'checkers' or 'ludo'.
  final String game;

  /// How it moved my rating, when it was rated.
  final int? ratingDelta;
  final DateTime endedAt;
  final bool won;
  final bool draw;
  final int stake;
  final int players;
  final List<String> opponents;
}

final _recentGamesProvider = FutureProvider.autoDispose
    .family<List<_RecentGame>, String>((ref, me) async {
      final client = ref.watch(supabaseClientProvider);
      // Row-level security only returns games I played in.
      final chess = await client
          .from('matches')
          .select(
            'id, game, ended_at, created_at, stake, winner_id, result, player_white, player_black',
          )
          .eq('status', 'completed')
          .order('ended_at', ascending: false)
          .limit(8);
      final ludo = await client
          .from('ludo_matches')
          .select('ended_at, created_at, stake, winner_id, players')
          .eq('status', 'completed')
          .order('ended_at', ascending: false)
          .limit(8);

      // What each rated game did to my rating.
      final ids = [for (final row in chess) row['id'] as String];
      final changes = ids.isEmpty
          ? const <Map<String, dynamic>>[]
          : await client
                .from('rating_changes')
                .select('match_id, before, after')
                .eq('user_id', me)
                .inFilter('match_id', ids);
      final delta = {
        for (final c in changes)
          c['match_id'] as String:
              (c['after'] as num).toInt() - (c['before'] as num).toInt(),
      };

      DateTime when(Map row) =>
          DateTime.tryParse(
            (row['ended_at'] ?? row['created_at']) as String,
          )?.toLocal() ??
          DateTime.now();

      final games = <_RecentGame>[
        for (final row in chess)
          if (row['result'] != 'aborted')
            _RecentGame(
              game: row['game'] == 'checkers' ? 'checkers' : 'chess',
              ratingDelta: delta[row['id']],
              endedAt: when(row),
              won: row['winner_id'] == me,
              draw: row['winner_id'] == null,
              stake: (row['stake'] as num).toInt(),
              players: 2,
              opponents: [
                for (final id in [row['player_white'], row['player_black']])
                  if (id != null && id != me) id as String,
              ],
            ),
        for (final row in ludo)
          _RecentGame(
            game: 'ludo',
            endedAt: when(row),
            won: row['winner_id'] == me,
            draw: row['winner_id'] == null,
            stake: (row['stake'] as num).toInt(),
            players: (row['players'] as List).length,
            opponents: [
              for (final id in row['players'] as List)
                if (id != me) id as String,
            ],
          ),
      ]..sort((a, b) => b.endedAt.compareTo(a.endedAt));
      return games.take(6).toList();
    });

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _saving = false;

  Future<void> _openAvatarPicker(Map<String, dynamic>? profile) async {
    ref.read(gameAudioProvider).play(Sfx.drawer);
    final choice = await showModalBottomSheet<_AvatarChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _AvatarPickerSheet(
        currentKind: profile?['avatar_url'] == null
            ? (profile?['avatar_kind'] as String?)
            : null,
        currentSeed: (profile?['avatar_seed'] as num?)?.toInt(),
      ),
    );
    if (choice == null || !mounted) return;

    if (choice.kind == null) {
      await _uploadPhoto();
    } else {
      await _save(
        (repository, myId) => repository.useGeneratedAvatar(
          userId: myId,
          kind: choice.kind!,
          seed: choice.seed!,
        ),
      );
    }
  }

  Future<void> _uploadPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    final dot = picked.name.lastIndexOf('.');
    final ext = dot == -1 ? 'jpg' : picked.name.substring(dot + 1);

    await _save(
      (repository, myId) => repository.replaceAvatarPhoto(
        userId: myId,
        bytes: bytes,
        fileExtension: ext,
      ),
    );
  }

  Future<void> _save(
    Future<void> Function(ProfileRepository repository, String myId) action,
  ) async {
    final myId = ref.read(currentUserProvider)?.id;
    if (myId == null) return;

    setState(() => _saving = true);
    try {
      await action(ref.read(profileRepositoryProvider), myId);
      ref.invalidate(profileByIdProvider(myId));
      ref.read(gameAudioProvider).play(Sfx.reaction);
    } catch (e) {
      if (mounted) {
        showUtopiaToast(
          context,
          friendlyError(e, fallback: strings.profileCouldnTChangeYourAvatar),
          kind: ToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(currentUserProvider)?.id;
    final profile = myId == null
        ? null
        : ref.watch(profileByIdProvider(myId)).valueOrNull;
    final name = myId == null
        ? strings.profileYou
        : profileDisplayName(profile, myId);
    final username = profile?['username'] as String?;
    final isGuest = ref.watch(isAnonymousProvider);
    final stats = myId == null
        ? null
        : ref.watch(_myStatsProvider(myId)).valueOrNull;
    final recent = myId == null ? null : ref.watch(_recentGamesProvider(myId));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: strings.profileSettings,
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: DoodleInk(
        child: AppBackground(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _Header(
                profile: profile,
                name: name,
                saving: _saving,
                onAvatarTap: () => _openAvatarPicker(profile),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: context.readablePadding(min: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tap your name to change it.
                    GestureDetector(
                      onTap: () => editProfileNames(context, ref),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.display(fontSize: 26),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accent.withValues(alpha: 0.35),
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: _UsernameChip(
                        username: username,
                        onTap: () => editProfileNames(context, ref),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _StatusBadge(
                          isGuest: isGuest,
                          since: DateTime.tryParse(
                            stats?['member_since'] as String? ?? '',
                          ),
                        ),
                        _BestRank(stats: stats),
                      ],
                    ),
                    if (isGuest) ...[
                      const SizedBox(height: AppSpacing.md),
                      PrimaryButton(
                        label: strings.profileSaveYourAccount,
                        color: AppColors.success,
                        onPressed: () => context.push('/auth/link'),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    const _CoinsCard(),
                    const SizedBox(height: AppSpacing.lg),
                    _StatsRow(stats: stats),
                    const SizedBox(height: AppSpacing.lg),
                    _SectionTitle(
                      icon: Icons.auto_awesome_rounded,
                      text: strings.profileCollection,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _Collection(profile: profile),
                    const SizedBox(height: AppSpacing.lg),
                    _SectionTitle(
                      icon: Icons.history_rounded,
                      text: strings.profileRecentGames,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _RecentGames(games: recent),
                    const SizedBox(height: AppSpacing.lg),
                    const _CompanionCard(),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.profile,
    required this.name,
    required this.saving,
    required this.onAvatarTap,
  });

  final Map<String, dynamic>? profile;
  final String name;
  final bool saving;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    // The avatar overlaps the bottom of the sky. The overlap is part of
    // this box (not hanging outside it), or taps on the avatar's lower half
    // and its camera badge would never land.
    const overlap = 56.0;
    return SizedBox(
      height: 170 + top + overlap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 170 + top,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(36),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const UtopiaWorld(),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.background.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: saving ? null : onAvatarTap,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            AppColors.goldBorder,
                            AppColors.goldBorderBright,
                            AppColors.goldBorder,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.glowRing.withValues(alpha: 0.6),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                      child: SizedBox.square(
                        dimension: 112,
                        child: saving
                            ? DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.surface,
                                ),
                                child: const Center(
                                  child: UtopiaLoader(size: 44, bubbles: false),
                                ),
                              )
                            : UserAvatar.fromProfile(
                                profile,
                                fallbackInitial: name,
                                radius: 56,
                              ),
                      ),
                    ),
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: const Alignment(-0.3, -0.4),
                            colors: [
                              Color.lerp(AppColors.accent, Colors.white, 0.4)!,
                              AppColors.accent,
                            ],
                          ),
                          border: Border.all(
                            color: AppColors.background,
                            width: 3,
                          ),
                        ),
                        child: const Icon(
                          Icons.photo_camera_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
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

class _UsernameChip extends StatelessWidget {
  const _UsernameChip({required this.username, required this.onTap});

  final String? username;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final has = username != null;
    return Material(
      color: Colors.black.withValues(alpha: 0.28),
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                !has ? strings.profilePickAUsername : '@$username',
                style: AppTextStyles.body(
                  fontWeight: FontWeight.w700,
                  color: has
                      ? AppColors.textSecondary
                      : AppColors.accentSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                has ? Icons.edit_rounded : Icons.add_circle_rounded,
                size: 16,
                color: has
                    ? AppColors.textSecondary
                    : AppColors.accentSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isGuest, required this.since});

  final bool isGuest;
  final DateTime? since;

  static final _months = [
    'Jan',
    strings.profileFeb,
    strings.profileMar,
    strings.profileApr,
    strings.profileMay,
    strings.profileJun,
    strings.profileJul,
    strings.profileAug,
    strings.profileSep,
    strings.profileOct,
    strings.profileNov,
    strings.profileDec,
  ];

  @override
  Widget build(BuildContext context) {
    final color = isGuest ? const Color(0xFFFFB020) : AppColors.mint;
    final ink = AppColors.readable(color);
    final text = isGuest
        ? strings.profileGuest
        : since == null
        ? strings.profileMember
        : strings.profileMemberSince(_months[since!.month - 1], since!.year);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isGuest ? Icons.person_outline_rounded : Icons.verified_rounded,
            size: 15,
            color: ink,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: AppTextStyles.body(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.accentSecondary),
        const SizedBox(width: 8),
        Text(text, style: AppTextStyles.display(fontSize: 18)),
      ],
    );
  }
}

class _CoinsCard extends ConsumerWidget {
  const _CoinsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(coinBalanceProvider).valueOrNull;
    return PopCard(
      borderRadius: 24,
      tint: AppColors.coinGold,
      glow: AppColors.coinGold,
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      child: Row(
        children: [
          const CoinIcon(size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  balance == null ? '...' : formatCoins(balance),
                  style: AppTextStyles.display(
                    fontSize: 26,
                    color: AppColors.readable(AppColors.coinGoldBright),
                  ),
                ),
                Text(
                  strings.profileCoins,
                  style: AppTextStyles.body(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 128,
            child: PrimaryButton(
              label: strings.profileGetCoins,
              color: AppColors.success,
              onPressed: () => showCoinShop(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final Map<String, dynamic>? stats;

  int _n(String key) => (stats?[key] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final played =
        _n('ludo_played') + _n('chess_played') + _n('checkers_played');
    final won = _n('ludo_won') + _n('chess_won') + _n('checkers_won');
    final rate = played == 0 ? 0 : (won * 100 / played).round();
    return Column(
      children: [
        Row(
          children: [
            _StatTile(
              icon: Icons.sports_esports_rounded,
              color: AppColors.sky,
              value: '$played',
              label: strings.profilePlayed,
            ),
            const SizedBox(width: AppSpacing.sm),
            _StatTile(
              icon: Icons.emoji_events_rounded,
              color: AppColors.coinGold,
              value: '$won',
              label: strings.profileWon,
            ),
            const SizedBox(width: AppSpacing.sm),
            _StatTile(
              icon: Icons.trending_up_rounded,
              color: AppColors.mint,
              value: '$rate%',
              label: strings.profileWinRate,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _GameSplit(
          ludoPlayed: _n('ludo_played'),
          ludoWon: _n('ludo_won'),
          chessPlayed: _n('chess_played'),
          chessWon: _n('chess_won'),
          checkersPlayed: _n('checkers_played'),
          checkersWon: _n('checkers_won'),
        ),
        const SizedBox(height: AppSpacing.lg),
        _SectionTitle(
          icon: Icons.leaderboard_rounded,
          text: strings.profileRanks,
        ),
        const SizedBox(height: AppSpacing.sm),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, game) in rankedGames.indexed) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                _RatingTile(
                  game: game,
                  rating: (stats?['${game}_rating'] as num?)?.toInt(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: PopCard(
        borderRadius: 20,
        depth: 3,
        borderWidth: 1.5,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            GlossyBadge(icon: icon, color: color, size: 34),
            const SizedBox(height: 6),
            Text(value, style: AppTextStyles.display(fontSize: 22)),
            Text(
              label,
              style: AppTextStyles.body(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wins out of games played, per game, as two little bars.
class _GameSplit extends StatelessWidget {
  const _GameSplit({
    required this.ludoPlayed,
    required this.ludoWon,
    required this.chessPlayed,
    required this.chessWon,
    required this.checkersPlayed,
    required this.checkersWon,
  });

  final int ludoPlayed;
  final int ludoWon;
  final int chessPlayed;
  final int chessWon;
  final int checkersPlayed;
  final int checkersWon;

  @override
  Widget build(BuildContext context) {
    Widget bar(Widget art, int won, int played, Color color) {
      final f = played == 0 ? 0.0 : won / played;
      return Row(
        children: [
          SizedBox.square(dimension: 28, child: Center(child: art)),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  Container(
                    height: 10,
                    color: Colors.black.withValues(alpha: 0.3),
                  ),
                  FractionallySizedBox(
                    widthFactor: f,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color.lerp(color, Colors.white, 0.3)!,
                            color,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 56,
            child: Text(
              '$won / $played',
              textAlign: TextAlign.right,
              style: AppTextStyles.body(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      );
    }

    return PopCard(
      borderRadius: 20,
      depth: 3,
      borderWidth: 1.5,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        children: [
          bar(
            const _LudoTokenArt(
              setId: 'classic',
              color: LudoColor.green,
              size: 24,
            ),
            ludoWon,
            ludoPlayed,
            AppColors.mint,
          ),
          const SizedBox(height: 10),
          bar(
            ChessPieceArt(
              type: PieceType.knight,
              finish: ChessPieceStyle.byId('classic').white,
              size: 26,
            ),
            chessWon,
            chessPlayed,
            AppColors.accent,
          ),
          const SizedBox(height: 10),
          bar(
            const SizedBox.square(
              dimension: 26,
              child: CustomPaint(painter: _CheckersDiscArt()),
            ),
            checkersWon,
            checkersPlayed,
            AppColors.coral,
          ),
        ],
      ),
    );
  }
}

class _CheckersDiscArt extends CustomPainter {
  const _CheckersDiscArt();

  @override
  void paint(Canvas canvas, Size size) => paintCheckersDisc(
    canvas,
    size.center(Offset.zero),
    size.width * 0.42,
    finish: checkersFinish('classic', CheckersSide.dark),
  );

  @override
  bool shouldRepaint(covariant _CheckersDiscArt old) => false;
}

/// A game's rank: its tier badge and rating; tap for the rankings.
class _RatingTile extends StatelessWidget {
  const _RatingTile({required this.game, required this.rating});

  final String game;

  /// Null until they've played a rated game.
  final int? rating;

  @override
  Widget build(BuildContext context) {
    final r = rating;
    final tier = RankTier.of(r ?? 1000);
    return Expanded(
      child: GestureDetector(
        onTap: () => context.push('/rankings?game=$game'),
        child: PopCard(
          borderRadius: 20,
          depth: 3,
          borderWidth: 1.5,
          tint: r == null ? null : tier.color,
          padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
          child: Column(
            children: [
              TierEmblem(tier: tier, size: 44, dim: r == null),
              const SizedBox(height: 6),
              Text(
                rankedGameName(game),
                style: AppTextStyles.body(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                r == null ? strings.profileUnrated : '$r',
                style: AppTextStyles.display(fontSize: r == null ? 15 : 20),
              ),
              Text(
                r == null ? strings.profilePlayOnline : tier.label,
                style: AppTextStyles.body(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: r == null
                      ? AppColors.textSecondary
                      : AppColors.readable(tier.color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Their best rank anywhere, by their name: "Gold in Chess".
class _BestRank extends StatelessWidget {
  const _BestRank({required this.stats});

  final Map<String, dynamic>? stats;

  @override
  Widget build(BuildContext context) {
    String? best;
    var top = 0;
    for (final game in rankedGames) {
      final r = (stats?['${game}_rating'] as num?)?.toInt();
      if (r != null && r > top) {
        top = r;
        best = game;
      }
    }
    if (best == null) return const SizedBox.shrink();
    final tier = RankTier.of(top);
    return GestureDetector(
      onTap: () => context.push('/rankings?game=$best'),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 3, 10, 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: tier.color.withValues(alpha: 0.15),
          border: Border.all(color: tier.color.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TierEmblem(tier: tier, size: 20),
            const SizedBox(width: 5),
            Text(
              '${tier.label} in ${rankedGameName(best)}',
              style: AppTextStyles.body(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.readable(tier.color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Collection extends ConsumerWidget {
  const _Collection({required this.profile});

  final Map<String, dynamic>? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeControllerProvider);
    final world = UtopiaThemes.active;
    final ludoId = pieceSetFor(profile);
    final chessId = profile?['equipped_chess_pieces'] as String? ?? 'classic';
    String nameOf(List<StoreItem> items, String id) =>
        items.where((i) => i.id == id).firstOrNull?.name ??
        strings.profileClassic;

    final aura = Aura.byId(activeAura(profile));
    final worldTile = _CollectionTile(
      label: world.name,
      onTap: () => context.push('/collection'),
      art: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.4),
            colors: [
              Color.lerp(world.accent, Colors.white, 0.45)!,
              world.accent,
            ],
          ),
          border: Border.all(color: Colors.white70, width: 2),
        ),
        child: const Icon(Icons.public_rounded, color: Colors.white),
      ),
    );
    final auraTile = _CollectionTile(
      label: aura?.name ?? strings.profileNoAura,
      onTap: () => context.push('/store?tab=auras'),
      art: aura == null
          ? Icon(
              Icons.auto_awesome_rounded,
              size: 34,
              color: AppColors.textSecondary,
            )
          : UserAvatar.fromProfile(profile, fallbackInitial: '?', radius: 18),
    );
    final ludoTile = _CollectionTile(
      label: nameOf(StoreCatalog.ludoPieceSets, ludoId),
      onTap: () => context.push('/store?tab=ludo'),
      art: _LudoTokenArt(setId: ludoId, color: LudoColor.red, size: 40),
    );
    final chessTile = _CollectionTile(
      label: nameOf(StoreCatalog.chessPieceSets, chessId),
      onTap: () => context.push('/store?tab=chess'),
      art: ChessPieceArt(
        type: PieceType.queen,
        finish: ChessPieceStyle.byId(chessId).white,
        size: 48,
        character: ChessPieceStyle.byId(chessId).character,
        mood: PieceMood.happy,
      ),
    );

    return Column(
      children: [
        Row(
          children: [
            worldTile,
            const SizedBox(width: AppSpacing.sm),
            auraTile,
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            ludoTile,
            const SizedBox(width: AppSpacing.sm),
            chessTile,
          ],
        ),
      ],
    );
  }
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({
    required this.label,
    required this.art,
    required this.onTap,
  });

  final String label;
  final Widget art;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: PopCard(
          borderRadius: 20,
          depth: 3,
          borderWidth: 1.5,
          padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
          child: Column(
            children: [
              SizedBox(height: 52, child: Center(child: art)),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single idle Ludo token from a piece set.
class _LudoTokenArt extends StatefulWidget {
  const _LudoTokenArt({
    required this.setId,
    required this.color,
    required this.size,
  });

  final String setId;
  final LudoColor color;
  final double size;

  @override
  State<_LudoTokenArt> createState() => _LudoTokenArtState();
}

class _LudoTokenArtState extends State<_LudoTokenArt>
    with SingleTickerProviderStateMixin {
  final _t = ValueNotifier<double>(0);
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    // Started here: a lazy field would only be created (and started)
    // on first use, which for a ticker is never.
    _ticker = createTicker(
      ambientTick((e) => _t.value = e.inMicroseconds / 1e6),
    )..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size * LudoTokenPainter.aspect,
      child: ValueListenableBuilder<double>(
        valueListenable: _t,
        builder: (context, t, _) => CustomPaint(
          painter: LudoTokenPainter(
            setId: widget.setId,
            color: widget.color,
            t: t,
          ),
        ),
      ),
    );
  }
}

class _RecentGames extends ConsumerWidget {
  const _RecentGames({required this.games});

  final AsyncValue<List<_RecentGame>>? games;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = games?.valueOrNull;
    if (games == null || games!.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Center(child: UtopiaLoader(size: 40, bubbles: false)),
      );
    }
    if (list == null || list.isEmpty) {
      return PopCard(
        borderRadius: 20,
        depth: 3,
        borderWidth: 1.5,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            const CoinBuddy(mood: BuddyMood.thinking, size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                strings.profileNoGamesYetYourFirst,
                style: AppTextStyles.body(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }
    return PopCard(
      borderRadius: 20,
      depth: 3,
      borderWidth: 1.5,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (final (i, g) in list.indexed) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 56,
                color: AppColors.glowRing.withValues(alpha: 0.2),
              ),
            _RecentRow(game: g),
          ],
        ],
      ),
    );
  }
}

class _RecentRow extends ConsumerWidget {
  const _RecentRow({required this.game});

  final _RecentGame game;

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'now';
    if (d.inHours < 1) return '${d.inMinutes}m';
    if (d.inDays < 1) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${(d.inDays / 7).floor()}w';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opponent = game.opponents.isEmpty ? null : game.opponents.first;
    final profile = opponent == null
        ? null
        : ref.watch(profileByIdProvider(opponent)).valueOrNull;
    final vs = opponent == null
        ? ''
        : game.players > 2
        ? '${game.players} players'
        : 'vs ${profileDisplayName(profile, opponent)}';
    final (label, color) = game.draw
        ? (strings.profileDraw, AppColors.textSecondary)
        : game.won
        ? (strings.profileWon, AppColors.success)
        : (strings.profileLost, AppColors.error);
    // There's no house cut: the winner takes the whole pot.
    final prize = game.players * game.stake;
    final delta = game.ratingDelta;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 34,
            child: Center(
              child: switch (game.game) {
                'chess' => ChessPieceArt(
                  type: PieceType.knight,
                  finish: ChessPieceStyle.byId('classic').white,
                  size: 32,
                ),
                'checkers' => const SizedBox.square(
                  dimension: 28,
                  child: CustomPaint(painter: _CheckersDiscArt()),
                ),
                _ => const _LudoTokenArt(
                  setId: 'classic',
                  color: LudoColor.yellow,
                  size: 24,
                ),
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.body(
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                    if (delta != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color:
                              (delta >= 0 ? AppColors.success : AppColors.error)
                                  .withValues(alpha: 0.18),
                        ),
                        child: Text(
                          '${delta >= 0 ? '+' : ''}$delta rating',
                          style: AppTextStyles.body(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: delta >= 0
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  vs,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (game.stake > 0 && !game.draw)
            CoinAmount(
              game.won ? prize : game.stake,
              prefix: game.won ? '+' : '-',
              size: 13,
              color: game.won
                  ? AppColors.readable(AppColors.success)
                  : AppColors.textSecondary,
            ),
          const SizedBox(width: 10),
          Text(
            _ago(game.endedAt),
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

class _CompanionCard extends StatelessWidget {
  const _CompanionCard();

  @override
  Widget build(BuildContext context) {
    return PopCard(
      borderRadius: 26,
      tint: AppColors.accent,
      glow: AppColors.accent,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const Tilt3D(
            child: AmbientTilt3D(
              child: CoinBuddy(mood: BuddyMood.happy, size: 96),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.profileChip,
                  style: AppTextStyles.display(fontSize: 20),
                ),
                const SizedBox(height: 2),
                Text(
                  strings.profileYourCompanionInEveryWorld,
                  style: AppTextStyles.body(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What the picker sheet returns: a null [kind] means "upload a photo".
class _AvatarChoice {
  const _AvatarChoice.photo() : kind = null, seed = null;
  const _AvatarChoice.generated(String this.kind, int this.seed);

  final String? kind;
  final int? seed;
}

/// Avatars by kind, picked with icon tabs, plus "upload your own".
class _AvatarPickerSheet extends StatefulWidget {
  const _AvatarPickerSheet({
    required this.currentKind,
    required this.currentSeed,
  });

  final String? currentKind;
  final int? currentSeed;

  @override
  State<_AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<_AvatarPickerSheet> {
  static const _kinds = [
    ('plant', Icons.eco_rounded, Color(0xFF3DDC97)),
    ('animal', Icons.pets_rounded, Color(0xFFFF8A3D)),
    ('human', Icons.face_rounded, Color(0xFF4DA3FF)),
  ];

  late String _kind = _kinds.any((k) => k.$1 == widget.currentKind)
      ? widget.currentKind!
      : _kinds.first.$1;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.surfaceElevated, AppColors.background],
        ),
        border: sheetBorder(AppColors.goldBorder),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
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
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  for (final (kind, icon, color) in _kinds) ...[
                    Expanded(
                      child: _KindTab(
                        icon: icon,
                        color: color,
                        selected: kind == _kind,
                        onTap: () => setState(() => _kind = kind),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: _KindTab(
                      icon: Icons.add_a_photo_rounded,
                      color: AppColors.coral,
                      selected: false,
                      onTap: () => Navigator.of(
                        context,
                      ).pop(const _AvatarChoice.photo()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: GridView.count(
                  key: ValueKey(_kind),
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  children: [
                    for (var seed = 0; seed < kAvatarChoicesPerKind; seed++)
                      _AvatarOption(
                        kind: _kind,
                        seed: seed,
                        index: seed,
                        selected:
                            _kind == widget.currentKind &&
                            seed == widget.currentSeed,
                        onTap: () => Navigator.of(
                          context,
                        ).pop(_AvatarChoice.generated(_kind, seed)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KindTab extends StatelessWidget {
  const _KindTab({
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1 : 0.9,
        duration: const Duration(milliseconds: 380),
        curve: Curves.elasticOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: selected
                  ? [Color.lerp(color, Colors.white, 0.3)!, color]
                  : [AppColors.surfaceElevated, AppColors.surface],
            ),
            border: Border.all(
              color: selected ? Colors.white70 : color.withValues(alpha: 0.4),
              width: selected ? 2 : 1.2,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Icon(icon, color: selected ? Colors.white : color, size: 28),
        ),
      ),
    );
  }
}

class _AvatarOption extends StatelessWidget {
  const _AvatarOption({
    required this.kind,
    required this.seed,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final String kind;
  final int seed;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + index * 50),
      curve: Curves.elasticOut,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? AppColors.goldBorderBright : Colors.transparent,
              width: 3,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.goldBorderBright.withValues(alpha: 0.5),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: LayoutBuilder(
            builder: (context, c) =>
                GeneratedAvatar(kind: kind, seed: seed, size: c.maxWidth),
          ),
        ),
      ),
    );
  }
}
