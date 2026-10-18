import 'dart:math' as math;
import 'dart:ui';

import 'art_doc.dart';
import 'svg_path.dart';

/// A picture to color in: bold outlines on the page ([kPageSize]), drawn
/// as closed shapes so each one fills with a single tap.
class ColoringPage {
  const ColoringPage({
    required this.id,
    required this.name,
    required this.draw,
    this.artPath,
  });

  /// A page from the picture library (pictures Chip draws for players):
  /// each outline is SVG path data in page units.
  factory ColoringPage.fromSvg({
    required String id,
    required String name,
    required List<String> paths,
  }) {
    List<Path> draw() => paths.map(parseSvgPath).whereType<Path>().toList();
    return ColoringPage(id: id, name: name, draw: draw);
  }

  /// A page that is line art (a real portrait): an image of black lines on
  /// white, kept in the library at [artPath] (see LineArt).
  factory ColoringPage.fromArt({
    required String id,
    required String name,
    required String artPath,
  }) => ColoringPage(id: id, name: name, draw: _noLines, artPath: artPath);

  final String id;
  final String name;

  /// The outlines, in page units (none for line art).
  final List<Path> Function() draw;

  /// Where a line-art page's image is kept; null for outlines.
  final String? artPath;

  /// How thick the outlines are drawn, in page units.
  static const lineWidth = 7.0;

  static ColoringPage? byId(String? id) =>
      kColoringPages.where((p) => p.id == id).firstOrNull;

  /// Draws the outlines in [ink] onto [canvas] (already in page units).
  static void paintLines(Canvas canvas, List<Path> lines, Color ink) {
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = ink;
    for (final p in lines) {
      canvas.drawPath(p, pen);
    }
  }
}

List<Path> _noLines() => const [];

const kColoringPages = [
  ColoringPage(id: 'mandala', name: 'Mandala', draw: _mandala),
  ColoringPage(id: 'chip', name: 'Chip', draw: _chip),
  ColoringPage(id: 'island', name: 'Floating island', draw: _island),
  ColoringPage(id: 'dragon', name: 'Little dragon', draw: _dragon),
  ColoringPage(id: 'rocket', name: 'Rocket', draw: _rocket),
  ColoringPage(id: 'castle', name: 'Castle', draw: _castle),
  ColoringPage(id: 'ocean', name: 'Under the sea', draw: _ocean),
  ColoringPage(id: 'garden', name: 'Garden', draw: _garden),
];

// ── shapes ─────────────────────────────────────────────────────────────────

Offset _dir(double a) => Offset(math.cos(a), math.sin(a));

Path _circle(Offset c, double r) =>
    Path()..addOval(Rect.fromCircle(center: c, radius: r));

Path _oval(Offset c, double w, double h) =>
    Path()..addOval(Rect.fromCenter(center: c, width: w, height: h));

Path _rrect(Rect r, double radius) =>
    Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)));

Path _poly(List<Offset> pts) => Path()..addPolygon(pts, true);

/// A smooth closed shape through [pts] (Catmull-Rom).
Path _blob(List<Offset> pts) {
  final n = pts.length;
  final path = Path();
  Offset at(int i) => pts[(i % n + n) % n];
  for (var i = 0; i < n; i++) {
    final p0 = at(i - 1), p1 = at(i), p2 = at(i + 1), p3 = at(i + 2);
    final c1 = p1 + (p2 - p0) / 6;
    final c2 = p2 - (p3 - p1) / 6;
    if (i == 0) path.moveTo(p1.dx, p1.dy);
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }
  return path..close();
}

/// An open smooth line through [pts].
Path _curve(List<Offset> pts) {
  final path = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (var i = 1; i < pts.length; i++) {
    final a = pts[i - 1], b = pts[i];
    final mid = Offset.lerp(a, b, 0.5)!;
    if (i == 1) {
      path.lineTo(mid.dx, mid.dy);
    } else {
      path.quadraticBezierTo(a.dx, a.dy, mid.dx, mid.dy);
    }
  }
  return path..lineTo(pts.last.dx, pts.last.dy);
}

Path _star(
  Offset c,
  double outer,
  double inner,
  int points, {
  double turn = 0,
}) {
  return _poly([
    for (var i = 0; i < points * 2; i++)
      c +
          _dir(-math.pi / 2 + turn + i * math.pi / points) *
              (i.isEven ? outer : inner),
  ]);
}

/// A teardrop petal from [base] pointing along [angle].
Path _petal(Offset base, double angle, double length, double width) {
  final d = _dir(angle);
  final n = Offset(-d.dy, d.dx);
  final tip = base + d * length;
  final a = base + d * (length * 0.45) + n * width;
  final b = base + d * (length * 0.45) - n * width;
  return Path()
    ..moveTo(base.dx, base.dy)
    ..quadraticBezierTo(a.dx, a.dy, tip.dx, tip.dy)
    ..quadraticBezierTo(b.dx, b.dy, base.dx, base.dy)
    ..close();
}

/// A puffy cloud: overlapping circles merged into one outline.
Path _cloud(Offset c, double w) {
  var cloud = _rrect(
    Rect.fromCenter(
      center: c.translate(0, w * 0.08),
      width: w,
      height: w * 0.32,
    ),
    w * 0.16,
  );
  for (final (dx, dy, r) in const [
    (-0.28, 0.0, 0.17),
    (-0.05, -0.1, 0.24),
    (0.24, -0.02, 0.19),
  ]) {
    cloud = Path.combine(
      PathOperation.union,
      cloud,
      _circle(c.translate(dx * w, dy * w), r * w),
    );
  }
  return cloud;
}

Path _heart(Offset c, double s) => Path()
  ..moveTo(c.dx, c.dy + s * 0.9)
  ..cubicTo(
    c.dx - s * 1.4,
    c.dy,
    c.dx - s * 0.7,
    c.dy - s * 1.1,
    c.dx,
    c.dy - s * 0.4,
  )
  ..cubicTo(
    c.dx + s * 0.7,
    c.dy - s * 1.1,
    c.dx + s * 1.4,
    c.dy,
    c.dx,
    c.dy + s * 0.9,
  )
  ..close();

/// Ground along the bottom of the page: straight down the sides and
/// along the bottom (inside the frame), a smooth line across the top
/// through [top].
Path _ground(List<Offset> top) {
  final path = Path()..moveTo(top.first.dx, 1270);
  path.lineTo(top.first.dx, top.first.dy);
  for (var i = 1; i < top.length; i++) {
    final a = top[i - 1], b = top[i];
    final mid = Offset.lerp(a, b, 0.5)!;
    path.quadraticBezierTo(a.dx, a.dy, mid.dx, mid.dy);
  }
  path
    ..lineTo(top.last.dx, top.last.dy)
    ..lineTo(top.last.dx, 1270)
    ..close();
  // Trimmed to the frame's rounded corners.
  return Path.combine(PathOperation.intersect, path, _frame());
}

Path _frame() => _rrect(const Rect.fromLTWH(30, 30, 940, 1240), 48);

// ── pages ──────────────────────────────────────────────────────────────────

List<Path> _mandala() {
  const c = Offset(500, 650);
  final out = <Path>[_frame(), _circle(c, 440), _circle(c, 70), _circle(c, 26)];
  // Rings of petals, each turned half a step from the one inside it.
  for (final (count, from, length, width, turn) in const [
    (8, 70.0, 110.0, 42.0, 0.0),
    (12, 170.0, 100.0, 34.0, 0.13),
    (16, 268.0, 100.0, 26.0, 0.0),
  ]) {
    for (var i = 0; i < count; i++) {
      final a = turn + i * 2 * math.pi / count;
      out.add(_petal(c + _dir(a) * from, a, length, width));
    }
  }
  out
    ..add(_circle(c, 170))
    ..add(_circle(c, 268));
  for (var i = 0; i < 24; i++) {
    final a = i * 2 * math.pi / 24;
    out.add(_circle(c + _dir(a) * 405, 18));
  }
  // Little hearts and stars in the corners.
  for (final (x, y) in const [
    (120.0, 130.0),
    (880.0, 130.0),
    (120.0, 1170.0),
    (880.0, 1170.0),
  ]) {
    out.add(_star(Offset(x, y), 46, 20, 5));
  }
  return out;
}

List<Path> _chip() {
  const c = Offset(500, 620);
  final out = <Path>[_frame()];
  // Sparkles.
  for (final (x, y, s) in const [
    (180.0, 230.0, 46.0),
    (830.0, 300.0, 38.0),
    (150.0, 900.0, 34.0),
    (860.0, 960.0, 48.0),
  ]) {
    out.add(_star(Offset(x, y), s, s * 0.38, 4));
  }
  // The sprout on top: a stem and two leaves.
  out
    ..add(
      _rrect(
        Rect.fromCenter(center: c.translate(0, -330), width: 26, height: 110),
        13,
      ),
    )
    ..add(
      _blob([
        c.translate(-6, -360),
        c.translate(-90, -420),
        c.translate(-170, -400),
        c.translate(-110, -350),
      ]),
    )
    ..add(
      _blob([
        c.translate(6, -370),
        c.translate(100, -450),
        c.translate(180, -420),
        c.translate(120, -360),
      ]),
    );
  // The coin: rim and face.
  out
    ..add(_circle(c, 300))
    ..add(_circle(c, 250));
  // Rim notches.
  for (var i = 0; i < 24; i++) {
    final a = i * 2 * math.pi / 24;
    out.add(
      Path()
        ..moveTo((c + _dir(a) * 255).dx, (c + _dir(a) * 255).dy)
        ..lineTo((c + _dir(a) * 296).dx, (c + _dir(a) * 296).dy),
    );
  }
  // Eyes with shines, cheeks, a big smile.
  for (final side in const [-1.0, 1.0]) {
    final e = c.translate(side * 95, -50);
    out
      ..add(_oval(e, 82, 110))
      ..add(_circle(e.translate(-14, -22), 16))
      ..add(_oval(c.translate(side * 160, 60), 70, 40));
  }
  out.add(
    Path()
      ..moveTo(c.dx - 110, c.dy + 70)
      ..quadraticBezierTo(c.dx, c.dy + 200, c.dx + 110, c.dy + 70)
      ..quadraticBezierTo(c.dx, c.dy + 120, c.dx - 110, c.dy + 70)
      ..close(),
  );
  // Two floating hands.
  for (final side in const [-1.0, 1.0]) {
    final h = c.translate(side * 380, 140);
    out
      ..add(_oval(h, 120, 100))
      ..add(_oval(h.translate(side * -48, -40), 44, 56));
  }
  // A little shadow underneath.
  out.add(_oval(c.translate(0, 420), 360, 60));
  return out;
}

List<Path> _island() {
  final out = <Path>[_frame()];
  // Sun and its rays.
  const sun = Offset(820, 210);
  out.add(_circle(sun, 85));
  for (var i = 0; i < 10; i++) {
    final a = i * 2 * math.pi / 10;
    out.add(
      _poly([
        sun + _dir(a - 0.12) * 105,
        sun + _dir(a) * 160,
        sun + _dir(a + 0.12) * 105,
      ]),
    );
  }
  out
    ..add(_cloud(const Offset(250, 250), 300))
    ..add(_cloud(const Offset(640, 420), 220));
  // The island: grassy top, layered rock below.
  out
    ..add(
      _blob(const [
        Offset(150, 760),
        Offset(330, 700),
        Offset(560, 690),
        Offset(800, 720),
        Offset(870, 780),
        Offset(700, 820),
        Offset(420, 830),
        Offset(200, 815),
      ]),
    )
    ..add(
      _blob(const [
        Offset(185, 810),
        Offset(430, 835),
        Offset(720, 820),
        Offset(840, 800),
        Offset(760, 930),
        Offset(620, 1040),
        Offset(500, 1150),
        Offset(400, 1030),
        Offset(260, 930),
      ]),
    )
    ..add(
      _curve(const [
        Offset(240, 900),
        Offset(430, 930),
        Offset(640, 905),
        Offset(770, 880),
      ]),
    )
    ..add(
      _curve(const [Offset(330, 1000), Offset(500, 1010), Offset(650, 990)]),
    );
  // A tree.
  out
    ..add(
      _poly(const [
        Offset(360, 720),
        Offset(380, 560),
        Offset(410, 560),
        Offset(425, 720),
      ]),
    )
    ..add(
      _blob(const [
        Offset(300, 560),
        Offset(310, 450),
        Offset(390, 390),
        Offset(480, 430),
        Offset(500, 530),
        Offset(440, 590),
        Offset(350, 600),
      ]),
    );
  for (final (x, y) in const [(360.0, 480.0), (430.0, 520.0), (390.0, 545.0)]) {
    out.add(_circle(Offset(x, y), 16));
  }
  // A little house.
  out
    ..add(_rect(const Rect.fromLTWH(560, 610, 150, 105)))
    ..add(_poly(const [Offset(540, 615), Offset(635, 530), Offset(730, 615)]))
    ..add(_rrect(const Rect.fromLTWH(615, 650, 42, 65), 12))
    ..add(_rect(const Rect.fromLTWH(575, 630, 30, 30)));
  // The waterfall pouring off the edge.
  out.add(
    _blob(const [
      Offset(805, 790),
      Offset(850, 780),
      Offset(860, 900),
      Offset(850, 1060),
      Offset(830, 1180),
      Offset(800, 1180),
      Offset(810, 1040),
      Offset(812, 900),
    ]),
  );
  // Birds.
  for (final (x, y) in const [(560.0, 210.0), (620.0, 260.0)]) {
    out.add(_curve([Offset(x - 30, y), Offset(x - 12, y - 16), Offset(x, y)]));
    out.add(_curve([Offset(x, y), Offset(x + 12, y - 16), Offset(x + 30, y)]));
  }
  return out;
}

Path _rect(Rect r) => Path()..addRect(r);

List<Path> _dragon() {
  final out = <Path>[_frame()];
  // Tail curling round, ending in a spade.
  out
    ..add(
      _blob(const [
        Offset(620, 960),
        Offset(780, 1010),
        Offset(860, 940),
        Offset(850, 840),
        Offset(880, 830),
        Offset(900, 950),
        Offset(800, 1060),
        Offset(610, 1020),
      ]),
    )
    ..add(_heart(const Offset(868, 790), 46));
  // Wings.
  for (final side in const [-1.0, 1.0]) {
    final s = side;
    out.add(
      _blob([
        Offset(500 + s * 90, 560),
        Offset(500 + s * 260, 380),
        Offset(500 + s * 380, 340),
        Offset(500 + s * 350, 470),
        Offset(500 + s * 300, 520),
        Offset(500 + s * 230, 560),
        Offset(500 + s * 150, 620),
      ]),
    );
    out.add(
      _curve([
        Offset(500 + s * 260, 380),
        Offset(500 + s * 250, 470),
        Offset(500 + s * 200, 560),
      ]),
    );
  }
  // Body and belly with stripes.
  out
    ..add(
      _blob(const [
        Offset(500, 520),
        Offset(650, 600),
        Offset(690, 800),
        Offset(640, 1010),
        Offset(500, 1060),
        Offset(360, 1010),
        Offset(310, 800),
        Offset(350, 600),
      ]),
    )
    ..add(
      _blob(const [
        Offset(500, 640),
        Offset(590, 700),
        Offset(600, 880),
        Offset(560, 1000),
        Offset(500, 1020),
        Offset(440, 1000),
        Offset(400, 880),
        Offset(410, 700),
      ]),
    );
  for (final y in const [720.0, 790.0, 860.0, 930.0]) {
    out.add(_curve([Offset(415, y), Offset(500, y + 18), Offset(590, y)]));
  }
  // Feet and arms.
  for (final side in const [-1.0, 1.0]) {
    out
      ..add(_oval(Offset(500 + side * 120, 1060), 150, 80))
      ..add(_oval(Offset(500 + side * 175, 760), 70, 130));
  }
  // Head: round with a snout, horns, eyes, a happy mouth.
  for (final side in const [-1.0, 1.0]) {
    out.add(
      _poly([
        Offset(500 + side * 70, 300),
        Offset(500 + side * 130, 150),
        Offset(500 + side * 145, 290),
      ]),
    );
  }
  out
    ..add(
      _blob(const [
        Offset(500, 240),
        Offset(640, 290),
        Offset(680, 410),
        Offset(620, 530),
        Offset(500, 560),
        Offset(380, 530),
        Offset(320, 410),
        Offset(360, 290),
      ]),
    )
    ..add(_oval(const Offset(500, 470), 220, 130));
  for (final side in const [-1.0, 1.0]) {
    out
      ..add(_oval(Offset(500 + side * 80, 370), 70, 84))
      ..add(_circle(Offset(500 + side * 74, 356), 14))
      ..add(_circle(Offset(500 + side * 36, 460), 10));
  }
  out.add(_curve(const [Offset(440, 500), Offset(500, 530), Offset(560, 500)]));
  // Spikes down the back of the head.
  for (var i = 0; i < 3; i++) {
    final y = 250.0 + i * 50;
    out.add(_poly([Offset(480, y), Offset(500, y - 40), Offset(520, y)]));
  }
  return out;
}

List<Path> _rocket() {
  final out = <Path>[_frame()];
  // Stars and a moon.
  for (final (x, y, s) in const [
    (140.0, 160.0, 34.0),
    (340.0, 110.0, 24.0),
    (870.0, 520.0, 30.0),
    (150.0, 640.0, 28.0),
    (880.0, 1000.0, 36.0),
    (190.0, 1050.0, 24.0),
  ]) {
    out.add(_star(Offset(x, y), s, s * 0.45, 5));
  }
  out.add(
    Path.combine(
      PathOperation.difference,
      _circle(const Offset(800, 190), 95),
      _circle(const Offset(845, 160), 85),
    ),
  );
  // A ringed planet.
  out
    ..add(_circle(const Offset(240, 360), 110))
    ..add(_oval(const Offset(240, 370), 330, 80))
    ..add(_curve(const [Offset(150, 330), Offset(240, 300), Offset(330, 330)]));
  // The rocket.
  const x = 560.0;
  out
    ..add(
      _blob(const [
        Offset(x, 330),
        Offset(x + 110, 470),
        Offset(x + 130, 700),
        Offset(x + 100, 920),
        Offset(x - 100, 920),
        Offset(x - 130, 700),
        Offset(x - 110, 470),
      ]),
    )
    ..add(
      _blob(const [
        Offset(x, 330),
        Offset(x + 70, 410),
        Offset(x + 90, 470),
        Offset(x - 90, 470),
        Offset(x - 70, 410),
      ]),
    )
    ..add(_circle(const Offset(x, 600), 66))
    ..add(_circle(const Offset(x, 600), 44))
    ..add(_circle(const Offset(x, 770), 30));
  for (final side in const [-1.0, 1.0]) {
    out.add(
      _blob([
        Offset(x + side * 110, 780),
        Offset(x + side * 200, 880),
        Offset(x + side * 210, 990),
        Offset(x + side * 120, 930),
        Offset(x + side * 96, 900),
      ]),
    );
  }
  out
    ..add(
      _rrect(
        Rect.fromCenter(center: const Offset(x, 945), width: 170, height: 50),
        14,
      ),
    )
    // Flames.
    ..add(
      _blob(const [
        Offset(x - 70, 975),
        Offset(x + 70, 975),
        Offset(x + 50, 1080),
        Offset(x, 1210),
        Offset(x - 50, 1080),
      ]),
    )
    ..add(
      _blob(const [
        Offset(x - 35, 985),
        Offset(x + 35, 985),
        Offset(x + 22, 1060),
        Offset(x, 1130),
        Offset(x - 22, 1060),
      ]),
    );
  return out;
}

List<Path> _castle() {
  final out = <Path>[_frame()];
  out
    ..add(_cloud(const Offset(220, 230), 260))
    ..add(_cloud(const Offset(780, 180), 220));
  // The hill.
  out.add(
    _ground(const [
      Offset(30, 1100),
      Offset(300, 1010),
      Offset(700, 1000),
      Offset(970, 1090),
    ]),
  );
  // Walls with battlements, a gate.
  final wall = <Offset>[const Offset(230, 1010)];
  for (var i = 0; i < 9; i++) {
    final x0 = 230.0 + i * 60;
    wall
      ..add(Offset(x0, 690))
      ..add(Offset(x0 + 30, 690))
      ..add(Offset(x0 + 30, 720))
      ..add(Offset(x0 + 60, 720));
  }
  wall
    ..removeLast()
    ..add(const Offset(770, 690))
    ..add(const Offset(770, 1010));
  out
    ..add(_poly(wall))
    ..add(
      Path()
        ..moveTo(440, 1010)
        ..lineTo(440, 900)
        ..arcToPoint(const Offset(560, 900), radius: const Radius.circular(60))
        ..lineTo(560, 1010)
        ..close(),
    );
  for (var i = 0; i < 3; i++) {
    out.add(
      _curve([Offset(470.0 + i * 30, 870), Offset(470.0 + i * 30, 1010)]),
    );
  }
  // Towers with cone roofs and flags.
  for (final (cx, top, w) in const [
    (230.0, 560.0, 150.0),
    (770.0, 560.0, 150.0),
    (500.0, 420.0, 170.0),
  ]) {
    out
      ..add(_rect(Rect.fromLTWH(cx - w / 2, top, w, cx == 500 ? 290 : 450)))
      ..add(
        _poly([
          Offset(cx - w / 2 - 20, top),
          Offset(cx, top - 190),
          Offset(cx + w / 2 + 20, top),
        ]),
      )
      ..add(
        _rrect(
          Rect.fromCenter(center: Offset(cx, top + 90), width: 46, height: 76),
          23,
        ),
      )
      ..add(_curve([Offset(cx, top - 190), Offset(cx, top - 270)]))
      ..add(
        _poly([
          Offset(cx, top - 270),
          Offset(cx + 70, top - 245),
          Offset(cx, top - 220),
        ]),
      );
  }
  // Windows along the wall.
  for (final x in const [320.0, 680.0]) {
    out.add(
      _rrect(
        Rect.fromCenter(center: Offset(x, 820), width: 40, height: 64),
        20,
      ),
    );
  }
  return out;
}

List<Path> _ocean() {
  final out = <Path>[_frame()];
  // The surface, waves.
  out.add(
    _curve([
      for (var i = 0; i <= 8; i++)
        Offset(30.0 + i * 117.5, i.isEven ? 170 : 140),
    ]),
  );
  // Sand and seaweed.
  out.add(
    _ground(const [
      Offset(30, 1120),
      Offset(300, 1080),
      Offset(620, 1110),
      Offset(970, 1070),
    ]),
  );
  for (final (x, h) in const [(140.0, 330.0), (230.0, 230.0), (860.0, 300.0)]) {
    out.add(
      _blob([
        Offset(x - 20, 1110),
        Offset(x - 50, 1110 - h * 0.35),
        Offset(x - 10, 1110 - h * 0.65),
        Offset(x - 30, 1110 - h),
        Offset(x + 20, 1110 - h * 0.7),
        Offset(x - 5, 1110 - h * 0.35),
        Offset(x + 20, 1110),
      ]),
    );
  }
  // Shells and a starfish on the sand.
  out
    ..add(_star(const Offset(560, 1170), 60, 24, 5, turn: 0.3))
    ..add(_oval(const Offset(720, 1175), 90, 60))
    ..add(
      _curve(const [Offset(690, 1150), Offset(720, 1200), Offset(750, 1150)]),
    );
  // The big fish.
  const f = Offset(480, 600);
  out
    ..add(
      _poly([
        f.translate(170, 0),
        f.translate(300, -110),
        f.translate(290, 110),
      ]),
    )
    ..add(_oval(f, 420, 280))
    ..add(
      _poly([
        f.translate(-30, -130),
        f.translate(40, -210),
        f.translate(100, -120),
      ]),
    )
    ..add(_circle(f.translate(-120, -30), 34))
    ..add(_circle(f.translate(-128, -38), 12))
    ..add(
      _curve([
        f.translate(-205, 30),
        f.translate(-180, 45),
        f.translate(-160, 35),
      ]),
    );
  for (final dx in const [-40.0, 40.0, 120.0]) {
    out.add(
      _curve([
        f.translate(dx, -128),
        f.translate(dx + 30, 0),
        f.translate(dx, 128),
      ]),
    );
  }
  // Two small fish.
  for (final (x, y, s) in const [(760.0, 900.0, 1.0), (260.0, 880.0, -1.0)]) {
    final c = Offset(x, y);
    out
      ..add(
        _poly([
          c.translate(s * -70, 0),
          c.translate(s * -130, -45),
          c.translate(s * -130, 45),
        ]),
      )
      ..add(_oval(c, 160, 96))
      ..add(_circle(c.translate(s * 40, -12), 12));
  }
  // Bubbles.
  for (final (x, y, r) in const [
    (300.0, 420.0, 26.0),
    (330.0, 340.0, 18.0),
    (310.0, 280.0, 12.0),
    (780.0, 380.0, 30.0),
    (820.0, 300.0, 20.0),
    (640.0, 860.0, 16.0),
  ]) {
    out.add(_circle(Offset(x, y), r));
  }
  return out;
}

List<Path> _garden() {
  final out = <Path>[_frame()];
  // Sun peeking in, and a butterfly.
  out.add(_circle(const Offset(150, 160), 80));
  const b = Offset(740, 300);
  for (final side in const [-1.0, 1.0]) {
    out
      ..add(
        _blob([
          b,
          b.translate(side * 110, -100),
          b.translate(side * 140, -10),
          b.translate(side * 40, 20),
        ]),
      )
      ..add(
        _blob([
          b.translate(0, 10),
          b.translate(side * 100, 40),
          b.translate(side * 80, 120),
          b.translate(side * 20, 60),
        ]),
      )
      ..add(_circle(b.translate(side * 80, -40), 16));
  }
  out
    ..add(_oval(b.translate(0, 20), 26, 130))
    ..add(
      _curve([
        b.translate(-6, -40),
        b.translate(-30, -90),
        b.translate(-50, -100),
      ]),
    )
    ..add(
      _curve([
        b.translate(6, -40),
        b.translate(30, -90),
        b.translate(50, -100),
      ]),
    );
  // Grass along the bottom.
  final grass = <Offset>[const Offset(40, 1265), const Offset(40, 1130)];
  for (var i = 0; i < 12; i++) {
    final x = 40.0 + i * 76.6;
    grass
      ..add(Offset(x + 38, 1060 + (i % 3) * 25))
      ..add(Offset(x + 76.6, 1130));
  }
  grass.add(const Offset(960, 1265));
  out.add(_poly(grass));
  // Three flowers: stem, leaves, petals and a middle.
  for (final (x, top, petals, size) in const [
    (260.0, 520.0, 6, 95.0),
    (520.0, 420.0, 8, 120.0),
    (790.0, 640.0, 5, 90.0),
  ]) {
    final head = Offset(x, top);
    out
      ..add(_rrect(Rect.fromLTRB(x - 12, top + size * 0.5, x + 12, 1110), 12))
      ..add(_petal(Offset(x + 10, top + size + 180), -0.5, 150, 46))
      ..add(_petal(Offset(x - 10, top + size + 260), math.pi + 0.45, 140, 42));
    for (var i = 0; i < petals; i++) {
      final a = i * 2 * math.pi / petals;
      out.add(_circle(head + _dir(a) * size * 0.72, size * 0.42));
    }
    out
      ..add(_circle(head, size * 0.42))
      ..add(_circle(head, size * 0.2));
  }
  // A little heart and ladybug.
  out
    ..add(_heart(const Offset(150, 840), 50))
    ..add(_oval(const Offset(650, 900), 90, 70))
    ..add(_curve(const [Offset(650, 866), Offset(650, 935)]))
    ..add(_circle(const Offset(650, 852), 22));
  return out;
}
