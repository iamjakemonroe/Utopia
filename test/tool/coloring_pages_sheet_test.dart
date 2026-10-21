// Every coloring page's outlines, for checking the art. Renders
// test/tool/goldens/coloring_pages.png.
// Run: flutter test --run-skipped --update-goldens test/tool/coloring_pages_sheet_test.dart
@Tags(['sheet'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/doodle_studio/domain/art_doc.dart';
import 'package:utopia/features/doodle_studio/domain/coloring_pages.dart';

class _Sheet extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE9E3D5),
    );
    const cell = Size(500, 650);
    for (var i = 0; i < kColoringPages.length; i++) {
      final at = Offset((i % 4) * cell.width, (i ~/ 4) * cell.height);
      canvas.save();
      canvas.translate(at.dx + 10, at.dy + 10);
      canvas.scale((cell.width - 20) / kPageSize.width);
      canvas.drawRect(
        Offset.zero & kPageSize,
        Paint()..color = const Color(0xFFFFFDF7),
      );
      ColoringPage.paintLines(
        canvas,
        kColoringPages[i].draw(),
        const Color(0xFF1F1E1B),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void main() {
  testWidgets('coloring pages', (tester) async {
    tester.view.physicalSize = const Size(2000, 650.0 * 4);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('sheet'),
        child: CustomPaint(painter: _Sheet(), size: const Size(2000, 650.0 * 4)),
      ),
    );
    await expectLater(
      find.byKey(const ValueKey('sheet')),
      matchesGoldenFile('goldens/coloring_pages.png'),
    );
  });
}
