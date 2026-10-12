/// Checkers (English draughts) on the 8x8 board: men move one square
/// diagonally forward, captures are compulsory and chain into multi-jumps,
/// a man reaching the far row becomes a king (which ends the move), and a
/// king moves and captures one square diagonally in any direction. A player
/// who can't move (no pieces, or all blocked) loses.
///
/// The 32 playable squares are numbered 0..31 from the top left, four per
/// row: row = index ~/ 4. Dark moves first and starts at the bottom (rows
/// 5 to 7), moving up; light starts at the top and moves down. No Flutter
/// or Supabase in here, like the chess and Ludo engines.
library;

enum CheckersSide {
  /// Moves first. Plays from the bottom of the board, up.
  dark,

  /// Plays from the top, down.
  light;

  CheckersSide get opponent => this == dark ? light : dark;

  /// Which way this side's men move: -1 up the board, +1 down.
  int get forward => this == dark ? -1 : 1;
}

class CheckersPiece {
  const CheckersPiece(this.side, {this.king = false});

  final CheckersSide side;
  final bool king;

  CheckersPiece crowned() => CheckersPiece(side, king: true);

  String get char => switch ((side, king)) {
    (CheckersSide.dark, false) => 'd',
    (CheckersSide.dark, true) => 'D',
    (CheckersSide.light, false) => 'l',
    (CheckersSide.light, true) => 'L',
  };

  static CheckersPiece? fromChar(String c) => switch (c) {
    'd' => const CheckersPiece(CheckersSide.dark),
    'D' => const CheckersPiece(CheckersSide.dark, king: true),
    'l' => const CheckersPiece(CheckersSide.light),
    'L' => const CheckersPiece(CheckersSide.light, king: true),
    _ => null,
  };

  @override
  bool operator ==(Object other) =>
      other is CheckersPiece && other.side == side && other.king == king;

  @override
  int get hashCode => Object.hash(side, king);
}

int rowOf(int square) => square ~/ 4;

int colOf(int square) {
  final row = rowOf(square);
  return 2 * (square % 4) + (row.isEven ? 1 : 0);
}

/// The playable square at [row], [col], or null for a light square or off
/// the board.
int? squareAt(int row, int col) {
  if (row < 0 || row > 7 || col < 0 || col > 7) return null;
  if ((row + col).isEven) return null;
  return row * 4 + col ~/ 2;
}

/// One move: the squares the piece visits, start to finish, and the
/// squares of the pieces it jumps (in order).
class CheckersMove {
  const CheckersMove({
    required this.path,
    required this.piece,
    this.captured = const [],
    this.promotes = false,
  });

  final List<int> path;
  final CheckersPiece piece;
  final List<int> captured;

  /// A man reaching the far row: it's crowned.
  final bool promotes;

  int get from => path.first;
  int get to => path.last;
  bool get isCapture => captured.isNotEmpty;

  /// Standard-style notation with squares 1 to 32: "22-18", "11x18x25".
  String get notation =>
      path.map((s) => '${s + 1}').join(isCapture ? 'x' : '-');

  @override
  String toString() => notation;
}

class CheckersPosition {
  CheckersPosition({
    required this.squares,
    required this.toMove,
    this.quietPlies = 0,
  }) : assert(squares.length == 32);

  final List<CheckersPiece?> squares;
  final CheckersSide toMove;

  /// Plies since the last capture or man move. 80 (forty moves each with
  /// only kings shuffling) is a draw.
  final int quietPlies;

  factory CheckersPosition.initial() => CheckersPosition(
    squares: [
      for (var i = 0; i < 32; i++)
        i < 12
            ? const CheckersPiece(CheckersSide.light)
            : i >= 20
            ? const CheckersPiece(CheckersSide.dark)
            : null,
    ],
    toMove: CheckersSide.dark,
  );

  CheckersPiece? at(int square) => squares[square];

  /// "dddd...llll d 0": the 32 squares, whose move it is, and the quiet
  /// count. Stored in the shared matches table's board column.
  String encode() =>
      '${squares.map((p) => p?.char ?? '.').join()} '
      '${toMove == CheckersSide.dark ? 'd' : 'l'} $quietPlies';

  factory CheckersPosition.decode(String text) {
    final parts = text.trim().split(RegExp(r'\s+'));
    final cells = parts[0];
    return CheckersPosition(
      squares: [for (var i = 0; i < 32; i++) CheckersPiece.fromChar(cells[i])],
      toMove: parts.length > 1 && parts[1] == 'l'
          ? CheckersSide.light
          : CheckersSide.dark,
      quietPlies: parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0,
    );
  }

  static final String initialCode = CheckersPosition.initial().encode();

  CheckersPosition apply(CheckersMove move) {
    final next = [...squares];
    final piece = next[move.from]!;
    next[move.from] = null;
    for (final c in move.captured) {
      next[c] = null;
    }
    next[move.to] = move.promotes ? piece.crowned() : piece;
    final quiet = move.isCapture || !piece.king ? 0 : quietPlies + 1;
    return CheckersPosition(
      squares: next,
      toMove: toMove.opponent,
      quietPlies: quiet,
    );
  }

  int count(CheckersSide side, {bool? kings}) {
    var n = 0;
    for (final p in squares) {
      if (p == null || p.side != side) continue;
      if (kings == null || p.king == kings) n++;
    }
    return n;
  }
}

enum CheckersStatus { ongoing, darkWins, lightWins, draw }

class CheckersEngine {
  const CheckersEngine();

  static const _dirs = [(-1, -1), (-1, 1), (1, -1), (1, 1)];

  /// Every legal move for the side to move. If any capture exists, only
  /// captures are legal (each a complete multi-jump).
  List<CheckersMove> legalMoves(CheckersPosition p) {
    final captures = <CheckersMove>[];
    for (var s = 0; s < 32; s++) {
      final piece = p.squares[s];
      if (piece == null || piece.side != p.toMove) continue;
      _jumps(p, s, piece, [s], [], captures);
    }
    if (captures.isNotEmpty) return captures;

    final moves = <CheckersMove>[];
    for (var s = 0; s < 32; s++) {
      final piece = p.squares[s];
      if (piece == null || piece.side != p.toMove) continue;
      for (final (dr, dc) in _dirs) {
        if (!piece.king && dr != piece.side.forward) continue;
        final to = squareAt(rowOf(s) + dr, colOf(s) + dc);
        if (to == null || p.squares[to] != null) continue;
        moves.add(
          CheckersMove(
            path: [s, to],
            piece: piece,
            promotes: !piece.king && _isKingRow(piece.side, to),
          ),
        );
      }
    }
    return moves;
  }

  /// Squares holding a piece that has a legal move right now (all of them
  /// capture when a capture is on).
  Set<int> movablePieces(CheckersPosition p) => {
    for (final m in legalMoves(p)) m.from,
  };

  bool _isKingRow(CheckersSide side, int square) =>
      side == CheckersSide.dark ? rowOf(square) == 0 : rowOf(square) == 7;

  /// Extends a jump sequence from [path].last as far as it goes; each
  /// finished sequence is a move.
  void _jumps(
    CheckersPosition p,
    int origin,
    CheckersPiece piece,
    List<int> path,
    List<int> taken,
    List<CheckersMove> out,
  ) {
    final at = path.last;
    var extended = false;
    for (final (dr, dc) in _dirs) {
      if (!piece.king && dr != piece.side.forward) continue;
      final over = squareAt(rowOf(at) + dr, colOf(at) + dc);
      final land = squareAt(rowOf(at) + 2 * dr, colOf(at) + 2 * dc);
      if (over == null || land == null) continue;
      final victim = p.squares[over];
      if (victim == null || victim.side == piece.side) continue;
      if (taken.contains(over)) continue;
      // The landing square must be empty; the mover's own start square
      // counts as empty (it has left it).
      if (p.squares[land] != null && land != origin) continue;
      extended = true;
      final nextPath = [...path, land];
      final nextTaken = [...taken, over];
      if (!piece.king && _isKingRow(piece.side, land)) {
        // Crowned: the move ends here.
        out.add(
          CheckersMove(
            path: nextPath,
            piece: piece,
            captured: nextTaken,
            promotes: true,
          ),
        );
      } else {
        _jumps(p, origin, piece, nextPath, nextTaken, out);
      }
    }
    if (!extended && taken.isNotEmpty) {
      out.add(CheckersMove(path: path, piece: piece, captured: taken));
    }
  }

  CheckersStatus status(CheckersPosition p) {
    if (legalMoves(p).isEmpty) {
      return p.toMove == CheckersSide.dark
          ? CheckersStatus.lightWins
          : CheckersStatus.darkWins;
    }
    if (p.quietPlies >= 80) return CheckersStatus.draw;
    return CheckersStatus.ongoing;
  }
}
