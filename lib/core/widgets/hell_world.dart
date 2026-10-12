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

const _lava = Color(0xFFFF7A1A);
const _lavaHot = Color(0xFFFFD27A);
const _basalt = Color(0xFF0E0504);

/// A jagged ridge from x = 0 to [w] around [base], up to [height] tall.
List<Offset> _peaks(double w, double base, double height, int seed) {
  final pts = <Offset>[Offset(0, base)];
  const steps = 18;
  for (var i = 0; i <= steps; i++) {
    final u = i / steps;
    final spike = i.isEven ? 1.0 : 0.45 + 0.3 * _rand(i, seed);
    final y = base - height * spike * (0.55 + 0.45 * _rand(i, seed + 1));
    pts.add(Offset(w * u, y));
  }
  pts.add(Offset(w, base));
  return pts;
}

/// Hell: everything in front of the sky. Smoke rolls under the [moon], the
/// peaks glow with lava veins, the volcano smokes, the black citadel's
/// windows burn, fire pits flicker along the ledges and the lava river runs.
/// With the set on (Inferno worn here, [WorldSets.hell]) the volcano erupts,
/// fire rains down, a horned shadow looms in the smoke with burning eyes,
/// and the heat pulses.
void paintHellScene(
  Canvas canvas,
  Size size,
  double t,
  WorldStyle style, {
  required Offset moon,
}) {
  final w = size.width;
  final h = size.height;
  final burning = WorldSets.hell.amount;

  if (burning > 0) _horned(canvas, size, t, burning);
  _smoke(canvas, size, t, y: h * 0.3, thick: 0.5 + 0.4 * burning, seed: 1);
  _bats(canvas, size, t, 4 + (burning * 3).round());

  // Far peaks with lava veins.
  final far = _peaks(w, h * 0.66, h * 0.18, 11);
  _ridge(canvas, size, far, style.layers[0], h * 0.48);
  _veins(canvas, far, t, h, 0.6 + 0.4 * burning, 3);
  // Their feet sink behind the nearer peaks.
  _volcano(canvas, Offset(w * 0.7, h * 0.8), w * 0.62, t, burning);
  _citadel(canvas, Offset(w * 0.2, h * 0.77), h * 0.24, t, style);

  final mid = _peaks(w, h * 0.78, h * 0.1, 23);
  _ridge(canvas, size, mid, style.layers[1], h * 0.66);
  _veins(canvas, mid, t, h, 0.7 + 0.3 * burning, 5);
  _smoke(canvas, size, t, y: h * 0.7, thick: 0.35 + 0.3 * burning, seed: 2);

  _lavaRiver(canvas, size, t, top: h * 0.86, burning: burning);
  for (final (x, y, s) in const [
    (0.1, 0.84, 1.0),
    (0.42, 0.83, 0.8),
    (0.9, 0.85, 1.1),
  ]) {
    _ledge(canvas, Offset(w * x, h * y), w * 0.16 * s, t, style);
  }
  if (burning > 0) _fireRain(canvas, size, t, burning);
  _embers(canvas, size, t, style, 22 + (burning * 22).round());

  // The heat: a red pulse at the edges.
  final rect = Offset.zero & size;
  final beat = 0.5 + 0.5 * math.sin(t * (1.2 + burning));
  canvas.drawRect(
    rect,
    Paint()
      ..shader = RadialGradient(
        radius: 0.95,
        colors: [
          Colors.transparent,
          _a(
            const Color(0xFF6A0A04),
            (0.25 + 0.3 * burning) * (0.7 + 0.3 * beat),
          ),
        ],
      ).createShader(rect),
  );
}

void _ridge(
  Canvas canvas,
  Size size,
  List<Offset> ridge,
  (Color, Color) colors,
  double top,
) {
  canvas.drawPath(
    Path()..addPolygon([
      ...ridge,
      Offset(size.width, size.height),
      Offset(0, size.height),
    ], true),
    Paint()
      ..shader = ui.Gradient.linear(Offset(0, top), Offset(0, size.height), [
        colors.$1,
        colors.$2,
      ]),
  );
}

/// Glowing cracks running down from the ridge's peaks.
void _veins(
  Canvas canvas,
  List<Offset> ridge,
  double t,
  double h,
  double strength,
  int seed,
) {
  final glow = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  for (var i = 1; i < ridge.length - 1; i += 2) {
    final p = ridge[i];
    final pulse = 0.55 + 0.45 * math.sin(t * 1.6 + i * 1.3 + seed);
    final path = Path()..moveTo(p.dx, p.dy + 3);
    var x = p.dx;
    var y = p.dy + 3;
    for (var k = 0; k < 4; k++) {
      x += (_rand(i * 5 + k, seed) - 0.5) * 14;
      y += h * 0.025;
      path.lineTo(x, y);
    }
    glow
      ..strokeWidth = 5
      ..color = _a(_lava, 0.25 * strength * pulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(path, glow);
    glow
      ..strokeWidth = 1.6
      ..maskFilter = null
      ..color = _a(_lavaHot, 0.8 * strength * pulse);
    canvas.drawPath(path, glow);
  }
}

/// The volcano: a black cone, its crater glowing, smoke rising. Erupting
/// ([burning]), it throws lava bombs in arcs.
void _volcano(
  Canvas canvas,
  Offset base,
  double width,
  double t,
  double burning,
) {
  final hgt = width * 0.72;
  final rim = base.translate(0, -hgt);
  final cone = Path()
    ..moveTo(base.dx - width / 2, base.dy)
    ..quadraticBezierTo(
      rim.dx - width * 0.12,
      rim.dy + hgt * 0.3,
      rim.dx - width * 0.08,
      rim.dy,
    )
    ..lineTo(rim.dx + width * 0.08, rim.dy)
    ..quadraticBezierTo(
      rim.dx + width * 0.12,
      rim.dy + hgt * 0.3,
      base.dx + width / 2,
      base.dy,
    )
    ..close();
  canvas.drawPath(
    cone,
    Paint()
      ..shader = ui.Gradient.linear(rim, base, [
        const Color(0xFF55201A),
        _basalt,
      ]),
  );
  // Its edge caught by the glow, so it stands off the peaks behind.
  canvas.drawPath(
    cone,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = ui.Gradient.linear(rim, base, [_a(_lava, 0.7), _a(_lava, 0)]),
  );
  // Lava spilling down from the crater.
  for (final side in const [-1.0, 0.3, 1.0]) {
    final flow = Path()
      ..moveTo(rim.dx + side * width * 0.04, rim.dy + 2)
      ..quadraticBezierTo(
        rim.dx + side * width * 0.1,
        rim.dy + hgt * 0.45,
        rim.dx + side * width * 0.2,
        rim.dy + hgt * (0.55 + 0.2 * side.abs()),
      );
    canvas.drawPath(
      flow,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = _a(_lava, 0.75 + 0.25 * math.sin(t * 2 + side)),
    );
  }
  final heat = 0.6 + 0.4 * math.sin(t * 1.8) + 0.4 * burning;
  canvas.drawOval(
    Rect.fromCenter(center: rim, width: width * 0.3, height: width * 0.12),
    Paint()
      ..color = _a(_lava, (0.5 * heat).clamp(0.0, 1.0))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.05),
  );
  canvas.drawOval(
    Rect.fromCenter(center: rim, width: width * 0.16, height: width * 0.04),
    Paint()..color = _lavaHot,
  );
  // Smoke billowing up.
  for (var i = 0; i < 6; i++) {
    final k = (t * 0.08 + i / 6) % 1.0;
    final r = width * (0.06 + 0.16 * k);
    canvas.drawCircle(
      rim.translate(
        math.sin(k * 5 + i) * width * 0.1 + k * width * 0.15,
        -k * hgt * 1.6,
      ),
      r,
      Paint()
        ..color = const Color(0xFF1A0A08).withValues(alpha: 0.55 * (1 - k))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.4),
    );
  }
  // Lava bombs.
  if (burning > 0) {
    for (var i = 0; i < 7; i++) {
      final cycle = 1.6 + _rand(i, 60) * 1.2;
      final k = ((t + _rand(i, 61) * cycle) % cycle) / cycle;
      final vx = (_rand(i, 62) - 0.5) * width * 0.9;
      final vy = hgt * (1.2 + _rand(i, 63));
      final p = rim + Offset(vx * k, -vy * k + vy * 1.6 * k * k);
      canvas.drawCircle(
        p,
        3.2 * burning,
        Paint()..color = _a(_lavaHot, burning * (1 - k * 0.6)),
      );
      canvas.drawCircle(
        p,
        7 * burning,
        Paint()
          ..color = _a(_lava, 0.35 * burning)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }
}

/// A black citadel of spiked towers on its crag, windows burning.
void _citadel(
  Canvas canvas,
  Offset base,
  double s,
  double t,
  WorldStyle style,
) {
  final dark = Paint()..color = const Color(0xFF090202);
  const towers = [
    (-0.5, 0.55, 0.16),
    (-0.22, 0.85, 0.2),
    (0.08, 1.0, 0.24),
    (0.38, 0.7, 0.18),
  ];
  for (final (dx, tall, wide) in towers) {
    final x = base.dx + dx * s;
    final top = base.dy - s * tall;
    canvas.drawRect(
      Rect.fromLTRB(x - s * wide / 2, top, x + s * wide / 2, base.dy),
      dark,
    );
    canvas.drawPath(
      Path()
        ..moveTo(x - s * wide / 2 - 2, top)
        ..lineTo(x, top - s * 0.28)
        ..lineTo(x + s * wide / 2 + 2, top)
        ..close(),
      dark,
    );
    // Windows flickering.
    for (var k = 0; k < 3; k++) {
      final flicker = 0.5 + 0.5 * math.sin(t * (3 + k) + dx * 9 + k);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(x, top + s * (0.15 + k * 0.2)),
          width: s * 0.035,
          height: s * 0.07,
        ),
        Paint()..color = _a(style.glow, 0.5 + 0.5 * flicker),
      );
    }
  }
  canvas.drawRect(
    Rect.fromLTRB(
      base.dx - s * 0.6,
      base.dy - s * 0.3,
      base.dx + s * 0.5,
      base.dy,
    ),
    dark,
  );
  canvas.drawCircle(
    base.translate(0, -s * 0.5),
    s * 0.7,
    Paint()
      ..color = _a(_lava, 0.08 + 0.04 * math.sin(t))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.3),
  );
}

/// Smoke drifting across in a band around [y].
void _smoke(
  Canvas canvas,
  Size size,
  double t, {
  required double y,
  required double thick,
  required int seed,
}) {
  final w = size.width;
  for (var i = 0; i < 6; i++) {
    final span = w * 1.8;
    final speed = 4 + _rand(i * 3 + seed, 70) * 5;
    final x = (t * speed + _rand(i + seed * 10, 71) * span) % span - w * 0.4;
    final yy = y + (_rand(i, 72 + seed) - 0.5) * size.height * 0.08;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, yy),
        width: w * (0.5 + _rand(i, 73) * 0.4),
        height: size.height * 0.07,
      ),
      Paint()
        ..color = const Color(0xFF2A0A06).withValues(alpha: 0.5 * thick)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
  }
}

/// The lava river along the bottom: waves of molten rock flowing, crusts
/// drifting, bubbles popping.
void _lavaRiver(
  Canvas canvas,
  Size size,
  double t, {
  required double top,
  required double burning,
}) {
  final w = size.width;
  final h = size.height;
  final surface = Path()..moveTo(0, h);
  for (var i = 0; i <= 30; i++) {
    final x = w * i / 30;
    final y =
        top + math.sin(i * 0.7 + t * 1.2) * 4 + math.sin(i * 1.9 - t * 0.8) * 2;
    surface.lineTo(x, y);
  }
  surface
    ..lineTo(w, h)
    ..close();
  canvas.drawPath(
    surface,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, top),
        Offset(0, h),
        [_lavaHot, _lava, const Color(0xFFB0300A)],
        [0, 0.35, 1],
      ),
  );
  // Dark crusts floating along.
  for (var i = 0; i < 9; i++) {
    final speed = 10 + _rand(i, 80) * 8;
    final x = (t * speed + _rand(i, 81) * w * 1.3) % (w * 1.3) - w * 0.15;
    final y = top + (h - top) * (0.25 + _rand(i, 82) * 0.6);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, y),
        width: 18 + _rand(i, 83) * 22,
        height: 5,
      ),
      Paint()..color = const Color(0xFF5A1406).withValues(alpha: 0.75),
    );
  }
  // Bubbles.
  for (var i = 0; i < 6 + (burning * 6).round(); i++) {
    final cycle = 1.5 + _rand(i, 84);
    final k = ((t + _rand(i, 85) * cycle) % cycle) / cycle;
    final x = w * _rand(i, 86);
    final y = top + (h - top) * (0.2 + 0.5 * _rand(i, 87));
    final r = 2 + 6 * k;
    canvas.drawCircle(
      Offset(x, y - k * 4),
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = _lavaHot.withValues(alpha: 1 - k),
    );
  }
  // The glow off it.
  canvas.drawRect(
    Rect.fromLTRB(0, top - 40, w, top + 10),
    Paint()
      ..shader = ui.Gradient.linear(Offset(0, top - 40), Offset(0, top + 10), [
        const Color(0x00FF7A1A),
        _a(_lava, 0.35 + 0.2 * burning),
      ]),
  );
}

/// A rock ledge over the lava with a fire pit burning on it.
void _ledge(Canvas canvas, Offset c, double s, double t, WorldStyle style) {
  canvas.drawPath(
    Path()
      ..moveTo(c.dx - s * 0.6, c.dy)
      ..lineTo(c.dx - s * 0.45, c.dy - s * 0.18)
      ..lineTo(c.dx + s * 0.5, c.dy - s * 0.2)
      ..lineTo(c.dx + s * 0.62, c.dy + s * 0.05)
      ..lineTo(c.dx + s * 0.3, c.dy + s * 0.22)
      ..lineTo(c.dx - s * 0.4, c.dy + s * 0.2)
      ..close(),
    Paint()
      ..shader = ui.Gradient.linear(
        c.translate(0, -s * 0.2),
        c.translate(0, s * 0.2),
        [style.rock[1], style.rock[2]],
      ),
  );
  _flame(canvas, c.translate(0, -s * 0.2), s * 0.35, t, c.dx);
}

/// A licking flame: three tongues swaying, hot at the core.
void _flame(Canvas canvas, Offset base, double s, double t, double seed) {
  canvas.drawCircle(
    base.translate(0, -s * 0.4),
    s * 0.9,
    Paint()
      ..color = _a(_lava, 0.25 + 0.1 * math.sin(t * 5 + seed))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.5),
  );
  for (var k = 0; k < 3; k++) {
    final scale = 1 - k * 0.28;
    final sway = math.sin(t * (6 + k * 2) + seed) * s * 0.12;
    final lick = 1 + 0.18 * math.sin(t * (9 + k * 3) + seed * 2);
    final hgt = s * 1.4 * scale * lick;
    final wid = s * 0.5 * scale;
    final tongue = Path()
      ..moveTo(base.dx - wid, base.dy)
      ..quadraticBezierTo(
        base.dx - wid * 1.1,
        base.dy - hgt * 0.5,
        base.dx + sway,
        base.dy - hgt,
      )
      ..quadraticBezierTo(
        base.dx + wid * 1.1,
        base.dy - hgt * 0.5,
        base.dx + wid,
        base.dy,
      )
      ..close();
    canvas.drawPath(
      tongue,
      Paint()
        ..color = switch (k) {
          0 => const Color(0xFFD9381F),
          1 => _lava,
          _ => _lavaHot,
        },
    );
  }
}

/// Fire raining down in streaks.
void _fireRain(Canvas canvas, Size size, double t, double amount) {
  final w = size.width;
  final h = size.height;
  for (var i = 0; i < 18; i++) {
    final speed = 0.25 + _rand(i, 90) * 0.25;
    final k = (t * speed + _rand(i, 91)) % 1.0;
    final x = w * _rand(i, 92) + k * 30;
    final y = -40 + k * (h * 0.9);
    canvas.drawLine(
      Offset(x, y),
      Offset(x - 8, y - 26),
      Paint()
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(Offset(x, y), Offset(x - 8, y - 26), [
          _a(_lavaHot, amount),
          _a(_lava, 0),
        ]),
    );
  }
}

/// A huge horned shadow in the smoke, its eyes burning and blinking.
void _horned(Canvas canvas, Size size, double t, double amount) {
  final w = size.width;
  final h = size.height;
  final c = Offset(w * 0.5, h * 0.27 + math.sin(t * 0.3) * 6);
  final s = w * 0.42;
  final shade = Paint()
    ..color = const Color(0xFF0A0202).withValues(alpha: 0.75 * amount)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.06);
  canvas.drawOval(Rect.fromCenter(center: c, width: s, height: s * 0.8), shade);
  // The horns come through the smoke sharper than the head.
  shade
    ..color = const Color(0xFF0A0202).withValues(alpha: 0.9 * amount)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.015);
  for (final side in const [-1.0, 1.0]) {
    canvas.drawPath(
      Path()
        ..moveTo(c.dx + side * s * 0.3, c.dy - s * 0.2)
        ..quadraticBezierTo(
          c.dx + side * s * 0.62,
          c.dy - s * 0.45,
          c.dx + side * s * 0.5,
          c.dy - s * 0.78,
        )
        ..quadraticBezierTo(
          c.dx + side * s * 0.46,
          c.dy - s * 0.4,
          c.dx + side * s * 0.14,
          c.dy - s * 0.3,
        )
        ..close(),
      shade,
    );
  }
  // A slow, heavy blink every nine seconds: the lids sink over most of a
  // second, stay shut a moment, then lift again. In between, the glow
  // breathes.
  final b = t % 9.0;
  final shut = b < 0.8
      ? Curves.easeInOut.transform(b / 0.8)
      : b < 1.3
      ? 1.0
      : b < 2.6
      ? 1 - Curves.easeInOut.transform((b - 1.3) / 1.3)
      : 0.0;
  final blink = 1 - 0.94 * shut;
  final breathe = 0.75 + 0.25 * math.sin(t * 0.6);
  for (final side in const [-1.0, 1.0]) {
    final eye = c.translate(side * s * 0.14, -s * 0.02);
    canvas.drawOval(
      Rect.fromCenter(center: eye, width: s * 0.1, height: s * 0.035 * blink),
      Paint()..color = _a(const Color(0xFFFF3A1A), amount),
    );
    canvas.drawCircle(
      eye,
      s * 0.08,
      Paint()
        ..color = _a(const Color(0xFFFF3A1A), 0.35 * amount * blink * breathe)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.04),
    );
  }
}

/// Bats flitting across, wings beating fast.
void _bats(Canvas canvas, Size size, double t, int count) {
  final w = size.width;
  final h = size.height;
  final ink = Paint()..color = const Color(0xFF070101);
  for (var i = 0; i < count; i++) {
    final speed = 20 + _rand(i, 50) * 16;
    final span = w + 80;
    final x = (t * speed + _rand(i, 51) * span) % span - 40;
    final y = h * (0.12 + _rand(i, 52) * 0.4) + math.sin(t * 2 + i) * 12;
    final s = 4 + _rand(i, 53) * 4;
    final flap = math.sin(t * (14 + _rand(i, 54) * 6) + i);
    canvas.drawPath(
      Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(
          x - s,
          y - s * (0.4 + flap),
          x - s * 2,
          y - s * 0.2 * flap,
        )
        ..lineTo(x - s * 1.4, y + s * 0.2)
        ..lineTo(x - s * 0.8, y)
        ..lineTo(x - s * 0.4, y + s * 0.4)
        ..lineTo(x, y + s * 0.15)
        ..lineTo(x + s * 0.4, y + s * 0.4)
        ..lineTo(x + s * 0.8, y)
        ..lineTo(x + s * 1.4, y + s * 0.2)
        ..lineTo(x + s * 2, y - s * 0.2 * flap)
        ..quadraticBezierTo(x + s, y - s * (0.4 + flap), x, y)
        ..close(),
      ink,
    );
  }
}

/// Embers rising and winking out.
void _embers(Canvas canvas, Size size, double t, WorldStyle style, int count) {
  final w = size.width;
  final h = size.height;
  for (var i = 0; i < count; i++) {
    final speed = 0.06 + _rand(i, 100) * 0.08;
    final k = (t * speed + _rand(i, 101)) % 1.0;
    final x = w * _rand(i, 102) + math.sin(t * 1.3 + i) * 14;
    final y = h * (1.0 - k * 0.95);
    final fade = math.sin(k * math.pi);
    final c = style.sparkles[i % 3];
    canvas.drawCircle(
      Offset(x, y),
      1.2 + _rand(i, 103) * 1.6,
      Paint()..color = _a(c, fade),
    );
  }
}
