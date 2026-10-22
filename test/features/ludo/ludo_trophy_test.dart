import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia/core/theme/theme_controller.dart'
    show sharedPreferencesProvider;
import 'package:utopia/features/ludo/domain/ludo_engine.dart';
import 'package:utopia/features/ludo/presentation/widgets/ludo_board.dart';

void main() {
  Future<void> show(WidgetTester tester, LudoState game) async {
    SharedPreferences.setMockInitialValues({'sound.sfx': false});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          home: Center(
            child: SizedBox.square(
              dimension: 380,
              child: LudoBoardView(
                game: game,
                myColor: LudoColor.green,
                movableTokens: const [],
                onTokenTap: (_) {},
                pieceSets: const {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  LudoState finishing(List<LudoColor> done) {
    final start = LudoState.initial(const [
      LudoColor.red,
      LudoColor.green,
      LudoColor.yellow,
      LudoColor.blue,
    ]);
    final home = start.rules.finish;
    return start.copyWith(
      tokens: {
        ...start.tokens,
        for (final c in done) c: [home, home, home, home],
      },
      winner: done.first,
      finished: done,
    );
  }

  testWidgets('everyone who has finished has a trophy with their place '
      'over their yard, while the rest race on', (tester) async {
    final semantics = tester.ensureSemantics();
    await show(tester, finishing(const [LudoColor.yellow, LudoColor.red]));

    expect(find.byKey(const ValueKey('trophy-yellow')), findsOneWidget);
    expect(find.byKey(const ValueKey('trophy-red')), findsOneWidget);
    expect(find.byKey(const ValueKey('trophy-green')), findsNothing);
    expect(find.byKey(const ValueKey('trophy-blue')), findsNothing);
    expect(find.bySemanticsLabel('Yellow: 1st'), findsOneWidget);
    expect(find.bySemanticsLabel('Red: 2nd'), findsOneWidget);

    semantics.dispose();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the next to finish gets theirs too', (tester) async {
    await show(tester, finishing(const [LudoColor.yellow]));
    expect(find.byKey(const ValueKey('trophy-yellow')), findsOneWidget);
    expect(find.byKey(const ValueKey('trophy-blue')), findsNothing);

    await show(tester, finishing(const [LudoColor.yellow, LudoColor.blue]));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey('trophy-blue')), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
