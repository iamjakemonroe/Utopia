import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import '../../../core/audio/game_audio.dart';
import '../data/pool_repository.dart';
import '../domain/pool_aim.dart';
import '../domain/pool_bot.dart';
import '../domain/pool_cues.dart';
import '../domain/pool_physics.dart';
import '../domain/pool_rules.dart';
import 'pool_art.dart';
import 'pool_cue_art.dart';

/// Who's at the table: Chip at a coin table (the server referees), or two
/// people passing one phone.
enum PoolMode { table, passAndPlay }

/// What the table says after a shot (the screen words it).
enum PoolNews {
  yourTurn,
  theirTurn,
  foulScratch,
  foulNoContact,
  foulWrongBall,
  foulNoCushion,
  groupsSet,
  callPocket,
  ballInHand,

  /// The break: the cue ball may go anywhere behind the line.
  breakHint,
}

/// A ball dropping into a pocket, for its last moment on screen.
class PoolSink {
  PoolSink(this.ball, this.x, this.y, this.px, this.py);

  final int ball;

  /// Where it was when it dropped, and the pocket's middle.
  final double x, y, px, py;
  double t = 0;
}

/// A game of 8-ball: the game, the aim, and the shot in play. The screen
/// paints from it; [advance] moves the strike, the balls and the effects
/// on.
///
/// At a coin table the server holds the game: a shot plays out here at
/// once (the same physics, so it lands where the server's does) while the
/// server referees it, and the server's table is the one kept; Chip's
/// turns come from the server, and Chip lines each one up and strikes it
/// here. On one phone it's all here.
class PoolMatchController extends ChangeNotifier {
  /// Two people on this phone, both with [cue].
  PoolMatchController.passAndPlay({
    required this.cue,
    required this.cueLevel,
    this.audio,
    int? seed,
  }) : mode = PoolMode.passAndPlay,
       repository = null,
       chipCue = cue,
       chipCueLevel = cueLevel,
       game = PoolGame.rack(seed ?? math.Random().nextInt(1 << 30)) {
    shown = game.balls.copy();
    _ready();
    news = const [PoolNews.breakHint];
  }

  /// Chip at a coin table: [table] as the server holds it.
  PoolMatchController.table({
    required PoolTableGame table,
    required PoolRepository this.repository,
    this.audio,
  }) : mode = PoolMode.table,
       cue = poolCue(table.cueId),
       cueLevel = table.cueLevel,
       chipCue = poolCue(table.botCue),
       chipCueLevel = table.botCueLevel,
       game = table.state {
    _adopt(table);
    shown = game.balls.copy();
    _ready();
    if (game.breakShot && !chipsTurn) news = const [PoolNews.breakHint];
  }

  final PoolMode mode;
  final PoolRepository? repository;

  /// Where the table's sounds go (none in tests).
  final GameAudio? audio;

  /// The player's cue (both players' on one phone) and Chip's.
  PoolCue cue;
  int cueLevel;
  PoolCue chipCue;
  int chipCueLevel;

  PoolGame game;
  final spin = PoolSpin();
  final fx = PoolFx();

  /// The coin table's game, while playing one.
  String? gameId;
  String? tableId;
  int shots = 0;
  int entry = 0, prize = 0;

  /// 'active', 'won' or 'lost' at a coin table.
  String status = 'active';

  /// What went wrong reaching the server, for the screen to offer a retry.
  String? trouble;

  /// The aim (a unit vector), how hard (0 to 1, while pulling back), and
  /// where the tip strikes (-1 to 1 each way, within the ball's face).
  double aimX = 1, aimY = 0;
  double power = 0;
  double spinX = 0, spinY = 0;

  /// The pocket called for the 8, when the shot needs one.
  int? called;

  /// The strike in progress (0 to 1, the cue moving in), then the shot
  /// playing and where its playback is (seconds in).
  double? striking;
  PoolShot? _shot;
  PoolShotResult? playing;
  double playTime = 0;
  int _nextEvent = 0;

  /// How far the cue was drawn back when the strike began.
  double strikeFrom = 0;

  /// The seconds the table's been up (the cues' animation).
  double clock = 0;

  /// Balls dropping into pockets.
  final sinks = <PoolSink>[];

  /// Where the balls are drawn now: the playback's, or the game's.
  late PoolBalls shown;

  /// The news after the last shot, for the screen to show.
  List<PoolNews> news = const [];

  /// Chip thinking or lining up, so the player's controls wait.
  bool chipBusy = false;

  /// The server's answer to the player's shot, while it plays out here.
  Future<PoolRuling>? _ruling;

  /// Chip's shot, from the server, while it plays out here.
  PoolRuling? _chipRuling;

  /// How many shots landed somewhere else here than on the server (none,
  /// with the same physics: tests check).
  @visibleForTesting
  int mismatches = 0;
  bool _disposed = false;

  bool get atTable => mode == PoolMode.table;

  /// Whether the player to shoot is Chip.
  bool get chipsTurn => atTable && game.turn == 1;

  bool get over => game.over || status != 'active';

  /// Whether the player at this phone won (at a coin table).
  bool get won =>
      status == 'won' || (game.over && game.winner == 0 && status == 'active');

  /// Whether a person at this phone may aim and shoot now.
  bool get canPlay =>
      playing == null &&
      striking == null &&
      !over &&
      !chipsTurn &&
      !chipBusy &&
      trouble == null;

  /// Whether the cue ball is in hand and may be moved.
  bool get placing => canPlay && game.hand != PoolHand.none;

  /// Whether anything's moving on its own (so the screen keeps drawing).
  bool get moving =>
      playing != null ||
      striking != null ||
      sinks.isNotEmpty ||
      fx.busy ||
      chipBusy;

  /// The cue of whoever's shooting, and its level.
  PoolCue get shooterCue => chipsTurn ? chipCue : cue;
  int get shooterLevel => chipsTurn ? chipCueLevel : cueLevel;
  CueStats get shooterStats => shooterCue.at(shooterLevel);

  PoolAim get aim => poolAim(shown, aimX, aimY);

  void _adopt(PoolTableGame table) {
    gameId = table.id;
    tableId = table.tableId;
    shots = table.shots;
    entry = table.entry;
    prize = table.prize;
    status = table.status;
    game = table.state;
    cue = poolCue(table.cueId);
    cueLevel = table.cueLevel;
    chipCue = poolCue(table.botCue);
    chipCueLevel = table.botCueLevel;
  }

  /// The table set for whoever's to shoot: the cue ball out where it can
  /// be struck, the aim at the rack.
  void _ready() {
    if (!game.over && game.hand != PoolHand.none && !game.balls.on[kCueBall]) {
      final (x, y) = _freeSpot(game);
      game = game.placeCue(x, y);
      shown = game.balls.copy();
    }
    _aimAtRack();
  }

  /// Points the cue at ([x], [y]) on the table.
  void aimAt(double x, double y) {
    final dx = x - shown.x[kCueBall], dy = y - shown.y[kCueBall];
    final l = math.sqrt(dx * dx + dy * dy);
    if (l < 1e-6) return;
    aimX = dx / l;
    aimY = dy / l;
    notifyListeners();
  }

  /// Turns the aim by [radians] (fine aiming).
  void nudge(double radians) {
    final c = math.cos(radians), s = math.sin(radians);
    final x = aimX * c - aimY * s, y = aimX * s + aimY * c;
    final l = math.sqrt(x * x + y * y);
    aimX = x / l;
    aimY = y / l;
    notifyListeners();
  }

  void setPower(double value) {
    power = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  /// Where the tip strikes: kept within the ball's face.
  void setSpin(double x, double y) {
    final l = math.sqrt(x * x + y * y);
    final k = l > 1 ? 1 / l : 1.0;
    spinX = x * k;
    spinY = y * k;
    notifyListeners();
  }

  void callPocket(int pocket) {
    called = pocket;
    notifyListeners();
  }

  /// Moves the cue ball (in hand) to ([x], [y]), if it may go there.
  bool placeCue(double x, double y) {
    if (!placing || !game.canPlace(x, y)) return false;
    game = game.placeCue(x, y);
    shown = game.balls.copy();
    notifyListeners();
    return true;
  }

  /// Shoots at the power set. Needs a called pocket when on the 8.
  bool shoot() {
    if (!canPlay || power < 0.02) return false;
    if (!game.balls.on[kCueBall]) return false;
    if (game.callsPocket && called == null) {
      news = const [PoolNews.callPocket];
      notifyListeners();
      return false;
    }
    final shot = PoolShot(
      dx: aimX,
      dy: aimY,
      power: power,
      spinX: spinX,
      spinY: spinY,
    );
    final repository = this.repository;
    if (atTable && repository != null) {
      final ruling = repository.shoot(
        gameId: gameId!,
        shots: shots,
        shot: shot,
        place: game.hand == PoolHand.none
            ? null
            : (game.balls.x[kCueBall], game.balls.y[kCueBall]),
        called: game.callsPocket ? called : null,
      );
      // Its error is read when the shot's played out.
      ruling.ignore();
      _ruling = ruling;
    }
    _strike(shot);
    return true;
  }

  /// The cue goes in: [advance] carries the strike to the ball, then the
  /// shot plays.
  void _strike(PoolShot shot) {
    _shot = shot;
    strikeFrom = power;
    striking = 0;
    news = const [];
    notifyListeners();
  }

  void _contact() {
    final shot = _shot!;
    final stats = shooterStats;
    final result = simulateShot(
      game.balls,
      shot,
      maxSpeed: stats.maxSpeed,
      tipOffset: stats.tipOffset,
    );
    audio?.play(
      game.breakShot ? Sfx.poolBreak : Sfx.poolCue,
      volume: 0.4 + 0.6 * shot.power,
    );
    fx.strike(
      shooterCue,
      shooterLevel,
      game.balls.x[kCueBall],
      game.balls.y[kCueBall],
      shot.dx,
      shot.dy,
      shot.power,
    );
    striking = null;
    playing = result;
    playTime = 0;
    _nextEvent = 0;
    power = 0;
  }

  /// Moves things on by [dt] seconds (the screen's ticker).
  void advance(double dt) {
    clock += dt;
    fx.advance(dt);
    for (final s in sinks) {
      s.t += dt / 0.32;
    }
    sinks.removeWhere((s) => s.t >= 1);

    final strike = striking;
    if (strike != null) {
      // The cue goes in quicker the harder the shot.
      final next = strike + dt / (0.16 - 0.07 * strikeFrom);
      if (next >= 1) {
        _contact();
      } else {
        striking = next;
      }
      notifyListeners();
      return;
    }

    final result = playing;
    if (result == null) {
      if (fx.trail.isNotEmpty) fx.fadeTrail();
      if (fx.busy || sinks.isNotEmpty) notifyListeners();
      return;
    }
    playTime += dt;
    final f = playTime * PoolShotResult.framesPerSecond;
    final i = f.floor();
    if (i >= result.frameCount - 1) {
      _show(result, result.frameCount - 1, 0);
      _events(result, double.infinity);
      playing = null;
      notifyListeners();
      unawaited(_finish(result));
      return;
    }
    _show(result, i, f - i);
    _events(result, playTime);
    fx.follow(shown.x[kCueBall], shown.y[kCueBall]);
    notifyListeners();
  }

  /// The balls at frame [i] (and [k] of the way to the next), rolled on
  /// from where they were drawn.
  void _show(PoolShotResult r, int i, double k) {
    const stride = 2 * kBalls;
    final a = i * stride, b = math.min(i + 1, r.frameCount - 1) * stride;
    final next = PoolBalls.empty();
    for (var ball = 0; ball < kBalls; ball++) {
      final ax = r.frames[a + 2 * ball], ay = r.frames[a + 2 * ball + 1];
      if (ax.isNaN) continue;
      final bx = r.frames[b + 2 * ball], by = r.frames[b + 2 * ball + 1];
      final x = bx.isNaN ? ax : ax + (bx - ax) * k;
      final y = by.isNaN ? ay : ay + (by - ay) * k;
      next.x[ball] = x;
      next.y[ball] = y;
      next.on[ball] = true;
      if (shown.on[ball]) spin.roll(ball, x - shown.x[ball], y - shown.y[ball]);
    }
    shown = next;
  }

  /// The shot's sounds and sights up to [until] seconds in.
  void _events(PoolShotResult r, double until) {
    final audio = this.audio;
    while (_nextEvent < r.events.length && r.events[_nextEvent].time <= until) {
      final e = r.events[_nextEvent++];
      final loud = (e.speed / 3).clamp(0.08, 1.0);
      switch (e.kind) {
        case PoolEventKind.ball:
          audio?.play(Sfx.poolClick, volume: loud);
        case PoolEventKind.cushion:
          audio?.play(Sfx.poolCushion, volume: loud * 0.8);
        case PoolEventKind.pocket:
          audio?.play(Sfx.poolPocket, volume: 0.9);
          final pocket = kPockets[e.b];
          // Where it was the frame before it dropped.
          final f = ((e.time * PoolShotResult.framesPerSecond).floor() - 1)
              .clamp(0, r.frameCount - 1);
          final x = r.frames[f * 2 * kBalls + 2 * e.a],
              y = r.frames[f * 2 * kBalls + 2 * e.a + 1];
          sinks.add(
            PoolSink(
              e.a,
              x.isNaN ? pocket.x : x,
              y.isNaN ? pocket.y : y,
              pocket.x,
              pocket.y,
            ),
          );
          if (e.a != kCueBall) {
            fx.pocket(shooterCue, shooterLevel, pocket.x, pocket.y);
          }
      }
    }
  }

  Future<void> _finish(PoolShotResult result) async {
    final before = game;
    var next = game.after(result, called: called);

    if (atTable) {
      final PoolRuling? ruling;
      if (before.turn == 1) {
        ruling = _chipRuling;
      } else {
        try {
          ruling = await _ruling;
        } on PoolRefused catch (e) {
          if (_disposed) return;
          await _catchUp(e.conflict ? null : e.message);
          return;
        } catch (e) {
          if (_disposed) return;
          await _catchUp('$e');
          return;
        }
      }
      if (_disposed) return;
      _ruling = null;
      _chipRuling = null;
      if (ruling != null) {
        if (!_sameTable(ruling.state, next)) {
          mismatches++;
          debugPrint(
            'pool: the table settled differently on the server; keeping its',
          );
        }
        next = ruling.state;
        shots = ruling.shots;
        status = ruling.status;
        if (ruling.status == 'won') prize = ruling.prize;
      }
    }
    _settle(before, next);
  }

  /// [next] is the game now: the news, the sounds, and whose turn.
  void _settle(PoolGame before, PoolGame next) {
    game = next;
    called = null;
    shown = game.balls.copy();
    spinX = spinY = 0;
    news = [
      for (final f in game.lastFouls)
        switch (f) {
          PoolFoul.scratch => PoolNews.foulScratch,
          PoolFoul.noContact => PoolNews.foulNoContact,
          PoolFoul.wrongBall => PoolNews.foulWrongBall,
          PoolFoul.noCushion => PoolNews.foulNoCushion,
        },
      if (before.open && !game.open) PoolNews.groupsSet,
      if (!game.over && game.hand != PoolHand.none && !chipsTurn)
        PoolNews.ballInHand,
      if (!game.over && game.turn != before.turn)
        chipsTurn ? PoolNews.theirTurn : PoolNews.yourTurn,
    ];
    if (over) {
      final iLost = atTable ? !won : false;
      audio?.play(iLost ? Sfx.lose : Sfx.win);
    } else {
      _ready();
    }
    notifyListeners();
    if (chipsTurn && !over) unawaited(_chipPlays());
  }

  /// Whether two tables have every ball in the same place (as far as a
  /// player could see).
  static bool _sameTable(PoolGame a, PoolGame b) {
    if (a.turn != b.turn || a.winner != b.winner) return false;
    for (var i = 0; i < kBalls; i++) {
      if (a.balls.on[i] != b.balls.on[i]) return false;
      if (!a.balls.on[i]) continue;
      if ((a.balls.x[i] - b.balls.x[i]).abs() > 1e-6) return false;
      if ((a.balls.y[i] - b.balls.y[i]).abs() > 1e-6) return false;
    }
    return true;
  }

  /// The server's game again, after a shot it turned down or couldn't be
  /// reached about: [problem] for the screen (null when the table had
  /// simply moved on and catching up is enough).
  Future<void> _catchUp(String? problem) async {
    final repository = this.repository;
    final id = gameId;
    if (repository == null || id == null) return;
    try {
      final table = await repository.game(id);
      if (_disposed) return;
      final before = game;
      _adopt(table);
      trouble = null;
      _ruling = null;
      _chipRuling = null;
      chipBusy = false;
      _settle(before, table.state);
    } catch (e) {
      if (_disposed) return;
      trouble = problem ?? '$e';
      chipBusy = false;
      shown = game.balls.copy();
      notifyListeners();
    }
  }

  /// Tries the server again after [trouble].
  Future<void> retry() async {
    trouble = null;
    notifyListeners();
    await _catchUp(null);
  }

  /// Points at the middle of the balls the shooter may hit (a fresh aim
  /// after the cue ball moves).
  void _aimAtRack() {
    var x = 0.0, y = 0.0, n = 0;
    final targets = game.targets;
    for (final i
        in targets.isEmpty ? [for (var b = 1; b < kBalls; b++) b] : targets) {
      if (!game.balls.on[i]) continue;
      x += game.balls.x[i];
      y += game.balls.y[i];
      n++;
    }
    if (n == 0) return;
    final cx = game.balls.on[kCueBall] ? game.balls.x[kCueBall] : kHeadSpot.$1;
    final cy = game.balls.on[kCueBall] ? game.balls.y[kCueBall] : kHeadSpot.$2;
    final dx = x / n - cx, dy = y / n - cy;
    final l = math.sqrt(dx * dx + dy * dy);
    if (l > 1e-6) {
      aimX = dx / l;
      aimY = dy / l;
    }
  }

  /// Somewhere the cue ball may go, in hand: the head spot, else the
  /// first free place.
  static (double, double) _freeSpot(PoolGame game) {
    final (hx, hy) = kHeadSpot;
    if (game.canPlace(hx, hy)) return (hx, hy);
    final maxX = game.hand == PoolHand.kitchen
        ? kHeadString - 0.01
        : kPoolLength - kBallRadius;
    for (var i = 0; i < 400; i++) {
      final x = kBallRadius + (i % 20) / 19 * (maxX - kBallRadius);
      final y = kBallRadius + (i ~/ 20) / 19 * (kPoolWidth - 2 * kBallRadius);
      if (game.canPlace(x, y)) return (x, y);
    }
    return (hx, hy);
  }

  /// Chip's turn: the server works it out, then Chip places the cue ball
  /// if it's in hand, lines up, pulls back and strikes, as a person would.
  Future<void> _chipPlays() async {
    final repository = this.repository;
    if (repository == null || chipBusy) return;
    chipBusy = true;
    notifyListeners();
    final started = DateTime.now();
    final PoolRuling ruling;
    try {
      ruling = await repository.chip(gameId: gameId!, shots: shots);
    } on PoolRefused catch (e) {
      chipBusy = false;
      if (!_disposed) await _catchUp(e.conflict ? null : e.message);
      return;
    } catch (e) {
      chipBusy = false;
      if (!_disposed) await _catchUp('$e');
      return;
    }
    final move = ruling.move;
    if (move == null) {
      chipBusy = false;
      if (!_disposed) await _catchUp(null);
      return;
    }
    // A moment's thought, however quick the server was.
    final waited = DateTime.now().difference(started);
    if (waited < const Duration(milliseconds: 900)) {
      await Future<void>.delayed(const Duration(milliseconds: 900) - waited);
    }
    if (_disposed) return;
    if (move.cueX != null &&
        game.hand != PoolHand.none &&
        game.canPlace(move.cueX!, move.cueY!)) {
      game = game.placeCue(move.cueX!, move.cueY!);
      shown = game.balls.copy();
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 380));
    }
    _chipRuling = ruling;
    await _swing(move);
  }

  /// Turns the cue to [move]'s aim, pulls back and strikes.
  Future<void> _swing(PoolBotMove move) async {
    final from = math.atan2(aimY, aimX),
        to = math.atan2(move.shot.dy, move.shot.dx);
    var turn = to - from;
    while (turn > math.pi) {
      turn -= 2 * math.pi;
    }
    while (turn < -math.pi) {
      turn += 2 * math.pi;
    }
    const steps = 26;
    for (var s = 1; s <= steps; s++) {
      if (_disposed) return;
      final k = Curves.easeInOutCubic.transform(s / steps);
      aimX = math.cos(from + turn * k);
      aimY = math.sin(from + turn * k);
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 22));
    }
    aimX = move.shot.dx;
    aimY = move.shot.dy;
    spinX = move.shot.spinX;
    spinY = move.shot.spinY;
    called = move.called;
    for (var s = 1; s <= 16; s++) {
      if (_disposed) return;
      power = move.shot.power * Curves.easeOut.transform(s / 16);
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 28));
    }
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (_disposed) return;
    chipBusy = false;
    _strike(move.shot);
  }

  /// The player gives up: at a coin table Chip wins (the server's told);
  /// on one phone, the player to shoot loses.
  Future<void> resign() async {
    if (over) return;
    final repository = this.repository;
    if (atTable && repository != null) {
      await repository.resign(gameId!);
      status = 'lost';
      game = game.copyWith(winner: 1, win: PoolWin.resign);
    } else {
      game = game.resign();
    }
    audio?.play(atTable ? Sfx.lose : Sfx.win);
    notifyListeners();
  }

  /// Another game: at a coin table, the same table (its entry paid again);
  /// on one phone, a new rack with the loser breaking. Returns what went
  /// wrong, or null.
  Future<String?> playAgain() async {
    final repository = this.repository;
    if (atTable && repository != null) {
      try {
        final table = await repository.start(tableId!);
        if (_disposed) return null;
        _adopt(table);
      } on PoolRefused catch (e) {
        return e.message;
      }
    } else {
      final breaker = game.winner == null ? 0 : 1 - game.winner!;
      game = PoolGame.rack(math.Random().nextInt(1 << 30), breaker: breaker);
    }
    shown = game.balls.copy();
    playing = null;
    striking = null;
    news = const [];
    called = null;
    trouble = null;
    power = spinX = spinY = 0;
    _ready();
    notifyListeners();
    start();
    return null;
  }

  /// Starts things off (Chip's turn, when it's Chip's to take).
  void start() {
    if (chipsTurn && !over) unawaited(_chipPlays());
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
