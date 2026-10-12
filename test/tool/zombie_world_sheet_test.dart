// Renders the Zombie world, plain and with the set complete, into
// test/tool/goldens/ for a look without a device. Run:
// flutter test --run-skipped --update-goldens test/tool/zombie_world_sheet_test.dart
@Tags(['sheet'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/theme/utopia_themes.dart';
import 'package:utopia/core/widgets/utopia_world.dart';
import 'package:utopia/core/widgets/zombie_world.dart';

void main() {
  for (final dead in [false, true]) {
    testWidgets('zombie world dead=$dead', (tester) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      ZombieWorld.dead.value = dead;
      ZombieWorld.settle();
      addTearDown(() => ZombieWorld.dead.value = false);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: const ValueKey('world'),
            child: FittedBox(
              child: SizedBox(
                width: 430,
                height: 932,
                child: UtopiaWorld(style: UtopiaThemes.utopiaZombie.world),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      await expectLater(
        find.byKey(const ValueKey('world')),
        matchesGoldenFile(
          'goldens/zombie_world_${dead ? 'dead' : 'plain'}.png',
        ),
      );
    });
  }
}
