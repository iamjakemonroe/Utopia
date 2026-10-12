import 'dart:isolate';
import 'dart:math';

import '../../chess/domain/chess_bot.dart' show BotLevel;
import 'checkers_engine.dart';

export '../../chess/domain/chess_bot.dart' show BotLevel;

const _engine = CheckersEngine();

/// Picks the computer's checkers move off the main thread. Null when it
/// has no moves.
Future<CheckersMove?> findCheckersBotMove(
  CheckersPosition position,
  BotLevel level,
) {
  final code = position.encode();
  final seed = Random().nextInt(1 << 30);
  return Isolate.run(
    () => CheckersBot(level, seed: seed).choose(CheckersPosition.decode(code)),
  );
}

/// Negamax with alpha-beta, iterative deepening against a time budget, and
/// captures searched first. Positions are judged on material (a king is
/// worth more than a man), men advancing, holding the centre, and keeping
/// the back row guarded against kings.
class CheckersBot {
  CheckersBot(this.level, {int? seed}) : _rng = Random(seed);

  final BotLevel level;
  final Random _rng;
  final _clock = Stopwatch();
  late Duration _budget;

  static const _win = 100000;

  CheckersMove? choose(CheckersPosition position) {
    final moves = _engine.legalMoves(position);
    if (moves.isEmpty) return null;
    if (moves.length == 1) return moves.first;
    if (level == BotLevel.easy && _rng.nextDouble() < 0.3) {
      return moves[_rng.nextInt(moves.length)];
    }

    final (maxDepth, noise, budgetMs) = switch (level) {
      BotLevel.easy => (2, 60, 300),
      BotLevel.normal => (4, 15, 800),
      BotLevel.hard => (10, 0, 1500),
    };
    _budget = Duration(milliseconds: budgetMs);
    _clock.start();

    _order(moves);
    var best = moves.first;
    for (var depth = 1; depth <= maxDepth; depth++) {
      try {
        var alpha = -_win * 2;
        var top = moves.first;
        var topScore = -_win * 3;
        for (final move in moves) {
          // Exact scores when adding a wobble, so moves don't tie.
          final score = -_search(
            position.apply(move),
            depth - 1,
            -_win * 2,
            noise > 0 ? _win * 2 : -alpha,
            1,
          );
          if (score > alpha) alpha = score;
          final s = score + (noise == 0 ? 0 : _rng.nextInt(noise * 2) - noise);
          if (s > topScore) {
            topScore = s;
            top = move;
          }
        }
        best = top;
        moves
          ..remove(best)
          ..insert(0, best);
        if (alpha.abs() > _win - 200) break;
      } on _OutOfTime {
        break;
      }
    }
    return best;
  }

  int _search(CheckersPosition p, int depth, int alpha, int beta, int ply) {
    if (_clock.elapsed > _budget) throw const _OutOfTime();
    final moves = _engine.legalMoves(p);
    if (moves.isEmpty) return -_win + ply;
    if (p.quietPlies >= 80) return 0;
    // Captures are forced, so keep looking while they're on.
    if (depth <= 0 && !moves.first.isCapture) return _evaluate(p);
    if (depth <= -6) return _evaluate(p);
    _order(moves);
    for (final move in moves) {
      final score = -_search(p.apply(move), depth - 1, -beta, -alpha, ply + 1);
      if (score >= beta) return beta;
      if (score > alpha) alpha = score;
    }
    return alpha;
  }

  void _order(List<CheckersMove> moves) {
    int key(CheckersMove m) =>
        -(m.captured.length * 100 + (m.promotes ? 50 : 0));
    moves.sort((a, b) => key(a).compareTo(key(b)));
  }

  /// From the side to move's point of view.
  int _evaluate(CheckersPosition p) {
    var score = 0;
    for (var s = 0; s < 32; s++) {
      final piece = p.squares[s];
      if (piece == null) continue;
      final row = rowOf(s);
      final col = colOf(s);
      var v = piece.king ? 175 : 100;
      if (!piece.king) {
        // How far the man has come (rows from its own back row).
        final advanced = piece.side == CheckersSide.dark ? 7 - row : row;
        v += advanced * 4;
        // Guarding the back row keeps the other side from crowning.
        if (advanced == 0) v += 8;
      }
      // The centre is strong; the edges are safe but passive.
      if (col >= 2 && col <= 5 && row >= 2 && row <= 5) v += 6;
      if (col == 0 || col == 7) v -= 3;
      score += piece.side == p.toMove ? v : -v;
    }
    return score;
  }
}

class _OutOfTime implements Exception {
  const _OutOfTime();
}
