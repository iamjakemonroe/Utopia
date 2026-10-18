import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/ranking.dart';

/// Ratings for online chess and checkers. The server rates each finished
/// game; the app only reads.
class RankingsRepository {
  RankingsRepository(this._client);

  final SupabaseClient _client;

  /// [game]'s board: everyone, or the player and their friends.
  Future<Leaderboard> leaderboard(String game, {bool friends = false}) async {
    final data = await _client.rpc(
      'get_leaderboard',
      params: {'p_game': game, 'p_friends': friends},
    );
    return Leaderboard.fromJson(Map<String, dynamic>.from(data as Map));
  }

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
