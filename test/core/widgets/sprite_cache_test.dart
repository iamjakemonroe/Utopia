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
    // (A frame is a 60th of a second on the cache's own clock: if the four
    // happen to straddle the start of the next one, that one makes one
    // more. Never all four.)
    expect(cache.length, inInclusiveRange(1, 2));
    expect([for (final s in spies) s.drawn], [1, 1, 1, 1]);
    cache.clear();
  });

  group('where making pixels reads back (CanvasKit: Safari, iPhones)', () {
    setUp(() => SpriteCache.debugReadsBack = true);
    tearDown(() {
      SpriteCache.debugReadsBack = null;
      SpriteCache.debugFailPixels = false;
    });

    void dot(SpriteCache cache, String key, _Spy spy, {double x = 0}) =>
        cache.draw(
          Canvas(ui.PictureRecorder()),
          key,
          bounds: const Rect.fromLTRB(-11, -11, 11, 11),
          dpr: 3,
          at: Offset(x, 20),
          paint: spy.paint,
        );

    test('pixels while they fit in half the budget', () {
      final cache = SpriteCache(maxBytes: 2 * 66 * 66 * 4 + 100);
      final spy = _Spy();
      dot(cache, 'dot', spy);
      expect(cache.bytes, 66 * 66 * 4);
      cache.clear();
    });

    test('past half the budget, pictures: shapes still built once', () {
      final cache = SpriteCache(maxBytes: 2 * 66 * 66 * 4 + 100);
      final a = _Spy();
      final b = _Spy();
      for (var i = 0; i < 4; i++) {
        dot(cache, 'a', a, x: i * 3.1);
        dot(cache, 'b', b, x: i * 3.1);
      }
      expect(a.drawn, 1);
      expect(b.drawn, 1, reason: 'kept as a picture, not drawn each time');
      expect(
        cache.bytes,
        lessThan(2 * 66 * 66 * 4),
        reason: 'b holds no pixels',
      );
      cache.clear();
    });

    test('pixels that fail become a picture, not a try every frame', () {
      SpriteCache.debugFailPixels = true;
      final cache = SpriteCache();
      final spy = _Spy();
      for (var i = 0; i < 5; i++) {
        dot(cache, 'dot', spy);
      }
      expect(spy.drawn, 1);
      SpriteCache.debugFailPixels = false;
      cache.clear();
    });

    test(
      'a picture looks exactly as drawn directly, moved and turned',
      () async {
        void shape(Canvas canvas) {
          canvas.drawPath(
            Path()
              ..moveTo(-9, -4)
              ..cubicTo(-3, -12, 8, -6, 9, 3)
              ..lineTo(-2, 9)
              ..close(),
            Paint()..color = const Color(0xFF5B2DD8),
          );
          canvas.drawCircle(
            const Offset(3, -2),
            3.3,
            Paint()..color = Colors.amber,
          );
        }

        Future<List<int>> render(void Function(Canvas) draw) async {
          final recorder = ui.PictureRecorder();
          draw(Canvas(recorder));
          final image = await recorder.endRecording().toImage(64, 64);
          final data = await image.toByteData();
          return data!.buffer.asUint8List().toList();
        }

        // No room for pixels at all: a picture.
        final cache = SpriteCache(maxBytes: 100);
        const at = Offset(31.37, 27.81);
        const angle = 0.61;
        final direct = await render((canvas) {
          canvas.save();
          canvas.translate(at.dx, at.dy);
          canvas.rotate(angle);
          shape(canvas);
          canvas.restore();
        });
        for (var i = 0; i < 2; i++) {
          final cached = await render(
            (canvas) => cache.draw(
              canvas,
              'shape',
              bounds: const Rect.fromLTRB(-13, -13, 13, 13),
              dpr: 2,
              at: at,
              angle: angle,
              paint: shape,
            ),
          );
          expect(cached, direct, reason: i == 0 ? 'made' : 'kept');
        }
        cache.clear();
      },
    );
  });
}
