import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/checkers/domain/checkers_engine.dart';
import 'package:utopia/features/checkers/presentation/controllers/checkers_match_controller.dart';

void main() {
  test('a logged move replays into the same move', () {
    var p = CheckersPosition.initial();
    for (final n in ['22-18', '9-14', '18x9']) {
      final before = p;
      final move = checkersEngine
          .legalMoves(p)
          .firstWhere((m) => m.notation == n);
      final again = checkersMoveFrom(before, checkersPathOf(move.notation));
      expect(again.notation, n);
      expect(again.captured, move.captured);
      p = p.apply(move);
    }
  });

  test('a path the engine does not offer is rebuilt with its jumps', () {
    final move = checkersMoveFrom(
      CheckersPosition.initial(),
      checkersPathOf('11x18x25'),
    );
    expect(move.captured, hasLength(2));
    expect(move.path, [10, 17, 24]);
  });

  test('the server stores the initial board the app expects', () {
    expect(
      CheckersPosition.initial().encode(),
      'llllllllllll........dddddddddddd d 0',
    );
  });
}
