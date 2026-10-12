import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/utopia_themes.dart';
import 'world_sets.dart';

/// Stable pseudo-random 0-1 from an index.
double _rand(int i, int salt) {
  final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

Color _a(Color c, double alpha) =>
    c.withValues(alpha: (c.a * alpha).clamp(0.0, 1.0));

/// Heaven: everything in front of the sky. Light pours down from [sun]
/// through rolling clouds onto the pearly gates; cloud temples float either
/// side, doves cross, angels circle far off and feathers drift down. With
/// the set on (Angel Halo worn here, [WorldSets.heaven]) the gates swing
/// open and the light floods out, a rainbow forms over them, and the
/// feathers and doves come thicker.
void paintHeavenScene(
  Canvas canvas,
  Size size,
  double t,
  WorldStyle style, {
  required Offset sun,
}) {
  final w = size.width;
  final h = size.height;
  final blessed = WorldSets.heaven.amount;

  _rays(canvas, size, t, sun, 0.55 + 0.45 * blessed);
  if (blessed > 0) _rainbow(canvas, size, t, blessed);
  _angels(canvas, size, t, 2 + (blessed > 0.5 ? 2 : 0));

  // Temples floating over the cloud floor, which stays low and soft so
  // the screens' light text reads over it.
  _templeIsland(canvas, Offset(w * 0.16, h * 0.6), w * 0.2, t, style, 0);
  _templeIsland(canvas, Offset(w * 0.86, h * 0.54), w * 0.16, t, style, 1);
  _cloudBank(canvas, size, t, y: h * 0.8, puff: w * 0.12, seed: 1, light: 0.55);
  _gates(canvas, Offset(w * 0.5, h * 0.89), w * 0.3, t, style, blessed);
  _doves(canvas, size, t, 3 + (blessed * 3).round());
  _cloudBank(canvas, size, t, y: h * 0.93, puff: w * 0.16, seed: 3, light: 0.8);
  _feathers(canvas, size, t, style, 10 + (blessed * 10).round());

  if (blessed > 0) {
    // Everything bathed a little warmer.
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, 0.4),
          radius: 0.9,
          colors: [_a(style.glow, 0.22 * blessed), _a(style.glow, 0)],
        ).createShader(rect),
    );
  }
}

/// Shafts of light fanning down from the sun, turning slowly.
void _rays(Canvas canvas, Size size, double t, Offset from, double strength) {
  final reach = size.height * 1.1;
  Offset toward(double angle) =>
      from + Offset(math.cos(angle), math.sin(angle)) * reach;
  for (var i = 0; i < 9; i++) {
    // Angles below the sun, from lower right round to lower left.
    final a = math.pi * (0.12 + i * 0.095) + 0.05 * math.sin(t * 0.15 + i);
    final spread = 0.035 + 0.02 * _rand(i, 2);
    final pulse = 0.6 + 0.4 * math.sin(t * 0.6 + i * 1.7);
    canvas.drawPath(
      Path()..addPolygon([from, toward(a - spread), toward(a + spread)], true),
      Paint()
        ..shader = ui.Gradient.linear(from, toward(a), [
          Colors.white.withValues(alpha: 0.16 * strength * pulse),
          Colors.white.withValues(alpha: 0),
        ])
        ..blendMode = BlendMode.plus,
    );
  }
}

/// A rainbow arching over the gates.
void _rainbow(Canvas canvas, Size size, double t, double amount) {
  final w = size.width;
  final h = size.height;
  final c = Offset(w * 0.5, h * 0.8);
  const colors = [
    Color(0xFFFF6B6B),
    Color(0xFFFFB04D),
    Color(0xFFFFE46B),
    Color(0xFF6BE08A),
    Color(0xFF6BB8FF),
    Color(0xFFB08BFF),
  ];
  final shimmer = 0.75 + 0.25 * math.sin(t * 0.8);
  for (var i = 0; i < colors.length; i++) {
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: w * (0.5 - i * 0.022)),
      math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.022
        ..color = colors[i].withValues(alpha: 0.28 * amount * shimmer)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }
}

/// A rolling bank of cloud across the screen at [y], drifting.
void _cloudBank(
  Canvas canvas,
  Size size,
  double t, {
  required double y,
  required double puff,
  required int seed,
  required double light,
}) {
  final w = size.width;
  final h = size.height;
  final drift = (t * (3 + seed * 1.5)) % (puff * 2);
  final path = Path()..moveTo(-puff * 2, h);
  final count = (w / puff).ceil() + 4;
  for (var i = 0; i < count; i++) {
    final x = -puff * 2 + i * puff * 0.9 + drift;
    final r = puff * (0.55 + 0.35 * _rand(i + seed * 20, 5));
    path.addOval(
      Rect.fromCircle(
        center: Offset(x, y - r * 0.2 + math.sin(t * 0.3 + i) * 2),
        radius: r,
      ),
    );
  }
  path.addRect(Rect.fromLTRB(-puff * 2, y, w + puff * 2, h));
  // Lavender, a little see-through, deepening below.
  final top = Color.lerp(const Color(0xFFCFC2F2), Colors.white, light)!;
  canvas.drawPath(
    path,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, y - puff),
        Offset(0, y + puff * 2),
        [
          top.withValues(alpha: 0.92),
          const Color(0xFF8C80C8).withValues(alpha: 0.85),
        ],
      ),
  );
}

/// A small cloud island carrying a round temple of columns.
void _templeIsland(
  Canvas canvas,
  Offset c,
  double s,
  double t,
  WorldStyle style,
  int seed,
) {
  final bob = math.sin(t * 0.5 + seed * 2) * s * 0.04;
  final at = c.translate(0, bob);
  // The cloud it rests on.
  final cloud = Path();
  for (var i = 0; i < 5; i++) {
    cloud.addOval(
      Rect.fromCircle(
        center: at.translate((i - 2) * s * 0.17, s * 0.06 * (i.isEven ? 1 : 0)),
        radius: s * (0.14 + 0.05 * _rand(i, 9 + seed)),
      ),
    );
  }
  canvas.drawPath(
    cloud,
    Paint()
      ..shader = ui.Gradient.linear(
        at.translate(0, -s * 0.15),
        at.translate(0, s * 0.2),
        [Colors.white, const Color(0xFFDCD0F6)],
      ),
  );
  // Base, columns, dome.
  final marble = Paint()
    ..shader = ui.Gradient.linear(
      at.translate(-s * 0.3, 0),
      at.translate(s * 0.3, 0),
      [style.rock[0], style.rock[1]],
    );
  final top = at.translate(0, -s * 0.1);
  canvas.drawRect(
    Rect.fromCenter(center: top, width: s * 0.62, height: s * 0.05),
    marble,
  );
  for (var i = 0; i < 5; i++) {
    canvas.drawRect(
      Rect.fromLTWH(
        top.dx - s * 0.26 + i * s * 0.12,
        top.dy - s * 0.32,
        s * 0.05,
        s * 0.3,
      ),
      marble,
    );
  }
  canvas.drawRect(
    Rect.fromCenter(
      center: top.translate(0, -s * 0.34),
      width: s * 0.66,
      height: s * 0.05,
    ),
    marble,
  );
  canvas.drawArc(
    Rect.fromCenter(
      center: top.translate(0, -s * 0.36),
      width: s * 0.5,
      height: s * 0.36,
    ),
    math.pi,
    math.pi,
    true,
    Paint()
      ..shader = ui.Gradient.linear(
        top.translate(-s * 0.25, -s * 0.5),
        top.translate(s * 0.25, -s * 0.36),
        [style.foliage[0], style.foliage[2]],
      ),
  );
  // A glow inside.
  canvas.drawCircle(
    top.translate(0, -s * 0.16),
    s * 0.22,
    Paint()
      ..color = _a(style.glow, 0.35 + 0.15 * math.sin(t * 1.3 + seed))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.08),
  );
}

/// The pearly gates on their cloud: two pillars, a golden arch, and two
/// gold-barred doors that swing open as [open] goes to 1, light pouring
/// out between them.
void _gates(
  Canvas canvas,
  Offset base,
  double width,
  double t,
  WorldStyle style,
  double open,
) {
  final hgt = width * 0.95;
  final pillarW = width * 0.13;
  final inner = width - pillarW * 2;
  final gold = Paint()
    ..shader = ui.Gradient.linear(base.translate(0, -hgt), base, [
      const Color(0xFFFFF1C4),
      const Color(0xFFD9A43A),
    ]);
  final marble = Paint()
    ..shader = ui.Gradient.linear(
      base.translate(-width / 2, 0),
      base.translate(width / 2, 0),
      [style.rock[0], style.rock[1], style.rock[0]],
      [0, 0.5, 1],
    );

  // The light behind, brighter as the doors open.
  final glow = 0.45 + 0.4 * open + 0.1 * math.sin(t * 1.1);
  canvas.drawOval(
    Rect.fromCenter(
      center: base.translate(0, -hgt * 0.45),
      width: inner * (1.4 + open),
      height: hgt * (1.1 + open * 0.4),
    ),
    Paint()
      ..color = _a(style.glow, glow)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.18),
  );

  // Steps.
  for (var i = 0; i < 3; i++) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: base.translate(0, -i * width * 0.035),
          width: width * (1.25 - i * 0.12),
          height: width * 0.045,
        ),
        Radius.circular(width * 0.01),
      ),
      marble,
    );
  }
  final floor = base.dy - width * 0.09;

  // The doors: gold bars, swinging inward (narrowing toward the pillars).
  final half = inner / 2;
  final doorH = hgt * 0.72;
  for (final side in const [-1.0, 1.0]) {
    final hinge = base.dx + side * half;
    // Swung in, a door shows narrower from the front.
    final reach = half * (1 - 0.55 * open);
    final bars = Paint()
      ..color = const Color(0xFFE8C060)
      ..strokeWidth = width * 0.012
      ..strokeCap = StrokeCap.round;
    for (var b = 0; b <= 6; b++) {
      final x = hinge - side * reach * (b / 6);
      final top = floor - doorH + (b / 6) * doorH * 0.12 * (1 - open);
      canvas.drawLine(Offset(x, floor), Offset(x, top), bars);
    }
    canvas.drawLine(
      Offset(hinge, floor - doorH * 0.5),
      Offset(hinge - side * reach, floor - doorH * 0.5),
      bars,
    );
    canvas.drawLine(
      Offset(hinge, floor - doorH),
      Offset(hinge - side * reach, floor - doorH * 0.88 - doorH * 0.12 * open),
      bars,
    );
  }

  // Pillars and the arch over them.
  for (final side in const [-1.0, 1.0]) {
    final x = base.dx + side * (half + pillarW / 2);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(x, floor - hgt * 0.42),
        width: pillarW,
        height: hgt * 0.84,
      ),
      marble,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(x, floor - hgt * 0.86),
        width: pillarW * 1.3,
        height: hgt * 0.06,
      ),
      gold,
    );
    canvas.drawCircle(Offset(x, floor - hgt * 0.94), pillarW * 0.32, gold);
  }
  canvas.drawArc(
    Rect.fromCenter(
      center: Offset(base.dx, floor - hgt * 0.84),
      width: inner + pillarW,
      height: hgt * 0.5,
    ),
    math.pi,
    math.pi,
    false,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 0.035
      ..shader = gold.shader,
  );
  // A star at the crown of the arch, twinkling.
  final star = Offset(base.dx, floor - hgt * 1.12);
  final tw = 0.7 + 0.3 * math.sin(t * 2.2);
  canvas.drawCircle(
    star,
    width * 0.06 * tw,
    Paint()
      ..color = _a(style.glow, 0.6)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.03),
  );
  final r = width * 0.04 * tw;
  canvas.drawPath(
    Path()
      ..moveTo(star.dx, star.dy - r)
      ..quadraticBezierTo(star.dx, star.dy, star.dx + r, star.dy)
      ..quadraticBezierTo(star.dx, star.dy, star.dx, star.dy + r)
      ..quadraticBezierTo(star.dx, star.dy, star.dx - r, star.dy)
      ..quadraticBezierTo(star.dx, star.dy, star.dx, star.dy - r),
    Paint()..color = Colors.white,
  );
}

/// White doves gliding across, wings beating up and down.
void _doves(Canvas canvas, Size size, double t, int count) {
  final w = size.width;
  final h = size.height;
  final white = Paint()..color = Colors.white;
  final under = Paint()..color = const Color(0xFFE4DEF4);
  for (var i = 0; i < count; i++) {
    final speed = 16 + _rand(i, 30) * 14;
    final span = w + 80;
    final dir = i.isEven ? 1.0 : -1.0;
    final run = (t * speed + _rand(i, 31) * span) % span - 40;
    final x = dir > 0 ? run : w - run;
    final y = h * (0.2 + _rand(i, 32) * 0.34) + math.sin(t * 0.8 + i) * 8;
    final s = 5 + _rand(i, 33) * 4;
    final flap = math.sin(t * (6 + _rand(i, 34) * 3) + i);
    canvas.save();
    canvas.translate(x, y);
    canvas.scale(dir, 1);
    // The far wing, then the body, head and tail, then the near wing.
    Path wing(double lift) => Path()
      ..moveTo(-s * 0.3, 0)
      ..quadraticBezierTo(-s * 0.2, -s * 1.6 * lift, -s * 1.2, -s * 2.0 * lift)
      ..quadraticBezierTo(s * 0.2, -s * 1.2 * lift, s * 0.5, 0)
      ..close();
    canvas.drawPath(wing(0.75 * flap), under);
    canvas.drawPath(
      Path()
        ..moveTo(-s * 1.3, s * 0.05)
        ..quadraticBezierTo(-s * 0.2, -s * 0.5, s * 1.0, -s * 0.15)
        ..quadraticBezierTo(s * 0.2, s * 0.5, -s * 1.3, s * 0.05)
        ..close(),
      white,
    );
    canvas.drawCircle(Offset(s * 1.05, -s * 0.3), s * 0.32, white);
    canvas.drawPath(
      Path()
        ..moveTo(s * 1.35, -s * 0.32)
        ..lineTo(s * 1.6, -s * 0.24)
        ..lineTo(s * 1.35, -s * 0.18)
        ..close(),
      Paint()..color = const Color(0xFFF2B86A),
    );
    canvas.drawPath(
      Path()
        ..moveTo(-s * 1.1, 0)
        ..lineTo(-s * 1.9, -s * 0.35)
        ..lineTo(-s * 1.8, s * 0.4)
        ..close(),
      white,
    );
    canvas.drawPath(wing(flap), white);
    canvas.restore();
  }
}

/// Tiny angels far off, circling on white wings with a glint of halo.
void _angels(Canvas canvas, Size size, double t, int count) {
  final w = size.width;
  final h = size.height;
  for (var i = 0; i < count; i++) {
    final a = t * (0.12 + 0.04 * i) + i * 2.1;
    final at = Offset(
      w * (0.5 + 0.36 * math.cos(a)),
      h * (0.2 + 0.05 * i + 0.04 * math.sin(a * 1.3)),
    );
    final s = 5.0 + i;
    final flap = math.sin(t * 6 + i);
    final wing = Paint()..color = Colors.white.withValues(alpha: 0.85);
    for (final side in const [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: at.translate(side * s * 0.8, -s * 0.2 - flap * s * 0.3),
          width: s * 1.4,
          height: s * 0.6,
        ),
        wing,
      );
    }
    canvas.drawCircle(at, s * 0.45, Paint()..color = const Color(0xFFFFF6E6));
    canvas.drawOval(
      Rect.fromCenter(
        center: at.translate(0, -s * 0.75),
        width: s * 0.9,
        height: s * 0.28,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFFFD98A),
    );
  }
}

/// Feathers drifting down, rocking side to side as they fall.
void _feathers(
  Canvas canvas,
  Size size,
  double t,
  WorldStyle style,
  int count,
) {
  final w = size.width;
  final h = size.height;
  for (var i = 0; i < count; i++) {
    final speed = 0.04 + _rand(i, 40) * 0.04;
    final k = (t * speed + _rand(i, 41)) % 1.0;
    final x = w * _rand(i, 42) + math.sin(t * 0.9 + i) * 16;
    final y = -20 + k * (h + 40);
    final s = 5 + _rand(i, 43) * 5;
    final fade = math.sin(k * math.pi);
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(math.sin(t * 1.4 + i) * 0.8);
    final vane = Path()
      ..moveTo(0, -s)
      ..quadraticBezierTo(s * 0.55, -s * 0.2, 0, s)
      ..quadraticBezierTo(-s * 0.55, -s * 0.2, 0, -s);
    canvas.drawPath(
      vane,
      Paint()..color = Colors.white.withValues(alpha: 0.85 * fade),
    );
    canvas.drawLine(
      Offset(0, -s),
      Offset(0, s * 1.2),
      Paint()
        ..color = _a(style.foliage[1], 0.8 * fade)
        ..strokeWidth = 0.8,
    );
    canvas.restore();
  }
}
