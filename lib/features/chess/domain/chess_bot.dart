import 'dart:isolate';
import 'dart:math';

import 'chess_engine.dart';
import 'chess_move.dart';
import 'chess_position.dart';
import 'chess_types.dart';

/// How strong the computer plays.
enum BotLevel {
  /// Looks one move ahead and often picks a so-so move.
  easy,

  /// Looks a couple of moves ahead, settles exchanges, a little loose.
  normal,

  /// Searches as deep as it can in about a second and a half.
  hard,
}

const _engine = ChessEngine();

/// Picks the computer's move for [position], off the main thread so the
/// board keeps animating while it thinks. Null when there are no moves.
Future<ChessMove?> findBotMove(ChessPosition position, BotLevel level) {
  final fen = position.toFen();
  final seed = Random().nextInt(1 << 30);
  return Isolate.run(
    () => ChessBot(level, seed: seed).choose(ChessPosition.fromFen(fen)),
  );
}

/// A small chess engine: negamax with alpha-beta pruning, a capture search
/// at the leaves so it doesn't stop mid-exchange, moves ordered so the good
/// ones are tried first, and material plus piece-square tables to judge a
/// position.
class ChessBot {
  ChessBot(this.level, {int? seed}) : _rng = Random(seed);

  final BotLevel level;
  final Random _rng;
  final _clock = Stopwatch();
  late Duration _budget;

  static const _mate = 100000;

  ChessMove? choose(ChessPosition position) {
    final moves = _engine.legalMoves(position);
    if (moves.isEmpty) return null;
    if (moves.length == 1) return moves.first;

    // Easy: sometimes just plays something.
    if (level == BotLevel.easy && _rng.nextDouble() < 0.25) {
      return moves[_rng.nextInt(moves.length)];
    }

    final (maxDepth, noise, budgetMs) = switch (level) {
      BotLevel.easy => (1, 180, 400),
      BotLevel.normal => (2, 35, 900),
      BotLevel.hard => (4, 0, 1500),
    };
    _budget = Duration(milliseconds: budgetMs);
    _clock.start();

    _order(position, moves);
    var best = moves.first;
    // Iterative deepening: each finished depth is kept; running out of
    // time partway through a depth falls back to the last finished one.
    for (var depth = 1; depth <= maxDepth; depth++) {
      try {
        final scored = <(ChessMove, int)>[];
        var alpha = -_mate * 2;
        for (final move in moves) {
          // With a wobble every move needs its true score (a narrow window
          // only says "no better than the best so far", so moves would tie);
          // without one, the narrow window is faster and picks the same.
          final score = -_search(
            position.applyMove(move),
            depth - 1,
            -_mate * 2,
            noise > 0 ? _mate * 2 : -alpha,
            1,
          );
          scored.add((move, score));
          if (score > alpha) alpha = score;
        }
        // Weaker levels wobble: a random nudge per move.
        var top = scored.first;
        var topScore = -_mate * 3;
        for (final (move, score) in scored) {
          final s = score + (noise == 0 ? 0 : _rng.nextInt(noise * 2) - noise);
          if (s > topScore) {
            topScore = s;
            top = (move, score);
          }
        }
        best = top.$1;
        // Search the best move first next time round.
        moves
          ..remove(best)
          ..insert(0, best);
        if (top.$2.abs() > _mate - 100) break; // found a mate
      } on _OutOfTime {
        break;
      }
    }
    return best;
  }

  int _search(ChessPosition p, int depth, int alpha, int beta, int ply) {
    if (_clock.elapsed > _budget) throw const _OutOfTime();
    if (p.halfmoveClock >= 100) return 0;
    if (depth <= 0) return _quiesce(p, alpha, beta, 0);

    final moves = _engine.legalMoves(p);
    if (moves.isEmpty) {
      return _engine.isInCheck(p, p.sideToMove) ? -_mate + ply : 0;
    }
    _order(p, moves);
    for (final move in moves) {
      final score = -_search(
        p.applyMove(move),
        depth - 1,
        -beta,
        -alpha,
        ply + 1,
      );
      if (score >= beta) return beta;
      if (score > alpha) alpha = score;
    }
    return alpha;
  }

  /// Keeps going through captures until the position is quiet.
  int _quiesce(ChessPosition p, int alpha, int beta, int qDepth) {
    final stand = _evaluate(p);
    if (stand >= beta) return beta;
    if (stand > alpha) alpha = stand;
    if (qDepth >= 4) return alpha;
    final captures = _engine.legalCaptures(p);
    _order(p, captures);
    for (final move in captures) {
      final score = -_quiesce(p.applyMove(move), -beta, -alpha, qDepth + 1);
      if (score >= beta) return beta;
      if (score > alpha) alpha = score;
    }
    return alpha;
  }

  /// Most valuable victim, least valuable attacker first; then promotions.
  void _order(ChessPosition p, List<ChessMove> moves) {
    int key(ChessMove m) {
      var k = 0;
      final victim =
          m.captured?.type ??
          (m.flag == MoveFlag.enPassant ? PieceType.pawn : null);
      if (victim != null) {
        k += 10 * _value[victim]! - _value[m.piece.type]! ~/ 10;
      }
      if (m.promotion != null) k += _value[m.promotion]!;
      return -k;
    }

    moves.sort((a, b) => key(a).compareTo(key(b)));
  }

  /// The position from the side to move's point of view, in centipawns.
  int _evaluate(ChessPosition p) {
    var score = 0;
    for (var rank = 0; rank < 8; rank++) {
      for (var file = 0; file < 8; file++) {
        final piece = p.board[rank][file];
        if (piece == null) continue;
        // Tables are written from white's side, rank 8 at the top.
        final row = piece.color == PieceColor.white ? 7 - rank : rank;
        final v = _value[piece.type]! + _table[piece.type]![row * 8 + file];
        score += piece.color == PieceColor.white ? v : -v;
      }
    }
    return p.sideToMove == PieceColor.white ? score : -score;
  }

  static const _value = {
    PieceType.pawn: 100,
    PieceType.knight: 320,
    PieceType.bishop: 330,
    PieceType.rook: 500,
    PieceType.queen: 900,
    PieceType.king: 0,
  };

  // Piece-square tables (simplified, from white's side, a8 first).
  static const _table = {
    PieceType.pawn: [
      0, 0, 0, 0, 0, 0, 0, 0, //
      50, 50, 50, 50, 50, 50, 50, 50, //
      10, 10, 20, 30, 30, 20, 10, 10, //
      5, 5, 10, 25, 25, 10, 5, 5, //
      0, 0, 0, 20, 20, 0, 0, 0, //
      5, -5, -10, 0, 0, -10, -5, 5, //
      5, 10, 10, -20, -20, 10, 10, 5, //
      0, 0, 0, 0, 0, 0, 0, 0,
    ],
    PieceType.knight: [
      -50, -40, -30, -30, -30, -30, -40, -50, //
      -40, -20, 0, 0, 0, 0, -20, -40, //
      -30, 0, 10, 15, 15, 10, 0, -30, //
      -30, 5, 15, 20, 20, 15, 5, -30, //
      -30, 0, 15, 20, 20, 15, 0, -30, //
      -30, 5, 10, 15, 15, 10, 5, -30, //
      -40, -20, 0, 5, 5, 0, -20, -40, //
      -50, -40, -30, -30, -30, -30, -40, -50,
    ],
    PieceType.bishop: [
      -20, -10, -10, -10, -10, -10, -10, -20, //
      -10, 0, 0, 0, 0, 0, 0, -10, //
      -10, 0, 5, 10, 10, 5, 0, -10, //
      -10, 5, 5, 10, 10, 5, 5, -10, //
      -10, 0, 10, 10, 10, 10, 0, -10, //
      -10, 10, 10, 10, 10, 10, 10, -10, //
      -10, 5, 0, 0, 0, 0, 5, -10, //
      -20, -10, -10, -10, -10, -10, -10, -20,
    ],
    PieceType.rook: [
      0, 0, 0, 0, 0, 0, 0, 0, //
      5, 10, 10, 10, 10, 10, 10, 5, //
      -5, 0, 0, 0, 0, 0, 0, -5, //
      -5, 0, 0, 0, 0, 0, 0, -5, //
      -5, 0, 0, 0, 0, 0, 0, -5, //
      -5, 0, 0, 0, 0, 0, 0, -5, //
      -5, 0, 0, 0, 0, 0, 0, -5, //
      0, 0, 0, 5, 5, 0, 0, 0,
    ],
    PieceType.queen: [
      -20, -10, -10, -5, -5, -10, -10, -20, //
      -10, 0, 0, 0, 0, 0, 0, -10, //
      -10, 0, 5, 5, 5, 5, 0, -10, //
      -5, 0, 5, 5, 5, 5, 0, -5, //
      0, 0, 5, 5, 5, 5, 0, -5, //
      -10, 5, 5, 5, 5, 5, 0, -10, //
      -10, 0, 5, 0, 0, 0, 0, -10, //
      -20, -10, -10, -5, -5, -10, -10, -20,
    ],
    PieceType.king: [
      -30, -40, -40, -50, -50, -40, -40, -30, //
      -30, -40, -40, -50, -50, -40, -40, -30, //
      -30, -40, -40, -50, -50, -40, -40, -30, //
      -30, -40, -40, -50, -50, -40, -40, -30, //
      -20, -30, -30, -40, -40, -30, -30, -20, //
      -10, -20, -20, -20, -20, -20, -20, -10, //
      20, 20, 0, 0, 0, 0, 20, 20, //
      20, 30, 10, 0, 0, 10, 30, 20,
    ],
  };
}

class _OutOfTime implements Exception {
  const _OutOfTime();
}
