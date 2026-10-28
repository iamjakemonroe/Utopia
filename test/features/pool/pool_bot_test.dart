import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/chess/domain/chess_bot.dart' show BotLevel;
import 'package:utopia/features/pool/domain/pool_bot.dart';
import 'package:utopia/features/pool/domain/pool_physics.dart';
import 'package:utopia/features/pool/domain/pool_rules.dart';

PoolGame midGame(
  Map<int, (double, double)> at, {
  List<PoolGroup?> groups = const [null, null],
  PoolHand hand = PoolHand.none,
}) {
  final b = PoolBalls.empty();
  for (final MapEntry(key: i, value: (x, y)) in at.entries) {
    b.x[i] = x;
    b.y[i] = y;
    b.on[i] = true;
  }
  return PoolGame(
    balls: b,
    turn: 0,
    groups: groups,
    hand: hand,
    breakShot: false,
  );
}

/// Plays [move] in [game].
PoolGame play(PoolGame game, PoolBotMove move) {
  var g = game;
  if (move.cueX != null) g = g.placeCue(move.cueX!, move.cueY!);
  return g.after(simulateShot(g.balls, move.shot), called: move.called);
}

void main() {
  test('a hard Chip pots a straight one', () {
    var potted = 0;
    for (var seed = 0; seed < 10; seed++) {
      final g = midGame(
        {kCueBall: (1.0, 0.7), 3: (1.0, 0.45), 12: (1.6, 0.8)},
        groups: [PoolGroup.solids, PoolGroup.stripes],
      );
      final next = play(g, choosePoolMove(g, BotLevel.hard, seed));
      if (!next.balls.on[3] && next.lastFouls.isEmpty) potted++;
    }
    expect(potted, greaterThanOrEqualTo(9));
  });

  test('on the 8 it calls the pocket it aims for, and wins', () {
    final g = midGame(
      {kCueBall: (1.0, 0.7), kEightBall: (1.0, 0.45), 12: (1.6, 0.8)},
      groups: [PoolGroup.solids, PoolGroup.stripes],
    );
    final move = choosePoolMove(g, BotLevel.hard, 3);
    expect(move.called, isNotNull);
    expect(play(g, move).winner, 0);
  });

  test('with the cue ball in hand it puts it somewhere it may go', () {
    final g = midGame({
      kEightBall: (1.5, 0.5),
      2: (0.6, 0.3),
      3: (1.2, 0.7),
      12: (1.7, 0.2),
    }, hand: PoolHand.anywhere);
    final move = choosePoolMove(g, BotLevel.normal, 5);
    expect(move.cueX, isNotNull);
    expect(g.canPlace(move.cueX!, move.cueY!), isTrue);
  });

  test('the break: from the kitchen, at full power', () {
    final g = PoolGame.rack(9);
    final move = choosePoolMove(g, BotLevel.hard, 1);
    expect(move.cueX, lessThanOrEqualTo(kHeadString));
    expect(move.shot.power, greaterThan(0.8));
  });

  for (final level in BotLevel.values) {
    test('two ${level.name} Chips finish a game', () {
      for (var seed = 0; seed < 3; seed++) {
        var g = PoolGame.rack(seed);
        final watch = Stopwatch()..start();
        var shots = 0;
        while (!g.over && shots < 400) {
          g = play(g, choosePoolMove(g, level, seed * 1000 + shots));
          shots++;
        }
        final perShot = watch.elapsedMilliseconds / shots;
        // ignore: avoid_print
        print(
          '${level.name} seed $seed: ${g.win?.name} for player ${g.winner} '
          'in $shots shots, ${perShot.toStringAsFixed(0)} ms a shot',
        );
        expect(g.over, isTrue, reason: 'seed $seed');
      }
    });
  }
}
