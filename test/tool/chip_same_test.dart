// Chip as pixels, in every mood at a few moments: made before a change to
// how he's built, then compared after it, so a speed-up provably changes
// nothing on screen. Run:
// flutter test --run-skipped [--update-goldens] test/tool/chip_same_test.dart
@Tags(['sheet'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/theme/app_text_styles.dart';
import 'package:utopia/core/widgets/coin_buddy.dart';

void main() {
  setUpAll(AppTextStyles.preloadFonts);
  setUp(() => CoinBuddy.debugSeed = 1.5);
  tearDown(() => CoinBuddy.debugSeed = null);

  for (final ms in const [0, 900, 3100]) {
    testWidgets('Chip at $ms ms', (tester) async {
      tester.view.physicalSize = const Size(720, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: ColoredBox(
            color: const Color(0xFF2A1B5C),
            child: Wrap(
              children: [
                for (final mood in BuddyMood.values.take(8))
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: CoinBuddy(mood: mood, size: 120),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(Duration(milliseconds: ms));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/chip_$ms.png'),
      );
    });
  }
}
