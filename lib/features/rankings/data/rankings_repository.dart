import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/rank_insights.dart';
import '../domain/ranking.dart';

/// Ratings for online chess and checkers. The server rates each finished
/// game; the app only reads.
class RankingsRepository {
  RankingsRepository(this._client);

  final SupabaseClient _client;

  /// A page of [game]'s board (everyone, or the player and their
  /// friends): [limit] places from [offset], of the top 100.
  Future<Leaderboard> leaderboard(
    String game, {
    bool friends = false,
    int offset = 0,
    int limit = kBoardPage,
  }) async {
    final data = await _client.rpc(
      'get_leaderboard',
      params: {
        'p_game': game,
        'p_friends': friends,
        'p_offset': offset,
        'p_limit': limit,
      },
    );
    return Leaderboard.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Everything worth knowing from the player's games in [game] (or
  /// [user]'s, someone else's, unless they hide them).
  Future<RankInsights> insights(String game, {String? user}) async {
    final data = await _client.rpc(
      'get_rank_insights',
      params: {'p_game': game, 'p_user': ?user},
    );
    return RankInsights.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Whether others can open the player's hologram (Settings).
  Future<void> setShowStats(bool show) =>
      _client.rpc('set_show_stats', params: {'p_show': show});

  /// The player's record in [game], or null before their first rated game.
  Future<PlayerRecord?> record(String game) async {
    final me = _client.auth.currentUser?.id;
    if (me == null) return null;
    final row = await _client
        .from('player_ratings')
        .select('rating, best, games, wins, losses, draws')
        .eq('user_id', me)
        .eq('game', game)
        .maybeSingle();
    return row == null ? null : PlayerRecord.fromJson(row);
  }

  /// The player's last [limit] rated games in [game], oldest first.
  Future<List<RatingStep>> history(String game, {int limit = 30}) async {
    final me = _client.auth.currentUser?.id;
    if (me == null) return const [];
    final rows = await _client
        .from('rating_changes')
        .select('before, after, created_at')
        .eq('user_id', me)
        .eq('game', game)
        .order('created_at', ascending: false)
        .limit(limit);
    return [
      for (final r in rows.reversed)
        RatingStep(
          RatingChange(
            (r['before'] as num).toInt(),
            (r['after'] as num).toInt(),
          ),
          DateTime.tryParse(r['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
        ),
    ];
  }

  /// How [matchId] moved the player's rating, or null if it wasn't rated
  /// (called off, too short, or a fourth game that day with the same
  /// player).
  Future<RatingChange?> change(String matchId) async {
    final me = _client.auth.currentUser?.id;
    if (me == null) return null;
    final row = await _client
        .from('rating_changes')
        .select('before, after')
        .eq('match_id', matchId)
        .eq('user_id', me)
        .maybeSingle();
    if (row == null) return null;
    return RatingChange(
      (row['before'] as num).toInt(),
      (row['after'] as num).toInt(),
    );
  }
}

final rankingsRepositoryProvider = Provider<RankingsRepository>(
  (ref) => RankingsRepository(ref.watch(supabaseClientProvider)),
);

/// A board by (game, friends only).
/// Places a page of the board brings.
const kBoardPage = 25;

/// The places after a board's first page, brought in as the player scrolls
/// down to them.
class BoardMore {
  const BoardMore({
    this.entries = const [],
    this.hasMore,
    this.loading = false,
  });

  final List<BoardEntry> entries;

  /// Whether there are more after these (null until a page is in: the
  /// first page says).
  final bool? hasMore;
  final bool loading;
}

class BoardMoreController extends StateNotifier<BoardMore> {
  BoardMoreController(this._repo, this._key) : super(const BoardMore());

  /// Read only when a page is brought in.
  final RankingsRepository Function() _repo;
  final (String, bool) _key;

  /// Brings the next page after the first one ([firstPage] places) and
  /// any already brought in, if there's one ([firstMore] says, until a
  /// page of its own has) and none is on its way. Counted here, not from
  /// what's on screen, which can be a page behind.
  Future<void> loadNext({
    required int firstPage,
    required bool firstMore,
  }) async {
    final more = state.hasMore ?? firstMore;
    final offset = firstPage + state.entries.length;
    if (state.loading || !more || offset >= 100) return;
    state = BoardMore(entries: state.entries, hasMore: more, loading: true);
    try {
      final page = await _repo().leaderboard(
        _key.$1,
        friends: _key.$2,
        offset: offset,
      );
      if (!mounted) return;
      // Places already in (the board moved under them) aren't doubled.
      final seen = {for (final e in state.entries) e.userId};
      state = BoardMore(
        entries: [
          ...state.entries,
          ...page.top.where((e) => !seen.contains(e.userId)),
        ],
        hasMore: page.hasMore,
      );
    } catch (_) {
      // Offline: scrolling down again tries again.
      if (mounted) {
        state = BoardMore(entries: state.entries, hasMore: state.hasMore);
      }
    }
  }
}

final boardMoreProvider = StateNotifierProvider.autoDispose
    .family<BoardMoreController, BoardMore, (String, bool)>(
      (ref, key) =>
          BoardMoreController(() => ref.read(rankingsRepositoryProvider), key),
    );

/// A board's first page (the rest comes as the player scrolls:
/// [boardMoreProvider]).
final leaderboardProvider = FutureProvider.autoDispose
    .family<Leaderboard, (String, bool)>(
      (ref, key) => ref
          .watch(rankingsRepositoryProvider)
          .leaderboard(key.$1, friends: key.$2),
    );

/// The player's record in a game.
final myRecordProvider = FutureProvider.autoDispose
    .family<PlayerRecord?, String>(
      (ref, game) => ref.watch(rankingsRepositoryProvider).record(game),
    );

/// The player's recent rated games in a game, oldest first.
final ratingHistoryProvider = FutureProvider.autoDispose
    .family<List<RatingStep>, String>(
      (ref, game) => ref.watch(rankingsRepositoryProvider).history(game),
    );

/// The player's rating change from one match.
final ratingChangeProvider = FutureProvider.autoDispose
    .family<RatingChange?, String>(
      (ref, matchId) => ref.watch(rankingsRepositoryProvider).change(matchId),
    );

/// The player's insights in a game, for the hologram.
/// Whose insights: the player's own ([user] null), or someone else's.
typedef InsightsKey = ({String game, String? user});

final rankInsightsProvider = FutureProvider.autoDispose
    .family<RankInsights, InsightsKey>(
      (ref, key) => ref
          .watch(rankingsRepositoryProvider)
          .insights(key.game, user: key.user),
    );
