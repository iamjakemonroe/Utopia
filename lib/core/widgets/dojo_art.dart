import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Art for the Dojo world: a samurai castle and two shadow fighters
/// sparring, drawn the way the Shadow Fight games draw their fighters.
/// Solid black silhouettes with real proportions, low wide stances, cloth
/// that streams with every move (headband tails, sash, flared hakama),
/// glowing white eyes, and a bright swoosh behind each strike.

// ── the castle ───────────────────────────────────────────────────────────

/// A Japanese castle keep (a tenshu, like Himeji's) on a curved stone base:
/// four storeys under sweeping roofs with upturned eaves, gables on the
/// roofs, golden fish on the ridge, warm windows, and roof edges lit by
/// the sun behind it. [s] is the base's width; [base] is its bottom middle.
void paintCastle(
  Canvas canvas,
  Offset base,
  double s,
  double t, {
  required Color wall,
  required Color roof,
  required Color stone,
  required Color light,
  required Color rim,
}) {
  final x = base.dx;
  var y = base.dy;

  // The stone base, its sides curving in as they rise.
  final bh = s * 0.2;
  final topW = s * 0.74;
  final stones = Path()
    ..moveTo(x - s / 2, y)
    ..quadraticBezierTo(x - s * 0.4, y - bh * 0.35, x - topW / 2, y - bh)
    ..lineTo(x + topW / 2, y - bh)
    ..quadraticBezierTo(x + s * 0.4, y - bh * 0.35, x + s / 2, y)
    ..close();
  canvas.drawPath(stones, Paint()..color = stone);
  canvas.save();
  canvas.clipPath(stones);
  final joint = Paint()
    ..color = Colors.black.withValues(alpha: 0.35)
    ..strokeWidth = s * 0.004;
  for (var r = 1; r < 6; r++) {
    final ry = y - bh * r / 6;
    canvas.drawLine(Offset(x - s / 2, ry), Offset(x + s / 2, ry), joint);
    for (var k = -6; k <= 6; k++) {
      final kx = x + (k + (r.isEven ? 0.5 : 0)) * s * 0.075;
      canvas.drawLine(Offset(kx, ry), Offset(kx, ry + bh / 6), joint);
    }
  }
  canvas.restore();
  y -= bh;

  final roofPaint = Paint()..color = roof;
  final wallPaint = Paint()..color = wall;
  final rimPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = s * 0.006
    ..strokeCap = StrokeCap.round
    ..color = rim;
  final glow = light.withValues(alpha: 0.75 + 0.25 * math.sin(t * 2.3));

  /// A roof with corners sweeping up: [w] wide at the eaves, rising [h].
  void eave(
    double w,
    double h,
    double yy, {
    bool gable = false,
    bool arch = false,
  }) {
    final lift = h * 0.55;
    final path = Path()
      ..moveTo(x - w / 2, yy - lift)
      ..quadraticBezierTo(x - w * 0.36, yy + h * 0.1, x - w * 0.2, yy)
      ..lineTo(x + w * 0.2, yy)
      ..quadraticBezierTo(x + w * 0.36, yy + h * 0.1, x + w / 2, yy - lift)
      ..lineTo(x + w * 0.3, yy - h)
      ..lineTo(x - w * 0.3, yy - h)
      ..close();
    canvas.drawPath(path, roofPaint);
    // Sunlight catching the tiles' top edge.
    canvas.drawPath(
      Path()
        ..moveTo(x - w / 2, yy - lift)
        ..lineTo(x - w * 0.3, yy - h)
        ..lineTo(x + w * 0.3, yy - h)
        ..lineTo(x + w / 2, yy - lift),
      rimPaint,
    );
    if (gable) {
      // A triangular gable sitting on the roof.
      final g = Path()
        ..moveTo(x - w * 0.16, yy - h * 0.55)
        ..lineTo(x, yy - h * 1.6)
        ..lineTo(x + w * 0.16, yy - h * 0.55)
        ..close();
      canvas.drawPath(g, roofPaint);
      canvas.drawPath(
        Path()
          ..moveTo(x - w * 0.16, yy - h * 0.55)
          ..lineTo(x, yy - h * 1.6)
          ..lineTo(x + w * 0.16, yy - h * 0.55),
        rimPaint,
      );
      canvas.drawCircle(
        Offset(x, yy - h * 0.95),
        w * 0.025,
        Paint()..color = glow,
      );
    }
    if (arch) {
      // A curved (karahafu) gable over the middle.
      final a = Path()
        ..moveTo(x - w * 0.14, yy - h * 0.3)
        ..quadraticBezierTo(x, yy - h * 1.45, x + w * 0.14, yy - h * 0.3)
        ..close();
      canvas.drawPath(a, roofPaint);
      canvas.drawPath(
        Path()
          ..moveTo(x - w * 0.14, yy - h * 0.3)
          ..quadraticBezierTo(x, yy - h * 1.45, x + w * 0.14, yy - h * 0.3),
        rimPaint,
      );
    }
  }

  void storey(double w, double h, int windows) {
    canvas.drawRect(Rect.fromLTWH(x - w / 2, y - h, w, h), wallPaint);
    for (var k = 0; k < windows; k++) {
      final wx = x - w / 2 + w * (k + 0.5) / windows;
      final flicker = 0.8 + 0.2 * math.sin(t * 3.1 + k * 1.7);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(wx, y - h * 0.5),
          width: w / windows * 0.42,
          height: h * 0.38,
        ),
        Paint()..color = glow.withValues(alpha: glow.a * flicker),
      );
    }
    y -= h;
  }

  storey(s * 0.66, s * 0.13, 6);
  eave(s * 0.86, s * 0.07, y, gable: true);
  y -= s * 0.06;
  storey(s * 0.52, s * 0.1, 5);
  eave(s * 0.7, s * 0.06, y, arch: true);
  y -= s * 0.05;
  storey(s * 0.42, s * 0.09, 4);
  eave(s * 0.56, s * 0.055, y, gable: true);
  y -= s * 0.045;
  storey(s * 0.32, s * 0.08, 3);
  // The top roof, its ridge capped with a golden fish at each end.
  eave(s * 0.46, s * 0.08, y);
  final ridgeY = y - s * 0.08;
  for (final side in [-1.0, 1.0]) {
    final fx = x + side * s * 0.13;
    final fish = Path()
      ..moveTo(fx, ridgeY)
      ..quadraticBezierTo(
        fx + side * s * 0.012,
        ridgeY - s * 0.035,
        fx - side * s * 0.01,
        ridgeY - s * 0.05,
      )
      ..quadraticBezierTo(
        fx + side * s * 0.03,
        ridgeY - s * 0.03,
        fx + side * s * 0.02,
        ridgeY,
      )
      ..close();
    canvas.drawPath(fish, Paint()..color = rim);
  }
}

/// A small corner turret on the wall: two storeys and a gate below.
void paintTurret(
  Canvas canvas,
  Offset base,
  double s,
  double t, {
  required Color wall,
  required Color roof,
  required Color stone,
  required Color light,
  required Color rim,
}) {
  final x = base.dx;
  final y = base.dy;
  canvas.drawPath(
    Path()
      ..moveTo(x - s / 2, y)
      ..quadraticBezierTo(
        x - s * 0.42,
        y - s * 0.12,
        x - s * 0.36,
        y - s * 0.28,
      )
      ..lineTo(x + s * 0.36, y - s * 0.28)
      ..quadraticBezierTo(x + s * 0.42, y - s * 0.12, x + s / 2, y)
      ..close(),
    Paint()..color = stone,
  );
  final rimPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = s * 0.012
    ..color = rim;
  var yy = y - s * 0.28;
  for (var tier = 0; tier < 2; tier++) {
    final w = s * (tier == 0 ? 0.6 : 0.42);
    final h = s * 0.2;
    canvas.drawRect(
      Rect.fromLTWH(x - w / 2, yy - h, w, h),
      Paint()..color = wall,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(x, yy - h / 2),
        width: w * 0.3,
        height: h * 0.4,
      ),
      Paint()
        ..color = light.withValues(alpha: 0.7 + 0.3 * math.sin(t * 2.7 + tier)),
    );
    yy -= h;
    final rw = w * 1.4;
    final roofPath = Path()
      ..moveTo(x - rw / 2, yy - s * 0.04)
      ..quadraticBezierTo(x - rw * 0.3, yy + s * 0.02, x, yy)
      ..quadraticBezierTo(
        x + rw * 0.3,
        yy + s * 0.02,
        x + rw / 2,
        yy - s * 0.04,
      )
      ..lineTo(x + rw * 0.25, yy - s * 0.12)
      ..lineTo(x - rw * 0.25, yy - s * 0.12)
      ..close();
    canvas.drawPath(roofPath, Paint()..color = roof);
    canvas.drawLine(
      Offset(x - rw * 0.25, yy - s * 0.12),
      Offset(x + rw * 0.25, yy - s * 0.12),
      rimPaint,
    );
    yy -= s * 0.1;
  }
}

/// A war banner (nobori) on a tall pole, cloth rippling in the wind.
void paintBanner(
  Canvas canvas,
  Offset foot,
  double h,
  double t,
  Color cloth,
  Color crest,
  Color pole,
) {
  canvas.drawLine(
    foot,
    foot.translate(0, -h),
    Paint()
      ..color = pole
      ..strokeWidth = h * 0.02,
  );
  final w = h * 0.22;
  final top = foot.translate(h * 0.01, -h * 0.95);
  final path = Path()..moveTo(top.dx, top.dy);
  const n = 8;
  for (var k = 0; k <= n; k++) {
    final v = k / n;
    path.lineTo(
      top.dx + w + math.sin(t * 3 + v * 4) * w * 0.12 * v,
      top.dy + v * h * 0.6,
    );
  }
  path
    ..lineTo(top.dx, top.dy + h * 0.6)
    ..close();
  canvas.drawPath(path, Paint()..color = cloth);
  canvas.drawCircle(
    top.translate(w * 0.5 + math.sin(t * 3 + 1.2) * w * 0.04, h * 0.18),
    w * 0.26,
    Paint()..color = crest,
  );
  canvas.drawCircle(
    top.translate(w * 0.5 + math.sin(t * 3 + 1.2) * w * 0.04, h * 0.18),
    w * 0.12,
    Paint()..color = cloth,
  );
}

// ── the fighters ─────────────────────────────────────────────────────────

/// A fighter's pose: angles in radians, measured from straight down and
/// turning toward the way the fighter faces; [lean] tips the torso
/// forward; [air] lifts them off the ground (a jump), in body heights.
class _Pose {
  const _Pose({
    this.lean = 0.12,
    this.thighF = 0.55,
    this.shinF = 0.0,
    this.thighB = -0.45,
    this.shinB = -0.7,
    this.upperF = 0.6,
    this.lowerF = 1.5,
    this.upperB = 0.35,
    this.lowerB = 1.4,
    this.weapon = 2.6,
    this.air = 0,
    this.shift = 0,
  });

  final double lean;
  final double thighF, shinF, thighB, shinB;
  final double upperF, lowerF, upperB, lowerB;
  final double weapon;
  final double air;

  /// Forward (+) or back (−) along the ground, in body heights.
  final double shift;

  _Pose lerp(_Pose o, double k) {
    double l(double a, double b) => a + (b - a) * k;
    return _Pose(
      lean: l(lean, o.lean),
      thighF: l(thighF, o.thighF),
      shinF: l(shinF, o.shinF),
      thighB: l(thighB, o.thighB),
      shinB: l(shinB, o.shinB),
      upperF: l(upperF, o.upperF),
      lowerF: l(lowerF, o.lowerF),
      upperB: l(upperB, o.upperB),
      lowerB: l(lowerB, o.lowerB),
      weapon: l(weapon, o.weapon),
      air: l(air, o.air),
      shift: l(shift, o.shift),
    );
  }
}

/// Keyframes: (time in the loop, pose). Eased between.
_Pose _at(List<(double, _Pose)> keys, double t) {
  for (var i = 0; i < keys.length - 1; i++) {
    final (ta, a) = keys[i];
    final (tb, b) = keys[i + 1];
    if (t >= ta && t <= tb) {
      final k = (t - ta) / (tb - ta);
      return a.lerp(b, k * k * (3 - 2 * k));
    }
  }
  return keys.last.$2;
}

const _loop = 7.0;

// The swordsman: stance, wind-up, a lunging cut, a leap over a sweep, a
// thrust. Clashes land at 1.5s and 5.3s.
const _sword = <(double, _Pose)>[
  (0.0, _Pose()),
  (0.9, _Pose(lean: 0.05, thighF: 0.5, thighB: -0.4, weapon: 2.7)),
  (
    1.2,
    _Pose(
      lean: -0.12,
      upperF: 2.9,
      lowerF: 3.5,
      upperB: 2.7,
      lowerB: 3.3,
      weapon: 4.1,
      shift: -0.05,
    ),
  ),
  (
    1.5,
    _Pose(
      lean: 0.5,
      thighF: 1.15,
      shinF: 0.15,
      thighB: -0.95,
      shinB: -1.45,
      upperF: 1.35,
      lowerF: 1.55,
      upperB: 1.1,
      lowerB: 1.5,
      weapon: 2.05,
      shift: 0.32,
    ),
  ),
  (
    2.2,
    _Pose(
      lean: 0.3,
      thighF: 0.9,
      thighB: -0.8,
      shinB: -1.2,
      upperF: 1.0,
      lowerF: 1.6,
      weapon: 2.4,
      shift: 0.22,
    ),
  ),
  (2.9, _Pose(shift: 0.05)),
  (
    3.3,
    _Pose(
      lean: 0.1,
      thighF: 0.75,
      shinF: -0.2,
      thighB: -0.3,
      shinB: -0.9,
      weapon: 2.9,
      shift: 0.05,
    ),
  ),
  (
    3.55,
    _Pose(
      lean: 0.2,
      thighF: 1.7,
      shinF: 0.25,
      thighB: 1.25,
      shinB: -0.35,
      upperF: 1.8,
      lowerF: 2.6,
      upperB: 1.6,
      lowerB: 2.5,
      weapon: 3.6,
      air: 0.32,
      shift: 0.1,
    ),
  ),
  (
    3.95,
    _Pose(
      lean: 0.25,
      thighF: 0.9,
      shinF: 0.1,
      thighB: -0.5,
      shinB: -1.0,
      weapon: 2.5,
      shift: 0.12,
    ),
  ),
  (4.8, _Pose(shift: 0.08)),
  (
    5.0,
    _Pose(
      lean: -0.05,
      upperF: 0.3,
      lowerF: 0.9,
      upperB: 0.2,
      lowerB: 0.8,
      weapon: 1.2,
      shift: 0.02,
    ),
  ),
  (
    5.3,
    _Pose(
      lean: 0.4,
      thighF: 1.0,
      shinF: 0.05,
      thighB: -0.85,
      shinB: -1.3,
      upperF: 1.55,
      lowerF: 1.6,
      upperB: 1.35,
      lowerB: 1.55,
      weapon: 1.62,
      shift: 0.3,
    ),
  ),
  (6.2, _Pose(shift: 0.06)),
  (7.0, _Pose()),
];

// The staff fighter: guards high against the cut, spins into a low sweep,
// parries the thrust.
const _staff = <(double, _Pose)>[
  (0.0, _Pose(upperF: 0.9, lowerF: 1.8, upperB: 0.5, lowerB: 1.3, weapon: 2.0)),
  (
    1.15,
    _Pose(upperF: 0.9, lowerF: 1.8, upperB: 0.5, lowerB: 1.3, weapon: 2.0),
  ),
  (
    1.45,
    _Pose(
      lean: -0.08,
      thighF: 0.45,
      thighB: -0.55,
      upperF: 2.5,
      lowerF: 1.7,
      upperB: 2.7,
      lowerB: 1.5,
      weapon: 1.55,
      shift: -0.04,
    ),
  ),
  (
    1.75,
    _Pose(
      lean: -0.15,
      thighF: 0.35,
      thighB: -0.65,
      shinB: -0.85,
      upperF: 2.3,
      lowerF: 1.6,
      upperB: 2.5,
      lowerB: 1.5,
      weapon: 1.6,
      shift: -0.14,
    ),
  ),
  (
    2.6,
    _Pose(
      upperF: 0.9,
      lowerF: 1.8,
      upperB: 0.5,
      lowerB: 1.3,
      weapon: 2.0,
      shift: -0.1,
    ),
  ),
  (
    3.2,
    _Pose(
      lean: 0.55,
      thighF: 1.45,
      shinF: -0.35,
      thighB: -1.25,
      shinB: -1.57,
      upperF: 1.2,
      lowerF: 1.35,
      upperB: 1.0,
      lowerB: 1.2,
      weapon: 1.45,
      shift: -0.05,
    ),
  ),
  (
    3.6,
    _Pose(
      lean: 0.6,
      thighF: 1.5,
      shinF: -0.4,
      thighB: -1.3,
      shinB: -1.57,
      upperF: 1.1,
      lowerF: 1.2,
      upperB: 0.9,
      lowerB: 1.1,
      weapon: 1.45 + 2 * math.pi,
      shift: 0.0,
    ),
  ),
  (
    4.2,
    _Pose(
      upperF: 0.9,
      lowerF: 1.8,
      upperB: 0.5,
      lowerB: 1.3,
      weapon: 2.0 + 2 * math.pi,
      shift: -0.08,
    ),
  ),
  (
    5.1,
    _Pose(
      upperF: 0.9,
      lowerF: 1.8,
      upperB: 0.5,
      lowerB: 1.3,
      weapon: 2.0 + 2 * math.pi,
      shift: -0.08,
    ),
  ),
  (
    5.3,
    _Pose(
      lean: -0.1,
      upperF: 1.3,
      lowerF: 2.3,
      upperB: 0.9,
      lowerB: 2.0,
      weapon: 2.75 + 2 * math.pi,
      shift: -0.16,
    ),
  ),
  (
    6.2,
    _Pose(
      upperF: 0.9,
      lowerF: 1.8,
      upperB: 0.5,
      lowerB: 1.3,
      weapon: 2.0 + 2 * math.pi,
      shift: -0.06,
    ),
  ),
  (
    7.0,
    _Pose(
      upperF: 0.9,
      lowerF: 1.8,
      upperB: 0.5,
      lowerB: 1.3,
      weapon: 2.0 + 2 * math.pi,
    ),
  ),
];

/// Two shadow fighters sparring on [ground] (y), facing each other round
/// [centre] (x): a swordsman in a headband on the left, a staff fighter in
/// a straw hat on the right. [h] is a fighter's height.
void paintShadowDuel(
  Canvas canvas,
  double centre,
  double ground,
  double h,
  double t, {
  required Color ink,
  required Color rim,
  required Color sash,
}) {
  final c = t % _loop;
  final breath = math.sin(t * 2.6) * h * 0.006;
  final sword = _at(_sword, c);
  final staff = _at(_staff, c);

  // Swooshes behind fast strikes: where the weapon was a moment ago.
  _swoosh(
    canvas,
    centre - h * 0.42,
    ground,
    h,
    c,
    1,
    _sword,
    sword: true,
    ink: rim,
  );
  _swoosh(
    canvas,
    centre + h * 0.42,
    ground,
    h,
    c,
    -1,
    _staff,
    sword: false,
    ink: rim,
  );

  _fighter(
    canvas,
    Offset(centre - h * 0.42, ground),
    h,
    sword,
    1,
    t,
    breath,
    ink: ink,
    rim: rim,
    sash: sash,
    hat: false,
    sword: true,
  );
  _fighter(
    canvas,
    Offset(centre + h * 0.42, ground),
    h,
    staff,
    -1,
    t + 1.3,
    breath,
    ink: ink,
    rim: rim,
    sash: sash,
    hat: true,
    sword: false,
  );

  // Sparks where the blade meets the staff.
  for (final hit in [1.5, 5.3]) {
    final k = (c - hit) / 0.35;
    if (k < 0 || k > 1) continue;
    final p = Offset(
      centre + h * (hit < 3 ? 0.02 : 0.04),
      ground - h * (hit < 3 ? 0.78 : 0.58),
    );
    final flash = Paint()
      ..color = Colors.white.withValues(alpha: (1 - k) * 0.9)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.03);
    canvas.drawCircle(p, h * 0.05 * (1 - k * 0.5), flash);
    final spark = Paint()
      ..color = Color.lerp(Colors.white, rim, k)!.withValues(alpha: 1 - k)
      ..strokeWidth = h * 0.008
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 9; i++) {
      final a = i * 0.7 + hit;
      final d = Offset(math.cos(a), math.sin(a) - 0.3);
      canvas.drawLine(
        p + d * h * 0.04 * k,
        p + d * h * (0.06 + 0.16 * k),
        spark,
      );
    }
  }
}

class _Body {
  _Body(this.hip, this.pose, this.h, this.dir, double breath) {
    Offset v(double a, double len) =>
        Offset(math.sin(a) * dir, math.cos(a)) * (len * h);
    final up = Offset(math.sin(pose.lean) * dir, -math.cos(pose.lean));
    shoulder = hip + up * (0.3 * h) + Offset(0, breath);
    neck = hip + up * (0.34 * h) + Offset(0, breath);
    head = hip + up * (0.42 * h) + Offset(0, breath);
    elbowF = shoulder + v(pose.upperF, 0.16);
    handF = elbowF + v(pose.lowerF, 0.15);
    elbowB = shoulder + v(pose.upperB, 0.16);
    handB = elbowB + v(pose.lowerB, 0.15);
    kneeF = hip + v(pose.thighF, 0.24);
    footF = kneeF + v(pose.shinF, 0.24);
    kneeB = hip + v(pose.thighB, 0.24);
    footB = kneeB + v(pose.shinB, 0.24);
    weaponDir = Offset(math.sin(pose.weapon) * dir, math.cos(pose.weapon));
  }

  final Offset hip;
  final _Pose pose;
  final double h;
  final double dir;
  late final Offset shoulder, neck, head;
  late final Offset elbowF, handF, elbowB, handB;
  late final Offset kneeF, footF, kneeB, footB;
  late final Offset weaponDir;

  /// The body stood on [ground]: the lowest foot touches it (unless in
  /// the air).
  static _Body stand(
    Offset feet,
    _Pose pose,
    double h,
    double dir,
    double breath,
  ) {
    final probe = _Body(Offset.zero, pose, h, dir, breath);
    final low = math.max(probe.footF.dy, probe.footB.dy);
    final hip = Offset(
      feet.dx + pose.shift * h * dir,
      feet.dy - low - pose.air * h,
    );
    return _Body(hip, pose, h, dir, breath);
  }
}

void _fighter(
  Canvas canvas,
  Offset feet,
  double h,
  _Pose pose,
  double dir,
  double t,
  double breath, {
  required Color ink,
  required Color rim,
  required Color sash,
  required bool hat,
  required bool sword,
}) {
  final b = _Body.stand(feet, pose, h, dir, breath);
  final flow = math.sin(t * 5.5);

  void draw(Paint paint, Offset shift) {
    canvas.save();
    canvas.translate(shift.dx, shift.dy);

    /// A limb from [a] to [c] that's [wa] wide at the start, swells to
    /// [wm] at [mid] of the way and narrows to [wc]: muscle and cloth.
    void seg(
      Offset a,
      Offset c,
      double wa,
      double wm,
      double wc, [
      double mid = 0.4,
    ]) {
      final d = c - a;
      final l = d.distance;
      if (l == 0) return;
      final n = Offset(-d.dy / l, d.dx / l);
      final m = Offset.lerp(a, c, mid)!;
      // Control points chosen so the curve passes through the swell.
      Offset ctrl(double sign) =>
          (m + n * (sign * wm / 2)) * 2 -
          (a + n * (sign * wa / 2) + c + n * (sign * wc / 2)) / 2;
      final p1 = ctrl(1);
      final p2 = ctrl(-1);
      canvas.drawPath(
        Path()
          ..moveTo((a + n * wa / 2).dx, (a + n * wa / 2).dy)
          ..quadraticBezierTo(
            p1.dx,
            p1.dy,
            (c + n * wc / 2).dx,
            (c + n * wc / 2).dy,
          )
          ..lineTo((c - n * wc / 2).dx, (c - n * wc / 2).dy)
          ..quadraticBezierTo(
            p2.dx,
            p2.dy,
            (a - n * wa / 2).dx,
            (a - n * wa / 2).dy,
          )
          ..close(),
        paint,
      );
      canvas.drawCircle(a, wa / 2, paint);
    }

    void leg(Offset knee, Offset foot) {
      seg(b.hip, knee, h * 0.11, h * 0.1, h * 0.07, 0.35);
      // Loose trousers, gathered at the ankle.
      seg(knee, foot, h * 0.07, h * 0.092, h * 0.04, 0.55);
      canvas.drawCircle(knee, h * 0.036, paint);
      _foot(canvas, foot, dir, h, paint);
    }

    void arm(Offset elbow, Offset hand, double scale) {
      seg(
        b.shoulder,
        elbow,
        h * 0.072 * scale,
        h * 0.062 * scale,
        h * 0.044 * scale,
        0.3,
      );
      seg(
        elbow,
        hand,
        h * 0.046 * scale,
        h * 0.052 * scale,
        h * 0.034 * scale,
        0.35,
      );
      canvas.drawCircle(hand, h * 0.026 * scale, paint);
    }

    // Back leg and arm.
    leg(b.kneeB, b.footB);
    arm(b.elbowB, b.handB, 0.95);

    // Torso: a V from broad shoulders to a narrow waist, and the neck.
    final up = (b.neck - b.hip) / (b.neck - b.hip).distance;
    final side = Offset(-up.dy, up.dx);
    Offset pt(double along, double across) =>
        b.hip + up * (along * h) + side * (across * h);
    canvas.drawPath(
      Path()
        ..moveTo(pt(0, 0.06).dx, pt(0, 0.06).dy)
        ..quadraticBezierTo(
          pt(0.12, 0.04).dx,
          pt(0.12, 0.04).dy,
          pt(0.22, 0.078).dx,
          pt(0.22, 0.078).dy,
        )
        ..quadraticBezierTo(
          pt(0.3, 0.09).dx,
          pt(0.3, 0.09).dy,
          pt(0.31, 0.03).dx,
          pt(0.31, 0.03).dy,
        )
        ..lineTo(pt(0.31, -0.03).dx, pt(0.31, -0.03).dy)
        ..quadraticBezierTo(
          pt(0.3, -0.09).dx,
          pt(0.3, -0.09).dy,
          pt(0.22, -0.078).dx,
          pt(0.22, -0.078).dy,
        )
        ..quadraticBezierTo(
          pt(0.12, -0.04).dx,
          pt(0.12, -0.04).dy,
          pt(0, -0.06).dx,
          pt(0, -0.06).dy,
        )
        ..close(),
      paint,
    );
    seg(b.neck, b.head, h * 0.042, h * 0.04, h * 0.04, 0.5);
    // Head, and a topknot or a straw hat.
    canvas.drawOval(
      Rect.fromCenter(center: b.head, width: h * 0.11, height: h * 0.13),
      paint,
    );
    if (hat) {
      canvas.drawPath(
        Path()
          ..moveTo(b.head.dx - h * 0.13, b.head.dy - h * 0.02)
          ..quadraticBezierTo(
            b.head.dx,
            b.head.dy - h * 0.2,
            b.head.dx + h * 0.13,
            b.head.dy - h * 0.02,
          )
          ..quadraticBezierTo(
            b.head.dx,
            b.head.dy - h * 0.05,
            b.head.dx - h * 0.13,
            b.head.dy - h * 0.02,
          )
          ..close(),
        paint,
      );
    } else {
      canvas.drawCircle(
        b.head + Offset(-dir * h * 0.035, -h * 0.07),
        h * 0.025,
        paint,
      );
      // Headband tails streaming back.
      final knot = b.head + Offset(-dir * h * 0.05, -h * 0.025);
      for (var k = 0; k < 2; k++) {
        final wave = math.sin(t * 7 + k * 1.4) * h * 0.025;
        canvas.drawPath(
          Path()
            ..moveTo(knot.dx, knot.dy)
            ..quadraticBezierTo(
              knot.dx - dir * h * 0.1,
              knot.dy + wave + k * h * 0.02,
              knot.dx - dir * h * (0.2 + k * 0.03),
              knot.dy + h * (0.02 + k * 0.03) - wave,
            )
            ..lineTo(
              knot.dx - dir * h * (0.19 + k * 0.03),
              knot.dy + h * (0.035 + k * 0.03) - wave,
            )
            ..quadraticBezierTo(
              knot.dx - dir * h * 0.09,
              knot.dy + h * 0.02 + wave + k * h * 0.02,
              knot.dx,
              knot.dy + h * 0.015,
            )
            ..close(),
          paint,
        );
      }
    }

    // The front leg.
    leg(b.kneeF, b.footF);
    // The sash tails, flying behind.
    final knotAt = b.hip + up * h * 0.03 - side * h * 0.0;
    canvas.drawPath(
      Path()
        ..moveTo(knotAt.dx, knotAt.dy)
        ..quadraticBezierTo(
          knotAt.dx - dir * h * 0.08,
          knotAt.dy + h * 0.06 + flow * h * 0.02,
          knotAt.dx - dir * h * 0.16,
          knotAt.dy + h * 0.1 - flow * h * 0.03,
        )
        ..lineTo(
          knotAt.dx - dir * h * 0.13,
          knotAt.dy + h * 0.115 - flow * h * 0.03,
        )
        ..quadraticBezierTo(
          knotAt.dx - dir * h * 0.06,
          knotAt.dy + h * 0.08 + flow * h * 0.02,
          knotAt.dx,
          knotAt.dy + h * 0.025,
        )
        ..close(),
      paint,
    );
    // Front arm.
    arm(b.elbowF, b.handF, 1);

    // The weapon.
    final wd = b.weaponDir;
    final wn = Offset(-wd.dy, wd.dx);
    if (sword) {
      final hiltEnd = b.handF - wd * h * 0.1;
      final guard = b.handF + wd * h * 0.02;
      final tip = guard + wd * h * 0.46 + wn * h * 0.025 * dir;
      canvas.drawLine(
        hiltEnd,
        guard,
        Paint()
          ..color = paint.color
          ..strokeWidth = h * 0.025
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        guard - wn * h * 0.025,
        guard + wn * h * 0.025,
        Paint()
          ..color = paint.color
          ..strokeWidth = h * 0.018,
      );
      canvas.drawPath(
        Path()
          ..moveTo(guard.dx + wn.dx * h * 0.008, guard.dy + wn.dy * h * 0.008)
          ..quadraticBezierTo(
            (guard + wd * h * 0.25 + wn * h * 0.02 * dir).dx,
            (guard + wd * h * 0.25 + wn * h * 0.02 * dir).dy,
            tip.dx,
            tip.dy,
          )
          ..quadraticBezierTo(
            (guard + wd * h * 0.25 + wn * h * 0.005 * dir).dx,
            (guard + wd * h * 0.25 + wn * h * 0.005 * dir).dy,
            guard.dx - wn.dx * h * 0.008,
            guard.dy - wn.dy * h * 0.008,
          )
          ..close(),
        paint,
      );
    } else {
      canvas.drawLine(
        b.handF - wd * h * 0.42,
        b.handF + wd * h * 0.5,
        Paint()
          ..color = paint.color
          ..strokeWidth = h * 0.022
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
  }

  // A rim of light from the sun behind, then the solid shadow on top.
  draw(Paint()..color = rim, Offset(0, -h * 0.008));
  draw(Paint()..color = ink, Offset.zero);

  // Glowing white eyes.
  final eye = b.head + Offset(dir * h * 0.03, -h * 0.006);
  canvas.drawOval(
    Rect.fromCenter(center: eye, width: h * 0.028, height: h * 0.011),
    Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.012),
  );
  canvas.drawOval(
    Rect.fromCenter(center: eye, width: h * 0.024, height: h * 0.008),
    Paint()..color = Colors.white,
  );
  // The sword's edge catches the light.
  if (sword) {
    final wd = b.weaponDir;
    final guard = b.handF + wd * h * 0.02;
    canvas.drawLine(
      guard + wd * h * 0.04,
      guard + wd * h * 0.4,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..strokeWidth = h * 0.004,
    );
  }
}

void _foot(Canvas canvas, Offset ankle, double dir, double h, Paint paint) {
  canvas.drawPath(
    Path()
      ..moveTo(ankle.dx - dir * h * 0.025, ankle.dy - h * 0.012)
      ..quadraticBezierTo(
        ankle.dx + dir * h * 0.03,
        ankle.dy - h * 0.01,
        ankle.dx + dir * h * 0.075,
        ankle.dy + h * 0.012,
      )
      ..lineTo(ankle.dx + dir * h * 0.07, ankle.dy + h * 0.022)
      ..lineTo(ankle.dx - dir * h * 0.03, ankle.dy + h * 0.022)
      ..close(),
    paint,
  );
}

/// A bright crescent behind a weapon that's moving fast: where its tip was
/// over the last moment.
void _swoosh(
  Canvas canvas,
  double x,
  double ground,
  double h,
  double c,
  double dir,
  List<(double, _Pose)> keys, {
  required bool sword,
  required Color ink,
}) {
  Offset tipAt(double time) {
    final b = _Body.stand(
      Offset(x, ground),
      _at(keys, time % _loop),
      h,
      dir,
      0,
    );
    return b.handF + b.weaponDir * h * (sword ? 0.48 : 0.5);
  }

  Offset handAt(double time) =>
      _Body.stand(Offset(x, ground), _at(keys, time % _loop), h, dir, 0).handF;

  final now = tipAt(c);
  final then = tipAt(c - 0.06);
  final speed = (now - then).distance / h;
  if (speed < 0.12) return;
  final strength = ((speed - 0.12) / 0.3).clamp(0.0, 1.0);
  final pts = [for (var k = 0; k <= 8; k++) tipAt(c - k * 0.022)];
  final inner = [
    for (var k = 8; k >= 0; k--)
      Offset.lerp(handAt(c - k * 0.022), pts[k], 0.55)!,
  ];
  canvas.drawPath(
    Path()..addPolygon([...pts, ...inner], true),
    Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.75 * strength),
          ink.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromPoints(pts.first, pts.last))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.006),
  );
}
