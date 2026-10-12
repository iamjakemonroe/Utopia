import 'chess_move.dart';
import 'chess_position.dart';
import 'chess_types.dart';

enum GameStatus { ongoing, check, checkmate, stalemate, draw }

const List<Square> _knightOffsets = [
  Square(1, 2),
  Square(2, 1),
  Square(2, -1),
  Square(1, -2),
  Square(-1, -2),
  Square(-2, -1),
  Square(-2, 1),
  Square(-1, 2),
];

const List<Square> _kingOffsets = [
  Square(1, 0),
  Square(1, 1),
  Square(0, 1),
  Square(-1, 1),
  Square(-1, 0),
  Square(-1, -1),
  Square(0, -1),
  Square(1, -1),
];

const List<Square> _bishopDirs = [
  Square(1, 1),
  Square(1, -1),
  Square(-1, 1),
  Square(-1, -1),
];
const List<Square> _rookDirs = [
  Square(1, 0),
  Square(-1, 0),
  Square(0, 1),
  Square(0, -1),
];

const List<PieceType> promotionChoices = [
  PieceType.queen,
  PieceType.rook,
  PieceType.bishop,
  PieceType.knight,
];

/// Stateless chess rules engine: legal move generation, check/checkmate/
/// stalemate detection, and SAN notation. Operates purely on [ChessPosition]
/// values — no game/session state lives here, so it's trivially the same
/// engine both players' clients run to stay in sync (see the migration's
/// note on why that sync, not a server-side replica, is the v1 trust model).
class ChessEngine {
  const ChessEngine();

  /// All fully legal moves for the side to move (pseudo-legal moves that
  /// don't leave that side's own king in check).
  List<ChessMove> legalMoves(ChessPosition position) {
    final color = position.sideToMove;
    final pseudo = _pseudoLegalMoves(position, color);
    return pseudo.where((move) {
      final next = position.applyMove(move);
      return !isInCheck(next, color);
    }).toList();
  }

  /// Legal captures (and promotions) only. Cheaper than filtering
  /// [legalMoves], since only these are checked for legality; the bot's
  /// search uses it to settle exchanges.
  List<ChessMove> legalCaptures(ChessPosition position) {
    final color = position.sideToMove;
    return [
      for (final move in _pseudoLegalMoves(position, color))
        if ((move.isCapture || move.promotion != null) &&
            !isInCheck(position.applyMove(move), color))
          move,
    ];
  }

  bool isInCheck(ChessPosition position, PieceColor color) {
    final kingSquare = _findKing(position, color);
    if (kingSquare == null) return false; // shouldn't happen in a real game
    return isSquareAttacked(position, kingSquare, color.opponent);
  }

  GameStatus status(ChessPosition position) {
    final inCheck = isInCheck(position, position.sideToMove);
    final hasMoves = legalMoves(position).isNotEmpty;

    if (!hasMoves) {
      return inCheck ? GameStatus.checkmate : GameStatus.stalemate;
    }
    if (position.halfmoveClock >= 100 || _hasInsufficientMaterial(position)) {
      return GameStatus.draw;
    }
    return inCheck ? GameStatus.check : GameStatus.ongoing;
  }

  /// SAN (e.g. "Nf3", "exd5", "O-O", "e8=Q+") for [move] played from
  /// [position]. Must be called with [position] *before* the move is
  /// applied — disambiguation depends on the other legal moves available
  /// at that position.
  String toSan(ChessPosition position, ChessMove move) {
    if (move.flag == MoveFlag.castleKingside) {
      return _withCheckSuffix(position, move, 'O-O');
    }
    if (move.flag == MoveFlag.castleQueenside) {
      return _withCheckSuffix(position, move, 'O-O-O');
    }

    final buffer = StringBuffer();
    final isPawn = move.piece.type == PieceType.pawn;

    if (!isPawn) {
      buffer.write(move.piece.type.letter);
      buffer.write(_disambiguation(position, move));
    } else if (move.isCapture) {
      buffer.write(String.fromCharCode('a'.codeUnitAt(0) + move.from.file));
    }

    if (move.isCapture) buffer.write('x');
    buffer.write(move.to.algebraic);
    if (move.promotion != null) buffer.write('=${move.promotion!.letter}');

    return _withCheckSuffix(position, move, buffer.toString());
  }

  String _withCheckSuffix(ChessPosition position, ChessMove move, String base) {
    final next = position.applyMove(move);
    final inCheck = isInCheck(next, next.sideToMove);
    if (!inCheck) return base;
    final isMate = legalMoves(next).isEmpty;
    return '$base${isMate ? '#' : '+'}';
  }

  String _disambiguation(ChessPosition position, ChessMove move) {
    final others = _pseudoLegalMoves(position, move.piece.color).where((m) {
      if (m.piece.type != move.piece.type ||
          m.to != move.to ||
          m.from == move.from) {
        return false;
      }
      final next = position.applyMove(m);
      return !isInCheck(next, move.piece.color);
    });

    if (others.isEmpty) return '';

    final sameFile = others.any((m) => m.from.file == move.from.file);
    final sameRank = others.any((m) => m.from.rank == move.from.rank);

    if (!sameFile) {
      return String.fromCharCode('a'.codeUnitAt(0) + move.from.file);
    }
    if (!sameRank) return '${move.from.rank + 1}';
    return move.from.algebraic;
  }

  Square? _findKing(ChessPosition position, PieceColor color) {
    for (var rank = 0; rank < 8; rank++) {
      for (var file = 0; file < 8; file++) {
        final piece = position.board[rank][file];
        if (piece != null &&
            piece.type == PieceType.king &&
            piece.color == color) {
          return Square(file, rank);
        }
      }
    }
    return null;
  }

  bool _hasInsufficientMaterial(ChessPosition position) {
    final pieces = <ChessPiece>[];
    for (final rank in position.board) {
      for (final piece in rank) {
        if (piece != null && piece.type != PieceType.king) pieces.add(piece);
      }
    }
    if (pieces.isEmpty) return true; // K v K
    if (pieces.length == 1 &&
        (pieces[0].type == PieceType.bishop ||
            pieces[0].type == PieceType.knight)) {
      return true; // K+minor v K
    }
    return false;
  }

  /// True if [square] is attacked by any piece of [byColor], independent of
  /// whose turn it is. Used both for check detection and for validating
  /// castling squares — deliberately does not call [legalMoves] (which
  /// itself depends on this) to avoid recursion.
  bool isSquareAttacked(
    ChessPosition position,
    Square square,
    PieceColor byColor,
  ) {
    // Pawns: attack diagonally forward from the attacker's perspective, so
    // check the squares a pawn of byColor would need to stand on to hit us.
    final pawnDir = byColor == PieceColor.white ? -1 : 1;
    for (final df in [-1, 1]) {
      final from = Square(square.file + df, square.rank + pawnDir);
      final piece = position.at(from);
      if (piece != null &&
          piece.type == PieceType.pawn &&
          piece.color == byColor) {
        return true;
      }
    }

    for (final offset in _knightOffsets) {
      final piece = position.at(square + offset);
      if (piece != null &&
          piece.type == PieceType.knight &&
          piece.color == byColor) {
        return true;
      }
    }

    for (final offset in _kingOffsets) {
      final piece = position.at(square + offset);
      if (piece != null &&
          piece.type == PieceType.king &&
          piece.color == byColor) {
        return true;
      }
    }

    for (final dir in _bishopDirs) {
      var s = square + dir;
      while (s.isOnBoard) {
        final piece = position.at(s);
        if (piece != null) {
          if (piece.color == byColor &&
              (piece.type == PieceType.bishop ||
                  piece.type == PieceType.queen)) {
            return true;
          }
          break;
        }
        s = s + dir;
      }
    }

    for (final dir in _rookDirs) {
      var s = square + dir;
      while (s.isOnBoard) {
        final piece = position.at(s);
        if (piece != null) {
          if (piece.color == byColor &&
              (piece.type == PieceType.rook || piece.type == PieceType.queen)) {
            return true;
          }
          break;
        }
        s = s + dir;
      }
    }

    return false;
  }

  List<ChessMove> _pseudoLegalMoves(ChessPosition position, PieceColor color) {
    final moves = <ChessMove>[];
    for (var rank = 0; rank < 8; rank++) {
      for (var file = 0; file < 8; file++) {
        final piece = position.board[rank][file];
        if (piece == null || piece.color != color) continue;
        final from = Square(file, rank);
        switch (piece.type) {
          case PieceType.pawn:
            moves.addAll(_pawnMoves(position, from, piece));
          case PieceType.knight:
            moves.addAll(_offsetMoves(position, from, piece, _knightOffsets));
          case PieceType.bishop:
            moves.addAll(_slidingMoves(position, from, piece, _bishopDirs));
          case PieceType.rook:
            moves.addAll(_slidingMoves(position, from, piece, _rookDirs));
          case PieceType.queen:
            moves.addAll(
              _slidingMoves(position, from, piece, [
                ..._bishopDirs,
                ..._rookDirs,
              ]),
            );
          case PieceType.king:
            moves.addAll(_offsetMoves(position, from, piece, _kingOffsets));
            moves.addAll(_castlingMoves(position, from, piece));
        }
      }
    }
    return moves;
  }

  List<ChessMove> _pawnMoves(
    ChessPosition position,
    Square from,
    ChessPiece piece,
  ) {
    final moves = <ChessMove>[];
    final dir = piece.color == PieceColor.white ? 1 : -1;
    final startRank = piece.color == PieceColor.white ? 1 : 6;
    final promoRank = piece.color == PieceColor.white ? 7 : 0;

    void addForwardOrPromotion(
      Square to, {
      ChessPiece? captured,
      MoveFlag flag = MoveFlag.normal,
    }) {
      if (to.rank == promoRank) {
        for (final promo in promotionChoices) {
          moves.add(
            ChessMove(
              from: from,
              to: to,
              piece: piece,
              captured: captured,
              promotion: promo,
              flag: MoveFlag.promotion,
            ),
          );
        }
      } else {
        moves.add(
          ChessMove(
            from: from,
            to: to,
            piece: piece,
            captured: captured,
            flag: flag,
          ),
        );
      }
    }

    final oneStep = Square(from.file, from.rank + dir);
    if (oneStep.isOnBoard && position.at(oneStep) == null) {
      addForwardOrPromotion(oneStep);

      final twoStep = Square(from.file, from.rank + 2 * dir);
      if (from.rank == startRank && position.at(twoStep) == null) {
        moves.add(
          ChessMove(
            from: from,
            to: twoStep,
            piece: piece,
            flag: MoveFlag.doublePawnPush,
          ),
        );
      }
    }

    for (final df in [-1, 1]) {
      final to = Square(from.file + df, from.rank + dir);
      if (!to.isOnBoard) continue;
      final target = position.at(to);
      if (target != null && target.color != piece.color) {
        addForwardOrPromotion(to, captured: target);
      } else if (target == null && to == position.enPassantTarget) {
        moves.add(
          ChessMove(
            from: from,
            to: to,
            piece: piece,
            captured: const ChessPiece(PieceType.pawn, PieceColor.white),
            flag: MoveFlag.enPassant,
          ),
        );
      }
    }

    return moves;
  }

  List<ChessMove> _offsetMoves(
    ChessPosition position,
    Square from,
    ChessPiece piece,
    List<Square> offsets,
  ) {
    final moves = <ChessMove>[];
    for (final offset in offsets) {
      final to = from + offset;
      if (!to.isOnBoard) continue;
      final target = position.at(to);
      if (target == null || target.color != piece.color) {
        moves.add(
          ChessMove(from: from, to: to, piece: piece, captured: target),
        );
      }
    }
    return moves;
  }

  List<ChessMove> _slidingMoves(
    ChessPosition position,
    Square from,
    ChessPiece piece,
    List<Square> dirs,
  ) {
    final moves = <ChessMove>[];
    for (final dir in dirs) {
      var to = from + dir;
      while (to.isOnBoard) {
        final target = position.at(to);
        if (target == null) {
          moves.add(ChessMove(from: from, to: to, piece: piece));
        } else {
          if (target.color != piece.color) {
            moves.add(
              ChessMove(from: from, to: to, piece: piece, captured: target),
            );
          }
          break;
        }
        to = to + dir;
      }
    }
    return moves;
  }

  List<ChessMove> _castlingMoves(
    ChessPosition position,
    Square from,
    ChessPiece piece,
  ) {
    final moves = <ChessMove>[];
    final rank = piece.color == PieceColor.white ? 0 : 7;
    if (from != Square(4, rank)) {
      return moves; // king must be on its home square
    }
    final opponent = piece.color.opponent;

    final canKingside = piece.color == PieceColor.white
        ? position.whiteKingside
        : position.blackKingside;
    final canQueenside = piece.color == PieceColor.white
        ? position.whiteQueenside
        : position.blackQueenside;

    if (isSquareAttacked(position, from, opponent)) {
      return moves; // can't castle out of check
    }

    if (canKingside &&
        position.at(Square(5, rank)) == null &&
        position.at(Square(6, rank)) == null &&
        !isSquareAttacked(position, Square(5, rank), opponent) &&
        !isSquareAttacked(position, Square(6, rank), opponent)) {
      moves.add(
        ChessMove(
          from: from,
          to: Square(6, rank),
          piece: piece,
          flag: MoveFlag.castleKingside,
        ),
      );
    }

    if (canQueenside &&
        position.at(Square(3, rank)) == null &&
        position.at(Square(2, rank)) == null &&
        position.at(Square(1, rank)) == null &&
        !isSquareAttacked(position, Square(3, rank), opponent) &&
        !isSquareAttacked(position, Square(2, rank), opponent)) {
      moves.add(
        ChessMove(
          from: from,
          to: Square(2, rank),
          piece: piece,
          flag: MoveFlag.castleQueenside,
        ),
      );
    }

    return moves;
  }
}
