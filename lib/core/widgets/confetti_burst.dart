import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A one-shot burst of confetti and coins from the top of its box, for
/// wins and unlocks. Paints over whatever it's stacked on and never takes
/// taps.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.pieces = 70});

  final int pieces;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _ConfettiPainter(t: _c.value, count: widget.pieces),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.t, required this.count});

  final double t;
  final int count;

  static const _colors = [
    Color(0xFFFFC94D),
    Color(0xFF2FD98E),
    Color(0xFFFF5C9C),
    Color(0xFF4DA3FF),
    Color(0xFFB27BFF),
    Color(0xFFFFFFFF),
  ];

  double _r(int i, int salt) {
    final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 1) return;
    final fade = t > 0.75 ? (1 - t) / 0.25 : 1.0;
    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 + (_r(i, 1) - 0.5) * 2.2;
      final speed = size.height * (0.6 + _r(i, 2) * 0.7);
      final start = Offset(
        size.width * (0.3 + _r(i, 3) * 0.4),
        size.height * 0.15,
      );
      final x =
          start.dx + math.cos(angle) * speed * t + math.sin(t * 8 + i) * 10;
      final y =
          start.dy + math.sin(angle) * speed * t + size.height * 1.4 * t * t;
      final paint = Paint()
        ..color = _colors[i % _colors.length].withValues(alpha: fade);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * 12 * (_r(i, 4) - 0.5));
      if (i % 5 == 0) {
        canvas.drawCircle(
          Offset.zero,
          5,
          Paint()..color = const Color(0xFFFFC94D).withValues(alpha: fade),
        );
        canvas.drawCircle(
          Offset.zero,
          3,
          Paint()..color = const Color(0xFFFFF0B8).withValues(alpha: fade),
        );
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-4, -2.5, 8, 5),
            const Radius.circular(1.5),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}
