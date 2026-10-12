import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia/core/chip/chip_brain.dart';
import 'package:utopia/core/theme/theme_controller.dart';
import 'package:utopia/features/auth/presentation/providers/auth_providers.dart';
import 'package:utopia/features/chip/presentation/chip_chat_controller.dart';
import 'package:utopia/features/chip/presentation/chip_chat_sheet.dart';
import 'package:utopia/features/doodle_studio/data/picture_library.dart';

void main() {
  testWidgets('a kept chat comes back with its button and its picture', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'chip_chat_me': jsonEncode([
        const ChipLine(
          fromChip: false,
          text: 'Can I have a million coins?',
        ).toStore(),
        const ChipLine(
          fromChip: true,
          text: "I'm a coin, not a bank! Your daily reward is waiting though.",
          mood: 'excited',
          open: 'coins',
        ).toStore(),
        const ChipLine(fromChip: false, text: 'Draw me a lion').toStore(),
        const ChipLine(
          fromChip: true,
          text: 'On it!',
          picture: ChipPicture(status: 'drawing', subject: 'lion', id: 'l1'),
        ).toStore(),
      ]),
    });
    final prefs = await SharedPreferences.getInstance();
    late BuildContext host;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          isAnonymousProvider.overrideWithValue(false),
          chipChatProvider.overrideWith(
            (ref) => ChipChatController(ref, prefs, 'me'),
          ),
          pictureWatchProvider.overrideWith(
            (ref, id) => Stream.value(
              const LibraryPicture(
                id: 'l1',
                status: 'ready',
                title: 'Sleepy lion',
                paths: ['M 100 100 L 900 100 L 900 1200 L 100 1200 Z'],
              ),
            ),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              host = context;
              return const Scaffold();
            },
          ),
        ),
      ),
    );
    showChipChat(host);
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Can I have a million coins?'), findsOneWidget);
    expect(find.text('Get coins'), findsOneWidget);
    expect(find.text('Sleepy lion'), findsOneWidget);
    expect(find.text('Color it'), findsOneWidget);
    expect(find.byTooltip('New chat'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });
}
