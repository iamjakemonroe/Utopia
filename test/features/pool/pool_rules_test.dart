import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/pool/domain/pool_physics.dart';
import 'package:utopia/features/pool/domain/pool_rules.dart';

PoolBalls table(Map<int, (double, double)> at) {
  final b = PoolBalls.empty();
  for (final MapEntry(key: i, value: (x, y)) in at.entries) {
    b.x[i] = x;
    b.y[i] = y;
    b.on[i] = true;
  }
  return b;
}

/// A game in progress: [balls] on the table, player 0 to shoot.
PoolGame midGame(
  Map<int, (double, double)> balls, {
  List<PoolGroup?> groups = const [null, null],
}) => PoolGame(
  balls: table(balls),
  turn: 0,
  groups: groups,
  hand: PoolHand.none,
  breakShot: false,
);

PoolGame shoot(PoolGame g, PoolShot shot, {int? called}) =>
    g.after(simulateShot(g.balls, shot), called: called);

// Straight up into the top side pocket (index 4): the cue ball under the
// object ball.
final up = PoolShot(dx: 0, dy: -1, power: 0.3, spinY: -0.15);

void main() {
  group('the break', () {
    test('is taken from the kitchen: the cue ball only goes behind the '
        'head string', () {
      final g = PoolGame.rack(1);
      expect(g.hand, PoolHand.kitchen);
      expect(g.canPlace(0.3, 0.4), isTrue);
      expect(g.canPlace(0.8, 0.4), isFalse);
      expect(g.placeCue(0.3, 0.4).balls.x[kCueBall], 0.3);
    });

    test('a ball pocketed on it keeps the turn, and the table stays open', () {
      var g = PoolGame.rack(3);
      // Find a break that pockets something.
      for (var k = 0; k < 40; k++) {
        final r = simulateShot(g.balls, PoolShot(dx: 1, dy: (k - 20) * 0.002, power: 1));
        final dropped = r.pocketed.where((p) => p.$1 != kCueBall && p.$1 != kEightBall);
        if (dropped.isNotEmpty && !r.pocketed.any((p) => p.$1 == kCueBall)) {
          g = g.after(r);
          expect(g.turn, 0);
          expect(g.open, isTrue);
          expect(g.breakShot, isFalse);
          return;
        }
      }
      fail('no break pocketed a ball');
    });
  });

  group('groups', () {
    test("the first ball pocketed after the break is the shooter's group", () {
      final g = shoot(midGame({kCueBall: (1.0, 0.75), 3: (1.0, 0.5), 12: (0.4, 0.3)}), up);
      expect(g.groups, [PoolGroup.solids, PoolGroup.stripes]);
      expect(g.turn, 0, reason: 'pocketed theirs: shoots again');
      expect(g.lastFouls, isEmpty);
    });

    test('a stripe first makes them stripes', () {
      final g = shoot(midGame({kCueBall: (1.0, 0.75), 11: (1.0, 0.5), 2: (0.4, 0.3)}), up);
      expect(g.groups, [PoolGroup.stripes, PoolGroup.solids]);
    });
  });

  group('fouls give the other player the cue ball in hand, anywhere', () {
    test('hitting nothing', () {
      final g = shoot(
        midGame({kCueBall: (0.5, 0.5), 3: (1.5, 0.2)}),
        PoolShot(dx: 0, dy: 1, power: 0.05),
      );
      expect(g.lastFouls, contains(PoolFoul.noContact));
      expect(g.turn, 1);
      expect(g.hand, PoolHand.anywhere);
    });

    test("hitting the other group's ball first", () {
      final g = shoot(
        midGame({kCueBall: (1.0, 0.75), 11: (1.0, 0.5), 2: (0.4, 0.3)}, groups: [PoolGroup.solids, PoolGroup.stripes]),
        up,
      );
      expect(g.lastFouls, contains(PoolFoul.wrongBall));
      expect(g.turn, 1);
      expect(g.balls.on[11], isFalse, reason: "the stripe stays down; it's theirs");
    });

    test('pocketing the cue ball', () {
      final g = shoot(
        midGame({kCueBall: (0.3, 0.3), 5: (1.5, 0.6)}),
        PoolShot(dx: -1, dy: -1, power: 0.3),
      );
      expect(g.lastFouls, contains(PoolFoul.scratch));
      expect(g.balls.on[kCueBall], isFalse);
      expect(g.turn, 1);
      expect(g.hand, PoolHand.anywhere);
      expect(g.canPlace(1.2, 0.5), isTrue);
      expect(g.canPlace(1.5, 0.6), isFalse, reason: 'on top of a ball');
    });

    test('nothing pocketed and no ball touching a cushion after the hit', () {
      final g = shoot(
        midGame({kCueBall: (0.8, 0.5), 3: (1.0, 0.5)}, groups: [PoolGroup.solids, PoolGroup.stripes]),
        PoolShot(dx: 1, dy: 0, power: 0.01),
      );
      expect(g.lastFouls, [PoolFoul.noCushion]);
      expect(g.turn, 1);
    });
  });

  test('a clean shot that pockets nothing passes the turn, with no ball in hand', () {
    final g = shoot(
      midGame({kCueBall: (0.5, 0.5), 3: (1.2, 0.5)}, groups: [PoolGroup.solids, PoolGroup.stripes]),
      PoolShot(dx: 1, dy: 0, power: 0.2),
    );
    expect(g.lastFouls, isEmpty);
    expect(g.turn, 1);
    expect(g.hand, PoolHand.none);
  });

  group('the 8', () {
    final onEight = {kCueBall: (1.0, 0.75), kEightBall: (1.0, 0.5), 12: (0.3, 0.2)};

    test('in the called pocket, once your group is down: you win', () {
      final g = midGame(onEight, groups: [PoolGroup.solids, PoolGroup.stripes]);
      expect(g.onTheEight(0), isTrue);
      expect(g.callsPocket, isTrue);
      expect(g.targets, [kEightBall]);
      final end = shoot(g, up, called: 4);
      expect(end.winner, 0);
      expect(end.win, PoolWin.eight);
    });

    test('in a pocket not called: you lose', () {
      final end = shoot(midGame(onEight, groups: [PoolGroup.solids, PoolGroup.stripes]), up, called: 0);
      expect(end.winner, 1);
      expect(end.win, PoolWin.eightWrongPocket);
    });

    test('too soon: you lose', () {
      final end = shoot(
        midGame({...onEight, 3: (0.3, 0.8)}, groups: [PoolGroup.solids, PoolGroup.stripes]),
        up,
        called: 4,
      );
      expect(end.winner, 1);
      expect(end.win, PoolWin.eightEarly);
    });

    test('with the cue ball following it in: you lose', () {
      final end = shoot(
        midGame(onEight, groups: [PoolGroup.solids, PoolGroup.stripes]),
        PoolShot(dx: 0, dy: -1, power: 0.6, spinY: 1),
        called: 4,
      );
      expect(end.balls.on[kCueBall], isFalse);
      expect(end.winner, 1);
      expect(end.win, PoolWin.eightFoul);
    });

    test('on the break: it comes back to the foot spot', () {
      final g = PoolGame(
        balls: table({kCueBall: (1.0, 0.75), kEightBall: (1.0, 0.5), 3: (0.3, 0.3)}),
        turn: 0,
        groups: const [null, null],
        hand: PoolHand.none,
        breakShot: true,
      );
      final next = shoot(g, up);
      expect(next.over, isFalse);
      expect(next.balls.on[kEightBall], isTrue);
      expect(next.balls.x[kEightBall], closeTo(kFootSpot.$1, 0.2));
    });
  });

  test('a game survives a round trip through JSON', () {
    final g = shoot(midGame({kCueBall: (1.0, 0.75), 3: (1.0, 0.5), 12: (0.4, 0.3)}), up);
    final back = PoolGame.fromJson(g.toJson());
    expect(back.toJson(), g.toJson());
  });
}
