import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:utopia/core/profiles/profile_providers.dart';
import 'package:utopia/core/supabase/supabase_providers.dart';
import 'package:utopia/core/theme/theme_controller.dart';
import 'package:utopia/features/auth/presentation/providers/auth_providers.dart';
import 'package:utopia/features/coins/presentation/providers/coin_balance_provider.dart';
import 'package:utopia/features/eights/presentation/controllers/eights_match_controller.dart';
import 'package:utopia/features/eights/presentation/screens/eights_match_screen.dart';

final _me = User(
  id: 'me',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: DateTime(2026).toIso8601String(),
);

/// An offline game on a phone-sized screen.
Future<String> _open(WidgetTester tester, {int players = 4}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    'sound.sfx': false,
    'sound.music': false,
  });
  final prefs = await SharedPreferences.getInstance();
  final id = startLocalEights(
    LocalEightsSetup(
      playerIds: [
        'me',
        for (final b in [
          'pip',
          'momo',
          'zuzu',
          'bix',
          'lumi',
        ].take(players - 1))
          'bot:$b',
      ],
      humanId: 'me',
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        supabaseClientProvider.overrideWithValue(
          SupabaseClient(
            'http://localhost',
            'test-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        ),
        currentUserProvider.overrideWithValue(_me),
        profileByIdProvider.overrideWith(
          (ref, id) async => {'id': id, 'display_name': id},
        ),
        publicCoinsProvider.overrideWith((ref, id) async => null),
      ],
      child: MaterialApp(home: EightsMatchScreen(matchId: id)),
    ),
  );
  return id;
}

void main() {
  testWidgets('an offline table deals and lays out without a hitch', (
    tester,
  ) async {
    await _open(tester);
    // The deal and the first few moves.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.takeException(), isNull);
    expect(find.text('Free'), findsOneWidget);
    // Three others round the table.
    expect(find.text('bot:pip'), findsOneWidget);
    expect(find.text('bot:zuzu'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('six at the table fits a phone', (tester) async {
    await _open(tester, players: 6);
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
