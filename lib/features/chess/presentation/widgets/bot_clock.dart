import 'dart:math' as math;

/// A game clock for games played on this phone (against a bot, or two
/// people on one phone): each side has its own time, only the side to
/// move counts down, and every move made earns back [increment]. Starts
/// on the first move, like a real clock, so the opening move is free.
/// While the app is in the background the clock is [pause]d: nobody loses
/// time for answering a text.
class BotClock<S> {
  BotClock(this.total, Iterable<S> sides, {this.increment = Duration.zero})
    : _left = {for (final s in sides) s: total.inMilliseconds};

  final Duration total;
  final Duration increment;
  final Map<S, int> _left;
  S? _running;
  DateTime? _since;
  bool _paused = false;

  /// Time left for [side] right now.
  int msLeft(S side) {
    var ms = _left[side] ?? 0;
    final since = _since;
    if (_running == side && since != null) {
      ms -= DateTime.now().difference(since).inMilliseconds;
    }
    return math.max(0, ms);
  }

  bool isRunning(S side) => _running == side;

  /// [side] is to move: its time runs. Whoever just moved gets their
  /// increment.
  void start(S side) {
    final mover = _running;
    stop();
    if (mover != null && mover != side) {
      _left[mover] = (_left[mover] ?? 0) + increment.inMilliseconds;
    }
    _running = side;
    _since = _paused ? null : DateTime.now();
  }

  /// The app went to the background: time stops for everyone.
  void pause() {
    final running = _running;
    if (running != null) _left[running] = msLeft(running);
    _since = null;
    _paused = true;
  }

  /// Back in the app: the side to move's time runs again.
  void resume() {
    _paused = false;
    if (_running != null && _since == null) _since = DateTime.now();
  }

  /// Whose time is running, if anyone's.
  S? get running => _running;

  /// Everyone's time right now, for saving the game.
  Map<S, int> get snapshot => {for (final s in _left.keys) s: msLeft(s)};

  /// Picks a saved game back up: these times, [running]'s clock going.
  void restore(Map<S, int> left, S? running) {
    _left.addAll(left);
    _running = running;
    _since = running == null || _paused ? null : DateTime.now();
  }

  /// Nobody's time runs (the game is over).
  void stop() {
    final running = _running;
    if (running != null) _left[running] = msLeft(running);
    _running = null;
    _since = null;
  }

  /// A fresh game: everyone's time back, nothing running.
  void reset() {
    _running = null;
    _since = null;
    for (final s in _left.keys) {
      _left[s] = total.inMilliseconds;
    }
  }

  /// The side whose time just ran out, if any.
  S? get flagged {
    final running = _running;
    if (running == null) return null;
    return msLeft(running) == 0 ? running : null;
  }
}
