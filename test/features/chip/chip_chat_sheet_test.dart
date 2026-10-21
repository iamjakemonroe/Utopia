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
import 'package:utopia/features/maestro/data/maestro_repository.dart';
import 'package:utopia/features/maestro/presentation/maestro_providers.dart';

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
    // It opens on the newest line, at the bottom.
    expect(find.text('Sleepy lion'), findsOneWidget);
    // Not in the Doodle world, and it isn't theirs: the button says so.
    expect(find.text('Get the Doodle world to color it'), findsOneWidget);
    expect(find.byTooltip('New chat'), findsOneWidget);
    // The older lines are above it.
    await tester.drag(find.byType(ListView).first, const Offset(0, 700));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Can I have a million coins?'), findsOneWidget);
    expect(find.text('Get coins'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('out of chats: keep going for coins, or Chip Maestro', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'sound.sfx': false});
    final prefs = await SharedPreferences.getInstance();
    late BuildContext host;
    Future<void> open({required bool member}) async {
      // A fresh app each time (the last one's sheet closed with it).
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            isAnonymousProvider.overrideWithValue(false),
            maestroProvider.overrideWith(
              (ref) async => MaestroStatus(active: member),
            ),
            chipChatProvider.overrideWith(
              (ref) =>
                  ChipChatController(ref, prefs, 'me')
                    ..debugLines = const [
                      ChipLine(fromChip: false, text: 'One more?'),
                      ChipLine(
                        fromChip: true,
                        text: 'My sprout is tired. 20 coins a message?',
                        mood: 'sad',
                        limit: 'coins',
                        price: 20,
                      ),
                    ],
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
    }

    await open(member: false);
    expect(find.text('Keep chatting · 20 coins'), findsOneWidget);
    expect(find.text('Chip Maestro: 200 chats a day'), findsOneWidget);
    expect(find.text('Upgrade Chip'), findsOneWidget);

    await open(member: true);
    expect(find.text('Keep chatting · 20 coins'), findsOneWidget);
    expect(find.text('Chip Maestro: 200 chats a day'), findsNothing);
    expect(find.text('Maestro'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
