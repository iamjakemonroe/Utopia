import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics.dart';
import '../router/app_router.dart';

/// In a browser: measures how fast the game draws while it's animating,
/// and records it once a visit for each screen (by its path, without ids),
/// so slow screens and devices show up in analytics. It never changes how
/// anything is drawn.
class WebFrameWatch extends ConsumerStatefulWidget {
  const WebFrameWatch({super.key});

  @override
  ConsumerState<WebFrameWatch> createState() => _WebFrameWatchState();
}

class _WebFrameWatchState extends ConsumerState<WebFrameWatch> {
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
  }

  @override
  void dispose() {
    _on = false;
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
    if (last == null) return;
    final screen = _path();
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
