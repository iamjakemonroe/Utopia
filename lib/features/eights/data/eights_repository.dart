import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../chat/domain/voice_note.dart';
import '../domain/eights_engine.dart';

/// A friend room, as create_eights_room returns it.
class EightsRoomRef {
  const EightsRoomRef({required this.id, required this.code});

  final String id;
  final String code;
}

/// Everything Crazy Eights asks the backend for (see
/// `supabase/migrations/20261021350000_crazy_eights.sql`). The server keeps
/// the cards: moves go through its functions, which check them, and each
/// player only ever reads their own hand.
class EightsRepository {
  EightsRepository(this._client);

  final SupabaseClient _client;

  // ── matches ──────────────────────────────────────────────────────────────

  Stream<Map<String, dynamic>?> watchMatch(String matchId) => _client
      .from('eights_matches')
      .stream(primaryKey: ['id'])
      .eq('id', matchId)
      .map((rows) => rows.isEmpty ? null : rows.first);

  Future<Map<String, dynamic>?> fetchMatch(String matchId) =>
      _client.from('eights_matches').select().eq('id', matchId).maybeSingle();

  /// The games this player is in, to notice a quick-match table filling.
  Stream<List<Map<String, dynamic>>> watchMyMatches() => _client
      .from('eights_matches')
      .stream(primaryKey: ['id'])
      .order('created_at');

  /// The card game [userId] is still playing in, if any.
  Future<String?> activeMatchId(String userId) async {
    final rows = await _client
        .from('eights_matches')
        .select('id, players, state')
        .eq('status', 'active')
        .contains('players', [userId])
        .order('created_at', ascending: false)
        .limit(3);
    for (final row in rows) {
      final seat = (row['players'] as List).indexOf(userId);
      final left = ((row['state'] as Map?)?['left'] as List?) ?? const [];
      if (seat >= 0 && !left.contains(seat)) return row['id'] as String;
    }
    return null;
  }

  /// My cards in [matchId].
  Future<List<PlayingCard>> fetchHand(String matchId, String userId) async {
    final row = await _client
        .from('eights_hands')
        .select('cards')
        .eq('match_id', matchId)
        .eq('user_id', userId)
        .maybeSingle();
    return _cards(row?['cards']);
  }

  static List<PlayingCard> _cards(Object? list) => [
    for (final c in (list as List? ?? const []))
      PlayingCard.fromCode(c as String),
  ];

  /// Plays [card] (naming [suit] for an eight); returns my hand after.
  Future<List<PlayingCard>> play(
    String matchId,
    PlayingCard card, {
    CardSuit? suit,
  }) async => _cards(
    await _client.rpc(
      'play_eights_card',
      params: {
        'p_match_id': matchId,
        'p_card': card.code,
        'p_suit': suit?.code,
      },
    ),
  );

  /// Draws a card; returns my hand after.
  Future<List<PlayingCard>> draw(String matchId) async => _cards(
    await _client.rpc('draw_eights_card', params: {'p_match_id': matchId}),
  );

  Future<void> pass(String matchId) =>
      _client.rpc('pass_eights_turn', params: {'p_match_id': matchId});

  /// Moves the turn on once the player on it has run out of time. [seq]
  /// names the action that timed out. False if the server says time
  /// isn't up yet.
  Future<bool> skipTurn(String matchId, int seq) async =>
      await _client.rpc(
        'skip_eights_turn',
        params: {'p_match_id': matchId, 'p_seq': seq},
      ) ==
      true;

  /// Leaves for good: a forfeit.
  Future<void> resign(String matchId) =>
      _client.rpc('resign_eights_match', params: {'p_match_id': matchId});

  // ── quick match ──────────────────────────────────────────────────────────

  /// Joins quick match for a [size]-player table. The new match's id when
  /// this join filled one, else null (keep waiting).
  Future<String?> joinMatchmakingQueue(int stake, {int size = 2}) async =>
      await _client.rpc(
            'join_eights_matchmaking_queue',
            params: {'p_stake': stake, 'p_size': size},
          )
          as String?;

  Future<void> leaveMatchmakingQueue() =>
      _client.rpc('leave_eights_matchmaking_queue');

  // ── friend rooms ─────────────────────────────────────────────────────────

  Future<EightsRoomRef> createRoom({
    required int maxPlayers,
    required int stake,
  }) async {
    final result = Map<String, dynamic>.from(
      await _client.rpc(
            'create_eights_room',
            params: {'p_max_players': maxPlayers, 'p_stake': stake},
          )
          as Map,
    );
    return EightsRoomRef(
      id: result['id'] as String,
      code: result['code'] as String,
    );
  }

  Future<String> joinRoom(String code) async =>
      await _client.rpc('join_eights_room', params: {'p_code': code}) as String;

  Future<void> leaveRoom(String roomId) =>
      _client.rpc('leave_eights_room', params: {'p_room_id': roomId});

  Future<String> startRoom(String roomId) async =>
      await _client.rpc('start_eights_room', params: {'p_room_id': roomId})
          as String;

  Stream<Map<String, dynamic>?> watchRoom(String roomId) => _client
      .from('eights_rooms')
      .stream(primaryKey: ['id'])
      .eq('id', roomId)
      .map((rows) => rows.isEmpty ? null : rows.first);

  Future<Map<String, dynamic>?> fetchRoom(String roomId) =>
      _client.from('eights_rooms').select().eq('id', roomId).maybeSingle();

  Stream<List<Map<String, dynamic>>> watchRoomMembers(String roomId) => _client
      .from('eights_room_members')
      .stream(primaryKey: ['room_id', 'user_id'])
      .eq('room_id', roomId)
      .order('seat', ascending: true);

  Future<List<Map<String, dynamic>>> fetchRoomMembers(String roomId) => _client
      .from('eights_room_members')
      .select()
      .eq('room_id', roomId)
      .order('seat', ascending: true);

  // ── chat ─────────────────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> watchChat(String matchId) => _client
      .from('eights_chat_messages')
      .stream(primaryKey: ['id'])
      .eq('match_id', matchId)
      .order('id', ascending: true);

  Future<void> sendChat({
    required String matchId,
    required String kind,
    required String body,
  }) => _client.rpc(
    'send_eights_chat',
    params: {'p_match_id': matchId, 'p_kind': kind, 'p_body': body},
  );

  /// Uploads a recorded voice note to [path] (the match's folder).
  Future<void> uploadVoice(String path, Uint8List bytes) => _client.storage
      .from('voice-notes')
      .uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: VoiceNote.contentType(path)),
      );
}
