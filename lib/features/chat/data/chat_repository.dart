import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';

/// Which game a chat belongs to. Each game keeps its messages in its own
/// table, behind its own send function, with the same shape.
enum ChatGame {
  ludo('ludo_chat_messages', 'send_ludo_chat'),
  chess('chess_chat_messages', 'send_chess_chat');

  const ChatGame(this.table, this.sendFunction);

  final String table;
  final String sendFunction;
}

/// In-game chat for any game: the live message list, sending, and voice
/// notes (stored in the private voice-notes bucket, one folder per match;
/// only that match's players can upload there or listen).
class ChatRepository {
  ChatRepository(this._client);

  final SupabaseClient _client;

  Stream<List<Map<String, dynamic>>> watchChat(ChatGame game, String matchId) {
    return _client
        .from(game.table)
        .stream(primaryKey: ['id'])
        .eq('match_id', matchId)
        .order('id', ascending: true);
  }

  Future<Map<String, dynamic>> sendChat({
    required ChatGame game,
    required String matchId,
    required String kind,
    required String body,
  }) async {
    return Map<String, dynamic>.from(
      await _client.rpc(
            game.sendFunction,
            params: {'p_match_id': matchId, 'p_kind': kind, 'p_body': body},
          )
          as Map,
    );
  }

  /// Whether a game is between friends: a chess game started from an
  /// invite, or a Ludo game from a friends' room.
  Future<bool> isFriendsGame(ChatGame game, String matchId) async {
    switch (game) {
      case ChatGame.chess:
        final row = await _client
            .from('match_invites')
            .select('id')
            .eq('match_id', matchId)
            .limit(1)
            .maybeSingle();
        return row != null;
      case ChatGame.ludo:
        final row = await _client
            .from('ludo_matches')
            .select('mode')
            .eq('id', matchId)
            .maybeSingle();
        return row?['mode'] == 'friends';
    }
  }

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
}

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(supabaseClientProvider)),
);
