import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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

  @override
  void initState() {
    super.initState();
    // Started here: a lazy field would only be created (and started)
    // on first use, which for a ticker is never.
    _ticker = createTicker((_) => _tick())..start();
  }

  int? _ms;
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
    if (ms != _ms) setState(() => _ms = ms);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ms = _ms;
    if (ms == null) return widget.child;

    final fraction = (ms / widget.totalMs).clamp(0.0, 1.0);
    final low = ms <= widget.warnMs;
    // 1 at each whole second, easing to 0 in between: a heartbeat.
    final beat = low ? math.pow(1 - (ms % 1000) / 1000, 3).toDouble() : 0.0;
    final color = low
        ? Color.lerp(_red, Colors.white, 0.25 * beat)!
        : fraction > 0.5
        ? widget.color
        : Color.lerp(widget.color, _amber, (0.5 - fraction) / 0.5 * 0.9)!;

    return Transform.scale(
      scale: 1 + 0.05 * beat,
      child: CustomPaint(
        foregroundPainter: _CountdownPainter(
          fraction: fraction,
          color: color,
          glow: low ? 0.5 + 0.5 * beat : 0.35,
          radius: widget.borderRadius,
          circle: widget.circle,
          strokeWidth: widget.strokeWidth,
        ),
        child: widget.child,
      ),
    );
  }
}

class _CountdownPainter extends CustomPainter {
  _CountdownPainter({
    required this.fraction,
    required this.color,
    required this.glow,
    required this.radius,
    required this.circle,
    required this.strokeWidth,
  });

  final double fraction;
  final Color color;
  final double glow;
  final double radius;
  final bool circle;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
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
      old.fraction != fraction || old.color != color || old.glow != glow;
}
