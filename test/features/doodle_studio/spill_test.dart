import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/doodle_studio/domain/art_doc.dart';
import 'package:utopia/features/doodle_studio/domain/spill.dart';
import 'package:utopia/features/guess_doodle/domain/doodle_shapes.dart';

const _black = 0xFF1F1E1B;
const _red = 0xFFE53935;
const _blue = 0xFF2B59D9;

/// A box drawn with the brush, from (200, 200) to (600, 600).
StrokeOp _box({int color = _black, double size = 5}) => StrokeOp(
  tool: ArtTool.marker,
  color: color,
  size: size,
  points: shapePoints(
    DoodleShape.box,
    const Offset(200, 200),
    const Offset(600, 600),
    size,
  ),
);

SpillGrid _grid(List<ArtOp> ops) {
  final grid = SpillGrid(const Size(1000, 1000));
  ops.forEach(grid.apply);
  return grid;
}

int _at(SpillGrid g, double x, double y) =>
    g.fill[(y / g.cell).floor() * g.cols + (x / g.cell).floor()];

void main() {
  test('poured inside a box, the paint stays in the box', () {
    final g = _grid([_box(), const SpillOp(x: 400, y: 400, color: _red)]);
    expect(_at(g, 400, 400), _red);
    expect(_at(g, 220, 580), _red);
    expect(_at(g, 100, 100), 0, reason: 'outside the box');
    expect(_at(g, 800, 400), 0);
  });

  test('poured outside, it fills around the box but not in it', () {
    final g = _grid([_box(), const SpillOp(x: 50, y: 50, color: _blue)]);
    expect(_at(g, 900, 900), _blue);
    expect(_at(g, 400, 400), 0);
  });

  test('a diagonal line holds paint back too', () {
    final line = StrokeOp(
      tool: ArtTool.marker,
      color: _black,
      size: 5,
      points: shapePoints(
        DoodleShape.line,
        const Offset(0, 1000),
        const Offset(1000, 0),
        5,
      ),
    );
    final g = _grid([line, const SpillOp(x: 100, y: 100, color: _red)]);
    expect(_at(g, 100, 100), _red);
    expect(_at(g, 900, 900), 0, reason: 'the far side of the line');
  });

  test('poured again, a shape takes the new color', () {
    final g = _grid([
      _box(),
      const SpillOp(x: 400, y: 400, color: _red),
      const SpillOp(x: 300, y: 300, color: _blue),
    ]);
    expect(_at(g, 400, 400), _blue);
    expect(_at(g, 100, 100), 0);
  });

  test('poured on a line, nothing happens', () {
    final g = _grid([_box(), const SpillOp(x: 200, y: 400, color: _red)]);
    expect(g.poured, isFalse);
  });

  test('a gap rubbed out of the box lets the paint out', () {
    final gap = StrokeOp(
      tool: ArtTool.eraser,
      color: 0,
      size: 12,
      points: const [600, 380, 12, 600, 420, 12],
    );
    final g = _grid([_box(), gap, const SpillOp(x: 400, y: 400, color: _red)]);
    expect(_at(g, 900, 900), _red);
  });

  test('the paint reaches under the line, so no paper shows at its edge', () {
    final g = _grid([_box(), const SpillOp(x: 400, y: 400, color: _red)]);
    final px = g.rgba();
    // The square on the box's left side, next to the paint.
    final col = (200 / g.cell).floor();
    final row = (400 / g.cell).floor();
    final o = (row * g.cols + col) * 4;
    expect(px[o + 3], 255);
    expect(px[o], 0xE5);
  });

  test('carrying on from a grid matches working it all out again', () {
    final ops = <ArtOp>[
      _box(),
      const SpillOp(x: 400, y: 400, color: _red),
      _box(color: _blue, size: 24),
      const SpillOp(x: 50, y: 50, color: _blue),
    ];
    final once = _grid(ops);
    final bit = _grid(ops.take(2).toList());
    for (final op in ops.skip(2)) {
      bit.apply(op);
    }
    expect(bit.fill, once.fill);
  });

  test('a box keeps square corners; a circle closes', () {
    final box = shapePoints(
      DoodleShape.box,
      const Offset(0, 0),
      const Offset(10, 20),
      5,
    );
    expect(box.length, 9 * 3);
    expect([box[3], box[4]], [10, 0]);
    expect([box[6], box[7]], [10, 0], reason: 'the corner twice');
    final ring = shapePoints(
      DoodleShape.circle,
      const Offset(0, 0),
      const Offset(100, 100),
      5,
    );
    expect(ring[0], closeTo(ring[ring.length - 6], 0.01));
  });

  test('a pour round-trips through its saved form', () {
    const op = SpillOp(x: 412.34, y: 98.76, color: _red);
    final back = ArtOp.fromJson(op.toJson()) as SpillOp;
    expect(back.x, 412.3);
    expect(back.y, 98.8);
    expect(back.color, _red);
    expect(StrokeOp.fromJson(op.toJson()), isNull, reason: 'old apps skip it');
  });
}
