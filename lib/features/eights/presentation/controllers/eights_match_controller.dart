import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/bots/bots.dart';
import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/widgets/game_card_art.dart';
import '../../../../l10n/strings.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../chat/domain/chat_filter.dart';
import '../../../chat/domain/chat_message.dart';
import '../../../chat/domain/voice_note.dart';
import '../../../home/data/offline_game.dart';
import '../../data/eights_repository.dart';
import '../../domain/eights_engine.dart';
import '../widgets/eights_table_view.dart';

final eightsRepositoryProvider = Provider<EightsRepository>(
  (ref) => EightsRepository(ref.watch(supabaseClientProvider)),
);

const _engine = EightsEngine();

/// Time for each action (a play, a draw, a pass) at a public table.
/// Matches the server's skip_eights_turn.
const kEightsTurnTime = Duration(seconds: 20);

/// Friends get longer to think.
const kEightsFriendsTurnTime = Duration(seconds: 40);

/// An offline game on this phone: who sits where. [humanId] is the phone's
/// owner; every other id is a bot.
class LocalEightsSetup {
  const LocalEightsSetup({required this.playerIds, required this.humanId});

  final List<String> playerIds;
  final String humanId;
}

final Map<String, LocalEightsSetup> _localGames = {};

/// Sets up an offline game; open it at `/eights/<id>`.
String startLocalEights(LocalEightsSetup setup) {
  final id = 'local-${DateTime.now().microsecondsSinceEpoch}';
  _localGames[id] = setup;
  return id;
}

LocalEightsSetup? localEightsSetup(String matchId) => _localGames[matchId];

/// Saved offline games to pick back up, every card where it was.
final Map<String, EightsGame> _localResume = {};

/// Brings back an offline game saved before the app closed (see
/// OfflineGame), ready to open at its route.
void restoreLocalEights(String route, Map<String, dynamic> data) {
  final id = route.split('/').last;
  final players = (data['players'] as List?)?.cast<String>();
  final human = data['human'] as String?;
  final game = data['game'];
  if (players == null || human == null || game is! Map) return;
  try {
    _localResume[id] = EightsGame.fromJson(game.cast<String, dynamic>());
  } catch (_) {
    return;
  }
  _localGames[id] = LocalEightsSetup(playerIds: players, humanId: human);
}

class EightsMatchState {
  const EightsMatchState({
    this.table,
    this.hand = const [],
    this.matchRow,
    this.mySeat,
    this.loading = true,
    this.busy = false,
    this.error,
    this.chat = const [],
    this.unread = 0,
    this.chatBaseline = -1,
    this.turnStartedAt,
  });

  final EightsTable? table;

  /// My cards.
  final List<PlayingCard> hand;
  final Map<String, dynamic>? matchRow;
  final int? mySeat;
  final bool loading;

  /// A move is on its way to the server.
  final bool busy;
  final String? error;
  final List<ChatMessage> chat;
  final int unread;

  /// The newest chat message already there when the game opened.
  final int chatBaseline;

  /// When the current action's clock started on this device.
  final DateTime? turnStartedAt;

  String get status => matchRow?['status'] as String? ?? 'active';
  bool get isActive => status == 'active';
  String get mode => matchRow?['mode'] as String? ?? 'public';
  bool get isLocal => mode == 'local';
  bool get isFriendsGame => mode == 'friends';
  int get stake => (matchRow?['stake'] as num?)?.toInt() ?? 0;
  int get pot => stake * playerIds.length;
  String? get winnerId => matchRow?['winner_id'] as String?;

  List<String> get playerIds =>
      (matchRow?['players'] as List?)?.cast<String>() ?? const [];

  String? userFor(int seat) =>
      seat >= 0 && seat < playerIds.length ? playerIds[seat] : null;

  int? seatOf(String userId) {
    final i = playerIds.indexOf(userId);
    return i < 0 ? null : i;
  }

  Duration get turnTime =>
      isFriendsGame || isLocal ? kEightsFriendsTurnTime : kEightsTurnTime;

  int missedTurns(int seat) =>
      ((matchRow?['missed_turns'] as Map?)?['$seat'] as num?)?.toInt() ?? 0;

  bool get iLeft => mySeat != null && (table?.left.contains(mySeat) ?? false);

  bool get isMyTurn {
    final t = table;
    return t != null &&
        mySeat == t.turn &&
        isActive &&
        !t.isOver &&
        !t.left.contains(mySeat);
  }

  /// Time left for the player on turn, or null when no clock is running.
  int? get turnMsLeft {
    final started = turnStartedAt;
    if (started == null || !isActive || (table?.isOver ?? true)) return null;
    final left =
        turnTime.inMilliseconds -
        DateTime.now().difference(started).inMilliseconds;
    return left < 0 ? 0 : left;
  }

  /// My cards that go on the pile now (none when it isn't my turn).
  Set<PlayingCard> get playable {
    final t = table;
    if (t == null || !isMyTurn || busy) return const {};
    return {
      for (final c in hand)
        if (t.canPlay(c)) c,
    };
  }

  bool get canDraw => isMyTurn && !busy && !(table?.drawn ?? true);

  /// Drawn, and free to pass.
  bool get canPass => isMyTurn && !busy && (table?.drawn ?? false);

  EightsMatchState copyWith({
    EightsTable? table,
    List<PlayingCard>? hand,
    Map<String, dynamic>? matchRow,
    int? mySeat,
    bool? loading,
    bool? busy,
    String? error,
    bool clearError = false,
    List<ChatMessage>? chat,
    int? unread,
    int? chatBaseline,
    DateTime? turnStartedAt,
  }) => EightsMatchState(
    table: table ?? this.table,
    hand: hand ?? this.hand,
    matchRow: matchRow ?? this.matchRow,
    mySeat: mySeat ?? this.mySeat,
    loading: loading ?? this.loading,
    busy: busy ?? this.busy,
    error: clearError ? null : (error ?? this.error),
    chat: chat ?? this.chat,
    unread: unread ?? this.unread,
    chatBaseline: chatBaseline ?? this.chatBaseline,
    turnStartedAt: turnStartedAt ?? this.turnStartedAt,
  );
}

/// Runs one game of Crazy Eights. Online, the server keeps the cards: moves
/// show here straight away and the server's answer (my new hand, the table
/// everyone sees) takes over. Offline, the whole game lives here and bots
/// take their turns.
class EightsMatchController extends StateNotifier<EightsMatchState> {
  EightsMatchController(this._repository, this._matchId, this._myUserId)
    : _local = null,
      _store = null,
      super(const EightsMatchState()) {
    _matchSub = _repository
        .watchMatch(_matchId)
        .listen(
          _onMatchRow,
          onError: (Object e) =>
              state = state.copyWith(error: strings.eightsConnectionLost),
        );
    _chatSub = _repository.watchChat(_matchId).listen(_onChat, onError: (_) {});
    _clock = Timer.periodic(
      const Duration(milliseconds: 400),
      (_) => _checkTurnTimer(),
    );
  }

  /// A game against bots on this phone.
  EightsMatchController.local(
    this._repository,
    this._matchId,
    this._myUserId,
    LocalEightsSetup setup, {
    Random? random,
    OfflineGameStore? store,
  }) : _local = setup,
       // ignore: prefer_initializing_formals
       _store = store,
       super(const EightsMatchState()) {
    _rng = random ?? Random();
    final me = setup.playerIds.indexOf(setup.humanId);
    // A game saved before the app closed carries on where it was.
    _game =
        _localResume.remove(_matchId) ??
        _engine.deal(
          setup.playerIds.length,
          random: _rng,
          firstTurn: _rng.nextInt(setup.playerIds.length),
        );
    state = EightsMatchState(
      table: _game!.table,
      hand: _game!.hands[me],
      mySeat: me,
      loading: false,
      matchRow: {
        'id': _matchId,
        'status': 'active',
        'mode': 'local',
        'stake': 0,
        'players': setup.playerIds,
        'missed_turns': <String, int>{},
      },
    );
    _restartClock();
    addListener((_) {
      _driveBots();
      _saveLocal();
    });
    _clock = Timer.periodic(
      const Duration(milliseconds: 400),
      (_) => _checkTurnTimer(),
    );
  }

  final EightsRepository _repository;
  final String _matchId;
  final String _myUserId;
  final LocalEightsSetup? _local;
  bool get _isLocal => _local != null;

  /// Where an offline game is saved after every move, so it comes back if
  /// the app closes.
  final OfflineGameStore? _store;
  String? _savedKey;

  String get _localRoute => '/eights/$_matchId';

  void _saveLocal() {
    final store = _store;
    final setup = _local;
    final game = _game;
    if (store == null || setup == null || game == null) return;
    final t = game.table;
    if (t.winner != null) {
      store.clear(route: _localRoute);
      return;
    }
    final key = '${t.seq}:${t.turn}:${t.drawn}:${t.drawCount}';
    if (key == _savedKey) return;
    _savedKey = key;
    store.save(
      OfflineGame(
        kind: GameKind.eights,
        route: _localRoute,
        opponent: 'bots',
        data: {
          'players': setup.playerIds,
          'human': setup.humanId,
          'game': game.toJson(),
        },
      ),
    );
  }

  Random _rng = Random();
  EightsGame? _game;

  StreamSubscription<Map<String, dynamic>?>? _matchSub;
  StreamSubscription<List<Map<String, dynamic>>>? _chatSub;
  Timer? _clock;
  Timer? _botTimer;
  Timer? _autoPass;
  int? _clockSeq;
  int _handSeq = -1;
  int _seenChatId = -1;
  bool _chatPrimed = false;
  bool _chatOpen = false;
  DateTime _lastSkip = DateTime.fromMillisecondsSinceEpoch(0);

  /// An offline game waits while the app is in the background.
  DateTime? _hiddenAt;

  // ── the table ────────────────────────────────────────────────────────────

  void _onMatchRow(Map<String, dynamic>? row) {
    if (row == null) {
      state = state.copyWith(loading: false, error: strings.eightsNotFound);
      return;
    }
    final table = EightsTable.fromJson(
      (row['state'] as Map).cast<String, dynamic>(),
    );
    final local = state.table;
    // Never back: a row older than what's showing (our own move already
    // shown) only brings what the server knows better.
    if (local != null && table.seq < local.seq && row['status'] == 'active') {
      return;
    }
    final players = (row['players'] as List).cast<String>();
    final seat = players.indexOf(_myUserId);
    state = state.copyWith(
      table: table,
      matchRow: row,
      mySeat: seat < 0 ? null : seat,
      loading: false,
      clearError: true,
    );
    _restartClock();
    // My count changed under me (the deal, a timeout's draw): fetch my
    // cards.
    if (seat >= 0 &&
        table.counts[seat] != state.hand.length &&
        _handSeq != table.seq) {
      _handSeq = table.seq;
      _refreshHand();
    }
  }

  Future<void> _refreshHand() async {
    try {
      final hand = await _repository.fetchHand(_matchId, _myUserId);
      if (mounted) state = state.copyWith(hand: hand);
    } catch (_) {}
  }

  void _restartClock() {
    final seq = state.table?.seq;
    if (seq == null || seq == _clockSeq) return;
    _clockSeq = seq;
    state = state.copyWith(turnStartedAt: DateTime.now());
  }

  /// Out of time: online, ask the server to move things on (my own phone
  /// asks first; the others give it a little longer). Offline, my turn
  /// plays itself: a card is drawn and the turn passes.
  void _checkTurnTimer() {
    if (!mounted || _hiddenAt != null || state.busy) return;
    final left = state.turnMsLeft;
    if (left == null) return;
    final overdue =
        DateTime.now().difference(state.turnStartedAt!).inMilliseconds -
        state.turnTime.inMilliseconds;
    if (overdue < (state.isMyTurn ? 300 : 2500)) return;
    final now = DateTime.now();
    if (now.difference(_lastSkip) < const Duration(milliseconds: 1500)) return;
    _lastSkip = now;
    if (_isLocal) {
      if (state.isMyTurn) {
        _apply(_engine.timeOut(_game!, state.mySeat!, random: _rng));
      }
      return;
    }
    _repository.skipTurn(_matchId, state.table!.seq).catchError((_) => false);
  }

  // ── my moves ─────────────────────────────────────────────────────────────

  /// Plays [card] (an eight names [suit]).
  Future<void> play(PlayingCard card, {CardSuit? suit}) async {
    final t = state.table;
    final seat = state.mySeat;
    if (t == null || seat == null || !state.playable.contains(card)) return;
    if (card.isEight && suit == null) return;
    _autoPass?.cancel();
    if (_isLocal) {
      _apply(_engine.play(_game!, seat, card, suit: suit));
      return;
    }
    final hand = [...state.hand]..remove(card);
    final out = hand.isEmpty;
    state = state.copyWith(
      busy: true,
      hand: hand,
      table: t.copyWith(
        counts: [...t.counts]..[seat] = hand.length,
        top: card,
        suit: card.isEight ? suit : card.suit,
        turn: out ? seat : t.nextSeat(seat),
        drawn: false,
        seq: t.seq + 1,
        last: EightsAction(
          seat: seat,
          kind: EightsActionKind.play,
          card: card,
          suit: card.isEight ? suit : null,
        ),
        winner: out ? seat : null,
      ),
    );
    _restartClock();
    try {
      final after = await _repository.play(_matchId, card, suit: suit);
      if (mounted) state = state.copyWith(busy: false, hand: after);
    } catch (e) {
      await _resync(strings.eightsThatCardDidntGo);
    }
  }

  /// Draws a card. If nothing in my hand goes after that, the turn passes
  /// on its own a moment later.
  Future<void> draw() async {
    final t = state.table;
    final seat = state.mySeat;
    if (t == null || seat == null || !state.canDraw) return;
    if (_isLocal) {
      _apply(_engine.draw(_game!, seat, random: _rng));
      _passIfStuck();
      return;
    }
    state = state.copyWith(busy: true);
    try {
      final hand = await _repository.draw(_matchId);
      if (!mounted) return;
      final now = state.table ?? t;
      state = state.copyWith(
        busy: false,
        hand: hand,
        table: now.seq > t.seq
            ? now
            : t.copyWith(
                counts: [...t.counts]..[seat] = hand.length,
                drawCount: max(0, t.drawCount - 1),
                drawn: true,
                seq: t.seq + 1,
                last: EightsAction(seat: seat, kind: EightsActionKind.draw),
              ),
      );
      _handSeq = state.table!.seq;
      _restartClock();
      _passIfStuck();
    } catch (e) {
      await _resync(strings.eightsCouldntDraw);
    }
  }

  /// Nothing to play after drawing: pass, once the drawn card has shown.
  void _passIfStuck() {
    if (!state.canPass || state.playable.isNotEmpty) return;
    _autoPass?.cancel();
    _autoPass = Timer(const Duration(milliseconds: 1100), () {
      if (mounted && state.canPass && state.playable.isEmpty) pass();
    });
  }

  Future<void> pass() async {
    final t = state.table;
    final seat = state.mySeat;
    if (t == null || seat == null || !state.canPass) return;
    _autoPass?.cancel();
    if (_isLocal) {
      _apply(_engine.pass(_game!, seat));
      return;
    }
    state = state.copyWith(
      busy: true,
      table: t.copyWith(
        turn: t.nextSeat(seat),
        drawn: false,
        seq: t.seq + 1,
        last: EightsAction(seat: seat, kind: EightsActionKind.pass),
      ),
    );
    _restartClock();
    try {
      await _repository.pass(_matchId);
      if (mounted) state = state.copyWith(busy: false);
    } catch (e) {
      await _resync(strings.eightsCouldntPass);
    }
  }

  /// Throws away what was shown and loads the game as the server has it.
  Future<void> _resync(String message) async {
    if (!mounted) return;
    state = state.copyWith(error: message, busy: false);
    try {
      final row = await _repository.fetchMatch(_matchId);
      final hand = await _repository.fetchHand(_matchId, _myUserId);
      if (!mounted || row == null) return;
      state = state.copyWith(
        table: EightsTable.fromJson(
          (row['state'] as Map).cast<String, dynamic>(),
        ),
        matchRow: row,
        hand: hand,
      );
      _restartClock();
    } catch (_) {}
  }

  /// Leaves for good (a forfeit). Offline, the game just ends.
  Future<void> leave() async {
    if (_isLocal) {
      _botTimer?.cancel();
      return;
    }
    await _repository.resign(_matchId);
  }

  // ── offline ──────────────────────────────────────────────────────────────

  /// Takes on [game] as the offline game's new state.
  void _apply(EightsGame game) {
    _game = game;
    final t = game.table;
    final winner = t.winner;
    state = state.copyWith(
      table: t,
      hand: game.hands[state.mySeat!],
      matchRow: {
        ...?state.matchRow,
        if (winner != null) ...{
          'status': 'completed',
          'winner_id': state.userFor(winner),
          'result': 'win',
        },
      },
    );
    _restartClock();
  }

  bool _isBot(int seat) => isBotId(state.userFor(seat));
  int? _botSeq;

  /// After every change offline: if a bot is on turn, it plays at a human
  /// pace: a moment to think, then a card, or a draw (and then a card or a
  /// pass).
  void _driveBots() {
    final t = state.table;
    if (!_isLocal || !mounted || _hiddenAt != null || t == null) return;
    if (t.isOver || !state.isActive || !_isBot(t.turn)) return;
    if (_botSeq == t.seq) return;
    _botSeq = t.seq;
    _botTimer?.cancel();
    // The very first move waits for the cards to be dealt out.
    final dealing = t.seq == 0
        ? kEightsDealCard * t.counts.fold<int>(0, (a, b) => a + b) +
              const Duration(milliseconds: 900)
        : Duration.zero;
    _botTimer = Timer(
      dealing +
          Duration(milliseconds: (t.drawn ? 700 : 1000) + _rng.nextInt(700)),
      _botAct,
    );
  }

  void _botAct() {
    if (!mounted) return;
    final g = _game!;
    final t = g.table;
    if (t.isOver || !_isBot(t.turn)) return;
    final seat = t.turn;
    final move = chooseEightsPlay(g.hands[seat], t, random: _rng);
    if (move != null) {
      _apply(_engine.play(g, seat, move.$1, suit: move.$2));
    } else if (!t.drawn) {
      _apply(_engine.draw(g, seat, random: _rng));
    } else {
      _apply(_engine.pass(g, seat));
    }
  }

  void appHidden() {
    if (!_isLocal || _hiddenAt != null) return;
    _hiddenAt = DateTime.now();
    _botTimer?.cancel();
    _botSeq = null;
  }

  void appShown() {
    final hidden = _hiddenAt;
    if (hidden == null || !mounted) return;
    _hiddenAt = null;
    final started = state.turnStartedAt;
    if (started != null) {
      final from = started.isAfter(hidden) ? started : hidden;
      state = state.copyWith(
        turnStartedAt: started.add(DateTime.now().difference(from)),
      );
    }
    _driveBots();
  }

  // ── chat ─────────────────────────────────────────────────────────────────

  void _onChat(List<Map<String, dynamic>> rows) {
    final messages = rows.map(ChatMessage.fromRow).toList();
    if (!_chatPrimed) {
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
      if (!_chatOpen && m.senderId != _myUserId) unread++;
    }
    state = state.copyWith(chat: messages, unread: unread);
  }

  void setChatOpen(bool open) {
    _chatOpen = open;
    if (open && state.unread != 0) state = state.copyWith(unread: 0);
  }

  Future<String?> sendChat(String text, {String kind = 'text'}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final body = state.isFriendsGame ? trimmed : ChatFilter.filter(trimmed);
    try {
      await _repository.sendChat(matchId: _matchId, kind: kind, body: body);
      return null;
    } catch (e) {
      if (e.toString().contains('slow down')) {
        return strings.ludoMatchWhoaSlowDownALittle;
      }
      return strings.ludoMatchCouldnTSendThatMessage;
    }
  }

  Future<String?> sendVoice(
    Uint8List bytes, {
    required int ms,
    required List<int> wave,
  }) async {
    final note = VoiceNote(
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

  @override
  void dispose() {
    // Leaving an offline game on purpose ends it (a closed app never gets
    // here, so that game comes back).
    if (_isLocal) _store?.clear(route: _localRoute);
    _matchSub?.cancel();
    _chatSub?.cancel();
    _clock?.cancel();
    _botTimer?.cancel();
    _autoPass?.cancel();
    super.dispose();
  }
}

final eightsMatchControllerProvider = StateNotifierProvider.autoDispose
    .family<EightsMatchController, EightsMatchState, String>((ref, matchId) {
      final repository = ref.watch(eightsRepositoryProvider);
      final local = localEightsSetup(matchId);
      if (local != null) {
        return EightsMatchController.local(
          repository,
          matchId,
          local.humanId,
          local,
          store: ref.read(offlineGameStoreProvider),
        );
      }
      return EightsMatchController(
        repository,
        matchId,
        ref.watch(currentUserProvider)?.id ?? '',
      );
    });
