import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/audio/game_audio.dart';

void main() {
  testWidgets('games make no sound or buzz while the app is hidden', (
    tester,
  ) async {
    final buzzes = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') buzzes.add(call.arguments);
        return null;
      },
    );
    // Music and sound files off: only the buzz shows whether play() ran.
    final audio = GameAudio(const SoundSettings(musicOn: false, sfxOn: false));
    addTearDown(audio.dispose);

    audio.play(Sfx.diceLand);
    await tester.pump();
    expect(buzzes, hasLength(1));

    // A system sheet over the app: still on screen, still heard.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    audio.play(Sfx.diceLand);
    await tester.pump();
    expect(buzzes, hasLength(2));

    // Off to another app: an online match carries on without a sound.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    audio.play(Sfx.diceLand);
    audio.play(Sfx.yourTurn);
    await tester.pump();
    expect(buzzes, hasLength(2));

    // Back again.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    audio.play(Sfx.diceLand);
    await tester.pump();
    expect(buzzes, hasLength(3));
  });

  testWidgets("a world's sounds play with the music off, but not in a game", (
    tester,
  ) async {
    // Music off, effects on: the Halloween world's thunder and screams
    // still play (only its music box is the music).
    final audio = GameAudio(const SoundSettings(musicOn: false));
    addTearDown(audio.dispose);
    audio.setBaseTrack(MusicTrack.menu);
    audio.setWorldTrack(MusicTrack.halloween);
    await tester.pump();
    expect(audio.worldShowing(MusicTrack.halloween), isTrue);
    expect(audio.isPlaying(MusicTrack.halloween), isFalse, reason: 'no music');

    // In a game: not the world's.
    final game = audio.pushTrack(MusicTrack.game);
    expect(audio.worldShowing(MusicTrack.halloween), isFalse);
    audio.popTrack(game);
    expect(audio.worldShowing(MusicTrack.halloween), isTrue);

    // Away (another app): nothing.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    expect(audio.worldShowing(MusicTrack.halloween), isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(audio.worldShowing(MusicTrack.halloween), isTrue);

    // Another world: not Halloween's.
    audio.setWorldTrack(null);
    expect(audio.worldShowing(MusicTrack.halloween), isFalse);
  });
}
