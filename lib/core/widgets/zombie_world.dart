import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/utopia_themes.dart';
import 'world_sets.dart';

/// The Zombie world's set: wearing the Zombie Bite aura in it makes the
/// world deader still (a blood moon, thicker fog, more of the dead up and
/// walking) and gets Chip bitten. Set by zombieSetProvider; one of
/// [WorldSets].
abstract final class ZombieWorld {
  static ValueNotifier<bool> get dead => WorldSets.zombie.on;

  /// How far the world has turned: 0 plain, 1 fully dead.
  static double get amount => WorldSets.zombie.amount;

  /// Skips the fade, so the next frame paints [dead] fully.
  @visibleForTesting
  static void settle() => WorldSets.zombie.settle();
}

/// Stable pseudo-random 0-1 from an index.
double _rand(int i, int salt) {
  final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

Color _a(Color c, double alpha) =>
    c.withValues(alpha: (c.a * alpha).clamp(0.0, 1.0));

const _ink = Color(0xFF060906);

/// A rolling ridge line from x = 0 to [w] around [base], up to [height]
/// tall, the same every frame for a [seed].
List<Offset> _ridge(double w, double base, double height, int seed) {
  final f1 = 1.2 + _rand(seed, 1) * 0.8, f2 = 2.6 + _rand(seed, 2) * 1.2;
  final p1 = _rand(seed, 3) * 6.28, p2 = _rand(seed, 4) * 6.28;
  return [
    for (var s = 0; s <= 40; s++)
      () {
        final u = s / 40;
        final y =
            0.6 * (0.5 + 0.5 * math.sin(u * f1 * 6.28 + p1)) +
            0.4 * (0.5 + 0.5 * math.sin(u * f2 * 6.28 + p2));
        return Offset(w * u, base - height * y);
      }(),
  ];
}

/// The ridge's height at x, read off the points [_ridge] made.
double _ridgeY(List<Offset> ridge, double x) {
  final step = ridge[1].dx - ridge[0].dx;
  final i = (x / step).clamp(0, ridge.length - 2).floor();
  final k = ((x - ridge[i].dx) / step).clamp(0.0, 1.0);
  return ridge[i].dy + (ridge[i + 1].dy - ridge[i].dy) * k;
}

/// The graveyard: paints everything in front of the sky. [moon] is where
/// the sky painter put the moon. When the set is on ([ZombieWorld.dead]),
/// the moon bleeds red, the fog thickens, more of the dead rise and walk,
/// and the dark closes in.
void paintZombieScene(
  Canvas canvas,
  Size size,
  double t,
  WorldStyle style, {
  required Offset moon,
}) {
  final w = size.width;
  final h = size.height;
  final ground = h * 0.86;
  final dead = ZombieWorld.amount;

  if (dead > 0) _bloodMoon(canvas, moon, w, t, dead);
  _moonClouds(canvas, size, t, moon);
  _crows(canvas, size, t);

  // The far ridge: a line of dead trees and a chapel, faded by the haze.
  final far = _ridge(w, h * 0.68, h * 0.06, 31);
  _fill(canvas, far, size, style.layers[0], h * 0.62);
  final hazeInk = Color.lerp(_ink, style.haze, 0.3)!;
  for (var i = 0; i < 9; i++) {
    final x = w * (0.04 + i * 0.115 + (_rand(i, 20) - 0.5) * 0.05);
    if ((x - w * 0.3).abs() < w * 0.07) continue; // the chapel's spot
    _deadTree(
      canvas,
      Offset(x, _ridgeY(far, x) + 2),
      h * (0.05 + _rand(i, 21) * 0.035),
      t,
      40 + i,
      hazeInk,
      depth: 3,
    );
  }
  _chapel(canvas, Offset(w * 0.3, _ridgeY(far, w * 0.3) + 3), h, t, style);
  _fog(canvas, size, t, y: h * 0.69, thick: 0.25 + 0.2 * dead, seed: 3);

  // The near hill and its two big dead trees.
  final mid = _ridge(w, h * 0.79, h * 0.07, 38);
  _fill(canvas, mid, size, style.layers[1], h * 0.72);
  _deadTree(
    canvas,
    Offset(w * 0.84, _ridgeY(mid, w * 0.84) + 4),
    h * 0.24,
    t,
    3,
    _ink,
  );
  _deadTree(
    canvas,
    Offset(w * 0.08, _ridgeY(mid, w * 0.08) + 4),
    h * 0.17,
    t,
    9,
    _ink,
  );
  _fog(canvas, size, t, y: h * 0.78, thick: 0.32 + 0.25 * dead, seed: 1);

  // The graveyard ground.
  final near = _ridge(w, ground, h * 0.035, 57);
  _fill(canvas, near, size, style.layers[2], ground - h * 0.035);
  _fence(canvas, size, ground - h * 0.045);
  for (var i = 0; i < 3; i++) {
    // The third only walks while the set is on.
    final fade = i < 2 ? 1.0 : dead;
    if (fade <= 0) continue;
    _shambler(canvas, size, t, i, ground - h * 0.005, style, fade);
  }
  _graves(canvas, size, t, ground, style);
  _risingHands(canvas, size, t, ground, dead);
  _wisps(canvas, size, t, style, dead);
  _fog(canvas, size, t, y: h * 0.95, thick: 0.42 + 0.3 * dead, seed: 2);

  if (dead > 0) {
    // A green-black vignette closing in.
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.9,
          colors: [
            Colors.transparent,
            _a(
              const Color(0xFF021006),
              dead * (0.55 + 0.05 * math.sin(t * 0.8)),
            ),
          ],
        ).createShader(rect),
    );
  }
}

/// A ridge filled down to the bottom with a (top, bottom) gradient.
void _fill(
  Canvas canvas,
  List<Offset> ridge,
  Size size,
  (Color, Color) colors,
  double top,
) {
  canvas.drawPath(
    Path()..addPolygon([
      Offset(0, size.height),
      ...ridge,
      Offset(size.width, size.height),
    ], true),
    Paint()
      ..shader = ui.Gradient.linear(Offset(0, top), Offset(0, size.height), [
        colors.$1,
        colors.$2,
      ]),
  );
}

/// The moon turning to blood over the sky painter's green one, pulsing.
void _bloodMoon(Canvas canvas, Offset c, double w, double t, double amount) {
  // The sky painter's moon is w * 0.075 across the radius.
  final r = w * 0.075;
  final pulse = 0.5 + 0.5 * math.sin(t * 0.9);
  canvas.drawCircle(
    c,
    r * 3.2,
    Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(
            0xFFB0182A,
          ).withValues(alpha: (0.3 + 0.1 * pulse) * amount),
          const Color(0x00B0182A),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: r * 3.2)),
  );
  canvas.drawCircle(
    c,
    r + 0.5,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        stops: const [0.0, 0.55, 0.85, 1.0],
        colors: [
          const Color(0xFFFFB49A).withValues(alpha: amount),
          const Color(0xFFE2463A).withValues(alpha: amount),
          const Color(0xFFA11B24).withValues(alpha: amount),
          const Color(0xFF4E0A12).withValues(alpha: amount),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: r)),
  );
  final crater = Paint()
    ..color = const Color(0xFF4E0A12).withValues(alpha: 0.3 * amount);
  canvas.drawCircle(c.translate(r * 0.3, r * 0.15), r * 0.18, crater);
  canvas.drawCircle(c.translate(-r * 0.25, r * 0.35), r * 0.12, crater);
  canvas.drawCircle(c.translate(r * 0.05, -r * 0.4), r * 0.1, crater);
}

/// Dark wisps of cloud sliding across the moon.
void _moonClouds(Canvas canvas, Size size, double t, Offset moon) {
  final w = size.width;
  final paint = Paint()
    ..color = const Color(0xB30B120D)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
  for (var i = 0; i < 3; i++) {
    final span = w * 1.6;
    final x = (t * (6 + i * 3) + _rand(i, 40) * span) % span - w * 0.3;
    final y = moon.dy + (i - 1) * w * 0.06 + math.sin(t * 0.3 + i) * 4;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, y), width: w * 0.42, height: w * 0.05),
      paint,
    );
  }
}

/// Crows crossing the sky, flapping.
void _crows(Canvas canvas, Size size, double t) {
  final w = size.width, h = size.height;
  final ink = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = const Color(0xFF050705);
  for (var i = 0; i < 5; i++) {
    final speed = 14 + _rand(i, 50) * 12;
    final span = w + 80;
    final x = (t * speed + _rand(i, 51) * span) % span - 40;
    final y = h * (0.12 + _rand(i, 52) * 0.3) + math.sin(t * 0.7 + i) * 6;
    final s = 4 + _rand(i, 53) * 4;
    final flap = math.sin(t * (6 + _rand(i, 54) * 3) + i);
    ink.strokeWidth = s * 0.32;
    canvas.drawPath(
      Path()
        ..moveTo(x - s * 1.6, y - s * 0.6 * flap)
        ..quadraticBezierTo(x - s * 0.7, y - s * (0.2 + 0.8 * flap), x, y)
        ..quadraticBezierTo(
          x + s * 0.7,
          y - s * (0.2 + 0.8 * flap),
          x + s * 1.6,
          y - s * 0.6 * flap,
        ),
      ink,
    );
  }
}

/// A crooked chapel on the far ridge, its one arched window flickering.
void _chapel(Canvas canvas, Offset base, double h, double t, WorldStyle style) {
  final s = h * 0.034;
  final dark = Paint()..color = Color.lerp(_ink, style.haze, 0.12)!;
  canvas.save();
  canvas.translate(base.dx, base.dy);
  canvas.rotate(-0.035);
  canvas.drawPath(
    Path()
      ..moveTo(-s * 0.75, 0)
      ..lineTo(-s * 0.75, -s * 1.1)
      ..lineTo(-s * 0.05, -s * 1.85)
      ..lineTo(s * 0.65, -s * 1.1)
      ..lineTo(s * 0.65, 0)
      ..close(),
    dark,
  );
  // The bell tower, its spire and cross.
  canvas.drawRect(Rect.fromLTWH(s * 0.4, -s * 2.4, s * 0.42, s * 2.4), dark);
  canvas.drawPath(
    Path()..addPolygon([
      Offset(s * 0.34, -s * 2.4),
      Offset(s * 0.61, -s * 3.1),
      Offset(s * 0.88, -s * 2.4),
    ], true),
    dark,
  );
  final cross = Paint()
    ..color = dark.color
    ..strokeWidth = s * 0.08;
  canvas.drawLine(
    Offset(s * 0.61, -s * 3.05),
    Offset(s * 0.61, -s * 3.5),
    cross,
  );
  canvas.drawLine(
    Offset(s * 0.48, -s * 3.32),
    Offset(s * 0.74, -s * 3.32),
    cross,
  );
  final flicker =
      0.55 + 0.45 * (math.sin(t * 3.1) * math.sin(t * 7.7 + 1)).abs();
  final window = Path()
    ..moveTo(-s * 0.26, -s * 0.35)
    ..lineTo(-s * 0.26, -s * 0.85)
    ..arcToPoint(Offset(s * 0.06, -s * 0.85), radius: Radius.circular(s * 0.16))
    ..lineTo(s * 0.06, -s * 0.35)
    ..close();
  canvas.drawCircle(
    Offset(-s * 0.1, -s * 0.65),
    s * 0.9,
    Paint()
      ..color = _a(style.glow, 0.16 * flicker)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
  );
  canvas.drawPath(
    window,
    Paint()..color = _a(style.glow, 0.35 + 0.5 * flicker),
  );
  // The window's leading.
  final lead = Paint()
    ..color = dark.color
    ..strokeWidth = s * 0.05;
  canvas.drawLine(
    Offset(-s * 0.1, -s * 0.35),
    Offset(-s * 0.1, -s * 0.98),
    lead,
  );
  canvas.drawLine(
    Offset(-s * 0.26, -s * 0.66),
    Offset(s * 0.06, -s * 0.66),
    lead,
  );
  canvas.restore();
}

/// A bare dead tree, branches forking and twisting, swaying a little.
void _deadTree(
  Canvas canvas,
  Offset root,
  double height,
  double t,
  int seed,
  Color color, {
  int depth = 5,
}) {
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..color = color;
  final sway = math.sin(t * 0.6 + seed) * 0.03;
  void branch(Offset from, double angle, double len, double width, int d) {
    final bend = (_rand(d * 13 + seed, 60) - 0.5) * 0.5 + sway * (5 - d);
    final a = angle + bend;
    final to = from + Offset(math.sin(a), -math.cos(a)) * len;
    paint.strokeWidth = width;
    canvas.drawLine(from, to, paint);
    if (d >= depth || len < 4) return;
    final spread = 0.45 + _rand(d * 7 + seed, 61) * 0.35;
    branch(to, a - spread, len * 0.7, width * 0.62, d + 1);
    branch(to, a + spread * 0.8, len * 0.66, width * 0.6, d + 1);
    if (d < 2) branch(to, a + 0.05, len * 0.5, width * 0.5, d + 2);
  }

  branch(root, -0.05, height * 0.38, height * 0.06, 0);
}

/// Drifting fog in a band around [y].
void _fog(
  Canvas canvas,
  Size size,
  double t, {
  required double y,
  required double thick,
  required int seed,
}) {
  final w = size.width;
  final paint = Paint()
    ..color = const Color(0xFF9DB89A).withValues(alpha: 0.13 * thick + 0.04)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
  for (var i = 0; i < 6; i++) {
    final span = w * 1.8;
    final speed = 5 + _rand(i * 3 + seed, 70) * 6;
    final x = (t * speed + _rand(i + seed * 10, 71) * span) % span - w * 0.4;
    final yy = y + (_rand(i, 72 + seed) - 0.5) * size.height * 0.06;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, yy),
        width: w * (0.5 + _rand(i, 73) * 0.4),
        height: size.height * 0.06,
      ),
      paint,
    );
  }
}

/// A broken iron fence along the back of the graveyard.
void _fence(Canvas canvas, Size size, double y) {
  final w = size.width;
  const iron = Color(0xFF0B100C);
  final bar = Paint()
    ..color = iron
    ..strokeWidth = 2;
  final spike = Paint()..color = iron;
  canvas.drawLine(Offset(w * 0.34, y - 9), Offset(w * 0.47, y - 9), bar);
  canvas.drawLine(Offset(w * 0.53, y - 9), Offset(w * 0.68, y - 9), bar);
  for (var i = 0; i < 15; i++) {
    final x = w * 0.34 + i * w * 0.024;
    if (i == 6 || i == 7) continue; // broken through
    final top = y - 20 - (i % 3 == 0 ? 3 : 0);
    final lean = i == 5
        ? -4.0
        : i == 8
        ? 4.0
        : 0.0;
    canvas.drawLine(Offset(x, y), Offset(x + lean, top), bar);
    canvas.drawPath(
      Path()..addPolygon([
        Offset(x + lean - 2.6, top + 3),
        Offset(x + lean, top - 4),
        Offset(x + lean + 2.6, top + 3),
      ], true),
      spike,
    );
  }
}

/// One of the dead, shambling across the graveyard: hunched, head lolling,
/// arms out, one foot dragging. Eyes glow. [fade] is its opacity.
void _shambler(
  Canvas canvas,
  Size size,
  double t,
  int i,
  double ground,
  WorldStyle style,
  double fade,
) {
  final w = size.width, h = size.height;
  final dir = i.isEven ? 1.0 : -1.0;
  final speed = 7 + _rand(i, 80) * 4;
  final span = w + 120;
  final travel = (t * speed + _rand(i, 81) * span) % span - 60;
  final x = dir > 0 ? travel : w - travel;
  final s = h * (0.027 + _rand(i, 82) * 0.007);
  final step = t * (1.4 + _rand(i, 83) * 0.6) + i * 1.7;
  final lurch = math.sin(step * math.pi);
  final bob = lurch.abs() * s * 0.08;
  final body = Paint()..color = _ink;

  if (fade < 1) {
    canvas.saveLayer(
      Rect.fromCenter(center: Offset(x, ground), width: s * 8, height: s * 8),
      Paint()..color = Color.fromRGBO(0, 0, 0, fade),
    );
  }
  canvas.save();
  canvas.translate(x, ground - bob);
  canvas.scale(dir, 1);
  canvas.rotate(0.14 + lurch * 0.04);

  final limb = Paint()
    ..color = _ink
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;
  // Legs: one stepping, one dragging behind.
  limb.strokeWidth = s * 0.2;
  final hip = Offset(0, -s * 1.15);
  canvas.drawPath(
    Path()
      ..moveTo(hip.dx, hip.dy)
      ..lineTo(s * (0.12 + 0.18 * lurch), -s * 0.55)
      ..lineTo(s * (0.2 + 0.3 * lurch), 0),
    limb,
  );
  canvas.drawPath(
    Path()
      ..moveTo(hip.dx, hip.dy)
      ..lineTo(-s * 0.25, -s * 0.5)
      ..lineTo(-s * 0.5, -s * 0.02)
      ..lineTo(-s * 0.68, 0),
    limb,
  );
  // A hunched torso in a ragged coat.
  canvas.drawPath(
    Path()
      ..moveTo(-s * 0.32, -s * 1.0)
      ..lineTo(-s * 0.2, -s * 0.86)
      ..lineTo(-s * 0.06, -s * 1.02)
      ..lineTo(s * 0.1, -s * 0.84)
      ..lineTo(s * 0.24, -s * 1.0)
      ..lineTo(s * 0.34, -s * 0.9)
      ..quadraticBezierTo(s * 0.42, -s * 1.7, s * 0.3, -s * 2.18)
      ..quadraticBezierTo(s * 0.05, -s * 2.5, -s * 0.28, -s * 2.2)
      ..quadraticBezierTo(-s * 0.42, -s * 1.6, -s * 0.32, -s * 1.0)
      ..close(),
    body,
  );
  // Arms out in front, bent, hands hanging.
  for (final k in const [0.0, 1.0]) {
    final sh = Offset(s * (0.18 - k * 0.08), -s * (2.1 - k * 0.06));
    final sway = math.sin(step * 0.5 + k * 2) * s * 0.07;
    final elbow = Offset(s * 0.62, -s * 2.02 + sway);
    final wrist = Offset(s * 1.02, -s * (2.08 - k * 0.1) + sway);
    limb.strokeWidth = s * 0.14;
    canvas.drawPath(
      Path()
        ..moveTo(sh.dx, sh.dy)
        ..lineTo(elbow.dx, elbow.dy)
        ..lineTo(wrist.dx, wrist.dy),
      limb,
    );
    limb.strokeWidth = s * 0.06;
    for (var f = 0; f < 3; f++) {
      canvas.drawLine(
        wrist,
        wrist + Offset(s * (0.18 - f * 0.02), s * (0.06 + f * 0.07)),
        limb,
      );
    }
  }
  // The head, lolling forward and to one side, jaw hanging.
  final head = Offset(s * 0.36, -s * 2.42);
  canvas.save();
  canvas.translate(head.dx, head.dy);
  canvas.rotate(0.35 + math.sin(step * 0.5) * 0.12);
  canvas.drawOval(
    Rect.fromCenter(center: Offset.zero, width: s * 0.46, height: s * 0.54),
    body,
  );
  canvas.drawRect(Rect.fromLTWH(-s * 0.02, s * 0.12, s * 0.22, s * 0.2), body);
  final glow = Paint()..color = _a(style.glow, 0.85);
  canvas.drawCircle(Offset(s * 0.1, -s * 0.04), s * 0.045, glow);
  canvas.drawCircle(Offset(s * 0.2, s * 0.0), s * 0.04, glow);
  canvas.drawCircle(
    Offset(s * 0.15, -s * 0.02),
    s * 0.16,
    Paint()
      ..color = _a(style.glow, 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
  );
  canvas.restore();
  canvas.restore();
  if (fade < 1) canvas.restore();
}

/// Gravestones and crosses across the front, some leaning, moss on top.
void _graves(
  Canvas canvas,
  Size size,
  double t,
  double ground,
  WorldStyle style,
) {
  final w = size.width, h = size.height;
  const spots = [0.12, 0.28, 0.46, 0.63, 0.78, 0.92];
  final outline = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4
    ..color = const Color(0xFF070A08);
  final moss = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..color = _a(style.foliage[0], 0.95);
  for (var i = 0; i < spots.length; i++) {
    final x = w * spots[i];
    final s = h * (0.05 + _rand(i, 90) * 0.025);
    final lean = (_rand(i, 91) - 0.5) * 0.4;
    final y = ground + h * (0.025 + _rand(i, 92) * 0.05);
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(lean);
    final stone = Paint()
      ..shader = ui.Gradient.linear(
        Offset(-s * 0.5, -s * 1.4),
        Offset(s * 0.5, 0),
        [style.rock[0], style.rock[1], style.rock[2]],
        [0, 0.5, 1],
      );
    moss.strokeWidth = s * 0.09;
    if (i % 3 == 1) {
      // A cross.
      final post = Rect.fromLTWH(-s * 0.12, -s * 1.5, s * 0.24, s * 1.5);
      final beam = Rect.fromLTWH(-s * 0.45, -s * 1.15, s * 0.9, s * 0.22);
      for (final r in [post, beam]) {
        canvas.drawRect(r, stone);
        canvas.drawRect(r, outline);
      }
      canvas.drawLine(
        Offset(-s * 0.4, -s * 1.13),
        Offset(-s * 0.15, -s * 1.13),
        moss,
      );
    } else {
      final tomb = Path()
        ..moveTo(-s * 0.5, 0)
        ..lineTo(-s * 0.5, -s * 0.9)
        ..arcToPoint(
          Offset(s * 0.5, -s * 0.9),
          radius: Radius.circular(s * 0.5),
        )
        ..lineTo(s * 0.5, 0)
        ..close();
      canvas.drawPath(tomb, stone);
      canvas.drawPath(tomb, outline);
      // Worn carving: a few short lines.
      final carve = Paint()
        ..color = const Color(0x66070A08)
        ..strokeWidth = 1.2;
      for (var k = 0; k < 3; k++) {
        final yy = -s * (0.85 - k * 0.2);
        final half = s * (0.28 - k * 0.04);
        canvas.drawLine(Offset(-half, yy), Offset(half, yy), carve);
      }
      // A crack.
      canvas.drawPath(
        Path()
          ..moveTo(s * 0.18, -s * 1.36)
          ..lineTo(s * 0.05, -s * 1.05)
          ..lineTo(s * 0.16, -s * 0.82),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xAA070A08),
      );
      // Moss creeping over the top's left shoulder.
      canvas.drawArc(
        Rect.fromCircle(center: Offset(0, -s * 0.9), radius: s * 0.47),
        math.pi * 1.05,
        math.pi * 0.42,
        false,
        moss,
      );
    }
    canvas.restore();
  }
}

/// Now and then a hand claws its way up out of the dirt, grasps, and sinks
/// back down, soil flying. More of them, more often, as the set comes on.
void _risingHands(
  Canvas canvas,
  Size size,
  double t,
  double ground,
  double dead,
) {
  final w = size.width, h = size.height;
  const spots = [0.37, 0.71, 0.2, 0.55, 0.86];
  final count = dead > 0 ? 5 : 2;
  for (var i = 0; i < count; i++) {
    // The extra hands only reach as far as the set has come on.
    final reach = i < 2 ? 1.0 : dead;
    final x = w * spots[i];
    final y = ground + h * (0.085 + _rand(i, 97) * 0.02);
    final s = h * 0.04;
    // Each hand keeps its own rhythm, so changing it never jumps a hand.
    final cycle = 7.0 + _rand(i, 98) * 2;
    final k = ((t + i * 2.3) % cycle) / cycle;
    // Up over the first third, grasping in the middle, down at the end.
    final up =
        reach *
        (k < 0.3
            ? Curves.easeOutBack.transform(k / 0.3)
            : k < 0.7
            ? 1.0
            : k < 0.85
            ? 1 - Curves.easeIn.transform((k - 0.7) / 0.15)
            : 0.0);
    if (up > 0) {
      final grasp = k > 0.3 && k < 0.7
          ? 0.5 + 0.5 * math.sin((k - 0.3) / 0.4 * math.pi * 3)
          : 0.2;
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(x - s * 2, y - s * 3, x + s * 2, y));
      canvas.translate(x, y + s * 2.2 * (1 - up));
      canvas.rotate(-0.12 + 0.08 * math.sin(t * 2 + i) + (i.isEven ? 0 : 0.2));
      _hand(canvas, s, grasp);
      canvas.restore();
      // Soil kicked up as it breaks the surface.
      if (k < 0.35) {
        final d = k / 0.35;
        final soil = Paint()
          ..color = const Color(0xFF3A3326).withValues(alpha: (1 - d) * reach);
        for (var p = 0; p < 7; p++) {
          final a = -math.pi / 2 + (p - 3) * 0.32;
          final dist = s * (0.3 + 1.5 * d) * (0.7 + _rand(p + i * 7, 95) * 0.6);
          canvas.drawCircle(
            Offset(
              x + math.cos(a) * dist,
              y - s * 0.1 + math.sin(a) * dist + d * d * s * 1.2,
            ),
            1.4 + _rand(p, 96) * 1.4,
            soil,
          );
        }
      }
    }
    // The broken earth it comes out of, always there.
    final alpha = i < 2 ? 1.0 : dead;
    final mound = Rect.fromCenter(
      center: Offset(x, y + s * 0.05),
      width: s * 1.9,
      height: s * 0.42,
    );
    canvas.drawOval(
      mound,
      Paint()..color = const Color(0xFF15120D).withValues(alpha: alpha),
    );
    canvas.drawArc(
      mound.deflate(1),
      math.pi * 1.1,
      math.pi * 0.8,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFF3A3326).withValues(alpha: alpha),
    );
  }
}

/// A rotting hand reaching up from the wrist at the origin: a ragged
/// sleeve, a thin palm, a thumb and four bony two-jointed fingers that
/// curl as [grasp] goes to 1.
void _hand(Canvas canvas, double s, double grasp) {
  const skin = Color(0xFF7D9663);
  const shade = Color(0xFF4F6340);
  const edge = Color(0xFF1A2414);

  // The sleeve, torn at the cuff.
  canvas.drawPath(
    Path()
      ..moveTo(-s * 0.3, s * 0.4)
      ..lineTo(-s * 0.3, -s * 0.85)
      ..lineTo(-s * 0.18, -s * 0.76)
      ..lineTo(-s * 0.06, -s * 0.9)
      ..lineTo(s * 0.08, -s * 0.78)
      ..lineTo(s * 0.2, -s * 0.92)
      ..lineTo(s * 0.3, -s * 0.8)
      ..lineTo(s * 0.3, s * 0.4)
      ..close(),
    Paint()..color = const Color(0xFF2A2236),
  );

  final bone = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final knuckle = Paint()..color = shade;
  void finger(Offset base, double angle, double l1, double l2, double width) {
    final mid = base + Offset(math.sin(angle), -math.cos(angle)) * l1;
    final a2 = angle + grasp * 1.1;
    final tip = mid + Offset(math.sin(a2), -math.cos(a2)) * l2;
    final path = Path()
      ..moveTo(base.dx, base.dy)
      ..lineTo(mid.dx, mid.dy)
      ..lineTo(tip.dx, tip.dy);
    bone
      ..color = edge
      ..strokeWidth = width + 2;
    canvas.drawPath(path, bone);
    bone
      ..color = skin
      ..strokeWidth = width;
    canvas.drawPath(path, bone);
    canvas.drawCircle(mid, width * 0.32, knuckle);
  }

  // The thumb, out to the side.
  finger(
    Offset(-s * 0.2, -s * 1.02),
    -0.9 + grasp * 0.5,
    s * 0.26,
    s * 0.2,
    s * 0.13,
  );
  // The palm.
  final palm = Path()
    ..moveTo(-s * 0.18, -s * 0.8)
    ..lineTo(-s * 0.26, -s * 1.32)
    ..quadraticBezierTo(0, -s * 1.4, s * 0.26, -s * 1.3)
    ..lineTo(s * 0.18, -s * 0.8)
    ..close();
  canvas.drawPath(palm, Paint()..color = skin);
  canvas.drawPath(
    palm,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = edge,
  );
  // Rot showing through.
  canvas.drawCircle(Offset(s * 0.06, -s * 1.08), s * 0.07, knuckle);
  canvas.drawCircle(Offset(-s * 0.1, -s * 0.92), s * 0.04, knuckle);
  for (var f = 0; f < 4; f++) {
    final bx = -s * 0.19 + f * s * 0.127;
    final long = f == 1 || f == 2;
    finger(
      Offset(bx, -s * 1.32 - (long ? s * 0.03 : 0)),
      (f - 1.5) * 0.12,
      s * (long ? 0.34 : 0.28),
      s * (long ? 0.28 : 0.22),
      s * 0.105,
    );
  }
}

/// Will-o'-the-wisps: little green lights drifting low over the graves.
/// Four more come out as the set comes on.
void _wisps(Canvas canvas, Size size, double t, WorldStyle style, double dead) {
  final w = size.width, h = size.height;
  for (var i = 0; i < 10; i++) {
    final fade = i < 6 ? 1.0 : dead;
    if (fade <= 0) continue;
    final x =
        w * _rand(i, 100) +
        math.sin(t * (0.3 + _rand(i, 101) * 0.4) + i) * w * 0.05;
    final y =
        h * (0.72 + _rand(i, 102) * 0.2) +
        math.cos(t * 0.5 + i * 2) * h * 0.015;
    final pulse = 0.5 + 0.5 * math.sin(t * (1.4 + _rand(i, 103)) + i);
    canvas.drawCircle(
      Offset(x, y),
      6 + 4 * pulse,
      Paint()
        ..color = _a(style.glow, 0.18 * pulse * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(
      Offset(x, y),
      1.6 + pulse,
      Paint()..color = _a(style.sparkles[1], (0.6 + 0.4 * pulse) * fade),
    );
  }
}
