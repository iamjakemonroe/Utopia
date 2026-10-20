import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/providers/auth_providers.dart';
import '../data/chat_repository.dart';
import '../domain/chat_filter.dart';
import '../domain/chat_message.dart';
import '../domain/voice_note.dart';
import '../../../l10n/strings.dart';

class GameChatState {
  const GameChatState({
    this.messages = const [],
    this.unread = 0,
    this.baseline = -1,
    this.friends = false,
  });

  final List<ChatMessage> messages;
  final int unread;

  /// The newest message already there when the game opened; anything at or
  /// below it is history, not news (no bubble, no sound, not unread).
  final int baseline;

  /// Friends chat freely; public games are kept friendly.
  final bool friends;

  GameChatState copyWith({
    List<ChatMessage>? messages,
    int? unread,
    int? baseline,
    bool? friends,
  }) {
    return GameChatState(
      messages: messages ?? this.messages,
      unread: unread ?? this.unread,
      baseline: baseline ?? this.baseline,
      friends: friends ?? this.friends,
    );
  }
}

/// One game's chat on its own: the live conversation, an unread count
/// while the sheet is closed, and sending (text, stickers, voice notes).
/// Ludo keeps its chat inside its match controller (its reactions ride on
/// it); chess uses this.
class GameChatController extends StateNotifier<GameChatState> {
  GameChatController(
    this._repo,
    this._game,
    this._matchId,
    this._me, {
    required bool friends,
  }) : super(GameChatState(friends: friends)) {
    _sub = _repo
        .watchChat(_game, _matchId)
        .listen(_onRows, onError: (Object _) {});
    _repo
        .isFriendsGame(_game, _matchId)
        .then((friends) {
          if (mounted) setFriends(friends);
        })
        .catchError((Object _) {});
  }

  final ChatRepository _repo;
  final ChatGame _game;
  final String _matchId;
  final String _me;
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  bool _primed = false;
  bool _open = false;
  int _seen = -1;

  void _onRows(List<Map<String, dynamic>> rows) {
    final messages = rows.map(ChatMessage.fromRow).toList();
    if (!_primed) {
      _primed = true;
      for (final m in messages) {
        if (m.id > _seen) _seen = m.id;
      }
      state = state.copyWith(messages: messages, baseline: _seen);
      return;
    }
    var unread = state.unread;
    for (final m in messages) {
      if (m.id <= _seen) continue;
      _seen = m.id;
      if (!_open && m.senderId != _me) unread++;
    }
    state = state.copyWith(messages: messages, unread: unread);
  }

  void setFriends(bool friends) {
    if (friends != state.friends) state = state.copyWith(friends: friends);
  }

  void setOpen(bool open) {
    _open = open;
    if (open && state.unread != 0) state = state.copyWith(unread: 0);
  }

  /// Returns an error to show, or null.
  Future<String?> send(String text, {String kind = 'text'}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final body = state.friends || kind != 'text'
        ? trimmed
        : ChatFilter.filter(trimmed);
    try {
      await _repo.sendChat(
        game: _game,
        matchId: _matchId,
        kind: kind,
        body: body,
      );
      return null;
    } catch (e) {
      if (e.toString().contains('slow down')) {
        return strings.gameChatWhoaSlowDownALittle;
      }
      return strings.gameChatCouldnTSendThatMessage;
    }
  }

  /// Uploads a recording and posts it. Returns an error to show, or null.
  Future<String?> sendVoice(
    Uint8List bytes, {
    required int ms,
    required List<int> wave,
  }) async {
    final note = VoiceNote(
      // A browser records WAV, the apps AAC.
      path: VoiceNote.newPath(_matchId, wav: VoiceNote.isWav(bytes)),
      ms: ms,
      wave: wave,
    );
    try {
      await _repo.uploadVoice(note.path, bytes);
      await _repo.sendChat(
        game: _game,
        matchId: _matchId,
        kind: 'voice',
        body: note.encode(),
      );
      return null;
    } catch (e) {
      if (e.toString().contains('slow down')) {
        return strings.gameChatWhoaSlowDownALittle;
      }
      return strings.gameChatCouldnTSendYourVoice;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// A game's chat, by game and match id.
final gameChatProvider = StateNotifierProvider.autoDispose
    .family<GameChatController, GameChatState, (ChatGame, String)>((ref, key) {
      final me = ref.watch(currentUserProvider)?.id ?? '';
      return GameChatController(
        ref.watch(chatRepositoryProvider),
        key.$1,
        key.$2,
        me,
        friends: false,
      );
    });
