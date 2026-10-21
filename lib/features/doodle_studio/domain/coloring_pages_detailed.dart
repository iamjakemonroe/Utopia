part of 'coloring_pages.dart';

// Detailed pages, for grown-ups: patterns and scenes with many shapes to
// fill, none of them tiny (a fingertip still picks one out).

/// [path] trimmed to the page's frame.
Path _inFrame(Path path) =>
    Path.combine(PathOperation.intersect, path, _frame());

Path _line(Offset a, Offset b) => Path()
  ..moveTo(a.dx, a.dy)
  ..lineTo(b.dx, b.dy);

/// The line from [a] to [b], cut to the page's frame (Path.combine only
/// works on shapes with an inside, so lines are cut by hand). Null if
/// none of it is on the page.
Path? _lineInFrame(Offset a, Offset b) {
  const box = Rect.fromLTRB(30, 30, 970, 1270);
  var t0 = 0.0, t1 = 1.0;
  final d = b - a;
  for (final (p, q) in [
    (-d.dx, a.dx - box.left),
    (d.dx, box.right - a.dx),
    (-d.dy, a.dy - box.top),
    (d.dy, box.bottom - a.dy),
  ]) {
    if (p == 0) {
      if (q < 0) return null;
      continue;
    }
    final r = q / p;
    if (p < 0) {
      if (r > t1) return null;
      if (r > t0) t0 = r;
    } else {
      if (r < t0) return null;
      if (r < t1) t1 = r;
    }
  }
  return _line(a + d * t0, a + d * t1);
}

/// A lotus petal from [base] along [angle]: a rounded body with a
/// pointed tip.
Path _lotusPetal(Offset base, double angle, double length, double width) {
  final d = _dir(angle);
  final n = Offset(-d.dy, d.dx);
  final tip = base + d * length;
  final l1 = base + n * width * 0.5;
  final r1 = base - n * width * 0.5;
  final l2 = base + d * (length * 0.55) + n * width;
  final r2 = base + d * (length * 0.55) - n * width;
  return Path()
    ..moveTo(l1.dx, l1.dy)
    ..quadraticBezierTo(l2.dx, l2.dy, tip.dx, tip.dy)
    ..quadraticBezierTo(r2.dx, r2.dy, r1.dx, r1.dy)
    ..close();
}

// ── Lotus mandala ─────────────────────────────────────────────────────────

List<Path> _lotusMandala() {
  const c = Offset(500, 650);
  final out = <Path>[_frame()];
  // The heart: a small flower.
  out.add(_circle(c, 30));
  for (var i = 0; i < 8; i++) {
    final a = i * math.pi / 4;
    out.add(_petal(c + _dir(a) * 30, a, 54, 17));
  }
  out.add(_circle(c, 96));
  // Twelve lotus petals, each with a smaller one inside.
  for (var i = 0; i < 12; i++) {
    final a = i * math.pi / 6;
    final base = c + _dir(a) * 96;
    out
      ..add(_lotusPetal(base, a, 104, 46))
      ..add(_lotusPetal(base, a, 64, 22));
  }
  out.add(_circle(c, 206));
  // A band of beads.
  for (var i = 0; i < 32; i++) {
    out.add(_circle(c + _dir(i * math.pi / 16) * 226, 14));
  }
  out.add(_circle(c, 246));
  // Sixteen pointed arches, teardrops between them.
  for (var i = 0; i < 16; i++) {
    final a = i * math.pi / 8;
    out
      ..add(_lotusPetal(c + _dir(a) * 246, a, 96, 40))
      ..add(_lotusPetal(c + _dir(a) * 246, a, 52, 16));
    final b = a + math.pi / 16;
    out.add(_petal(c + _dir(b) * 262, b, 58, 13));
  }
  out.add(_circle(c, 356));
  // Scallops round the edge, each with a dot.
  for (var i = 0; i < 24; i++) {
    final a = i * math.pi / 12;
    out
      ..add(
        Path.combine(
          PathOperation.difference,
          _circle(c + _dir(a) * 356, 42),
          _circle(c, 356),
        ),
      )
      ..add(_circle(c + _dir(a) * 378, 9));
  }
  out.add(_circle(c, 440));
  // Corner rosettes.
  for (final corner in const [
    Offset(30, 30),
    Offset(970, 30),
    Offset(30, 1270),
    Offset(970, 1270),
  ]) {
    for (final r in const [170.0, 120.0, 70.0]) {
      out.add(_inFrame(_circle(corner, r)));
    }
    for (var i = 0; i < 16; i++) {
      final a = i * math.pi / 8;
      out.add(_inFrame(_petal(corner + _dir(a) * 120, a, 46, 16)));
    }
  }
  return out;
}

// ── Rose window ───────────────────────────────────────────────────────────

List<Path> _roseWindow() {
  const c = Offset(500, 650);
  final out = <Path>[_frame()];
  // The middle: six overlapping circles, a flower of light.
  for (var i = 0; i < 6; i++) {
    out.add(_circle(c + _dir(i * math.pi / 3) * 36, 36));
  }
  out.add(_circle(c, 72));
  // Ring of twelve: spokes and a round pane in each.
  for (var i = 0; i < 12; i++) {
    final a = i * math.pi / 6;
    out
      ..add(_line(c + _dir(a) * 72, c + _dir(a) * 152))
      ..add(_circle(c + _dir(a + math.pi / 12) * 112, 24));
  }
  out.add(_circle(c, 152));
  // Lancet arches, pointing outwards.
  for (var i = 0; i < 12; i++) {
    final a = i * math.pi / 6 + math.pi / 12;
    out
      ..add(_lotusPetal(c + _dir(a) * 152, a, 100, 54))
      ..add(_circle(c + _dir(a) * 214, 14));
    final s = a + math.pi / 12;
    out.add(_line(c + _dir(s) * 152, c + _dir(s) * 254));
  }
  out.add(_circle(c, 254));
  // Twenty-four round panes.
  for (var i = 0; i < 24; i++) {
    final a = i * math.pi / 12;
    out
      ..add(_circle(c + _dir(a) * 296, 32))
      ..add(_circle(c + _dir(a) * 296, 14));
  }
  out.add(_circle(c, 338));
  // Trefoils in the outer ring, between spokes.
  for (var i = 0; i < 12; i++) {
    final a = i * math.pi / 6;
    final s = a + math.pi / 12;
    out.add(_line(c + _dir(s) * 338, c + _dir(s) * 440));
    final t = c + _dir(a) * 388;
    for (var k = 0; k < 3; k++) {
      final b = a + k * 2 * math.pi / 3;
      out.add(_circle(t + _dir(b) * 18, 20));
    }
  }
  out.add(_circle(c, 440));
  // Quatrefoils above and below, and in the corners of the stone.
  for (final y in const [120.0, 1180.0]) {
    for (final x in const [140.0, 320.0, 500.0, 680.0, 860.0]) {
      final q = Offset(x, y);
      for (var k = 0; k < 4; k++) {
        out.add(_circle(q + _dir(k * math.pi / 2) * 26, 28));
      }
      out.add(_circle(q, 12));
    }
  }
  for (final y in const [205.0, 1095.0]) {
    out.add(_line(Offset(30, y), Offset(970, y)));
  }
  return out;
}

// ── Moroccan tiles ────────────────────────────────────────────────────────

List<Path> _moroccanTiles() {
  const step = 188.0;
  final out = <Path>[_frame()];
  for (var row = -1; row <= 7; row++) {
    for (var col = -1; col <= 5; col++) {
      final at = Offset(124 + col * step, 86 + row * step);
      // An eight-point star from two squares, a ring of petals inside.
      out
        ..add(_inFrame(_star(at, 78, 78 * 0.765, 8)))
        ..add(_inFrame(_star(at, 56, 30, 8, turn: math.pi / 8)))
        ..add(_inFrame(_circle(at, 18)));
      for (var k = 0; k < 4; k++) {
        final a = k * math.pi / 2 + math.pi / 4;
        final strap = _lineInFrame(at + _dir(a) * 78, at + _dir(a) * 89);
        if (strap != null) out.add(strap);
      }
      // A cross-shaped tile between four stars.
      final mid = at + const Offset(step / 2, step / 2);
      out
        ..add(_inFrame(_star(mid, 44, 18, 4, turn: math.pi / 4)))
        ..add(_inFrame(_circle(mid, 9)));
    }
  }
  return out;
}

// ── Koi pond ──────────────────────────────────────────────────────────────

/// A koi seen from above, its head at [head], swimming along [angle] with
/// a gentle bend.
List<Path> _koi(Offset head, double angle, double length, double bend) {
  final spine = [
    for (var i = 0; i <= 10; i++)
      () {
        final t = i / 10;
        final along = _dir(angle) * (-t * length);
        final side =
            Offset(-math.sin(angle), math.cos(angle)) *
            (math.sin(t * math.pi) * bend * length);
        return head + along + side;
      }(),
  ];
  const widths = [0.0, 0.62, 0.86, 1.0, 0.96, 0.84, 0.68, 0.5, 0.34, 0.2, 0.08];
  final w = length * 0.16;
  final left = <Offset>[], right = <Offset>[];
  for (var i = 0; i <= 10; i++) {
    final a = spine[(i + 1).clamp(0, 10)], b = spine[(i - 1).clamp(0, 10)];
    final d = (a - b) / (a - b).distance;
    final n = Offset(-d.dy, d.dx);
    left.add(spine[i] + n * w * widths[i]);
    right.add(spine[i] - n * w * widths[i]);
  }
  final body = _blob([...left, ...right.reversed.skip(1).take(9)]);
  final tailRoot = spine[10];
  final tailDir = (spine[10] - spine[8]).direction;
  final fins = [
    _petal(tailRoot, tailDir + 0.45, length * 0.3, length * 0.07),
    _petal(tailRoot, tailDir - 0.45, length * 0.3, length * 0.07),
    _petal(
      left[3],
      (left[3] - spine[3]).direction + 0.5,
      length * 0.2,
      length * 0.05,
    ),
    _petal(
      right[3],
      (right[3] - spine[3]).direction - 0.5,
      length * 0.2,
      length * 0.05,
    ),
  ];
  // Patches and a row of scales, all kept on the body.
  final marks = [
    _blob([
      for (var k = 0; k < 6; k++)
        spine[3] + _dir(k * math.pi / 3) * (w * (0.5 + 0.2 * (k % 2))),
    ]),
    _blob([
      for (var k = 0; k < 6; k++)
        spine[6] + _dir(k * math.pi / 3 + 0.4) * (w * (0.42 + 0.18 * (k % 2))),
    ]),
    for (var i = 4; i <= 8; i += 2) _circle(spine[i], w * widths[i] * 0.42),
  ].map((m) => Path.combine(PathOperation.intersect, m, body));
  final eyes = [
    for (final s in const [1.0, -1.0])
      _circle(
        spine[1] + Offset(-math.sin(angle), math.cos(angle)) * (w * 0.4 * s),
        length * 0.018,
      ),
  ];
  return [...fins, body, ...marks, ...eyes];
}

/// A lily pad: a disc with a notch, and its veins.
List<Path> _lilyPad(Offset c, double r, double notch) {
  final pad = Path.combine(
    PathOperation.difference,
    _circle(c, r),
    _poly([
      c,
      c + _dir(notch - 0.22) * (r * 1.2),
      c + _dir(notch + 0.22) * (r * 1.2),
    ]),
  );
  return [
    pad,
    for (var k = 1; k < 6; k++)
      _line(c, c + _dir(notch + k * math.pi / 3) * (r - 8)),
  ];
}

List<Path> _koiPond() {
  const c = Offset(500, 650);
  final out = <Path>[_frame()];
  // Rings spreading out from the middle, where the three fish circle.
  for (final r in const [90.0, 150.0, 430.0]) {
    out.add(_inFrame(_circle(c, r)));
  }
  // Lily pads round the edge, a lotus flowering on the biggest.
  for (final (at, r, notch) in const [
    (Offset(160, 1130), 115.0, -0.7),
    (Offset(850, 1120), 95.0, -2.3),
    (Offset(870, 190), 100.0, 2.4),
    (Offset(150, 190), 85.0, 0.8),
    (Offset(500, 1190), 60.0, -1.6),
    (Offset(500, 110), 55.0, 1.6),
    (Offset(905, 650), 60.0, 3.1),
    (Offset(95, 650), 60.0, 0.0),
  ]) {
    out.addAll(_lilyPad(at, r, notch).map((p) => p));
  }
  for (final (at, size) in const [
    (Offset(165, 1125), 64.0),
    (Offset(865, 195), 54.0),
  ]) {
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      out.add(_lotusPetal(at + _dir(a) * 8, a, size, size * 0.38));
    }
    out.add(_circle(at, size * 0.24));
  }
  // Three koi chasing each other round the pond.
  for (var k = 0; k < 3; k++) {
    final phi = -math.pi / 2 + k * 2 * math.pi / 3;
    final head = c + _dir(phi) * 300;
    out.addAll(_koi(head, phi + math.pi / 2, 330, -0.1).map(_inFrame));
  }
  return out;
}

// ── Low-poly peaks ────────────────────────────────────────────────────────

/// A mountain range cut into triangles: from its ridge (x, height) down to
/// [base] in [rows] bands. Returns its triangles and its outline.
(List<Path>, Path) _lowPolyRange(
  List<Offset> ridge,
  double base,
  int rows,
  int salt,
) {
  double jitter(int i, int j) {
    final v = math.sin(i * 12.9898 + j * 78.233 + salt * 3.1) * 43758.5453;
    return v - v.floorToDouble() - 0.5;
  }

  final grid = <List<Offset>>[];
  for (var j = 0; j <= rows; j++) {
    final t = j / rows;
    grid.add([
      for (var i = 0; i < ridge.length; i++)
        Offset(
          ridge[i].dx +
              (j == 0 || j == rows || i == 0 || i == ridge.length - 1
                  ? 0
                  : jitter(i, j) * 46),
          ridge[i].dy + (base - ridge[i].dy) * t,
        ),
    ]);
  }
  final tris = <Path>[];
  for (var j = 0; j < rows; j++) {
    for (var i = 0; i < ridge.length - 1; i++) {
      final a = grid[j][i], b = grid[j][i + 1];
      final c = grid[j + 1][i], d = grid[j + 1][i + 1];
      if ((i + j).isEven) {
        tris
          ..add(_poly([a, b, d]))
          ..add(_poly([a, d, c]));
      } else {
        tris
          ..add(_poly([a, b, c]))
          ..add(_poly([b, d, c]));
      }
    }
  }
  final outline = _poly([
    ...ridge,
    Offset(ridge.last.dx, base),
    Offset(ridge.first.dx, base),
  ]);
  return (tris, outline);
}

List<Path> _lowPolyPeaks() {
  final out = <Path>[_frame()];
  // The sun and its rays.
  const sun = Offset(700, 260);
  out.add(_circle(sun, 84));
  out.add(_circle(sun, 52));
  for (var i = 0; i < 16; i++) {
    final a = i * math.pi / 8;
    out.add(
      _inFrame(
        _poly([
          sun + _dir(a - 0.08) * 108,
          sun + _dir(a) * (i.isEven ? 230 : 180),
          sun + _dir(a + 0.08) * 108,
        ]),
      ),
    );
  }
  final (front, frontEdge) = _lowPolyRange(
    const [
      Offset(30, 760),
      Offset(150, 640),
      Offset(270, 700),
      Offset(400, 560),
      Offset(520, 680),
      Offset(640, 620),
      Offset(760, 720),
      Offset(880, 640),
      Offset(970, 700),
    ],
    960,
    3,
    2,
  );
  final (back, _) = _lowPolyRange(
    const [
      Offset(30, 600),
      Offset(140, 470),
      Offset(250, 520),
      Offset(370, 360),
      Offset(500, 470),
      Offset(620, 400),
      Offset(740, 520),
      Offset(860, 430),
      Offset(970, 520),
    ],
    900,
    3,
    7,
  );
  // The far range shows only where the near one doesn't cover it.
  for (final t in back) {
    out.add(Path.combine(PathOperation.difference, t, frontEdge));
  }
  out.addAll(front);
  // The lake, with the mountains' reflections as ripples.
  out.add(_line(const Offset(30, 960), const Offset(970, 960)));
  for (var k = 0; k < 6; k++) {
    final y = 1010.0 + k * 42;
    out.add(
      _curve([
        for (var x = 30.0; x <= 970; x += 47)
          Offset(x, y + math.sin(x / 40 + k) * 7),
      ]),
    );
  }
  // Pines along the near shore.
  for (final (x, h) in const [
    (90.0, 150.0),
    (150.0, 110.0),
    (850.0, 130.0),
    (905.0, 170.0),
  ]) {
    for (var k = 0; k < 3; k++) {
      final top = 960 - h + k * h * 0.28;
      final half = h * (0.18 + k * 0.08);
      out.add(
        _poly([
          Offset(x, top),
          Offset(x + half, top + h * 0.42),
          Offset(x - half, top + h * 0.42),
        ]),
      );
    }
  }
  return out;
}

// ── Art deco fans ─────────────────────────────────────────────────────────

List<Path> _artDecoFans() {
  const r = 118.0;
  final out = <Path>[_frame()];
  // Rows of fans, each half under the row in front of it.
  final rows = <List<Offset>>[];
  for (var row = 0; row < 23; row++) {
    final y = 30 + row * r * 0.5 + r;
    final shift = row.isOdd ? r : 0.0;
    rows.add([for (var x = -r + shift; x <= 970 + r; x += 2 * r) Offset(x, y)]);
  }
  Path fan(Offset c) => Path.combine(
    PathOperation.intersect,
    _circle(c, r),
    Path()..addRect(Rect.fromLTRB(c.dx - r, c.dy - r, c.dx + r, c.dy)),
  );
  for (var row = 0; row < rows.length; row++) {
    var cover = Path();
    if (row + 1 < rows.length) {
      for (final c in rows[row + 1]) {
        cover = Path.combine(PathOperation.union, cover, fan(c));
      }
    }
    for (final c in rows[row]) {
      final shape = Path.combine(PathOperation.difference, fan(c), cover);
      final parts = <Path>[
        shape,
        for (final f in const [0.72, 0.44]) _circle(c, r * f),
        // The ribs, as the edges of six slices.
        for (var k = 0; k < 6; k++)
          _poly([
            c,
            c + _dir(math.pi + k * math.pi / 6) * (r * 1.1),
            c + _dir(math.pi + (k + 1) * math.pi / 6) * (r * 1.1),
          ]),
      ];
      for (final p in parts) {
        out.add(_inFrame(Path.combine(PathOperation.intersect, p, shape)));
      }
    }
  }
  return out;
}

// ── City at night ─────────────────────────────────────────────────────────

/// A tower of [w] by [h] standing on [base] at [x], its roof [roof] (0
/// flat, 1 pointed, 2 stepped), with windows.
(Path, List<Path>) _tower(double x, double base, double w, double h, int roof) {
  final top = base - h;
  var outline = Path()..addRect(Rect.fromLTRB(x, top, x + w, base));
  switch (roof) {
    case 1:
      outline = Path.combine(
        PathOperation.union,
        outline,
        _poly([
          Offset(x, top),
          Offset(x + w / 2, top - w * 0.7),
          Offset(x + w, top),
        ]),
      );
    case 2:
      outline = Path.combine(
        PathOperation.union,
        outline,
        Path()
          ..addRect(Rect.fromLTRB(x + w * 0.15, top - 40, x + w * 0.85, top))
          ..addRect(
            Rect.fromLTRB(x + w * 0.32, top - 80, x + w * 0.68, top - 40),
          ),
      );
  }
  final windows = <Path>[];
  const ww = 30.0, wh = 40.0, gap = 22.0;
  final cols = ((w - gap) / (ww + gap)).floor();
  final left = x + (w - (cols * (ww + gap) - gap)) / 2;
  for (var y = top + 30; y + wh < base - 30; y += wh + gap) {
    for (var i = 0; i < cols; i++) {
      windows.add(_rrect(Rect.fromLTWH(left + i * (ww + gap), y, ww, wh), 5));
    }
  }
  return (outline, [outline, ...windows]);
}

List<Path> _cityAtNight() {
  final out = <Path>[_frame()];
  // The moon, its craters, and stars.
  const moon = Offset(790, 190);
  out
    ..add(_circle(moon, 80))
    ..add(_circle(moon + const Offset(-22, -18), 18))
    ..add(_circle(moon + const Offset(28, 14), 13))
    ..add(_circle(moon + const Offset(-6, 36), 10));
  for (final (x, y, s) in const [
    (120.0, 120.0, 30.0),
    (300.0, 200.0, 22.0),
    (470.0, 110.0, 26.0),
    (610.0, 260.0, 18.0),
    (200.0, 330.0, 18.0),
    (900.0, 370.0, 22.0),
  ]) {
    out.add(_star(Offset(x, y), s, s * 0.35, 4));
  }
  const base = 1000.0;
  // The far row, then the near row in front of it.
  final far = [
    _tower(40, base, 150, 520, 2),
    _tower(230, base, 130, 610, 1),
    _tower(420, base, 170, 470, 0),
    _tower(640, base, 140, 560, 2),
    _tower(830, base, 140, 430, 1),
  ];
  final near = [
    _tower(110, base, 160, 330, 0),
    _tower(330, base, 140, 400, 1),
    _tower(530, base, 150, 290, 2),
    _tower(740, base, 150, 360, 0),
  ];
  var front = Path();
  for (final (outline, _) in near) {
    front = Path.combine(PathOperation.union, front, outline);
  }
  for (final (_, parts) in far) {
    for (final p in parts) {
      out.add(_inFrame(Path.combine(PathOperation.difference, p, front)));
    }
  }
  for (final (_, parts) in near) {
    out.addAll(parts.map(_inFrame));
  }
  // The river: the lights on the water.
  out.add(_line(const Offset(30, base), const Offset(970, base)));
  for (var k = 0; k < 5; k++) {
    final y = base + 50 + k * 48;
    for (var x = 60.0 + (k.isOdd ? 50 : 0); x < 940; x += 170) {
      out.add(_inFrame(_rrect(Rect.fromLTWH(x, y, 90, 18), 9)));
    }
  }
  return out;
}

// ── Peacock feathers ──────────────────────────────────────────────────────

/// One feather from [root] along [angle], [length] long: its shaft, its
/// vane, the eye near its tip, and a few barbs.
List<Path> _feather(Offset root, double angle, double length) {
  final d = _dir(angle);
  final n = Offset(-d.dy, d.dx);
  final tip = root + d * length;
  final start = root + d * (length * 0.38);
  final widest = length * 0.105;
  final vane = _blob([
    start,
    start + d * (length * 0.18) + n * (widest * 0.6),
    root + d * (length * 0.72) + n * widest,
    root + d * (length * 0.93) + n * (widest * 0.55),
    tip,
    root + d * (length * 0.93) - n * (widest * 0.55),
    root + d * (length * 0.72) - n * widest,
    start + d * (length * 0.18) - n * (widest * 0.6),
  ]);
  final eye = root + d * (length * 0.78);
  // The eye's ovals, drawn upright about the eye, then turned to lie
  // along the feather (upright is along it when it points straight up).
  final turn = _turnAbout(eye, angle + math.pi / 2);
  final out = <Path>[
    _line(root, start),
    vane,
    for (final (lift, w, h) in [
      (0.0, 1.3, 1.65),
      (0.08, 0.82, 1.05),
      (0.14, 0.38, 0.48),
    ])
      _oval(
        eye - Offset(0, widest * lift),
        widest * w,
        widest * h,
      ).transform(turn),
  ];
  // Barbs from the shaft, short enough to stay inside the vane.
  for (var k = 1; k <= 3; k++) {
    final at = root + d * (length * (0.44 + k * 0.06));
    for (final s in const [1.0, -1.0]) {
      out.add(_line(at, at + d * (widest * 0.25) + n * (widest * 0.42 * s)));
    }
  }
  return out;
}

/// A matrix turning by [radians] about [c] (column-major 4x4).
Float64List _turnAbout(Offset c, double radians) {
  final cos = math.cos(radians), sin = math.sin(radians);
  return Float64List.fromList([
    cos, sin, 0, 0, //
    -sin, cos, 0, 0, //
    0, 0, 1, 0, //
    c.dx - cos * c.dx + sin * c.dy, c.dy - sin * c.dx - cos * c.dy, 0, 1,
  ]);
}

List<Path> _peacock() {
  final out = <Path>[_frame()];
  const root = Offset(500, 1180);
  // Nine feathers fanned out, each as long as the page allows.
  for (var i = 0; i < 9; i++) {
    final angle = -math.pi / 2 + (i - 4) * 0.205;
    final d = _dir(angle);
    final toTop = (root.dy - 60) / -d.dy;
    final toSide = d.dx.abs() < 0.01
        ? double.infinity
        : (d.dx > 0 ? 940 - root.dx : root.dx - 60) / d.dx.abs();
    final length = math.min(toTop, toSide) * (i.isEven ? 0.97 : 0.8);
    out.addAll(_feather(root, angle, length));
  }
  // A scalloped medallion over where they meet.
  out.add(
    _inFrame(
      Path.combine(
        PathOperation.intersect,
        _circle(root, 150),
        Path()..addRect(const Rect.fromLTRB(30, 1000, 970, 1270)),
      ),
    ),
  );
  for (var i = 0; i < 9; i++) {
    final a = math.pi + (i + 0.5) * math.pi / 9;
    out
      ..add(_petal(root + _dir(a) * 60, a, 72, 20))
      ..add(_circle(root + _dir(a) * 150, 14));
  }
  out.add(_circle(root, 50));
  return out;
}
