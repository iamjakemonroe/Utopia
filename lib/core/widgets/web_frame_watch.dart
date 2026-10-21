import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics.dart';
import '../router/app_router.dart';

/// In a browser: measures how fast the game draws while it's animating,
/// and records it once a visit for each screen (by its path, without ids),
/// so slow screens and devices show up in analytics. It also records each
/// freeze of [freezeMs] or more, two ways: a frame that took that long
/// from start to on screen (`web_freeze`, with whether the app's own work
/// or the drawing took the time), and a gap that long between two frames
/// while something was moving (`web_stall`: the app busy between frames).
/// Each with the screen and how long it had been open. It never changes
/// how anything is drawn.
class WebFrameWatch extends ConsumerStatefulWidget {
  const WebFrameWatch({super.key});

  @override
  ConsumerState<WebFrameWatch> createState() => _WebFrameWatchState();
}

/// A frame this slow, start to finish, is a freeze a player notices.
const freezeMs = 300;

/// Freezes recorded a visit, at most (and at most one every few seconds).
const _maxFreezes = 12;

class _WebFrameWatchState extends ConsumerState<WebFrameWatch> {
  int _freezes = 0;
  DateTime _lastFreeze = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _screenSince = DateTime.now();
  String? _freezeScreen;

  /// The last frame left another one asked for (something moving).
  bool _moving = false;

  /// The tab was hidden or shown since the last frame (a gap then is the
  /// browser resting, not a freeze).
  bool _awayBetween = false;
  AppLifecycleListener? _life;
  Duration? _last;
  final _gaps = <double>[];
  String? _screen;
  DateTime _settled = DateTime.now().add(const Duration(seconds: 5));
  final _reported = <String>{};
  bool _on = true;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;
    SchedulerBinding.instance.addPersistentFrameCallback(_onFrame);
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _life = AppLifecycleListener(onStateChange: (_) => _awayBetween = true);
  }

  /// The browser's own timing of each frame: what it spent building it
  /// (the app's code) and drawing it (the graphics card).
  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      final total = t.totalSpan.inMilliseconds;
      if (total < freezeMs) continue;
      _record('web_freeze', {
        'ms': total,
        'build_ms': t.buildDuration.inMilliseconds,
        'raster_ms': t.rasterDuration.inMilliseconds,
      });
    }
  }

  /// A freeze, with where it happened: at most one every few seconds and
  /// [_maxFreezes] a visit.
  void _record(String name, Map<String, Object?> props) {
    if (!_on || _freezes >= _maxFreezes) return;
    final now = DateTime.now();
    if (now.difference(_lastFreeze) < const Duration(seconds: 4)) return;
    _lastFreeze = now;
    _freezes++;
    ref.read(analyticsProvider).log(name, {
      ...props,
      'path': _freezeScreen ?? _path(),
      // Seconds the screen had been open: a freeze as it opens is
      // different from one in the middle of play.
      'open_s': now.difference(_screenSince).inSeconds,
      'nth': _freezes,
      'wasm': const bool.fromEnvironment('dart.tool.dart2wasm'),
    });
  }

  @override
  void dispose() {
    _on = false;
    _life?.dispose();
    if (kIsWeb) SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }

  /// The screen showing, e.g. /chess/match/:id.
  String _path() {
    try {
      final path = ref
          .read(goRouterProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .path;
      return path
          .split('/')
          .map(
            (part) =>
                RegExp(r'^[0-9a-f-]{16,}$|^\d+$').hasMatch(part) ? ':id' : part,
          )
          .join('/');
    } catch (_) {
      return '?';
    }
  }

  void _onFrame(Duration stamp) {
    if (!_on) return;
    final last = _last;
    _last = stamp;
    final screen = _path();
    if (screen != _freezeScreen) {
      _freezeScreen = screen;
      _screenSince = DateTime.now();
    }
    // A long gap while something was moving: the app was busy between
    // frames.
    final moving = _moving;
    final away = _awayBetween;
    _awayBetween = false;
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => _moving = SchedulerBinding.instance.hasScheduledFrame,
    );
    if (last == null) return;
    final gap = (stamp - last).inMilliseconds;
    if (moving && !away && gap >= freezeMs) {
      _record('web_stall', {'ms': gap});
    }
    if (screen != _screen) {
      // A new screen: give it a moment to settle before judging it.
      _screen = screen;
      _gaps.clear();
      _settled = DateTime.now().add(const Duration(seconds: 2));
      return;
    }
    final ms = (stamp - last).inMicroseconds / 1000;
    // Back-to-back frames only: a longer pause is the app sitting still.
    if (ms <= 0 || ms > 250 || DateTime.now().isBefore(_settled)) return;
    if (_reported.contains(screen)) return;
    _gaps.add(ms);
    if (_gaps.length < 120) return;
    final average = _gaps.reduce((a, b) => a + b) / _gaps.length;
    _gaps.clear();
    _reported.add(screen);
    final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
    ref.read(analyticsProvider).log('web_fps', {
      'fps': (1000 / average).round(),
      'screen': view?.devicePixelRatio,
      'path': screen,
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
