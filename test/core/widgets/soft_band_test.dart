import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/widgets/soft_band.dart';

const _size = Size(390, 300);
const _dpr = 3.0;

Future<Uint8List> _pixels(void Function(Canvas canvas) draw) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(_dpr);
  canvas.drawRect(
    Offset.zero & _size,
    Paint()..color = const Color(0xFF1B1442),
  );
  draw(canvas);
  final image = await recorder.endRecording().toImage(
    (_size.width * _dpr).round(),
    (_size.height * _dpr).round(),
  );
  return (await image.toByteData())!.buffer.asUint8List();
}

void main() {
  test('a soft band looks like the shape it stands for', () async {
    // An aurora ribbon, as the world draws it.
    for (final t in [0.0, 3.7, 11.2]) {
      const steps = 28;
      final lower = <Offset>[];
      final upper = <Offset>[];
      for (var s = 0; s <= steps; s++) {
        final u = s / steps;
        final y =
            80 +
            25 * math.sin(u * 5 + t * 0.25) +
            12 * math.sin(u * 11 - t * 0.4);
        final curtain = 100 * (0.55 + 0.45 * math.sin(u * 7 + t * 0.3));
        lower.add(Offset(_size.width * u, y + 120));
        upper.add(Offset(_size.width * u, y + 120 - curtain));
      }
      final paint = Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 240),
          const Offset(0, 20),
          [const Color(0x8C7CFFB2), const Color(0x007CFFB2)],
        );
      final shape = await _pixels(
        (c) => c.drawPath(
          Path()..addPolygon([...lower, ...upper.reversed], true),
          paint,
        ),
      );
      final band = await _pixels(
        (c) => c.drawVertices(
          softBand(lower, upper, _dpr),
          BlendMode.modulate,
          paint,
        ),
      );
      var worst = 0;
      var off = 0;
      for (var i = 0; i < shape.length; i++) {
        final d = (shape[i] - band[i]).abs();
        if (d > worst) worst = d;
        if (d > 6) off++;
      }
      // The same but for the outermost pixels of its edges, a few levels
      // of 255 apart where a corner turns (a straight fade against the
      // exact share of the pixel covered): less than the ribbon's own
      // drift changes them from one frame to the next.
      expect(worst, lessThanOrEqualTo(20), reason: 'at t=$t');
      expect(off / shape.length, lessThan(0.0005), reason: 'at t=$t');
    }
  });
}
