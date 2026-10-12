// One wingbeat of the flying dragon in eight steps, large, for judging the
// motion. Renders test/tool/goldens/dragon_beat.png.
// Run: flutter test --run-skipped --update-goldens test/tool/dragon_beat_sheet_test.dart
@Tags(['sheet'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/widgets/western_dragon.dart';

class _Beat extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF2A1810),
    );
    for (var i = 0; i < 8; i++) {
      final t = 10 + i / 8 / 0.6;
      final at = Offset(470.0 + (i % 2) * 700, 230.0 + (i ~/ 2) * 330);
      paintDragonFlying(canvas, at, 120, t, DragonColors.crimson);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void main() {
  testWidgets('dragon wingbeat', (tester) async {
    tester.view.physicalSize = const Size(1400, 1340);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('sheet'),
        child: CustomPaint(painter: _Beat(), size: const Size(1400, 1340)),
      ),
    );
    await expectLater(
      find.byKey(const ValueKey('sheet')),
      matchesGoldenFile('goldens/dragon_beat.png'),
    );
  });
}
