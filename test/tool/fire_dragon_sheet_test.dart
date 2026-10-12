// Renders the fire dragon at moments through its breath and wingbeat into
// test/tool/goldens/fire_dragon.png. Run:
// flutter test --run-skipped --update-goldens test/tool/fire_dragon_sheet_test.dart
@Tags(['sheet'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/widgets/fire_dragon.dart';

class _Sheet extends CustomPainter {
  // Breath every 7 s: drawing in to 0.7, blasting to 2.4, resting to 2.9.
  static const times = [0.1, 0.55, 0.95, 1.5, 2.2, 2.6, 4.0, 4.45];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF24120A), Color(0xFF8A4A1C)],
        ).createShader(Offset.zero & size),
    );
    const cols = 2;
    final w = size.width / cols;
    final h = size.height / (times.length / cols);
    for (var i = 0; i < times.length; i++) {
      final cell = Offset((i % cols) * w, (i ~/ cols) * h);
      paintFireDragon(
        canvas,
        cell + Offset(w * 0.42, h * 0.55),
        w * 0.17,
        times[i],
        FireDragonColors.crimson,
      );
      final label = TextPainter(
        text: TextSpan(
          text: 't=${times[i]}',
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, cell + const Offset(10, 10));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void main() {
  testWidgets('fire dragon', (tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('sheet'),
        child: CustomPaint(painter: _Sheet(), size: const Size(1400, 1800)),
      ),
    );
    await expectLater(
      find.byKey(const ValueKey('sheet')),
      matchesGoldenFile('goldens/fire_dragon.png'),
    );
  });
}
