import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/pool/domain/pool_physics.dart';
import 'package:utopia/features/pool/domain/pool_rules.dart';

/// A table with only the cue ball and the balls given, at their places.
PoolBalls table(Map<int, (double, double)> at) {
  final b = PoolBalls.empty();
  for (final MapEntry(key: i, value: (x, y)) in at.entries) {
    b.x[i] = x;
    b.y[i] = y;
    b.on[i] = true;
  }
  return b;
}

double dist(PoolBalls b, int i, (double, double) p) =>
    math.sqrt(math.pow(b.x[i] - p.$1, 2) + math.pow(b.y[i] - p.$2, 2));

void main() {
  test('a ball comes to rest, rolling straight', () {
    final r = simulateShot(
      table({kCueBall: (0.4, 0.5)}),
      PoolShot(dx: 1, dy: 0, power: 0.05),
    );
    expect(r.end.y[kCueBall], closeTo(0.5, 1e-9));
    expect(r.end.x[kCueBall], inInclusiveRange(0.7, 1.8));
    expect(r.duration, lessThan(30));
    expect(r.events, isEmpty);
  });

  // Straight up into the top side pocket: the 1 drops, so it can't come
  // back off a cushion into the cue ball.
  final straightIn = table({kCueBall: (1.0, 0.75), 1: (1.0, 0.5)});

  const contact = 0.5 + 2 * kBallRadius;

  test('a centre hit full on: the 1 drops; the cloth has given the cue ball '
      'some roll on the way, so it follows a little', () {
    final r = simulateShot(straightIn, PoolShot(dx: 0, dy: -1, power: 0.3));
    expect(r.firstContact, 1);
    expect(r.pocketed, [(1, 4)]);
    expect(contact - r.end.y[kCueBall], inInclusiveRange(0.02, 0.16));
  });

  test('a touch below centre stuns it: it stops where it hit', () {
    final r = simulateShot(
      straightIn,
      PoolShot(dx: 0, dy: -1, power: 0.3, spinY: -0.15),
    );
    expect(r.pocketed, [(1, 4)]);
    expect(r.end.y[kCueBall], closeTo(contact, 0.03));
  });

  test('backspin draws the cue ball back; topspin follows through', () {
    final draw = simulateShot(
      straightIn,
      PoolShot(dx: 0, dy: -1, power: 0.35, spinY: -1),
    );
    final follow = simulateShot(
      straightIn,
      PoolShot(dx: 0, dy: -1, power: 0.35, spinY: 1),
    );
    expect(draw.end.y[kCueBall], greaterThan(0.68), reason: 'came back');
    expect(
      !follow.end.on[kCueBall] || follow.end.y[kCueBall] < 0.4,
      isTrue,
      reason: 'went on after the 1',
    );
  });

  test('a cut sends the object ball along the line of centres', () {
    // The cue ball hits the 1 a little above its centre: the 1 goes down
    // and away, the cue ball off the other way.
    final r = simulateShot(
      table({kCueBall: (0.5, 0.5), 1: (1.0, 0.52)}),
      PoolShot(dx: 1, dy: 0, power: 0.3),
    );
    expect(r.firstContact, 1);
    expect(r.end.y[1], greaterThan(0.52));
    expect(r.end.y[kCueBall], lessThan(0.5));
  });

  test('off a cushion: back out, a little slower, the angle kept', () {
    final r = simulateShot(
      table({kCueBall: (0.5, 0.5)}),
      PoolShot(dx: 0.3, dy: -1, power: 0.25),
    );
    final cushion = r.events.firstWhere((e) => e.kind == PoolEventKind.cushion);
    expect(cushion.b, 0, reason: 'the top rail, left half');
    // Went up and right, came back down and right.
    expect(r.end.y[kCueBall], greaterThan(0.1));
    expect(r.end.x[kCueBall], greaterThan(0.5));
  });

  test('into the corner pocket, and into a side pocket', () {
    final corner = simulateShot(
      table({kCueBall: (0.3, 0.3)}),
      PoolShot(dx: -1, dy: -1, power: 0.3),
    );
    expect(corner.pocketed, [(kCueBall, 0)]);
    expect(corner.end.on[kCueBall], isFalse);

    final side = simulateShot(
      table({kCueBall: (1.0, 0.5)}),
      PoolShot(dx: 0, dy: -1, power: 0.3),
    );
    expect(side.pocketed, [(kCueBall, 4)]);
  });

  test('a ball sent along a rail into a corner drops (no stuck jaw)', () {
    final r = simulateShot(
      table({kCueBall: (1.6, kBallRadius + 0.002)}),
      PoolShot(dx: 1, dy: 0, power: 0.35),
    );
    expect(r.pocketed.map((p) => p.$2), [1]);
  });

  group('the break', () {
    final rack = rackBalls(7);
    final r = simulateShot(rack, PoolShot(dx: 1, dy: 0.004, power: 1));

    test('spreads the rack and everything comes to rest on the cloth', () {
      final moved = [
        for (var i = 1; i < kBalls; i++)
          if (!r.end.on[i] || dist(r.end, i, (rack.x[i], rack.y[i])) > 0.05) i,
      ];
      expect(moved.length, greaterThan(8));
      for (var i = 0; i < kBalls; i++) {
        if (!r.end.on[i]) continue;
        expect(
          r.end.x[i],
          inInclusiveRange(
            kBallRadius - 1e-6,
            kPoolLength - kBallRadius + 1e-6,
          ),
        );
        expect(
          r.end.y[i],
          inInclusiveRange(kBallRadius - 1e-6, kPoolWidth - kBallRadius + 1e-6),
        );
        for (var j = i + 1; j < kBalls; j++) {
          if (!r.end.on[j]) continue;
          final d = math.sqrt(
            math.pow(r.end.x[i] - r.end.x[j], 2) +
                math.pow(r.end.y[i] - r.end.y[j], 2),
          );
          expect(
            d,
            greaterThan(2 * kBallRadius - 1e-3),
            reason: 'balls $i and $j overlap',
          );
        }
      }
      expect(r.duration, lessThan(30));
    });

    test('is recorded frame by frame, to play back', () {
      expect(r.frameCount, greaterThan(100));
      expect(r.frames.length, r.frameCount * 2 * kBalls);
    });

    test('the same shot from the same rack plays out exactly the same', () {
      final again = simulateShot(
        rackBalls(7),
        PoolShot(dx: 1, dy: 0.004, power: 1),
      );
      expect(again.end.x, r.end.x);
      expect(again.end.y, r.end.y);
      expect(again.end.on, r.end.on);
      expect(again.events.length, r.events.length);
    });
  });

  test('a rack: 15 balls in a triangle, the 8 in the middle, a solid and a '
      'stripe in the back corners, nothing touching', () {
    final b = rackBalls(42);
    for (var i = 0; i < kBalls; i++) {
      expect(b.on[i], isTrue);
    }
    expect(
      b.x[kEightBall],
      closeTo(kFootSpot.$1 + 2 * 2 * kBallRadius * 0.866, 1e-3),
    );
    expect(b.y[kEightBall], closeTo(kFootSpot.$2, 1e-9));
    final back = [
      for (var i = 1; i < kBalls; i++)
        if (b.x[i] > kFootSpot.$1 + 3.9 * 2 * kBallRadius * 0.866 &&
            (b.y[i] - 0.5).abs() > 3.9 * kBallRadius)
          i,
    ];
    expect(back.length, 2);
    expect(
      PoolGroup.solids.has(back[0]) != PoolGroup.solids.has(back[1]),
      isTrue,
    );
    for (var i = 0; i < kBalls; i++) {
      expect(b.isFree(b.x[i], b.y[i], except: i), isTrue, reason: 'ball $i');
    }
  });
}
