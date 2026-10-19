import 'dart:math';

import '../../checkers/domain/checkers_bot.dart';
import '../../checkers/domain/checkers_engine.dart';
import '../../chess/domain/chess_bot.dart';
import '../../chess/domain/chess_engine.dart';
import '../../chess/domain/chess_position.dart';
import '../../chess/domain/chess_types.dart';

/// A house player's turn in an online chess or checkers game: whether the
/// game is already over, and otherwise the move they play and how long a
/// person would take over it. Plain Dart, compiled to JavaScript for the
/// house-move function (lib/web_workers/house_brain_js.dart).
///
/// [position] is the match's board (a FEN for chess, the board code for
/// checkers), [rating] the house player's (their strength), [msLeft] what's
/// on their clock (0 for no clock).
Map<String, Object?> houseTurn({
  required String game,
  required String position,
  required int rating,
  required int msLeft,
  required int ply,
  required int seed,
}) {
  final rng = Random(seed);
  final level = rating < 950
      ? BotLevel.easy
      : rating < 1300
      ? BotLevel.normal
      : BotLevel.hard;
  return game == 'checkers'
      ? _checkers(position, level, msLeft, ply, rng, seed)
      : _chessTurn(position, level, msLeft, ply, rng, seed);
}

/// The most a house player thinks on the server, whatever its level.
const _serverMs = 700;

const _chess = ChessEngine();

Map<String, Object?> _chessTurn(
  String fen,
  BotLevel level,
  int msLeft,
  int ply,
  Random rng,
  int seed,
) {
  final status = _chess.status(ChessPosition.fromFen(fen));
  if (status != GameStatus.ongoing && status != GameStatus.check) {
    return {'over': _chessOver(ChessPosition.fromFen(fen))};
  }
  return _chessMove(fen, level, msLeft, ply, rng, seed);
}

Map<String, Object?> _chessMove(
  String fen,
  BotLevel level,
  int msLeft,
  int ply,
  Random rng,
  int seed,
) {
  final before = ChessPosition.fromFen(fen);
  final move = ChessBot(level, seed: seed, maxMs: _serverMs).choose(before);
  if (move == null) return {'over': _chessOver(before)};
  final after = before.applyMove(move);
  final status = _chess.status(after);
  return {
    'move': {
      'from': move.from.algebraic,
      'to': move.to.algebraic,
      'promotion': move.promotion?.letter.toLowerCase(),
      'san': _chess.toSan(before, move),
      'fen_after': after.toFen(),
    },
    'think_ms': thinkMs(
      ply: ply,
      msLeft: msLeft,
      quick: move.isCapture || status == GameStatus.check,
      rng: rng,
    ),
    if (status != GameStatus.ongoing && status != GameStatus.check)
      'over_after': _chessOver(after),
  };
}

/// How a chess game that's over ended: the winner's color and the result
/// the apps report.
Map<String, Object?> _chessOver(ChessPosition position) {
  final status = _chess.status(position);
  if (status == GameStatus.checkmate) {
    return {
      'winner': position.sideToMove == PieceColor.white ? 'black' : 'white',
      'result': 'checkmate',
    };
  }
  return {
    'winner': null,
    'result': status == GameStatus.stalemate ? 'stalemate' : 'draw',
  };
}

Map<String, Object?> _checkers(
  String code,
  BotLevel level,
  int msLeft,
  int ply,
  Random rng,
  int seed,
) {
  const engine = CheckersEngine();
  final before = CheckersPosition.decode(code);
  if (engine.status(before) != CheckersStatus.ongoing) {
    return {'over': _checkersOver(engine.status(before))};
  }
  final move = CheckersBot(level, seed: seed, maxMs: _serverMs).choose(before);
  if (move == null) return {'over': _checkersOver(engine.status(before))};
  final after = before.apply(move);
  final status = engine.status(after);
  return {
    'move': {
      'from': '${move.from + 1}',
      'to': '${move.to + 1}',
      'promotion': move.promotes ? 'k' : null,
      'san': move.notation,
      'fen_after': after.encode(),
    },
    'think_ms': thinkMs(
      ply: ply,
      msLeft: msLeft,
      quick: move.isCapture,
      rng: rng,
    ),
    if (status != CheckersStatus.ongoing) 'over_after': _checkersOver(status),
  };
}

/// Dark moves first and sits in player_white.
Map<String, Object?> _checkersOver(CheckersStatus status) => switch (status) {
  CheckersStatus.darkWins => {'winner': 'white', 'result': 'win'},
  CheckersStatus.lightWins => {'winner': 'black', 'result': 'win'},
  _ => {'winner': null, 'result': 'draw'},
};

/// How long a person might take over a move: quick through the opening and
/// over a capture or check, longer in the middle of a game, never so long
/// they'd run their clock down (a little faster the less is left).
int thinkMs({
  required int ply,
  required int msLeft,
  required bool quick,
  required Random rng,
}) {
  final spread = rng.nextDouble();
  var ms = ply < 8
      ? 900 + spread * 2200
      : quick
      ? 1000 + spread * 2500
      : 2200 + spread * spread * 9000;
  // Now and then a long think, like anyone's.
  if (!quick && ply >= 8 && rng.nextDouble() < 0.08) ms += 4000 + spread * 6000;
  if (msLeft > 0) ms = min(ms, msLeft / 18);
  return max(600, ms.round());
}
