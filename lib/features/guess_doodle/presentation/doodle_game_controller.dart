import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/strings.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../chat/domain/voice_note.dart';
import '../../doodle_studio/domain/art_doc.dart';
import '../data/doodle_game_repository.dart';
import '../domain/doodle_game.dart';
import '../domain/doodle_shapes.dart';
import 'doodle_ink.dart';

@immutable
class DoodleGameState {
  const DoodleGameState({
    this.game,
    this.players = const [],
    this.messages = const [],
    this.choices = const [],
    this.word,
    this.secretTurn = -1,
    this.clockOffset = Duration.zero,
    this.left = false,
    this.lastCorrect,
  });

  final DoodleGame? game;

  /// Everyone who's played in it, in drawing order (left ones included,
  /// marked).
  final List<DoodlePlayer> players;
  final List<DoodleMessage> messages;

  /// For the drawer while choosing: the three words.
  final List<String> choices;

  /// For the drawer: the word.
  final String? word;

  /// The turn [choices] and [word] belong to.
  final int secretTurn;

  /// Server clock minus this phone's.
  final Duration clockOffset;

  /// This player has left (or was never let in).
  final bool left;

  /// The player's latest right guess: its points and when, for the burst.
  final ({int points, DateTime at})? lastCorrect;

  DoodlePlayer? player(String? id) =>
      players.where((p) => p.userId == id).firstOrNull;

  List<DoodlePlayer> get active => [
    for (final p in players)
      if (!p.left) p,
  ];

  DoodleGameState copyWith({
    DoodleGame? game,
    List<DoodlePlayer>? players,
    List<DoodleMessage>? messages,
    List<String>? choices,
    String? word,
    bool clearWord = false,
    int? secretTurn,
    Duration? clockOffset,
    bool? left,
    ({int points, DateTime at})? lastCorrect,
  }) => DoodleGameState(
    game: game ?? this.game,
    players: players ?? this.players,
    messages: messages ?? this.messages,
    choices: choices ?? this.choices,
    word: clearWord ? null : (word ?? this.word),
    secretTurn: secretTurn ?? this.secretTurn,
    clockOffset: clockOffset ?? this.clockOffset,
    left: left ?? this.left,
    lastCorrect: lastCorrect ?? this.lastCorrect,
  );
}

/// One game of Guess My Doodle, seen from this phone: it follows the
/// server (game, players, chat), keeps the clock in step, checks in every
/// few seconds and at each deadline (which is what moves the game on), and
/// runs the drawing: the drawer's strokes go out live on the ink channel
/// and are saved; everyone else plays them back as they arrive and catches
/// up from the saved strokes if they miss any.
class DoodleGameController extends StateNotifier<DoodleGameState> {
  DoodleGameController(this._repo, this.gameId, this.me)
    : super(const DoodleGameState()) {
    _start();
  }

  final DoodleGameRepository _repo;
  final String gameId;
  final String? me;

  final ink = DoodleInk();

  StreamSubscription<DoodleGame?>? _gameSub;
  StreamSubscription<List<DoodlePlayer>>? _playersSub;
  StreamSubscription<List<DoodleMessage>>? _messagesSub;
  DoodleInkLink? _link;
  Timer? _heartbeat;
  Timer? _deadline;
  Timer? _resync;
  Timer? _flush;
  bool _disposed = false;

  /// The turn and phase a secret is being fetched for, so each is asked
  /// for once however many updates arrive meanwhile.
  String? _secretKey;
  final _random = math.Random();

  /// The drawer's next stroke number, and how many of its points went out.
  int _sid = 0;
  int _sent = 0;

  /// A shape being dragged out, and where the drag began.
  DoodleShape? _shape;
  Offset _shapeFrom = Offset.zero;

  DateTime get serverNow => DateTime.now().add(state.clockOffset);

  bool get isDrawer => me != null && state.game?.drawerId == me;

  bool get guessedThisTurn {
    final game = state.game;
    final p = state.player(me);
    return game != null && p != null && p.guessedTurn == game.turn;
  }

  void _start() {
    _gameSub = _repo.watchGame(gameId).listen(_onGame, onError: (_) {});
    _playersSub = _repo.watchPlayers(gameId).listen((players) {
      if (_disposed) return;
      // Shown straight away the first time; after that a live update only
      // says the players changed, and who has what comes from the
      // database (the live copies could hold someone's score at 0).
      if (state.players.isEmpty) {
        players.sort((a, b) => a.joinSeq.compareTo(b.joinSeq));
        state = state.copyWith(players: players);
      }
      _refreshPlayersSoon();
    }, onError: (_) {});
    _messagesSub = _repo.watchMessages(gameId).listen((messages) {
      if (!_disposed) state = state.copyWith(messages: messages);
    }, onError: (_) {});

    _link = _repo.inkLink(gameId)
      ..listen((event, data) {
        switch (event) {
          case 'ink':
            _onInk(data);
          case 'end':
            _onEnd(data);
          case 'spill':
            _onSpill(data);
          case 'undo':
            _onUndo(data);
          case 'clear':
            _onClear(data);
        }
      });

    _tick();
    _heartbeat = Timer.periodic(const Duration(seconds: 4), (_) => _tick());
  }

  // ── the server's side ────────────────────────────────────────────────────

  /// The players (and their scores) from the database. Live updates of
  /// other players' rows didn't always arrive, so their scores could sit
  /// at 0 on your screen: this keeps everyone's right, on every tick and
  /// whenever the turn or phase moves on.
  Timer? _playersTimer;

  void _refreshPlayersSoon() {
    _playersTimer?.cancel();
    _playersTimer = Timer(
      const Duration(milliseconds: 120),
      () => unawaited(_refreshPlayers()),
    );
  }

  Future<void> _refreshPlayers() async {
    try {
      final players = await _repo.fetchPlayers(gameId);
      if (_disposed || players.isEmpty) return;
      players.sort((a, b) => a.joinSeq.compareTo(b.joinSeq));
      state = state.copyWith(players: players);
    } catch (_) {}
  }

  Future<void> _tick() async {
    unawaited(_refreshPlayers());
    try {
      final now = await _repo.tick(gameId);
      if (_disposed || now == null) return;
      final offset = now.difference(DateTime.now());
      // Steady the offset: network delay swings it a little each time.
      final old = state.clockOffset;
      state = state.copyWith(
        clockOffset: old == Duration.zero
            ? offset
            : Duration(
                microseconds:
                    (old.inMicroseconds * 0.7 + offset.inMicroseconds * 0.3)
                        .round(),
              ),
      );
    } catch (e) {
      if (_disposed) return;
      if (e.toString().contains('not in this game') ||
          e.toString().contains('game not found')) {
        state = state.copyWith(left: true);
      }
    }
  }

  void _onGame(DoodleGame? game) {
    if (_disposed) return;
    if (game == null) {
      // Gone from view: removed, or this player isn't in it.
      if (state.game != null) state = state.copyWith(left: true);
      return;
    }
    final before = state.game;
    final newTurn = before == null || before.turn != game.turn;
    state = state.copyWith(
      game: game,
      choices: newTurn ? const [] : null,
      clearWord: newTurn,
      secretTurn: newTurn ? -1 : null,
    );
    // Scores change as a turn ends and a game finishes: fresh ones for
    // every new turn or phase (the reveal, the final standings).
    if (newTurn || before.phase != game.phase) unawaited(_refreshPlayers());

    // The canvas follows the turn and its clears.
    if (ink.turn != game.turn) {
      ink.reset(turn: game.turn, epoch: game.canvasEpoch, rev: 0);
      _sid = 0;
      if (game.canvasRev > 0) _refetch();
    } else if (ink.epoch != game.canvasEpoch) {
      ink.clear(epoch: game.canvasEpoch);
    }
    if (game.canvasRev > ink.rev) _scheduleResync();

    // The drawer finds out their words (and a guesser who got it, the
    // word).
    final drawing =
        game.phase == DoodlePhase.choosing || game.phase == DoodlePhase.drawing;
    if ((isDrawer || guessedThisTurn) && drawing) {
      final need = game.phase == DoodlePhase.choosing
          ? isDrawer && state.choices.isEmpty
          : state.word == null;
      if (need) _loadSecret();
    }

    _scheduleDeadline(game.phaseEndsAt);
  }

  Future<void> _loadSecret() async {
    final game = state.game;
    if (game == null) return;
    final key = '${game.turn}-${game.phase.name}';
    if (_secretKey == key) return;
    _secretKey = key;
    try {
      final secret = await _repo.secret(gameId);
      final now = state.game;
      if (_disposed || now == null || secret.turn != now.turn) return;
      state = state.copyWith(
        choices: secret.choices.isEmpty ? null : secret.choices,
        word: secret.word,
        secretTurn: secret.turn,
      );
    } catch (_) {
      // Ask again on the next update.
      if (_secretKey == key) _secretKey = null;
    }
  }

  /// Checks in just after a deadline so the game moves on on time. Each
  /// phone waits a slightly different moment, so they don't all arrive at
  /// once.
  void _scheduleDeadline(DateTime? at) {
    _deadline?.cancel();
    if (at == null) return;
    final wait =
        at.difference(serverNow) +
        Duration(milliseconds: 150 + _random.nextInt(450));
    if (wait > const Duration(minutes: 5)) return;
    _deadline = Timer(wait.isNegative ? Duration.zero : wait, _tick);
  }

  // ── guessing and chat ────────────────────────────────────────────────────

  /// Sends a guess or a chat line. Returns what the server made of it.
  Future<GuessResult> send(String text) async {
    final result = await _repo.guess(gameId, text);
    if (result.result == GuessResult.correct && !_disposed) {
      state = state.copyWith(
        lastCorrect: (points: result.points, at: DateTime.now()),
      );
      _loadSecret();
    }
    return result.result;
  }

  /// Whether this player may talk now: between turns anyone can; while
  /// someone draws, only those who know the word (the drawer, and anyone
  /// who's guessed it), heard only by each other.
  bool get canTalk {
    final phase = state.game?.phase;
    if (phase != DoodlePhase.choosing && phase != DoodlePhase.drawing) {
      return true;
    }
    return isDrawer || guessedThisTurn;
  }

  /// Uploads a recorded voice note and posts it. Returns an error to show,
  /// or null.
  Future<String?> sendVoice(
    Uint8List bytes, {
    required int ms,
    required List<int> wave,
  }) async {
    final note = VoiceNote(
      path: VoiceNote.newPath(gameId, wav: VoiceNote.isWav(bytes)),
      ms: ms,
      wave: wave,
    );
    try {
      await _repo.uploadVoice(note.path, bytes);
      await _repo.sendVoice(gameId, note);
      return null;
    } catch (e) {
      if (e.toString().contains('slow down')) {
        return strings.ludoMatchWhoaSlowDownALittle;
      }
      if (e.toString().contains('guess the word first')) {
        return strings.doodleVoiceAfterYouGuess;
      }
      return strings.ludoMatchCouldnTSendYourVoice;
    }
  }

  Future<void> choose(int index) async {
    await _repo.choose(gameId, index);
    _loadSecret();
  }

  Future<void> startGame() => _repo.start(gameId);

  Future<void> leave() async {
    if (state.left) return;
    state = state.copyWith(left: true);
    await _repo.leave(gameId);
  }

  // ── drawing (the drawer) ─────────────────────────────────────────────────

  bool get canDraw =>
      isDrawer &&
      state.game?.phase == DoodlePhase.drawing &&
      ink.turn == state.game?.turn;

  void strokeStart(Offset at, ArtTool tool, int color, double size) {
    if (!canDraw) return;
    _sid++;
    _sent = 0;
    ink.mine = LiveStroke(tool: tool, color: color, size: size)
      ..points.addAll([_r(at.dx), _r(at.dy), size]);
    ink.changed();
    _flush?.cancel();
    _flush = Timer.periodic(
      const Duration(milliseconds: 110),
      (_) => _sendPoints(),
    );
  }

  /// A line, box or circle dragged out from [at]: it shows as it's
  /// dragged, and goes to everyone whole when the finger lifts.
  void shapeStart(Offset at, DoodleShape shape, int color, double size) {
    if (!canDraw) return;
    _sid++;
    _shape = shape;
    _shapeFrom = Offset(_r(at.dx), _r(at.dy));
    ink.mine = LiveStroke(tool: ArtTool.marker, color: color, size: size)
      ..points.addAll(shapePoints(shape, _shapeFrom, _shapeFrom, size));
    ink.changed();
  }

  /// Paint poured into the shape at [at].
  void spill(Offset at, int color) {
    final game = state.game;
    if (!canDraw || game == null) return;
    final op = SpillOp(x: _r(at.dx), y: _r(at.dy), color: color);
    ink.add(op);
    final json = op.toJson();
    _broadcast('spill', {
      'by': me,
      'turn': game.turn,
      'epoch': ink.epoch,
      'op': json,
    });
    _save(game.turn, ink.epoch, json);
  }

  void strokeMove(Offset at) {
    final stroke = ink.mine;
    if (stroke == null) return;
    final shape = _shape;
    if (shape != null) {
      stroke.points
        ..clear()
        ..addAll(shapePoints(shape, _shapeFrom, at, stroke.size));
      ink.changed();
      return;
    }
    final n = stroke.points.length;
    final dx = at.dx - stroke.points[n - 3];
    final dy = at.dy - stroke.points[n - 2];
    // Skip points too close to the last to matter.
    if (dx * dx + dy * dy < 2.5) return;
    stroke.points.addAll([_r(at.dx), _r(at.dy), stroke.size]);
    ink.changed();
  }

  void strokeEnd() {
    final stroke = ink.mine;
    if (stroke == null) return;
    _flush?.cancel();
    _shape = null;
    ink.mine = null;
    final op = StrokeOp(
      tool: stroke.tool,
      color: stroke.color,
      size: stroke.size,
      points: stroke.points,
    );
    ink.add(op);
    final game = state.game;
    if (game == null) return;
    final json = op.toJson();
    _broadcast('end', {
      'by': me,
      'turn': game.turn,
      'epoch': ink.epoch,
      'sid': _sid,
      'op': json,
    });
    _save(game.turn, ink.epoch, json);
  }

  Future<void> _save(int turn, int epoch, Map<String, Object?> op) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final rev = await _repo.addStroke(
          gameId: gameId,
          turn: turn,
          epoch: epoch,
          op: op,
        );
        if (rev > ink.rev && ink.turn == turn) ink.rev = rev;
        return;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
      }
    }
  }

  void _sendPoints() {
    final stroke = ink.mine;
    final game = state.game;
    if (stroke == null || game == null) return;
    final total = stroke.length;
    if (total <= _sent) return;
    _broadcast('ink', {
      'by': me,
      'turn': game.turn,
      'epoch': ink.epoch,
      'sid': _sid,
      'tool': stroke.tool.name,
      'c': stroke.color,
      'w': stroke.size,
      'from': _sent,
      'p': stroke.points.sublist(_sent * 3),
    });
    _sent = total;
  }

  Future<void> undo() async {
    final game = state.game;
    if (!canDraw || game == null || !ink.canUndo) return;
    ink.undo();
    _broadcast('undo', {'by': me, 'turn': game.turn, 'epoch': ink.epoch});
    try {
      final rev = await _repo.undo(gameId);
      if (rev > ink.rev && ink.turn == game.turn) ink.rev = rev;
    } catch (_) {}
  }

  Future<void> clearCanvas() async {
    final game = state.game;
    if (!canDraw || game == null) return;
    ink.clear(epoch: ink.epoch + 1);
    _broadcast('clear', {'by': me, 'turn': game.turn, 'epoch': ink.epoch});
    try {
      final rev = await _repo.clear(gameId);
      if (rev > ink.rev && ink.turn == game.turn) ink.rev = rev;
    } catch (_) {}
  }

  void _broadcast(String event, Map<String, dynamic> payload) {
    _link?.send(event, payload);
  }

  // ── drawing (everyone else) ──────────────────────────────────────────────

  /// From the drawer, for this turn and canvas.
  bool _current(Map<String, dynamic> p) {
    final game = state.game;
    return game != null &&
        !isDrawer &&
        p['by'] == game.drawerId &&
        p['turn'] == ink.turn &&
        p['epoch'] == ink.epoch;
  }

  void _onInk(Map<String, dynamic> p) {
    if (_disposed || !_current(p)) return;
    final tool = ArtTool.values.where((t) => t.name == p['tool']).firstOrNull;
    final values = p['p'];
    if (tool == null || values is! List) return;
    ink.receivePoints(
      sid: (p['sid'] as num).toInt(),
      tool: tool,
      color: (p['c'] as num).toInt(),
      size: (p['w'] as num).toDouble(),
      from: (p['from'] as num).toInt(),
      values: [for (final v in values) (v as num).toDouble()],
    );
  }

  void _onEnd(Map<String, dynamic> p) {
    if (_disposed || !_current(p)) return;
    final op = p['op'];
    if (op is! Map) return;
    final stroke = StrokeOp.fromJson(Map<String, Object?>.from(op));
    if (stroke == null) return;
    ink.receiveDone((p['sid'] as num).toInt(), stroke);
  }

  void _onSpill(Map<String, dynamic> p) {
    if (_disposed || !_current(p)) return;
    final op = p['op'];
    if (op is! Map) return;
    final spill = SpillOp.fromJson(Map<String, Object?>.from(op));
    if (spill != null) ink.receiveSpill(spill);
  }

  void _onUndo(Map<String, dynamic> p) {
    if (_disposed || !_current(p)) return;
    ink.undo();
    ink.rev++;
  }

  void _onClear(Map<String, dynamic> p) {
    final game = state.game;
    if (_disposed || game == null || isDrawer || p['by'] != game.drawerId) {
      return;
    }
    if (p['turn'] != ink.turn) return;
    final epoch = (p['epoch'] as num?)?.toInt() ?? ink.epoch + 1;
    if (epoch <= ink.epoch) return;
    ink.clear(epoch: epoch);
    ink.rev++;
  }

  /// The game says the canvas has changed more than this copy has seen:
  /// give the broadcasts a moment, then load the saved strokes.
  void _scheduleResync() {
    if (_resync?.isActive ?? false) return;
    _resync = Timer(const Duration(milliseconds: 1500), () {
      final game = state.game;
      if (_disposed || game == null) return;
      if (game.canvasRev > ink.rev && !(isDrawer && ink.mine != null)) {
        _refetch();
      }
    });
  }

  Future<void> _refetch() async {
    final game = state.game;
    if (game == null) return;
    final turn = game.turn;
    final epoch = game.canvasEpoch;
    final rev = game.canvasRev;
    final changes = ink.changes;
    try {
      final rows = await _repo.strokes(
        gameId: gameId,
        turn: turn,
        epoch: epoch,
      );
      if (_disposed || ink.turn != turn) return;
      // Something was drawn, undone or cleared while it loaded: this copy
      // could be from before it (an undone stroke would come back, a new
      // one would vanish) and the canvas would stay unlike everyone
      // else's. Look again once things are quiet instead.
      if (ink.changes != changes) {
        _scheduleResync();
        return;
      }
      if (ink.epoch != epoch) ink.clear(epoch: epoch);
      // Counted as of when it was asked for: anything saved after that
      // shows up as the game's revision moving past it, and is loaded then.
      ink.replaceAll([
        for (final row in rows)
          if (ArtOp.fromJson(row) case final op?
              when op is StrokeOp || op is SpillOp)
            op,
      ], rev: rev);
    } catch (_) {}
  }

  static double _r(double v) => (v * 10).roundToDouble() / 10;

  @override
  void dispose() {
    // Off the game's screen means out of the game: the others shouldn't
    // wait for a player who's gone.
    if (!state.left) _repo.leave(gameId).ignore();
    _disposed = true;
    _gameSub?.cancel();
    _playersSub?.cancel();
    _playersTimer?.cancel();
    _messagesSub?.cancel();
    _heartbeat?.cancel();
    _deadline?.cancel();
    _resync?.cancel();
    _flush?.cancel();
    _link?.close().ignore();
    ink.dispose();
    super.dispose();
  }
}

final doodleGameControllerProvider = StateNotifierProvider.autoDispose
    .family<DoodleGameController, DoodleGameState, String>((ref, gameId) {
      return DoodleGameController(
        ref.watch(doodleGameRepositoryProvider),
        gameId,
        ref.watch(currentUserProvider)?.id,
      );
    });
