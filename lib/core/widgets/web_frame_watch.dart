import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics.dart';
import '../platform/web_render.dart';

/// In a browser: watches how fast the game draws while it's animating,
/// and on a device that can't keep up (under about 35 frames a second),
/// draws a step less sharp (2x, 1.75x, 1.5x) until it can. Once a visit it
/// records the frame rate it got, so slow devices show up in analytics.
class WebFrameWatch extends ConsumerStatefulWidget {
  const WebFrameWatch({super.key});

  @override
  ConsumerState<WebFrameWatch> createState() => _WebFrameWatchState();
}

class _WebFrameWatchState extends ConsumerState<WebFrameWatch> {
  static const _steps = [2.0, 1.75, 1.5];
  static const _slowMs = 28.0;

  Duration? _last;
  final _gaps = <double>[];
  DateTime _settled = DateTime.now().add(const Duration(seconds: 5));
  bool _reported = false;
  bool _on = true;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb || !WebRender.available) return;
    SchedulerBinding.instance.addPersistentFrameCallback(_onFrame);
  }

  @override
  void dispose() {
    _on = false;
    super.dispose();
  }

  void _onFrame(Duration stamp) {
    if (!_on) return;
    final last = _last;
    _last = stamp;
    if (last == null) return;
    final ms = (stamp - last).inMicroseconds / 1000;
    // Back-to-back frames only: a longer pause is the app sitting still.
    if (ms <= 0 || ms > 250 || DateTime.now().isBefore(_settled)) return;
    _gaps.add(ms);
    if (_gaps.length < 120) return;
    final average = _gaps.reduce((a, b) => a + b) / _gaps.length;
    _gaps.clear();
    final cap = WebRender.cap;
    if (!_reported) {
      _reported = true;
      ref.read(analyticsProvider).log('web_fps', {
        'fps': (1000 / average).round(),
        'sharpness': cap,
        'screen': WebRender.screen,
      });
    }
    if (average <= _slowMs) return;
    final next = _steps.where((s) => s < cap - 0.01).firstOrNull;
    if (next == null || WebRender.screen <= next) return;
    WebRender.lower(next);
    // Let it redraw at the new size before judging again.
    _settled = DateTime.now().add(const Duration(seconds: 3));
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
