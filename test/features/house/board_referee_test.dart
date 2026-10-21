import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/checkers/domain/checkers_engine.dart';
import 'package:utopia/features/house/domain/board_referee.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

Map<String, Object?> chess(String fen, String from, String to, [String? p]) =>
    refereeMove(
      game: 'chess',
      position: fen,
      from: from,
      to: to,
      promotion: p,
    );

void main() {
  group('chess', () {
    test('a legal move: its notation and the position after', () {
      final r = chess(_start, 'e2', 'e4');
      expect(r['legal'], isTrue);
      expect(r['san'], 'e4');
      expect(
        r['fen_after'] as String,
        startsWith('rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b'),
      );
      expect(r['over'], isNull);
    });

    test("a move the rules don't allow isn't", () {
      expect(chess(_start, 'e2', 'e5')['legal'], isFalse);
      expect(chess(_start, 'e7', 'e5')['legal'], isFalse, reason: 'not your piece');
      expect(chess('not a position', 'e2', 'e4')['legal'], isFalse);
    });

    test('a pawn on the last row must say what it becomes', () {
      const fen = '7k/4P3/8/8/8/8/8/4K3 w - - 0 1';
      expect(chess(fen, 'e7', 'e8')['legal'], isFalse);
      final queen = chess(fen, 'e7', 'e8', 'q');
      expect(queen['legal'], isTrue);
      expect(queen['san'], contains('=Q'));
    });

    test("checkmate ends the game, for the one who gave it", () {
      // Fool's mate: 1. f3 e5 2. g4, and black's queen mates.
      const fen =
          'rnbqkbnr/pppp1ppp/8/4p3/6P1/5P2/PPPPP2P/RNBQKBNR b KQkq g3 0 2';
      final r = chess(fen, 'd8', 'h4');
      expect(r['legal'], isTrue);
      expect(r['over'], {'winner': 'black', 'result': 'checkmate'});
    });
  });

  group('checkers', () {
    test('any legal move is taken, with its position after', () {
      const engine = CheckersEngine();
      final start = CheckersPosition.initial();
      final move = engine.legalMoves(start).first;
      final r = refereeMove(
        game: 'checkers',
        position: CheckersPosition.initialCode,
        from: '${move.from + 1}',
        to: '${move.to + 1}',
        notation: move.notation,
      );
      expect(r['legal'], isTrue);
      expect(r['fen_after'], start.apply(move).encode());
      expect(r['san'], move.notation);
    });

    test("a square nothing can move from isn't", () {
      final r = refereeMove(
        game: 'checkers',
        position: CheckersPosition.initialCode,
        from: '1',
        to: '32',
      );
      expect(r['legal'], isFalse);
    });
  });
}
