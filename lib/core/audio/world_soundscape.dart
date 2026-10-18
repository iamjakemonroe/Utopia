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
/// never the same twice, and, in step with the scene, everything soft and
/// far away: a distant rumble after some flashes of lightning, a shimmer of
/// magic as the witch crosses the moon, a bell across the hollow when
/// someone appears in the tower window, a ghost's breath as it opens its
/// mouth in view, and now and then an owl. Played at the music's volume, and
/// only while that music is (so not in games, or with the music off).
///
/// Reads the same clock and timings as the scene ([worldSeconds],
/// [HalloweenTimeline]), so nothing is heard before or after it's seen.
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
  int _note = 2;

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

  /// Plays [biome]'s music and sounds (Halloween has them; other worlds
  /// keep the menu music).
  void update(WorldBiome biome) {
    final on = biome == WorldBiome.halloween;
    _audio.setWorldTrack(on ? MusicTrack.halloween : null);
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

  bool _chance(double p) => _rng.nextDouble() < p;

  void _halloween() {
    final now = worldSeconds;
    final prev = _last;
    _last = now;
    // Back from the background (or a long stall), or the music's off, in a
    // game, or giving way to the player's own: nothing to catch up on.
    if (now - prev > 1 || !_audio.isPlaying(MusicTrack.halloween)) {
      _due.clear();
      return;
    }
    final night = WorldSets.halloween.amount;

    // A low rumble, far away, after some of the lightning.
    if (crossed(prev, now, HalloweenTimeline.lightningPeriod(night), 0) &&
        _chance(0.6)) {
      _due.add((
        now + 1.5 + _rng.nextDouble() * 1.5,
        _chance(0.5) ? Sfx.hwRumble1 : Sfx.hwRumble2,
        0.5 + _rng.nextDouble() * 0.25,
      ));
    }
    // A shimmer of magic as the witch sweeps across the moon (some nights).
    if (crossed(prev, now, HalloweenTimeline.witchPeriod(night), 0.9) &&
        _chance(0.5)) {
      _audio.playWithMusic(Sfx.hwMagic, volume: 0.55);
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
      _audio.playWithMusic(Sfx.hwBell, volume: 0.45);
    }
    // A ghost's breath as its mouth opens wide, if it's in view.
    if (now >= _ghostsQuietUntil) {
      for (var i = 0; i < HalloweenTimeline.ghostCount(night); i++) {
        final fade = HalloweenTimeline.ghostFade(now, i);
        if (HalloweenTimeline.ghostScream(prev, i) < 0.93 &&
            HalloweenTimeline.ghostScream(now, i) >= 0.93 &&
            fade > 0.45) {
          _audio.playWithMusic(
            i.isEven ? Sfx.hwGhost1 : Sfx.hwGhost2,
            volume: 0.25 + 0.3 * fade,
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
      _audio.playWithMusic(Sfx.hwOwl, volume: 0.4);
      _nextOwl = now + 28 + _rng.nextDouble() * 27;
    }
    _due.removeWhere((d) {
      if (d.$1 > now) return false;
      _audio.playWithMusic(d.$2, volume: d.$3);
      return true;
    });
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
