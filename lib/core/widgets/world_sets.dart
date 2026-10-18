import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

/// A set being worn: a world with its matching aura. Switched on or off by
/// the set's provider; [amount] fades over a couple of seconds so the world
/// and Chip change together rather than popping.
class SetBonus {
  SetBonus() {
    on.addListener(_changed);
  }

  final on = ValueNotifier<bool>(false);

  static final _clock = Stopwatch()..start();
  static double get _now => _clock.elapsedMicroseconds / 1e6;
  double _changedAt = -100;

  void _changed() => _changedAt = _now;

  /// 0 off, 1 fully on.
  double get amount {
    final k = Curves.easeInOut.transform(
      ((_now - _changedAt) / 2.5).clamp(0.0, 1.0),
    );
    return on.value ? k : 1 - k;
  }

  /// Skips the fade, so the next frame shows [on] fully (for tests and
  /// previews).
  void settle() => _changedAt = -100;
}

/// The sets there are, one for each world that has one. A player is in one
/// world at a time, so at most one is on.
abstract final class WorldSets {
  /// Dragon Coil in the Dojo: the dragon breaks free, and Chip squares up
  /// to it in a headband.
  static final dragon = SetBonus();

  /// Zombie Bite in the Zombie world: Chip turns, the world goes deader.
  static final zombie = SetBonus();

  /// Angel Halo in Heaven: Chip gets his wings, the gates open.
  static final heaven = SetBonus();

  /// Inferno in Hell: Chip grows horns, the fires rise.
  static final hell = SetBonus();

  /// Encore in the Music world: Chip puts on his headphones and shades and
  /// the show peaks, with fireworks, confetti and the crowd jumping.
  static final music = SetBonus();

  /// Jack's Lantern in the Halloween world: Chip is carved into a
  /// jack-o'-lantern in a witch's hat, and the night turns.
  static final halloween = SetBonus();

  /// Not a set: the player's own music is playing, so the Music world
  /// dances harder.
  static final musicLive = SetBonus();

  /// The player's birthday: Chip puts on a party hat (on the day, in any
  /// world). Worn with the Birthday frame in the Birthday world, the party
  /// peaks.
  static final birthday = SetBonus();

  /// Not a world's set but the same idea: a Chip Maestro member's Chip
  /// wears his artist's beret, with a brush tucked behind him.
  static final maestro = SetBonus();
}
