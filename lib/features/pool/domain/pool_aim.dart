import 'dart:math' as math;

import 'pool_physics.dart';

/// What the aiming line shows for a shot from the cue ball along ([dx],
/// [dy]): where the cue ball first touches something (the ghost ball's
/// centre, [gx], [gy]), and, if that's a ball ([target]), the way the
/// object ball goes ([ox], [oy]) and the way the cue ball glances off
/// ([cx], [cy]), each a unit vector, with how full the hit is ([fullness],
/// 1 dead on, 0 a graze).
class PoolAim {
  const PoolAim({
    required this.gx,
    required this.gy,
    this.target,
    this.ox = 0,
    this.oy = 0,
    this.cx = 0,
    this.cy = 0,
    this.fullness = 0,
  });

  final double gx, gy;
  final int? target;
  final double ox, oy, cx, cy, fullness;
}

/// The aim for a shot along ([dx], [dy]) (a unit vector) from the cue ball
/// in [balls]: the first ball the cue ball would touch rolling straight,
/// else where it would meet a cushion.
PoolAim poolAim(PoolBalls balls, double dx, double dy) {
  final sx = balls.x[kCueBall], sy = balls.y[kCueBall];
  const r = kBallRadius;
  var best = double.infinity;
  int? hit;
  for (var i = 1; i < kBalls; i++) {
    if (!balls.on[i]) continue;
    // Where along the line the cue ball's centre comes within 2r of ball i.
    final fx = balls.x[i] - sx, fy = balls.y[i] - sy;
    final along = fx * dx + fy * dy;
    if (along <= 0) continue;
    final off2 = fx * fx + fy * fy - along * along;
    final reach2 = 4 * r * r;
    if (off2 >= reach2) continue;
    final t = along - math.sqrt(reach2 - off2);
    if (t < best) {
      best = t;
      hit = i;
    }
  }
  // The cushion it would reach otherwise (the rails, a radius in).
  var wall = double.infinity;
  if (dx > 0) wall = math.min(wall, (kPoolLength - r - sx) / dx);
  if (dx < 0) wall = math.min(wall, (r - sx) / dx);
  if (dy > 0) wall = math.min(wall, (kPoolWidth - r - sy) / dy);
  if (dy < 0) wall = math.min(wall, (r - sy) / dy);
  if (hit == null || wall < best) {
    final t = math.max(0.0, wall);
    return PoolAim(gx: sx + dx * t, gy: sy + dy * t);
  }
  final gx = sx + dx * best, gy = sy + dy * best;
  var nx = balls.x[hit] - gx, ny = balls.y[hit] - gy;
  final n = math.sqrt(nx * nx + ny * ny);
  nx /= n;
  ny /= n;
  final full = dx * nx + dy * ny;
  // The cue ball goes off at right angles to the object ball's line.
  var cx = dx - full * nx, cy = dy - full * ny;
  final c = math.sqrt(cx * cx + cy * cy);
  if (c > 1e-9) {
    cx /= c;
    cy /= c;
  } else {
    cx = cy = 0;
  }
  return PoolAim(
    gx: gx,
    gy: gy,
    target: hit,
    ox: nx,
    oy: ny,
    cx: cx,
    cy: cy,
    fullness: full,
  );
}
