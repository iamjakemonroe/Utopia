// The Dojo world with the dragon set complete: the dragon flies free.
// Renders test/tool/goldens/dojo_free_<n>.png at a few moments.
// Run: flutter test --update-goldens --run-skipped test/tool/dojo_free_test.dart
@Tags(['sheet'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/theme/utopia_themes.dart';
import 'package:utopia/core/widgets/dojo_dragon.dart';
import 'package:utopia/core/widgets/utopia_world.dart';

class _Frame {}

void main() {
  testWidgets('dojo, dragon circling a frame', (tester) async {
    final frame = _Frame();
    DojoDragon.claim(frame, const Offset(215, 260), 56, worldSeconds - 20);
    addTearDown(() => DojoDragon.release(frame, worldSeconds));
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: const ValueKey('world'),
          child: Stack(
            children: [
              UtopiaWorld(style: UtopiaThemes.utopiaDojo.world),
              const Positioned(
                left: 159,
                top: 204,
                child: CircleAvatar(
                  radius: 56,
                  backgroundColor: Color(0xFF4DA3FF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await expectLater(
      find.byKey(const ValueKey('world')),
      matchesGoldenFile('goldens/dojo_perch.png'),
    );
  });

  testWidgets('dojo, dragon free', (tester) async {
    DojoDragon.free.value = true;
    addTearDown(() => DojoDragon.free.value = false);
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: const ValueKey('world'),
          child: UtopiaWorld(style: UtopiaThemes.utopiaDojo.world),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await expectLater(
      find.byKey(const ValueKey('world')),
      matchesGoldenFile('goldens/dojo_free.png'),
    );
  });
}
