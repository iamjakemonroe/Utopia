// Renders Heaven and Hell, plain and with their sets on, into
// test/tool/goldens/. Run:
// flutter test --run-skipped --update-goldens test/tool/heaven_hell_sheet_test.dart
@Tags(['sheet'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/theme/utopia_themes.dart';
import 'package:utopia/core/widgets/utopia_world.dart';
import 'package:utopia/core/widgets/world_sets.dart';

void main() {
  for (final (name, theme, set) in [
    ('heaven', UtopiaThemes.utopiaHeaven, WorldSets.heaven),
    ('hell', UtopiaThemes.utopiaHell, WorldSets.hell),
  ]) {
    for (final on in [false, true]) {
      testWidgets('$name set=$on', (tester) async {
        tester.view.physicalSize = const Size(1290, 2796);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        set.on.value = on;
        set.settle();
        addTearDown(() => set.on.value = false);
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: RepaintBoundary(
              key: const ValueKey('world'),
              child: FittedBox(
                child: SizedBox(
                  width: 430,
                  height: 932,
                  child: UtopiaWorld(style: theme.world),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 3));
        await expectLater(
          find.byKey(const ValueKey('world')),
          matchesGoldenFile('goldens/${name}_${on ? 'set' : 'plain'}.png'),
        );
      });
    }
  }
}
