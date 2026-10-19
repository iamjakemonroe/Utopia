import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/checkers/domain/checkers_engine.dart';
import 'package:utopia/features/chess/domain/chess_engine.dart';
import 'package:utopia/features/chess/domain/chess_position.dart';
import 'package:utopia/features/house/domain/house_brain.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

void main() {
  test('a chess opening move: legal, recorded the way the apps do', () {
    final turn = houseTurn(
      game: 'chess',
      position: _start,
      rating: 1100,
      msLeft: 600000,
      ply: 0,
      seed: 3,
    );
    final move = turn['move']! as Map;
    final after = ChessPosition.fromFen(move['fen_after'] as String);
    expect(after.sideToMove.name, 'black');
    expect(
      const ChessEngine()
          .legalMoves(ChessPosition.fromFen(_start))
          .any(
            (m) =>
                m.from.algebraic == move['from'] &&
                m.to.algebraic == move['to'],
          ),
      isTrue,
    );
    expect(move['san'], isNotEmpty);
    // Quick in the opening.
    expect(turn['think_ms']! as int, inInclusiveRange(600, 3200));
  });

  test('a game that is over says how it ended', () {
    // Fool's mate: white is checkmated.
    const mated =
        'rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3';
    final turn = houseTurn(
      game: 'chess',
      position: mated,
      rating: 1000,
      msLeft: 0,
      ply: 4,
      seed: 1,
    );
    expect(turn['over'], {'winner': 'black', 'result': 'checkmate'});
    expect(turn.containsKey('move'), isFalse);
  });

  test('a checkers move', () {
    final turn = houseTurn(
      game: 'checkers',
      position: CheckersPosition.initialCode,
      rating: 1400,
      msLeft: 300000,
      ply: 0,
      seed: 9,
    );
    final move = turn['move']! as Map;
    expect(
      CheckersPosition.decode(move['fen_after'] as String).toMove,
      CheckersSide.light,
    );
    expect(move['san'], matches(RegExp(r'^\d+[-x]\d+')));
  });

  test('never thinks a short clock away', () {
    final rng = Random(5);
    for (var i = 0; i < 200; i++) {
      final ms = thinkMs(ply: 30, msLeft: 20000, quick: false, rng: rng);
      expect(ms, lessThanOrEqualTo(1112));
    }
  });
}
