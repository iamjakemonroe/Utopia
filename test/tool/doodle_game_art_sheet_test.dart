// Renders Guess My Doodle's banner art mid-sketch and once it's guessed,
// into test/tool/goldens/. Run:
// flutter test --run-skipped --update-goldens test/tool/doodle_game_art_sheet_test.dart
@Tags(['sheet'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/widgets/game_card_art.dart';

void main() {
  for (final (name, ms) in [('mid', 2600), ('done', 5300)]) {
    testWidgets('doodle art $name', (tester) async {
      tester.view.physicalSize = const Size(1200, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: ValueKey('art'),
            child: FittedBox(
              child: SizedBox(
                width: 400,
                height: 200,
                child: GameSceneArt(game: GameKind.doodle, height: 200),
              ),
            ),
          ),
        ),
      );
      await tester.pump(Duration(milliseconds: ms));
      await expectLater(
        find.byKey(const ValueKey('art')),
        matchesGoldenFile('goldens/doodle_game_art_$name.png'),
      );
    });
  }
}
