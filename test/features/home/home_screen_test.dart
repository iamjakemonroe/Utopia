import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:utopia/core/theme/theme_controller.dart';
import 'package:utopia/features/auth/presentation/providers/auth_providers.dart';
import 'package:utopia/features/coins/presentation/providers/coin_balance_provider.dart';
import 'package:utopia/features/home/presentation/screens/home_screen.dart';

/// A phone's screen (tests default to 800 x 600, a tablet's width).
Future<SharedPreferences> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

void main() {
  testWidgets(
    'HomeScreen renders the live coin balance, not a hardcoded value',
    (tester) async {
      final prefs = await _phone(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            coinBalanceProvider.overrideWith((ref) => Stream.value(1000)),
            isAnonymousProvider.overrideWithValue(false),
            // No signed-in user id in this test — the invite/username banners
            // key off currentUserProvider and simply don't render without one,
            // which keeps this test from needing a real Supabase client.
            currentUserProvider.overrideWithValue(null),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('1,000'), findsOneWidget);
      // Anonymous-only "save your account" banner should not show.
      expect(find.textContaining('Save your account'), findsNothing);
    },
  );

  testWidgets('HomeScreen shows the save-account banner for anonymous users', (
    tester,
  ) async {
    final prefs = await _phone(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          coinBalanceProvider.overrideWith((ref) => Stream.value(1000)),
          isAnonymousProvider.overrideWithValue(true),
          currentUserProvider.overrideWithValue(null),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Save your account'), findsOneWidget);
  });

  testWidgets('on a tablet, the games sit in one row and cards side by side', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2048, 2732);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          coinBalanceProvider.overrideWith((ref) => Stream.value(1000)),
          isAnonymousProvider.overrideWithValue(true),
          currentUserProvider.overrideWithValue(null),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();

    final rows = {
      for (final game in ['Chess', 'Ludo', 'Checkers', 'Guess My Doodle'])
        tester.getCenter(find.text(game)).dy.round(),
    };
    expect(rows, hasLength(1), reason: 'all four games in one row');
    // The save-account card is a column wide, not the whole width.
    final banner = find.ancestor(
      of: find.textContaining('Save your account'),
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(banner.first).width, lessThan(560));
    expect(tester.takeException(), isNull);
  });
}
