import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/ludo/domain/ludo_bot.dart';
import 'package:utopia/features/ludo/domain/ludo_engine.dart';

void main() {
  const engine = LudoEngine();

  LudoColor playOut(List<LudoColor> players, int seed) {
    final rng = Random(seed);
    var state = LudoState.initial(players);
    for (var turn = 0; turn < 4000; turn++) {
      if (state.winner != null) return state.winner!;
      final dice = engine.rollDie(rng);
      final outcome = engine.registerRoll(state, dice);
      if (outcome.forfeited || outcome.movableTokens.isEmpty) {
        state = outcome.forfeited
            ? outcome.state
            : engine.passTurnNoMove(outcome.state);
        continue;
      }
      final token = chooseLudoMove(outcome.state, dice, random: rng);
      expect(outcome.movableTokens, contains(token));
      state = engine.applyMove(outcome.state, token, dice).state;
    }
    fail('the game never ended');
  }

  test('bots finish games on every board size', () {
    for (final n in [2, 3, 4]) {
      final players = LudoColor.values.take(4).toList().sublist(0, n);
      expect(players, contains(playOut(players, n)));
    }
    final six = [
      LudoColor.red,
      LudoColor.orange,
      LudoColor.yellow,
      LudoColor.green,
      LudoColor.blue,
      LudoColor.purple,
    ];
    expect(six, contains(playOut(six, 6)));
  });

  test('a bot takes a capture when it can', () {
    var state = LudoState.initial(const [LudoColor.red, LudoColor.yellow]);
    // Red has a piece 3 behind yellow's piece on an open square, and a
    // piece in base. Rolling 3 should capture rather than plod along.
    state = state.copyWith(
      tokens: {
        LudoColor.red: [5, 20, -1, -1],
        // Yellow starts at 26; relative 4 is absolute 30 = red relative 30?
        LudoColor.yellow: [-1, -1, -1, -1],
      },
    );
    final rules = state.rules;
    // Put a yellow piece exactly 3 ahead of red's piece on 5 (absolute 8
    // is a safe star, so use red's piece on 20 -> absolute 23).
    final target = (rules.startSquare(LudoColor.red) + 23) % rules.ringSize;
    final yellowRel =
        (target - rules.startSquare(LudoColor.yellow)) % rules.ringSize;
    state = state.copyWith(
      tokens: {
        LudoColor.red: [5, 20, -1, -1],
        LudoColor.yellow: [yellowRel, -1, -1, -1],
      },
      hasRolled: true,
      diceValue: 3,
    );
    expect(chooseLudoMove(state, 3, random: Random(1)), 1);
  });
}
