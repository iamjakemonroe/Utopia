// Every coin pack's picture, smallest to biggest, at three times card size.
// Renders test/tool/goldens/coin_packs.png.
// Run: flutter test --update-goldens test/tool/coin_packs_sheet_test.dart
@Tags(['sheet'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/store/presentation/coin_pack_art.dart';

void main() {
  testWidgets('coin packs', (tester) async {
    const w = 124.0 * 3;
    const h = 116.0 * 3;
    tester.view.physicalSize = const Size(4 * w, 2 * h);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: const ValueKey('sheet'),
          child: Container(
            color: const Color(0xFF1E1638),
            child: Wrap(
              children: [
                for (var tier = 0; tier < 8; tier++)
                  SizedBox(
                    width: w,
                    height: h,
                    child: CustomPaint(
                      painter: CoinPackArtPainter(tier: tier, t: 2.4),
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
      matchesGoldenFile('goldens/coin_packs.png'),
    );
  });
}
