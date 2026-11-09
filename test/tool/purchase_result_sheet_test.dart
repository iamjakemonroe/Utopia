// The purchase result modal, for a look: each state over a world, the
// size of an iPhone. Renders test/tool/goldens/purchase_*.png. Run:
// flutter test --run-skipped --update-goldens test/tool/purchase_result_sheet_test.dart
@Tags(['sheet'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia/core/audio/game_audio.dart';
import 'package:utopia/core/theme/app_theme.dart';
import 'package:utopia/core/theme/theme_controller.dart';
import 'package:utopia/core/theme/utopia_themes.dart';
import 'package:utopia/core/widgets/utopia_world.dart';
import 'package:utopia/features/auth/presentation/providers/auth_providers.dart';
import 'package:utopia/features/coins/presentation/providers/coin_balance_provider.dart';
import 'package:utopia/features/store/presentation/purchase_result.dart';

class _Quiet extends GameAudio {
  _Quiet() : super(const SoundSettings(musicOn: false, sfxOn: false));

  @override
  void play(Sfx sfx, {double volume = 1}) {}
}

Future<void> _shoot(
  WidgetTester tester,
  String name,
  PurchaseResult result, {
  Duration settle = const Duration(milliseconds: 1600),
}) async {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    'sound.sfx': false,
    'sound.music': false,
    'utopia.theme': UtopiaThemes.utopiaTwilight.id,
  });
  final prefs = await SharedPreferences.getInstance();
  late BuildContext host;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        gameAudioProvider.overrideWithValue(_Quiet()),
        isAnonymousProvider.overrideWithValue(false),
        currentUserProvider.overrideWithValue(null),
        coinBalanceProvider.overrideWith((ref) => Stream.value(40000)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) {
            host = context;
            return Stack(
              children: [
                Positioned.fill(
                  child: UtopiaWorld(style: UtopiaThemes.active.world),
                ),
              ],
            );
          },
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
  unawaited(showPurchaseResult(host, ValueNotifier(result)));
  final steps = settle.inMilliseconds ~/ 100;
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.runAsync(GoogleFonts.pendingFonts);
  await tester.pump(const Duration(milliseconds: 50));
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/purchase_$name.png'),
  );
  while (tester.takeException() != null) {}
}

void main() {
  testWidgets('paid, coins', (tester) async {
    await _shoot(
      tester,
      'paid_coins',
      const PurchaseResult(
        stage: PurchaseStage.paid,
        coins: 20000,
        paid: '₦1,000',
        balance: 40000,
      ),
      settle: const Duration(milliseconds: 1200),
    );
  });

  testWidgets('paid, Chip Maestro', (tester) async {
    await _shoot(
      tester,
      'paid_maestro',
      const PurchaseResult(
        stage: PurchaseStage.paid,
        plan: true,
        paid: '£6.49',
      ),
      settle: const Duration(milliseconds: 1200),
    );
  });

  testWidgets('confirming', (tester) async {
    await _shoot(
      tester,
      'confirming',
      const PurchaseResult(stage: PurchaseStage.confirming, coins: 55000),
    );
  });

  testWidgets('still confirming', (tester) async {
    await _shoot(
      tester,
      'waiting',
      const PurchaseResult(stage: PurchaseStage.waiting, coins: 55000),
    );
  });

  testWidgets('failed', (tester) async {
    await _shoot(
      tester,
      'failed',
      const PurchaseResult(stage: PurchaseStage.failed, coins: 55000),
    );
  });

  testWidgets("couldn't confirm", (tester) async {
    await _shoot(
      tester,
      'unconfirmed',
      const PurchaseResult(stage: PurchaseStage.unconfirmed, coins: 55000),
    );
  });
}
