// The winged dragon: flying through a wingbeat, and coiled round a picture
// (the Dragon Coil aura). Renders test/tool/goldens/dragon.png.
// Run: flutter test --update-goldens --run-skipped test/tool/dragon_sheet_test.dart
@Tags(['sheet'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/widgets/western_dragon.dart';

class _Sheet extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF2A160C),
    );
    // A wingbeat, left to right.
    const beats = [0.0, 0.35, 0.75, 1.3];
    for (final (i, t) in beats.indexed) {
      paintDragonFlying(
        canvas,
        Offset(230 + i * 330.0, 260),
        120,
        t,
        DragonColors.crimson,
      );
    }
    // Breathing fire.
    paintDragonFlying(
      canvas,
      const Offset(330, 620),
      150,
      0.9,
      DragonColors.blazing,
      fire: true,
    );
    // Perched on a picture.
    const c = Offset(1000, 820);
    const r = 120.0;
    paintDragonCoiled(canvas, c, r, 3.4, DragonColors.blazing, front: false);
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF4DA3FF));
    paintDragonCoiled(canvas, c, r, 3.4, DragonColors.blazing, front: true);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

void main() {
  testWidgets('dragon sheet', (tester) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('sheet'),
        child: CustomPaint(size: const Size(1400, 1100), painter: _Sheet()),
      ),
    );
    await expectLater(
      find.byKey(const ValueKey('sheet')),
      matchesGoldenFile('goldens/dragon.png'),
    );
  });
}
