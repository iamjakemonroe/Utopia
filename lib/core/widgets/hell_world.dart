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
const _blood = Color(0xFFD9201A);
const _basalt = Color(0xFF0E0504);
const _ink = Color(0xFF050101);

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

/// Hell: everything in front of the sky. Thick storm clouds lit red from
/// below roll over the blood moon, red lightning splits them, and a giant
/// face watches from them, its slit eyes slowly opening. A wall of fire
/// burns behind the black peaks; chains and hooks hang from above; the
/// volcano smokes, the citadel's windows burn, skulls sit by the fire pits
/// and the lava sea's crust cracks and bursts into geysers.
///
/// With the set on (Inferno worn here, [WorldSets.hell]) all of it goes to
/// extremes: the fire wall roars higher, the volcano erupts, the face opens
/// its eyes and its burning mouth, lightning comes fast, fire rains, and
/// flames lick up the bottom of the screen.
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

  // The sky darkens and reddens as the set comes on.
  canvas.drawRect(
    Rect.fromLTRB(0, 0, w, h * 0.7),
    Paint()
      ..shader = ui.Gradient.linear(Offset.zero, Offset(0, h * 0.7), [
        _a(_ink, 0.55),
        _a(const Color(0xFF5A0804), 0.25 * burning),
      ]),
  );
  final watching = 0.45 + 0.55 * burning;
  _watcher(canvas, size, t, watching, burning);
  _stormClouds(canvas, size, t, burning);
  _watcherGlow(canvas, size, t, watching, burning);
  _lightning(canvas, size, t, burning);
  _chains(canvas, size, t);
  _bats(canvas, size, t, 5 + (burning * 4).round());

  // Far peaks with lava veins.
  final far = _peaks(w, h * 0.66, h * 0.18, 11);
  _ridge(canvas, size, far, style.layers[0], h * 0.48);
  _veins(canvas, far, t, h, 0.6 + 0.4 * burning, 3);
  // Their feet sink behind the nearer peaks.
  _volcano(canvas, Offset(w * 0.7, h * 0.8), w * 0.62, t, burning);
  _citadel(canvas, Offset(w * 0.2, h * 0.77), h * 0.24, t, style);
  // The fire wall, behind the nearer peaks so they stand black against it.
  _fireWall(canvas, size, t, h * 0.775, burning);

  final mid = _peaks(w, h * 0.78, h * 0.1, 23);
  _ridge(canvas, size, mid, style.layers[1], h * 0.66);
  _veins(canvas, mid, t, h, 0.7 + 0.3 * burning, 5);
  _smoke(canvas, size, t, y: h * 0.72, thick: 0.5 + 0.4 * burning, seed: 2);

  _lavaSea(canvas, size, t, top: h * 0.86, burning: burning);
  _geysers(canvas, size, t, top: h * 0.86, burning: burning);
  for (final (x, y, s) in const [
    (0.1, 0.84, 1.0),
    (0.42, 0.83, 0.8),
    (0.9, 0.85, 1.1),
  ]) {
    _ledge(canvas, Offset(w * x, h * y), w * 0.16 * s, t, style, burning);
  }
  _deadTree(canvas, Offset(-w * 0.02, h * 0.9), h * 0.36, t);
  _thorns(canvas, size, t);
  _ash(canvas, size, t, 26 + (burning * 20).round());
  if (burning > 0) _fireRain(canvas, size, t, burning);
  _embers(canvas, size, t, style, 26 + (burning * 30).round());
  if (burning > 0) _hellfire(canvas, size, t, burning);

  // Darkness closing in at the edges, and the heat pulsing red.
  final rect = Offset.zero & size;
  final beat = 0.5 + 0.5 * math.sin(t * (1.4 + burning * 1.6));
  canvas.drawRect(
    rect,
    Paint()
      ..shader = RadialGradient(
        radius: 0.9,
        colors: [Colors.transparent, _a(_ink, 0.55)],
        stops: const [0.55, 1],
      ).createShader(rect),
  );
  canvas.drawRect(
    rect,
    Paint()
      ..shader = RadialGradient(
        radius: 1.0,
        colors: [
          Colors.transparent,
          _a(
            const Color(0xFF8A0A04),
            (0.18 + 0.35 * burning) * (0.6 + 0.4 * beat),
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

/// Thick, low storm clouds rolling slowly over the sky, black above and lit
/// red underneath by the fires.
void _stormClouds(Canvas canvas, Size size, double t, double burning) {
  final w = size.width;
  final h = size.height;
  for (var i = 0; i < 9; i++) {
    final span = w * 1.7;
    final speed = 3 + _rand(i, 300) * 4;
    final cx = (t * speed + _rand(i, 301) * span) % span - w * 0.35;
    final cy = h * (0.03 + _rand(i, 302) * 0.34);
    final s = w * (0.3 + _rand(i, 303) * 0.24);
    final under = Offset(cx, cy + s * 0.22);
    canvas.drawCircle(
      under,
      s * 0.7,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _a(const Color(0xFFFF3A0A), 0.2 + 0.25 * burning),
            const Color(0x00FF3A0A),
          ],
        ).createShader(Rect.fromCircle(center: under, radius: s * 0.7)),
    );
    for (var k = 0; k < 4; k++) {
      final p = Offset(
        cx + (k - 1.5) * s * 0.3,
        cy + math.sin(k * 1.7 + i + t * 0.2) * s * 0.07,
      );
      final r = s * (0.25 + 0.1 * _rand(i * 4 + k, 304));
      canvas.drawCircle(
        p,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: const [
              Color(0xF2070101),
              Color(0xC8110302),
              Color(0x00110302),
            ],
            stops: const [0, 0.6, 1],
          ).createShader(Rect.fromCircle(center: p, radius: r)),
      );
    }
  }
}

/// Red lightning now and then: the sky flashes and a jagged bolt cracks
/// down through the clouds. Much more often with the set on.
void _lightning(Canvas canvas, Size size, double t, double burning) {
  final period = 7.0 - 4.4 * burning;
  final k = t % period;
  if (k > 0.4) return;
  final n = (t / period).floor();
  final flash = k < 0.07
      ? 1.0
      : k < 0.14
      ? 0.25
      : k < 0.22
      ? 0.85
      : (0.4 - k) / 0.18;
  canvas.drawRect(
    Offset.zero & size,
    Paint()..color = _a(const Color(0xFFFF2A1A), 0.14 * flash),
  );
  var p = Offset(size.width * (0.12 + 0.76 * _rand(n, 310)), size.height * 0.1);
  final bolt = Path()..moveTo(p.dx, p.dy);
  final branch = Path();
  for (var i = 0; i < 10; i++) {
    p += Offset(
      (_rand(n * 10 + i, 311) - 0.5) * size.width * 0.09,
      size.height * 0.05,
    );
    bolt.lineTo(p.dx, p.dy);
    if (i == 4) {
      branch.moveTo(p.dx, p.dy);
      branch.lineTo(
        p.dx + size.width * 0.08 * (_rand(n, 312) - 0.3),
        p.dy + size.height * 0.07,
      );
      branch.lineTo(
        p.dx + size.width * 0.12 * (_rand(n, 313) - 0.2),
        p.dy + size.height * 0.12,
      );
    }
  }
  for (final path in [bolt, branch]) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeJoin = StrokeJoin.round
        ..color = _a(const Color(0xFFFF2A1A), 0.4 * flash)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..color = _a(const Color(0xFFFFE6D6), flash),
    );
  }
}

/// A giant horned face in the clouds. Always there, faintly, its slit eyes
/// slowly opening and shutting; with the set on ([burning]) it shows
/// itself, eyes blazing wide and a burning, fanged grin opening.
void _watcher(
  Canvas canvas,
  Size size,
  double t,
  double amount,
  double burning,
) {
  final (c, s) = _watcherAt(size, t, burning);

  // The head: a darker shape in the dark, its edge just catching the glow.
  canvas.drawOval(
    Rect.fromCenter(center: c, width: s, height: s * 0.86),
    Paint()
      ..shader = RadialGradient(
        colors: [
          _a(const Color(0xFF000000), 0.85 * amount),
          _a(const Color(0xFF070101), 0.6 * amount),
          const Color(0x00070101),
        ],
        stops: const [0, 0.7, 1],
      ).createShader(Rect.fromCenter(center: c, width: s, height: s * 0.86)),
  );
  for (final side in const [-1.0, 1.0]) {
    final horn = Path()
      ..moveTo(c.dx + side * s * 0.26, c.dy - s * 0.24)
      ..cubicTo(
        c.dx + side * s * 0.62,
        c.dy - s * 0.42,
        c.dx + side * s * 0.62,
        c.dy - s * 0.78,
        c.dx + side * s * 0.38,
        c.dy - s * 0.92,
      )
      ..cubicTo(
        c.dx + side * s * 0.5,
        c.dy - s * 0.66,
        c.dx + side * s * 0.4,
        c.dy - s * 0.44,
        c.dx + side * s * 0.1,
        c.dy - s * 0.32,
      )
      ..close();
    canvas.drawPath(horn, Paint()..color = _a(_ink, 0.92 * amount));
    canvas.drawPath(
      horn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = _a(_blood, 0.35 * amount),
    );
  }
}

/// Where the watcher's face is, and how big, at [t].
(Offset, double) _watcherAt(Size size, double t, double burning) => (
  Offset(size.width * 0.5, size.height * 0.24 + math.sin(t * 0.3) * 6),
  size.width * (0.6 + 0.15 * burning),
);

/// The watcher's eyes and mouth, glowing through the clouds.
void _watcherGlow(
  Canvas canvas,
  Size size,
  double t,
  double amount,
  double burning,
) {
  final (c, s) = _watcherAt(size, t, burning);
  // The eyes: slowly opening and shutting on their own, wide open and
  // blazing with the set on.
  final cycle = (t % 14.0) / 14.0;
  final idle = cycle < 0.2
      ? Curves.easeInOut.transform(cycle / 0.2)
      : cycle < 0.6
      ? 1.0
      : cycle < 0.75
      ? 1 - Curves.easeInOut.transform((cycle - 0.6) / 0.15)
      : 0.0;
  final open = (idle * (1 - burning) + burning).clamp(0.0, 1.0);
  final blaze = 0.75 + 0.25 * math.sin(t * 2.2);
  for (final side in const [-1.0, 1.0]) {
    final eye = c.translate(side * s * 0.15, -s * 0.03);
    final ew = s * 0.16;
    final eh = s * 0.075 * open;
    if (eh > 0.5) {
      canvas.drawCircle(
        eye,
        s * 0.15,
        Paint()
          ..shader = RadialGradient(
            colors: [
              _a(const Color(0xFFFF6A1A), 0.5 * amount * open * blaze),
              const Color(0x00FF6A1A),
            ],
          ).createShader(Rect.fromCircle(center: eye, radius: s * 0.15)),
      );
      // A slanted, almond eye, angled down toward the nose.
      canvas.save();
      canvas.translate(eye.dx, eye.dy);
      canvas.rotate(side * 0.28);
      final almond = Path()
        ..moveTo(-ew / 2, 0)
        ..quadraticBezierTo(0, -eh * 1.2, ew / 2, 0)
        ..quadraticBezierTo(0, eh * 1.2, -ew / 2, 0)
        ..close();
      canvas.drawPath(
        almond,
        Paint()
          ..shader =
              RadialGradient(
                colors: [
                  _a(const Color(0xFFFFF0A0), amount),
                  _a(const Color(0xFFFF8A1A), amount),
                  _a(_blood, amount),
                ],
              ).createShader(
                Rect.fromCenter(center: Offset.zero, width: ew, height: ew),
              ),
      );
      // The slit pupil, looking slowly around.
      final look = math.sin(t * 0.4) * ew * 0.18;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(look, 0),
          width: ew * 0.12,
          height: eh * 1.9,
        ),
        Paint()..color = _a(_ink, amount),
      );
      canvas.restore();
    }
  }

  // The grin: a wide, wicked smile burning from inside, with fangs.
  if (burning > 0) {
    final gape = burning * (0.8 + 0.2 * math.sin(t * 1.3));
    final m = c.translate(0, s * 0.2);
    final mw = s * 0.52;
    final lift = s * 0.07; // how far the corners curl up
    final open = s * 0.13 * gape;
    final left = m.translate(-mw / 2, -lift);
    final right = m.translate(mw / 2, -lift);
    final grin = Path()
      ..moveTo(left.dx, left.dy)
      ..quadraticBezierTo(m.dx, m.dy + lift * 0.6, right.dx, right.dy)
      ..quadraticBezierTo(m.dx, m.dy + lift + open * 2, left.dx, left.dy)
      ..close();
    canvas.drawPath(
      grin,
      Paint()
        ..shader = ui.Gradient.linear(
          m.translate(0, -lift),
          m.translate(0, lift + open * 1.4),
          [
            _a(const Color(0xFFFFE08A), burning),
            _a(const Color(0xFFFF5A10), burning),
            _a(const Color(0xFF7A0804), burning),
          ],
          const [0, 0.45, 1],
        ),
    );
    canvas.drawCircle(
      m.translate(0, open * 0.5),
      mw * 0.7,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _a(const Color(0xFFFF5A10), 0.25 * burning),
            const Color(0x00FF5A10),
          ],
        ).createShader(Rect.fromCircle(center: m, radius: mw * 0.7)),
    );
    // Fangs hanging from the upper lip, and two rising from below.
    final fang = Paint()..color = _a(const Color(0xFFF4E9DA), burning);
    for (final (u, long, up) in const [
      (0.18, 1.0, false),
      (0.36, 0.6, false),
      (0.64, 0.6, false),
      (0.82, 1.0, false),
      (0.3, 0.55, true),
      (0.7, 0.55, true),
    ]) {
      final x = left.dx + mw * u;
      final curve = 4 * u * (1 - u);
      final topY = left.dy + (lift * 1.3) * curve;
      final bottomY = left.dy + (lift * 1.6 + open * 2) * curve * 0.92;
      final wide = mw * 0.045;
      final len = open * 1.1 * long + s * 0.02;
      canvas.drawPath(
        up
            ? (Path()
                ..moveTo(x - wide, bottomY)
                ..lineTo(x + wide, bottomY)
                ..lineTo(x, bottomY - len)
                ..close())
            : (Path()
                ..moveTo(x - wide, topY)
                ..lineTo(x + wide, topY)
                ..lineTo(x, topY + len)
                ..close()),
        fang,
      );
    }
  }
}

/// Chains hanging from above, each ending in a hook, swaying slowly.
void _chains(Canvas canvas, Size size, double t) {
  final w = size.width;
  final h = size.height;
  final iron = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..color = const Color(0xFF2E1E1A);
  final shine = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = const Color(0x66FF8A3D);
  for (final (x, length, phase) in const [
    (0.08, 0.3, 0.0),
    (0.9, 0.22, 1.7),
    (0.66, 0.14, 3.1),
  ]) {
    final top = Offset(w * x, -6);
    final len = h * length;
    final swing = math.sin(t * 0.7 + phase) * 0.06;
    canvas.save();
    canvas.translate(top.dx, top.dy);
    canvas.rotate(swing);
    const link = 11.0;
    for (var y = 0.0, i = 0; y < len; y += link * 0.75, i++) {
      final rect = i.isEven
          ? Rect.fromCenter(center: Offset(0, y), width: 7, height: link)
          : Rect.fromCenter(center: Offset(0, y), width: 2.5, height: link);
      canvas.drawOval(rect, iron);
      if (i.isEven) canvas.drawOval(rect.deflate(1.5), shine);
    }
    // The hook.
    final hook = Path()
      ..moveTo(0, len)
      ..lineTo(0, len + 14)
      ..arcToPoint(
        Offset(-16, len + 18),
        radius: const Radius.circular(9),
        clockwise: true,
      )
      ..lineTo(-14, len + 10);
    canvas.drawPath(
      hook,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF3A2620),
    );
    canvas.restore();
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
        const Color(0xFF3A140F),
        _basalt,
      ]),
  );
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
  // Thick black smoke billowing up.
  for (var i = 0; i < 7; i++) {
    final k = (t * 0.08 + i / 7) % 1.0;
    final r = width * (0.07 + 0.2 * k);
    final at = rim.translate(
      math.sin(k * 5 + i) * width * 0.1 + k * width * 0.15,
      -k * hgt * 1.7,
    );
    canvas.drawCircle(
      at,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF0A0303).withValues(alpha: 0.8 * (1 - k)),
            const Color(0x000A0303),
          ],
        ).createShader(Rect.fromCircle(center: at, radius: r)),
    );
  }
  // Erupting: a column of fire from the crater, and lava bombs.
  if (burning > 0) {
    _flame(
      canvas,
      rim.translate(0, 4),
      width * 0.12,
      t,
      91,
      tall: 1.6 * burning,
    );
    for (var i = 0; i < 9; i++) {
      final cycle = 1.4 + _rand(i, 60) * 1.2;
      final k = ((t + _rand(i, 61) * cycle) % cycle) / cycle;
      final vx = (_rand(i, 62) - 0.5) * width * 1.0;
      final vy = hgt * (1.3 + _rand(i, 63));
      final p = rim + Offset(vx * k, -vy * k + vy * 1.6 * k * k);
      canvas.drawCircle(
        p,
        3.6 * burning,
        Paint()..color = _a(_lavaHot, burning * (1 - k * 0.6)),
      );
      canvas.drawCircle(
        p,
        8 * burning,
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
  final dark = Paint()..color = const Color(0xFF060101);
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
        ..lineTo(x, top - s * 0.32)
        ..lineTo(x + s * wide / 2 + 2, top)
        ..close(),
      dark,
    );
    // Windows flickering like fire inside.
    for (var k = 0; k < 3; k++) {
      final flicker = 0.5 + 0.5 * math.sin(t * (3 + k) + dx * 9 + k);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(x, top + s * (0.15 + k * 0.2)),
          width: s * 0.035,
          height: s * 0.07,
        ),
        Paint()..color = _a(const Color(0xFFFF4A1A), 0.5 + 0.5 * flicker),
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
}

/// The wall of fire burning behind the near peaks, rising with the set.
void _fireWall(Canvas canvas, Size size, double t, double y, double burning) {
  final w = size.width;
  final h = size.height;
  final rise = 1 + 0.9 * burning;
  final glowTop = y - h * 0.18 * rise;
  canvas.drawRect(
    Rect.fromLTRB(0, glowTop, w, y + 6),
    Paint()
      ..shader = ui.Gradient.linear(Offset(0, glowTop), Offset(0, y), [
        const Color(0x00FF3A0A),
        _a(const Color(0xFFFF4A10), 0.5 + 0.3 * burning),
      ]),
  );
  const n = 14;
  for (var i = 0; i < n; i++) {
    final x = w * (i + 0.5) / n + (_rand(i, 200) - 0.5) * w * 0.05;
    _flame(
      canvas,
      Offset(x, y + 4),
      h * (0.034 + 0.026 * _rand(i, 201)),
      t,
      i * 7.3,
      tall: rise * (0.9 + 0.6 * _rand(i, 202)),
    );
  }
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
    final rect = Rect.fromCenter(
      center: Offset(x, yy),
      width: w * (0.5 + _rand(i, 73) * 0.4),
      height: size.height * 0.08,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF140404).withValues(alpha: 0.7 * thick),
            const Color(0x00140404),
          ],
        ).createShader(rect),
    );
  }
}

/// The lava sea: a dark crust cracked with glowing seams that drift along,
/// molten pools pulsing, bubbles bursting, and its glow on the air above.
void _lavaSea(
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
        [
          Color.lerp(const Color(0xFF6A1406), _lava, 0.3 + 0.4 * burning)!,
          const Color(0xFF2A0603),
          const Color(0xFF120202),
        ],
        const [0, 0.3, 1],
      ),
  );
  canvas.save();
  canvas.clipPath(surface);
  // Molten pools showing through the crust.
  for (var i = 0; i < 7; i++) {
    final speed = 8 + _rand(i, 330) * 6;
    final x = (t * speed + _rand(i, 331) * w * 1.4) % (w * 1.4) - w * 0.2;
    final y = top + (h - top) * (0.2 + _rand(i, 332) * 0.7);
    final r =
        w * (0.05 + 0.05 * _rand(i, 333)) * (0.85 + 0.15 * math.sin(t * 2 + i));
    final rect = Rect.fromCenter(
      center: Offset(x, y),
      width: r * 2.6,
      height: r,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [_lavaHot, _lava, const Color(0x00FF7A1A)],
          stops: const [0, 0.45, 1],
        ).createShader(rect),
    );
  }
  // The seams: glowing cracks drifting with the flow.
  for (var row = 0; row < 6; row++) {
    final y = top + (h - top) * (0.1 + row * 0.16);
    const seg = 26.0;
    final shift = t * (10 + row * 3.0);
    final first = (shift / seg).floor() - 1;
    final seam = Path();
    for (var j = first; ; j++) {
      final x = j * seg - shift;
      final yy = y + (_rand(row * 991 + j, 321) - 0.5) * 16;
      if (j == first) {
        seam.moveTo(x, yy);
      } else {
        seam.lineTo(x, yy);
      }
      if (x > w + seg) break;
    }
    final pulse = 0.6 + 0.4 * math.sin(t * 1.5 + row);
    canvas.drawPath(
      seam,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeJoin = StrokeJoin.round
        ..color = _a(_lava, 0.3 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      seam,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round
        ..color = _a(_lavaHot, 0.85 * pulse),
    );
  }
  // Bubbles swelling and bursting.
  for (var i = 0; i < 7 + (burning * 7).round(); i++) {
    final cycle = 1.4 + _rand(i, 84);
    final k = ((t + _rand(i, 85) * cycle) % cycle) / cycle;
    final x = w * _rand(i, 86);
    final y = top + (h - top) * (0.15 + 0.6 * _rand(i, 87));
    canvas.drawCircle(
      Offset(x, y - k * 4),
      2 + 7 * k,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = _lavaHot.withValues(alpha: 1 - k),
    );
  }
  canvas.restore();
  // The glow off it.
  canvas.drawRect(
    Rect.fromLTRB(0, top - 50, w, top + 10),
    Paint()
      ..shader = ui.Gradient.linear(Offset(0, top - 50), Offset(0, top + 10), [
        const Color(0x00FF7A1A),
        _a(_lava, 0.35 + 0.25 * burning),
      ]),
  );
}

/// Now and then the lava bursts: a fountain of fire shooting up, falling
/// back in drops. Bigger and more of them with the set on.
void _geysers(
  Canvas canvas,
  Size size,
  double t, {
  required double top,
  required double burning,
}) {
  final w = size.width;
  final h = size.height;
  final count = 2 + (burning * 3).round();
  for (var i = 0; i < count; i++) {
    final cycle = 4.5 + _rand(i, 340) * 3;
    final n = ((t + _rand(i, 341) * cycle) / cycle).floor();
    final k = ((t + _rand(i, 341) * cycle) % cycle) / cycle;
    if (k > 0.35) continue;
    final life = k / 0.35;
    final x = w * (0.08 + 0.84 * _rand(n * 7 + i, 342));
    final height = h * (0.12 + 0.12 * burning) * math.sin(life * math.pi);
    _flame(
      canvas,
      Offset(x, top + 6),
      w * 0.05,
      t,
      i * 13.0 + n,
      tall: height / (w * 0.05 * 1.5),
    );
    for (var d = 0; d < 6; d++) {
      final spread = (_rand(n * 11 + d, 343) - 0.5) * w * 0.12;
      final up = height * (0.6 + 0.6 * _rand(n * 11 + d, 344));
      final p = Offset(
        x + spread * life,
        top - up * life + up * 1.8 * life * life,
      );
      canvas.drawCircle(p, 2.6, Paint()..color = _a(_lavaHot, 1 - life * 0.5));
    }
  }
}

/// A rock ledge over the lava: a fire pit roaring on it and a little pile
/// of skulls beside the flames.
void _ledge(
  Canvas canvas,
  Offset c,
  double s,
  double t,
  WorldStyle style,
  double burning,
) {
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
  _skulls(canvas, c.translate(s * 0.32, -s * 0.2), s * 0.12, t);
  final glow = c.translate(0, -s * 0.5);
  canvas.drawCircle(
    glow,
    s * 0.7,
    Paint()
      ..shader = RadialGradient(
        colors: [
          _a(_lava, 0.35 + 0.1 * math.sin(t * 5 + c.dx)),
          const Color(0x00FF7A1A),
        ],
      ).createShader(Rect.fromCircle(center: glow, radius: s * 0.7)),
  );
  _flame(
    canvas,
    c.translate(-s * 0.05, -s * 0.2),
    s * 0.3,
    t,
    c.dx,
    tall: 1.1 + 0.6 * burning,
  );
}

/// Three skulls in a heap, lit orange from the fire.
void _skulls(Canvas canvas, Offset at, double s, double t) {
  final bone = Paint()
    ..shader = ui.Gradient.linear(
      at.translate(0, -s * 2),
      at.translate(0, s),
      const [Color(0xFFF0D6B8), Color(0xFF9A6A4E)],
    );
  final hole = Paint()..color = const Color(0xFF120403);
  for (final (dx, dy, k) in const [
    (-0.9, 0.0, 0.9),
    (0.9, 0.05, 0.85),
    (0.0, -1.1, 1.0),
  ]) {
    final c = at.translate(s * dx, s * dy);
    final r = s * k;
    canvas.drawCircle(c, r, bone);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: c.translate(0, r * 0.75),
          width: r * 1.1,
          height: r * 0.6,
        ),
        Radius.circular(r * 0.2),
      ),
      bone,
    );
    for (final side in const [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(side * r * 0.38, r * 0.05),
          width: r * 0.5,
          height: r * 0.55,
        ),
        hole,
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy + r * 0.32)
        ..lineTo(c.dx - r * 0.12, c.dy + r * 0.52)
        ..lineTo(c.dx + r * 0.12, c.dy + r * 0.52)
        ..close(),
      hole,
    );
  }
}

/// A dead, twisted tree reaching in from the left, black against the fire.
void _deadTree(Canvas canvas, Offset root, double s, double t) {
  final bark = Paint()
    ..color = const Color(0xFF070202)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final sway = math.sin(t * 0.5) * 0.02;
  void branch(
    Offset from,
    double angle,
    double length,
    double width,
    int depth,
  ) {
    final to = from + Offset(math.cos(angle), math.sin(angle)) * length;
    final bend =
        Offset.lerp(from, to, 0.5)! +
        Offset(math.cos(angle + 1.4), math.sin(angle + 1.4)) * length * 0.12;
    canvas.drawPath(
      Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(bend.dx, bend.dy, to.dx, to.dy),
      bark..strokeWidth = width,
    );
    if (depth == 0) return;
    branch(to, angle - 0.55 + sway, length * 0.62, width * 0.62, depth - 1);
    branch(to, angle + 0.45 + sway, length * 0.55, width * 0.58, depth - 1);
  }

  branch(root, -math.pi / 2 + 0.38, s * 0.42, s * 0.07, 4);
}

/// Black thorns jutting up in the bottom right corner.
void _thorns(Canvas canvas, Size size, double t) {
  final w = size.width;
  final h = size.height;
  final ink = Paint()..color = const Color(0xFF060101);
  for (var i = 0; i < 6; i++) {
    final x = w * (0.74 + i * 0.05);
    final tall = h * (0.06 + 0.07 * _rand(i, 350));
    final lean = (_rand(i, 351) - 0.3) * tall * 0.5;
    final wide = w * (0.03 + 0.015 * _rand(i, 352));
    canvas.drawPath(
      Path()
        ..moveTo(x - wide, h + 2)
        ..quadraticBezierTo(x - wide * 0.2, h - tall * 0.5, x + lean, h - tall)
        ..quadraticBezierTo(x + wide * 0.4, h - tall * 0.4, x + wide, h + 2)
        ..close(),
      ink,
    );
  }
}

/// A big licking flame: four tongues from deep red to a white-hot core,
/// each swaying and leaping on its own. [tall] stretches it.
void _flame(
  Canvas canvas,
  Offset base,
  double s,
  double t,
  double seed, {
  double tall = 1,
}) {
  const colors = [Color(0xFF8A0A03), Color(0xFFD9381F), _lava, _lavaHot];
  for (var k = 0; k < 4; k++) {
    final scale = 1 - k * 0.22;
    final sway =
        (math.sin(t * (5 + k * 1.7) + seed) +
            0.5 * math.sin(t * 11.3 + seed * 3 + k)) *
        s *
        0.1;
    final lick =
        1 +
        0.22 * math.sin(t * (8 + k * 2.3) + seed * 2) +
        0.1 * math.sin(t * 17 + seed);
    final hgt = s * 1.5 * tall * scale * lick;
    // Taller flames are fatter too, not thin spikes.
    final wid = s * 0.5 * scale * math.sqrt(math.max(tall, 0.3));
    final tip = Offset(base.dx + sway, base.dy - hgt);
    canvas.drawPath(
      Path()
        ..moveTo(base.dx - wid, base.dy)
        ..cubicTo(
          base.dx - wid * 1.25,
          base.dy - hgt * 0.35,
          base.dx - wid * 0.2 + sway * 0.6,
          base.dy - hgt * 0.7,
          tip.dx,
          tip.dy,
        )
        ..cubicTo(
          base.dx + wid * 0.3 + sway * 0.6,
          base.dy - hgt * 0.65,
          base.dx + wid * 1.25,
          base.dy - hgt * 0.35,
          base.dx + wid,
          base.dy,
        )
        ..close(),
      Paint()..color = colors[k],
    );
  }
}

/// Fire raining down in streaks.
void _fireRain(Canvas canvas, Size size, double t, double amount) {
  final w = size.width;
  final h = size.height;
  for (var i = 0; i < 30; i++) {
    final speed = 0.25 + _rand(i, 90) * 0.3;
    final k = (t * speed + _rand(i, 91)) % 1.0;
    final x = w * _rand(i, 92) + k * 40;
    final y = -40 + k * (h * 0.95);
    final len = 22 + _rand(i, 93) * 22;
    canvas.drawLine(
      Offset(x, y),
      Offset(x - len * 0.3, y - len),
      Paint()
        ..strokeWidth = 2.6 + _rand(i, 94) * 1.6
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(
          Offset(x, y),
          Offset(x - len * 0.3, y - len),
          [_a(_lavaHot, amount), _a(_lava, 0)],
        ),
    );
  }
}

/// Flames licking up the bottom of the screen, in front of everything,
/// when the set is on.
void _hellfire(Canvas canvas, Size size, double t, double amount) {
  final w = size.width;
  final h = size.height;
  canvas.drawRect(
    Rect.fromLTRB(0, h * 0.82, w, h),
    Paint()
      ..shader = ui.Gradient.linear(Offset(0, h * 0.82), Offset(0, h), [
        const Color(0x00FF4A10),
        _a(const Color(0xFFFF4A10), 0.45 * amount),
      ]),
  );
  const n = 9;
  for (var i = 0; i < n; i++) {
    final x = w * (i + 0.5) / n + math.sin(t * 0.7 + i) * 6;
    _flame(
      canvas,
      Offset(x, h + 8),
      w * (0.07 + 0.03 * _rand(i, 360)),
      t,
      i * 4.1 + 50,
      tall: amount * (0.9 + 0.7 * _rand(i, 361)),
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

/// Grey ash drifting down.
void _ash(Canvas canvas, Size size, double t, int count) {
  final w = size.width;
  final h = size.height;
  for (var i = 0; i < count; i++) {
    final speed = 0.03 + _rand(i, 370) * 0.04;
    final k = (t * speed + _rand(i, 371)) % 1.0;
    final x = w * _rand(i, 372) + math.sin(t * 0.8 + i) * 18;
    final y = k * h;
    canvas.drawCircle(
      Offset(x, y),
      1 + _rand(i, 373) * 1.6,
      Paint()..color = const Color(0xFF8A7A74).withValues(alpha: 0.45),
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
