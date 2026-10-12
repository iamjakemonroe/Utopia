// The Dragon Coil frame close up through a breath of fire.
// Renders test/tool/goldens/dragon_coil_big.png.
// Run: flutter test --update-goldens test/tool/dragon_coil_big_sheet_test.dart
@Tags(['sheet'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/auras/presentation/aura_frame.dart';

void main() {
  testWidgets('dragon_coil_big', (tester) async {
    const times = [0.4, 1.2, 2.1, 4.5];
    const r = 200.0;
    tester.view.physicalSize = const Size(4 * 620, 900);
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
                    height: 900,
                    child: Align(
                      alignment: const Alignment(0, 0.45),
                      child: CustomPaint(
                        painter: AuraPainter(
                          'dragon',
                          ValueNotifier(t),
                          front: false,
                        ),
                        foregroundPainter: AuraPainter(
                          'dragon',
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
      matchesGoldenFile('goldens/dragon_coil_big.png'),
    );
  });
}
