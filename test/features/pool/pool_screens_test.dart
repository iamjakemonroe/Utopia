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
import 'package:utopia/features/pool/data/pool_repository.dart';
import 'package:utopia/features/pool/domain/pool_cues.dart';
import 'package:utopia/features/pool/presentation/pool_art.dart';
import 'package:utopia/features/pool/presentation/pool_cue_art.dart';
import 'package:utopia/features/pool/presentation/pool_lobby_screen.dart';
import 'package:utopia/features/pool/presentation/pool_match_screen.dart';
import 'package:utopia/features/pool/presentation/pool_providers.dart';

final _me = User(
  id: 'me',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: DateTime(2026).toIso8601String(),
);

Future<void> _open(
  WidgetTester tester,
  Widget screen, {
  int coins = 3000,
}) async {
  PoolBallArt.debugForget();
  CueArt.debugForget();
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    'sound.sfx': false,
    'sound.music': false,
  });
  final prefs = await SharedPreferences.getInstance();
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
        isAnonymousProvider.overrideWithValue(false),
        profileByIdProvider.overrideWith(
          (ref, id) async => {'id': id, 'display_name': 'Me'},
        ),
        coinBalanceProvider.overrideWith((ref) => Stream.value(coins)),
        poolTablesProvider.overrideWith((ref) async => kPoolTables),
        activePoolGameProvider.overrideWith((ref) async => null),
        poolCueLevelsProvider.overrideWith(
          (ref) async => const {'cue_galaxy': 3},
        ),
        myPoolCueProvider.overrideWithValue((
          cue: poolCue('cue_galaxy'),
          level: 3,
          upgradable: true,
        )),
      ],
      child: MaterialApp(home: screen),
    ),
  );
}

void main() {
  testWidgets('the lobby: your cue, the tables, a game for two', (
    tester,
  ) async {
    await _open(tester, const PoolLobbyScreen());
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.takeException(), isNull);
    expect(find.text('Galaxy'), findsOneWidget);
    expect(find.text('Legendary'), findsOneWidget);
    expect(find.text('Lagoon Table'), findsOneWidget);
    expect(find.text('Upgrade'), findsOneWidget);
    // 3,000 coins: the Lagoon and Dunes tables, not the Neon or Summit.
    await tester.scrollUntilVisible(find.text('Summit Table'), 200);
    expect(find.text('Get coins'), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('two on one phone: the table, the controls, a shot', (
    tester,
  ) async {
    await _open(tester, const PoolMatchScreen.friends());
    // The shaders load for real (not on the test's clock).
    for (var i = 0; i < 40 && find.text('Player 1').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.takeException(), isNull);
    expect(find.text('Player 1'), findsOneWidget);
    expect(find.text('Player 2'), findsOneWidget);
    expect(find.textContaining('Player 1\'s shot'), findsOneWidget);

    // Draw the cue back on the power bar and let go: the break.
    final bar = find.bySemanticsLabel('Power: drag down, let go to shoot');
    expect(bar, findsOneWidget);
    final top = tester.getTopLeft(bar) + const Offset(20, 20);
    final gesture = await tester.startGesture(top);
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    for (var i = 0; i < 400; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.takeException(), isNull);
    // The break's been played: the table's moved on.
    expect(find.textContaining('the break'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
