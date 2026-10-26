import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/theme/utopia_themes.dart';
import 'package:utopia/core/widgets/live_world_cards.dart';
import 'package:utopia/core/widgets/utopia_world.dart';

/// A screen of world cards (as the Store and Collection have), as in a
/// browser.
Widget _cards(List<UtopiaTheme> themes) => MaterialApp(
  home: LiveWorldArea(
    child: GridView.count(
      crossAxisCount: 2,
      childAspectRatio: 0.78,
      children: [
        for (final t in themes)
          LiveWorldCard(
            id: t.id,
            child: UtopiaWorld(style: t.world),
          ),
      ],
    ),
  ),
);

void main() {
  setUp(() {
    debugLiveWorldCardsAsWeb = true;
    debugWorldSeconds = 2;
  });
  tearDown(() {
    debugLiveWorldCardsAsWeb = null;
    debugWorldSeconds = null;
  });

  testWidgets('only one card is a world; the rest become pictures, one a '
      'frame, kept for the next visit', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final themes = UtopiaThemes.utopia.take(6).toList();

    await tester.pumpWidget(_cards(themes));
    // Every card starts as its world, waiting for its picture.
    expect(find.byType(UtopiaWorld), findsNWidgets(6));
    await tester.pump();
    // A picture a frame (and the middle card is picked to move).
    final after = <int>[];
    for (var i = 0; i < 8; i++) {
      await tester.pump();
      after.add(find.byType(UtopiaWorld).evaluate().length);
    }
    for (var i = 1; i < after.length; i++) {
      expect(after[i - 1] - after[i], lessThanOrEqualTo(1));
    }
    expect(after.last, 1, reason: 'only the live card is still a world');

    // Away and back: the pictures were kept, so only the live one is made.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_cards(themes));
    await tester.pump();
    await tester.pump();
    expect(find.byType(UtopiaWorld), findsOneWidget);
  });
}
