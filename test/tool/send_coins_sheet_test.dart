// Phone screenshots of the send-coins sheet (ready to send, and a new
// account told to wait), into test/tool/goldens/. Run:
// flutter test --run-skipped --update-goldens test/tool/send_coins_sheet_test.dart
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
import 'package:utopia/features/coins/data/coin_gift_repository.dart';
import 'package:utopia/features/coins/presentation/send_coins_sheet.dart';

GiftAllowance _allowance({bool ok = true, String? why, int held = 0}) =>
    GiftAllowance(
      ok: ok,
      why: why,
      readyAt: why == 'new'
          ? DateTime.now().add(const Duration(days: 3))
          : null,
      balance: 4820,
      giftable: 4820 - held,
      held: held,
      holdDays: 14,
      min: 10,
      max: 50000,
      leftToday: 2410,
      giftsLeft: 19,
      capLeft: 100000,
      dailyCap: 100000,
      shareLeft: 2410,
    );

Future<void> _sheet(
  WidgetTester tester,
  GiftAllowance allowance,
  String name,
) async {
  tester.view.physicalSize = const Size(1290, 2796);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    'sound.sfx': false,
    'sound.music': false,
  });
  final prefs = await SharedPreferences.getInstance();
  late BuildContext host;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        giftAllowanceProvider.overrideWith((ref, _) async => allowance),
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
    await GoogleFonts.pendingFonts();
  });
  showSendCoinsSheet(host, (
    id: 'f2',
    name: 'Kofi',
    avatarUrl: null,
    avatarKind: 'animal',
    avatarSeed: 7,
  ));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  // The sheet's own fonts, asked for once it was up.
  await tester.runAsync(GoogleFonts.pendingFonts);
  await tester.pump(const Duration(milliseconds: 100));
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/send_coins_$name.png'),
  );
}

void main() {
  testWidgets('ready to send', (tester) async {
    await _sheet(tester, _allowance(held: 1000), 'ready');
  });

  testWidgets('a new account waits', (tester) async {
    await _sheet(tester, _allowance(ok: false, why: 'new'), 'new');
  });
}
