// The Dojo's shadow fighters at moments through their routine, and the
// castle. Renders test/tool/goldens/dojo_art.png.
// Run: flutter test --update-goldens --run-skipped test/tool/dojo_sheet_test.dart
@Tags(['sheet'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/widgets/dojo_art.dart';

class _Sheet extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFB9662E),
    );
    const times = [0.4, 1.2, 1.5, 3.3, 3.55, 5.3];
    for (final (i, t) in times.indexed) {
      final col = i % 3;
      final row = i ~/ 3;
      paintShadowDuel(
        canvas,
        200 + col * 400.0,
        320 + row * 330.0,
        230,
        t,
        ink: const Color(0xFF0B0604),
        rim: const Color(0xFFFF8A3D),
        sash: const Color(0xFFC8321E),
      );
    }
    paintCastle(
      canvas,
      const Offset(900, 1150),
      420,
      1,
      wall: const Color(0xFF2A160C),
      roof: const Color(0xFF160B06),
      stone: const Color(0xFF3E2618),
      light: const Color(0xFFFFB45A),
      rim: const Color(0xFFFF9A4A),
    );
    paintTurret(
      canvas,
      const Offset(420, 1150),
      150,
      1,
      wall: const Color(0xFF2A160C),
      roof: const Color(0xFF160B06),
      stone: const Color(0xFF3E2618),
      light: const Color(0xFFFFB45A),
      rim: const Color(0xFFFF9A4A),
    );
    paintBanner(
      canvas,
      const Offset(160, 1150),
      260,
      1,
      const Color(0xFFC8321E),
      const Color(0xFFFFE2B0),
      const Color(0xFF160B06),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

void main() {
  testWidgets('dojo art sheet', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('sheet'),
        child: CustomPaint(size: const Size(1200, 1200), painter: _Sheet()),
      ),
    );
    await expectLater(
      find.byKey(const ValueKey('sheet')),
      matchesGoldenFile('goldens/dojo_art.png'),
    );
  });
}
