import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/ludo/domain/ludo_engine.dart';

void main() {
  const engine = LudoEngine();
  const players = [LudoColor.red, LudoColor.yellow];

  group('base entry', () {
    test('a token in base cannot move on a non-6', () {
      final state = LudoState.initial(players);
      expect(engine.isTokenMovable(kLudoBase, 4), isFalse);
      expect(engine.legalTokenMoves(state, 4), isEmpty);
    });

    test('a token in base can enter on a 6', () {
      final state = LudoState.initial(players);
      expect(engine.isTokenMovable(kLudoBase, 6), isTrue);
      expect(engine.legalTokenMoves(state, 6), [0, 1, 2, 3]);
    });

    test(
      'entering moves the token to relative position 0, its start square',
      () {
        final state = LudoState.initial(players);
        final result = engine.applyMove(state, 0, 6);
        expect(result.toPosition, 0);
        expect(
          engine.absoluteSquare(LudoColor.red, 0),
          kLudoStartSquare[LudoColor.red],
        );
      },
    );
  });

  group('movement and finishing', () {
    test('a token cannot overshoot past the finish', () {
      // Position 53 + 6 = 59 > 56, illegal; 53 + 3 = 56, exactly home, legal.
      expect(engine.isTokenMovable(53, 6), isFalse);
      expect(engine.isTokenMovable(53, 3), isTrue);
    });

    test('five squares up the home stretch, then home', () {
      const rules = LudoBoardRules.classic;
      // From the first stretch square (51) home is five steps away.
      expect(rules.finish - (rules.ringLast + 1), 5);
      expect(engine.isTokenMovable(51, 5), isTrue);
      expect(engine.isTokenMovable(51, 6), isFalse);
    });

    test('a token saved one step past home (older games) counts as home', () {
      const rules = LudoBoardRules.classic;
      expect(rules.isHome(57), isTrue);
      expect(engine.isTokenMovable(57, 1), isFalse);
    });

    test('landing exactly on 56 finishes the token', () {
      var state = LudoState.initial(players);
      state = state.copyWith(
        tokens: {
          ...state.tokens,
          LudoColor.red: [53, -1, -1, -1],
        },
      );
      final result = engine.applyMove(state, 0, 3);
      expect(result.toPosition, kLudoPathLength);
      expect(result.reachedHome, isTrue);
      expect(result.state.tokens[LudoColor.red]![0], kLudoPathLength);
    });

    test('all four tokens home wins the game', () {
      var state = LudoState.initial(players);
      state = state.copyWith(
        tokens: {
          ...state.tokens,
          LudoColor.red: [56, 56, 56, 53],
        },
      );
      final result = engine.applyMove(state, 3, 3);
      expect(result.wonGame, isTrue);
      expect(result.state.winner, LudoColor.red);
    });
  });

  group('capturing', () {
    test(
      'landing on an opponent token on a non-safe square sends it to base',
      () {
        var state = LudoState.initial(players);
        // Red at relative 10 -> absolute square 10 (start 0 + 10). Yellow's
        // start is 26, so yellow needs relative position r where
        // (26 + r) % 52 == 10  =>  r == 36. Square 10 isn't in the safe set.
        state = state.copyWith(
          tokens: {
            LudoColor.red: [8, -1, -1, -1],
            LudoColor.yellow: [36, -1, -1, -1],
          },
        );
        expect(kLudoSafeSquares.contains(10), isFalse);
        final result = engine.applyMove(state, 0, 2); // red 8 -> 10
        expect(result.captured, isTrue);
        expect(result.state.tokens[LudoColor.yellow]![0], kLudoBase);
      },
    );

    test('a token on a safe square cannot be captured', () {
      var state = LudoState.initial(players);
      // Square 8 is safe. Yellow relative r with (26 + r) % 52 == 8 => r = 34.
      state = state.copyWith(
        tokens: {
          LudoColor.red: [6, -1, -1, -1],
          LudoColor.yellow: [34, -1, -1, -1],
        },
      );
      expect(kLudoSafeSquares.contains(8), isTrue);
      final result = engine.applyMove(state, 0, 2); // red 6 -> 8
      expect(result.captured, isFalse);
      expect(result.state.tokens[LudoColor.yellow]![0], 34);
    });

    test('capturing does not apply inside a home stretch', () {
      // Home-stretch positions (51-55) are private per color and never
      // collide with another color's absoluteSquare mapping, so a capture
      // check must not run there at all — verified by the fact that this
      // move (which lands in red's private stretch) reports no capture
      // even though yellow occupies an arbitrary ring square.
      var state = LudoState.initial(players);
      state = state.copyWith(
        tokens: {
          LudoColor.red: [50, -1, -1, -1],
          LudoColor.yellow: [5, -1, -1, -1],
        },
      );
      final result = engine.applyMove(
        state,
        0,
        2,
      ); // red 50 -> 52 (home stretch)
      expect(result.captured, isFalse);
    });
  });

  group('extra turns', () {
    test('rolling a 6 grants an extra turn (turn does not advance)', () {
      final state = LudoState.initial(players);
      final result = engine.applyMove(state, 0, 6);
      expect(result.extraTurn, isTrue);
      expect(result.state.turn, LudoColor.red);
    });

    test('a non-6, non-capture, non-home move passes the turn', () {
      var state = LudoState.initial(players);
      state = state.copyWith(
        tokens: {
          ...state.tokens,
          LudoColor.red: [10, -1, -1, -1],
        },
      );
      final result = engine.applyMove(state, 0, 2);
      expect(result.extraTurn, isFalse);
      expect(result.state.turn, LudoColor.yellow);
    });

    test('capturing grants an extra turn even off a non-6', () {
      var state = LudoState.initial(players);
      state = state.copyWith(
        tokens: {
          LudoColor.red: [8, -1, -1, -1],
          LudoColor.yellow: [36, -1, -1, -1],
        },
      );
      final result = engine.applyMove(state, 0, 2);
      expect(result.captured, isTrue);
      expect(result.extraTurn, isTrue);
      expect(result.state.turn, LudoColor.red);
    });
  });

  group('sixes in a row', () {
    test('a third six in a row stands: the player moves and rolls again', () {
      final state = LudoState.initial(players).copyWith(consecutiveSixes: 2);
      final outcome = engine.registerRoll(state, 6);
      expect(outcome.state.turn, LudoColor.red);
      expect(outcome.state.diceValue, 6);
      expect(outcome.state.hasRolled, isTrue);
      expect(outcome.state.consecutiveSixes, 3);
      expect(outcome.movableTokens, [0, 1, 2, 3]);
      final moved = engine.applyMove(outcome.state, 0, 6);
      expect(moved.extraTurn, isTrue);
      expect(moved.state.turn, LudoColor.red);
    });

    test('a fourth and fifth six still stand', () {
      var state = LudoState.initial(players).copyWith(consecutiveSixes: 3);
      for (var i = 0; i < 2; i++) {
        final outcome = engine.registerRoll(state, 6);
        expect(outcome.movableTokens, isNotEmpty);
        state = engine.applyMove(outcome.state, outcome.movableTokens.first, 6).state;
        expect(state.turn, LudoColor.red);
      }
    });

    test('a first six counts one, anything else resets the count', () {
      final state = LudoState.initial(players);
      final six = engine.registerRoll(state, 6);
      expect(six.state.consecutiveSixes, 1);
      expect(six.state.turn, LudoColor.red);
      final four = engine.registerRoll(state.copyWith(consecutiveSixes: 2), 4);
      expect(four.state.consecutiveSixes, 0);
    });
  });

  group('no legal move', () {
    test('passTurnNoMove advances the turn and clears the dice', () {
      final state = LudoState.initial(players);
      final next = engine.passTurnNoMove(state);
      expect(next.turn, LudoColor.yellow);
      expect(next.diceValue, isNull);
      expect(next.hasRolled, isFalse);
    });
  });

  group('serialization', () {
    test('toJson/fromJson round-trips exactly', () {
      var state = LudoState.initial(players);
      state = state.copyWith(
        tokens: {
          LudoColor.red: [-1, 0, 30, 56],
          LudoColor.yellow: [-1, -1, -1, 5],
        },
        diceValue: 4,
        hasRolled: true,
        consecutiveSixes: 1,
      );
      final restored = LudoState.fromJson(state.toJson());
      expect(restored.players, state.players);
      expect(restored.tokens, state.tokens);
      expect(restored.turn, state.turn);
      expect(restored.diceValue, state.diceValue);
      expect(restored.hasRolled, state.hasRolled);
      expect(restored.consecutiveSixes, state.consecutiveSixes);
    });
  });

  group('v2: more players, rolls and captures', () {
    test('a roll is recorded for everyone with an increasing sequence', () {
      final state = LudoState.initial(players);
      final first = engine.registerRoll(state, 4).state;
      expect(first.rollSeq, 1);
      expect(first.lastRoll, const LudoRoll(LudoColor.red, 4));
      final passed = engine.passTurnNoMove(first);
      expect(
        passed.lastRoll,
        first.lastRoll,
        reason: 'stays visible after the pass',
      );
      final second = engine.registerRoll(passed, 2).state;
      expect(second.rollSeq, 2);
      expect(second.lastRoll, const LudoRoll(LudoColor.yellow, 2));
    });

    test('a third six is shown as rolled, and stands', () {
      final state = LudoState.initial(players).copyWith(consecutiveSixes: 2);
      final outcome = engine.registerRoll(state, 6);
      expect(outcome.state.lastRoll, const LudoRoll(LudoColor.red, 6));
      expect(outcome.state.diceValue, 6);
    });

    test('a capture is recorded with who captured and who was sent home', () {
      var state = LudoState.initial(players);
      state = state.copyWith(
        tokens: {
          LudoColor.red: [8, -1, -1, -1],
          LudoColor.yellow: [36, -1, -1, -1],
        },
      );
      final result = engine.applyMove(state, 0, 2);
      final capture = result.state.capture!;
      expect(capture.seq, 1);
      expect(capture.by, LudoColor.red);
      expect(capture.token, 0);
      expect(capture.victims, [(LudoColor.yellow, 0)]);
      // A later move without a capture keeps the record (and its seq).
      final calm = engine.applyMove(
        result.state.copyWith(turn: LudoColor.red),
        0,
        1,
      );
      expect(calm.state.capture?.seq, 1);
    });

    test('four players take turns clockwise', () {
      const four = [
        LudoColor.red,
        LudoColor.green,
        LudoColor.yellow,
        LudoColor.blue,
      ];
      var state = LudoState.initial(four);
      expect(state.board, LudoBoardKind.classic);
      final order = <LudoColor>[];
      for (var i = 0; i < 4; i++) {
        state = engine.passTurnNoMove(state);
        order.add(state.turn);
      }
      expect(order, [
        LudoColor.green,
        LudoColor.yellow,
        LudoColor.blue,
        LudoColor.red,
      ]);
    });

    test('players who left are skipped and can\'t be captured', () {
      const three = [LudoColor.red, LudoColor.green, LudoColor.yellow];
      var state = LudoState.initial(three).copyWith(left: [LudoColor.green]);
      expect(state.nextPlayer(), LudoColor.yellow);
      expect(state.activePlayers, [LudoColor.red, LudoColor.yellow]);

      // Green "sits" on red's landing square but has left: no capture.
      state = state.copyWith(
        tokens: {
          LudoColor.red: [8, -1, -1, -1],
          LudoColor.green: [49, -1, -1, -1], // (13 + 49) % 52 == 10
          LudoColor.yellow: [-1, -1, -1, -1],
        },
      );
      final result = engine.applyMove(state, 0, 2);
      expect(result.captured, isFalse);
    });

    test('six players play on the six-arm board with a 78-square ring', () {
      const six = [
        LudoColor.red,
        LudoColor.orange,
        LudoColor.yellow,
        LudoColor.green,
        LudoColor.blue,
        LudoColor.purple,
      ];
      final state = LudoState.initial(six);
      expect(state.board, LudoBoardKind.hex);
      expect(state.rules.ringSize, 78);
      expect(state.rules.finish, 82);
      expect(state.rules.startSquare(LudoColor.purple), 65);
      expect(engine.isTokenMovable(79, 3, rules: state.rules), isTrue);
      expect(engine.isTokenMovable(79, 4, rules: state.rules), isFalse);

      // Orange (start 13) lands on square 20 where purple (start 65) sits.
      final placed = state.copyWith(
        turn: LudoColor.orange,
        tokens: {
          ...state.tokens,
          LudoColor.orange: [5, -1, -1, -1],
          LudoColor.purple: [33, -1, -1, -1], // (65 + 33) % 78 == 20
        },
      );
      final result = engine.applyMove(placed, 0, 2);
      expect(result.captured, isTrue);
      expect(result.state.tokens[LudoColor.purple]![0], kLudoBase);
    });

    test('everything new survives a JSON round trip', () {
      var state = LudoState.initial(players);
      state = engine
          .registerRoll(state, 3)
          .state
          .copyWith(
            left: [LudoColor.yellow],
            capture: const LudoCapture(
              seq: 4,
              by: LudoColor.red,
              token: 2,
              victims: [(LudoColor.yellow, 1)],
            ),
          );
      final restored = LudoState.fromJson(state.toJson());
      expect(restored.board, state.board);
      expect(restored.left, state.left);
      expect(restored.rollSeq, state.rollSeq);
      expect(restored.lastRoll, state.lastRoll);
      expect(restored.capture!.seq, 4);
      expect(restored.capture!.victims, [(LudoColor.yellow, 1)]);
    });

    test('a pre-v2 state from the server still loads', () {
      final restored = LudoState.fromJson({
        'players': ['red', 'yellow'],
        'tokens': {
          'red': [-1, -1, -1, -1],
          'yellow': [-1, -1, -1, -1],
        },
        'turn': 'red',
        'dice_value': null,
        'has_rolled': false,
        'consecutive_sixes': 0,
        'winner': null,
      });
      expect(restored.board, LudoBoardKind.classic);
      expect(restored.left, isEmpty);
      expect(restored.rollSeq, 0);
      expect(restored.capture, isNull);
    });
  });

  group('playing on after a finish', () {
    const three = [LudoColor.red, LudoColor.green, LudoColor.yellow];

    LudoState withTokens(
      List<LudoColor> players,
      Map<LudoColor, List<int>> tokens, {
      LudoColor? turn,
    }) {
      final s = LudoState.initial(players);
      return s.copyWith(tokens: {...s.tokens, ...tokens}, turn: turn);
    }

    test('with three, the first home takes first and the others play on', () {
      final state = withTokens(three, {
        LudoColor.red: [56, 56, 56, 53],
      });
      final result = engine.applyMove(state, 3, 3);
      final next = result.state;
      expect(result.wonGame, isTrue);
      expect(result.firstPlace, isTrue);
      expect(next.winner, LudoColor.red);
      expect(next.finished, [LudoColor.red]);
      expect(next.placeOf(LudoColor.red), 1);
      expect(next.isOver, isFalse);
      expect(next.racing, [LudoColor.green, LudoColor.yellow]);
      // No extra turn for getting home last: on to green.
      expect(next.turn, LudoColor.green);
    });

    test('turns skip whoever has finished', () {
      final state = withTokens(
        three,
        {
          LudoColor.red: [56, 56, 56, 56],
        },
        turn: LudoColor.yellow,
      ).copyWith(finished: [LudoColor.red], winner: LudoColor.red);
      expect(state.nextPlayer(), LudoColor.green);
      // A roll with nothing to move passes past red too.
      expect(engine.passTurnNoMove(state).turn, LudoColor.green);
    });

    test('the second home ends a three-player game; the winner stays', () {
      final state = withTokens(
        three,
        {
          LudoColor.red: [56, 56, 56, 56],
          LudoColor.green: [56, 56, 55, 56],
        },
        turn: LudoColor.green,
      ).copyWith(finished: [LudoColor.red], winner: LudoColor.red);
      final result = engine.applyMove(state, 2, 1);
      final next = result.state;
      expect(result.wonGame, isTrue);
      expect(result.firstPlace, isFalse);
      expect(next.finished, [LudoColor.red, LudoColor.green]);
      expect(next.placeOf(LudoColor.green), 2);
      expect(next.winner, LudoColor.red);
      expect(next.isOver, isTrue);
      expect(next.turn, LudoColor.green);
    });

    test('with two, the first home ends it', () {
      final state = withTokens(
        const [LudoColor.red, LudoColor.yellow],
        {
          LudoColor.red: [56, 56, 56, 53],
        },
      );
      final next = engine.applyMove(state, 3, 3).state;
      expect(next.isOver, isTrue);
      expect(next.turn, LudoColor.red);
    });

    test('someone leaving can end it once one finished', () {
      final state =
          withTokens(three, {
            LudoColor.red: [56, 56, 56, 56],
          }).copyWith(
            finished: [LudoColor.red],
            winner: LudoColor.red,
            left: [LudoColor.green],
          );
      expect(state.racing, [LudoColor.yellow]);
      expect(state.isOver, isTrue);
    });

    test('the finishing order survives a JSON round trip', () {
      final state = LudoState.initial(three).copyWith(
        finished: [LudoColor.yellow, LudoColor.red],
        winner: LudoColor.yellow,
      );
      final restored = LudoState.fromJson(state.toJson());
      expect(restored.finished, [LudoColor.yellow, LudoColor.red]);
      expect(restored.winner, LudoColor.yellow);
    });

    test('a game saved with only a winner has them finished first', () {
      final json = LudoState.initial(const [
        LudoColor.red,
        LudoColor.yellow,
      ]).toJson()..remove('finished');
      json['winner'] = 'yellow';
      final restored = LudoState.fromJson(json);
      expect(restored.finished, [LudoColor.yellow]);
      expect(restored.isOver, isTrue);
    });
  });
}
