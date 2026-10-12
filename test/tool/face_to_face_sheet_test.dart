// One-phone (face to face) boards: the top player's pieces turned to face
// them. Renders test/tool/goldens/face_to_face.png.
// Run: flutter test --run-skipped --update-goldens test/tool/face_to_face_sheet_test.dart
@Tags(['sheet'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/checkers/domain/checkers_engine.dart';
import 'package:utopia/features/checkers/presentation/widgets/checkers_board.dart';
import 'package:utopia/features/chess/domain/chess_position.dart';
import 'package:utopia/features/chess/domain/chess_types.dart';
import 'package:utopia/features/chess/presentation/widgets/animated_chess_board.dart';

void main() {
  testWidgets('face to face boards', (tester) async {
    tester.view.physicalSize = const Size(1040, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: const ValueKey('sheet'),
          child: ColoredBox(
            color: const Color(0xFF1E1638),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 520,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: AnimatedChessBoard(
                      position: ChessPosition.initial(),
                      lastMove: null,
                      legalDestinations: const [],
                      selectedSquare: null,
                      myColor: PieceColor.white,
                      interactive: false,
                      onSquareTap: (_) {},
                      whiteSet: 'chess_buddies',
                      blackSet: 'chess_buddies',
                      turnedFor: PieceColor.black,
                    ),
                  ),
                ),
                SizedBox.square(
                  dimension: 520,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: CheckersBoard(
                      position: CheckersPosition.initial(),
                      darkSet: 'chess_monsters',
                      lightSet: 'chess_monsters',
                      turnedFor: CheckersSide.light,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await expectLater(
      find.byKey(const ValueKey('sheet')),
      matchesGoldenFile('goldens/face_to_face.png'),
    );
  });
}
