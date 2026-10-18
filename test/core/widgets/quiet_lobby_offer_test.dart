import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/widgets/quiet_lobby_offer.dart';

void main() {
  testWidgets('offers an offline game only once the search has run a while', (
    tester,
  ) async {
    var played = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuietLobbyOffer(label: 'Play Chip', onPlay: () => played++),
        ),
      ),
    );

    expect(find.text('Play Chip'), findsNothing);
    await tester.pump(kQuietLobbyAfter - const Duration(seconds: 1));
    expect(find.text('Play Chip'), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text("It's quiet right now"), findsOneWidget);
    await tester.tap(find.text('Play Chip'));
    expect(played, 1);

    // Chip on the card bobs forever; stop before the test ends.
    await tester.pumpWidget(const SizedBox());
  });
}
