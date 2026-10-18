import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../router/app_router.dart';
import '../theme/theme_controller.dart';
import '../theme/utopia_themes.dart';
import '../widgets/halloween_world.dart';
import '../widgets/utopia_world.dart' show worldSeconds;
import '../widgets/world_sets.dart';
import 'game_audio.dart';

/// A world's own sounds, on home, in step with what's happening in it.
///
/// Halloween: wind always blowing under it all; thunder after every flash
/// of lightning (a near one cracks soon after, a far one rolls in later);
/// the witch cackling as she sweeps across the moon; the tower window
/// creaking as someone appears in it; a ghost moaning as its scream opens
/// wide, if it's in view; bats squeaking as they swirl, and an owl
/// somewhere in the trees. With Jack's Lantern on, the night quickens and
/// so do the sounds.
///
/// Reads the same clock and timings as the scene ([worldSeconds],
/// [HalloweenTimeline]), so nothing is heard before or after it's seen.
class WorldSoundscape {
  WorldSoundscape(this._audio);

  final GameAudio _audio;
  final _rng = math.Random();
  Timer? _tick;
  WorldBiome? _playing;
  double _last = 0;
  double _nextBats = 0;
  double _nextOwl = 0;
  double _ghostsQuietUntil = 0;

  /// Sounds waiting for their moment: (when, sound, volume).
  final List<(double, Sfx, double)> _due = [];

  /// Plays [biome]'s sounds while the player is on home ([onHome]), and
  /// stops them otherwise.
  void update({required WorldBiome biome, required bool onHome}) {
    final wanted = onHome && biome == WorldBiome.halloween ? biome : null;
    if (wanted == _playing) return;
    _playing = wanted;
    _tick?.cancel();
    _due.clear();
    if (wanted == null) {
      _audio.setAmbient(null);
      return;
    }
    _audio.setAmbient('sfx/hw_wind.wav', level: 0.35);
    _last = worldSeconds;
    _nextBats = _last + 4 + _rng.nextDouble() * 6;
    _nextOwl = _last + 9 + _rng.nextDouble() * 10;
    _tick = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _halloween(),
    );
  }

  /// Whether the moment [at] seconds into every [period] fell after [prev]
  /// and by [now].
  static bool crossed(double prev, double now, double period, double at) =>
      ((now - at) / period).floor() > ((prev - at) / period).floor();

  void _halloween() {
    final now = worldSeconds;
    final prev = _last;
    _last = now;
    // Back from the background (or a long stall): nothing to catch up on.
    if (now - prev > 1 || !_audio.worldSoundsOn) {
      _due.clear();
      return;
    }
    final night = WorldSets.halloween.amount;

    if (crossed(prev, now, HalloweenTimeline.lightningPeriod(night), 0)) {
      final near = _rng.nextBool();
      _due.add((
        now +
            (near
                ? 0.35 + _rng.nextDouble() * 0.4
                : 1.2 + _rng.nextDouble() * 1.0),
        near ? Sfx.hwThunderNear : Sfx.hwThunderFar,
        near ? 0.75 : 0.55,
      ));
    }
    if (crossed(prev, now, HalloweenTimeline.witchPeriod(night), 0.9)) {
      _audio.play(Sfx.hwWitch, volume: 0.6);
    }
    if (crossed(
      prev,
      now,
      HalloweenTimeline.watcherPeriod,
      HalloweenTimeline.watcherPeriod * HalloweenTimeline.watcherFrom,
    )) {
      _audio.play(Sfx.hwCreak, volume: 0.45);
    }
    if (now >= _ghostsQuietUntil) {
      for (var i = 0; i < HalloweenTimeline.ghostCount(night); i++) {
        final fade = HalloweenTimeline.ghostFade(now, i);
        if (HalloweenTimeline.ghostScream(prev, i) < 0.93 &&
            HalloweenTimeline.ghostScream(now, i) >= 0.93 &&
            fade > 0.4) {
          _audio.play(
            i.isEven ? Sfx.hwGhost1 : Sfx.hwGhost2,
            volume: 0.3 + 0.35 * fade,
          );
          _ghostsQuietUntil = now + 9 - 3 * night;
          break;
        }
      }
    }
    if (now >= _nextBats) {
      _audio.play(Sfx.hwBats, volume: 0.35);
      _nextBats = now + 7 - 3 * night + _rng.nextDouble() * 7;
    }
    if (now >= _nextOwl) {
      _audio.play(Sfx.hwOwl, volume: 0.4);
      _nextOwl = now + 18 + _rng.nextDouble() * 14;
    }
    _due.removeWhere((d) {
      if (d.$1 > now) return false;
      _audio.play(d.$2, volume: d.$3);
      return true;
    });
  }

  void dispose() {
    _tick?.cancel();
    _audio.setAmbient(null);
  }
}

/// Keeps the active world's sounds playing while home is on screen.
/// Watched at the app's root.
final worldSoundscapeProvider = Provider<void>((ref) {
  final scape = WorldSoundscape(ref.read(gameAudioProvider));
  final router = ref.watch(goRouterProvider);
  void sync() => scape.update(
    biome: ref.read(themeControllerProvider).world.biome,
    onHome: currentPath(router) == '/home',
  );
  router.routerDelegate.addListener(sync);
  ref.listen(themeControllerProvider, (_, _) => sync());
  ref.onDispose(() {
    router.routerDelegate.removeListener(sync);
    scape.dispose();
  });
  sync();
});
