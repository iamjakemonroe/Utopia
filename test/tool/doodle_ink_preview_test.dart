// Renders Doodle ink strokes (a slow one and a fast one, then the fade)
// into test/tool/goldens/doodle_ink_*.png.
// Run: flutter test --run-skipped --update-goldens test/tool/doodle_ink_preview_test.dart
@Tags(['sheet'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/theme/utopia_themes.dart';
import 'package:utopia/core/widgets/doodle_ink.dart';

void main() {
  testWidgets('doodle ink strokes and fade', (tester) async {
    UtopiaThemes.active = UtopiaThemes.utopiaDoodle;
    addTearDown(() => UtopiaThemes.active = UtopiaThemes.utopiaDark);
    tester.view.physicalSize = const Size(400, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: ValueKey('ink'),
          child: DoodleInk(
            child: SizedBox.expand(child: ColoredBox(color: Color(0xFFF7F3EA))),
          ),
        ),
      ),
    );

    var clock = Duration.zero;
    Future<void> stroke(double y, Duration step) async {
      final g = await tester.startGesture(Offset(40, y));
      // Hold for the pen to touch down, then draw.
      await tester.pump(DoodleInk.hold + const Duration(milliseconds: 40));
      for (var i = 1; i <= 20; i++) {
        clock += step;
        await g.moveTo(
          Offset(40 + i * 16.0, y + (i.isEven ? 10 : -10)),
          timeStamp: clock,
        );
        await tester.pump(step);
      }
      await g.up();
    }

    // A quick swipe draws nothing.
    final swipe = await tester.startGesture(const Offset(40, 60));
    await swipe.moveTo(const Offset(300, 70));
    await swipe.up();
    // Slow, then fast.
    await stroke(140, const Duration(milliseconds: 60));
    await stroke(320, const Duration(milliseconds: 8));
    await tester.pump(const Duration(milliseconds: 100));
    await expectLater(
      find.byKey(const ValueKey('ink')),
      matchesGoldenFile('goldens/doodle_ink_drawn.png'),
    );
    await tester.pump(const Duration(milliseconds: 900));
    await expectLater(
      find.byKey(const ValueKey('ink')),
      matchesGoldenFile('goldens/doodle_ink_fading.png'),
    );
    await tester.pump(const Duration(seconds: 2));
    await expectLater(
      find.byKey(const ValueKey('ink')),
      matchesGoldenFile('goldens/doodle_ink_gone.png'),
    );
  });
}
