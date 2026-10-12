import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/doodle_studio/domain/art_doc.dart';
import 'package:utopia/features/doodle_studio/domain/regions.dart';

StrokeOp _stroke(double x) => StrokeOp(
  tool: ArtTool.pen,
  color: 0xFF112233,
  size: 8,
  points: [x, 10, 4, x + 5, 12, 6],
);

void main() {
  test('undo and redo walk the history; drawing clears redo', () {
    final doc = ArtDoc.blank(ArtKind.sketch);
    doc
      ..add(_stroke(1))
      ..add(_stroke(2));
    expect(doc.undo(), isA<StrokeOp>());
    expect(doc.ops, hasLength(1));
    expect(doc.canRedo, isTrue);
    doc.redoLast();
    expect(doc.ops, hasLength(2));
    doc.undo();
    doc.add(_stroke(3));
    expect(doc.canRedo, isFalse);
    expect(doc.ops, hasLength(2));
  });

  test('saves and loads everything drawn', () {
    final doc = ArtDoc.blank(ArtKind.coloring, pageId: 'mandala')
      ..add(_stroke(1.234))
      ..add(const FillOp(region: 3, color: 0xFFFF0000))
      ..add(const FillOp(region: 3, color: 0xFF00FF00));
    final back = ArtDoc.fromJson(doc.toJson())!;
    expect(back.id, doc.id);
    expect(back.kind, ArtKind.coloring);
    expect(back.pageId, 'mandala');
    expect(back.ops, hasLength(3));
    final s = back.ops.first as StrokeOp;
    expect(s.tool, ArtTool.pen);
    expect(s.points.first, closeTo(1.2, 1e-9));
    // The later fill of a shape wins.
    expect(back.fills, {3: 0xFF00FF00});
  });

  test('damaged entries are skipped, not fatal', () {
    final back = ArtDoc.fromJson({
      'id': 'a',
      'kind': 'sketch',
      'ops': [
        {
          't': 's',
          'tool': 'nope',
          'p': [1, 2, 3],
        },
        {
          't': 's',
          'tool': 'pen',
          'p': [1, 2],
        },
        {'t': '?'},
        {'t': 'f', 'r': 2, 'c': 5},
      ],
    })!;
    expect(back.ops, hasLength(1));
  });

  test('shapes are traced between the lines, and fills color them', () {
    // 9 x 5, with a wall down the middle column: two shapes.
    const w = 9, h = 5;
    final px = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      px[(y * w + 4) * 4 + 3] = 255;
    }
    final map = RegionMap.label(px, w, h);
    expect(map.count, 2);
    final left = map.regionAt(1, 2), right = map.regionAt(7, 2);
    expect(left, isNot(right));
    // A tap right on the line still finds a shape nearby.
    expect(map.regionAt(4, 2), isNonZero);

    final pixels = map.fillPixels({left: 0xFFFF0000});
    int alphaAt(int x, int y) => pixels[(y * w + x) * 4 + 3];
    int redAt(int x, int y) => pixels[(y * w + x) * 4];
    expect(redAt(0, 0), 255);
    expect(alphaAt(8, 0), 0); // the other shape stays clear
    // The fill reaches in under the line.
    expect(alphaAt(4, 0), 255);
  });
}
