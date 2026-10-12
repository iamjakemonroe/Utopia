import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/profiles/profile_repository.dart';

/// A friend/recent row as the popup renders it: someone else's public
/// profile plus how this user relates to them.
class SocialProfile {
  const SocialProfile({
    required this.id,
    required this.name,
    required this.username,
    required this.avatarUrl,
    required this.avatarKind,
    required this.avatarSeed,
    this.lastPlayedAt,
  });

  final String id;
  final String name;
  final String? username;
  final String? avatarUrl;
  final String? avatarKind;
  final int? avatarSeed;
  final DateTime? lastPlayedAt;

  factory SocialProfile.fromProfileRow(
    Map<String, dynamic> row, {
    DateTime? lastPlayedAt,
  }) {
    final id = row['id'] as String;
    return SocialProfile(
      id: id,
      name: profileDisplayName(row, id),
      username: row['username'] as String?,
      avatarUrl: row['avatar_url'] as String?,
      avatarKind: row['avatar_kind'] as String?,
      avatarSeed: (row['avatar_seed'] as num?)?.toInt(),
      lastPlayedAt: lastPlayedAt,
    );
  }
}

/// Friends, friend requests, and "recents" (people you've played but never
/// added). Recents are derived client-side from the `matches` table rather
/// than a dedicated table — RLS already scopes `matches` to rows the caller
/// is a player in, so "who have I played" is just that table with the
/// friend list subtracted out.
enum FriendshipStatus { self, friends, requested, incoming, none }

class FriendRepository {
  FriendRepository(this._client, this._profiles);

  final SupabaseClient _client;
  final ProfileRepository _profiles;

  Future<List<String>> _friendIds(String userId) async {
    final rows = await _client
        .from('friendships')
        .select('user_low, user_high')
        .or('user_low.eq.$userId,user_high.eq.$userId');
    return rows
        .map<String>(
          (row) => row['user_low'] == userId
              ? row['user_high'] as String
              : row['user_low'] as String,
        )
        .toList();
  }

  /// Where [me] stands with [other], for the "Add friend" button on a
  /// player card.
  Future<FriendshipStatus> friendshipStatus(String me, String other) async {
    if (me == other) return FriendshipStatus.self;
    if ((await _friendIds(me)).contains(other)) return FriendshipStatus.friends;
    final pending = await _client
        .from('friend_requests')
        .select('from_user')
        .eq('status', 'pending')
        .or(
          'and(from_user.eq.$me,to_user.eq.$other),'
          'and(from_user.eq.$other,to_user.eq.$me)',
        );
    if (pending.isEmpty) return FriendshipStatus.none;
    return pending.first['from_user'] == me
        ? FriendshipStatus.requested
        : FriendshipStatus.incoming;
  }

  Future<List<SocialProfile>> fetchFriends(String userId) async {
    final ids = await _friendIds(userId);
    if (ids.isEmpty) return const [];
    final profiles = await _profiles.fetchByIds(ids);
    return profiles.map(SocialProfile.fromProfileRow).toList();
  }

  /// Opponents from completed/active matches who are not already friends,
  /// most recently played first.
  Future<List<SocialProfile>> fetchRecents(String userId) async {
    final matches = await _client
        .from('matches')
        .select('player_white, player_black, created_at')
        .or('player_white.eq.$userId,player_black.eq.$userId')
        .order('created_at', ascending: false)
        .limit(100);

    final friendIds = (await _friendIds(userId)).toSet();
    final lastPlayed = <String, DateTime>{};
    for (final row in matches) {
      final opponentId = row['player_white'] == userId
          ? row['player_black'] as String?
          : row['player_white'] as String?;
      if (opponentId == null ||
          opponentId == userId ||
          friendIds.contains(opponentId)) {
        continue;
      }
      lastPlayed.putIfAbsent(
        opponentId,
        () => DateTime.parse(row['created_at'] as String),
      );
    }

    if (lastPlayed.isEmpty) return const [];
    final profiles = await _profiles.fetchByIds(lastPlayed.keys.toList());
    final result =
        profiles
            .map(
              (row) => SocialProfile.fromProfileRow(
                row,
                lastPlayedAt: lastPlayed[row['id']],
              ),
            )
            .toList()
          ..sort((a, b) => b.lastPlayedAt!.compareTo(a.lastPlayedAt!));
    return result;
  }

  Future<List<Map<String, dynamic>>> fetchIncomingFriendRequests(
    String userId,
  ) async {
    final rows = await _client
        .from('friend_requests')
        .select('id, from_user, created_at')
        .eq('to_user', userId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// People this user has a request out to (still waiting on them).
  Future<Set<String>> fetchOutgoingRequestIds(String userId) async {
    final rows = await _client
        .from('friend_requests')
        .select('to_user')
        .eq('from_user', userId)
        .eq('status', 'pending');
    return {for (final row in rows) row['to_user'] as String};
  }

  Future<void> sendFriendRequest(String toUserId) {
    return _client.rpc('send_friend_request', params: {'p_to_user': toUserId});
  }

  Future<void> respondFriendRequest({
    required String requestId,
    required bool accept,
  }) {
    return _client.rpc(
      'respond_friend_request',
      params: {'p_request_id': requestId, 'p_accept': accept},
    );
  }

  Future<List<Map<String, dynamic>>> searchUsers(
    String query, {
    required String excludeId,
  }) {
    return _profiles.searchByUsername(query, excludeId: excludeId);
  }
}
