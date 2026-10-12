// Renders checkers discs in every set and face, plus a board mid-game with
// a piece selected, into test/tool/goldens/checkers.png, so the art can be
// looked at without a device.
// Run: flutter test --update-goldens --run-skipped test/tool/checkers_sheet_test.dart
@Tags(['sheet'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/checkers/domain/checkers_engine.dart';
import 'package:utopia/features/checkers/presentation/widgets/checkers_board.dart';
import 'package:utopia/features/checkers/presentation/widgets/checkers_disc.dart';

class _Discs extends CustomPainter {
  static const sets = [
    'classic',
    'chess_crystal',
    'chess_royal',
    'chess_neon',
    'chess_buddies',
    'chess_monsters',
    'chess_robots',
    'chess_candy',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 64.0;
    for (final (row, set) in sets.indexed) {
      var col = 0;
      for (final side in CheckersSide.values) {
        for (final king in [false, true]) {
          for (final face in [DiscFace.calm, DiscFace.scared, DiscFace.happy]) {
            final c = Offset(col * cell + cell / 2, row * cell + cell / 2 + 6);
            canvas.drawRect(
              Rect.fromCenter(
                center: c.translate(0, -6),
                width: cell,
                height: cell,
              ),
              Paint()..color = const Color(0xFF3A2C78),
            );
            paintCheckersDisc(
              canvas,
              c,
              cell * 0.36,
              finish: checkersFinish(set, side),
              king: king,
              character: checkersCharacter(set),
              face: face,
            );
            col++;
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

void main() {
  testWidgets('checkers sheet', (tester) async {
    tester.view.physicalSize = const Size(12 * 64 + 40, 8 * 64 + 40 + 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const engine = CheckersEngine();
    var p = CheckersPosition.initial();
    for (final n in ['22-18', '9-14', '18x9', '5x14', '24-19']) {
      p = p.apply(engine.legalMoves(p).firstWhere((m) => m.notation == n));
    }
    // Promote a light man to show a king on the board.
    final squares = [...p.squares];
    squares[30] = null;
    squares[17] = const CheckersPiece(CheckersSide.dark, king: true);
    p = CheckersPosition(squares: squares, toMove: p.toMove);
    final moves = engine.legalMoves(p);
    final sel = moves.first.from;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: const ValueKey('sheet'),
          child: Container(
            color: const Color(0xFF1B1433),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                SizedBox(
                  width: 12 * 64,
                  height: 8 * 64,
                  child: CustomPaint(painter: _Discs()),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox.square(
                      dimension: 400,
                      child: CheckersBoard(
                        position: p,
                        selected: sel,
                        targets: [
                          for (final m in moves)
                            if (m.from == sel) m,
                        ],
                        movable: engine.movablePieces(p),
                        mustCapture: moves.first.isCapture,
                        interactive: true,
                        darkSet: 'chess_buddies',
                        lightSet: 'chess_robots',
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox.square(
                      dimension: 340,
                      child: CheckersBoard(
                        position: CheckersPosition.initial(),
                        bottom: CheckersSide.light,
                        movable: engine.movablePieces(
                          CheckersPosition.initial(),
                        ),
                        interactive: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byKey(const ValueKey('sheet')),
      matchesGoldenFile('goldens/checkers.png'),
    );
  });
}
