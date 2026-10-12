import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/chess/domain/chess_position.dart';
import 'package:utopia/features/chess/domain/chess_types.dart';
import 'package:utopia/features/chess/presentation/controllers/chess_match_controller.dart';

ChessMoveRecord _record(
  int ply,
  String from,
  String to,
  String san,
  String fen,
) => ChessMoveRecord(
  ply: ply,
  from: Square.fromAlgebraic(from),
  to: Square.fromAlgebraic(to),
  san: san,
  fenAfter: fen,
);

// Fool's mate: black mates on move two.
final _foolsMate = [
  _record(
    1,
    'f2',
    'f3',
    'f3',
    'rnbqkbnr/pppppppp/8/8/8/5P2/PPPPP1PP/RNBQKBNR b KQkq - 0 1',
  ),
  _record(
    2,
    'e7',
    'e5',
    'e5',
    'rnbqkbnr/pppp1ppp/8/4p3/8/5P2/PPPPP1PP/RNBQKBNR w KQkq e6 0 2',
  ),
  _record(
    3,
    'g2',
    'g4',
    'g4',
    'rnbqkbnr/pppp1ppp/8/4p3/6P1/5P2/PPPPP2P/RNBQKBNR b KQkq g3 0 2',
  ),
  _record(
    4,
    'd8',
    'h4',
    'Qh4#',
    'rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3',
  ),
];

Map<String, dynamic> _row({String status = 'active'}) => {
  'status': status,
  'player_white': 'white-id',
  'player_black': 'black-id',
  'ply_count': 4,
  'board_fen': _foolsMate.last.fenAfter,
};

void main() {
  group('looking back through a game', () {
    final state = ChessMatchState(
      position: _foolsMate.last.positionAfter,
      matchRow: _row(),
      history: _foolsMate,
      loading: false,
    );

    test('live by default: the board shows the latest position', () {
      expect(state.reviewing, isFalse);
      expect(state.displayPly, 4);
      expect(state.displayPosition.toFen(), _foolsMate.last.fenAfter);
    });

    test('ply 0 is the starting position, with no move to highlight', () {
      final start = ChessMatchState(
        position: state.position,
        matchRow: _row(),
        history: _foolsMate,
        reviewPly: 0,
      );
      expect(start.displayPosition.toFen(), ChessPosition.initial().toFen());
      expect(start.displayLastMove, isNull);
    });

    test('a past ply shows that move and the board after it', () {
      final second = ChessMatchState(
        position: state.position,
        matchRow: _row(),
        history: _foolsMate,
        reviewPly: 2,
      );
      expect(second.displayPosition.toFen(), _foolsMate[1].fenAfter);
      expect(second.displayLastMove!.from, Square.fromAlgebraic('e7'));
      expect(second.displayLastMove!.to, Square.fromAlgebraic('e5'));
      expect(second.displayLastMove!.piece.type, PieceType.pawn);
    });
  });

  group('a game over on the board before the server says so', () {
    test('checkmate is seen at once, with the right winner', () {
      final state = ChessMatchState(
        position: _foolsMate.last.positionAfter,
        matchRow: _row(),
        myColor: PieceColor.white,
      );
      expect(state.localOutcome?.result, 'checkmate');
      expect(state.localOutcome?.winnerId, 'black-id');
      expect(state.localOutcome?.settled, isFalse);
      expect(state.isOver, isTrue);
      // The mated side can't move, even though the server still says active.
      expect(state.isMyTurn, isFalse);
    });

    test('once settled, the server result is the outcome', () {
      final state = ChessMatchState(
        position: _foolsMate.last.positionAfter,
        matchRow: {
          ..._row(status: 'completed'),
          'winner_id': 'black-id',
          'result': 'checkmate',
        },
      );
      expect(state.localOutcome, isNull);
      expect(state.outcome?.settled, isTrue);
      expect(state.outcome?.winnerId, 'black-id');
    });

    test('a game still in play has no outcome', () {
      final state = ChessMatchState(
        position: _foolsMate[1].positionAfter,
        matchRow: _row(),
        myColor: PieceColor.white,
      );
      expect(state.isOver, isFalse);
      expect(state.isMyTurn, isTrue);
    });
  });
}
