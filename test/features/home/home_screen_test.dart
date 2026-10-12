import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:utopia/features/auth/presentation/providers/auth_providers.dart';
import 'package:utopia/features/coins/presentation/providers/coin_balance_provider.dart';
import 'package:utopia/features/home/presentation/screens/home_screen.dart';

void main() {
  testWidgets(
    'HomeScreen renders the live coin balance, not a hardcoded value',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
}
