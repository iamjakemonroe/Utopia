// Chip Maestro, for a look: the sheet with free next to Maestro, and Chip's
// chat with the Upgrade pill and, once today's chats are used, the way to
// Maestro. Renders test/tool/goldens/maestro_*.png. Run:
// flutter test --run-skipped --update-goldens test/tool/maestro_sheet_test.dart
@Tags(['sheet'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
// The store plugin's own message types, to answer it in a test.
// ignore: implementation_imports, depend_on_referenced_packages
import 'package:in_app_purchase_android/src/messages.g.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia/core/chip/chip_brain.dart';
import 'package:utopia/core/theme/theme_controller.dart';
import 'package:utopia/core/theme/utopia_themes.dart';
import 'package:utopia/core/widgets/utopia_world.dart';
import 'package:utopia/features/auth/presentation/providers/auth_providers.dart';
import 'package:utopia/features/chip/presentation/chip_chat_controller.dart';
import 'package:utopia/features/chip/presentation/chip_chat_sheet.dart';
import 'package:utopia/features/maestro/data/maestro_repository.dart';
import 'package:utopia/features/maestro/presentation/maestro_providers.dart';
import 'package:utopia/features/maestro/presentation/maestro_sheet.dart';
import 'package:utopia/features/maestro/presentation/maestro_widgets.dart';

Future<void> _shoot(
  WidgetTester tester,
  String name,
  void Function(BuildContext host) open, {
  bool member = false,
  List<ChipLine> lines = const [],
}) async {
  tester.view.physicalSize = const Size(1290, 2796);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    'chip_chat_me': jsonEncode([for (final l in lines) l.toStore()]),
    'sound.sfx': false,
    'sound.music': false,
    'utopia.theme': UtopiaThemes.utopiaTwilight.id,
  });
  final prefs = await SharedPreferences.getInstance();
  // No store in a test: every store call is answered "unavailable", so
  // the sheet shows as it would on a phone with no store connection.
  final messenger = tester.binding.defaultBinaryMessenger;
  const codec = InAppPurchaseApi.pigeonChannelCodec;
  for (final call in const ['startConnection', 'isReady', 'endConnection']) {
    messenger.setMockMessageHandler(
      'dev.flutter.pigeon.in_app_purchase_android.InAppPurchaseApi.$call',
      (_) async => codec.encodeMessage(<Object?>[
        if (call == 'startConnection')
          PlatformBillingResult(
            responseCode: PlatformBillingResponse.serviceUnavailable,
            debugMessage: 'no store in tests',
          )
        else if (call == 'isReady')
          false
        else
          null,
      ]),
    );
  }
  late BuildContext host;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isAnonymousProvider.overrideWithValue(false),
        currentUserProvider.overrideWithValue(null),
        maestroProvider.overrideWith(
          (ref) async => MaestroStatus(
            active: member,
            freePortrait: !member,
            left: 24,
            autoRenew: true,
            until: DateTime(2026, 11, 21),
          ),
        ),
        chipChatProvider.overrideWith(
          (ref) => ChipChatController(ref, prefs, 'me'),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Builder(
          builder: (context) {
            host = context;
            return Stack(
              children: [
                Positioned.fill(
                  child: UtopiaWorld(style: UtopiaThemes.active.world),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 80,
                  child: MaestroStrip(),
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
  open(host);
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.runAsync(GoogleFonts.pendingFonts);
  await tester.pump(const Duration(milliseconds: 300));
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/maestro_$name.png'),
  );
  while (tester.takeException() != null) {}
}

void main() {
  testWidgets('the sheet', (tester) async {
    await _shoot(tester, 'sheet', showMaestroSheet);
  });

  testWidgets('the sheet, for a member', (tester) async {
    await _shoot(tester, 'member', showMaestroSheet, member: true);
  });

  testWidgets('out of chats', (tester) async {
    await _shoot(
      tester,
      'chat',
      showChipChat,
      lines: const [
        ChipLine(fromChip: false, text: 'One more question about chess!'),
        ChipLine(
          fromChip: true,
          text:
              "I've talked so much today my sprout is tired. I can keep going "
              'for 20 coins a message, or we chat again tomorrow!',
          mood: 'sad',
          limit: 'coins',
          price: 20,
        ),
      ],
    );
  });
}
