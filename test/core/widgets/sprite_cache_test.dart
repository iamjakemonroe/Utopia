import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/widgets/sprite_cache.dart';

/// Counts how often the drawing is drawn, and how it was placed.
class _Spy {
  var drawn = 0;
  void paint(Canvas canvas) {
    drawn++;
    canvas.drawCircle(Offset.zero, 10, Paint()..color = Colors.black);
  }
}

void main() {
  test('a drawing is drawn once, then placed', () {
    final cache = SpriteCache();
    final spy = _Spy();
    for (var i = 0; i < 5; i++) {
      final canvas = Canvas(ui.PictureRecorder());
      cache.draw(
        canvas,
        'dot',
        bounds: const Rect.fromLTRB(-11, -11, 11, 11),
        dpr: 3,
        at: Offset(i * 7.3, 20),
        paint: spy.paint,
      );
    }
    expect(spy.drawn, 1);
    cache.clear();
  });

  test(
    'past its budget, what is still showing stays, and the rest is drawn as is',
    () {
      // Room for one 66x66 drawing at 3x.
      final cache = SpriteCache(maxBytes: 66 * 66 * 4 + 100);
      final a = _Spy();
      final b = _Spy();
      for (var i = 0; i < 3; i++) {
        final canvas = Canvas(ui.PictureRecorder());
        for (final (key, spy) in [('a', a), ('b', b)]) {
          cache.draw(
            canvas,
            key,
            bounds: const Rect.fromLTRB(-11, -11, 11, 11),
            dpr: 3,
            paint: spy.paint,
          );
        }
      }
      expect(a.drawn, 1, reason: 'kept');
      expect(b.drawn, 3, reason: "didn't fit: drawn each time, not kept");
      cache.clear();
    },
  );

  test("a frame's making stops at its budget; the rest are made after", () {
    final cache = SpriteCache(frameBudget: Duration.zero);
    final spies = [for (var i = 0; i < 4; i++) _Spy()];
    final canvas = Canvas(ui.PictureRecorder());
    for (final (i, spy) in spies.indexed) {
      cache.draw(
        canvas,
        i,
        bounds: const Rect.fromLTRB(-11, -11, 11, 11),
        dpr: 3,
        paint: spy.paint,
      );
    }
    // The first is made (and spends the budget); the rest are drawn as is.
    expect(cache.length, 1);
    expect([for (final s in spies) s.drawn], [1, 1, 1, 1]);
    cache.clear();
  });
}
