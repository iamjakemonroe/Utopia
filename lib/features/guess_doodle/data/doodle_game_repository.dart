import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../chat/domain/voice_note.dart';
import '../domain/doodle_game.dart';

/// Guess My Doodle's server side (see the guess_my_doodle migration): the
/// game, players and chat stream in; everything that changes them is an
/// RPC the server checks. The drawing itself travels on a broadcast
/// channel ([inkChannel]) and is saved stroke by stroke for late joiners.
class DoodleGameRepository {
  DoodleGameRepository(this._client);

  final SupabaseClient _client;

  // ── joining ──────────────────────────────────────────────────────────────

  /// A public game with room, busiest first, or a new one. Its id.
  Future<String> quickPlay() async =>
      await _client.rpc('quick_play_doodle') as String;

  /// A private game friends join with its code: (id, code).
  Future<(String, String)> create({
    required int rounds,
    required int drawSeconds,
  }) async {
    final result = Map<String, dynamic>.from(
      await _client.rpc(
            'create_doodle_game',
            params: {
              'p_public': false,
              'p_rounds': rounds,
              'p_draw_seconds': drawSeconds,
            },
          )
          as Map,
    );
    return (result['id'] as String, result['code'] as String);
  }

  Future<String> join(String code) async =>
      await _client.rpc('join_doodle_game', params: {'p_code': code}) as String;

  Future<void> leave(String gameId) =>
      _client.rpc('leave_doodle_game', params: {'p_game': gameId});

  /// The game the player is still in, if any.
  Future<String?> myGame() async =>
      await _client.rpc('my_doodle_game') as String?;

  // ── playing ──────────────────────────────────────────────────────────────

  Future<void> start(String gameId) =>
      _client.rpc('start_doodle_game', params: {'p_game': gameId});

  /// [index] is 0, 1 or 2.
  Future<void> choose(String gameId, int index) => _client.rpc(
    'choose_doodle_word',
    params: {'p_game': gameId, 'p_index': index + 1},
  );

  /// For the drawer: the turn, and the words to pick from or the word.
  /// Empty for everyone else.
  Future<({int turn, List<String> choices, String? word})> secret(
    String gameId,
  ) async {
    final result = Map<String, dynamic>.from(
      await _client.rpc('doodle_secret', params: {'p_game': gameId}) as Map,
    );
    return (
      turn: (result['turn'] as num?)?.toInt() ?? -1,
      choices: [
        for (final w in (result['choices'] as List?) ?? const []) w as String,
      ],
      word: result['word'] as String?,
    );
  }

  /// Checks in, moves the game on if it's due, and returns the server's
  /// clock.
  /// The game's players as they are now (scores and all), straight from
  /// the database: what [watchPlayers] shows, for when its live updates
  /// don't all arrive.
  Future<List<DoodlePlayer>> fetchPlayers(String gameId) async {
    final rows = await _client
        .from('doodle_players')
        .select()
        .eq('game_id', gameId);
    return [for (final r in rows) DoodlePlayer.fromRow(r)];
  }

  Future<DateTime?> tick(String gameId) async {
    final result = await _client.rpc('tick_doodle', params: {'p_game': gameId});
    return DateTime.tryParse(
      (result is Map ? result['now'] : null) as String? ?? '',
    );
  }

  /// A line typed into the chat: a guess while someone's drawing.
  /// Uploads a recorded voice note to [path] (the game's folder).
  Future<void> uploadVoice(String path, Uint8List bytes) => _client.storage
      .from('voice-notes')
      .uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: VoiceNote.contentType(path)),
      );

  /// Posts an uploaded voice note to the game's chat.
  Future<void> sendVoice(String gameId, VoiceNote note) => _client.rpc(
    'send_doodle_voice',
    params: {'p_game': gameId, 'p_body': note.encode()},
  );

  Future<({GuessResult result, int points})> guess(
    String gameId,
    String text,
  ) async {
    final result = Map<String, dynamic>.from(
      await _client.rpc(
            'guess_doodle',
            params: {'p_game': gameId, 'p_text': text},
          )
          as Map,
    );
    return (
      result: switch (result['result']) {
        'correct' => GuessResult.correct,
        'close' => GuessResult.close,
        _ => GuessResult.chat,
      },
      points: (result['points'] as num?)?.toInt() ?? 0,
    );
  }

  // ── the drawing ──────────────────────────────────────────────────────────

  /// Saves a finished stroke. The canvas revision it made, or -1 if the
  /// turn moved on first.
  Future<int> addStroke({
    required String gameId,
    required int turn,
    required int epoch,
    required Map<String, Object?> op,
  }) async =>
      (await _client.rpc(
                'add_doodle_stroke',
                params: {
                  'p_game': gameId,
                  'p_turn': turn,
                  'p_epoch': epoch,
                  'p_op': op,
                },
              )
              as num)
          .toInt();

  Future<int> undo(String gameId) async =>
      (await _client.rpc('undo_doodle_stroke', params: {'p_game': gameId})
              as num)
          .toInt();

  Future<int> clear(String gameId) async =>
      (await _client.rpc('clear_doodle_canvas', params: {'p_game': gameId})
              as num)
          .toInt();

  /// The strokes on the canvas now, oldest first.
  Future<List<Map<String, Object?>>> strokes({
    required String gameId,
    required int turn,
    required int epoch,
  }) async {
    final rows = await _client
        .from('doodle_strokes')
        .select('op')
        .eq('game_id', gameId)
        .eq('turn', turn)
        .eq('epoch', epoch)
        .eq('undone', false)
        .order('id');
    return [
      for (final row in rows) Map<String, Object?>.from(row['op'] as Map),
    ];
  }

  /// The live drawing between this game's players.
  DoodleInkLink inkLink(String gameId) => _RealtimeInkLink(
    _client,
    _client.channel(
      'doodle-ink-$gameId',
      opts: const RealtimeChannelConfig(self: false),
    ),
  );

  // ── streams ──────────────────────────────────────────────────────────────

  /// The game as it is now (null: gone, or not this player's).
  Future<DoodleGame?> fetchGame(String gameId) async {
    final row = await _client
        .from('doodle_games')
        .select()
        .eq('id', gameId)
        .maybeSingle();
    return row == null ? null : DoodleGame.fromRow(row);
  }

  Stream<DoodleGame?> watchGame(String gameId) => _client
      .from('doodle_games')
      .stream(primaryKey: ['id'])
      .eq('id', gameId)
      .map((rows) => rows.isEmpty ? null : DoodleGame.fromRow(rows.first));

  Stream<List<DoodlePlayer>> watchPlayers(String gameId) => _client
      .from('doodle_players')
      .stream(primaryKey: ['game_id', 'user_id'])
      .eq('game_id', gameId)
      .map(
        (rows) => [
          // A row can arrive twice right after opening (the first load and
          // its insert); the later copy is the newer one.
          for (final r in {for (final r in rows) r['user_id']: r}.values)
            DoodlePlayer.fromRow(r),
        ],
      );

  /// The newest 80 chat lines, oldest first.
  Stream<List<DoodleMessage>> watchMessages(String gameId) => _client
      .from('doodle_messages')
      .stream(primaryKey: ['id'])
      .eq('game_id', gameId)
      .order('id', ascending: false)
      .limit(80)
      .map((rows) {
        // A line can arrive twice right after opening (the first load and
        // its insert): keep one of each.
        final seen = <Object?>{};
        return [
          for (final r in rows.reversed)
            if (seen.add(r['id'])) ?DoodleMessage.fromRow(r),
        ];
      });
}

/// The drawer's strokes, live, to everyone else in the game (and undo and
/// clear). Messages aren't echoed back to their sender.
abstract class DoodleInkLink {
  /// Starts listening: ink, end, undo and clear events.
  void listen(void Function(String event, Map<String, dynamic> data) onEvent);

  void send(String event, Map<String, dynamic> data);

  Future<void> close();
}

class _RealtimeInkLink implements DoodleInkLink {
  _RealtimeInkLink(this._client, this._channel);

  final SupabaseClient _client;
  final RealtimeChannel _channel;

  static const _events = ['ink', 'end', 'undo', 'clear'];

  @override
  void listen(void Function(String event, Map<String, dynamic> data) onEvent) {
    for (final event in _events) {
      _channel.onBroadcast(
        event: event,
        callback: (p) {
          // The sent fields arrive at the top level (some versions nest
          // them under 'payload').
          final inner = p['payload'];
          onEvent(event, inner is Map ? Map<String, dynamic>.from(inner) : p);
        },
      );
    }
    _channel.subscribe();
  }

  @override
  void send(String event, Map<String, dynamic> data) {
    _channel.sendBroadcastMessage(event: event, payload: Map.of(data)).ignore();
  }

  @override
  Future<void> close() => _client.removeChannel(_channel);
}

final doodleGameRepositoryProvider = Provider<DoodleGameRepository>(
  (ref) => DoodleGameRepository(ref.watch(supabaseClientProvider)),
);
