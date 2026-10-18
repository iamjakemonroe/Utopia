import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_controller.dart';
import '../theme/utopia_themes.dart';
import '../widgets/halloween_world.dart';
import '../widgets/utopia_world.dart' show worldSeconds;
import '../widgets/world_sets.dart';
import 'game_audio.dart';

/// A world whose music is its own soundscape.
///
/// Halloween's replaces the menu music: a calm, spooky bed
/// ([MusicTrack.halloween]) with a music box picking out a lullaby that's
/// never the same twice, and, in step with the scene: thunder with every
/// strike of lightning (loud and at once when it's near, faint and late
/// when it's far, just as the flash shows it), the witch laughing as she
/// crosses the moon (from the left to the right, as she flies), a shimmer
/// of magic as she sweeps in, a bell across the hollow when someone appears
/// in the tower window, a ghost's breath as it opens its mouth in view (as
/// loud as the ghost is clear), a ghost moaning from its side of the
/// hollow when everything's gone quiet, whispers from the trees where eyes open,
/// now and then a far-off owl, and once in a while the scare: a wraith
/// rushing out at you, screaming (sometimes after a swell of dread, and
/// sometimes the dread comes and nothing does). Played at the music's
/// volume (the scream louder), and only while that music is (so not in
/// games, or with the music off).
///
/// Reads the same clock and timings as the scene ([worldSeconds],
/// [HalloweenTimeline]), so nothing is heard before or after it's seen.
///
/// The Birthday world has music of its own too: a birthday song in place
/// of the menu's ([MusicTrack.birthday]).
class WorldSoundscape {
  WorldSoundscape(this._audio);

  final GameAudio _audio;
  final _rng = math.Random();
  Timer? _tick;
  bool _on = false;
  double _last = 0;
  double _nextPhrase = 0;
  double _nextOwl = 0;
  double _ghostsQuietUntil = 0;
  double _whispersQuietUntil = 0;
  double _moanQuietUntil = 0;

  /// When something last broke the quiet.
  double _lastEvent = 0;
  int _note = 2;

  static const _thunder = [Sfx.hwThunder1, Sfx.hwThunder2, Sfx.hwThunder3];

  static const _notes = [
    Sfx.hwNote1,
    Sfx.hwNote2,
    Sfx.hwNote3,
    Sfx.hwNote4,
    Sfx.hwNote5,
    Sfx.hwNote6,
  ];

  /// Sounds waiting for their moment: (when, sound, volume).
  final List<(double, Sfx, double)> _due = [];

  /// Sounds waiting for their moment that play as sound effects (louder).
  final List<(double, Sfx, double)> _loud = [];

  /// Plays [biome]'s music and sounds (Halloween has both, Birthday its
  /// song; other worlds keep the menu music).
  void update(WorldBiome biome) {
    _audio.setWorldTrack(switch (biome) {
      WorldBiome.halloween => MusicTrack.halloween,
      WorldBiome.birthday => MusicTrack.birthday,
      _ => null,
    });
    final on = biome == WorldBiome.halloween;
    if (on == _on) return;
    _on = on;
    _tick?.cancel();
    _due.clear();
    if (!on) return;
    _last = worldSeconds;
    _nextPhrase = _last + 3 + _rng.nextDouble() * 4;
    _nextOwl = _last + 20 + _rng.nextDouble() * 20;
    _tick = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _halloween(),
    );
  }

  /// Whether the moment [at] seconds into every [period] fell after [prev]
  /// and by [now].
  static bool crossed(double prev, double now, double period, double at) =>
      ((now - at) / period).floor() > ((prev - at) / period).floor();

  /// Whether the moment [at] fell after [prev] and by [now].
  static bool passed(double prev, double now, double at) =>
      prev < at && now >= at;

  bool _chance(double p) => _rng.nextDouble() < p;

  void _halloween() {
    final now = worldSeconds;
    final prev = _last;
    _last = now;
    // Back from the background (or a long stall), or the music's off, in a
    // game, or giving way to the player's own: nothing to catch up on.
    if (now - prev > 1 || !_audio.isPlaying(MusicTrack.halloween)) {
      _due.clear();
      _loud.clear();
      return;
    }
    final night = WorldSets.halloween.amount;

    // Thunder with every strike, as near as it looks: a near one cracks
    // loud right on the flash and rolls on; a far one rumbles faintly, a
    // moment after (sound takes its time from far away). Louder on a wild
    // night (the set on).
    if (crossed(prev, now, HalloweenTimeline.lightningPeriod(night), 0)) {
      final near = HalloweenTimeline.strikeNear(
        HalloweenTimeline.strike(now, night),
      );
      if (near >= 0.45) {
        // Near: loud, as a sound effect (and felt).
        _loud.add((
          now + 0.02 + (1 - near) * 0.35,
          _thunder[_rng.nextInt(_thunder.length)],
          (0.4 + 0.5 * near + 0.1 * night).clamp(0.0, 1.0),
        ));
      } else {
        _due.add((
          now + 1 + (1 - near) * 2,
          _chance(0.5) ? Sfx.hwRumble1 : Sfx.hwRumble2,
          0.25 + 0.5 * near,
        ));
      }
    }
    // The witch: a shimmer of magic as she sweeps in (some nights), and
    // every time, her laugh, swelling as she crosses the moon and trailing
    // off as she flies on. Nearer (louder) on a wild night.
    final witch = HalloweenTimeline.witchPeriod(night);
    if (crossed(prev, now, witch, 0.9) && _chance(0.5)) {
      _sound(Sfx.hwMagic, 0.45, now);
    }
    if (crossed(prev, now, witch, HalloweenTimeline.cackleAt)) {
      // Not a background sound: as loud as a sound effect.
      _sound(
        Sfx.hwCackle,
        (0.6 + 0.3 * night).clamp(0.0, 1.0),
        now,
        loud: true,
      );
    }
    // The scare: the scream and a jolt as the wraith rushes out, sometimes
    // after a swell of dread that cuts to silence first; and now and then
    // the dread comes and nothing does. The scream plays as a sound effect
    // (so it's loud: the music's soft).
    {
      final k = (now / HalloweenTimeline.scareSlot).floor();
      final slot = k * HalloweenTimeline.scareSlot;
      final at = HalloweenTimeline.scareIn(k);
      if (at != null) {
        if (HalloweenTimeline.scareWarned(k) &&
            passed(prev, now, slot + at - HalloweenTimeline.dreadLead)) {
          _sound(Sfx.hwDread, 0.75, now);
        }
        if (passed(prev, now, slot + at)) {
          _sound(Sfx.hwScream, 1, now, loud: true);
        }
      }
      final alarm = HalloweenTimeline.falseAlarmIn(k);
      if (alarm != null && passed(prev, now, slot + alarm)) {
        _sound(Sfx.hwDread, 0.6, now);
      }
    }
    // Whispers from the trees as eyes open there, on that side: faint, and
    // only now and then.
    if (now >= _whispersQuietUntil) {
      for (var i = 0; i < HalloweenTimeline.eyePairs(night); i++) {
        if (HalloweenTimeline.eyePhase(now, i) <
            HalloweenTimeline.eyePhase(prev, i)) {
          if (_chance(0.35)) {
            _sound(
              i.isEven ? Sfx.hwWhisperLeft : Sfx.hwWhisperRight,
              0.3 + 0.15 * night,
              now,
            );
            _whispersQuietUntil = now + 25 + _rng.nextDouble() * 20;
          }
          break;
        }
      }
    }
    // A bell across the hollow, now and then, as someone appears up in the
    // tower window.
    if (crossed(
          prev,
          now,
          HalloweenTimeline.watcherPeriod,
          HalloweenTimeline.watcherPeriod * HalloweenTimeline.watcherFrom,
        ) &&
        _chance(0.35)) {
      _sound(Sfx.hwBell, 0.45, now);
    }
    // A ghost's breath as its mouth opens wide, if it's in view.
    if (now >= _ghostsQuietUntil) {
      for (var i = 0; i < HalloweenTimeline.ghostCount(night); i++) {
        final fade = HalloweenTimeline.ghostFade(now, i);
        if (HalloweenTimeline.ghostScream(prev, i) < 0.93 &&
            HalloweenTimeline.ghostScream(now, i) >= 0.93 &&
            fade > 0.45) {
          _sound(
            i.isEven ? Sfx.hwGhost1 : Sfx.hwGhost2,
            0.25 + 0.3 * fade,
            now,
          );
          _ghostsQuietUntil = now + 14 - 4 * night;
          break;
        }
      }
    }
    // The music box: a few notes at a time, wandering up and down a minor
    // scale, so the lullaby is never the same twice.
    if (now >= _nextPhrase) {
      final notes = 1 + _rng.nextInt(3);
      var at = now;
      for (var k = 0; k < notes; k++) {
        _note = (_note + const [-2, -1, -1, 1, 1, 2, 0][_rng.nextInt(7)]).clamp(
          0,
          _notes.length - 1,
        );
        _due.add((at, _notes[_note], 0.35 + _rng.nextDouble() * 0.25));
        at += 0.45 + _rng.nextDouble() * 0.5;
      }
      _nextPhrase = at + 3.5 - night + _rng.nextDouble() * 5.5;
    }
    // An owl, somewhere in the trees.
    if (now >= _nextOwl) {
      _sound(Sfx.hwOwl, 0.4, now);
      _nextOwl = now + 28 + _rng.nextDouble() * 27;
    }
    // In the quiet (nothing much for a while, and nothing coming: no
    // lightning or witch about to), a ghost you can see moans, from its
    // side of the hollow, as loud as it's clear.
    if (now >= _moanQuietUntil &&
        now - _lastEvent > 5 &&
        clearAhead(now, night)) {
      for (var i = 0; i < HalloweenTimeline.ghostCount(night); i++) {
        final fade = HalloweenTimeline.ghostFade(now, i);
        if (fade > 0.45) {
          _sound(
            HalloweenTimeline.ghostCrossed(now, i) < 0.5
                ? Sfx.hwMoanLeft
                : Sfx.hwMoanRight,
            (0.5 + 0.5 * fade).clamp(0.0, 1.0),
            now,
          );
          _moanQuietUntil = now + 20 + _rng.nextDouble() * 15;
          break;
        }
      }
    }
    _due.removeWhere((d) {
      if (d.$1 > now) return false;
      // A far rumble is part of the quiet; the music box is the quiet.
      _audio.playWithMusic(d.$2, volume: d.$3);
      return true;
    });
    _loud.removeWhere((d) {
      if (d.$1 > now) return false;
      _sound(d.$2, d.$3, now, loud: true);
      return true;
    });
  }

  /// Plays [sfx] with the music (or, [loud], as a sound effect), and notes
  /// that the hollow wasn't quiet just now.
  void _sound(Sfx sfx, double volume, double now, {bool loud = false}) {
    if (loud) {
      _audio.play(sfx, volume: volume);
    } else {
      _audio.playWithMusic(sfx, volume: volume);
    }
    _lastEvent = now;
  }

  /// Whether nothing's about to happen: no lightning in the next 3.5
  /// seconds, and the witch not about to laugh.
  static bool clearAhead(double now, double night) {
    final lightning = HalloweenTimeline.lightningPeriod(night);
    final witch = HalloweenTimeline.witchPeriod(night);
    final nextStrike = lightning - now % lightning;
    final nextLaugh = (HalloweenTimeline.cackleAt - now % witch) % witch;
    return nextStrike > 3.5 && nextLaugh > 4;
  }

  void dispose() {
    _tick?.cancel();
    _audio.setWorldTrack(null);
  }
}

/// Plays the active world's own music and sounds, if it has them. Watched
/// at the app's root.
final worldSoundscapeProvider = Provider<void>((ref) {
  final scape = WorldSoundscape(ref.read(gameAudioProvider));
  ref.listen(
    themeControllerProvider,
    (_, theme) => scape.update(theme.world.biome),
  );
  ref.onDispose(scape.dispose);
  scape.update(ref.read(themeControllerProvider).world.biome);
});
