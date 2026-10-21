import '../../checkers/domain/checkers_engine.dart';
import '../../chess/domain/chess_engine.dart';
import '../../chess/domain/chess_position.dart';
import '../../chess/domain/chess_types.dart';

/// The server's referee for online chess and checkers: whether a player's
/// move is legal in the match's position, and if so the position after it,
/// its notation, and whether it ends the game. Plain Dart (the apps' own
/// rules), compiled to JavaScript for the board-move function
/// (lib/web_workers/house_brain_js.dart).
///
/// [position] is the match's board (a FEN for chess, the board code for
/// checkers). A chess move is [from] and [to] squares ("e2", "e4") and a
/// [promotion] letter ("q"); a checkers move is squares 1 to 32, its
/// [notation] ("11x18x25") telling apart two jumps between the same
/// squares.
///
/// Returns `{legal: false}`, or `{legal: true, san, fen_after, over}` with
/// `over` null, or `{winner: 'white'|'black'|null, result}`.
Map<String, Object?> refereeMove({
  required String game,
  required String position,
  required String from,
  required String to,
  String? promotion,
  String? notation,
}) {
  try {
    return game == 'checkers'
        ? _checkers(position, from, to, notation)
        : _chess(position, from, to, promotion);
  } catch (_) {
    // A position or move that doesn't even parse.
    return const {'legal': false};
  }
}

const _chessEngine = ChessEngine();

Map<String, Object?> _chess(
  String fen,
  String from,
  String to,
  String? promotion,
) {
  final before = ChessPosition.fromFen(fen);
  final wanted = promotion?.toLowerCase();
  final move = _chessEngine
      .legalMoves(before)
      .where(
        (m) =>
            m.from.algebraic == from &&
            m.to.algebraic == to &&
            m.promotion?.letter.toLowerCase() == wanted,
      )
      .firstOrNull;
  if (move == null) return const {'legal': false};
  final after = before.applyMove(move);
  final status = _chessEngine.status(after);
  return {
    'legal': true,
    'san': _chessEngine.toSan(before, move),
    'fen_after': after.toFen(),
    'over': switch (status) {
      GameStatus.ongoing || GameStatus.check => null,
      GameStatus.checkmate => {
        'winner': after.sideToMove == PieceColor.white ? 'black' : 'white',
        'result': 'checkmate',
      },
      GameStatus.stalemate => {'winner': null, 'result': 'stalemate'},
      _ => {'winner': null, 'result': 'draw'},
    },
  };
}

const _checkersEngine = CheckersEngine();

Map<String, Object?> _checkers(
  String code,
  String from,
  String to,
  String? notation,
) {
  final before = CheckersPosition.decode(code);
  final matches = [
    for (final m in _checkersEngine.legalMoves(before))
      if ('${m.from + 1}' == from && '${m.to + 1}' == to) m,
  ];
  // Two jumps between the same squares: the notation says which.
  final move = matches.length > 1
      ? matches.where((m) => m.notation == notation).firstOrNull
      : matches.firstOrNull;
  if (move == null) return const {'legal': false};
  final after = before.apply(move);
  return {
    'legal': true,
    'san': move.notation,
    'fen_after': after.encode(),
    // Dark moves first and sits in player_white.
    'over': switch (_checkersEngine.status(after)) {
      CheckersStatus.ongoing => null,
      CheckersStatus.darkWins => {'winner': 'white', 'result': 'win'},
      CheckersStatus.lightWins => {'winner': 'black', 'result': 'win'},
      _ => {'winner': null, 'result': 'draw'},
    },
  };
}
