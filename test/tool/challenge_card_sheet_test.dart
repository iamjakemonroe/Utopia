// The challenge card on home at a small, a middling and a big phone's
// width, for a look. Run:
// flutter test --run-skipped --update-goldens test/tool/challenge_card_sheet_test.dart
@Tags(['sheet'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia/core/profiles/profile_providers.dart';
import 'package:utopia/core/theme/app_colors.dart';
import 'package:utopia/core/theme/app_theme.dart';
import 'package:utopia/core/theme/theme_controller.dart';
import 'package:utopia/core/theme/utopia_themes.dart';
import 'package:utopia/core/widgets/app_background.dart';
import 'package:utopia/features/home/presentation/screens/home_screen.dart';

const _invites = [
  {
    'id': 'a',
    'from_user': 'ada',
    'game': 'checkers',
    'stake': 25000,
    'minutes': 15,
    'increment': 10,
    'status': 'pending',
  },
  {
    'id': 'b',
    'from_user': 'bo',
    'game': 'chess',
    'stake': 0,
    'minutes': 3,
    'increment': 2,
    'status': 'pending',
  },
];

void main() {
  for (final world in [
    UtopiaThemes.utopiaTwilight,
    UtopiaThemes.utopiaDoodle,
  ]) {
    testWidgets('challenge cards in ${world.id}', (tester) async {
      UtopiaThemes.active = world;
      addTearDown(() => UtopiaThemes.active = UtopiaThemes.utopiaTwilight);
      tester.view.physicalSize = const Size(1290 * 3 / 3, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({'utopia.theme': world.id});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            profileByIdProvider.overrideWith(
              (ref, id) async => id == 'ada'
                  ? {
                      'id': 'ada',
                      'display_name': 'Adaeze Okonkwo-Williams',
                      'avatar_kind': 'initial',
                    }
                  : {
                      'id': 'bo',
                      'display_name': 'Bo',
                      'avatar_kind': 'initial',
                    },
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark,
            home: Scaffold(
              body: AppBackground(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final width in [320.0, 375.0, 430.0])
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: width - 32,
                          child: Column(
                            children: [
                              Text(
                                '${width.round()} wide',
                                style: TextStyle(color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 8),
                              for (final invite in _invites)
                                ChallengeCard(invite: invite),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
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
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/challenge_cards_${world.id}.png'),
      );
      while (tester.takeException() != null) {}
    });
  }
}
