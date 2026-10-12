import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/doodle_studio/domain/coloring_pages.dart';
import 'package:utopia/features/doodle_studio/domain/svg_path.dart';

/// The bounds of the line itself (getBounds counts curve control points).
Rect _bounds(String d) {
  final path = parseSvgPath(d)!;
  var r = Rect.zero;
  var first = true;
  for (final m in path.computeMetrics()) {
    for (var t = 0.0; t <= m.length; t += 0.25) {
      final p = m.getTangentForOffset(t)!.position;
      r = first
          ? Rect.fromPoints(p, p)
          : r.expandToInclude(Rect.fromPoints(p, p));
      first = false;
    }
  }
  return r;
}

void _near(Rect a, Rect b) {
  expect(a.left, closeTo(b.left, 0.5));
  expect(a.top, closeTo(b.top, 0.5));
  expect(a.right, closeTo(b.right, 0.5));
  expect(a.bottom, closeTo(b.bottom, 0.5));
}

void main() {
  test('absolute lines and close', () {
    _near(
      _bounds('M 100 200 L 300 200 L 300 400 Z'),
      const Rect.fromLTRB(100, 200, 300, 400),
    );
  });

  test('relative commands, H and V, and pairs after a move', () {
    _near(
      _bounds('m10,10 h50 v30 h-50 z'),
      const Rect.fromLTRB(10, 10, 60, 40),
    );
    // Extra pairs after M are lines.
    _near(_bounds('M0 0 100 0 100 100'), const Rect.fromLTRB(0, 0, 100, 100));
  });

  test('numbers run together the way SVG allows', () {
    _near(_bounds('M10-20L.5.5L1e2,3'), const Rect.fromLTRB(0.5, -20, 100, 3));
  });

  test('a circle from two arcs, flags squashed together', () {
    _near(
      _bounds('M400 500a100 100 0 1 0 200 0a100 100 0 1,0 -200 0z'),
      const Rect.fromLTRB(400, 400, 600, 600),
    );
    _near(
      _bounds('M400 500a100 100 0 10200 0a100 100 0 10-200 0z'),
      const Rect.fromLTRB(400, 400, 600, 600),
    );
  });

  test('curves, smooth curves and quadratics', () {
    final c = _bounds('M0 0 C 0 100 100 100 100 0 S 200 -100 200 0');
    expect(c.left, closeTo(0, 0.5));
    expect(c.right, closeTo(200, 0.5));
    expect(c.bottom, greaterThan(70));
    expect(c.top, lessThan(-70));
    final q = _bounds('M0 0 Q 50 100 100 0 T 200 0');
    expect(q.bottom, closeTo(50, 0.5));
    expect(q.top, closeTo(-50, 0.5));
  });

  test('stops at nonsense but keeps what came before', () {
    _near(
      _bounds('M0 0 L 10 10 L 20 banana 30'),
      const Rect.fromLTRB(0, 0, 10, 10),
    );
    expect(parseSvgPath('hello'), isNull);
    expect(parseSvgPath(''), isNull);
    expect(parseSvgPath('M 1e999 0 L 5 5'), isNull);
  });

  test('a library page draws its outlines', () {
    final page = ColoringPage.fromSvg(
      id: 'p:test',
      name: 'Test',
      paths: const ['M 0 0 L 10 10', 'nonsense', 'M 5 5 h 20 v 20 z'],
    );
    expect(page.draw(), hasLength(2));
  });
}
