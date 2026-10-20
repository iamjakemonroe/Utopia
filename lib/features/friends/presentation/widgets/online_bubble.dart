import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/strings.dart';

/// On a friend's picture: a glassy bubble. While they're around, a green
/// glow fills it and it breathes, the light sliding gently over its skin;
/// when they're not, it's an empty bubble, still.
class OnlineBubble extends StatefulWidget {
  const OnlineBubble({super.key, required this.online, this.size = 14});

  final bool online;
  final double size;

  @override
  State<OnlineBubble> createState() => _OnlineBubbleState();
}

class _OnlineBubbleState extends State<OnlineBubble>
    with TickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  /// How full of green it is: eases in and out as they come and go.
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
    value: widget.online ? 1 : 0,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant OnlineBubble old) {
    super.didUpdateWidget(old);
    if (old.online != widget.online) {
      widget.online ? _fill.forward() : _fill.reverse();
      _sync();
    }
  }

  /// Breathes only while they're around (and motion isn't turned down).
  void _sync() {
    final still = MediaQuery.disableAnimationsOf(context);
    if (widget.online && !still) {
      if (!_breath.isAnimating) _breath.repeat();
    } else {
      _breath.stop();
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return Semantics(
      label: widget.online
          ? strings.onlineBubbleOnline
          : strings.onlineBubbleOffline,
      child: RepaintBoundary(
        child: SizedBox.square(
          // Room for the glow and the breath.
          dimension: size * 1.5,
          child: CustomPaint(
            painter: _BubblePainter(
              breath: _breath,
              fill: _fill,
              ring: AppColors.surface,
            ),
          ),
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  _BubblePainter({required this.breath, required this.fill, required this.ring})
    : super(repaint: Listenable.merge([breath, fill]));

  final Animation<double> breath;
  final Animation<double> fill;

  /// A thin ring in the card's color, so the bubble stands off the picture.
  final Color ring;

  static const _green = Color(0xFF2FE38A);
  static const _deep = Color(0xFF0E9F5B);
  static const _light = Color(0xFFB8FFD8);

  @override
  void paint(Canvas canvas, Size size) {
    final on = Curves.easeOut.transform(fill.value);
    final wave = math.sin(breath.value * 2 * math.pi);
    final c = size.center(Offset.zero);
    // The bubble's radius: a third of the box, a little rounder each
    // breath while they're around.
    final r = size.width / 3 * (1 + 0.07 * wave * on);

    // A soft green halo while they're around.
    if (on > 0) {
      final halo = r * (1.7 + 0.15 * wave);
      canvas.drawCircle(
        c,
        halo,
        Paint()
          ..shader = RadialGradient(
            colors: [
              _green.withValues(alpha: 0.45 * on),
              _green.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: halo)),
      );
    }

    // The ring that sets it off the picture.
    canvas.drawCircle(c, r + 1.6, Paint()..color = ring);

    // Inside: green glowing from the middle when on; nearly clear when not.
    final body = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.15, -0.2),
          colors: [
            Color.lerp(Colors.white.withValues(alpha: 0.08), _light, on)!,
            Color.lerp(Colors.white.withValues(alpha: 0.04), _green, on)!,
            Color.lerp(Colors.white.withValues(alpha: 0.10), _deep, on)!,
          ],
          stops: const [0, 0.55, 1],
        ).createShader(body),
    );

    // The bubble's skin: a clear rim, brighter where the light is.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.1, r * 0.16)
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.95),
            Colors.white.withValues(alpha: 0.35 + 0.15 * on),
          ],
        ).createShader(body),
    );

    // The shine, sliding a touch round the top as it breathes.
    final glint = c + Offset(-r * (0.36 + 0.06 * wave * on), -r * 0.4);
    canvas.save();
    canvas.translate(glint.dx, glint.dy);
    canvas.rotate(-0.6);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 0.62, height: r * 0.34),
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
    canvas.restore();
    // And a little light caught on the far side.
    canvas.drawCircle(
      c + Offset(r * 0.42, r * 0.44),
      r * 0.11,
      Paint()..color = Colors.white.withValues(alpha: 0.35 + 0.25 * on),
    );
  }

  @override
  bool shouldRepaint(covariant _BubblePainter old) => old.ring != ring;
}
