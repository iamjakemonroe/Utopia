// Renders auras at a few moments into test/tool/goldens/auras_new.png.
// Run: flutter test --update-goldens test/tool/aura_preview_test.dart
@Tags(['sheet'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/auras/presentation/aura_frame.dart';

void main() {
  testWidgets('new auras', (tester) async {
    const ids = ['demon', 'zombie', 'flame', 'dragon'];
    const times = [0.4, 2.0, 4.6, 8.0];
    const r = 80.0;
    tester.view.physicalSize = Size(4 * 300, 360.0 * ids.length);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: const ValueKey('sheet'),
          child: Container(
            color: const Color(0xFF1E1638),
            child: Column(
              children: [
                for (final id in ids)
                  Row(
                    children: [
                      for (final t in times)
                        SizedBox(
                          width: 300,
                          height: 360,
                          child: Center(
                            child: CustomPaint(
                              painter: AuraPainter(
                                id,
                                ValueNotifier(t),
                                front: false,
                              ),
                              foregroundPainter: AuraPainter(
                                id,
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
              ],
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byKey(const ValueKey('sheet')),
      matchesGoldenFile('goldens/auras_new.png'),
    );
  });
}
