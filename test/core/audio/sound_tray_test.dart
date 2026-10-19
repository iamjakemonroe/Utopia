import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia/core/audio/sound_controls.dart';
import 'package:utopia/core/theme/theme_controller.dart';

void main() {
  testWidgets('the chat button works with the sound buttons open, and closes them', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var chats = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              child: Row(
                children: [
                  const Spacer(),
                  const SoundQuickToggle(),
                  IconButton(
                    key: const Key('chat'),
                    icon: const Icon(Icons.chat_bubble_rounded),
                    onPressed: () {
                      closeSoundTray();
                      chats++;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    await tester.pumpAndSettle();
    expect(soundTrayOpen.value, isTrue);
    await tester.tap(find.byKey(const Key('chat')));
    await tester.pumpAndSettle();
    expect(chats, 1);
    expect(soundTrayOpen.value, isFalse);
  });
}
