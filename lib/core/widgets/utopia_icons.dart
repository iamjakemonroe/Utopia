import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Utopia's coin: a small gold coin with a raised rim and a star.
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _CoinPainter());
}

class _CoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r * 0.94);
    // The coin's edge, showing its thickness.
    canvas.drawCircle(
      c.translate(0, r * 0.14),
      r * 0.94,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFC88A1E), Color(0xFF8A5A10)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // Face.
    canvas.drawCircle(
      c,
      r * 0.94,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.45),
          colors: [Color(0xFFFFF8D8), Color(0xFFFFD45E), Color(0xFFE09A26)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // Raised rim.
    canvas.drawCircle(
      c,
      r * 0.72,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.1
        ..color = const Color(0x66A86E14),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.86),
      math.pi * 1.05,
      math.pi * 0.55,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.55),
    );
    // Embossed star: a shadow, then the star.
    Path star(Offset at) {
      final path = Path();
      for (var i = 0; i < 10; i++) {
        final a = -math.pi / 2 + i * math.pi / 5;
        final rr = i.isEven ? r * 0.44 : r * 0.19;
        final p = at + Offset(math.cos(a), math.sin(a)) * rr;
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      return path..close();
    }

    canvas.drawPath(
      star(c.translate(r * 0.03, r * 0.06)),
      Paint()..color = const Color(0x88A86E14),
    );
    canvas.drawPath(
      star(c),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFDF0), Color(0xFFFFE8A0)],
        ).createShader(Rect.fromCircle(center: c, radius: r * 0.45)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A small gold crown, for hosts and winners.
class CrownIcon extends StatelessWidget {
  const CrownIcon({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(size, size * 0.8), painter: _CrownPainter());
}

class _CrownPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final crown = Path()
      ..moveTo(w * 0.08, h * 0.9)
      ..lineTo(0, h * 0.25)
      ..lineTo(w * 0.3, h * 0.52)
      ..lineTo(w * 0.5, 0)
      ..lineTo(w * 0.7, h * 0.52)
      ..lineTo(w, h * 0.25)
      ..lineTo(w * 0.92, h * 0.9)
      ..close();
    canvas.drawPath(
      crown.shift(Offset(0, h * 0.06)),
      Paint()..color = const Color(0xFF8A5A10),
    );
    canvas.drawPath(
      crown,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF0B8), Color(0xFFFFC94D), Color(0xFFD9962A)],
        ).createShader(Offset.zero & size),
    );
    final gem = Paint()..color = const Color(0xFFFF5C9C);
    canvas.drawCircle(Offset(w * 0.5, h * 0.66), w * 0.08, gem);
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.06),
      w * 0.07,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A glossy colored disc with a white icon: menu rows, rules, setup tiles.
class GlossyBadge extends StatelessWidget {
  const GlossyBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 42,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: [Color.lerp(color, Colors.white, 0.45)!, color],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: size * 0.03,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: size * 0.2,
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.52),
    );
  }
}

/// Coins shown as "[coin] 1,250".
class CoinAmount extends StatelessWidget {
  const CoinAmount(
    this.amount, {
    super.key,
    this.size = 16,
    this.color,
    this.prefix = '',
  });

  final int amount;
  final double size;
  final Color? color;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CoinIcon(size: size * 1.1),
        SizedBox(width: size * 0.3),
        Text(
          '$prefix${formatCoins(amount)}',
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w800,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Short, for showing off: 950 -> "950", 1250 -> "1.2K", 24500 -> "24.5K",
/// 2400000 -> "2.4M" (rounded down, so it never claims more than there is).
String formatCoinsShort(int amount) {
  final n = amount.abs();
  String unit(double v, String suffix) {
    final down = (v * 10).floor() / 10;
    final text = down == down.roundToDouble()
        ? down.toStringAsFixed(0)
        : down.toStringAsFixed(1);
    return '${amount < 0 ? '-' : ''}$text$suffix';
  }

  if (n >= 1000000000) return unit(n / 1000000000, 'B');
  if (n >= 1000000) return unit(n / 1000000, 'M');
  if (n >= 1000) return unit(n / 1000, 'K');
  return '$amount';
}

/// 1250 -> "1,250".
String formatCoins(int amount) {
  final s = amount.abs().toString();
  final out = StringBuffer(amount < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}
