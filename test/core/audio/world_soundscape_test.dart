import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/audio/game_audio.dart';
import 'package:utopia/core/audio/world_soundscape.dart';
import 'package:utopia/core/widgets/halloween_world.dart';

void main() {
  test('every sound the game can play is in the assets', () {
    for (final sfx in Sfx.values) {
      expect(
        File('assets/sfx/${sfx.file}.wav').existsSync(),
        isTrue,
        reason: sfx.file,
      );
    }
  });

  test('a moment in a repeating cycle is caught once, as it passes', () {
    // Lightning every 9 seconds, flashing at 0, 9, 18...
    const period = 9.0;
    var hits = <double>[];
    for (var t = 0.05; t < 30; t += 0.1) {
      if (WorldSoundscape.crossed(t, t + 0.1, period, 0)) hits.add(t + 0.1);
    }
    expect(hits.length, 3); // 9, 18, 27
    for (final (i, at) in hits.indexed) {
      expect(at, closeTo(period * (i + 1), 0.11));
    }
  });

  test('the witch is heard while she is crossing the moon', () {
    final period = HalloweenTimeline.witchPeriod(0);
    // The cackle's moment, 0.9 s into each crossing, is inside it.
    expect(0.9, lessThan(HalloweenTimeline.witchCrossing));
    expect(
      WorldSoundscape.crossed(period + 0.85, period + 0.95, period, 0.9),
      isTrue,
    );
    expect(
      WorldSoundscape.crossed(period + 0.95, period + 1.05, period, 0.9),
      isFalse,
    );
  });
}
