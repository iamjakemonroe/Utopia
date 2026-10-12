import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/theme/utopia_themes.dart';
import 'package:utopia/core/widgets/coin_buddy.dart';
import 'package:utopia/core/widgets/utopia_world.dart';
import 'package:utopia/core/widgets/world_sets.dart';

void main() {
  final all = [
    WorldSets.dragon,
    WorldSets.zombie,
    WorldSets.heaven,
    WorldSets.hell,
  ];
  tearDown(() {
    for (final set in all) {
      set.on.value = false;
      set.settle();
    }
  });

  test('a set fades in and out rather than popping', () {
    final set = WorldSets.heaven..settle();
    expect(set.amount, 0);
    set.on.value = true;
    expect(set.amount, lessThan(0.1));
    set.settle();
    expect(set.amount, 1);
    set.on.value = false;
    expect(set.amount, greaterThan(0.9));
  });

  for (final (name, theme, set) in [
    ('Dojo', UtopiaThemes.utopiaDojo, WorldSets.dragon),
    ('Zombie', UtopiaThemes.utopiaZombie, WorldSets.zombie),
    ('Heaven', UtopiaThemes.utopiaHeaven, WorldSets.heaven),
    ('Hell', UtopiaThemes.utopiaHell, WorldSets.hell),
  ]) {
    for (final on in [false, true]) {
      testWidgets('$name and every Chip mood paint, set=$on', (tester) async {
        set.on.value = on;
        set.settle();
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              children: [
                Positioned.fill(child: UtopiaWorld(style: theme.world)),
                Wrap(
                  children: [
                    for (final mood in BuddyMood.values)
                      CoinBuddy(mood: mood, size: 80),
                  ],
                ),
              ],
            ),
          ),
        );
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 400));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
