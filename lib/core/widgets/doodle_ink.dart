import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../theme/utopia_themes.dart';

/// In the Doodle world, the page is paper you can draw on. Press and hold
/// for a moment somewhere with nothing to tap (not a button, card or
/// field), feel the pen touch down, then drag to draw: the line fades a
/// moment after you lift, and the faster you draw the bolder it is. An
/// ordinary swipe scrolls as usual and draws nothing, and while you draw
/// the page holds still. In every other world it's just [child].
class DoodleInk extends StatefulWidget {
  const DoodleInk({super.key, required this.child});

  final Widget child;

  /// How long to hold before the pen touches down.
  static const hold = Duration(milliseconds: 320);

  @override
  State<DoodleInk> createState() => _DoodleInkState();
}

class _InkPoint {
  _InkPoint(this.at, this.width);

  final Offset at;
  final double width;
}

class _Stroke {
  _Stroke(this.started);

  final double started;
  final List<_InkPoint> points = [];

  /// When the finger lifted, in seconds; null while still drawing.
  double? endedAt;
  double lastAt = 0;
}

/// A long press that only starts where nothing under the finger can be
/// tapped, so buttons and cards keep working and only bare page draws.
class _HoldToDraw extends LongPressGestureRecognizer {
  _HoldToDraw({required this.blankAt}) : super(duration: DoodleInk.hold);

  final bool Function(Offset global) blankAt;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      super.isPointerAllowed(event) && blankAt(event.position);
}

class _DoodleInkState extends State<DoodleInk>
    with SingleTickerProviderStateMixin {
  /// How long a finished stroke stays before it starts to fade, and how
  /// long the fade takes.
  static const _keep = 0.45;
  static const _fade = 1.1;

  final _clock = ValueNotifier<double>(0);
  late final Ticker _ticker;
  final List<_Stroke> _strokes = [];

  /// The finger that's drawing right now, once its hold has landed.
  int? _pen;
  int? _lastDown;
  _Stroke? _live;

  /// The latest frame's time, in seconds: what the fade runs on. (Readable
  /// between frames too, where touches arrive; while ink is on screen the
  /// ticker keeps frames coming, so it's never stale.)
  double get _now =>
      SchedulerBinding.instance.currentSystemFrameTimeStamp.inMicroseconds /
      1e6;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      final now = _now;
      _strokes.removeWhere(
        (s) => s.endedAt != null && now - s.endedAt! > _keep + _fade,
      );
      _clock.value = now;
      // Nothing left to draw: stop ticking until the next stroke.
      if (_strokes.isEmpty) _ticker.stop();
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  /// True when nothing under [global] can be tapped: no button, card,
  /// link or text field. Scrolling areas are fine (they only drag).
  bool _blankAt(Offset global) {
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(
      result,
      global,
      View.of(context).viewId,
    );
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderSemanticsGestureHandler &&
          (target.onTap != null || target.onLongPress != null)) {
        return false;
      }
      if (target is RenderEditable) return false;
    }
    return true;
  }

  void _penDown(LongPressStartDetails d) {
    final pointer = _lastDown;
    if (pointer == null) return;
    HapticFeedback.selectionClick();
    final s = _Stroke(_now)..lastAt = _now;
    s.points.add(_InkPoint(d.localPosition, 2.4));
    _pen = pointer;
    _live = s;
    _strokes.add(s);
    if (!_ticker.isActive) _ticker.start();
  }

  void _move(PointerMoveEvent e) {
    final s = _live;
    if (s == null || e.pointer != _pen) return;
    // Speed from the touch events' own timestamps: exact, unlike frames.
    final now = e.timeStamp.inMicroseconds / 1e6;
    final last = s.points.last;
    final dist = (e.localPosition - last.at).distance;
    if (dist < 1.5) return;
    final dt = math.max(now - s.lastAt, 1 / 240);
    // Pixels per second to line width: a slow line is fine, a fast flick
    // is bold. Eased toward the target so the width doesn't jump.
    final speed = s.points.length < 2 ? 0.0 : dist / dt;
    final target = (2.0 + speed / 160).clamp(2.0, 13.0);
    final width = last.width + (target - last.width) * 0.35;
    s.points.add(_InkPoint(e.localPosition, width));
    s.lastAt = now;
  }

  void _penUp() {
    _live?.endedAt = _now;
    _live = null;
    _pen = null;
  }

  @override
  Widget build(BuildContext context) {
    if (UtopiaThemes.active.world.biome != WorldBiome.doodle) {
      return widget.child;
    }
    final ink = UtopiaThemes.active.textPrimary;
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      // Kept out of semantics so it never counts itself as tappable.
      excludeFromSemantics: true,
      gestures: {
        _HoldToDraw: GestureRecognizerFactoryWithHandlers<_HoldToDraw>(
          () => _HoldToDraw(blankAt: _blankAt),
          (r) => r
            ..onLongPressStart = _penDown
            ..onLongPressEnd = ((_) {
              _penUp();
            })
            ..onLongPressCancel = _penUp,
        ),
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) => _lastDown = e.pointer,
        onPointerMove: _move,
        onPointerUp: (e) {
          if (e.pointer == _pen) _penUp();
        },
        onPointerCancel: (e) {
          if (e.pointer == _pen) _penUp();
        },
        child: Stack(
          children: [
            widget.child,
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _InkPainter(
                      strokes: _strokes,
                      clock: _clock,
                      ink: ink,
                      keep: _keep,
                      fade: _fade,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InkPainter extends CustomPainter {
  _InkPainter({
    required this.strokes,
    required this.clock,
    required this.ink,
    required this.keep,
    required this.fade,
  }) : super(repaint: clock);

  final List<_Stroke> strokes;
  final ValueNotifier<double> clock;
  final Color ink;
  final double keep;
  final double fade;

  @override
  void paint(Canvas canvas, Size size) {
    final now = clock.value;
    for (final s in strokes) {
      // The pen touching down: a ring of ink spreading from the nib.
      final since = now - s.started;
      if (since < 0.35 && s.points.isNotEmpty) {
        final k = since / 0.35;
        canvas.drawCircle(
          s.points.first.at,
          4 + 14 * Curves.easeOut.transform(k),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6 * (1 - k)
            ..color = ink.withValues(alpha: 0.6 * (1 - k)),
        );
      }
      // The whole stroke fades together once the finger lifts.
      final ended = s.endedAt;
      final alpha = ended == null
          ? 0.9
          : 0.9 *
                (1 - ((now - ended - keep) / fade).clamp(0.0, 1.0)).toDouble();
      if (alpha <= 0) continue;
      // Drawn solid on its own layer, then faded as one piece, so the
      // overlapping segment ends don't show as darker dots.
      canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = ink;
      final pts = s.points;
      if (pts.length == 1) {
        canvas.drawCircle(
          pts.first.at,
          pts.first.width / 2,
          Paint()..color = ink,
        );
      }
      for (var i = 1; i < pts.length; i++) {
        paint.strokeWidth = (pts[i - 1].width + pts[i].width) / 2;
        canvas.drawLine(pts[i - 1].at, pts[i].at, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _InkPainter old) => true;
}
