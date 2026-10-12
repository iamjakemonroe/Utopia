// Renders every animated chess set, piece and reaction into a contact sheet
// (test/tool/goldens/chess_pieces.png) so the art can be looked at without
// a device. Run: flutter test --update-goldens test/tool/chess_piece_sheet_test.dart
@Tags(['sheet'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/chess/domain/chess_types.dart';
import 'package:utopia/features/chess/presentation/widgets/chess_piece_art.dart';
import 'package:utopia/features/chess/presentation/widgets/chess_piece_styles.dart';

void main() {
  testWidgets('chess piece contact sheet', (tester) async {
    const sets = ['chess_buddies', 'chess_monsters', 'chess_robots'];
    const moods = [
      PieceMood.idle,
      PieceMood.scared,
      PieceMood.happy,
      PieceMood.panic,
      PieceMood.ko,
    ];
    const size = 72.0;
    tester.view.physicalSize = const Size(
      6 * 2 * size * 1.0 + 40,
      3 * 5 * size + 40,
    );
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: const ValueKey('sheet'),
          child: Container(
            color: const Color(0xFF2A2350),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                for (final id in sets)
                  for (final mood in moods)
                    Row(
                      children: [
                        for (final color in PieceColor.values)
                          for (final type in PieceType.values)
                            Container(
                              width: size,
                              height: size,
                              color: (type.index + color.index).isEven
                                  ? const Color(0xFFEEE3C8)
                                  : const Color(0xFF6B5BA8),
                              child: ChessPieceArt(
                                type: type,
                                finish: ChessPieceStyle.byId(id).of(color),
                                character: ChessPieceStyle.byId(id).character,
                                mood: mood,
                                size: size,
                                t: 1.3,
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
    await expectLater(
      find.byKey(const ValueKey('sheet')),
      matchesGoldenFile('goldens/chess_pieces.png'),
    );
  });
}
