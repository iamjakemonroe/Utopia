import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/checkers/domain/checkers_bot.dart';
import 'package:utopia/features/checkers/domain/checkers_engine.dart';

const engine = CheckersEngine();

/// A board from a picture: row strings top to bottom, using only the
/// playable (odd) squares. "d"/"D" dark man/king, "l"/"L" light, "." empty.
CheckersPosition board(
  List<String> rows, {
  CheckersSide toMove = CheckersSide.dark,
}) {
  final squares = List<CheckersPiece?>.filled(32, null);
  for (var r = 0; r < 8; r++) {
    for (var c = 0; c < 8; c++) {
      final ch = rows[r][c];
      final s = squareAt(r, c);
      if (s == null) continue;
      squares[s] = CheckersPiece.fromChar(ch);
    }
  }
  return CheckersPosition(squares: squares, toMove: toMove);
}

void main() {
  test('the opening: 12 each, dark has 7 moves', () {
    final p = CheckersPosition.initial();
    expect(p.count(CheckersSide.dark), 12);
    expect(p.count(CheckersSide.light), 12);
    expect(engine.legalMoves(p), hasLength(7));
    expect(engine.status(p), CheckersStatus.ongoing);
  });

  test('round-trips through its text form', () {
    final p = CheckersPosition.initial();
    final again = CheckersPosition.decode(p.encode());
    expect(again.encode(), p.encode());
    expect(p.encode().split(' ').first, hasLength(32));
  });

  test('captures are compulsory', () {
    final p = board([
      '........',
      '........',
      '........',
      '........',
      '...l....',
      '..d.....',
      '.......d',
      '........',
    ]);
    final moves = engine.legalMoves(p);
    expect(moves, hasLength(1));
    expect(moves.single.isCapture, isTrue);
  });

  test('jumps chain into a multi-jump', () {
    final p = board([
      '........',
      '........',
      '.....l..',
      '........',
      '...l....',
      '..d.....',
      '........',
      '........',
    ]);
    final moves = engine.legalMoves(p);
    expect(moves, hasLength(1));
    expect(moves.single.captured, hasLength(2));
    final after = p.apply(moves.single);
    expect(after.count(CheckersSide.light), 0);
  });

  test('a man that reaches the far row is crowned, and the move ends', () {
    final p = board([
      '........',
      '..l.....',
      '...d....',
      '........',
      '........',
      '........',
      '........',
      '........',
    ]);
    final moves = engine.legalMoves(p);
    expect(moves.single.promotes, isTrue);
    final after = p.apply(moves.single);
    expect(after.at(moves.single.to)!.king, isTrue);
  });

  test('men only move forward; kings go both ways', () {
    final man = board([
      '........',
      '........',
      '........',
      '..d.....',
      '........',
      '........',
      '........',
      '........',
    ]);
    expect(engine.legalMoves(man), hasLength(2));
    final king = board([
      '........',
      '........',
      '........',
      '..D.....',
      '........',
      '........',
      '........',
      '........',
    ]);
    expect(engine.legalMoves(king), hasLength(4));
  });

  test('no moves left means a loss', () {
    final p = board([
      '........',
      '........',
      '........',
      '........',
      '........',
      '........',
      '........',
      'l.......',
    ]);
    expect(engine.status(p), CheckersStatus.lightWins);
  });

  test('the bot takes a double jump over a single', () {
    final p = board([
      '........',
      '........',
      '.....l..',
      '........',
      '...l....',
      '..d.....',
      '.......d',
      '........',
    ]);
    final move = CheckersBot(BotLevel.normal, seed: 1).choose(p)!;
    expect(move.captured, hasLength(2));
  });

  test('bots play a whole game of legal moves', () {
    var p = CheckersPosition.initial();
    final bots = [
      CheckersBot(BotLevel.easy, seed: 3),
      CheckersBot(BotLevel.normal, seed: 4),
    ];
    for (var ply = 0; ply < 200; ply++) {
      if (engine.status(p) != CheckersStatus.ongoing) break;
      final move = bots[ply % 2].choose(p)!;
      expect(
        engine.legalMoves(p).map((m) => m.notation),
        contains(move.notation),
      );
      p = p.apply(move);
    }
  });

  test('hard thinks within its budget', () {
    final watch = Stopwatch()..start();
    expect(
      CheckersBot(BotLevel.hard, seed: 5).choose(CheckersPosition.initial()),
      isNotNull,
    );
    expect(watch.elapsed, lessThan(const Duration(seconds: 4)));
  });
}
