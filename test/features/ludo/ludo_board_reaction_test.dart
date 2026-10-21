import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia/core/theme/theme_controller.dart'
    show sharedPreferencesProvider;
import 'package:utopia/features/ludo/domain/ludo_engine.dart';
import 'package:utopia/features/ludo/presentation/widgets/ludo_board.dart';
import 'package:utopia/features/ludo/presentation/widgets/ludo_capture_bubble.dart';

void main() {
  testWidgets('tapping the piece that captured opens its reaction', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    SharedPreferences.setMockInitialValues({'sound.sfx': false});
    final prefs = await SharedPreferences.getInstance();
    final start = LudoState.initial(const [LudoColor.red, LudoColor.yellow]);
    final game = start.copyWith(
      tokens: {
        ...start.tokens,
        LudoColor.red: [12, 5, kLudoBase, kLudoBase],
      },
    );
    var opened = 0;
    var moved = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          home: Center(
            child: SizedBox.square(
              dimension: 380,
              child: LudoBoardView(
                game: game,
                myColor: LudoColor.red,
                movableTokens: const [],
                onTokenTap: (_) => moved++,
                pieceSets: const {},
                anchors: [
                  LudoTokenAnchor(
                    color: LudoColor.red,
                    token: 0,
                    width: LudoCaptureBadge.size.width,
                    onTokenTap: () => opened++,
                    child: LudoCaptureBadge(
                      deadline: DateTime.now().add(const Duration(seconds: 6)),
                      window: const Duration(seconds: 6),
                      onTap: () => opened++,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // The piece that captured.
    await tester.tap(find.bySemanticsLabel('Red token 1'));
    await tester.pump();
    expect(opened, 1);
    // Its badge too.
    await tester.tap(find.text('React'));
    await tester.pump();
    expect(opened, 2);
    // Any other piece: nothing (none can move before the roll).
    await tester.tap(find.bySemanticsLabel('Red token 2'));
    await tester.pump();
    expect(opened, 2);
    expect(moved, 0);

    semantics.dispose();
    await tester.pumpWidget(const SizedBox());
  });
}
