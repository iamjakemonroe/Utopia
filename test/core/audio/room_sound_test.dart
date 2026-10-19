import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/audio/room_sound.dart';
import 'package:utopia/core/theme/utopia_themes.dart';
import 'package:utopia/core/widgets/music_world.dart';
import 'package:utopia/core/widgets/utopia_world.dart' show worldSeconds;

/// 50 ms of 16 kHz sound at [loudness] (0 silent, 1 full): noise, so it's
/// like a room.
Uint8List _chunk(double loudness, math.Random random) {
  const samples = 800;
  final data = ByteData(samples * 2);
  for (var i = 0; i < samples; i++) {
    final v = (random.nextDouble() * 2 - 1) * loudness * 32767;
    data.setInt16(i * 2, v.round(), Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  late double now;
  late RoomListener ears;
  final random = math.Random(1);

  setUp(() {
    now = 0;
    ears = RoomListener(clock: () => now);
    RoomSound.level = 0;
    RoomSound.beatAt = -100;
    RoomSound.beats = 0;
  });

  /// [seconds] of sound, [loudness] for each 50 ms by its time.
  void play(double seconds, double Function(double t) loudness) {
    for (var t = 0.0; t < seconds; t += 0.05) {
      now += 0.05;
      ears.hear(_chunk(loudness(t), random));
    }
  }

  test('a quiet room: no beats, and quiet', () {
    play(4, (_) => 0.002);
    expect(RoomSound.beats, 0);
    expect(RoomSound.level, lessThan(0.1));
  });

  test('a kick every half second: a beat on each', () {
    play(1, (_) => 0.01);
    // 120 BPM: a loud thump for 50 ms, then quiet, for 6 seconds.
    play(6, (t) => (t % 0.5) < 0.05 ? 0.6 : 0.02);
    expect(RoomSound.beats, inInclusiveRange(10, 13), reason: '12 kicks');
  });

  test('loud music: loud, with its beats', () {
    play(1, (_) => 0.02);
    play(4, (t) => (t % 0.5) < 0.1 ? 0.8 : 0.25);
    expect(RoomSound.level, greaterThan(0.5));
    expect(RoomSound.beats, greaterThanOrEqualTo(6));
  });

  test('one steady sound is not a stream of beats', () {
    play(1, (_) => 0.01);
    play(5, (_) => 0.4);
    expect(
      RoomSound.beats,
      lessThanOrEqualTo(1),
      reason: 'only where it began',
    );
  });

  test('the Music world draws to the room, on a beat and between', () {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = Size(390, 844);
    for (final (listening, level, sinceBeat) in [
      (false, 0.0, 10.0),
      (true, 0.9, 0.0),
      (true, 0.9, 0.2),
      (true, 0.1, 5.0),
    ]) {
      RoomSound.listening = listening;
      RoomSound.level = level;
      RoomSound.beatAt = worldSeconds - sinceBeat;
      paintMusicScene(
        canvas,
        size,
        worldSeconds,
        UtopiaThemes.utopiaMusic.world,
        moon: const Offset(290, 130),
      );
    }
    recorder.endRecording().dispose();
    RoomSound.listening = false;
  });
}
