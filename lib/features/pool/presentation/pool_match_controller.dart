import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import '../../../core/audio/game_audio.dart';
import '../../chess/domain/chess_bot.dart' show BotLevel;
import '../domain/pool_aim.dart';
import '../domain/pool_bot.dart';
import '../domain/pool_bot_runner.dart';
import '../domain/pool_physics.dart';
import '../domain/pool_rules.dart';
import 'pool_art.dart';

/// Who's at the table: against Chip, or two people passing one device.
enum PoolMode { chip, passAndPlay }

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
}

/// A game of 8-ball on this device: the game, the aim and the shot in
/// play. The screen paints from it; [time] moves a shot's playback.
class PoolMatchController extends ChangeNotifier {
  PoolMatchController({
    required this.mode,
    this.level = BotLevel.normal,
    this.audio,
    int? seed,
  }) : game = PoolGame.rack(seed ?? math.Random().nextInt(1 << 30)) {
    _aimAtRack();
  }

  final PoolMode mode;
  final BotLevel level;

  /// Where the table's sounds go (none in tests).
  final GameAudio? audio;

  PoolGame game;
  final spin = PoolSpin();

  /// The aim (a unit vector), how hard (0 to 1, while pulling back), and
  /// where the tip strikes (-1 to 1 each way).
  double aimX = 1, aimY = 0;
  double power = 0;
  double spinX = 0, spinY = 0;

  /// The pocket called for the 8, when the shot needs one.
  int? called;

  /// The shot playing, and where its playback is (seconds in).
  PoolShotResult? playing;
  double playTime = 0;
  int _nextEvent = 0;

  /// Where the balls are drawn now: the playback's, or the game's.
  late PoolBalls shown = game.balls.copy();

  /// The news after the last shot, for the screen to show.
  List<PoolNews> news = const [];

  /// Chip thinking (or lining up), so the player's controls wait.
  bool chipBusy = false;
  bool _disposed = false;

  /// Whether the player to shoot is Chip.
  bool get chipsTurn => mode == PoolMode.chip && game.turn == 1;

  /// Whether a person at this device may aim and shoot now.
  bool get canPlay => playing == null && !game.over && !chipsTurn && !chipBusy;

  /// Whether the cue ball is in hand and may be moved.
  bool get placing => canPlay && game.hand != PoolHand.none;

  PoolAim get aim => poolAim(shown, aimX, aimY);

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
    _play(PoolShot(dx: aimX, dy: aimY, power: power, spinX: spinX, spinY: spinY));
    return true;
  }

  void _play(PoolShot shot) {
    final result = simulateShot(game.balls, shot);
    audio?.play(game.breakShot ? Sfx.poolBreak : Sfx.poolCue, volume: 0.4 + 0.6 * shot.power);
    playing = result;
    playTime = 0;
    _nextEvent = 0;
    power = 0;
    news = const [];
    notifyListeners();
  }

  /// Moves the playback on by [dt] seconds (the screen's ticker).
  void advance(double dt) {
    final result = playing;
    if (result == null) return;
    playTime += dt;
    final f = playTime * PoolShotResult.framesPerSecond;
    final i = f.floor();
    if (i >= result.frameCount - 1) {
      _show(result, result.frameCount - 1, 0);
      _sounds(result, double.infinity);
      _finish(result);
      return;
    }
    _show(result, i, f - i);
    _sounds(result, playTime);
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

  void _sounds(PoolShotResult r, double until) {
    final audio = this.audio;
    while (_nextEvent < r.events.length && r.events[_nextEvent].time <= until) {
      final e = r.events[_nextEvent++];
      if (audio == null) continue;
      final loud = (e.speed / 3).clamp(0.08, 1.0);
      switch (e.kind) {
        case PoolEventKind.ball:
          audio.play(Sfx.poolClick, volume: loud);
        case PoolEventKind.cushion:
          audio.play(Sfx.poolCushion, volume: loud * 0.8);
        case PoolEventKind.pocket:
          audio.play(Sfx.poolPocket, volume: 0.9);
      }
    }
  }

  void _finish(PoolShotResult result) {
    final before = game;
    game = game.after(result, called: called);
    playing = null;
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
      if (!game.over && game.turn != before.turn)
        mode == PoolMode.chip && game.turn == 1 ? PoolNews.theirTurn : PoolNews.yourTurn,
    ];
    if (game.over) {
      audio?.play(
        mode == PoolMode.chip && game.winner == 1 ? Sfx.lose : Sfx.win,
      );
    } else if (game.hand != PoolHand.none) {
      _aimAtRack();
    }
    notifyListeners();
    if (chipsTurn) unawaited(_chipPlays());
  }

  /// Points at the middle of the balls (a fresh aim after the cue ball
  /// moves).
  void _aimAtRack() {
    var x = 0.0, y = 0.0, n = 0;
    for (var i = 1; i < kBalls; i++) {
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

  /// Chip's turn: it thinks (off the main thread), places the cue ball if
  /// it's in hand, lines up, pulls back and strikes, as a person would.
  Future<void> _chipPlays() async {
    chipBusy = true;
    notifyListeners();
    final started = DateTime.now();
    final move = await findPoolBotMove(game, level);
    // At least a moment's thought, however quick it was.
    final waited = DateTime.now().difference(started);
    if (waited < const Duration(milliseconds: 700)) {
      await Future<void>.delayed(const Duration(milliseconds: 700) - waited);
    }
    if (_disposed) return;
    if (move.cueX != null && game.hand != PoolHand.none && game.canPlace(move.cueX!, move.cueY!)) {
      game = game.placeCue(move.cueX!, move.cueY!);
      shown = game.balls.copy();
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    await _swing(move);
  }

  /// Turns the cue to [move]'s aim, pulls back and strikes.
  Future<void> _swing(PoolBotMove move) async {
    final fromX = aimX, fromY = aimY;
    final from = math.atan2(fromY, fromX), to = math.atan2(move.shot.dy, move.shot.dx);
    var turn = to - from;
    while (turn > math.pi) {
      turn -= 2 * math.pi;
    }
    while (turn < -math.pi) {
      turn += 2 * math.pi;
    }
    const steps = 24;
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
    for (var s = 1; s <= 14; s++) {
      if (_disposed) return;
      power = move.shot.power * s / 14;
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 26));
    }
    await Future<void>.delayed(const Duration(milliseconds: 160));
    if (_disposed) return;
    chipBusy = false;
    _play(move.shot);
  }

  /// The player to shoot (on this device) gives up.
  void resign() {
    if (game.over) return;
    game = mode == PoolMode.chip
        ? game.copyWith(winner: 1, win: PoolWin.resign)
        : game.resign();
    notifyListeners();
  }

  /// A new rack, the loser of this one breaking (or the same breaker).
  void rematch() {
    final breaker = game.winner == null ? 0 : 1 - game.winner!;
    game = PoolGame.rack(math.Random().nextInt(1 << 30), breaker: breaker);
    shown = game.balls.copy();
    playing = null;
    news = const [];
    called = null;
    power = spinX = spinY = 0;
    _aimAtRack();
    notifyListeners();
    if (chipsTurn) unawaited(_chipPlays());
  }

  /// Starts things off (Chip breaks first, when it's its rack).
  void start() {
    if (chipsTurn) unawaited(_chipPlays());
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

