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

  test('every music track is in the assets', () {
    for (final track in MusicTrack.values) {
      final asset = track.asset;
      if (asset == null) continue;
      expect(File('assets/$asset').existsSync(), isTrue, reason: asset);
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

  test('the witch laughs as she crosses the moon, and is gone after', () {
    const at = HalloweenTimeline.cackleAt;
    const until = at + HalloweenTimeline.cackleLength;
    // Before the moon when it starts, past it when it ends.
    expect(
      HalloweenTimeline.witchAcross(at),
      lessThan(HalloweenTimeline.moonAcross),
    );
    expect(
      HalloweenTimeline.witchAcross(until),
      greaterThan(HalloweenTimeline.moonAcross),
    );
    // On screen the whole time, and over before she's flown off.
    expect(HalloweenTimeline.witchAcross(at), greaterThan(0));
    expect(HalloweenTimeline.witchAcross(until), lessThan(1));
    expect(until, lessThan(HalloweenTimeline.witchCrossing));
    // Once per crossing.
    final period = HalloweenTimeline.witchPeriod(0);
    expect(
      WorldSoundscape.crossed(
        period + at - 0.05,
        period + at + 0.05,
        period,
        at,
      ),
      isTrue,
    );
    expect(
      WorldSoundscape.crossed(
        period + at + 0.05,
        period + at + 0.15,
        period,
        at,
      ),
      isFalse,
    );
  });

  test('every strike has its nearness, and they vary', () {
    final near = [for (var n = 0; n < 40; n++) HalloweenTimeline.strikeNear(n)];
    expect(near.every((v) => v >= 0 && v < 1), isTrue);
    // Some near enough to crack, some far enough only to rumble.
    expect(near.where((v) => v >= 0.45), isNotEmpty);
    expect(near.where((v) => v < 0.45), isNotEmpty);
    expect(HalloweenTimeline.strike(9.5, 0), 1);
  });

  group('the scare', () {
    test('comes rarely, at moments no one can guess', () {
      final starts = [
        for (var k = 0; k < 60; k++)
          if (HalloweenTimeline.scareIn(k) case final at?)
            k * HalloweenTimeline.scareSlot + at,
      ];
      // Most stretches have one, not all.
      expect(starts.length, inInclusiveRange(42, 59));
      final gaps = [
        for (var i = 1; i < starts.length; i++) starts[i] - starts[i - 1],
      ];
      // Never two close together; about every 2 or 3 minutes.
      expect(gaps.reduce((a, b) => a < b ? a : b), greaterThan(40));
      final mean = gaps.reduce((a, b) => a + b) / gaps.length;
      expect(mean, inInclusiveRange(140, 220));
    });

    test('its dread starts inside its stretch, and false alarms keep away', () {
      for (var k = 0; k < 60; k++) {
        final at = HalloweenTimeline.scareIn(k);
        if (at != null) {
          expect(at - HalloweenTimeline.dreadLead, greaterThan(0));
        }
        final alarm = HalloweenTimeline.falseAlarmIn(k);
        if (alarm != null && at != null) {
          expect((alarm - at).abs(), greaterThan(45));
        }
      }
    });

    test('the wraith shows only while it rushes in', () {
      final k = [
        for (var k = 0; k < 20; k++) k,
      ].firstWhere((k) => HalloweenTimeline.scareIn(k) != null);
      final start =
          k * HalloweenTimeline.scareSlot + HalloweenTimeline.scareIn(k)!;
      expect(HalloweenTimeline.scareProgress(start - 0.1), isNull);
      expect(HalloweenTimeline.scareProgress(start + 0.4), closeTo(0.47, 0.01));
      expect(
        HalloweenTimeline.scareProgress(
          start + HalloweenTimeline.scareLength + 0.1,
        ),
        isNull,
      );
    });
  });

  test('eyes open on their own cycles, left and right', () {
    for (var i = 0; i < 6; i++) {
      final cycle = HalloweenTimeline.eyeCycle(i);
      expect(cycle, inInclusiveRange(4, 9));
      // Once round the cycle, it's back where it was.
      expect(
        HalloweenTimeline.eyePhase(10 + cycle, i),
        closeTo(HalloweenTimeline.eyePhase(10, i), 1e-9),
      );
    }
  });

  test('ghosts moan only when nothing is about to happen', () {
    // Just before a strike of lightning: not now.
    final period = HalloweenTimeline.lightningPeriod(0);
    expect(WorldSoundscape.clearAhead(period * 10 - 1, 0), isFalse);
    // Just before the witch laughs: not now either.
    final witch = HalloweenTimeline.witchPeriod(0);
    expect(
      WorldSoundscape.clearAhead(witch * 4 + HalloweenTimeline.cackleAt - 1, 0),
      isFalse,
    );
    // Some moments in a minute are clear.
    final clear = [
      for (var t = 0.0; t < 60; t += 0.1)
        if (WorldSoundscape.clearAhead(t, 0)) t,
    ];
    expect(clear, isNotEmpty);
  });
}
