import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/theme/utopia_themes.dart';
import 'package:utopia/core/widgets/coin_buddy.dart';
import 'package:utopia/core/widgets/utopia_world.dart';
import 'package:utopia/core/widgets/zombie_world.dart';

void main() {
  tearDown(() {
    ZombieWorld.dead.value = false;
    ZombieWorld.settle();
  });

  test('the zombie set fades in rather than popping', () {
    ZombieWorld.settle();
    expect(ZombieWorld.amount, 0);
    ZombieWorld.dead.value = true;
    expect(ZombieWorld.amount, lessThan(0.1));
    ZombieWorld.settle();
    expect(ZombieWorld.amount, 1);
    ZombieWorld.dead.value = false;
    expect(ZombieWorld.amount, greaterThan(0.9));
  });

  for (final dead in [false, true]) {
    testWidgets('the Zombie world and Chip paint, dead=$dead', (tester) async {
      ZombieWorld.dead.value = dead;
      ZombieWorld.settle();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              Positioned.fill(
                child: UtopiaWorld(style: UtopiaThemes.utopiaZombie.world),
              ),
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
