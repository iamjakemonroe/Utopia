import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/theme_controller.dart';
import '../widgets/utopia_world.dart' show worldSeconds;

/// What the room sounds like, for the Music world: how loud it is, and when
/// the last beat landed (on the world's clock). Read by the world's painter
/// every frame, written by [RoomListener] while it listens. Nothing of the
/// sound itself is kept: only these few numbers.
abstract final class RoomSound {
  /// Listening now.
  static bool listening = false;

  /// How loud, 0 (quiet) to 1 (a party), smoothed.
  static double level = 0;

  /// When the last beat landed, in [worldSeconds].
  static double beatAt = -100;

  /// Beats heard so far (the world changes color every four).
  static int beats = 0;

  /// While something else needs the microphone (a voice note being
  /// recorded), the room isn't listened to.
  static final hold = ValueNotifier<int>(0);

  /// Whether the room is driving the show: listening, and beats heard
  /// in the last couple of seconds.
  static bool get hearing => listening && worldSeconds - beatAt < 2.5;
}

/// Listens to the room through the microphone, for [RoomSound]: loudness
/// and beats only. The sound is read as it comes in and let go at once;
/// it's never recorded, kept or sent anywhere.
class RoomListener {
  RoomListener({@visibleForTesting double Function()? clock})
    : _now = clock ?? (() => worldSeconds);

  /// The world's clock (beats are timed on it, as the painter draws).
  final double Function() _now;

  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _sub;
  bool _starting = false;

  /// How loud the moment before was, and the room lately (from the first
  /// thing heard), in dB: a beat is a sudden rise (a drum hit, a clap)
  /// above the room, not just loudness, so a steady sound (a fan, a hum)
  /// isn't one.
  double? _previous;
  double _room = 0;

  /// Starts listening; false if the microphone isn't allowed (or the
  /// platform can't).
  Future<bool> start() async {
    if (_recorder != null || _starting) return true;
    _starting = true;
    final recorder = AudioRecorder();
    try {
      if (!await recorder.hasPermission()) {
        await recorder.dispose();
        return false;
      }
      final stream = await recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          // The room as it is: nothing evened out or cleaned up.
          autoGain: false,
          echoCancel: false,
          noiseSuppress: false,
          // Utopia's own sound, and the player's music, keep playing out
          // of the speaker alongside.
          iosConfig: IosRecordConfig(
            categoryOptions: [
              IosAudioCategoryOption.mixWithOthers,
              IosAudioCategoryOption.defaultToSpeaker,
              IosAudioCategoryOption.allowBluetoothA2DP,
            ],
          ),
        ),
      );
      _recorder = recorder;
      _sub = stream.listen(_hear, onError: (_) => stop());
      RoomSound.listening = true;
      return true;
    } catch (_) {
      await recorder.dispose();
      return false;
    } finally {
      _starting = false;
    }
  }

  /// What's just been heard, as 16-bit samples (for tests too).
  @visibleForTesting
  void hear(Uint8List chunk) => _hear(chunk);

  void _hear(Uint8List chunk) {
    final samples = chunk.length ~/ 2;
    if (samples == 0) return;
    final data = ByteData.sublistView(chunk);
    var sum = 0.0;
    for (var i = 0; i < samples; i++) {
      final v = data.getInt16(i * 2, Endian.little) / 32768;
      sum += v * v;
    }
    final rms = math.sqrt(sum / samples);
    final db = 20 * math.log(math.max(rms, 1e-6)) / math.ln10;
    // A quiet room (-55 dB) to a loud one (-12 dB).
    final loud = ((db + 55) / 43).clamp(0.0, 1.0);
    RoomSound.level = RoomSound.level * 0.75 + loud * 0.25;
    // Beats in decibels, where a hit stands out as much in loud music as
    // in a quiet room: a jump of 3 dB on the moment before, above the room
    // lately, and not lost in a whisper.
    final previous = _previous;
    _previous = db;
    final room = _room = previous == null ? db : _room * 0.9 + db * 0.1;
    final now = _now();
    if (previous != null &&
        db - previous > 3 &&
        db > room + 1.5 &&
        db > -45 &&
        now - RoomSound.beatAt > 0.27) {
      RoomSound.beatAt = now;
      RoomSound.beats++;
    }
  }

  Future<void> stop() async {
    final recorder = _recorder;
    _recorder = null;
    await _sub?.cancel();
    _sub = null;
    RoomSound.listening = false;
    RoomSound.level = 0;
    _previous = null;
    _room = 0;
    if (recorder == null) return;
    try {
      await recorder.stop();
    } catch (_) {}
    await recorder.dispose();
  }
}

/// Whether the Music world listens to the room (Settings > Sound), off
/// until the player turns it on; and whether they've been asked.
class MusicWorldListens extends StateNotifier<bool> {
  MusicWorldListens(this._prefs) : super(_prefs?.getBool(_key) ?? false);

  final SharedPreferences? _prefs;

  static const _key = 'music_world.listens';
  static const _askedKey = 'music_world.asked';

  bool get asked => _prefs?.getBool(_askedKey) ?? false;

  void set(bool on) {
    state = on;
    _prefs?.setBool(_key, on);
    _prefs?.setBool(_askedKey, true);
  }

  void markAsked() => _prefs?.setBool(_askedKey, true);
}

final musicWorldListensProvider =
    StateNotifierProvider<MusicWorldListens, bool>((ref) {
      SharedPreferences? prefs;
      try {
        prefs = ref.watch(sharedPreferencesProvider);
      } catch (_) {}
      return MusicWorldListens(prefs);
    });
