import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Utopia's dragon: a sleek, smooth hero creature in the app's glossy
/// style. One flowing line from the head down the long neck and body to a
/// tail ending in a gold spade; a broad head with big glowing eyes (slit
/// pupils, no whites, like a real reptile's), ear flaps and swept gold
/// horns; bat wings with curved bones and soft scalloped membrane that
/// beat with a strong downstroke, their tips trailing. Two poses: flying
/// (the Dojo world's dragon) and wound round a picture, facing you, wings
/// spread (the Dragon Coil aura).

class DragonColors {
  const DragonColors({
    required this.top,
    required this.body,
    required this.shadow,
    required this.belly,
    required this.membrane,
    required this.membraneDeep,
    required this.gold,
    required this.eye,
    this.glow,
  });

  /// The body's three tones: lit top, middle, shadowed underside.
  final Color top;
  final Color body;
  final Color shadow;

  /// The warm plated belly and throat.
  final Color belly;

  /// Wing membrane, from near the bones out to the tips.
  final Color membrane;
  final Color membraneDeep;

  /// Horns, claws, spikes and the tail's spade.
  final Color gold;
  final Color eye;

  /// A haze of heat and sparkles round it.
  final Color? glow;

  /// Ruby red with a warm belly, ivory-gold horns, amber eyes.
  static const crimson = DragonColors(
    top: Color(0xFFFF6A5A),
    body: Color(0xFFD6283A),
    shadow: Color(0xFF6E0C2C),
    belly: Color(0xFFFFB45A),
    membrane: Color(0xFFE0304A),
    membraneDeep: Color(0xFF5A1063),
    gold: Color(0xFFFFE3A0),
    eye: Color(0xFFFFC23A),
  );

  /// Blazing: the set complete, or the Mythic aura.
  static const blazing = DragonColors(
    top: Color(0xFFFF8A5A),
    body: Color(0xFFE8303A),
    shadow: Color(0xFF7A0E2A),
    belly: Color(0xFFFFC85A),
    membrane: Color(0xFFFF4A4A),
    membraneDeep: Color(0xFF6A1070),
    gold: Color(0xFFFFE9B0),
    eye: Color(0xFFFFE27A),
    glow: Color(0xFFFF5A2A),
  );
}

// ── drawing helpers ──────────────────────────────────────────────────────

const _ink = Color(0xFF2A0614);

/// Catmull-Rom through [p] (closed when [closed]): smooth organic shapes
/// from a few control points.
List<Offset> _smooth(List<Offset> p, {bool closed = false, int steps = 8}) {
  if (p.length < 3) return p;
  final n = p.length;
  final out = <Offset>[];
  final spans = closed ? n : n - 1;
  Offset at(int i) => closed ? p[(i % n + n) % n] : p[i.clamp(0, n - 1)];
  for (var i = 0; i < spans; i++) {
    final p0 = at(i - 1), p1 = at(i), p2 = at(i + 1), p3 = at(i + 2);
    for (var k = 0; k < steps; k++) {
      final t = k / steps;
      final t2 = t * t, t3 = t2 * t;
      out.add(
        (p1 * 2 +
                (p2 - p0) * t +
                (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 +
                (p1 * 3 - p0 - p2 * 3 + p3) * t3) *
            0.5,
      );
    }
  }
  if (!closed) out.add(p.last);
  return out;
}

Path _blob(List<Offset> pts) =>
    Path()..addPolygon(_smooth(pts, closed: true), true);

/// A smooth tube along [pts] tapering through [widths] (half-widths).
/// Returns the outline and the centre line with its normals.
(Path, List<Offset>, List<Offset>, List<double>) _tube(
  List<Offset> pts,
  List<double> widths,
) {
  final c = _smooth(pts);
  final w = [
    for (var i = 0; i < c.length; i++)
      () {
        final x = i / (c.length - 1) * (widths.length - 1);
        final a = x.floor().clamp(0, widths.length - 1);
        final b = math.min(a + 1, widths.length - 1);
        return widths[a] + (widths[b] - widths[a]) * (x - a);
      }(),
  ];
  final n = <Offset>[];
  for (var i = 0; i < c.length; i++) {
    final d = c[math.min(c.length - 1, i + 1)] - c[math.max(0, i - 1)];
    final l = d.distance;
    n.add(l == 0 ? const Offset(0, -1) : Offset(d.dy / l, -d.dx / l));
  }
  final left = [for (var i = 0; i < c.length; i++) c[i] + n[i] * w[i]];
  final right = [for (var i = 0; i < c.length; i++) c[i] - n[i] * w[i]];
  return (Path()..addPolygon([...left, ...right.reversed], true), c, n, w);
}

/// Fills [path] with the body's rounded shading (lit from above), adds a
/// soft highlight band and a clean outline: the glossy Utopia look.
void _shade(
  Canvas canvas,
  Path path,
  DragonColors col, {
  Color? top,
  Color? mid,
  Color? bottom,
  double outline = 0.02,
  bool lite = false,
}) {
  final box = path.getBounds();
  canvas.drawPath(
    path,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top ?? col.top, mid ?? col.body, bottom ?? col.shadow],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(box),
  );
  if (!lite) {
    // A soft sheen across the upper part.
    canvas.save();
    canvas.clipPath(path);
    canvas.drawOval(
      Rect.fromLTWH(
        box.left + box.width * 0.12,
        box.top + box.height * 0.08,
        box.width * 0.6,
        box.height * 0.28,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          box.shortestSide * 0.08,
        ),
    );
    canvas.restore();
  }
  if (outline > 0) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = outline
        ..strokeJoin = StrokeJoin.round
        ..color = _ink.withValues(alpha: 0.85),
    );
  }
}

/// Gold horns, claws and spikes: ivory at the base to gold at the tip,
/// with a bright edge.
void _gold(
  Canvas canvas,
  Path path,
  DragonColors col, {
  double outline = 0.018,
}) {
  final box = path.getBounds();
  canvas.drawPath(
    path,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [
          Color.lerp(col.gold, Colors.white, 0.4)!,
          col.gold,
          const Color(0xFFD9962E),
        ],
      ).createShader(box),
  );
  if (outline > 0) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = outline
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF6B3A08),
    );
  }
}

/// A curved horn from [base] sweeping through [mid] to a point at [tip].
Path _horn(Offset base, Offset mid, Offset tip, double width) {
  final (path, _, _, _) = _tube([base, mid, tip], [width, width * 0.6, 0.004]);
  return path;
}

/// Little sparkles glinting round it (the Utopia touch).
void _sparkles(
  Canvas canvas,
  Offset c,
  double spread,
  double t,
  Color color,
  int count,
) {
  for (var i = 0; i < count; i++) {
    final life = (t * (0.4 + (i % 4) * 0.1) + i / count) % 1.0;
    final a = i * 2.39996 + t * 0.2;
    final p =
        c +
        Offset(math.cos(a), math.sin(a)) *
            spread *
            (0.6 + 0.5 * ((i * 37) % 10) / 10) +
        Offset(0, -life * spread * 0.4);
    final s = spread * 0.05 * math.sin(life * math.pi);
    if (s <= 0) continue;
    final paint = Paint()
      ..color = color.withValues(alpha: math.sin(life * math.pi));
    canvas.drawPath(
      Path()
        ..moveTo(p.dx, p.dy - s)
        ..quadraticBezierTo(p.dx, p.dy, p.dx + s, p.dy)
        ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + s)
        ..quadraticBezierTo(p.dx, p.dy, p.dx - s, p.dy)
        ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - s),
      paint,
    );
  }
}

/// A gout of fire from [mouth] along [dir]: hot white core, gold, orange,
/// red edges, with sparks thrown ahead. [k] runs 0..1 through the breath.
void _fire(
  Canvas canvas,
  Offset mouth,
  Offset dir,
  double len,
  double t,
  double k,
) {
  final d = dir / dir.distance;
  final n = Offset(-d.dy, d.dx);
  final grow = Curves.easeOut.transform((k * 2.5).clamp(0.0, 1.0));
  final fade = k < 0.7 ? 1.0 : (1 - (k - 0.7) / 0.3);
  if (fade <= 0) return;
  Path plume(double l, double w, double phase) {
    final wob = math.sin(t * 14 + phase) * w * 0.3;
    final end = mouth + d * l + n * wob;
    return Path()
      ..moveTo(mouth.dx, mouth.dy)
      ..quadraticBezierTo(
        (mouth + d * (l * 0.5) + n * (w + wob)).dx,
        (mouth + d * (l * 0.5) + n * (w + wob)).dy,
        end.dx,
        end.dy,
      )
      ..quadraticBezierTo(
        (mouth + d * (l * 0.5) - n * (w - wob)).dx,
        (mouth + d * (l * 0.5) - n * (w - wob)).dy,
        mouth.dx,
        mouth.dy,
      )
      ..close();
  }

  final l = len * grow;
  for (final (scale, width, color) in [
    (1.0, 0.32, const Color(0xFFE23A1E)),
    (0.82, 0.22, const Color(0xFFFF8A1F)),
    (0.6, 0.13, const Color(0xFFFFD25A)),
    (0.35, 0.06, const Color(0xFFFFF6D6)),
  ]) {
    canvas.drawPath(
      plume(l * scale, len * width, scale * 3),
      Paint()
        ..color = color.withValues(alpha: fade * (scale == 1.0 ? 0.85 : 1)),
    );
  }
  for (var i = 0; i < 8; i++) {
    final s = (t * 2 + i / 8) % 1.0;
    final p =
        mouth +
        d * (l * (0.4 + 0.8 * s)) +
        n * (math.sin(i * 2.1 + t * 6) * len * 0.18);
    canvas.drawCircle(
      p,
      len * 0.025 * (1 - s),
      Paint()
        ..color = const Color(0xFFFFE27A).withValues(alpha: fade * (1 - s)),
    );
  }
}

/// A bat wing from [shoulder]: a curved arm out to the wrist, long fingers
/// bowing a little as they fan from it, and the membrane slung between
/// them in soft scallops back to [root] on the body. Light comes through
/// the membrane near the bones; it deepens toward the edge.
void _wing(
  Canvas canvas,
  Offset shoulder,
  Offset elbow,
  Offset wrist,
  List<Offset> fingers,
  Offset root,
  double bone,
  DragonColors col, {
  bool far = false,
  double under = 0,
  bool lite = false,
}) {
  // Each finger bows toward the trailing edge (the side the root is on).
  Offset bowOf(Offset tip) {
    final d = tip - wrist;
    var p = Offset(-d.dy, d.dx) / (d.distance + 1e-6);
    final toRoot = root - wrist;
    if (p.dx * toRoot.dx + p.dy * toRoot.dy < 0) p = -p;
    return Offset.lerp(wrist, tip, 0.5)! + p * (d.distance * 0.07);
  }

  // The leading edge runs smoothly along the arm to the first finger.
  final lead = _smooth([shoulder, elbow, wrist, fingers.first], steps: 10);
  final membrane = Path()..moveTo(lead.first.dx, lead.first.dy);
  for (final p in lead.skip(1)) {
    membrane.lineTo(p.dx, p.dy);
  }
  final tips = [...fingers, root];
  final edge = Path()..moveTo(fingers.first.dx, fingers.first.dy);
  for (var k = 1; k < tips.length; k++) {
    final a = tips[k - 1];
    final b = tips[k];
    final mid = Offset.lerp(a, b, 0.5)!;
    // The outer edge bows outward; the rest scallops in between fingers.
    final sag = mid + (wrist - mid) * (k == 1 ? -0.07 : 0.32);
    membrane.quadraticBezierTo(sag.dx, sag.dy, b.dx, b.dy);
    edge.quadraticBezierTo(sag.dx, sag.dy, b.dx, b.dy);
  }
  membrane.close();

  final box = membrane.getBounds();
  final dim = far ? 0.38 : 0.3 * under;
  Color tone(Color c) => Color.lerp(c, Colors.black, dim)!;
  canvas.drawPath(
    membrane,
    Paint()
      ..shader = RadialGradient(
        center: Alignment(
          ((wrist.dx - box.center.dx) / (box.width / 2 + 1e-6)).clamp(
            -1.0,
            1.0,
          ),
          ((wrist.dy - box.center.dy) / (box.height / 2 + 1e-6)).clamp(
            -1.0,
            1.0,
          ),
        ),
        radius: 1.5,
        colors: [
          tone(Color.lerp(col.membrane, col.belly, 0.35)!),
          tone(col.membrane),
          tone(Color.lerp(col.membrane, col.membraneDeep, 0.6)!),
          tone(col.membraneDeep),
        ],
        stops: const [0, 0.3, 0.7, 1],
      ).createShader(box),
  );
  if (!lite) {
    // Light glowing through the thin trailing edge.
    canvas.save();
    canvas.clipPath(membrane);
    canvas.drawPath(
      edge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = bone * 1.4
        ..color = Color.lerp(
          col.membrane,
          col.belly,
          0.5,
        )!.withValues(alpha: far ? 0.2 : 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, bone * 0.7),
    );
    canvas.restore();
  }
  canvas.drawPath(
    membrane,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = bone * 0.3
      ..strokeJoin = StrokeJoin.round
      ..color = _ink.withValues(alpha: 0.75),
  );

  // Bones: the fingers under the arm, each a slim curve.
  for (final f in fingers.skip(1)) {
    final (finger, _, _, _) = _tube(
      [wrist, bowOf(f), f],
      [bone * 0.42, bone * 0.26, bone * 0.05],
    );
    _shade(
      canvas,
      finger,
      col,
      top: tone(col.top),
      mid: tone(col.body),
      bottom: tone(col.shadow),
      outline: bone * 0.22,
      lite: true,
    );
  }
  final (arm, _, _, _) = _tube(
    [shoulder, elbow, wrist],
    [bone * 0.8, bone * 0.6, bone * 0.45],
  );
  _shade(
    canvas,
    arm,
    col,
    top: tone(col.top),
    mid: tone(col.body),
    bottom: tone(col.shadow),
    outline: bone * 0.3,
    lite: true,
  );
  // A gold claw at the wrist.
  final up = fingers.first - wrist;
  _gold(
    canvas,
    _horn(
      wrist,
      Offset.lerp(wrist, fingers.first, 0.6)!,
      fingers.first + up * 0.2,
      bone * 0.5,
    ),
    col,
    outline: bone * 0.18,
  );
}

/// A smooth ear flap from [base] pointing along [angle]: a long leaf of
/// skin with a ridge down the middle, its tip curling to the side [bend]
/// points (1 or -1). They frame the head the way a cat's ears do.
void _earFlap(
  Canvas canvas,
  Offset base,
  double angle,
  double len,
  DragonColors col, {
  double bend = 1,
  bool far = false,
  bool lite = false,
}) {
  final d = Offset(math.cos(angle), math.sin(angle));
  final n = Offset(-d.dy, d.dx) * bend;
  final w = len * 0.36;
  final tip = base + d * len + n * (len * 0.16);
  final a1 = base + d * (len * 0.3) + n * w;
  final a2 = base + d * (len * 0.78) + n * (w * 0.75);
  final b1 = base + d * (len * 0.72) - n * (w * 0.2);
  final b2 = base + d * (len * 0.3) - n * (w * 0.55);
  final leaf = Path()
    ..moveTo(base.dx, base.dy)
    ..cubicTo(a1.dx, a1.dy, a2.dx, a2.dy, tip.dx, tip.dy)
    ..cubicTo(b1.dx, b1.dy, b2.dx, b2.dy, base.dx, base.dy)
    ..close();
  final dim = far ? 0.38 : 0.0;
  _shade(
    canvas,
    leaf,
    col,
    top: Color.lerp(col.top, Colors.black, dim),
    mid: Color.lerp(col.body, Colors.black, dim),
    bottom: Color.lerp(col.shadow, Colors.black, dim),
    outline: len * 0.035,
    lite: lite,
  );
  final rib = base + d * (len * 0.5) + n * (w * 0.3);
  canvas.drawPath(
    Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(rib.dx, rib.dy, tip.dx, tip.dy),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = len * 0.035
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(
        col.shadow,
        Colors.black,
        dim,
      )!.withValues(alpha: 0.75),
  );
}

/// Three gold claws at [foot], curling the way [dir] points.
void _claws(
  Canvas canvas,
  Offset foot,
  Offset dir,
  double size,
  DragonColors col,
) {
  final d = dir / dir.distance;
  for (var k = 0; k < 3; k++) {
    final a = (k - 1) * 0.5;
    final v = Offset(
      d.dx * math.cos(a) - d.dy * math.sin(a),
      d.dx * math.sin(a) + d.dy * math.cos(a),
    );
    final tip = foot + v * size + Offset(-v.dy, v.dx) * size * 0.3;
    _gold(
      canvas,
      _horn(foot, foot + v * size * 0.6, tip, size * 0.22),
      col,
      outline: size * 0.08,
    );
  }
}

/// The tail: long, swaying, spined in gold, ending in a gold spade.
void _tail(
  Canvas canvas,
  List<Offset> spine,
  List<double> widths,
  DragonColors col, {
  bool lite = false,
}) {
  final (path, c, n, w) = _tube(spine, widths);
  // Gold spikes along the top, shrinking toward the tip.
  for (var i = 4; i < c.length - 6; i += 5) {
    final d = c[i + 1] - c[i - 1];
    final along = d / (d.distance + 1e-6);
    final base = c[i] + n[i] * (w[i] * 0.8);
    final tip = base + n[i] * (w[i] * 1.3) - along * (w[i] * 0.9);
    _gold(
      canvas,
      Path()
        ..moveTo(
          (base + along * w[i] * 0.55).dx,
          (base + along * w[i] * 0.55).dy,
        )
        ..quadraticBezierTo(
          (base + n[i] * w[i] * 0.9).dx,
          (base + n[i] * w[i] * 0.9).dy,
          tip.dx,
          tip.dy,
        )
        ..lineTo(
          (base - along * w[i] * 0.55).dx,
          (base - along * w[i] * 0.55).dy,
        )
        ..close(),
      col,
      outline: w[i] * 0.12,
    );
  }
  _shade(canvas, path, col, lite: lite, outline: widths.first * 0.12);
  // The belly side of the tail, warm.
  final belly = Path();
  for (var i = 0; i < c.length; i++) {
    final p = c[i] - n[i] * (w[i] * 0.45);
    i == 0 ? belly.moveTo(p.dx, p.dy) : belly.lineTo(p.dx, p.dy);
  }
  canvas.drawPath(
    belly,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = widths.first * 0.35
      ..strokeCap = StrokeCap.round
      ..color = col.belly.withValues(alpha: 0.55),
  );
  // The spade.
  final tip = c.last;
  final d = c.last - c[c.length - 4];
  final td = d / (d.distance + 1e-6);
  final tn = Offset(-td.dy, td.dx);
  final s = widths.first * 1.4;
  final spade = Path()
    ..moveTo(tip.dx, tip.dy)
    ..quadraticBezierTo(
      (tip + tn * s * 0.9 + td * s * 0.2).dx,
      (tip + tn * s * 0.9 + td * s * 0.2).dy,
      (tip + td * s * 1.2).dx,
      (tip + td * s * 1.2).dy,
    )
    ..quadraticBezierTo(
      (tip - tn * s * 0.9 + td * s * 0.2).dx,
      (tip - tn * s * 0.9 + td * s * 0.2).dy,
      tip.dx,
      tip.dy,
    )
    ..close();
  if (col.glow != null && !lite) {
    canvas.drawPath(
      spade,
      Paint()
        ..color = col.glow!.withValues(alpha: 0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.5),
    );
  }
  _gold(canvas, spade, col, outline: widths.first * 0.12);
}

/// A dragon's eye: an almond of glowing iris (no white, like a real
/// reptile's) with a slit pupil, a shadow from the lid along the top and a
/// bright catchlight. [blink] closes it.
void _dragonEye(
  Canvas canvas,
  Offset c,
  double w,
  double h,
  DragonColors col, {
  Offset look = Offset.zero,
  double blink = 0,
  double tilt = 0,
  bool lite = false,
}) {
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(tilt);
  final open = (1 - blink).clamp(0.0, 1.0);
  final hw = w / 2;
  final up = h * 0.62 * open;
  final down = h * 0.42 * open;
  if (open < 0.12) {
    // Shut: just the lid's line.
    canvas.drawPath(
      Path()
        ..moveTo(-hw, 0)
        ..quadraticBezierTo(0, h * 0.18, hw, 0),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.14
        ..strokeCap = StrokeCap.round
        ..color = _ink,
    );
    canvas.restore();
    return;
  }
  final almond = Path()
    ..moveTo(-hw, 0)
    ..cubicTo(-hw * 0.45, -up * 1.3, hw * 0.45, -up * 1.3, hw, 0)
    ..cubicTo(hw * 0.45, down * 1.3, -hw * 0.45, down * 1.3, -hw, 0)
    ..close();
  final iris = Offset(look.dx * w * 0.14, look.dy * h * 0.1);
  canvas.save();
  canvas.clipPath(almond);
  canvas.drawRect(
    Rect.fromCenter(center: Offset.zero, width: w * 1.2, height: h * 1.4),
    Paint()
      ..shader = RadialGradient(
        colors: [
          Color.lerp(col.eye, Colors.white, 0.6)!,
          col.eye,
          Color.lerp(col.eye, const Color(0xFFB8360F), 0.7)!,
        ],
        stops: const [0, 0.45, 1],
      ).createShader(Rect.fromCircle(center: iris, radius: w * 0.62)),
  );
  // The slit pupil.
  canvas.drawOval(
    Rect.fromCenter(center: iris, width: h * 0.2, height: h * 1.1),
    Paint()..color = const Color(0xFF14020A),
  );
  // The lid's shadow along the top.
  canvas.drawRect(
    Rect.fromLTRB(-hw, -up * 1.1, hw, -up * 0.25),
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          col.shadow.withValues(alpha: 0.85),
          col.shadow.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTRB(-hw, -up * 1.1, hw, -up * 0.25)),
  );
  canvas.drawCircle(
    iris + Offset(-w * 0.12, -up * 0.3),
    h * 0.13,
    Paint()..color = Colors.white.withValues(alpha: 0.95),
  );
  if (!lite) {
    canvas.drawCircle(
      iris + Offset(w * 0.13, down * 0.35),
      h * 0.06,
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
  }
  canvas.restore();
  canvas.drawPath(
    almond,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.12
      ..strokeJoin = StrokeJoin.round
      ..color = _ink,
  );
  canvas.restore();
}

double _blink(double t) {
  final k = t % 4.6;
  return k < 0.14 ? math.sin(k / 0.14 * math.pi) : 0;
}

/// 0 most of the time; a 1.4 s breath of fire every 5 seconds.
double _breath(double t) {
  final k = (t % 5.0) / 1.4;
  return k < 1 ? k : 0;
}

// ── flying ───────────────────────────────────────────────────────────────

/// The dragon in flight, facing +x, about [s] across the body (it's about
/// four times that nose to tail). One smooth line runs from the hips up
/// the long neck to the head; the wings beat with a strong downstroke,
/// their tips trailing the arm, the body riding up as they push. The tail
/// sways, it glances about and roars now and then; with [fire] it
/// breathes fire.
void paintDragonFlying(
  Canvas canvas,
  Offset at,
  double s,
  double t,
  DragonColors col, {
  bool facingLeft = false,
  double tilt = 0,
  bool fire = false,
  bool lite = false,
}) {
  canvas.save();
  canvas.translate(at.dx, at.dy);
  canvas.rotate(tilt);
  canvas.scale(facingLeft ? -s : s, s);

  // The wingbeat: [beat] is 1 with the wings raised, -1 at the bottom of a
  // quick downstroke; the recovery is slower. The hands trail the arms.
  final cycle = (t * 0.6) % 1.0;
  final eased = cycle < 0.4
      ? cycle / 0.4 * 0.5
      : 0.5 + (cycle - 0.4) / 0.6 * 0.5;
  final beat = math.cos(eased * 2 * math.pi);
  final trail = math.cos(eased * 2 * math.pi - 0.9);
  canvas.translate(0, beat * 0.03);

  if (col.glow != null && !lite) {
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(-0.2, -0.1),
        width: 3.6,
        height: 1.8,
      ),
      Paint()
        ..color = col.glow!.withValues(alpha: 0.22 + 0.06 * math.sin(t * 3))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.45),
    );
  }

  // The wing's shape when raised, shoulder at the origin: the arm arches
  // up to a high wrist and the fingers fan back from it.
  const elbowUp = Offset(0.06, -0.58);
  const wristUp = Offset(-0.36, -1.18);
  const thumbUp = Offset(-0.24, -1.34);
  const tipsUp = [
    Offset(-1.7, -1.42),
    Offset(-1.68, -0.66),
    Offset(-1.12, -0.1),
  ];
  // Seen from the side, a wingbeat swings the wing toward us and away: it
  // narrows to a sliver as it passes level and shows its underside,
  // shorter, below. The hand follows the arm a moment later.
  double lift(double b) => b >= 0 ? b : b * 0.7;
  final ya = lift(beat);
  final yh = lift(trail);
  (Offset, Offset, List<Offset>) wingAt(Offset sh, double size) {
    Offset p(Offset q, double y) => sh + Offset(q.dx, q.dy * y) * size;
    final yw = (ya + yh) / 2;
    return (
      p(elbowUp, ya),
      p(wristUp, yw),
      [p(thumbUp, yw), for (final q in tipsUp) p(q, yh)],
    );
  }

  // The far wing, darker, behind; a little forward and higher, so with
  // both raised it shows above the near one.
  const farShoulder = Offset(0.3, -0.24);
  final far = wingAt(farShoulder, 0.92);
  _wing(
    canvas,
    farShoulder,
    far.$1,
    far.$2,
    far.$3,
    const Offset(-0.42, -0.06),
    0.075,
    col,
    far: true,
    lite: lite,
  );

  // The tail, swaying behind.
  final sway = t * 2.2;
  _tail(
    canvas,
    [
      const Offset(-0.45, 0.04),
      for (var k = 1; k <= 6; k++)
        Offset(-0.45 - k * 0.32, 0.04 + math.sin(sway - k * 0.8) * 0.06 * k),
    ],
    const [0.17, 0.13, 0.1, 0.075, 0.055, 0.04, 0.025],
    col,
    lite: lite,
  );

  // The far legs, tucked, in shadow.
  final legTone = Color.lerp(col.body, col.shadow, 0.5)!;
  for (final (pts, widths) in [
    (
      const [Offset(-0.28, 0.06), Offset(-0.2, 0.24), Offset(-0.34, 0.32)],
      const [0.1, 0.07, 0.045],
    ),
    (
      const [Offset(0.26, 0.1), Offset(0.34, 0.24), Offset(0.24, 0.3)],
      const [0.07, 0.05, 0.035],
    ),
  ]) {
    final (leg, _, _, _) = _tube(pts, widths);
    _shade(
      canvas,
      leg,
      col,
      top: legTone,
      mid: legTone,
      bottom: col.shadow,
      outline: 0.016,
      lite: true,
    );
  }

  // The body and neck: one sleek curve, deep in the chest, slim at the
  // waist, rippling a little as it flies.
  final ripple = math.sin(t * 2.2);
  final (body, bc, bn, bw) = _tube(
    [
      const Offset(-0.52, 0.04),
      Offset(-0.2, 0.05 + ripple * 0.012),
      const Offset(0.14, 0.01),
      Offset(0.44, -0.11 - ripple * 0.008),
      const Offset(0.64, -0.29),
      const Offset(0.8, -0.44),
    ],
    const [0.16, 0.19, 0.23, 0.165, 0.125, 0.115],
  );
  // Small gold ridge spikes down the back, from the head to the hips.
  for (var i = bc.length - 5; i > 6; i -= 6) {
    final d = bc[i + 1] - bc[i - 1];
    final along = d / (d.distance + 1e-6);
    final base = bc[i] + bn[i] * (bw[i] * 0.86);
    final h = bw[i] * 0.7;
    final tip = base + bn[i] * h - along * (h * 0.9);
    _gold(
      canvas,
      Path()
        ..moveTo((base + along * h * 0.5).dx, (base + along * h * 0.5).dy)
        ..quadraticBezierTo(
          (base + bn[i] * h * 0.8).dx,
          (base + bn[i] * h * 0.8).dy,
          tip.dx,
          tip.dy,
        )
        ..lineTo((base - along * h * 0.5).dx, (base - along * h * 0.5).dy)
        ..close(),
      col,
      outline: 0.01,
    );
  }
  _shade(canvas, body, col, lite: lite);
  // The warm underside: chest, belly and throat, soft-edged, no plates.
  canvas.save();
  canvas.clipPath(body);
  final under = Path()
    ..addPolygon([
      for (var i = 0; i < bc.length; i++) bc[i] - bn[i] * (bw[i] * 0.2),
      for (var i = bc.length - 1; i >= 0; i--) bc[i] - bn[i] * (bw[i] * 1.2),
    ], true);
  canvas.drawPath(
    under,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(col.belly, Colors.white, 0.15)!,
          col.belly,
          Color.lerp(col.belly, col.shadow, 0.45)!,
        ],
      ).createShader(under.getBounds())
      ..maskFilter = lite
          ? null
          : const MaskFilter.blur(BlurStyle.normal, 0.025),
  );
  if (!lite) {
    // Light along the top of the back.
    final rim = Path();
    for (var i = 0; i < bc.length; i++) {
      final p = bc[i] + bn[i] * (bw[i] * 0.72);
      i == 0 ? rim.moveTo(p.dx, p.dy) : rim.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.05
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.025),
    );
  }
  canvas.restore();
  canvas.drawPath(
    body,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.02
      ..strokeJoin = StrokeJoin.round
      ..color = _ink.withValues(alpha: 0.85),
  );

  // The near legs, tucked up in flight, gold claws trailing.
  final (thigh, _, _, _) = _tube(
    const [Offset(-0.34, 0.03), Offset(-0.18, 0.25), Offset(-0.4, 0.35)],
    const [0.15, 0.09, 0.05],
  );
  _shade(canvas, thigh, col, lite: lite, outline: 0.018);
  _claws(canvas, const Offset(-0.41, 0.35), const Offset(-1, 0.25), 0.11, col);
  final (fore, _, _, _) = _tube(
    const [Offset(0.2, 0.1), Offset(0.32, 0.26), Offset(0.19, 0.33)],
    const [0.085, 0.06, 0.04],
  );
  _shade(canvas, fore, col, lite: lite, outline: 0.016);
  _claws(canvas, const Offset(0.18, 0.34), const Offset(-0.6, 0.6), 0.09, col);

  // The head, held steady while the body bobs.
  final breath = fire ? _breath(t) : 0.0;
  final roar = math.max(0.0, math.sin(t * 0.9 - 1));
  canvas.save();
  canvas.translate(0.8, -0.45 - beat * 0.015);
  canvas.rotate(0.16 + 0.05 * math.sin(t * 1.3) - (breath > 0 ? 0.15 : 0));
  canvas.scale(1.35, 1.35);
  _headSide(
    canvas,
    t,
    col,
    open: breath > 0 ? 0.5 : 0.06 + 0.3 * roar,
    breath: breath,
    lite: lite,
  );
  canvas.restore();

  // The near wing, over the body (its underside, darker, on the way down).
  const nearShoulder = Offset(0.16, -0.13);
  final near = wingAt(nearShoulder, 1.0);
  _wing(
    canvas,
    nearShoulder,
    near.$1,
    near.$2,
    near.$3,
    const Offset(-0.46, 0.0),
    0.085,
    col,
    under: ya < 0 ? -ya : 0,
    lite: lite,
  );

  if (col.glow != null && !lite) {
    _sparkles(canvas, const Offset(-0.3, 0), 1.4, t, col.gold, 10);
  }
  canvas.restore();
}

/// The head in profile, facing +x from the top of the neck (the origin):
/// a broad, smooth skull running down to a rounded snout, a big glowing
/// eye with a slit pupil under a strong brow, ear flaps swept back with
/// gold horns over them, and a mouth that curls up at the corner. Jaws
/// open [open] radians when it roars; [breath] 0..1 is a gout of fire.
void _headSide(
  Canvas canvas,
  double t,
  DragonColors col, {
  required double open,
  double breath = 0,
  bool lite = false,
}) {
  const hinge = Offset(0.02, 0.06);
  Offset jaw(Offset p) {
    final d = p - hinge;
    return hinge +
        Offset(
          d.dx * math.cos(open) - d.dy * math.sin(open),
          d.dx * math.sin(open) + d.dy * math.cos(open),
        );
  }

  final flick = math.sin(t * 1.7) * 0.06;

  // The far ear flap and horn, behind.
  _earFlap(
    canvas,
    const Offset(-0.04, -0.17),
    math.pi + 0.32 + flick,
    0.36,
    col,
    far: true,
    lite: lite,
  );
  _gold(
    canvas,
    _horn(
      const Offset(0.12, -0.21),
      const Offset(-0.04, -0.36),
      const Offset(-0.24, -0.42),
      0.04,
    ),
    col,
  );

  // Inside the mouth when it's open: dark, a tongue, rows of teeth.
  if (open > 0.12) {
    final inside = Path()
      ..moveTo(0.06, 0.06)
      ..lineTo(0.49, 0.04)
      ..lineTo(
        jaw(const Offset(0.46, 0.07)).dx,
        jaw(const Offset(0.46, 0.07)).dy,
      )
      ..lineTo(
        jaw(const Offset(0.06, 0.09)).dx,
        jaw(const Offset(0.06, 0.09)).dy,
      )
      ..close();
    canvas.drawPath(inside, Paint()..color = const Color(0xFF4A0816));
    canvas.drawPath(
      _blob([
        jaw(const Offset(0.12, 0.09)),
        jaw(const Offset(0.3, 0.08)),
        jaw(const Offset(0.39, 0.06)),
        jaw(const Offset(0.28, 0.11)),
      ]),
      Paint()..color = const Color(0xFFE85A78),
    );
    final tooth = Paint()..color = const Color(0xFFFFF8EC);
    for (var k = 0; k < 4; k++) {
      final x = 0.18 + k * 0.07;
      canvas.drawPath(
        Path()..addPolygon([
          Offset(x, 0.05),
          Offset(x + 0.016, 0.09),
          Offset(x + 0.032, 0.05),
        ], true),
        tooth,
      );
      canvas.drawPath(
        Path()..addPolygon([
          jaw(Offset(x, 0.075)),
          jaw(Offset(x + 0.016, 0.04)),
          jaw(Offset(x + 0.032, 0.075)),
        ], true),
        tooth,
      );
    }
  }

  // The lower jaw, warm underneath.
  final lower = _blob([
    jaw(const Offset(-0.1, 0.06)),
    jaw(const Offset(0.2, 0.065)),
    jaw(const Offset(0.44, 0.055)),
    jaw(const Offset(0.47, 0.09)),
    jaw(const Offset(0.32, 0.13)),
    jaw(const Offset(0.1, 0.155)),
    jaw(const Offset(-0.08, 0.13)),
  ]);
  _shade(
    canvas,
    lower,
    col,
    top: col.body,
    mid: col.belly,
    bottom: Color.lerp(col.belly, col.shadow, 0.5)!,
    lite: lite,
    outline: 0.016,
  );
  // Little gold spikes along the back of the jaw.
  for (final (base, mid, tip, w) in [
    (
      const Offset(-0.07, 0.07),
      const Offset(-0.16, 0.1),
      const Offset(-0.25, 0.15),
      0.026,
    ),
    (
      const Offset(-0.03, 0.12),
      const Offset(-0.1, 0.17),
      const Offset(-0.17, 0.23),
      0.02,
    ),
  ]) {
    _gold(canvas, _horn(base, mid, tip, w), col, outline: 0.008);
  }

  // Skull and snout: broad and smooth, one sweep from crown to nose.
  final skull = _blob(const [
    Offset(-0.15, 0.0),
    Offset(-0.15, -0.13),
    Offset(-0.05, -0.23),
    Offset(0.1, -0.27),
    Offset(0.25, -0.24),
    Offset(0.37, -0.17),
    Offset(0.47, -0.1),
    Offset(0.52, -0.03),
    Offset(0.5, 0.04),
    Offset(0.36, 0.065),
    Offset(0.18, 0.07),
    Offset(0.0, 0.09),
  ]);
  _shade(canvas, skull, col, lite: lite, outline: 0.018);
  if (!lite) {
    // Light along the bridge of the nose.
    canvas.save();
    canvas.clipPath(skull);
    canvas.drawPath(
      Path()
        ..moveTo(0.04, -0.25)
        ..quadraticBezierTo(0.32, -0.21, 0.49, -0.07),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.05
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.02),
    );
    canvas.restore();
  }

  // The mouth, shut: a long line curling up at the corner, one fang.
  if (open <= 0.12) {
    canvas.drawPath(
      Path()
        ..moveTo(0.495, 0.035)
        ..quadraticBezierTo(0.32, 0.075, 0.13, 0.065)
        ..quadraticBezierTo(0.06, 0.06, 0.05, 0.02),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.014
        ..strokeCap = StrokeCap.round
        ..color = _ink,
    );
    canvas.drawPath(
      Path()..addPolygon(const [
        Offset(0.38, 0.06),
        Offset(0.392, 0.1),
        Offset(0.408, 0.058),
      ], true),
      Paint()..color = const Color(0xFFFFF8EC),
    );
  }

  // The nostril, a curved slit.
  canvas.drawPath(
    Path()
      ..moveTo(0.43, -0.065)
      ..quadraticBezierTo(0.465, -0.085, 0.488, -0.055),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.014
      ..strokeCap = StrokeCap.round
      ..color = _ink,
  );

  // The eye under a strong brow.
  _dragonEye(
    canvas,
    const Offset(0.17, -0.1),
    0.19,
    0.125,
    col,
    look: const Offset(0.6, 0.0),
    blink: _blink(t),
    tilt: 0.1,
    lite: lite,
  );
  canvas.drawPath(
    Path()
      ..moveTo(0.04, -0.18)
      ..quadraticBezierTo(0.17, -0.23, 0.31, -0.165),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.032
      ..strokeCap = StrokeCap.round
      ..color = col.shadow,
  );

  // The near ear flaps, a long one and a short one, and the horns.
  _earFlap(
    canvas,
    const Offset(-0.1, -0.07),
    math.pi - 0.08 + flick * 0.6,
    0.28,
    col,
    lite: lite,
  );
  _earFlap(
    canvas,
    const Offset(-0.08, -0.16),
    math.pi + 0.22 + flick,
    0.46,
    col,
    lite: lite,
  );
  _gold(
    canvas,
    _horn(
      const Offset(0.08, -0.23),
      const Offset(-0.1, -0.37),
      const Offset(-0.32, -0.42),
      0.05,
    ),
    col,
  );

  if (breath > 0) {
    _fire(
      canvas,
      jaw(const Offset(0.5, 0.05)),
      Offset(math.cos(open * 0.5), math.sin(open * 0.5)),
      1.4,
      t,
      breath,
    );
  }
}

// ── coiled ───────────────────────────────────────────────────────────────

/// The Dragon Coil aura: the dragon wound round a picture of radius [r] at
/// [c]. Its body circles the frame with gold spikes along its back, the
/// tail ending in a gold spade; its head rises at the top facing you, both
/// big eyes on you, wings spread behind it. Every few seconds it roars and
/// breathes fire. All of it sits behind the picture, so the picture is
/// never covered: with [front] it draws nothing.
void paintDragonCoiled(
  Canvas canvas,
  Offset c,
  double r,
  double t,
  DragonColors col, {
  required bool front,
  bool lite = false,
}) {
  if (front) return;
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.scale(r, r);

  final flapK = (t % 6.0) / 1.0;
  final flap = flapK < 1 ? math.sin(flapK * math.pi) : 0.0;
  final breath = _breath(t + 2);
  final roar = breath > 0 ? 1.0 : math.max(0.0, math.sin(t * 0.8 - 2)) * 0.6;
  final breathe = math.sin(t * 1.6) * 0.01;

  if (col.glow != null && !lite) {
    canvas.drawCircle(
      Offset.zero,
      1.25,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.35
        ..color = col.glow!.withValues(alpha: 0.3 + 0.08 * math.sin(t * 3))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.25),
    );
  }

  // Wings, spread up and out behind the head.
  for (final side in [-1.0, 1.0]) {
    canvas.save();
    canvas.translate(side * 0.2, -1.12);
    canvas.rotate(side * (0.05 * math.sin(t * 1.4) - 0.25 * flap));
    canvas.translate(-side * 0.2, 1.12);
    Offset m(double x, double y) => Offset(side * x, y);
    _wing(
      canvas,
      m(0.2, -1.12),
      m(0.56, -1.5),
      m(0.9, -1.68),
      [m(0.82, -1.98), m(1.36, -1.5), m(1.42, -0.96), m(1.16, -0.5)],
      m(0.5, -0.92),
      0.065,
      col,
      lite: lite,
    );
    canvas.restore();
  }

  // The body: from the neck at the top, round the frame clockwise, to the
  // tail's spade up on the left.
  final body = <Offset>[
    for (var k = 0; k <= 14; k++)
      () {
        final a = -math.pi / 2 + 0.15 + k * 0.4;
        final rr = 1.13 + 0.025 * math.sin(t * 1.8 - k * 0.6);
        return Offset(math.cos(a), math.sin(a)) * rr;
      }(),
  ];
  _tail(
    canvas,
    body,
    const [0.15, 0.15, 0.14, 0.12, 0.1, 0.08, 0.06, 0.045, 0.03, 0.02],
    col,
    lite: lite,
  );

  // The neck rising from the coil, then the head facing you.
  final (neck, _, _, _) = _tube(
    [
      Offset(math.cos(-math.pi / 2 + 0.15), math.sin(-math.pi / 2 + 0.15)) *
          1.13,
      Offset(0.06, -1.3 + breathe),
      Offset(0.0, -1.42 + breathe),
    ],
    const [0.15, 0.13, 0.12],
  );
  _shade(canvas, neck, col, lite: lite);
  canvas.save();
  canvas.translate(0, -1.6 + breathe - roar * 0.05);
  canvas.rotate(0.06 * math.sin(t * 0.7));
  canvas.scale(1.1, 1.1);
  _headFront(canvas, t, col, roar: roar, breath: breath, lite: lite);
  canvas.restore();

  if (col.glow != null && !lite) {
    _sparkles(canvas, const Offset(0, -0.4), 1.3, t, col.gold, 8);
  }
  canvas.restore();
}

/// The head from the front, centred on the origin: broad across the brow
/// and narrowing to a rounded snout, big glowing eyes set wide with slit
/// pupils under strong brows, ear flaps sweeping out to the sides, gold
/// horns rising behind, and a wide mouth that curls up at the corners. It
/// opens into a roar ([roar] 0..1) and fire ([breath]).
void _headFront(
  Canvas canvas,
  double t,
  DragonColors col, {
  required double roar,
  double breath = 0,
  bool lite = false,
}) {
  final flick = math.sin(t * 1.5) * 0.07;

  // Horns and ear flaps behind the head.
  for (final side in [-1.0, 1.0]) {
    Offset m(double x, double y) => Offset(side * x, y);
    _gold(
      canvas,
      _horn(m(0.12, -0.27), m(0.26, -0.5), m(0.44, -0.62), 0.055),
      col,
    );
    double out(double a) => side > 0 ? a : math.pi - a;
    _earFlap(
      canvas,
      m(0.3, -0.02),
      out(0.05 + flick * 0.6),
      0.3,
      col,
      bend: -side,
      lite: lite,
    );
    _earFlap(
      canvas,
      m(0.27, -0.17),
      out(-0.42 - flick),
      0.5,
      col,
      bend: -side,
      lite: lite,
    );
  }

  // The head.
  final head = _blob(const [
    Offset(0.0, -0.33),
    Offset(0.22, -0.3),
    Offset(0.35, -0.18),
    Offset(0.38, -0.02),
    Offset(0.31, 0.13),
    Offset(0.18, 0.25),
    Offset(0.0, 0.29),
    Offset(-0.18, 0.25),
    Offset(-0.31, 0.13),
    Offset(-0.38, -0.02),
    Offset(-0.35, -0.18),
    Offset(-0.22, -0.3),
  ]);
  _shade(canvas, head, col, lite: lite, outline: 0.02);
  if (!lite) {
    canvas.save();
    canvas.clipPath(head);
    // A warmer snout and a sheen down the middle of the face.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 0.2), width: 0.4, height: 0.22),
      Paint()
        ..color = col.belly.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.05),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, -0.28)
        ..lineTo(0, 0.1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.07
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.03),
    );
    canvas.restore();
  }

  // Nostrils: two small slits, angled out.
  for (final side in [-1.0, 1.0]) {
    canvas.drawPath(
      Path()
        ..moveTo(side * 0.035, 0.13)
        ..quadraticBezierTo(side * 0.06, 0.12, side * 0.08, 0.15),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.016
        ..strokeCap = StrokeCap.round
        ..color = _ink,
    );
  }

  final mouthOpen = roar.clamp(0.0, 1.0);
  if (mouthOpen > 0.15) {
    // A roaring mouth: dark inside, a tongue, a row of teeth.
    final drop = 0.06 + mouthOpen * 0.14;
    final mouth = Path()
      ..moveTo(-0.2, 0.18)
      ..quadraticBezierTo(0, 0.23, 0.2, 0.18)
      ..quadraticBezierTo(0.06, 0.2 + drop * 1.4, 0, 0.2 + drop * 1.45)
      ..quadraticBezierTo(-0.06, 0.2 + drop * 1.4, -0.2, 0.18)
      ..close();
    canvas.drawPath(mouth, Paint()..color = const Color(0xFF4A0816));
    canvas.save();
    canvas.clipPath(mouth);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, 0.2 + drop * 1.3),
        width: 0.22,
        height: drop * 0.9,
      ),
      Paint()..color = const Color(0xFFE85A78),
    );
    final tooth = Paint()..color = const Color(0xFFFFF8EC);
    for (var k = -2; k <= 2; k++) {
      final x = k * 0.07;
      final y = 0.2 + 0.02 * (1 - (k.abs() / 2));
      canvas.drawPath(
        Path()..addPolygon([
          Offset(x - 0.022, y - 0.01),
          Offset(x, y + (k.abs() == 2 ? 0.05 : 0.03)),
          Offset(x + 0.022, y - 0.01),
        ], true),
        tooth,
      );
    }
    canvas.restore();
    canvas.drawPath(
      mouth,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.016
        ..strokeJoin = StrokeJoin.round
        ..color = _ink,
    );
  } else {
    // A wide mouth line, curling up at both corners.
    canvas.drawPath(
      Path()
        ..moveTo(-0.24, 0.15)
        ..quadraticBezierTo(-0.22, 0.19, -0.18, 0.19)
        ..quadraticBezierTo(0, 0.25, 0.18, 0.19)
        ..quadraticBezierTo(0.22, 0.19, 0.24, 0.15),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.016
        ..strokeCap = StrokeCap.round
        ..color = _ink,
    );
  }

  // Big eyes set wide, glancing about, under strong brows.
  final glance = Offset(math.sin(t * 0.7) * 0.4, math.sin(t * 0.5) * 0.2);
  final blink = _blink(t);
  for (final side in [-1.0, 1.0]) {
    _dragonEye(
      canvas,
      Offset(side * 0.17, -0.05),
      0.21,
      0.16,
      col,
      look: glance,
      blink: blink,
      tilt: -side * 0.16,
      lite: lite,
    );
    canvas.drawPath(
      Path()
        ..moveTo(side * 0.06, -0.12)
        ..quadraticBezierTo(side * 0.17, -0.18, side * 0.29, -0.16),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.032
        ..strokeCap = StrokeCap.round
        ..color = col.shadow,
    );
  }

  if (breath > 0) _fireBurst(canvas, const Offset(0, 0.22), t, breath);
}

/// Fire breathed straight at you: a burst of flame petals blooming round
/// the mouth, a white-hot core, sparks flung out. [k] runs 0..1.
void _fireBurst(Canvas canvas, Offset at, double t, double k) {
  final grow = Curves.easeOutBack.transform((k * 2.2).clamp(0.0, 1.0));
  final fade = k < 0.7 ? 1.0 : (1 - (k - 0.7) / 0.3);
  if (fade <= 0) return;
  canvas.drawCircle(
    at,
    0.42 * grow,
    Paint()
      ..color = const Color(0xFFFF7A2A).withValues(alpha: 0.45 * fade)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.12),
  );
  for (final (scale, color) in [
    (1.0, const Color(0xFFE23A1E)),
    (0.72, const Color(0xFFFF8A1F)),
    (0.48, const Color(0xFFFFD25A)),
  ]) {
    for (var i = 0; i < 9; i++) {
      final a = i * 2 * math.pi / 9 + t * 1.5 + scale;
      final d = Offset(math.cos(a), math.sin(a));
      final n = Offset(-d.dy, d.dx);
      final len = 0.34 * scale * grow * (0.8 + 0.2 * math.sin(t * 13 + i));
      final tip = at + d * len;
      final c1 = at + d * (len * 0.5) + n * (len * 0.35);
      final c2 = at + d * (len * 0.5) - n * (len * 0.35);
      canvas.drawPath(
        Path()
          ..moveTo(at.dx, at.dy)
          ..quadraticBezierTo(c1.dx, c1.dy, tip.dx, tip.dy)
          ..quadraticBezierTo(c2.dx, c2.dy, at.dx, at.dy)
          ..close(),
        Paint()..color = color.withValues(alpha: fade),
      );
    }
  }
  canvas.drawCircle(
    at,
    0.08 * grow,
    Paint()..color = const Color(0xFFFFF6D6).withValues(alpha: fade),
  );
  for (var i = 0; i < 10; i++) {
    final s = (t * 1.8 + i / 10) % 1.0;
    final a = i * 2.39996;
    canvas.drawCircle(
      at + Offset(math.cos(a), math.sin(a)) * (0.2 + 0.4 * s) * grow,
      0.02 * (1 - s),
      Paint()
        ..color = const Color(0xFFFFE27A).withValues(alpha: fade * (1 - s)),
    );
  }
}
