// The names step of signing up, for a look. Run:
// flutter test --run-skipped --update-goldens test/tool/names_screen_sheet_test.dart
@Tags(['sheet'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:utopia/core/profiles/profile_providers.dart';
import 'package:utopia/core/profiles/profile_repository.dart';
import 'package:utopia/core/supabase/supabase_providers.dart';
import 'package:utopia/core/theme/app_theme.dart';
import 'package:utopia/core/theme/theme_controller.dart';
import 'package:utopia/core/theme/utopia_themes.dart';
import 'package:utopia/features/auth/presentation/providers/auth_providers.dart';
import 'package:utopia/features/profile/presentation/screens/names_screen.dart';

/// Every username's free.
class _AllFree extends ProfileRepository {
  _AllFree(super.client);

  @override
  Future<bool> isUsernameTaken(String username, String myId) async =>
      username == 'jake_monroe';
}

void main() {
  for (final world in [
    UtopiaThemes.utopiaTwilight,
    UtopiaThemes.utopiaDoodle,
  ]) {
    testWidgets('names step in ${world.id}', (tester) async {
      UtopiaThemes.active = world;
      addTearDown(() => UtopiaThemes.active = UtopiaThemes.utopiaTwilight);
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({
        'sound.sfx': false,
        'sound.music': false,
        'utopia.theme': world.id,
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
            profileRepositoryProvider.overrideWithValue(_AllFree(client)),
            currentUserProvider.overrideWithValue(null),
          ],
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark,
            routerConfig: GoRouter(
              initialLocation: '/names',
              routes: [
                GoRoute(
                  path: '/names',
                  builder: (_, _) => const NamesScreen(onboarding: true),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        final artifacts = File(
          Platform.resolvedExecutable,
        ).parent.parent.parent;
        final icons = File(
          '${artifacts.path}/material_fonts/MaterialIcons-Regular.otf',
        ).readAsBytesSync();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(Future.value(ByteData.sublistView(icons)))).load();
        await GoogleFonts.pendingFonts();
      });
      await tester.pump(const Duration(seconds: 1));
      await tester.enterText(find.byType(TextField).first, 'Jake Monroe');
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('@jakemonroe'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(seconds: 1));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/names_step_${world.id}.png'),
      );
      while (tester.takeException() != null) {}
    });
  }
}
