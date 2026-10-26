import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/checkers/domain/checkers_engine.dart';

/// Perft: every legal sequence of moves from the opening, counted to a depth.
/// The published counts for English draughts (8x8 checkers: compulsory
/// captures, multi-jumps, men forward only, crowning ends the move) are the
/// standard check that a move generator plays the game exactly.
int perft(CheckersEngine engine, CheckersPosition p, int depth) {
  final moves = engine.legalMoves(p);
  if (depth == 1) return moves.length;
  var n = 0;
  for (final m in moves) {
    n += perft(engine, p.apply(m), depth - 1);
  }
  return n;
}

void main() {
  const engine = CheckersEngine();
  const expected = [7, 49, 302, 1469, 7361, 36768, 179740, 845931];

  for (var depth = 1; depth <= expected.length; depth++) {
    test('perft $depth from the opening is ${expected[depth - 1]}', () {
      expect(perft(engine, CheckersPosition.initial(), depth), expected[depth - 1]);
    });
  }
}
