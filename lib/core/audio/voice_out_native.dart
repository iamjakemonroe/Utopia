import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays voice notes on a phone (a browser has its own, voice_out_web.dart).
class VoiceOut {
  VoiceOut() {
    // Android: played as speech on the media volume, other apps dipping
    // meanwhile, not as one of the game's effects. (An iPhone's audio setup
    // is the whole app's: GameAudio.voiceSession changes it.)
    if (defaultTargetPlatform == TargetPlatform.android) {
      unawaited(
        _player
            .setAudioContext(
              AudioContext(
                android: const AudioContextAndroid(
                  contentType: AndroidContentType.speech,
                  usageType: AndroidUsageType.media,
                  audioFocus: AndroidAudioFocus.gainTransientMayDuck,
                ),
              ),
            )
            .catchError((Object e) => debugPrint('VoiceOut: $e')),
      );
    }
  }

  final AudioPlayer _player = AudioPlayer(playerId: 'utopia-voice');

  /// Readies the browser's player; nothing to ready on a phone.
  static void prime() {}

  Stream<Duration> get position => _player.onPositionChanged;

  Stream<void> get completed => _player.onPlayerComplete;

  Future<void> play(String url) => _player.play(UrlSource(url));

  Future<void> stop() => _player.stop();

  void dispose() => unawaited(_player.dispose());
}
