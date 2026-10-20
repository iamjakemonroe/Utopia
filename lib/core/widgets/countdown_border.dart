import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'live_transform.dart';

const _amber = Color(0xFFFFB020);
const _red = Color(0xFFFF4D5E);

/// A turn timer drawn as the border of whatever it wraps (an avatar frame).
/// The lit part of the border drains clockwise from the top as time runs
/// out, warming from [color] to amber, and in the last [warnMs] it turns red
/// and pulses once a second, in step with the countdown.
class CountdownBorder extends StatefulWidget {
  const CountdownBorder({
    super.key,
    required this.child,
    required this.msLeft,
    required this.totalMs,
    required this.color,
    this.borderRadius = 18,
    this.circle = false,
    this.strokeWidth = 4,
    this.warnMs = 5000,
    this.onWarnSecond,
  });

  final Widget child;

  /// Time left right now, or null when this player isn't on the clock.
  final int? Function() msLeft;
  final int totalMs;
  final Color color;
  final double borderRadius;

  /// Round frames (chess avatars) instead of rounded squares.
  final bool circle;
  final double strokeWidth;
  final int warnMs;

  /// Called once per second during the warning, with the seconds left.
  final ValueChanged<int>? onWarnSecond;

  @override
  State<CountdownBorder> createState() => _CountdownBorderState();
}

class _CountdownBorderState extends State<CountdownBorder>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  /// Time left, as of this frame, and the heartbeat's size. The border and
  /// the beat follow them without the widget being built again: built
  /// every frame, it laid out and drew the whole game screen each frame
  /// (see FrameIsland).
  final _ms = ValueNotifier<int?>(null);
  final _scale = ValueNotifier<double>(1);

  @override
  void initState() {
    super.initState();
    // Started here: a lazy field would only be created (and started)
    // on first use, which for a ticker is never.
    _ticker = createTicker((_) => _tick())..start();
  }

  int? _lastWarnSecond;

  void _tick() {
    final ms = widget.msLeft();
    if (ms != null && ms <= widget.warnMs && ms > 0) {
      final second = (ms / 1000).ceil();
      if (second != _lastWarnSecond) {
        _lastWarnSecond = second;
        widget.onWarnSecond?.call(second);
      }
    } else if (ms == null || ms > widget.warnMs) {
      _lastWarnSecond = null;
    }
    final was = _ms.value;
    if (ms == was) return;
    _ms.value = ms;
    _scale.value = 1 + 0.05 * _beat(ms, widget.warnMs);
    // Only coming on or off the clock changes what's built.
    if ((was == null) != (ms == null)) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    _ms.dispose();
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ms.value == null) return widget.child;
    return RepaintBoundary(
      child: LiveTransform(
        listenable: _scale,
        transform: () => Matrix4.diagonal3Values(_scale.value, _scale.value, 1),
        child: CustomPaint(
          foregroundPainter: _CountdownPainter(
            ms: _ms,
            totalMs: widget.totalMs,
            warnMs: widget.warnMs,
            baseColor: widget.color,
            radius: widget.borderRadius,
            circle: widget.circle,
            strokeWidth: widget.strokeWidth,
          ),
          child: RepaintBoundary(child: widget.child),
        ),
      ),
    );
  }
}

/// 1 at each whole second of the warning, easing to 0 in between: a
/// heartbeat. 0 before the warning.
double _beat(int? ms, int warnMs) => ms != null && ms <= warnMs
    ? math.pow(1 - (ms % 1000) / 1000, 3).toDouble()
    : 0.0;

class _CountdownPainter extends CustomPainter {
  _CountdownPainter({
    required this.ms,
    required this.totalMs,
    required this.warnMs,
    required this.baseColor,
    required this.radius,
    required this.circle,
    required this.strokeWidth,
  }) : super(repaint: ms);

  final ValueListenable<int?> ms;
  final int totalMs;
  final int warnMs;
  final Color baseColor;
  final double radius;
  final bool circle;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final left = ms.value;
    if (left == null) return;
    final fraction = (left / totalMs).clamp(0.0, 1.0);
    final low = left <= warnMs;
    final beat = _beat(left, warnMs);
    final color = low
        ? Color.lerp(_red, Colors.white, 0.25 * beat)!
        : fraction > 0.5
        ? baseColor
        : Color.lerp(baseColor, _amber, (0.5 - fraction) / 0.5 * 0.9)!;
    final glow = low ? 0.5 + 0.5 * beat : 0.35;
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    // Start at the top middle and run clockwise.
    final Path border;
    if (circle) {
      border = Path()..addArc(rect, -math.pi / 2, math.pi * 2 - 0.0001);
    } else {
      final r = math.max(0.0, radius - strokeWidth / 2);
      border = Path()
        ..moveTo(rect.center.dx, rect.top)
        ..lineTo(rect.right - r, rect.top)
        ..arcToPoint(
          Offset(rect.right, rect.top + r),
          radius: Radius.circular(r),
        )
        ..lineTo(rect.right, rect.bottom - r)
        ..arcToPoint(
          Offset(rect.right - r, rect.bottom),
          radius: Radius.circular(r),
        )
        ..lineTo(rect.left + r, rect.bottom)
        ..arcToPoint(
          Offset(rect.left, rect.bottom - r),
          radius: Radius.circular(r),
        )
        ..lineTo(rect.left, rect.top + r)
        ..arcToPoint(
          Offset(rect.left + r, rect.top),
          radius: Radius.circular(r),
        )
        ..close();
    }

    canvas.drawPath(
      border,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = Colors.black.withValues(alpha: 0.35),
    );
    if (fraction <= 0) return;

    final PathMetric metric = border.computeMetrics().first;
    final lit = metric.extractPath(0, metric.length * fraction);
    canvas.drawPath(
      lit,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 2.2
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.45 * glow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawPath(
      lit,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = color,
    );

    // A spark riding the end of the timer.
    final head = metric.getTangentForOffset(metric.length * fraction)?.position;
    if (head != null) {
      canvas.drawCircle(
        head,
        strokeWidth * 1.3,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
      canvas.drawCircle(
        head,
        strokeWidth * 0.55,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CountdownPainter old) =>
      old.ms != ms ||
      old.totalMs != totalMs ||
      old.warnMs != warnMs ||
      old.baseColor != baseColor ||
      old.radius != radius ||
      old.circle != circle ||
      old.strokeWidth != strokeWidth;
}
