// The Inferno frame close up, a moment apart, to see what moves.
// Renders test/tool/goldens/inferno.png.
// Run: flutter test --update-goldens test/tool/inferno_sheet_test.dart
@Tags(['sheet'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/auras/presentation/aura_frame.dart';

void main() {
  testWidgets('inferno', (tester) async {
    const times = [3.0, 3.6, 4.2];
    const r = 200.0;
    tester.view.physicalSize = const Size(3 * 620, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: const ValueKey('sheet'),
          child: Container(
            color: const Color(0xFF1E1638),
            child: Row(
              children: [
                for (final t in times)
                  SizedBox(
                    width: 620,
                    height: 700,
                    child: Center(
                      child: CustomPaint(
                        painter: AuraPainter(
                          'demon',
                          ValueNotifier(t),
                          front: false,
                        ),
                        foregroundPainter: AuraPainter(
                          'demon',
                          ValueNotifier(t),
                          front: true,
                        ),
                        child: Container(
                          width: r * 2,
                          height: r * 2,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF6FA8DC),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byKey(const ValueKey('sheet')),
      matchesGoldenFile('goldens/inferno.png'),
    );
  });
}
