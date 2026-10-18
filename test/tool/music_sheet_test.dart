// Renders the Music world plain, with the player's music playing, and with
// the Encore set on, into test/tool/goldens/. Run:
// flutter test --run-skipped --update-goldens test/tool/music_sheet_test.dart
@Tags(['sheet'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/theme/utopia_themes.dart';
import 'package:utopia/core/widgets/utopia_world.dart';
import 'package:utopia/core/widgets/world_sets.dart';

void main() {
  for (final (name, sets) in [
    ('plain', <SetBonus>[]),
    ('live', [WorldSets.musicLive]),
    ('set', [WorldSets.music, WorldSets.musicLive]),
  ]) {
    testWidgets('music $name', (tester) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final set in sets) {
        set.on.value = true;
        set.settle();
      }
      addTearDown(() {
        for (final set in sets) {
          set.on.value = false;
          set.settle();
        }
      });
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: const ValueKey('world'),
            child: FittedBox(
              child: SizedBox(
                width: 430,
                height: 932,
                child: UtopiaWorld(style: UtopiaThemes.utopiaMusic.world),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 3010));
      await expectLater(
        find.byKey(const ValueKey('world')),
        matchesGoldenFile('goldens/music_$name.png'),
      );
    });
  }
}
