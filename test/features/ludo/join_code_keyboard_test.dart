import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:utopia/core/supabase/supabase_providers.dart';
import 'package:utopia/core/theme/theme_controller.dart';
import 'package:utopia/features/auth/presentation/providers/auth_providers.dart';
import 'package:utopia/features/coins/presentation/providers/coin_balance_provider.dart';
import 'package:utopia/features/guess_doodle/presentation/guess_doodle_lobby_screen.dart';
import 'package:utopia/features/ludo/presentation/screens/ludo_lobby_screen.dart';

/// Opens [screen]'s Play with friends sheet on the Join tab.
Future<void> _join(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    'sound.sfx': false,
    'sound.music': false,
  });
  final prefs = await SharedPreferences.getInstance();
  final client = SupabaseClient(
    'http://127.0.0.1:9',
    'test',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        supabaseClientProvider.overrideWithValue(client),
        currentUserProvider.overrideWithValue(null),
        isAnonymousProvider.overrideWithValue(false),
        coinBalanceProvider.overrideWith((ref) => Stream.value(1250)),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/s',
          routes: [
            GoRoute(path: '/s', builder: (_, _) => screen),
            GoRoute(path: '/home', builder: (_, _) => const SizedBox()),
          ],
        ),
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.tap(find.text('Play with friends').first);
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.tap(find.text('Join').last);
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _check(WidgetTester tester, Widget screen) async {
  await _join(tester, screen);
  final field = tester.widget<TextField>(find.byType(TextField).last);
  expect(field.focusNode!.hasFocus, isTrue, reason: 'Join opens the keyboard');
  expect(tester.testTextInput.isVisible, isTrue);
  final tiles = tester.getRect(find.byType(FittedBox).last);
  for (final (where, at) in [
    ('the middle', tiles.center),
    ('the first tile', Offset(tiles.left + 10, tiles.center.dy)),
    ('the top of a tile', Offset(tiles.center.dx, tiles.top + 4)),
    ('the bottom of a tile', Offset(tiles.center.dx, tiles.bottom - 4)),
  ]) {
    // The keyboard put away, the field still focused.
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    await tester.tapAt(at);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue, reason: 'tapped $where');
  }
  while (tester.takeException() != null) {}
}

void main() {
  testWidgets(
    'Ludo: the code tiles always bring the keyboard up',
    (t) => _check(t, const LudoLobbyScreen()),
  );
  testWidgets(
    'Guess My Doodle: the code tiles always bring the keyboard up',
    (t) => _check(t, const GuessDoodleLobbyScreen()),
  );
}
