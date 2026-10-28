import 'dart:math' as math;
import 'dart:typed_data';

/// A pool table's physics: balls sliding and rolling on cloth, hitting each
/// other and the cushions, and dropping into pockets.
///
/// Plain Dart and deterministic: a shot played from the same position gives
/// exactly the same result on a phone, in a browser and on the server (it
/// will referee online games). So it steps in fixed time, in a fixed order,
/// with nothing but arithmetic and square roots (which every platform rounds
/// the same way; sines and cosines it never uses).
///
/// Units: the playfield (the cloth inside the cushions) is [kPoolLength]
/// long (x) and [kPoolWidth] wide (y), with (0, 0) at a corner. Time is in
/// seconds. One unit is about 1.12 m, so speeds are close to real ones.
const kPoolLength = 2.0;
const kPoolWidth = 1.0;
const kBallRadius = 0.0255;
const kBalls = 16;

/// The cue ball's index; the others are numbered 1 to 15, the 8 among them.
const kCueBall = 0;
const kEightBall = 8;

/// Where racks and breaks start: the foot spot (the rack's apex), the head
/// spot (the cue ball for the break) and the head string (the kitchen, where
/// the cue ball is placed for the break, is behind it: x < [kHeadString]).
const kFootSpot = (1.5, 0.5);
const kHeadSpot = (0.5, 0.5);
const kHeadString = 0.5;

/// Fastest and slowest cue ball off the tip, at power 1 and 0.
const kMaxCueSpeed = 7.2;
const kMinCueSpeed = 0.25;

/// How far off centre the tip may strike, as a fraction of the radius.
const kMaxTipOffset = 0.6;

// Physics, tuned to feel like a real table.
const _g = 8.76; // gravity in units/s²
const _slideFriction = 0.2 * _g;
const _rollFriction = 0.016 * _g;
const _spinFriction = 2.2; // side spin lost a second, in units/s
const _ballRestitution = 0.94;
const _cushionRestitution = 0.78;
const _cushionGrip = 0.96;
const _english = 0.3; // side spin into the cushion's sideways speed
const _step = 1 / 600; // physics step (s)
const _framesEvery = 5; // record a frame every 5 steps: 120 frames a second
const _rest = 0.004; // slower than this (units/s) is at rest

/// A straight cushion edge ([ax], [ay]) to ([bx], [by]); balls bounce off
/// it on either side.
class PoolCushion {
  const PoolCushion(this.ax, this.ay, this.bx, this.by);
  final double ax, ay, bx, by;
}

/// A pocket: a ball whose centre comes within [radius] of ([x], [y]) drops.
class PoolPocket {
  const PoolPocket(this.x, this.y, this.radius);
  final double x, y, radius;

  /// Where a shot aims to send a ball into it: inside its mouth.
  (double, double) get aim {
    final cx = x.clamp(0.0, kPoolLength);
    final cy = y.clamp(0.0, kPoolWidth);
    return ((x + cx) / 2, (y + cy) / 2);
  }
}

const _cornerGap = 0.066; // a rail stops this far from a corner
const _sideGap = 0.05; // ... and this far either side of a side pocket
const _jaw = 0.05; // how far a pocket's jaw runs in

/// The six pockets: the four corners, then the two sides (top, bottom).
const kPockets = [
  PoolPocket(-0.018, -0.018, 0.058),
  PoolPocket(kPoolLength + 0.018, -0.018, 0.058),
  PoolPocket(-0.018, kPoolWidth + 0.018, 0.058),
  PoolPocket(kPoolLength + 0.018, kPoolWidth + 0.018, 0.058),
  PoolPocket(kPoolLength / 2, -0.044, 0.052),
  PoolPocket(kPoolLength / 2, kPoolWidth + 0.044, 0.052),
];

/// The cushions: the six rails between the pockets, and each pocket's
/// jaws, angled into it.
final kCushions = _cushions();

List<PoolCushion> _cushions() {
  const l = kPoolLength, w = kPoolWidth, c = _cornerGap, s = _sideGap, j = _jaw;
  const half = l / 2;
  return const [
    // Top rail, both halves, and bottom rail.
    PoolCushion(c, 0, half - s, 0),
    PoolCushion(half + s, 0, l - c, 0),
    PoolCushion(c, w, half - s, w),
    PoolCushion(half + s, w, l - c, w),
    // The end rails.
    PoolCushion(0, c, 0, w - c),
    PoolCushion(l, c, l, w - c),
    // Corner jaws, at 45 degrees.
    PoolCushion(c, 0, c - j, -j),
    PoolCushion(0, c, -j, c - j),
    PoolCushion(l - c, 0, l - c + j, -j),
    PoolCushion(l, c, l + j, c - j),
    PoolCushion(c, w, c - j, w + j),
    PoolCushion(0, w - c, -j, w - c + j),
    PoolCushion(l - c, w, l - c + j, w + j),
    PoolCushion(l, w - c, l + j, w - c + j),
    // Side pocket jaws, nearly straight in.
    PoolCushion(half - s, 0, half - s + 0.012, -j),
    PoolCushion(half + s, 0, half + s - 0.012, -j),
    PoolCushion(half - s, w, half - s + 0.012, w + j),
    PoolCushion(half + s, w, half + s - 0.012, w + j),
  ];
}

/// Where the balls are: [x] and [y] for each of the 16 (index 0 the cue
/// ball), and whether it's still on the table.
class PoolBalls {
  PoolBalls(this.x, this.y, this.on);

  factory PoolBalls.empty() => PoolBalls(
    Float64List(kBalls),
    Float64List(kBalls),
    List.filled(kBalls, false),
  );

  final Float64List x;
  final Float64List y;
  final List<bool> on;

  PoolBalls copy() =>
      PoolBalls(Float64List.fromList(x), Float64List.fromList(y), List.of(on));

  /// Whether a ball centred at ([px], [py]) would sit on the cloth without
  /// touching any ball on the table (other than [except]).
  bool isFree(double px, double py, {int except = -1}) {
    if (px < kBallRadius || px > kPoolLength - kBallRadius) return false;
    if (py < kBallRadius || py > kPoolWidth - kBallRadius) return false;
    for (var i = 0; i < kBalls; i++) {
      if (i == except || !on[i]) continue;
      final dx = x[i] - px, dy = y[i] - py;
      if (dx * dx + dy * dy < 4 * kBallRadius * kBallRadius) return false;
    }
    return true;
  }

  Map<String, Object?> toJson() => {
    'x': [for (final v in x) v],
    'y': [for (final v in y) v],
    'on': [for (final v in on) v],
  };

  factory PoolBalls.fromJson(Map<String, Object?> json) => PoolBalls(
    Float64List.fromList([
      for (final v in json['x']! as List) (v as num).toDouble(),
    ]),
    Float64List.fromList([
      for (final v in json['y']! as List) (v as num).toDouble(),
    ]),
    [for (final v in json['on']! as List) v as bool],
  );
}

/// A stroke of the cue: the direction ([dx], [dy], made a unit vector), how
/// hard (0 to 1), and where the tip hits the cue ball: [spinX] right of
/// centre and [spinY] above it, each -1 to 1 (scaled to the cue's reach,
/// [kMaxTipOffset] unless a cue says otherwise).
class PoolShot {
  PoolShot({
    required double dx,
    required double dy,
    required double power,
    double spinX = 0,
    double spinY = 0,
  }) : dx = dx / _len(dx, dy),
       dy = dy / _len(dx, dy),
       power = power.clamp(0.0, 1.0),
       spinX = spinX.clamp(-1.0, 1.0),
       spinY = spinY.clamp(-1.0, 1.0);

  final double dx, dy, power, spinX, spinY;

  static double _len(double dx, double dy) {
    final l = math.sqrt(dx * dx + dy * dy);
    return l == 0 ? 1 : l;
  }

  double get speed => speedFor(kMaxCueSpeed);

  /// How fast the cue ball leaves a cue whose fastest is [maxSpeed].
  double speedFor(double maxSpeed) =>
      kMinCueSpeed + power * (maxSpeed - kMinCueSpeed);

  Map<String, Object?> toJson() => {
    'dx': dx,
    'dy': dy,
    'power': power,
    'spinX': spinX,
    'spinY': spinY,
  };

  /// A shot as [toJson] wrote it: its aim taken as it is (already a unit
  /// vector), so the shot read back is the very one written, to the last
  /// bit, and plays out the same (the referee checks the aim's length).
  PoolShot.fromJson(Map<String, Object?> json)
    : dx = (json['dx']! as num).toDouble(),
      dy = (json['dy']! as num).toDouble(),
      power = (json['power']! as num).toDouble().clamp(0.0, 1.0),
      spinX = ((json['spinX'] ?? 0) as num).toDouble().clamp(-1.0, 1.0),
      spinY = ((json['spinY'] ?? 0) as num).toDouble().clamp(-1.0, 1.0);
}

/// Something that happened during a shot, at [time]: a ball hitting a ball
/// ([a] hits [b]), a cushion ([a], [b] the cushion's index) or dropping
/// into a pocket ([a], [b] the pocket's index). [speed] for the sound.
enum PoolEventKind { ball, cushion, pocket }

class PoolEvent {
  const PoolEvent(this.kind, this.time, this.a, this.b, this.speed);
  final PoolEventKind kind;
  final double time;
  final int a, b;
  final double speed;
}

/// What a shot did: how it played out ([frames], 120 a second, each the 16
/// balls' x and y, NaN once a ball has dropped), what happened in it, and
/// where the balls ended up.
class PoolShotResult {
  PoolShotResult({
    required this.frames,
    required this.frameCount,
    required this.events,
    required this.end,
    required this.duration,
  });

  final Float32List frames;
  final int frameCount;
  final List<PoolEvent> events;
  final PoolBalls end;
  final double duration;

  static const framesPerSecond = 120.0;

  /// The first ball the cue ball touched, or null if it touched none.
  int? get firstContact {
    for (final e in events) {
      if (e.kind == PoolEventKind.ball &&
          (e.a == kCueBall || e.b == kCueBall)) {
        return e.a == kCueBall ? e.b : e.a;
      }
    }
    return null;
  }

  /// The balls that dropped, in the order they dropped, with their pockets.
  List<(int, int)> get pocketed => [
    for (final e in events)
      if (e.kind == PoolEventKind.pocket) (e.a, e.b),
  ];

  /// Whether any ball touched a cushion after the cue ball's first contact.
  bool get cushionAfterContact {
    var touched = false;
    for (final e in events) {
      if (e.kind == PoolEventKind.ball &&
          (e.a == kCueBall || e.b == kCueBall)) {
        touched = true;
      } else if (touched && e.kind == PoolEventKind.cushion) {
        return true;
      }
    }
    return false;
  }
}

/// Plays [shot] from [start] to the end (every ball at rest). With [record]
/// off, no frames are kept (a bot trying shots out). Stops after [maxTime].
/// The cue decides how fast the cue ball can go ([maxSpeed]) and how far
/// off centre the tip may strike ([tipOffset]); see pool_cues.dart.
PoolShotResult simulateShot(
  PoolBalls start,
  PoolShot shot, {
  bool record = true,
  double maxTime = 30,
  double maxSpeed = kMaxCueSpeed,
  double tipOffset = kMaxTipOffset,
}) {
  final x = Float64List.fromList(start.x);
  final y = Float64List.fromList(start.y);
  final on = List.of(start.on);
  final vx = Float64List(kBalls), vy = Float64List(kBalls);
  final wx = Float64List(kBalls), wy = Float64List(kBalls);
  final wz = Float64List(kBalls);
  final moving = List.filled(kBalls, false);

  // The tip's strike: speed along the aim; above centre, topspin (rolling
  // speed of the surface, 2.5 x the offset x speed for a solid ball);
  // below, backspin; to the side, side spin.
  final v0 = shot.speedFor(maxSpeed);
  vx[kCueBall] = shot.dx * v0;
  vy[kCueBall] = shot.dy * v0;
  final roll = 2.5 * shot.spinY * tipOffset * v0;
  wx[kCueBall] = shot.dx * roll;
  wy[kCueBall] = shot.dy * roll;
  wz[kCueBall] = 2.5 * shot.spinX * tipOffset * v0;
  moving[kCueBall] = on[kCueBall];

  final events = <PoolEvent>[];
  final frames = <double>[];
  void keep() {
    for (var i = 0; i < kBalls; i++) {
      frames
        ..add(on[i] ? x[i] : double.nan)
        ..add(on[i] ? y[i] : double.nan);
    }
  }

  if (record) keep();
  const r = kBallRadius;
  const touch = 4 * r * r;
  var steps = 0;
  final maxSteps = (maxTime / _step).ceil();
  var anyMoving = moving[kCueBall];

  while (anyMoving && steps < maxSteps) {
    steps++;
    final time = steps * _step;

    // Cloth: sliding until rolling, then rolling to a stop; side spin wears
    // off. Then on.
    for (var i = 0; i < kBalls; i++) {
      if (!moving[i]) continue;
      final rx = vx[i] - wx[i], ry = vy[i] - wy[i];
      final slip = math.sqrt(rx * rx + ry * ry);
      if (slip > 1e-6) {
        final nx = rx / slip, ny = ry / slip;
        final dv = _slideFriction * _step;
        if (3.5 * dv >= slip) {
          // Rolls from here on: the slip's gone.
          vx[i] -= nx * slip / 3.5;
          vy[i] -= ny * slip / 3.5;
          wx[i] = vx[i];
          wy[i] = vy[i];
        } else {
          vx[i] -= nx * dv;
          vy[i] -= ny * dv;
          wx[i] += nx * 2.5 * dv;
          wy[i] += ny * 2.5 * dv;
        }
      } else {
        final speed = math.sqrt(vx[i] * vx[i] + vy[i] * vy[i]);
        final dv = _rollFriction * _step;
        if (speed <= dv) {
          vx[i] = 0;
          vy[i] = 0;
        } else {
          final k = (speed - dv) / speed;
          vx[i] *= k;
          vy[i] *= k;
        }
        wx[i] = vx[i];
        wy[i] = vy[i];
      }
      final spin = _spinFriction * _step;
      wz[i] = wz[i] > spin ? wz[i] - spin : (wz[i] < -spin ? wz[i] + spin : 0);
      x[i] += vx[i] * _step;
      y[i] += vy[i] * _step;
    }

    // Ball on ball: equal masses, so they trade the speed along the line
    // between their centres. Pushed apart so they just touch.
    for (var i = 0; i < kBalls; i++) {
      if (!on[i]) continue;
      for (var j = i + 1; j < kBalls; j++) {
        if (!on[j] || (!moving[i] && !moving[j])) continue;
        final dx = x[j] - x[i], dy = y[j] - y[i];
        final d2 = dx * dx + dy * dy;
        if (d2 >= touch || d2 == 0) continue;
        final d = math.sqrt(d2);
        final nx = dx / d, ny = dy / d;
        final closing = (vx[i] - vx[j]) * nx + (vy[i] - vy[j]) * ny;
        final push = (2 * r - d) / 2;
        x[i] -= nx * push;
        y[i] -= ny * push;
        x[j] += nx * push;
        y[j] += ny * push;
        if (closing <= 0) continue;
        final impulse = (1 + _ballRestitution) / 2 * closing;
        vx[i] -= nx * impulse;
        vy[i] -= ny * impulse;
        vx[j] += nx * impulse;
        vy[j] += ny * impulse;
        moving[i] = true;
        moving[j] = true;
        events.add(PoolEvent(PoolEventKind.ball, time, i, j, closing));
      }
    }

    // Cushions: the speed into the cushion comes back weaker; side spin
    // pushes the ball along it.
    for (var i = 0; i < kBalls; i++) {
      if (!moving[i]) continue;
      for (var c = 0; c < kCushions.length; c++) {
        final k = kCushions[c];
        final sx = k.bx - k.ax, sy = k.by - k.ay;
        final len2 = sx * sx + sy * sy;
        var t = ((x[i] - k.ax) * sx + (y[i] - k.ay) * sy) / len2;
        t = t < 0 ? 0 : (t > 1 ? 1 : t);
        final qx = k.ax + sx * t, qy = k.ay + sy * t;
        final dx = x[i] - qx, dy = y[i] - qy;
        final d2 = dx * dx + dy * dy;
        if (d2 >= r * r || d2 == 0) continue;
        final d = math.sqrt(d2);
        final nx = dx / d, ny = dy / d;
        x[i] += nx * (r - d);
        y[i] += ny * (r - d);
        final into = vx[i] * nx + vy[i] * ny;
        if (into >= 0) continue;
        // Along the cushion: kept (a little lost), plus the side spin's
        // push to the right of the ball's travel.
        final tx = -ny, ty = nx;
        final speed = math.sqrt(vx[i] * vx[i] + vy[i] * vy[i]);
        var along = (vx[i] * tx + vy[i] * ty) * _cushionGrip;
        if (speed > 0) {
          final rightX = -vy[i] / speed, rightY = vx[i] / speed;
          along += _english * wz[i] * (rightX * tx + rightY * ty);
        }
        final out = -into * _cushionRestitution;
        vx[i] = tx * along + nx * out;
        vy[i] = ty * along + ny * out;
        // The roll turns with it, weaker; side spin is spent on it.
        final rollAlong = (wx[i] * tx + wy[i] * ty) * 0.8;
        final rollInto = (wx[i] * nx + wy[i] * ny) * -0.4;
        wx[i] = tx * rollAlong + nx * rollInto;
        wy[i] = ty * rollAlong + ny * rollInto;
        wz[i] *= 0.55;
        events.add(PoolEvent(PoolEventKind.cushion, time, i, c, -into));
      }
    }

    // Pockets.
    for (var i = 0; i < kBalls; i++) {
      if (!moving[i]) continue;
      for (var p = 0; p < kPockets.length; p++) {
        final k = kPockets[p];
        final dx = x[i] - k.x, dy = y[i] - k.y;
        if (dx * dx + dy * dy >= k.radius * k.radius) continue;
        events.add(
          PoolEvent(
            PoolEventKind.pocket,
            time,
            i,
            p,
            math.sqrt(vx[i] * vx[i] + vy[i] * vy[i]),
          ),
        );
        on[i] = false;
        moving[i] = false;
        vx[i] = vy[i] = wx[i] = wy[i] = wz[i] = 0;
        break;
      }
      // Out of the table altogether (it can't, but numbers): dropped in the
      // nearest pocket.
      if (on[i] &&
          (x[i] < -0.08 ||
              x[i] > kPoolLength + 0.08 ||
              y[i] < -0.08 ||
              y[i] > kPoolWidth + 0.08)) {
        var best = 0;
        var bestD = double.infinity;
        for (var p = 0; p < kPockets.length; p++) {
          final dx = x[i] - kPockets[p].x, dy = y[i] - kPockets[p].y;
          final d = dx * dx + dy * dy;
          if (d < bestD) {
            bestD = d;
            best = p;
          }
        }
        events.add(PoolEvent(PoolEventKind.pocket, time, i, best, 0));
        on[i] = false;
        moving[i] = false;
        vx[i] = vy[i] = wx[i] = wy[i] = wz[i] = 0;
      }
    }

    // Who's still going.
    anyMoving = false;
    for (var i = 0; i < kBalls; i++) {
      if (!moving[i]) continue;
      final rx = vx[i] - wx[i], ry = vy[i] - wy[i];
      if (vx[i] * vx[i] + vy[i] * vy[i] < _rest * _rest &&
          rx * rx + ry * ry < _rest * _rest) {
        vx[i] = vy[i] = wx[i] = wy[i] = wz[i] = 0;
        moving[i] = false;
      } else {
        anyMoving = true;
      }
    }

    if (record && steps % _framesEvery == 0) keep();
  }
  if (record && steps % _framesEvery != 0) keep();

  return PoolShotResult(
    frames: Float32List.fromList(frames),
    frameCount: record ? frames.length ~/ (2 * kBalls) : 0,
    events: events,
    end: PoolBalls(x, y, on),
    duration: steps * _step,
  );
}
