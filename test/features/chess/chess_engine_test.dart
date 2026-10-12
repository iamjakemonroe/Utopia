import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/chess/domain/chess_engine.dart';
import 'package:utopia/features/chess/domain/chess_position.dart';

/// Perft (performance test) counts the number of leaf positions reachable
/// at a given depth from a starting position. It's the standard way to
/// verify a chess move generator: the correct counts for the standard
/// starting position are well-known published values, so any bug in move
/// generation (missing en passant, bad castling rights, wrong promotion
/// handling, etc.) shows up as a wrong count rather than a subtle silent
/// error, which a handful of example-based tests would likely miss.
int perft(ChessPosition position, int depth, ChessEngine engine) {
  if (depth == 0) return 1;
  final moves = engine.legalMoves(position);
  if (depth == 1) return moves.length;
  var nodes = 0;
  for (final move in moves) {
    nodes += perft(position.applyMove(move), depth - 1, engine);
  }
  return nodes;
}

void main() {
  const engine = ChessEngine();

  group('perft from the starting position (published reference values)', () {
    final start = ChessPosition.initial();

    test('depth 1 = 20', () => expect(perft(start, 1, engine), 20));
    test('depth 2 = 400', () => expect(perft(start, 2, engine), 400));
    test('depth 3 = 8902', () => expect(perft(start, 3, engine), 8902));
    test('depth 4 = 197281', () => expect(perft(start, 4, engine), 197281));
  });

  group(
    'perft on Kiwipete (castling, en passant, promotions all reachable)',
    () {
      // Standard second perft-suite position, chosen because it exercises
      // castling both sides, en passant, and near-immediate promotions —
      // none of which the starting position reaches within a few plies.
      final kiwipete = ChessPosition.fromFen(
        'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1',
      );

      test('depth 1 = 48', () => expect(perft(kiwipete, 1, engine), 48));
      test('depth 2 = 2039', () => expect(perft(kiwipete, 2, engine), 2039));
      test('depth 3 = 97862', () => expect(perft(kiwipete, 3, engine), 97862));
    },
  );

  test('detects checkmate (fool\'s mate)', () {
    var position = ChessPosition.initial();
    for (final uci in ['f2f3', 'e7e5', 'g2g4', 'd8h4']) {
      final from = uci.substring(0, 2);
      final to = uci.substring(2, 4);
      final move = engine
          .legalMoves(position)
          .firstWhere((m) => m.from.algebraic == from && m.to.algebraic == to);
      position = position.applyMove(move);
    }
    expect(engine.status(position), GameStatus.checkmate);
  });

  test('detects stalemate', () {
    // King on a1 boxed in by its own edge, black king+queen deliver
    // stalemate (no check, no legal moves).
    final position = ChessPosition.fromFen('k7/8/1Q6/8/8/8/8/K7 b - - 0 1');
    expect(engine.isInCheck(position, position.sideToMove), isFalse);
    expect(engine.status(position), GameStatus.stalemate);
  });

  test('round-trips FEN after a promotion', () {
    final position = ChessPosition.fromFen('8/P7/8/8/8/8/8/k6K w - - 0 1');
    final promo = engine
        .legalMoves(position)
        .firstWhere((m) => m.promotion != null && m.to.algebraic == 'a8');
    final next = position.applyMove(promo);
    expect(next.toFen().startsWith('Q7/8/8/8/8/8/8/k6K'), isTrue);
  });
}
