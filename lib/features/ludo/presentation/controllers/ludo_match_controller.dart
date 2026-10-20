import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/bots/bots.dart';
import '../../../../core/widgets/game_card_art.dart';
import '../../../home/data/offline_game.dart';
import '../../../../core/supabase/supabase_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/ludo_repository.dart';
import '../../../chat/domain/chat_filter.dart';
import '../../../chat/domain/chat_message.dart';
import '../../domain/ludo_bot.dart';
import '../../domain/ludo_engine.dart';
import '../../../chat/domain/voice_note.dart';
import '../widgets/ludo_board.dart';
import '../widgets/ludo_dice.dart';
import '../widgets/ludo_pieces.dart';
import '../../../../l10n/strings.dart';

final ludoRepositoryProvider = Provider<LudoRepository>((ref) {
  return LudoRepository(ref.watch(supabaseClientProvider));
});

const _engine = LudoEngine();

/// How long the capturing player has to pick a reaction.
const kReactionWindow = Duration(seconds: 6);

/// Time for each action (a roll, then picking a token) in a public game.
/// Matches the server's skip_ludo_turn.
const kTurnTime = Duration(seconds: 15);

/// Friends' rooms get longer to think.
const kFriendsTurnTime = Duration(seconds: 40);

/// Three missed turns in a row and a player is out.
const kMaxMissedTurns = 3;

/// An offline game on this phone: who sits where. The phone's owner is
/// [humanId]; `friend:` ids are friends taking turns on the same phone, and
/// every other id is a bot (see bots.dart).
class LocalLudoSetup {
  const LocalLudoSetup({
    required this.playerIds,
    required this.colors,
    required this.humanId,
  });

  final List<String> playerIds;
  final List<LudoColor> colors;
  final String humanId;
}

final Map<String, LocalLudoSetup> _localGames = {};

/// Sets up an offline game and returns its match id (open it at
/// `/ludo/<id>`).
String startLocalLudo(LocalLudoSetup setup) {
  final id = 'local-${DateTime.now().microsecondsSinceEpoch}';
  _localGames[id] = setup;
  return id;
}

LocalLudoSetup? localLudoSetup(String matchId) => _localGames[matchId];

/// Saved offline games to pick back up: the board and the move count.
final Map<String, (LudoState, int)> _localResume = {};

/// Brings back an offline game saved before the app closed (see
/// OfflineGame), ready to open at its route.
void restoreLocalLudo(String route, Map<String, dynamic> data) {
  final id = route.split('/').last;
  final players = (data['players'] as List?)?.cast<String>();
  final colors = (data['colors'] as List?)?.cast<String>();
  final human = data['human'] as String?;
  final game = data['game'];
  if (players == null || colors == null || human == null || game is! Map) {
    return;
  }
  _localGames[id] = LocalLudoSetup(
    playerIds: players,
    colors: [for (final c in colors) LudoColor.values.byName(c)],
    humanId: human,
  );
  _localResume[id] = (
    LudoState.fromJson(game.cast<String, dynamic>()),
    (data['turn'] as num?)?.toInt() ?? 0,
  );
}

bool isLocalLudo(String matchId) => matchId.startsWith('local-');

/// A capture waiting on its reaction: the capturing player is choosing
/// war or peace (everyone else sees a thought bubble).
class PendingReaction {
  const PendingReaction({required this.capture, required this.deadline});

  final LudoCapture capture;
  final DateTime deadline;
}

class LudoMatchState {
  const LudoMatchState({
    required this.game,
    this.matchRow,
    this.myColor,
    this.loading = true,
    this.busy = false,
    this.error,
    this.chat = const [],
    this.unread = 0,
    this.pendingReaction,
    this.reaction,
    this.chatBaseline = -1,
    this.turnStartedAt,
    this.rollShownAt,
  });

  final LudoState game;
  final Map<String, dynamic>? matchRow;
  final LudoColor? myColor;
  final bool loading;

  /// A roll or move is being sent.
  final bool busy;
  final String? error;
  final List<ChatMessage> chat;
  final int unread;
  final PendingReaction? pendingReaction;
  final LudoTokenReaction? reaction;

  /// The newest chat message already there when the match opened; anything
  /// at or below it is history, not news.
  final int chatBaseline;

  /// When the current action's timer started on this device.
  final DateTime? turnStartedAt;

  /// When the latest roll's number is showing on the die. Until then no
  /// piece glows or moves: the die always lands first.
  final DateTime? rollShownAt;

  /// The die is still tumbling.
  bool get rollShowing =>
      rollShownAt == null || !DateTime.now().isBefore(rollShownAt!);

  /// Time left for the player on turn, or null when no clock is running.
  int? get turnMsLeft {
    final started = turnStartedAt;
    if (started == null || !isActive || game.winner != null) return null;
    final left =
        turnTime.inMilliseconds -
        DateTime.now().difference(started).inMilliseconds;
    return left < 0 ? 0 : left;
  }

  /// Turns in a row [color] has let run out.
  int missedTurns(LudoColor color) =>
      ((matchRow?['missed_turns'] as Map?)?[color.name] as num?)?.toInt() ?? 0;

  String get status => matchRow?['status'] as String? ?? 'pending';
  bool get isActive => status == 'active';
  int get stake => (matchRow?['stake'] as num?)?.toInt() ?? 0;
  int get pot => stake * playerIds.length;
  String get mode => matchRow?['mode'] as String? ?? 'public';
  bool get isFriendsGame => mode == 'friends';

  /// An offline game against computer players.
  bool get isLocal => mode == 'local';

  /// How long each action has: longer among friends, and for friends
  /// passing one phone around.
  Duration get turnTime =>
      isFriendsGame || friendColors.isNotEmpty ? kFriendsTurnTime : kTurnTime;
  String? get winnerId => matchRow?['winner_id'] as String?;

  List<String> get playerIds =>
      (matchRow?['players'] as List?)?.cast<String>() ?? const [];

  List<LudoColor> get seatColors => [
    for (final c in (matchRow?['colors'] as List? ?? const []))
      LudoColor.values.byName(c as String),
  ];

  String? userFor(LudoColor color) {
    final i = seatColors.indexOf(color);
    return i < 0 || i >= playerIds.length ? null : playerIds[i];
  }

  LudoColor? colorOf(String userId) {
    final i = playerIds.indexOf(userId);
    return i < 0 || i >= seatColors.length ? null : seatColors[i];
  }

  bool get iLeft => myColor != null && game.left.contains(myColor);

  /// Colours played by friends passing this phone around (offline games).
  Set<LudoColor> get friendColors => {
    if (isLocal)
      for (final c in seatColors)
        if (isFriendSeatId(userFor(c))) c,
  };

  /// [color] is played by someone holding this phone: me, or a friend.
  bool playsHere(LudoColor color) =>
      color == myColor || friendColors.contains(color);

  /// Someone on this phone is on turn (me, or a friend in pass and play).
  bool get isMyTurn =>
      playsHere(game.turn) && isActive && !game.left.contains(game.turn);

  /// Someone on this phone can react to their capture (tap the piece that
  /// took it). The die doesn't wait: rolling on passes on reacting.
  bool get choosingReaction =>
      pendingReaction != null &&
      playsHere(pendingReaction!.capture.by) &&
      DateTime.now().isBefore(pendingReaction!.deadline);

  bool get canRoll =>
      isMyTurn &&
      !game.hasRolled &&
      !busy &&
      rollShowing &&
      game.winner == null;

  List<int> get movableTokens {
    final dice = game.diceValue;
    if (!isMyTurn || !game.hasRolled || dice == null || busy) return const [];
    if (!rollShowing) return const [];
    return _engine.legalTokenMoves(game, dice);
  }

  LudoMatchState copyWith({
    LudoState? game,
    Map<String, dynamic>? matchRow,
    LudoColor? myColor,
    bool? loading,
    bool? busy,
    String? error,
    bool clearError = false,
    List<ChatMessage>? chat,
    int? unread,
    PendingReaction? pendingReaction,
    bool clearPendingReaction = false,
    LudoTokenReaction? reaction,
    bool clearReaction = false,
    int? chatBaseline,
    DateTime? turnStartedAt,
    DateTime? rollShownAt,
  }) {
    return LudoMatchState(
      game: game ?? this.game,
      matchRow: matchRow ?? this.matchRow,
      myColor: myColor ?? this.myColor,
      loading: loading ?? this.loading,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
      chat: chat ?? this.chat,
      unread: unread ?? this.unread,
      pendingReaction: clearPendingReaction
          ? null
          : (pendingReaction ?? this.pendingReaction),
      reaction: clearReaction ? null : (reaction ?? this.reaction),
      chatBaseline: chatBaseline ?? this.chatBaseline,
      turnStartedAt: turnStartedAt ?? this.turnStartedAt,
      rollShownAt: rollShownAt ?? this.rollShownAt,
    );
  }
}

/// Drives one live Ludo match. The `ludo_matches` row is the shared truth;
/// this applies the local player's rolls and moves optimistically, sends
/// them, and never lets a late-arriving older row roll the game back (rows
/// are ordered by turn count, then roll count).
class LudoMatchController extends StateNotifier<LudoMatchState> {
  LudoMatchController(this._repository, this._matchId, this._myUserId)
    : _local = null,
      _store = null,
      super(
        LudoMatchState(
          game: LudoState.initial(const [LudoColor.red, LudoColor.yellow]),
        ),
      ) {
    _matchSub = _repository
        .watchMatch(_matchId)
        .listen(
          _onMatchRow,
          onError: (Object e) => state = state.copyWith(
            error: strings.ludoMatchConnectionLostReconnecting,
          ),
        );
    _chatSub = _repository.watchChat(_matchId).listen(_onChat, onError: (_) {});
    _turnClock = Timer.periodic(
      const Duration(milliseconds: 400),
      (_) => _checkTurnTimer(),
    );
  }

  /// An offline game against bots: everything runs on this phone.
  LudoMatchController.local(
    this._repository,
    this._matchId,
    this._myUserId,
    LocalLudoSetup setup, {
    OfflineGameStore? store,
  }) : _local = setup,
       // ignore: prefer_initializing_formals
       _store = store,
       super(
         LudoMatchState(
           game: _localResume[_matchId]?.$1 ?? LudoState.initial(setup.colors),
           matchRow: {
             'id': _matchId,
             'status': 'active',
             'mode': 'local',
             'stake': 0,
             'turn_count': _localResume.remove(_matchId)?.$2 ?? 0,
             'missed_turns': <String, int>{},
             'players': setup.playerIds,
             'colors': [for (final c in setup.colors) c.name],
           },
           myColor: setup.colors[setup.playerIds.indexOf(setup.humanId)],
           loading: false,
         ),
       ) {
    addListener((_) {
      _driveBots();
      _saveLocal();
    });
    // Offline turns are timed too: run out and your turn plays itself.
    _restartTimerIfNew(state.matchRow, state.game);
    _turnClock = Timer.periodic(
      const Duration(milliseconds: 400),
      (_) => _checkTurnTimer(),
    );
  }

  final LudoRepository _repository;
  final String _matchId;
  final String _myUserId;
  final LocalLudoSetup? _local;
  bool get _isLocal => _local != null;

  /// Where an offline game is saved after every move, so it comes back if
  /// the app closes.
  final OfflineGameStore? _store;
  String? _savedKey;

  String get _localRoute => '/ludo/$_matchId';

  void _saveLocal() {
    final store = _store;
    final setup = _local;
    if (store == null || setup == null) return;
    final g = state.game;
    if (g.winner != null) {
      store.clear(route: _localRoute);
      return;
    }
    final turn = (state.matchRow?['turn_count'] as num?)?.toInt() ?? 0;
    final key = '$turn:${g.rollSeq}:${g.hasRolled}';
    if (key == _savedKey) return;
    _savedKey = key;
    store.save(
      OfflineGame(
        kind: GameKind.ludo,
        route: _localRoute,
        opponent: setup.playerIds.any(isFriendSeatId) ? 'friends' : 'bots',
        data: {
          'players': setup.playerIds,
          'colors': [for (final c in setup.colors) c.name],
          'human': setup.humanId,
          'game': g.toJson(),
          'turn': turn,
        },
      ),
    );
  }

  final _rng = Random();
  Timer? _botTimer;
  String? _botKey;

  StreamSubscription<Map<String, dynamic>?>? _matchSub;
  StreamSubscription<List<Map<String, dynamic>>>? _chatSub;
  bool _hasReportedResult = false;
  int _seenCaptureSeq = 0;
  int _seenChatId = -1;
  bool _chatPrimed = false;
  bool _chatOpen = false;
  Timer? _reactionTimer;
  Timer? _autoMove;

  /// When this player last rolled; pieces wait until the die has landed.
  DateTime _rolledAt = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _revealTimer;

  /// A move that arrived while the roll before it was still tumbling; it
  /// plays once the number has shown.
  Map<String, dynamic>? _heldRow;
  Timer? _heldTimer;

  /// Every new roll, from anyone: pieces wait until its number shows.
  @override
  set state(LudoMatchState value) {
    final prev = super.state;
    if (!value.loading &&
        !prev.loading &&
        value.game.rollSeq > prev.game.rollSeq) {
      value = value.copyWith(rollShownAt: DateTime.now().add(kDiceReveal));
      _revealTimer?.cancel();
      // Rebuild when the number is up, so the pieces light then.
      _revealTimer = Timer(kDiceReveal, () {
        if (mounted) state = state.copyWith();
      });
    }
    super.state = value;
  }

  Timer? _turnClock;
  String? _turnKey;

  /// When the app went to the background, while it's there.
  DateTime? _hiddenAt;

  /// The app went to the background: an offline game waits (no turn
  /// timer, no bots playing on) until the player is back.
  void appHidden() {
    if (!_isLocal || _hiddenAt != null) return;
    _hiddenAt = DateTime.now();
    _botTimer?.cancel();
    _botKey = null;
  }

  /// Back in the app: the turn's time picks up where it stopped.
  void appShown() {
    final hidden = _hiddenAt;
    if (hidden == null || !mounted) return;
    _hiddenAt = null;
    final started = state.turnStartedAt;
    if (started != null) {
      // Only time spent away is given back: a turn that began while away
      // (a roll that passed on its own) gets its full time from now.
      final from = started.isAfter(hidden) ? started : hidden;
      state = state.copyWith(
        turnStartedAt: started.add(DateTime.now().difference(from)),
      );
    }
    _driveBots();
  }

  DateTime _lastSkip = DateTime.fromMillisecondsSinceEpoch(0);

  /// Identifies the current action: a new roll or a new turn restarts the
  /// timer.
  String _keyFor(Map<String, dynamic>? row, LudoState game) =>
      '${row?['turn_count']}:${game.rollSeq}:${game.turn.name}:${game.hasRolled}';

  void _restartTimerIfNew(Map<String, dynamic>? row, LudoState game) {
    final key = _keyFor(row, game);
    if (key == _turnKey) return;
    _turnKey = key;
    state = state.copyWith(turnStartedAt: DateTime.now());
  }

  /// When the player on turn runs out of time, ask the server to pass the
  /// turn on. Their own device asks right away; everyone else waits a
  /// little longer, since the server's timer started before they heard.
  void _checkTurnTimer() {
    if (!mounted || _hiddenAt != null) return;
    final left = state.turnMsLeft;
    if (left == null || state.busy) return;
    final grace = state.isMyTurn ? 300 : 2500;
    final overdue =
        DateTime.now().difference(state.turnStartedAt!).inMilliseconds -
        state.turnTime.inMilliseconds;
    if (overdue < grace) return;
    final now = DateTime.now();
    if (now.difference(_lastSkip) < const Duration(milliseconds: 1500)) return;
    _lastSkip = now;
    if (_isLocal) {
      // Bots play on their own; only the player's own turn can run out.
      if (state.isMyTurn) _playForMe();
      return;
    }
    _autoMove?.cancel();
    _repository
        .skipTurn(
          matchId: _matchId,
          turnCount: (state.matchRow?['turn_count'] as num?)?.toInt() ?? 0,
          rollSeq: state.game.rollSeq,
        )
        .catchError((_) => false);
  }

  void _onMatchRow(Map<String, dynamic>? row) {
    if (row == null) {
      state = state.copyWith(
        loading: false,
        error: strings.ludoMatchMatchNotFound,
      );
      return;
    }
    final game = LudoState.fromJson(row['state'] as Map<String, dynamic>);
    if (!state.loading && !_isNewer(row, game)) return;

    final turn = (row['turn_count'] as num?)?.toInt() ?? 0;
    final localTurn = (state.matchRow?['turn_count'] as num?)?.toInt() ?? 0;

    // The roll and the move it made arrived together (a slow connection,
    // or an update that never came through): roll the die on the board as
    // it was, and the move waits below until its number has shown.
    final roll = game.lastRoll;
    if (!state.loading &&
        turn > localTurn &&
        game.rollSeq > state.game.rollSeq &&
        !game.hasRolled &&
        roll != null) {
      state = state.copyWith(
        game: state.game.copyWith(rollSeq: game.rollSeq, lastRoll: roll),
      );
    }

    // Someone moved before their die had landed here: show the roll first.
    final shownAt = state.rollShownAt;
    if (!state.loading && shownAt != null && turn > localTurn) {
      final wait = shownAt.add(kDiceReadTime).difference(DateTime.now());
      if (wait > Duration.zero) {
        _heldRow = row;
        _heldTimer?.cancel();
        _heldTimer = Timer(wait, () {
          final held = _heldRow;
          _heldRow = null;
          if (mounted && held != null) _onMatchRow(held);
        });
        return;
      }
    }

    final players = (row['players'] as List).cast<String>();
    final colors = (row['colors'] as List).cast<String>();
    final seat = players.indexOf(_myUserId);
    final myColor = seat < 0 ? null : LudoColor.values.byName(colors[seat]);

    final firstLoad = state.loading;
    state = state.copyWith(
      game: game,
      matchRow: row,
      myColor: myColor,
      loading: false,
      busy: false,
      clearError: true,
    );
    _restartTimerIfNew(row, game);
    _noticeCapture(game, firstLoad: firstLoad);
    if (row['status'] == 'active') _maybeReportResult(game);
  }

  /// Rows only ever move the game forward: more moves, or more rolls on the
  /// same move. Equal counts still apply (a player leaving changes state
  /// without either).
  bool _isNewer(Map<String, dynamic> row, LudoState game) {
    if (row['status'] != state.matchRow?['status']) return true;
    final turn = (row['turn_count'] as num?)?.toInt() ?? 0;
    final localTurn = (state.matchRow?['turn_count'] as num?)?.toInt() ?? 0;
    if (turn != localTurn) return turn > localTurn;
    return game.rollSeq >= state.game.rollSeq;
  }

  void _noticeCapture(LudoState game, {required bool firstLoad}) {
    final capture = game.capture;
    if (firstLoad) {
      // Captures from before we opened the match aren't news.
      _seenCaptureSeq = capture?.seq ?? 0;
      return;
    }
    if (capture == null || capture.seq <= _seenCaptureSeq) return;
    _seenCaptureSeq = capture.seq;
    state = state.copyWith(
      pendingReaction: PendingReaction(
        capture: capture,
        deadline: DateTime.now().add(kReactionWindow),
      ),
    );
    _reactionTimer?.cancel();
    _reactionTimer = Timer(kReactionWindow, () {
      if (mounted) state = state.copyWith(clearPendingReaction: true);
    });
  }

  void _maybeReportResult(LudoState game) {
    if (game.winner == null || _hasReportedResult) return;
    _hasReportedResult = true;
    _repository
        .reportMatchResult(
          matchId: _matchId,
          winnerId: state.userFor(game.winner!),
          result: 'win',
        )
        .catchError((_) => _hasReportedResult = false);
  }

  // ── chat ─────────────────────────────────────────────────────────────────

  void _onChat(List<Map<String, dynamic>> rows) {
    final messages = rows.map(ChatMessage.fromRow).toList();
    if (!_chatPrimed) {
      // The first batch is the conversation so far: shown in the chat,
      // but not unread, not speech bubbles, and old reactions don't replay.
      _chatPrimed = true;
      for (final m in messages) {
        if (m.id > _seenChatId) _seenChatId = m.id;
      }
      state = state.copyWith(chat: messages, chatBaseline: _seenChatId);
      return;
    }
    var unread = state.unread;
    for (final m in messages) {
      if (m.id <= _seenChatId) continue;
      _seenChatId = m.id;
      if (m.kind == 'reaction') {
        _onReaction(m);
      } else if (!_chatOpen && m.senderId != _myUserId) {
        unread++;
      }
    }
    state = state.copyWith(chat: messages, unread: unread);
  }

  void _onReaction(ChatMessage m) {
    final pending = state.pendingReaction;
    if (pending == null) return;
    if (state.userFor(pending.capture.by) != m.senderId) return;
    _startReaction(
      pending.capture,
      m.body == 'war' ? TokenReaction.war : TokenReaction.peace,
    );
  }

  void _startReaction(LudoCapture capture, TokenReaction kind) {
    _reactionTimer?.cancel();
    state = state.copyWith(
      clearPendingReaction: true,
      reaction: LudoTokenReaction(
        color: capture.by,
        token: capture.token,
        kind: kind,
        startedAt: LudoBoardView.clockNow(),
      ),
    );
  }

  void setChatOpen(bool open) {
    _chatOpen = open;
    if (open && state.unread != 0) state = state.copyWith(unread: 0);
  }

  /// Sends a chat message. Public games are filtered before sending (the
  /// server masks again). Returns an error message to show, or null.
  Future<String?> sendChat(String text, {String kind = 'text'}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final body = state.isFriendsGame ? trimmed : ChatFilter.filter(trimmed);
    try {
      await _repository.sendChat(matchId: _matchId, kind: kind, body: body);
      return null;
    } catch (e) {
      final message = e.toString();
      if (message.contains('slow down')) {
        return strings.ludoMatchWhoaSlowDownALittle;
      }
      return strings.ludoMatchCouldnTSendThatMessage;
    }
  }

  /// Uploads a recorded voice note and posts it to the chat. Returns an
  /// error message to show, or null.
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
      await _repository.uploadVoice(note.path, bytes);
      await _repository.sendChat(
        matchId: _matchId,
        kind: 'voice',
        body: note.encode(),
      );
      return null;
    } catch (e) {
      if (e.toString().contains('slow down')) {
        return strings.ludoMatchWhoaSlowDownALittle;
      }
      return strings.ludoMatchCouldnTSendYourVoice;
    }
  }

  /// The capturing player's choice: war or peace.
  Future<void> chooseReaction(TokenReaction kind) async {
    final pending = state.pendingReaction;
    if (pending == null || !state.playsHere(pending.capture.by)) return;
    _startReaction(pending.capture, kind);
    if (_isLocal) return;
    try {
      await _repository.sendChat(
        matchId: _matchId,
        kind: 'reaction',
        body: kind == TokenReaction.war ? 'war' : 'peace',
      );
    } catch (_) {
      // The reaction already played here; others just won't see it.
    }
  }

  void skipReaction() {
    _reactionTimer?.cancel();
    state = state.copyWith(clearPendingReaction: true);
  }

  // ── playing ──────────────────────────────────────────────────────────────

  Future<void> rollDice() async {
    if (!state.canRoll) return;
    // Rolling on instead of reacting to a capture.
    if (state.choosingReaction) skipReaction();
    final before = state.game;
    final dice = _engine.rollDie();
    final outcome = _engine.registerRoll(before, dice);

    if (outcome.forfeited || outcome.movableTokens.isEmpty) {
      await _showThenPass(before, dice, outcome, send: true);
      return;
    }

    final rolledAt = DateTime.now();
    _rolledAt = rolledAt;
    state = state.copyWith(game: outcome.state, busy: !_isLocal);
    _restartTimerIfNew(state.matchRow, outcome.state);
    if (!_isLocal) {
      try {
        await _repository.recordRoll(
          matchId: _matchId,
          state: outcome.state.toJson(),
        );
        state = state.copyWith(busy: false);
      } catch (_) {
        await _resync(strings.ludoMatchCouldnTSendYourRoll);
        return;
      }
    }

    // Only one real choice (one movable token, or several still sharing
    // the same spot, like all in base): move it once the die has landed.
    final options = outcome.movableTokens;
    final mine = outcome.state.tokens[outcome.state.turn]!;
    final positions = {for (final i in options) mine[i]};
    if (positions.length == 1) {
      // Counted from the tap, so a slow network doesn't add to the wait:
      // the die lands, the number holds a moment, then the piece goes.
      final wait =
          kDiceReveal + kDiceReadTime - DateTime.now().difference(rolledAt);
      _autoMove?.cancel();
      _autoMove = Timer(
        wait < const Duration(milliseconds: 120)
            ? const Duration(milliseconds: 120)
            : wait,
        () {
          if (mounted) selectToken(options.first);
        },
      );
    }
  }

  /// Offline, when the player's clock runs out, their turn plays itself:
  /// the roll, or the move a bot would make, so the table never stalls.
  void _playForMe() {
    if (state.canRoll) {
      rollDice();
      return;
    }
    final g = state.game;
    final dice = g.diceValue;
    final legal = state.movableTokens;
    if (!g.hasRolled || dice == null || legal.isEmpty) return;
    final pick = chooseLudoMove(g, dice, random: _rng);
    selectToken(legal.contains(pick) ? pick : legal.first);
  }

  /// A roll that can't be played (no piece can move, or a third six in a
  /// row): everyone sees the die land on it first, the number holds a
  /// moment, and only then does the turn pass. [send] puts the roll on the
  /// server (this player's own roll in an online game).
  Future<void> _showThenPass(
    LudoState before,
    int dice,
    LudoRollOutcome outcome, {
    required bool send,
  }) async {
    // On a third six nothing may move while it shows: no dice value.
    final shown = outcome.forfeited
        ? before.copyWith(
            rollSeq: outcome.state.rollSeq,
            lastRoll: outcome.state.lastRoll,
            hasRolled: true,
          )
        : outcome.state;
    final rolledAt = DateTime.now();
    _rolledAt = rolledAt;
    state = state.copyWith(game: shown, busy: send && !_isLocal);
    _restartTimerIfNew(state.matchRow, shown);
    if (send && !_isLocal) {
      try {
        await _repository.recordRoll(matchId: _matchId, state: shown.toJson());
        state = state.copyWith(busy: false);
      } catch (_) {
        await _resync(strings.ludoMatchCouldnTSendYourRoll);
        return;
      }
    }
    final wait =
        kDiceReveal + kNoMoveHold - DateTime.now().difference(rolledAt);
    if (wait > Duration.zero) await Future<void>.delayed(wait);
    if (!mounted) return;
    // Only if the board is still on this roll (a timeout or a resync may
    // have moved things on meanwhile).
    if (state.game.rollSeq != shown.rollSeq || state.game.turn != shown.turn) {
      return;
    }
    final next = outcome.forfeited
        ? outcome.state
        : _engine.passTurnNoMove(outcome.state);
    await _commitMove(
      next,
      diceValue: dice,
      tokenIndex: null,
      captured: false,
      reachedHome: false,
    );
  }

  Future<void> selectToken(int tokenIndex) async {
    _autoMove?.cancel();
    if (state.game.diceValue == null ||
        !state.movableTokens.contains(tokenIndex)) {
      return;
    }
    // A quick tap waits for the die: the roll shows before the piece moves.
    final early = kDiceReveal - DateTime.now().difference(_rolledAt);
    if (early > Duration.zero) {
      await Future<void>.delayed(early);
      if (!mounted) return;
    }
    final dice = state.game.diceValue;
    if (dice == null || !state.movableTokens.contains(tokenIndex)) return;
    final result = _engine.applyMove(state.game, tokenIndex, dice);
    await _commitMove(
      result.state,
      diceValue: dice,
      tokenIndex: tokenIndex,
      captured: result.captured,
      reachedHome: result.reachedHome,
    );
  }

  Future<void> _commitMove(
    LudoState next, {
    required int diceValue,
    required int? tokenIndex,
    required bool captured,
    required bool reachedHome,
  }) async {
    final turnNumber =
        ((state.matchRow?['turn_count'] as num?)?.toInt() ?? 0) + 1;
    if (_isLocal) {
      final winner = next.winner;
      state = state.copyWith(
        game: next,
        matchRow: {
          ...?state.matchRow,
          'turn_count': turnNumber,
          if (winner != null) ...{
            'status': 'completed',
            'winner_id': state.userFor(winner),
            'result': 'win',
          },
        },
      );
      _noticeCapture(next, firstLoad: false);
      _restartTimerIfNew(state.matchRow, next);
      return;
    }
    state = state.copyWith(
      game: next,
      busy: true,
      matchRow: {...?state.matchRow, 'turn_count': turnNumber},
    );
    _restartTimerIfNew(state.matchRow, next);
    _noticeCapture(next, firstLoad: false);
    try {
      await _repository.recordMove(
        matchId: _matchId,
        turnNumber: turnNumber,
        diceValue: diceValue,
        tokenIndex: tokenIndex,
        captured: captured,
        reachedHome: reachedHome,
        stateAfter: next.toJson(),
      );
      state = state.copyWith(busy: false);
      if (state.isActive) _maybeReportResult(next);
    } catch (_) {
      await _resync(strings.ludoMatchThatMoveDidnTGo);
    }
  }

  /// Throws away local guesses and reloads the match as the server has it.
  Future<void> _resync(String message) async {
    state = state.copyWith(error: message, busy: false);
    final row = await _repository.fetchMatch(_matchId).catchError((_) => null);
    if (row == null || !mounted) return;
    final game = LudoState.fromJson(row['state'] as Map<String, dynamic>);
    state = state.copyWith(game: game, matchRow: row, busy: false);
    _restartTimerIfNew(row, game);
  }

  /// Leaves the game for good (a forfeit). Offline, the game just ends.
  Future<void> leave() async {
    if (_isLocal) {
      _botTimer?.cancel();
      return;
    }
    await _repository.resignMatch(_matchId);
  }

  // ── bots (offline games) ─────────────────────────────────────────────────

  bool _isBot(LudoColor color) => isBotId(state.userFor(color));

  /// After every change in an offline game: if it's a bot's move, line up
  /// what it does next, at a human-ish pace so its rolls are easy to follow.
  void _driveBots() {
    if (!_isLocal || !mounted || _hiddenAt != null) return;
    final g = state.game;
    if (g.winner != null || !state.isActive) {
      _botTimer?.cancel();
      return;
    }
    // A bot that just captured picks war or peace first.
    final pending = state.pendingReaction;
    if (pending != null && _isBot(pending.capture.by)) {
      final key = 'react:${pending.capture.seq}';
      if (key == _botKey) return;
      _botKey = key;
      _botTimer?.cancel();
      _botTimer = Timer(Duration(milliseconds: 900 + _rng.nextInt(600)), () {
        if (!mounted) return;
        final p = state.pendingReaction;
        if (p == null || p.capture.seq != pending.capture.seq) return;
        _startReaction(
          p.capture,
          _rng.nextBool() ? TokenReaction.war : TokenReaction.peace,
        );
      });
      return;
    }
    if (!_isBot(g.turn)) return;
    final key =
        '${state.matchRow?['turn_count']}:${g.rollSeq}:${g.turn.name}:${g.hasRolled}';
    if (key == _botKey) return;
    _botKey = key;
    _botTimer?.cancel();
    if (!g.hasRolled) {
      // Long enough for everyone to see the last roll before the next.
      _botTimer = Timer(
        Duration(milliseconds: 1100 + _rng.nextInt(400)),
        _botRoll,
      );
    } else {
      _botTimer = Timer(
        kDiceReveal + kDiceReadTime + Duration(milliseconds: _rng.nextInt(300)),
        _botMove,
      );
    }
  }

  void _botRoll() {
    if (!mounted) return;
    final g = state.game;
    if (!_isBot(g.turn) || g.hasRolled || g.winner != null) return;
    // Wait for a reaction still being chosen.
    if (state.pendingReaction != null) {
      _botKey = null;
      _botTimer = Timer(const Duration(milliseconds: 500), _driveBots);
      return;
    }
    final dice = _engine.rollDie(_rng);
    final outcome = _engine.registerRoll(g, dice);
    if (outcome.forfeited || outcome.movableTokens.isEmpty) {
      _showThenPass(g, dice, outcome, send: false);
      return;
    }
    state = state.copyWith(game: outcome.state);
    _restartTimerIfNew(state.matchRow, outcome.state);
  }

  void _botMove() {
    if (!mounted) return;
    final g = state.game;
    final dice = g.diceValue;
    if (!_isBot(g.turn) || !g.hasRolled || dice == null) return;
    // A roll with no move is shown, then passes on its own.
    if (_engine.legalTokenMoves(g, dice).isEmpty) return;
    final token = chooseLudoMove(g, dice, random: _rng);
    final result = _engine.applyMove(g, token, dice);
    _commitMove(
      result.state,
      diceValue: dice,
      tokenIndex: token,
      captured: result.captured,
      reachedHome: result.reachedHome,
    );
  }

  @override
  void dispose() {
    // Leaving an offline game on purpose ends it (a closed app never gets
    // here, so that game comes back).
    if (_isLocal) _store?.clear(route: _localRoute);
    _revealTimer?.cancel();
    _heldTimer?.cancel();
    _matchSub?.cancel();
    _chatSub?.cancel();
    _reactionTimer?.cancel();
    _autoMove?.cancel();
    _turnClock?.cancel();
    _botTimer?.cancel();
    super.dispose();
  }
}

final ludoMatchControllerProvider = StateNotifierProvider.autoDispose
    .family<LudoMatchController, LudoMatchState, String>((ref, matchId) {
      final repository = ref.watch(ludoRepositoryProvider);
      final userId = ref.watch(currentUserProvider)?.id ?? '';
      final local = localLudoSetup(matchId);
      if (local != null) {
        return LudoMatchController.local(
          repository,
          matchId,
          local.humanId,
          local,
          store: ref.read(offlineGameStoreProvider),
        );
      }
      return LudoMatchController(repository, matchId, userId);
    });

/// A player's equipped Ludo piece set.
String pieceSetFor(Map<String, dynamic>? profile) =>
    profile?['equipped_ludo_pieces'] as String? ?? 'classic';
