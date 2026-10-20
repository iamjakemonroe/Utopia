import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'sprite_cache.dart';

/// Utopia drawn in ink on paper: the Doodle world. Everything is a pen
/// line on a warm sheet, and the lines "boil" (redraw with a fresh wobble a
/// few times a second) the way hand-drawn animation does, so the page feels
/// alive while it drifts: clouds, floating islands with a waterfall, a
/// balloon, a paper plane looping, birds and twinkling doodle stars.

const _paper = Color(0xFFF7F3EA);
const _ink = Color(0xFF1C1B19);
const _pencil = Color(0xFF8E8A80);

/// Lines redraw this many times a second.
const _boilRate = 6.0;

/// In a browser, the lines boil through this many drawings, over and
/// over, the way a hand-drawn boil loops (each kept as pixels: see
/// [DoodleScenePainter.dpr]).
const _boilLoop = 4;

double _rand(int i, int salt) {
  final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

/// A puffy shape, the way an illustrator builds a cumulus or a tree's
/// canopy: round lobes overlapping back to front, optionally cut flat
/// along a base line. Built once and reused every frame.
class _Puff {
  _Puff(this.lobes, {this.base});

  /// (centre, radius), back to front.
  final List<(Offset, double)> lobes;

  /// A flat underside at this y (clouds), or none (canopies).
  final double? base;

  late final Path shape = _build();

  /// [shape]'s bounds, worked out once: a browser builds a path again
  /// each frame it's used, and this one is a union of every lobe.
  late final Rect bounds = shape.getBounds();

  /// Points round the silhouette, for redrawing it by hand each boil.
  late final List<List<Offset>> outline = [
    for (final m in shape.computeMetrics())
      [
        for (var d = 0.0; d < m.length; d += 4)
          m.getTangentForOffset(d)!.position,
      ],
  ];

  Path _build() {
    var p = Path();
    for (final (c, r) in lobes) {
      p = Path.combine(
        PathOperation.union,
        p,
        Path()..addOval(Rect.fromCircle(center: c, radius: r)),
      );
    }
    final b = base;
    if (b == null) return p;
    final box = p.getBounds().inflate(4);
    final cut = Path()
      ..moveTo(box.left, box.top)
      ..lineTo(box.right, box.top)
      ..lineTo(box.right, b)
      ..quadraticBezierTo(box.center.dx, b + box.width * 0.03, box.left, b)
      ..close();
    return Path.combine(PathOperation.intersect, p, cut);
  }

  static final _cache = <String, _Puff>{};

  /// A cumulus [w] wide sitting on y = 0: a tall crown of big lobes at the
  /// back, smaller ones crowding along the flat base in front.
  static _Puff cumulus(
    int seed,
    double w,
  ) => _cache.putIfAbsent('cu$seed:${w.round()}', () {
    double j(int k, double amount) => (_rand(seed * 17 + k, 61) - 0.5) * amount;
    final lobes = <(Offset, double)>[
      (
        Offset(w * (-0.06 + j(1, 0.08)), w * (-0.31 + j(2, 0.05))),
        w * (0.26 + j(3, 0.04)),
      ),
      (
        Offset(w * (0.18 + j(4, 0.06)), w * (-0.22 + j(5, 0.05))),
        w * (0.2 + j(6, 0.04)),
      ),
      (
        Offset(w * (-0.29 + j(7, 0.06)), w * (-0.17 + j(8, 0.04))),
        w * (0.18 + j(9, 0.03)),
      ),
      (Offset(w * (0.36 + j(10, 0.04)), w * -0.09), w * (0.13 + j(11, 0.03))),
      (Offset(w * (-0.42 + j(12, 0.04)), w * -0.07), w * (0.12 + j(13, 0.02))),
      (Offset(w * (0.12 + j(14, 0.05)), w * -0.06), w * (0.17 + j(15, 0.03))),
      (Offset(w * (-0.16 + j(16, 0.05)), w * -0.05), w * (0.16 + j(17, 0.03))),
    ];
    return _Puff(lobes, base: 0);
  });

  /// A long, low bank of cloud.
  static _Puff bank(int seed, double w) =>
      _cache.putIfAbsent('bk$seed:${w.round()}', () {
        final lobes = <(Offset, double)>[
          for (var k = 0; k < 4; k++)
            (
              Offset(
                w * (-0.3 + 0.2 * k + (_rand(seed + k, 62) - 0.5) * 0.06),
                -w * 0.1,
              ),
              w * (0.1 + 0.05 * _rand(seed + k, 63)),
            ),
          for (var k = 0; k < 6; k++)
            (
              Offset(w * (-0.45 + 0.18 * k), -w * 0.035),
              w * (0.065 + 0.03 * _rand(seed + k, 64)),
            ),
        ];
        return _Puff(lobes, base: 0);
      });

  /// A tree's canopy, [s] across, centred on the origin.
  static _Puff canopy(int seed, double s) =>
      _cache.putIfAbsent('tr$seed:${s.round()}', () {
        double j(int k) => (_rand(seed * 13 + k, 65) - 0.5) * 0.06;
        return _Puff([
          (Offset(s * (0.02 + j(1)), s * (-0.2 + j(2))), s * 0.3),
          (Offset(s * (-0.24 + j(3)), s * (-0.04 + j(4))), s * 0.24),
          (Offset(s * (0.25 + j(5)), s * (-0.02 + j(6))), s * 0.25),
          (Offset(s * (-0.08 + j(7)), s * (0.12 + j(8))), s * 0.24),
          (Offset(s * (0.16 + j(9)), s * (0.16 + j(10))), s * 0.2),
        ]);
      });
}

/// The sheet itself: paper, faint ruled lines and a little grain. Never
/// moves, so it's painted once.
class DoodleSkyPainter extends CustomPainter {
  const DoodleSkyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFBF8F1), _paper, Color(0xFFF0EBDF)],
        ).createShader(rect),
    );
    // Ruled lines, very faint, like the page of a sketchbook.
    final rule = Paint()
      ..color = const Color(0xFF9DB3C8).withValues(alpha: 0.13)
      ..strokeWidth = 1;
    for (var y = 120.0; y < size.height; y += 34) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rule);
    }
    // Paper grain.
    final grain = Paint();
    for (var i = 0; i < 420; i++) {
      grain.color = _pencil.withValues(alpha: 0.05 + 0.08 * _rand(i, 3));
      canvas.drawCircle(
        Offset(_rand(i, 1) * size.width, _rand(i, 2) * size.height),
        0.4 + 0.8 * _rand(i, 4),
        grain,
      );
    }
    // A soft vignette, like the edges of a page.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 1.05,
          colors: [
            Colors.transparent,
            const Color(0xFF6B5E45).withValues(alpha: 0.08),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant DoodleSkyPainter old) => false;
}

/// Everything drawn on the page, in ink.
class DoodleScenePainter extends CustomPainter {
  DoodleScenePainter(this.clock, {this.dpr}) : super(repaint: clock);

  final ValueListenable<double> clock;

  /// In a browser, the screen's pixels a point: the islands, trees,
  /// clouds, balloon and hills are kept as pixels for each drawing of the
  /// boil (see [SpriteCache]), and only what moves on its own (birds, the
  /// plane, stars, the sun's rays, grass, flowers, water and smoke) is
  /// drawn each frame. Null in the apps, which draw it all each frame.
  final double? dpr;

  late double _t;
  late int _boil;

  Paint _pen(double width, [double alpha = 1]) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = _ink.withValues(alpha: alpha);

  /// A hand-drawn version of the line through [points]: each segment gets
  /// a gentle wobble that changes with the boil.
  Path _wobble(
    List<Offset> points, {
    double amp = 1.4,
    int salt = 0,
    bool close = false,
  }) {
    final path = Path();
    if (points.isEmpty) return path;
    final pts = close ? [...points, points.first] : points;
    path.moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1];
      final b = pts[i];
      final seg = b - a;
      final len = seg.distance;
      final steps = math.max(1, (len / 14).round());
      final n = len == 0 ? Offset.zero : Offset(-seg.dy / len, seg.dx / len);
      for (var s = 1; s <= steps; s++) {
        final p = Offset.lerp(a, b, s / steps)!;
        final j = s == steps
            ? 0.0
            : (_rand(_boil * 31 + salt * 7 + i * 13 + s, 9) - 0.5) * 2 * amp;
        path.lineTo(p.dx + n.dx * j, p.dy + n.dy * j);
      }
    }
    if (close) path.close();
    return path;
  }

  /// Draws [paint]'s drawing of something that, until the boil redraws
  /// it, only moves as a whole: around [at] (or, [absolute], where it is
  /// now), turned [angle], within [bounds] of [at]. In a browser it's kept
  /// as pixels for each [key] and drawing of the boil.
  void _still(
    Canvas canvas,
    Object key,
    Rect bounds,
    void Function(Canvas canvas) paint, {
    Offset at = Offset.zero,
    double angle = 0,
    bool absolute = false,
  }) {
    final dpr = this.dpr;
    if (dpr != null) {
      worldSprites.draw(
        canvas,
        ('doodle', key, _boil),
        bounds: bounds,
        dpr: dpr,
        paint: paint,
        at: at,
        angle: angle,
        absolute: absolute,
      );
    } else if (absolute) {
      paint(canvas);
    } else {
      canvas.save();
      canvas.translate(at.dx, at.dy);
      if (angle != 0) canvas.rotate(angle);
      paint(canvas);
      canvas.restore();
    }
  }

  /// Points around an ellipse, for wobbly circles.
  List<Offset> _ring(
    Offset c,
    double rx,
    double ry, {
    int n = 18,
    double start = 0,
  }) => [
    for (var i = 0; i < n; i++)
      c +
          Offset(
            math.cos(start + i / n * 2 * math.pi) * rx,
            math.sin(start + i / n * 2 * math.pi) * ry,
          ),
  ];

  /// Draws a shape twice with slightly different wobbles, the way a quick
  /// sketch doubles back over its own lines.
  void _sketch(
    Canvas canvas,
    List<Offset> pts,
    double width, {
    bool close = true,
    int salt = 0,
    double alpha = 1,
    Color? fill,
  }) {
    if (fill != null) {
      canvas.drawPath(Path()..addPolygon(pts, true), Paint()..color = fill);
    }
    canvas.drawPath(_wobble(pts, salt: salt, close: close), _pen(width, alpha));
    canvas.drawPath(
      _wobble(pts, salt: salt + 101, close: close, amp: 1.0),
      _pen(width * 0.55, alpha * 0.55),
    );
  }

  /// Diagonal hatching inside [clip].
  void _hatch(
    Canvas canvas,
    Path clip,
    Rect bounds, {
    double gap = 7,
    double alpha = 0.55,
    int salt = 0,
  }) {
    canvas.save();
    canvas.clipPath(clip);
    final pen = _pen(1.1, alpha);
    for (var x = bounds.left - bounds.height; x < bounds.right; x += gap) {
      final j = (_rand(_boil + salt + x.toInt(), 5) - 0.5) * 1.5;
      canvas.drawLine(
        Offset(x + j, bounds.bottom),
        Offset(x + bounds.height + j, bounds.top),
        pen,
      );
    }
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    _t = clock.value;
    _boil = (_t * _boilRate).floor();
    if (dpr != null) _boil %= _boilLoop;
    final w = size.width;
    final h = size.height;

    _sun(canvas, Offset(w * 0.84, h * 0.13), w * 0.085);
    _stars(canvas, size);
    _clouds(canvas, size);
    _birds(canvas, size);
    _island(canvas, Offset(w * 0.22, h * 0.36), w * 0.24, 0, tree: true);
    _island(
      canvas,
      Offset(w * 0.76, h * 0.52),
      w * 0.3,
      1,
      tree: true,
      waterfall: true,
    );
    _island(canvas, Offset(w * 0.34, h * 0.68), w * 0.16, 2);
    _balloon(canvas, size);
    _plane(canvas, size);
    _hills(canvas, size);
  }

  void _sun(Canvas canvas, Offset c, double r) {
    // Rays turning slowly round a smiling sun.
    final spin = _t * 0.15;
    for (var i = 0; i < 12; i++) {
      final a = spin + i * math.pi / 6;
      final d = Offset(math.cos(a), math.sin(a));
      final inner = c + d * r * 1.35;
      final outer = c + d * r * (i.isEven ? 1.95 : 1.7);
      canvas.drawPath(_wobble([inner, outer], amp: 0.8, salt: i), _pen(2.2));
    }
    _still(
      canvas,
      ('sun', r),
      Rect.fromCircle(center: Offset.zero, radius: r + 6),
      at: c,
      absolute: true,
      (canvas) {
        _sketch(canvas, _ring(c, r, r), 2.6, salt: 3, fill: _paper);
        // A face: it's Utopia.
        final eye = _pen(2.4);
        canvas.drawPath(
          _wobble([
            c + Offset(-r * 0.38, -r * 0.18),
            c + Offset(-r * 0.38, -r * 0.02),
          ], amp: 0.3),
          eye,
        );
        canvas.drawPath(
          _wobble([
            c + Offset(r * 0.38, -r * 0.18),
            c + Offset(r * 0.38, -r * 0.02),
          ], amp: 0.3),
          eye,
        );
        canvas.drawPath(
          _wobble(
            [
              for (var i = 0; i <= 6; i++)
                c +
                    Offset(
                      -r * 0.42 + r * 0.84 * i / 6,
                      r * 0.22 + math.sin(i / 6 * math.pi) * r * 0.22,
                    ),
            ],
            amp: 0.5,
            close: false,
          ),
          _pen(2.2),
        );
      },
    );
  }

  void _stars(Canvas canvas, Size size) {
    for (var i = 0; i < 16; i++) {
      final p = Offset(
        _rand(i, 21) * size.width,
        _rand(i, 22) * size.height * 0.62,
      );
      final twinkle = 0.5 + 0.5 * math.sin(_t * (1.2 + _rand(i, 23)) + i);
      final s = (5 + 5 * _rand(i, 24)) * (0.6 + 0.4 * twinkle);
      final pen = _pen(1.6, 0.35 + 0.5 * twinkle);
      if (i % 3 == 0) {
        // An asterisk.
        for (var k = 0; k < 3; k++) {
          final a = k * math.pi / 3;
          final d = Offset(math.cos(a), math.sin(a)) * s;
          canvas.drawLine(p - d, p + d, pen);
        }
      } else {
        // A four-point sparkle.
        final path = Path()
          ..moveTo(p.dx, p.dy - s)
          ..quadraticBezierTo(p.dx, p.dy, p.dx + s, p.dy)
          ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + s)
          ..quadraticBezierTo(p.dx, p.dy, p.dx - s, p.dy)
          ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - s);
        canvas.drawPath(path, pen);
      }
    }
  }

  /// Clouds in pen and ink: a confident outline that's heavier on the
  /// shadow side, the lobes' edges drawn where they overlap, and shading
  /// hatched into their undersides. The sun is up on the right, so the
  /// shadows fall down and to the left. Far clouds are smaller, fainter
  /// and slower.
  void _clouds(Canvas canvas, Size size) {
    // (width, height on the page, speed, ink, a long bank?)
    const specs = [
      (64.0, 0.07, 3.0, 0.5, false),
      (150.0, 0.2, 6.5, 1.0, false),
      (120.0, 0.43, 4.5, 0.62, true),
      (96.0, 0.31, 5.2, 0.8, false),
      (124.0, 0.6, 7.5, 0.9, false),
    ];
    for (final (i, (w, y, speed, alpha, bank)) in specs.indexed) {
      final span = size.width + w * 1.4;
      final x = (_rand(i, 32) * span + _t * speed) % span - w * 0.7;
      final puff = bank ? _Puff.bank(i, w) : _Puff.cumulus(i, w);
      final weight = 1.3 + w / 90;
      _still(
        canvas,
        ('cloud', i, w),
        puff.bounds.inflate(weight * 3 + 4),
        at: Offset(x, size.height * y + math.sin(_t * 0.3 + i) * 3),
        (canvas) =>
            _drawPuff(canvas, puff, weight: weight, alpha: alpha, salt: 40 + i),
      );
    }
  }

  /// Draws a [_Puff] at the origin.
  void _drawPuff(
    Canvas canvas,
    _Puff puff, {
    required double weight,
    double alpha = 1,
    double shade = 1,
    int salt = 0,
  }) {
    final body = Paint()..color = _paper;
    canvas.drawPath(puff.shape, body);
    // All the ink goes on one layer, faded together, so crossing strokes
    // don't darken where they meet.
    final box = puff.bounds.inflate(weight * 3);
    canvas.saveLayer(box, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    canvas.save();
    canvas.clipPath(puff.shape);
    for (final (i, (c, r)) in puff.lobes.indexed) {
      // Back to front: each lobe covers the lines of the ones behind it.
      canvas.drawCircle(c, r, body);
      // A light stroke where it overlaps the lobes behind, drawn only
      // part of the way round, the way a pen suggests it.
      if (i > 0) {
        _taperedArc(canvas, c, r, math.pi * 1.04, math.pi * 0.52, weight * 0.5);
      }
      // Form: arcs following its round in the shadow, lower left.
      for (var k = 1; k <= 3; k++) {
        final jitter = (_rand(_boil + salt * 5 + i * 3 + k, 66) - 0.5) * 0.5;
        _taperedArc(
          canvas,
          c.translate(r * 0.06 * k, -r * 0.05 * k),
          r * (1 - 0.13 * k) + jitter,
          math.pi * (0.4 + 0.06 * k),
          math.pi * (0.6 - 0.12 * k),
          weight * (0.42 - 0.08 * k) * shade,
        );
      }
    }
    // The underside in shadow: a few strokes along the flat base, longest
    // at the bottom.
    final base = puff.base;
    if (base != null) {
      final b = puff.bounds;
      for (var k = 0; k < 4; k++) {
        final y =
            base - 2.5 - k * 3.4 + (_rand(_boil + salt + k, 67) - 0.5) * 0.5;
        final reach = b.width * (0.62 - 0.13 * k);
        final left = b.left + b.width * 0.04 * k;
        canvas.drawPath(
          Path()
            ..moveTo(left, y)
            ..quadraticBezierTo(left + reach / 2, y + 1.2, left + reach, y),
          _pen(weight * 0.28, 0.6 - 0.1 * k),
        );
      }
    }
    canvas.restore();
    _contour(canvas, puff, weight, salt);
    canvas.restore();
  }

  /// A brush-pen outline: an even hairline all the way round, swelling to a
  /// heavy stroke on the shadow side. Redrawn by hand each boil.
  void _contour(Canvas canvas, _Puff puff, double weight, int salt) {
    final path = Path();
    for (final (ci, pts) in puff.outline.indexed) {
      for (var i = 0; i < pts.length; i++) {
        final j = (_rand(_boil * 29 + salt * 3 + ci * 7 + i, 68) - 0.5) * 0.7;
        final p = pts[i] + Offset(j, -j);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
    }
    canvas.drawPath(path, _pen(weight * 0.42));
    final box = path.getBounds().inflate(weight * 3);
    canvas.saveLayer(box, Paint());
    canvas.drawPath(path, Paint()..color = _ink);
    canvas.translate(weight * 0.55, -weight * 0.8);
    canvas.drawPath(
      path,
      Paint()
        ..blendMode = BlendMode.dstOut
        ..color = Colors.black,
    );
    canvas.restore();
  }

  /// An arc that swells in the middle and tapers to fine points, like a
  /// pen pressed harder mid-stroke. One filled shape, so it fades evenly.
  void _taperedArc(
    Canvas canvas,
    Offset c,
    double r,
    double start,
    double sweep,
    double width, [
    double alpha = 1,
  ]) {
    if (alpha <= 0 || width <= 0) return;
    const n = 16;
    final outer = <Offset>[];
    final inner = <Offset>[];
    for (var k = 0; k <= n; k++) {
      final a = start + sweep * k / n;
      final d = Offset(math.cos(a), math.sin(a));
      final half = width * 0.5 * math.sin(math.pi * k / n);
      outer.add(c + d * (r + half));
      inner.add(c + d * (r - half));
    }
    canvas.drawPath(
      Path()..addPolygon([...outer, ...inner.reversed], true),
      Paint()..color = _ink,
    );
  }

  void _birds(Canvas canvas, Size size) {
    for (var i = 0; i < 3; i++) {
      final x =
          (size.width * (0.2 + 0.3 * i) + _t * (14 + i * 3)) %
              (size.width + 60) -
          30;
      final y = size.height * (0.2 + 0.05 * i) + math.sin(_t * 0.8 + i) * 8;
      final flap = math.sin(_t * 6 + i * 2) * 4;
      final s = 7.0 + i;
      canvas.drawPath(
        _wobble(
          [
            Offset(x - s, y - flap),
            Offset(x - s * 0.4, y - s * 0.2),
            Offset(x, y + 2),
            Offset(x + s * 0.4, y - s * 0.2),
            Offset(x + s, y - flap),
          ],
          amp: 0.4,
          salt: 60 + i,
        ),
        _pen(1.8),
      );
    }
  }

  void _island(
    Canvas canvas,
    Offset base,
    double width,
    int seed, {
    bool tree = false,
    bool waterfall = false,
  }) {
    final bob = math.sin(_t * 0.7 + seed * 2.1) * 6;
    final c = base.translate(0, bob);
    final half = width / 2;
    final depth = width * 0.68;
    final tip = c + Offset(-half * 0.08, depth);

    // Roots trailing under the rock, swaying a little.
    for (var k = 0; k < 4; k++) {
      final u = -0.5 + k * 0.3 + (_rand(seed * 5 + k, 81) - 0.5) * 0.1;
      final from = Offset.lerp(
        c + Offset(u * half * 1.6, depth * 0.3),
        tip,
        0.35 + 0.15 * (k % 2),
      )!;
      final len = depth * (0.25 + 0.2 * _rand(seed * 5 + k, 82));
      final sway = math.sin(_t * 1.3 + k + seed) * 3;
      canvas.drawPath(
        _wobble(
          [
            for (var i = 0; i <= 5; i++)
              from +
                  Offset(
                    math.sin(i * 1.4 + k) * 2.5 + sway * i / 5,
                    len * i / 5,
                  ),
          ],
          amp: 0.4,
          salt: 200 + seed * 9 + k,
        ),
        _pen(1.1, 0.7),
      );
    }

    // The rock and its grass top: the same until the boil redraws them.
    _still(
      canvas,
      ('rock', seed, width),
      Rect.fromLTRB(-half - 6, -half * 0.22 - 6, half + 6, depth * 1.1 + 6),
      at: c,
      absolute: true,
      (canvas) {
        // The rock: a craggy cone of broken facets under the grass.
        const outline = [
          (-1.0, 0.0),
          (-0.9, 0.14),
          (-0.8, 0.2),
          (-0.7, 0.36),
          (-0.55, 0.42),
          (-0.46, 0.6),
          (-0.3, 0.68),
          (-0.2, 0.86),
          (0.0, 0.94),
          (0.08, 0.8),
          (0.2, 0.7),
          (0.32, 0.56),
          (0.46, 0.5),
          (0.6, 0.36),
          (0.74, 0.28),
          (0.86, 0.15),
          (1.0, 0.0),
        ];
        final rock = <Offset>[
          for (final (i, (x, y)) in outline.indexed)
            c +
                Offset(
                  x * half,
                  y * depth * (1 + (_rand(seed * 11 + i, 83) - 0.5) * 0.16),
                ),
        ];
        rock[8] = tip;
        final rockPath = Path()..addPolygon(rock, true);
        canvas.drawPath(rockPath, Paint()..color = _paper);
        // Facets: ridges run from the rim down to the rock's corners, and each
        // plane is hatched for how much light it gets: dense on the shadowed
        // left, lighter in the middle, bare stone toward the sun.
        Offset rim(double u) =>
            c +
            Offset(u * half, half * 0.22 * math.sqrt(1 - u * u) + half * 0.04);
        final ridges = [
          (rim(-0.5), rock[6]),
          (rim(-0.05), rock[8]),
          (rim(0.36), rock[11]),
          (rim(0.7), rock[14]),
        ];
        canvas.save();
        canvas.clipPath(rockPath);
        // (gap, ink, how far up the plane the strokes reach, crossed?)
        const planes = [
          (2.6, 0.75, 1.0, true),
          (3.4, 0.6, 1.0, false),
          (5.0, 0.5, 0.55, false),
          (7.5, 0.4, 0.3, false),
        ];
        for (final (band, (gap, ink, reachUp, crossed)) in planes.indexed) {
          final left = band == 0
              ? (
                  c + Offset(-half * 1.2, -half),
                  c + Offset(-half * 1.2, depth * 1.2),
                )
              : ridges[band - 1];
          final right = ridges[band];
          final plane = Path()
            ..addPolygon([
              left.$1.translate(0, -half),
              right.$1.translate(0, -half),
              right.$1,
              right.$2,
              right.$2.translate(0, depth),
              left.$2.translate(0, depth),
              left.$2,
              left.$1,
            ], true);
          canvas.save();
          canvas.clipPath(plane);
          final b = plane.getBounds();
          // Lit planes are only shaded low down, toward the point.
          final cutoff = c.dy + depth * (1 - reachUp);
          void hatch(Offset along, double alpha) {
            final across = Offset(-along.dy, along.dx);
            final reach = b.longestSide * 1.5;
            for (var d = -reach; d < reach; d += gap) {
              final o = b.center + across * d;
              final j =
                  (_rand(_boil + seed * 31 + band * 7 + d.round(), 87) - 0.5) *
                  0.7;
              var p0 = o - along * reach;
              var p1 = o + along * reach;
              if (reachUp < 1) {
                // Clip the stroke to below the cutoff.
                if (p1.dy < cutoff) continue;
                final t = ((cutoff - p0.dy) / (p1.dy - p0.dy)).clamp(0.0, 1.0);
                p0 = Offset.lerp(p0, p1, t)!;
              }
              canvas.drawLine(p0 + across * j, p1, _pen(0.85, alpha));
            }
          }

          hatch(const Offset(0.42, 0.91), ink);
          if (crossed) hatch(const Offset(0.93, -0.36), ink * 0.7);
          canvas.restore();
        }
        // A few cracks across the lit faces.
        for (var k = 0; k < 3; k++) {
          final from =
              c + Offset(half * (0.1 + 0.22 * k), depth * (0.2 + 0.12 * k));
          canvas.drawPath(
            _wobble(
              [
                from,
                from + Offset(half * 0.12, depth * 0.03),
                from + Offset(half * 0.18, depth * 0.09),
              ],
              amp: 0.5,
              salt: 240 + seed * 7 + k,
            ),
            _pen(1.1, 0.7),
          );
        }
        canvas.restore();
        for (final (from, to) in ridges) {
          canvas.drawPath(
            _wobble(
              [from, Offset.lerp(from, to, 0.5)! + const Offset(-2, 0), to],
              amp: 0.6,
              salt: 250 + seed * 5 + from.dx.round(),
            ),
            _pen(1.7, 0.9),
          );
        }
        _sketch(canvas, rock, 2.2, salt: 80 + seed, close: false);

        // The grass top, with the soil showing along its front lip.
        final top = _ring(c, half, half * 0.22, n: 26);
        final lip = <Offset>[
          for (var i = 0; i <= 12; i++)
            c +
                Offset(
                  math.cos(i / 12 * math.pi) * half,
                  math.sin(i / 12 * math.pi) * half * 0.22 + half * 0.07,
                ),
        ];
        canvas.drawPath(
          _wobble(lip, amp: 0.6, salt: 95 + seed, close: false),
          _pen(1.6, 0.85),
        );
        _sketch(canvas, top, 2.4, salt: 90 + seed, fill: _paper);
      },
    );
    // Grass tufts along the front edge.
    final grass = _pen(1.3, 0.8);
    for (var i = 0; i < 11; i++) {
      final gx = c.dx - half * 0.86 + half * 1.72 * i / 10;
      final gy =
          c.dy +
          half *
              0.21 *
              math.sqrt(1 - math.pow((gx - c.dx) / half, 2).clamp(0, 1));
      final lean = math.sin(_t * 1.6 + i * 0.8 + seed) * 1.2;
      canvas.drawLine(Offset(gx, gy), Offset(gx - 2 + lean, gy - 6), grass);
      canvas.drawLine(
        Offset(gx + 1.5, gy),
        Offset(gx + 3.5 + lean, gy - 4.5),
        grass,
      );
    }
    if (tree) {
      _tree(
        canvas,
        c.translate(-half * 0.25, -half * 0.06),
        width * 0.36,
        seed,
      );
    }
    if (waterfall) {
      _waterfall(
        canvas,
        c.translate(half * 0.55, half * 0.12),
        depth * 1.3,
        seed,
      );
      // A tiny cottage on the big island.
      _cottage(canvas, c.translate(half * 0.2, -half * 0.06), width * 0.16);
    }
  }

  void _tree(Canvas canvas, Offset foot, double size, int seed) {
    final sway = math.sin(_t * 1.1 + seed) * 0.03;
    final crown = _Puff.canopy(seed, size);
    final bounds =
        Rect.fromLTRB(
          -size * 0.13 - 6,
          -size * 0.66 - 6,
          size * 0.13 + 6,
          6,
        ).expandToInclude(
          crown.bounds.shift(Offset(0, -size * 0.82)).inflate(2 * 3 + 4),
        );
    _still(
      canvas,
      ('tree', seed, size),
      bounds,
      at: foot,
      angle: sway,
      (canvas) => _treeShape(canvas, crown, size, seed),
    );
  }

  /// A tree standing on the origin.
  void _treeShape(Canvas canvas, _Puff crown, double size, int seed) {
    // The trunk, wider at the foot, forking into two branches.
    final trunk = [
      Offset(-size * 0.05, 0),
      Offset(-size * 0.03, -size * 0.42),
      Offset(-size * 0.12, -size * 0.62),
      Offset(-size * 0.09, -size * 0.64),
      Offset(0, -size * 0.5),
      Offset(size * 0.1, -size * 0.66),
      Offset(size * 0.13, -size * 0.63),
      Offset(size * 0.03, -size * 0.42),
      Offset(size * 0.05, 0),
    ];
    _sketch(canvas, trunk, 1.6, salt: 300 + seed, fill: _paper);
    // Bark: a few strokes down the shadowed left of the trunk.
    for (var k = 0; k < 3; k++) {
      canvas.drawLine(
        Offset(-size * 0.025, -size * (0.06 + 0.12 * k)),
        Offset(-size * 0.02, -size * (0.12 + 0.12 * k)),
        _pen(0.9, 0.6),
      );
    }
    canvas.save();
    canvas.translate(0, -size * 0.82);
    _drawPuff(canvas, crown, weight: 2.0, shade: 1.3, salt: 310 + seed);
    // Leaves: little scallops scattered through the shade.
    for (var k = 0; k < 7; k++) {
      final p = Offset(
        size * (-0.32 + 0.4 * _rand(seed * 3 + k, 85)),
        size * (-0.05 + 0.25 * _rand(seed * 3 + k, 86)),
      );
      canvas.drawArc(
        Rect.fromCenter(center: p, width: size * 0.09, height: size * 0.07),
        0.2,
        math.pi - 0.4,
        false,
        _pen(1.0, 0.6),
      );
    }
    canvas.restore();
  }

  void _waterfall(Canvas canvas, Offset top, double length, int seed) {
    for (var k = 0; k < 4; k++) {
      final x = top.dx + k * 4 - 6;
      final pts = <Offset>[
        for (var i = 0; i <= 10; i++)
          Offset(
            x + math.sin(i * 0.9 + _t * 4 + k) * 1.6,
            top.dy + length * i / 10,
          ),
      ];
      canvas.drawPath(_wobble(pts, amp: 0.4, salt: 120 + k), _pen(1.3, 0.75));
    }
    // A splash of little dashes at the bottom.
    final splash = _pen(1.3, 0.7);
    final bottom = top.translate(0, length);
    for (var i = 0; i < 5; i++) {
      final a = math.pi + (i + 0.5) / 5 * math.pi;
      final d = Offset(math.cos(a), math.sin(a));
      final pulse = 0.6 + 0.4 * math.sin(_t * 5 + i);
      canvas.drawLine(bottom + d * 4, bottom + d * (9 * pulse), splash);
    }
  }

  void _cottage(Canvas canvas, Offset foot, double s) {
    _still(
      canvas,
      ('cottage', s),
      Rect.fromLTRB(-s * 0.65 - 6, -s * 1.25 - 6, s * 0.65 + 6, 6),
      at: foot,
      absolute: true,
      (canvas) => _house(canvas, foot, s),
    );
    // Smoke curling up from the chimney.
    final chimney = foot.translate(s * 0.3, -s * 1.0);
    final smoke = <Offset>[
      for (var i = 0; i <= 8; i++)
        chimney.translate(math.sin(i * 0.9 - _t * 2) * 4, -i * 4.0),
    ];
    canvas.drawPath(_wobble(smoke, amp: 0.4, salt: 143), _pen(1.3, 0.5));
  }

  /// The cottage itself, standing on [foot].
  void _house(Canvas canvas, Offset foot, double s) {
    final body = [
      foot.translate(-s / 2, 0),
      foot.translate(-s / 2, -s * 0.7),
      foot.translate(s / 2, -s * 0.7),
      foot.translate(s / 2, 0),
    ];
    _sketch(canvas, body, 1.8, salt: 140, fill: _paper);
    _sketch(
      canvas,
      [
        foot.translate(-s * 0.65, -s * 0.66),
        foot.translate(0, -s * 1.25),
        foot.translate(s * 0.65, -s * 0.66),
      ],
      1.9,
      salt: 141,
      close: false,
    );
    _sketch(
      canvas,
      [
        foot.translate(-s * 0.12, 0),
        foot.translate(-s * 0.12, -s * 0.35),
        foot.translate(s * 0.12, -s * 0.35),
        foot.translate(s * 0.12, 0),
      ],
      1.4,
      salt: 142,
      close: false,
    );
  }

  void _balloon(Canvas canvas, Size size) {
    final x = size.width * (0.58 + 0.04 * math.sin(_t * 0.18));
    final y = size.height * 0.26 + math.sin(_t * 0.6) * 10;
    final r = size.width * 0.07;
    final c = Offset(x, y);
    _still(
      canvas,
      ('balloon', r),
      Rect.fromLTRB(-r - 6, -r * 1.05 - 6, r + 6, r * 2.15 + 6),
      at: c,
      absolute: true,
      (canvas) => _balloonShape(canvas, c, r),
    );
  }

  /// The balloon around [c], [r] across its envelope.
  void _balloonShape(Canvas canvas, Offset c, double r) {
    final env = <Offset>[
      for (var i = 0; i <= 20; i++)
        c +
            Offset(
              math.sin(i / 20 * 2 * math.pi) * r,
              -math.cos(i / 20 * 2 * math.pi) *
                  r *
                  (i > 5 && i < 15 ? 1.25 : 1),
            ),
    ];
    _sketch(canvas, env, 2.2, salt: 150, fill: _paper);
    // Stripes down the envelope.
    for (final k in const [-0.5, 0.0, 0.5]) {
      canvas.drawPath(
        _wobble(
          [
            c.translate(k * r * 0.9, -r * 0.95),
            c.translate(k * r * 1.1, 0),
            c.translate(k * r * 0.6, r * 1.15),
          ],
          amp: 0.5,
          salt: 151 + (k * 10).round(),
          close: false,
        ),
        _pen(1.3, 0.7),
      );
    }
    final basketTop = c.translate(0, r * 1.75);
    for (final side in const [-1.0, 1.0]) {
      canvas.drawLine(
        c.translate(side * r * 0.55, r * 1.12),
        basketTop.translate(side * r * 0.25, 0),
        _pen(1.2, 0.8),
      );
    }
    final basket = [
      basketTop.translate(-r * 0.3, 0),
      basketTop.translate(r * 0.3, 0),
      basketTop.translate(r * 0.24, r * 0.4),
      basketTop.translate(-r * 0.24, r * 0.4),
    ];
    final basketPath = Path()..addPolygon(basket, true);
    canvas.drawPath(basketPath, Paint()..color = _paper);
    _hatch(
      canvas,
      basketPath,
      basketPath.getBounds(),
      gap: 4,
      alpha: 0.6,
      salt: 9,
    );
    _sketch(canvas, basket, 1.6, salt: 155);
  }

  void _plane(Canvas canvas, Size size) {
    // A paper plane looping lazily across the page, with a dashed trail.
    const period = 14.0;
    Offset at(double time) {
      final k = (time % period) / period;
      final x = -40 + (size.width + 80) * k;
      final y =
          size.height * 0.46 +
          math.sin(k * 2 * math.pi * 1.5) * size.height * 0.05;
      return Offset(x, y);
    }

    final p = at(_t);
    final ahead = at(_t + 0.05);
    final dir = ahead - p;
    final angle = math.atan2(dir.dy, dir.dx);
    final trail = _pen(1.2, 0.45);
    for (var i = 1; i < 14; i++) {
      final a = at(_t - i * 0.12);
      final b = at(_t - i * 0.12 - 0.05);
      if (a.dx > p.dx) break;
      canvas.drawLine(a, b, trail);
    }
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(angle);
    const s = 14.0;
    final body = [
      const Offset(s, 0),
      const Offset(-s, -s * 0.6),
      const Offset(-s * 0.55, 0),
      const Offset(-s, s * 0.55),
    ];
    _sketch(canvas, body, 1.7, salt: 160, fill: _paper);
    canvas.drawLine(
      const Offset(s, 0),
      const Offset(-s * 0.55, 0),
      _pen(1.2, 0.8),
    );
    canvas.restore();
  }

  void _hills(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final top = <Offset>[
      for (var i = 0; i <= 16; i++)
        Offset(
          w * i / 16,
          h * 0.9 - math.sin(i / 16 * math.pi * 1.6 + 0.4) * h * 0.035,
        ),
    ];
    _still(
      canvas,
      ('hills', w, h),
      Rect.fromLTRB(-6, h * 0.86 - 6, w + 6, h + 4),
      absolute: true,
      (canvas) {
        final area = Path()
          ..addPolygon([...top, Offset(w, h + 4), Offset(0, h + 4)], true);
        canvas.drawPath(area, Paint()..color = _paper);
        _hatch(
          canvas,
          area,
          Rect.fromLTRB(0, h * 0.84, w, h),
          gap: 9,
          alpha: 0.18,
          salt: 3,
        );
        canvas.drawPath(_wobble(top, salt: 170, close: false), _pen(2.2));
      },
    );
    // Flowers swaying on the hill.
    for (var i = 0; i < 6; i++) {
      final fx = w * (0.08 + 0.16 * i) + _rand(i, 71) * 14;
      final fy = h * 0.9 - math.sin(fx / w * math.pi * 1.6 + 0.4) * h * 0.035;
      final sway = math.sin(_t * 1.4 + i) * 3;
      final head = Offset(fx + sway, fy - 18 - 6 * _rand(i, 72));
      canvas.drawLine(Offset(fx, fy), head, _pen(1.4));
      for (var k = 0; k < 5; k++) {
        final a = k * 2 * math.pi / 5 + _t * 0.3;
        canvas.drawCircle(
          head + Offset(math.cos(a), math.sin(a)) * 4,
          2.6,
          _pen(1.2),
        );
      }
      canvas.drawCircle(head, 1.6, Paint()..color = _ink);
    }
  }

  @override
  bool shouldRepaint(covariant DoodleScenePainter old) => old.dpr != dpr;
}
