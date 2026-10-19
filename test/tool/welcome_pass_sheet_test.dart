// A phone screenshot of the welcome pass sheet a new player sees, into
// test/tool/goldens/. Run:
// flutter test --run-skipped --update-goldens test/tool/welcome_pass_sheet_test.dart
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
import 'package:utopia/core/widgets/app_background.dart';
import 'package:utopia/features/auth/presentation/providers/auth_providers.dart';
import 'package:utopia/features/welcome/presentation/welcome_week.dart';

void main() {
  testWidgets('welcome pass', (tester) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'sound.sfx': false});
    final prefs = await SharedPreferences.getInstance();
    late BuildContext host;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentUserProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: Scaffold(
            body: AppBackground(
              child: Builder(
                builder: (context) {
                  host = context;
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
      final icons = File(
        '${artifacts.path}/material_fonts/MaterialIcons-Regular.otf',
      ).readAsBytesSync();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(Future.value(ByteData.sublistView(icons)))).load();
    });
    showModalBottomSheet<void>(
      context: host,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WelcomeWeekSheet(
        until: DateTime.now().add(const Duration(days: 3, minutes: 5)),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.runAsync(GoogleFonts.pendingFonts);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/welcome_pass.png'),
    );
    await tester.pumpWidget(const SizedBox());
  });
}
