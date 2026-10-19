import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/checkers/domain/checkers_bot.dart';
import 'package:utopia/features/checkers/domain/checkers_engine.dart';
import 'package:utopia/features/chess/domain/chess_bot.dart';
import 'package:utopia/features/chess/domain/chess_engine.dart';
import 'package:utopia/features/chess/domain/chess_position.dart';

/// The browser's worker answers with an index among the legal moves: it
/// has to be the move the bot chose, the same as it plays on a phone.
void main() {
  test('chess: the index names the move the bot chose', () {
    const fen =
        'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3';
    final position = ChessPosition.fromFen(fen);
    final moves = const ChessEngine().legalMoves(position);
    // Easy and normal stop at a set depth, so they choose the same move
    // every time for a seed; hard thinks against the clock.
    for (final level in [BotLevel.easy, BotLevel.normal]) {
      final index = chessBotMoveIndex(fen, level.name, 7);
      final chosen = ChessBot(level, seed: 7).choose(position);
      final named = moves[index!];
      expect(
        (named.from, named.to, named.promotion),
        (chosen!.from, chosen.to, chosen.promotion),
        reason: level.name,
      );
    }
    final hard = chessBotMoveIndex(fen, BotLevel.hard.name, 7);
    expect(hard, inInclusiveRange(0, moves.length - 1));
  });

  test('checkers: the index names the move the bot chose', () {
    final start = CheckersPosition.initialCode;
    final position = CheckersPosition.decode(start);
    final moves = const CheckersEngine().legalMoves(position);
    for (final level in [BotLevel.easy, BotLevel.normal]) {
      final index = checkersBotMoveIndex(start, level.name, 11);
      final chosen = CheckersBot(level, seed: 11).choose(position)!;
      expect(moves[index!].notation, chosen.notation, reason: level.name);
    }
    final hard = checkersBotMoveIndex(start, BotLevel.hard.name, 11);
    expect(hard, inInclusiveRange(0, moves.length - 1));
  });
}
