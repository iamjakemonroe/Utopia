import 'package:flutter/widgets.dart';

/// The Dojo world's dragon, shared between the world and the Dragon Coil
/// aura. Normally it circles the castle in the sky. Wear the aura in the
/// Dojo world and the set is complete: the dragon breaks free and flies
/// the whole screen. And whenever a large Dragon Coil frame is on screen
/// (someone's profile), the dragon flies down to circle it.
abstract final class DojoDragon {
  /// The set is complete: the player wears Dragon Coil in the Dojo world.
  static final free = ValueNotifier<bool>(false);

  /// A Dragon Coil frame on screen: its centre (in global coordinates) and
  /// radius. Null when there's none.
  static (Offset, double)? get perch => _perch;
  static (Offset, double)? _perch;

  /// The last frame it circled, kept while it flies back to the sky.
  static (Offset, double)? lastPerch;

  /// World time (seconds) when a frame last appeared or went away, so the
  /// dragon can fly in and out instead of jumping.
  static double perchChangedAt = -100;

  static Object? _owner;

  /// A frame claims the dragon. [now] is the world clock.
  static void claim(Object owner, Offset centre, double radius, double now) {
    if (_perch == null) perchChangedAt = now;
    _owner = owner;
    _perch = (centre, radius);
    lastPerch = _perch;
  }

  /// That frame is gone (only if it's still the one the dragon is on).
  static void release(Object owner, double now) {
    if (_owner != owner) return;
    _owner = null;
    _perch = null;
    perchChangedAt = now;
  }
}
