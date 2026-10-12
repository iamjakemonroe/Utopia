import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// A friend lobby, as the backend's create_ludo_room returns it.
class LudoRoomRef {
  const LudoRoomRef({required this.id, required this.code});

  final String id;
  final String code;
}

/// All Ludo data access: realtime streams for matches, rooms and chat, and
/// the RPCs that mutate them server-side (see
/// `supabase/migrations/20261001090000_ludo_v2_social_store.sql`). No
/// client-side balance math: every coin movement happens inside a
/// SECURITY DEFINER function.
class LudoRepository {
  LudoRepository(this._client);

  final SupabaseClient _client;

  // ── matches ──────────────────────────────────────────────────────────────

  Stream<Map<String, dynamic>?> watchMatch(String matchId) {
    return _client
        .from('ludo_matches')
        .stream(primaryKey: ['id'])
        .eq('id', matchId)
        .map((rows) => rows.isEmpty ? null : rows.first);
  }

  Future<Map<String, dynamic>?> fetchMatch(String matchId) {
    return _client
        .from('ludo_matches')
        .select()
        .eq('id', matchId)
        .maybeSingle();
  }

  /// Matches the user is in (RLS limits rows to those). Used to notice a
  /// quick-match table filling up from someone else's join.
  Stream<List<Map<String, dynamic>>> watchMyMatches() {
    return _client
        .from('ludo_matches')
        .stream(primaryKey: ['id'])
        .order('created_at');
  }

  /// The Ludo game [userId] is still playing in (not one they left), if
  /// any, newest first.
  Future<String?> activeMatchId(String userId) async {
    final rows = await _client
        .from('ludo_matches')
        .select('id, players, colors, state')
        .eq('status', 'active')
        .contains('players', [userId])
        .order('created_at', ascending: false)
        .limit(3);
    for (final row in rows) {
      final players = (row['players'] as List).cast<String>();
      final colors = (row['colors'] as List).cast<String>();
      final seat = players.indexOf(userId);
      if (seat < 0 || seat >= colors.length) continue;
      final left = ((row['state'] as Map?)?['left'] as List?) ?? const [];
      if (!left.contains(colors[seat])) return row['id'] as String;
    }
    return null;
  }

  /// Joins quick match for a [size]-player table (2 or 4). Returns the new
  /// match id if this join completed a table, else null (keep waiting).
  Future<String?> joinMatchmakingQueue(int stake, {int size = 2}) async {
    final result = await _client.rpc(
      'join_ludo_matchmaking_queue',
      params: {'p_stake': stake, 'p_size': size},
    );
    return result as String?;
  }

  Future<void> leaveMatchmakingQueue() {
    return _client.rpc('leave_ludo_matchmaking_queue');
  }

  /// Shares a roll that leaves the player choosing a token.
  Future<void> recordRoll({
    required String matchId,
    required Map<String, dynamic> state,
  }) {
    return _client.rpc(
      'record_ludo_roll',
      params: {'p_match_id': matchId, 'p_state': state},
    );
  }

  /// Passes the turn on once the player on turn has run out of time. The
  /// turn is named by [turnCount] and [rollSeq] so a stale call can't skip
  /// a later turn. Returns false if the server says time isn't up yet.
  Future<bool> skipTurn({
    required String matchId,
    required int turnCount,
    required int rollSeq,
  }) async {
    final result = await _client.rpc(
      'skip_ludo_turn',
      params: {
        'p_match_id': matchId,
        'p_turn_count': turnCount,
        'p_roll_seq': rollSeq,
      },
    );
    return result == true;
  }

  Future<void> recordMove({
    required String matchId,
    required int turnNumber,
    required int diceValue,
    int? tokenIndex,
    required bool captured,
    required bool reachedHome,
    required Map<String, dynamic> stateAfter,
  }) {
    return _client.rpc(
      'record_ludo_move',
      params: {
        'p_match_id': matchId,
        'p_turn_number': turnNumber,
        'p_dice_value': diceValue,
        'p_token_index': tokenIndex,
        'p_captured': captured,
        'p_reached_home': reachedHome,
        'p_state_after': stateAfter,
      },
    );
  }

  Future<void> reportMatchResult({
    required String matchId,
    String? winnerId,
    required String result,
  }) {
    return _client.rpc(
      'report_ludo_match_result',
      params: {
        'p_match_id': matchId,
        'p_winner_id': winnerId,
        'p_result': result,
      },
    );
  }

  /// Leaves a match for good: a forfeit. With two players left the other
  /// one wins; with more, the game goes on without this player.
  Future<void> resignMatch(String matchId) {
    return _client.rpc('resign_ludo_match', params: {'p_match_id': matchId});
  }

  // ── friend rooms ─────────────────────────────────────────────────────────

  Future<LudoRoomRef> createRoom({
    required int maxPlayers,
    required int stake,
  }) async {
    final result = Map<String, dynamic>.from(
      await _client.rpc(
            'create_ludo_room',
            params: {'p_max_players': maxPlayers, 'p_stake': stake},
          )
          as Map,
    );
    return LudoRoomRef(
      id: result['id'] as String,
      code: result['code'] as String,
    );
  }

  Future<String> joinRoom(String code) async {
    return await _client.rpc('join_ludo_room', params: {'p_code': code})
        as String;
  }

  Future<void> leaveRoom(String roomId) {
    return _client.rpc('leave_ludo_room', params: {'p_room_id': roomId});
  }

  Future<String> startRoom(String roomId) async {
    return await _client.rpc('start_ludo_room', params: {'p_room_id': roomId})
        as String;
  }

  /// Moves the current player to an open seat (and its color).
  Future<void> takeSeat(String roomId, int seat) {
    return _client.rpc(
      'take_ludo_room_seat',
      params: {'p_room_id': roomId, 'p_seat': seat},
    );
  }

  Stream<Map<String, dynamic>?> watchRoom(String roomId) {
    return _client
        .from('ludo_rooms')
        .stream(primaryKey: ['id'])
        .eq('id', roomId)
        .map((rows) => rows.isEmpty ? null : rows.first);
  }

  Stream<List<Map<String, dynamic>>> watchRoomMembers(String roomId) {
    return _client
        .from('ludo_room_members')
        .stream(primaryKey: ['room_id', 'user_id'])
        .eq('room_id', roomId)
        .order('seat', ascending: true);
  }

  // ── chat ─────────────────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> watchChat(String matchId) {
    return _client
        .from('ludo_chat_messages')
        .stream(primaryKey: ['id'])
        .eq('match_id', matchId)
        .order('id', ascending: true);
  }

  Future<Map<String, dynamic>> sendChat({
    required String matchId,
    required String kind,
    required String body,
  }) async {
    return Map<String, dynamic>.from(
      await _client.rpc(
            'send_ludo_chat',
            params: {'p_match_id': matchId, 'p_kind': kind, 'p_body': body},
          )
          as Map,
    );
  }

  // ── players ──────────────────────────────────────────────────────────────

  /// Uploads a recorded voice note (AAC in an .m4a) to [path].
  Future<void> uploadVoice(String path, Uint8List bytes) async {
    await _client.storage
        .from('voice-notes')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'audio/mp4'),
        );
  }

  /// A short-lived link to play a voice note (only match players get one).
  Future<String> voiceUrl(String path) {
    return _client.storage.from('voice-notes').createSignedUrl(path, 3600);
  }

  Future<Map<String, dynamic>> playerStats(String userId) async {
    return Map<String, dynamic>.from(
      await _client.rpc('get_player_stats', params: {'p_user': userId}) as Map,
    );
  }

  Future<void> reportPlayer({
    required String userId,
    required String reason,
    String? details,
    String? matchId,
  }) {
    return _client.rpc(
      'report_player',
      params: {
        'p_reported': userId,
        'p_reason': reason,
        'p_details': details,
        'p_match_id': matchId,
      },
    );
  }
}
