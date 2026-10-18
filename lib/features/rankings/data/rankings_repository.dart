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

/// The player's rating change from one match.
final ratingChangeProvider = FutureProvider.autoDispose
    .family<RatingChange?, String>(
      (ref, matchId) => ref.watch(rankingsRepositoryProvider).change(matchId),
    );
