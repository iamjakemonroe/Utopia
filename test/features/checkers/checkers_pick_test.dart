import 'package:flutter_test/flutter_test.dart';
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
      final s = squareAt(r, c);
      if (s == null) continue;
      squares[s] = CheckersPiece.fromChar(rows[r][c]);
    }
  }
  return CheckersPosition(squares: squares, toMove: toMove);
}

int sq(int row, int col) => squareAt(row, col)!;

void main() {
  // A dark man that must take two light men, one hop after the other.
  final double = board([
    '........',
    '........',
    '.....l..',
    '........',
    '...l....',
    '..d.....',
    '........',
    '........',
  ]);

  test('a double capture is made hop by hop, as on a real board', () {
    final legal = engine.legalMoves(double);
    var pick = CheckersPick.none.tap(sq(5, 2), legal).pick;
    expect(pick.selected, sq(5, 2));
    expect(pick.targets(legal).map((m) => m.to), [sq(3, 4)]);
    expect(pick.targets(legal).single.captured, [sq(4, 3)]);

    // First hop: the piece lands, the first man is gone, it must jump again.
    final first = pick.tap(sq(3, 4), legal);
    expect(first.play, isNull);
    expect(first.hop!.path, [sq(5, 2), sq(3, 4)]);
    pick = first.pick;
    expect(pick.hopping, isTrue);
    final mid = pick.board(double, legal);
    expect(mid.at(sq(3, 4))?.side, CheckersSide.dark);
    expect(mid.at(sq(4, 3)), isNull);
    expect(mid.at(sq(2, 5))?.side, CheckersSide.light);
    expect(mid.toMove, CheckersSide.dark);
    expect(pick.targets(legal).map((m) => m.to), [sq(1, 6)]);

    // Second hop: the whole move is played; only that hop flies.
    final second = pick.tap(sq(1, 6), legal);
    expect(second.play!.captured, [sq(4, 3), sq(2, 5)]);
    expect(second.hop!.path, [sq(3, 4), sq(1, 6)]);
    expect(second.pick.selected, isNull);
    expect(double.apply(second.play!).count(CheckersSide.light), 0);
  });

  test('tapping where the whole jump ends still plays it at once', () {
    final legal = engine.legalMoves(double);
    final pick = CheckersPick.none.tap(sq(5, 2), legal).pick;
    final tap = pick.tap(sq(1, 6), legal);
    expect(tap.play!.captured, hasLength(2));
    expect(tap.hop, isNull, reason: 'the whole move flies');
  });

  test('partway through, the rest of the jump can be tapped at once too', () {
    final legal = engine.legalMoves(double);
    final hopping = CheckersPick([sq(5, 2), sq(3, 4)]);
    final tap = hopping.tap(sq(1, 6), legal);
    expect(tap.play!.captured, hasLength(2));
    expect(tap.hop!.path, [sq(3, 4), sq(1, 6)]);
  });

  test('mid-capture: other squares do nothing; the piece itself takes the hops back', () {
    final legal = engine.legalMoves(double);
    final hopping = CheckersPick([sq(5, 2), sq(3, 4)]);
    final elsewhere = hopping.tap(sq(7, 0), legal);
    expect(elsewhere.play, isNull);
    expect(elsewhere.pick.path, hopping.path);
    final back = hopping.tap(sq(3, 4), legal);
    expect(back.pick.path, [sq(5, 2)]);
    expect(back.pick.board(double, legal).encode(), double.encode());
  });

  test('two ways to jump: both first hops are offered, then the chosen route', () {
    // Over (4,1) to (3,0) ends there; over (4,3) to (3,4) goes on over (2,5).
    final fork = board([
      '........',
      '........',
      '.....l..',
      '........',
      '.l.l....',
      '..d.....',
      '........',
      '........',
    ]);
    final legal = engine.legalMoves(fork);
    final pick = CheckersPick.none.tap(sq(5, 2), legal).pick;
    expect(pick.targets(legal).map((m) => m.to).toSet(), {sq(3, 0), sq(3, 4)});

    final short = pick.tap(sq(3, 0), legal);
    expect(short.play!.captured, [sq(4, 1)]);

    final long = pick.tap(sq(3, 4), legal);
    expect(long.play, isNull);
    expect(long.pick.targets(legal).map((m) => m.to), [sq(1, 6)]);
    expect(long.pick.tap(sq(1, 6), legal).play!.captured, [sq(4, 3), sq(2, 5)]);
  });

  test('a man crowned by a jump stops there', () {
    final crown = board([
      '........',
      '..l.l...',
      '...d....',
      '........',
      '........',
      '........',
      '........',
      '........',
    ]);
    final legal = engine.legalMoves(crown);
    final pick = CheckersPick.none.tap(sq(2, 3), legal).pick;
    final tap = pick.tap(pick.targets(legal).first.to, legal);
    expect(tap.play, isNotNull);
    expect(tap.play!.promotes, isTrue);
    expect(tap.play!.captured, hasLength(1));
  });

  test('a plain move: pick, then tap the square; tapping the piece again lets go', () {
    final p = CheckersPosition.initial();
    final legal = engine.legalMoves(p);
    final from = sq(5, 0);
    var pick = CheckersPick.none.tap(from, legal).pick;
    expect(pick.selected, from);
    final to = pick.targets(legal).single.to;
    final tap = pick.tap(to, legal);
    expect(tap.play!.path, [from, to]);
    expect(tap.hop!.path, [from, to]);
    expect(pick.tap(from, legal).pick.selected, isNull);
    // Another piece that can move takes over the pick.
    pick = pick.tap(sq(5, 2), legal).pick;
    expect(pick.selected, sq(5, 2));
    // A square nothing can reach lets go.
    expect(pick.tap(sq(3, 0), legal).pick.selected, isNull);
  });
}
