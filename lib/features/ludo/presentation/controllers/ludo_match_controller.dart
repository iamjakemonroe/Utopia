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

/// How long the players in a capture have to pick a reaction.
const kReactionWindow = Duration(seconds: 6);

/// Time for each action (a roll, then picking a token) in a public game.
/// Matches the server's skip_ludo_turn.
const kTurnTime = Duration(seconds: 15);

/// Friends' rooms get longer to think.
const kFriendsTurnTime = Duration(seconds: 40);

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

/// A capture waiting on its reactions: the player who captured picks war
/// or peace, and each player whose piece was sent home picks sad or again
/// (everyone else sees a thought bubble over each of them).
class PendingReaction {
  const PendingReaction({
    required this.capture,
    required this.deadline,
    this.done = const {},
  });

  final LudoCapture capture;
  final DateTime deadline;

  /// The players who've reacted (or passed on it).
  final Set<LudoColor> done;

  /// Everyone who can react: the one who captured, then each player who
  /// had a piece sent home.
  List<LudoColor> get reactors => [
    capture.by,
    for (final c in {for (final (color, _) in capture.victims) color})
      if (c != capture.by) c,
  ];

  /// [color] can still react to this capture.
  bool waitingOn(LudoColor color) =>
      !done.contains(color) &&
      reactors.contains(color) &&
      DateTime.now().isBefore(deadline);

  /// The piece [color] reacts on: the one that captured, or its first
  /// piece sent home.
  int tokenFor(LudoColor color) => color == capture.by
      ? capture.token
      : capture.victims.firstWhere((v) => v.$1 == color).$2;

  /// The reactions a player in this capture can pick from.
  static List<TokenReaction> choicesFor(bool capturer) => capturer
      ? const [TokenReaction.war, TokenReaction.peace]
      : const [TokenReaction.sad, TokenReaction.again];

  PendingReaction withDone(LudoColor color) => PendingReaction(
    capture: capture,
    deadline: deadline,
    done: {...done, color},
  );
}

/// How a reaction goes in the chat, and back.
const Map<TokenReaction, String> kReactionBodies = {
  TokenReaction.war: 'war',
  TokenReaction.peace: 'peace',
  TokenReaction.sad: 'sad',
  TokenReaction.again: 'again',
};

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
    this.reactions = const [],
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

  /// Reactions playing on the board now.
  final List<LudoTokenReaction> reactions;

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
    if (started == null || !isActive || game.isOver) return null;
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

  /// I've got all four pieces home: free to watch the rest or go.
  bool get iFinished => myColor != null && game.finished.contains(myColor);

  /// My finishing place (1 for first), or null while I'm racing.
  int? get myPlace => myColor == null ? null : game.placeOf(myColor!);

  /// Someone's finished but the others are still racing.
  bool get playingOn => isActive && game.finished.isNotEmpty && !game.isOver;

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
  bool get choosingReaction {
    final pending = pendingReaction;
    return pending != null &&
        playsHere(pending.capture.by) &&
        pending.waitingOn(pending.capture.by);
  }

  /// Players on this phone who had a piece sent home and can still react
  /// to it (tap the piece in its yard).
  List<LudoColor> get sentHomeChoosing {
    final pending = pendingReaction;
    if (pending == null) return const [];
    return [
      for (final c in pending.reactors.skip(1))
        if (playsHere(c) && pending.waitingOn(c)) c,
    ];
  }

  bool get canRoll =>
      isMyTurn && !game.hasRolled && !busy && rollShowing && !game.isOver;

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
    List<LudoTokenReaction>? reactions,
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
      reactions: reactions ?? this.reactions,
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
    if (g.isOver) {
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

  /// The bot reactions already lined up (`capture seq:color`).
  final Set<String> _botReacting = {};

  StreamSubscription<Map<String, dynamic>?>? _matchSub;
  StreamSubscription<List<Map<String, dynamic>>>? _chatSub;
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

    // Someone moved before their die had landed here: show the roll first
    // (a roll no piece could use holds longer, so everyone sees it).
    final shownAt = state.rollShownAt;
    if (!state.loading && shownAt != null && turn > localTurn) {
      final passed = _samePieces(game, state.game);
      final wait = shownAt
          .add(passed ? kNoMoveHold : kDiceReadTime)
          .difference(DateTime.now());
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
  }

  /// No piece moved between [a] and [b] (a roll that passed the turn).
  bool _samePieces(LudoState a, LudoState b) {
    for (final color in a.players) {
      final x = a.tokens[color], y = b.tokens[color];
      if (x == null || y == null || x.length != y.length) return false;
      for (var i = 0; i < x.length; i++) {
        if (x[i] != y[i]) return false;
      }
    }
    return true;
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

  /// Someone in the capture reacted: the one who captured (war or peace)
  /// or someone whose piece was sent home (sad or again).
  void _onReaction(ChatMessage m) {
    final pending = state.pendingReaction;
    final color = state.colorOf(m.senderId);
    if (pending == null || color == null) return;
    final kind = kReactionBodies.entries
        .where((e) => e.value == m.body)
        .firstOrNull
        ?.key;
    if (kind == null) return;
    final capturer = color == pending.capture.by;
    if (!PendingReaction.choicesFor(capturer).contains(kind)) return;
    _startReaction(color, kind);
  }

  /// [color] reacts with [kind] on its piece in the capture. Once everyone
  /// in it has, there's nothing left to wait for.
  void _startReaction(LudoColor color, TokenReaction kind) {
    final pending = state.pendingReaction;
    if (pending == null || !pending.waitingOn(color)) return;
    final now = LudoBoardView.clockNow();
    final after = pending.withDone(color);
    final allIn = after.reactors.every(after.done.contains);
    if (allIn) _reactionTimer?.cancel();
    state = state.copyWith(
      pendingReaction: allIn ? null : after,
      clearPendingReaction: allIn,
      reactions: [
        for (final r in state.reactions)
          if (now - r.startedAt < LudoTokenReaction.duration) r,
        LudoTokenReaction(
          color: color,
          token: pending.tokenFor(color),
          kind: kind,
          startedAt: now,
        ),
      ],
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

  /// A choice from a player on this phone: war or peace for the one who
  /// captured, sad or again for one sent home ([color], or the first one
  /// here still deciding).
  Future<void> chooseReaction(TokenReaction kind, {LudoColor? color}) async {
    final pending = state.pendingReaction;
    if (pending == null) return;
    final capturer = kind == TokenReaction.war || kind == TokenReaction.peace;
    final who = capturer
        ? pending.capture.by
        : (color ?? state.sentHomeChoosing.firstOrNull);
    if (who == null || !state.playsHere(who) || !pending.waitingOn(who)) {
      return;
    }
    _startReaction(who, kind);
    if (_isLocal) return;
    try {
      await _repository.sendChat(
        matchId: _matchId,
        kind: 'reaction',
        body: kReactionBodies[kind]!,
      );
    } catch (_) {
      // The reaction already played here; others just won't see it.
    }
  }

  /// The one who captured rolls on instead of reacting: they pass on it
  /// (anyone sent home can still react).
  void skipReaction() {
    final pending = state.pendingReaction;
    if (pending == null) return;
    final after = pending.withDone(pending.capture.by);
    if (after.reactors.every(after.done.contains)) {
      _reactionTimer?.cancel();
      state = state.copyWith(clearPendingReaction: true);
    } else {
      state = state.copyWith(pendingReaction: after);
    }
  }

  // ── playing ──────────────────────────────────────────────────────────────

  Future<void> rollDice() async {
    if (!state.canRoll) return;
    // Rolling on instead of reacting to a capture.
    if (state.choosingReaction) skipReaction();
    if (!_isLocal) {
      await _rollOnServer();
      return;
    }
    final before = state.game;
    final dice = _engine.rollDie();
    final outcome = _engine.registerRoll(before, dice);

    if (outcome.movableTokens.isEmpty) {
      await _showThenPass(dice, outcome);
      return;
    }

    final rolledAt = DateTime.now();
    _rolledAt = rolledAt;
    state = state.copyWith(game: outcome.state);
    _restartTimerIfNew(state.matchRow, outcome.state);
    _autoMoveIfOneChoice(rolledAt);
  }

  /// Online the server rolls (so no one can choose their number): the die
  /// tumbles here while it does, then lands on what came up. A roll no
  /// piece can use comes back with the turn already passed; the die shows
  /// it first, then the turn moves on.
  Future<void> _rollOnServer() async {
    final rolledAt = DateTime.now();
    _rolledAt = rolledAt;
    state = state.copyWith(busy: true);
    final Map<String, dynamic> row;
    try {
      row = await _repository.rollDice(_matchId);
    } catch (_) {
      await _resync(strings.ludoMatchCouldnTSendYourRoll);
      return;
    }
    if (!mounted) return;
    state = state.copyWith(busy: false);
    _onMatchRow(row);
    _autoMoveIfOneChoice(rolledAt);
  }

  /// Only one real choice (one movable token, or several still sharing the
  /// same spot, like all in base): move it once the die has landed.
  void _autoMoveIfOneChoice(DateTime rolledAt) {
    final g = state.game;
    final dice = g.diceValue;
    if (!state.isMyTurn || !g.hasRolled || dice == null) return;
    final options = _engine.legalTokenMoves(g, dice);
    final mine = g.tokens[g.turn]!;
    final positions = {for (final i in options) mine[i]};
    if (options.isNotEmpty && positions.length == 1) {
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

  /// Offline, a roll no piece can use: the die lands on it first, the number
  /// holds a moment, and only then does the turn pass. (Online the server
  /// passes it.)
  Future<void> _showThenPass(int dice, LudoRollOutcome outcome) async {
    final shown = outcome.state;
    final rolledAt = DateTime.now();
    _rolledAt = rolledAt;
    state = state.copyWith(game: shown);
    _restartTimerIfNew(state.matchRow, shown);
    final wait =
        kDiceReveal + kNoMoveHold - DateTime.now().difference(rolledAt);
    if (wait > Duration.zero) await Future<void>.delayed(wait);
    if (!mounted) return;
    // Only if the board is still on this roll (a timeout or a resync may
    // have moved things on meanwhile).
    if (state.game.rollSeq != shown.rollSeq || state.game.turn != shown.turn) {
      return;
    }
    final next = _engine.passTurnNoMove(outcome.state);
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
          // The first home wins; the game ends once no one's left to race.
          if (winner != null) ...{
            'winner_id': state.userFor(winner),
            'result': 'win',
          },
          if (next.isOver) 'status': 'completed',
        },
      );
      _noticeCapture(next, firstLoad: false);
      _restartTimerIfNew(state.matchRow, next);
      return;
    }
    // Online: shown straight away as this phone works it out; the server
    // works it out too, and what it sends back is the move that counts.
    state = state.copyWith(
      game: next,
      busy: true,
      matchRow: {...?state.matchRow, 'turn_count': turnNumber},
    );
    _restartTimerIfNew(state.matchRow, next);
    _noticeCapture(next, firstLoad: false);
    try {
      final row = await _repository.moveToken(
        matchId: _matchId,
        token: tokenIndex!,
      );
      if (!mounted) return;
      state = state.copyWith(busy: false);
      _onMatchRow(row);
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
  /// Someone who's finished just goes: their place (and any prize) is
  /// theirs whatever happens next.
  Future<void> leave() async {
    if (_isLocal) {
      _botTimer?.cancel();
      return;
    }
    if (state.iFinished) return;
    await _repository.resignMatch(_matchId);
  }

  // ── bots (offline games) ─────────────────────────────────────────────────

  bool _isBot(LudoColor color) => isBotId(state.userFor(color));

  /// After every change in an offline game: if it's a bot's move, line up
  /// what it does next, at a human-ish pace so its rolls are easy to follow.
  void _driveBots() {
    if (!_isLocal || !mounted || _hiddenAt != null) return;
    final g = state.game;
    if (g.isOver || !state.isActive) {
      _botTimer?.cancel();
      return;
    }
    // Bots in a capture react too: war or peace for the one that took a
    // piece, sad or again for one sent home (once it's back in its yard).
    final pending = state.pendingReaction;
    if (pending != null) {
      for (final color in pending.reactors) {
        if (!_isBot(color) || !pending.waitingOn(color)) continue;
        final key = '${pending.capture.seq}:${color.name}';
        if (!_botReacting.add(key)) continue;
        final capturer = color == pending.capture.by;
        Timer(
          Duration(milliseconds: (capturer ? 900 : 1500) + _rng.nextInt(700)),
          () {
            if (!mounted) return;
            final p = state.pendingReaction;
            if (p == null || p.capture.seq != pending.capture.seq) return;
            final choices = PendingReaction.choicesFor(capturer);
            _startReaction(color, choices[_rng.nextInt(choices.length)]);
          },
        );
      }
      // A bot that just captured picks first, then plays on.
      if (pending.waitingOn(pending.capture.by) && _isBot(pending.capture.by)) {
        return;
      }
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
    if (!_isBot(g.turn) || g.hasRolled || g.isOver) return;
    // Wait while the one who captured is still choosing (whoever was sent
    // home reacts while play goes on).
    if (state.pendingReaction?.waitingOn(state.pendingReaction!.capture.by) ??
        false) {
      _botKey = null;
      _botTimer = Timer(const Duration(milliseconds: 500), _driveBots);
      return;
    }
    final dice = _engine.rollDie(_rng);
    final outcome = _engine.registerRoll(g, dice);
    if (outcome.movableTokens.isEmpty) {
      _showThenPass(dice, outcome);
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
