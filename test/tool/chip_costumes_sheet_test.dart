// Renders Chip in several moods in each set's costume (zombie, angel,
// devil, fighter) into test/tool/goldens/chip_<costume>.png. Run:
// flutter test --run-skipped --update-goldens test/tool/chip_costumes_sheet_test.dart
@Tags(['sheet'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/widgets/coin_buddy.dart';
import 'package:utopia/core/widgets/world_sets.dart';

void main() {
  const moods = [
    BuddyMood.idle,
    BuddyMood.happy,
    BuddyMood.sad,
    BuddyMood.vibing,
    BuddyMood.thinking,
    BuddyMood.hot,
  ];
  for (final (name, set) in [
    ('zombie', WorldSets.zombie),
    ('angel', WorldSets.heaven),
    ('devil', WorldSets.hell),
    ('fighter', WorldSets.dragon),
  ]) {
    testWidgets('chip $name', (tester) async {
      tester.view.physicalSize = const Size(1500, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final other in [
        WorldSets.zombie,
        WorldSets.heaven,
        WorldSets.hell,
        WorldSets.dragon,
      ]) {
        other.on.value = other == set;
        other.settle();
      }
      addTearDown(() {
        set.on.value = false;
        set.settle();
      });
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: const ValueKey('sheet'),
            child: ColoredBox(
              color: const Color(0xFF1A1430),
              child: Center(
                child: SizedBox(
                  height: 320,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final m in moods) CoinBuddy(mood: m, size: 220),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1300));
      await expectLater(
        find.byKey(const ValueKey('sheet')),
        matchesGoldenFile('goldens/chip_$name.png'),
      );
    });
  }
}
