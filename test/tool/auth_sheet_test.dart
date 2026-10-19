// Phone screenshots of the sign-in screens (the start screen, the email
// step and the code step), into test/tool/goldens/. Run:
// flutter test --run-skipped --update-goldens test/tool/auth_sheet_test.dart
@Tags(['sheet'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia/core/theme/app_theme.dart';
import 'package:utopia/core/theme/theme_controller.dart';
import 'package:utopia/core/theme/utopia_themes.dart';
import 'package:utopia/features/auth/data/auth_repository.dart';
import 'package:utopia/features/auth/presentation/providers/auth_providers.dart';
import 'package:utopia/features/auth/presentation/screens/auth_choice_screen.dart';
import 'package:utopia/features/auth/presentation/screens/email_link_screen.dart';

/// Sends codes into the void.
class _FakeAuth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

Future<void> _phone(
  WidgetTester tester,
  Widget child, {
  UtopiaTheme world = UtopiaThemes.utopiaTwilight,
  Size size = const Size(1290, 2796),
}) async {
  UtopiaThemes.active = world;
  addTearDown(() => UtopiaThemes.active = UtopiaThemes.utopiaTwilight);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    'sound.sfx': false,
    'sound.music': false,
    'utopia.theme': world.id,
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currentUserProvider.overrideWithValue(null),
        authRepositoryProvider.overrideWithValue(_FakeAuth()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: child,
      ),
    ),
  );
  // The app's fonts (bundled) and the icon font, so text and icons draw.
  await tester.runAsync(() async {
    final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
    final icons = File(
      '${artifacts.path}/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytesSync();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.sublistView(icons)))).load();
    await GoogleFonts.pendingFonts();
    // The gateway, so it's in the first picture.
    await precacheImage(
      const AssetImage('assets/branding/logo_mark.png'),
      tester.element(find.byType(Scaffold).first),
    );
  });
  await tester.pump(const Duration(milliseconds: 2500));
}

void main() {
  testWidgets('start screen', (tester) async {
    await _phone(tester, const AuthChoiceScreen());
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/auth_start.png'),
    );
  });

  testWidgets('start screen, small phone', (tester) async {
    await _phone(
      tester,
      const AuthChoiceScreen(),
      size: const Size(1125, 2001),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/auth_start_small.png'),
    );
  });

  testWidgets('email step', (tester) async {
    await _phone(tester, const EmailLinkScreen());
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/auth_email.png'),
    );
  });

  testWidgets('code step', (tester) async {
    await _phone(tester, const EmailLinkScreen());
    await tester.enterText(find.byType(TextField).first, 'jake@kaivon.app');
    await tester.tap(find.text('Send code'));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.enterText(find.byType(TextField).last, '4821');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/auth_code.png'),
    );
    // Gone, so its resend countdown stops.
    await tester.pumpWidget(const SizedBox());
  });
}
