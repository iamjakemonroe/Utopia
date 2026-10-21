import 'dart:math' as math;
import 'dart:ui';

/// Shapes the drawer drags out: a straight line, a box, a circle. Each is
/// sent as an ordinary stroke (points along its outline), so everyone's
/// canvas draws it the way it draws any line.
enum DoodleShape { line, box, circle }

/// [shape] from [a] to [b] (page units), as stroke points: x, y and width
/// [size] for each. A box's corners come twice, so the smoothing that
/// rounds a hand-drawn line leaves them square.
List<double> shapePoints(DoodleShape shape, Offset a, Offset b, double size) {
  final pts = switch (shape) {
    DoodleShape.line => [a, b],
    DoodleShape.box => [
      a,
      Offset(b.dx, a.dy),
      Offset(b.dx, a.dy),
      b,
      b,
      Offset(a.dx, b.dy),
      Offset(a.dx, b.dy),
      a,
      a,
    ],
    DoodleShape.circle => _ring(Rect.fromPoints(a, b)),
  };
  return [
    for (final p in pts) ...[_r(p.dx), _r(p.dy), size],
  ];
}

/// Points round the oval in [box], closed (the first two again, so the
/// smoothing meets itself).
List<Offset> _ring(Rect box) {
  const n = 48;
  final c = box.center;
  final rx = box.width / 2;
  final ry = box.height / 2;
  return [
    for (var i = 0; i <= n + 1; i++)
      Offset(
        c.dx + rx * math.cos(i * 2 * math.pi / n),
        c.dy + ry * math.sin(i * 2 * math.pi / n),
      ),
  ];
}

double _r(double v) => (v * 10).roundToDouble() / 10;
