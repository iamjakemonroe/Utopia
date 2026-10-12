// Renders Chip in several moods, himself and turned by the zombie set, into
// test/tool/goldens/chip_zombie.png. Run:
// flutter test --run-skipped --update-goldens test/tool/chip_zombie_sheet_test.dart
@Tags(['sheet'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/widgets/coin_buddy.dart';
import 'package:utopia/core/widgets/zombie_world.dart';

void main() {
  testWidgets('chip zombie sheet', (tester) async {
    tester.view.physicalSize = const Size(1500, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => ZombieWorld.dead.value = false);
    const moods = [
      BuddyMood.idle,
      BuddyMood.happy,
      BuddyMood.sad,
      BuddyMood.vibing,
      BuddyMood.thinking,
      BuddyMood.evil,
    ];
    Widget row() => Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [for (final m in moods) CoinBuddy(mood: m, size: 220)],
    );
    // Two rows can't differ on a global switch in one frame, so render
    // each state into its own boundary and stitch them by pumping twice.
    for (final dead in [false, true]) {
      ZombieWorld.dead.value = dead;
      ZombieWorld.settle();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: const ValueKey('sheet'),
            child: ColoredBox(
              color: const Color(0xFF0D150F),
              child: Center(child: SizedBox(height: 320, child: row())),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1300));
      await expectLater(
        find.byKey(const ValueKey('sheet')),
        matchesGoldenFile('goldens/chip_${dead ? 'zombie' : 'plain'}.png'),
      );
    }
  });
}
