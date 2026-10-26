import 'dart:math' as math;

import '../../chess/domain/chess_bot.dart' show BotLevel;
import 'pool_physics.dart';
import 'pool_rules.dart';

/// What the bot does with its turn: where it puts the cue ball (when it's
/// in hand), the shot, and the pocket it calls (when it's on the 8).
class PoolBotMove {
  const PoolBotMove({required this.shot, this.cueX, this.cueY, this.called});

  final PoolShot shot;
  final double? cueX, cueY;
  final int? called;

  Map<String, Object?> toJson() => {
    'shot': shot.toJson(),
    'cueX': cueX,
    'cueY': cueY,
    'called': called,
  };

  factory PoolBotMove.fromJson(Map<String, Object?> json) => PoolBotMove(
    shot: PoolShot.fromJson(json['shot']! as Map<String, Object?>),
    cueX: (json['cueX'] as num?)?.toDouble(),
    cueY: (json['cueY'] as num?)?.toDouble(),
    called: json['called'] as int?,
  );
}

/// A shot to try: the cue ball sent to the ghost ball (where it must be to
/// send [target] into [pocket]).
class _Plan {
  _Plan(this.target, this.pocket, this.dx, this.dy, this.difficulty, this.power);
  final int target, pocket;
  final double dx, dy, difficulty, power;
}

/// Chip at the pool table. It looks at every ball it may hit into every
/// pocket (the line clear, the cut not too thin), tries the likeliest
/// shots out with the real physics at a few strengths and spins, and plays
/// the one that pots and leaves it the best next shot; failing any, it
/// plays safe. Then its hand shakes as much as its level allows. Plain
/// Dart: it thinks in an isolate in the apps and a Web Worker in a browser.
PoolBotMove choosePoolMove(PoolGame game, BotLevel level, int seed) {
  final rng = math.Random(seed);
  var balls = game.balls;
  double? cueX, cueY;

  if (game.hand != PoolHand.none) {
    final spot = _placeCue(game, rng);
    cueX = spot.$1;
    cueY = spot.$2;
    game = game.placeCue(cueX, cueY);
    balls = game.balls;
  }

  if (game.breakShot) {
    // The break: full power at the apex, a hair off straight.
    final (fx, fy) = kFootSpot;
    return PoolBotMove(
      shot: PoolShot(
        dx: fx - balls.x[kCueBall],
        dy: fy - balls.y[kCueBall] + (rng.nextDouble() - 0.5) * 0.02,
        power: level == BotLevel.easy ? 0.85 : 1,
      ),
      cueX: cueX,
      cueY: cueY,
    );
  }

  final me = game.turn;
  final plans = _plans(game)..sort((a, b) => a.difficulty.compareTo(b.difficulty));
  final tries = switch (level) {
    BotLevel.easy => 3,
    BotLevel.normal => 6,
    BotLevel.hard => 12,
  };

  PoolShot? best;
  int? bestCalled;
  var bestScore = -double.infinity;
  for (final plan in plans.take(tries)) {
    final variants = <(double, double)>[
      (plan.power, 0),
      (math.min(1, plan.power * 1.3), 0),
      if (level == BotLevel.hard) ...[
        (plan.power, -0.5),
        (plan.power, 0.5),
      ],
    ];
    for (final (power, spinY) in variants) {
      final shot = PoolShot(dx: plan.dx, dy: plan.dy, power: power, spinY: spinY);
      final called = game.callsPocket ? plan.pocket : null;
      final result = simulateShot(balls, shot, record: false, maxTime: 14);
      final next = game.after(result, called: called);
      final score = _score(next, me, plan);
      if (score > bestScore) {
        bestScore = score;
        best = shot;
        bestCalled = called;
      }
    }
  }

  // Nothing pots cleanly: a safe shot, softly into a ball it may hit.
  if (best == null || bestScore < 0) {
    final safe = _safety(game, rng);
    if (safe != null && (best == null || bestScore < -100)) {
      best = safe;
      bestCalled = game.callsPocket ? _nearestPocket(balls, kEightBall) : null;
    }
  }
  best ??= PoolShot(dx: 1, dy: 0, power: 0.4);

  // Its hand: off by a fraction of a degree (hard) to a couple (easy).
  final wobble = switch (level) {
    BotLevel.easy => 0.035,
    BotLevel.normal => 0.016,
    BotLevel.hard => 0.0045,
  };
  final shaken = _turn(best.dx, best.dy, (rng.nextDouble() * 2 - 1) * wobble);
  final powerShake = 1 + (rng.nextDouble() * 2 - 1) * wobble;
  return PoolBotMove(
    shot: PoolShot(
      dx: shaken.$1,
      dy: shaken.$2,
      power: best.power * powerShake,
      spinX: best.spinX,
      spinY: best.spinY,
    ),
    cueX: cueX,
    cueY: cueY,
    called: bestCalled,
  );
}

/// How good the game is for [me] after a shot.
double _score(PoolGame next, int me, _Plan plan) {
  if (next.winner == me) return 1000;
  if (next.winner != null) return -1000;
  if (next.lastFouls.isNotEmpty) return -300;
  if (next.turn != me) return -50 - plan.difficulty;
  // Potted and on again: the easier the next shot, the better.
  final following = _plans(next);
  var ease = 0.0;
  for (final p in following) {
    ease = math.max(ease, 1 / (0.2 + p.difficulty));
  }
  return 200 + 40 * ease;
}

/// Every pot worth considering: each ball the player may hit, into each
/// pocket, with nothing in the way and the cut not too thin.
List<_Plan> _plans(PoolGame game) {
  final b = game.balls;
  if (!b.on[kCueBall]) return const [];
  final cx = b.x[kCueBall], cy = b.y[kCueBall];
  final plans = <_Plan>[];
  for (final t in game.targets) {
    final tx = b.x[t], ty = b.y[t];
    for (var p = 0; p < kPockets.length; p++) {
      final (ax, ay) = kPockets[p].aim;
      var px = ax - tx, py = ay - ty;
      final toPocket = math.sqrt(px * px + py * py);
      if (toPocket < 1e-9) continue;
      px /= toPocket;
      py /= toPocket;
      final gx = tx - px * 2 * kBallRadius, gy = ty - py * 2 * kBallRadius;
      var dx = gx - cx, dy = gy - cy;
      final toGhost = math.sqrt(dx * dx + dy * dy);
      if (toGhost < 1e-9) continue;
      dx /= toGhost;
      dy /= toGhost;
      final cut = dx * px + dy * py;
      if (cut < 0.22) continue;
      if (!_clear(b, cx, cy, gx, gy, t)) continue;
      if (!_clear(b, tx, ty, ax, ay, t)) continue;
      final difficulty = (toGhost + 1.6 * toPocket) / (cut * cut);
      // Enough to get the object ball there with some to spare.
      final power = (0.12 + 0.2 * (toGhost + toPocket / cut)).clamp(0.12, 0.9);
      plans.add(_Plan(t, p, dx, dy, difficulty, power));
    }
  }
  return plans;
}

/// Whether a ball can travel from ([ax], [ay]) to ([bx], [by]) without
/// touching any ball but the cue ball and [skip].
bool _clear(PoolBalls b, double ax, double ay, double bx, double by, int skip) {
  final sx = bx - ax, sy = by - ay;
  final len2 = sx * sx + sy * sy;
  if (len2 == 0) return true;
  const room = 2 * kBallRadius;
  for (var i = 1; i < kBalls; i++) {
    if (i == skip || !b.on[i]) continue;
    var t = ((b.x[i] - ax) * sx + (b.y[i] - ay) * sy) / len2;
    if (t <= 0) continue;
    t = t > 1 ? 1 : t;
    final dx = b.x[i] - (ax + sx * t), dy = b.y[i] - (ay + sy * t);
    if (dx * dx + dy * dy < room * room) return false;
  }
  return true;
}

/// Where to put the cue ball in hand: lined up behind the easiest pot
/// (a straight one, from a comfortable distance), else somewhere free.
(double, double) _placeCue(PoolGame game, math.Random rng) {
  final b = game.balls;
  if (game.breakShot || game.hand == PoolHand.kitchen) {
    for (var k = 0; k < 20; k++) {
      final y = 0.5 + (rng.nextDouble() - 0.5) * 0.3;
      final x = 0.42 + (rng.nextDouble() - 0.5) * 0.06;
      if (game.canPlace(x, y)) return (x, y);
    }
  }
  var best = (-1.0, -1.0);
  var bestDifficulty = double.infinity;
  for (final t in game.targets) {
    final tx = b.x[t], ty = b.y[t];
    for (var p = 0; p < kPockets.length; p++) {
      final (ax, ay) = kPockets[p].aim;
      var px = ax - tx, py = ay - ty;
      final toPocket = math.sqrt(px * px + py * py);
      if (toPocket < 1e-9 || !_clear(b, tx, ty, ax, ay, t)) continue;
      px /= toPocket;
      py /= toPocket;
      for (final back in const [0.22, 0.32, 0.15, 0.45]) {
        final x = tx - px * (2 * kBallRadius + back);
        final y = ty - py * (2 * kBallRadius + back);
        if (!game.canPlace(x, y)) continue;
        if (!_clear(b, x, y, tx - px * 2 * kBallRadius, ty - py * 2 * kBallRadius, t)) continue;
        final difficulty = back + 1.6 * toPocket;
        if (difficulty < bestDifficulty) {
          bestDifficulty = difficulty;
          best = (x, y);
        }
        break;
      }
    }
  }
  if (best.$1 >= 0) return best;
  for (var k = 0; k < 400; k++) {
    final x = kBallRadius + rng.nextDouble() * (kPoolLength - 2 * kBallRadius);
    final y = kBallRadius + rng.nextDouble() * (kPoolWidth - 2 * kBallRadius);
    if (game.canPlace(game.hand == PoolHand.kitchen ? math.min(x, kHeadString - 0.01) : x, y)) {
      return (game.hand == PoolHand.kitchen ? math.min(x, kHeadString - 0.01) : x, y);
    }
  }
  return kHeadSpot;
}

/// A soft shot straight at the nearest ball the player may hit, if one's in
/// sight.
PoolShot? _safety(PoolGame game, math.Random rng) {
  final b = game.balls;
  if (!b.on[kCueBall]) return null;
  final cx = b.x[kCueBall], cy = b.y[kCueBall];
  PoolShot? best;
  var bestD = double.infinity;
  for (final t in game.targets) {
    final dx = b.x[t] - cx, dy = b.y[t] - cy;
    final d = math.sqrt(dx * dx + dy * dy);
    if (d >= bestD || !_clear(b, cx, cy, b.x[t], b.y[t], t)) continue;
    bestD = d;
    best = PoolShot(dx: dx, dy: dy, power: (0.18 + d * 0.15).clamp(0.18, 0.5));
  }
  return best;
}

int _nearestPocket(PoolBalls b, int ball) {
  var best = 0;
  var bestD = double.infinity;
  for (var p = 0; p < kPockets.length; p++) {
    final dx = b.x[ball] - kPockets[p].x, dy = b.y[ball] - kPockets[p].y;
    final d = dx * dx + dy * dy;
    if (d < bestD) {
      bestD = d;
      best = p;
    }
  }
  return best;
}

/// ([dx], [dy]) turned by a small [angle] (radians), without trigonometry
/// (so it turns the same on every platform).
(double, double) _turn(double dx, double dy, double angle) {
  final c = 1 - angle * angle / 2, s = angle;
  final x = dx * c - dy * s, y = dx * s + dy * c;
  final l = math.sqrt(x * x + y * y);
  return (x / l, y / l);
}
