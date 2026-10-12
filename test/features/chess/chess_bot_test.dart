import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/chess/domain/chess_bot.dart';
import 'package:utopia/features/chess/domain/chess_engine.dart';
import 'package:utopia/features/chess/domain/chess_position.dart';

void main() {
  const engine = ChessEngine();

  test('finds a mate in one', () {
    // White to move: Qh5xf7 is mate (scholar's mate setup).
    final p = ChessPosition.fromFen(
      'r1bqkbnr/pppp1ppp/2n5/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4',
    );
    for (final level in [BotLevel.normal, BotLevel.hard]) {
      final move = ChessBot(level, seed: 1).choose(p)!;
      expect(move.toString(), 'h5f7', reason: level.name);
      expect(engine.status(p.applyMove(move)), GameStatus.checkmate);
    }
  });

  test('takes a free queen', () {
    // Black's queen on d4 hangs to the knight on f3.
    final p = ChessPosition.fromFen(
      'rnb1kbnr/pppp1ppp/8/4p3/3q4/5N2/PPPPPPPP/RNBQKB1R w KQkq - 0 3',
    );
    final move = ChessBot(BotLevel.hard, seed: 2).choose(p)!;
    expect(move.toString(), 'f3d4');
  });

  test('no move when the game is over', () {
    final mated = ChessPosition.fromFen(
      'rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3',
    );
    expect(ChessBot(BotLevel.hard).choose(mated), isNull);
  });

  test('hard thinks within its time budget', () {
    final watch = Stopwatch()..start();
    final move = ChessBot(
      BotLevel.hard,
      seed: 3,
    ).choose(ChessPosition.initial());
    expect(move, isNotNull);
    // 1.5s budget, plus finishing the move it's on.
    expect(watch.elapsed, lessThan(const Duration(seconds: 4)));
  });

  test('every level plays a whole game of legal moves', () {
    var p = ChessPosition.initial();
    final bots = [
      ChessBot(BotLevel.easy, seed: 4),
      ChessBot(BotLevel.normal, seed: 5),
    ];
    for (var ply = 0; ply < 60; ply++) {
      final status = engine.status(p);
      if (status == GameStatus.checkmate ||
          status == GameStatus.stalemate ||
          status == GameStatus.draw) {
        break;
      }
      final move = bots[ply % 2].choose(p)!;
      expect(
        engine.legalMoves(p).map((m) => m.toString()),
        contains(move.toString()),
      );
      p = p.applyMove(move);
    }
  });
}
