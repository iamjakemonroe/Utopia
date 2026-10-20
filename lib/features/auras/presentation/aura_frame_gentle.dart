part of 'aura_frame.dart';

/// The gentle frames: Bubbles, Sakura, Frost, Angel Halo, Hearts, Fireflies, Starlight and Autumn.
extension _GentleFrames on AuraPainter {
  void _bubbles(Canvas canvas, Offset c, double r, double t) {
    if (!front) {
      canvas.drawCircle(
        c,
        r * 1.05,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.18
          ..shader = SweepGradient(
            colors: const [
              Color(0x997FE3FF),
              Color(0x99FF9ECF),
              Color(0x99B9A8FF),
              Color(0x997FE3FF),
            ],
            transform: GradientRotation(t * 0.6),
          ).createShader(Rect.fromCircle(center: c, radius: r * 1.1))
          ..maskFilter = _blur(r * 0.1),
      );
      return;
    }
    for (var i = 0; i < 11; i++) {
      final p = (t * (0.22 + _rand(i, 1) * 0.12) + _rand(i, 2)) % 1;
      final a = i * 2 * math.pi / 11 + math.sin(t * 0.8 + i) * 0.25;
      final pos = c + _dir(a) * r * (1.0 + 0.3 * p) + Offset(0, -r * 0.45 * p);
      final s = r * (0.06 + 0.1 * math.sin(math.pi * p));
      final alpha = math.sin(math.pi * p);
      final rect = Rect.fromCircle(center: pos, radius: s);
      canvas.drawCircle(
        pos,
        s,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0x10FFFFFF),
              const Color(0x557FE3FF).withValues(alpha: 0.33 * alpha),
              const Color(0x88FF9ECF).withValues(alpha: 0.5 * alpha),
            ],
            stops: const [0.0, 0.75, 1.0],
          ).createShader(rect),
      );
      canvas.drawCircle(
        pos,
        s,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.8, s * 0.12)
          ..color = Colors.white.withValues(alpha: 0.75 * alpha),
      );
      canvas.drawCircle(
        pos + Offset(-s * 0.35, -s * 0.35),
        s * 0.22,
        Paint()..color = Colors.white.withValues(alpha: 0.9 * alpha),
      );
    }
  }

  void _sakura(Canvas canvas, Offset c, double r, double t) {
    if (!front) {
      _glowRing(canvas, c, r, const Color(0x99FF8FC4), width: 0.22);
      return;
    }
    for (var i = 0; i < 10; i++) {
      final a = t * 0.7 + i * 2 * math.pi / 10;
      final d = r * (1.14 + 0.1 * math.sin(t * 1.8 + i * 1.3));
      final pos = c + _dir(a) * d;
      final s = r * (0.13 + 0.04 * _rand(i, 6));
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(a + t * 2.4 + i);
      final petal = Path()
        ..moveTo(0, -s)
        ..quadraticBezierTo(s * 0.9, -s * 0.2, 0, s)
        ..quadraticBezierTo(-s * 0.9, -s * 0.2, 0, -s)
        ..close();
      canvas.drawPath(
        petal,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFE3F0), Color(0xFFFF8FC4)],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: s)),
      );
      canvas.drawLine(
        Offset(0, -s * 0.5),
        Offset(0, s * 0.6),
        Paint()
          ..strokeWidth = math.max(0.6, s * 0.08)
          ..color = const Color(0x66C2407A),
      );
      canvas.restore();
    }
  }

  void _frost(Canvas canvas, Offset c, double r, double t) {
    final pulse = 0.5 + 0.5 * math.sin(t * 2.5);
    if (!front) {
      _glowRing(
        canvas,
        c,
        r,
        const Color(0xFF7FE3FF).withValues(alpha: 0.45 + 0.3 * pulse),
        width: 0.24,
      );
      // Ice shards around the rim.
      const n = 14;
      for (var i = 0; i < n; i++) {
        final a = i * 2 * math.pi / n;
        final len = r * (0.12 + 0.1 * (0.5 + 0.5 * math.sin(t * 3 + i * 2)));
        final base = c + _dir(a) * r * 0.98;
        final shard = Path()
          ..moveTo(
            (base + _dir(a + math.pi / 2) * r * 0.05).dx,
            (base + _dir(a + math.pi / 2) * r * 0.05).dy,
          )
          ..lineTo((base + _dir(a) * len).dx, (base + _dir(a) * len).dy)
          ..lineTo(
            (base + _dir(a - math.pi / 2) * r * 0.05).dx,
            (base + _dir(a - math.pi / 2) * r * 0.05).dy,
          )
          ..close();
        canvas.drawPath(shard, Paint()..color = const Color(0xCCDDF6FF));
      }
      return;
    }
    for (var i = 0; i < 6; i++) {
      final a = -t * 0.5 + i * math.pi / 3;
      final p = c + _dir(a) * r * 1.22;
      final s = r * 0.11;
      final paint = Paint()
        ..strokeWidth = math.max(0.9, r * 0.025)
        ..strokeCap = StrokeCap.round
        ..color = Colors.white;
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(t * 1.2 + i);
      for (var k = 0; k < 6; k++) {
        final d = _dir(k * math.pi / 3);
        canvas.drawLine(Offset.zero, d * s, paint);
        final mid = d * s * 0.55;
        canvas.drawLine(
          mid,
          mid + _dir(k * math.pi / 3 + 0.7) * s * 0.3,
          paint,
        );
        canvas.drawLine(
          mid,
          mid + _dir(k * math.pi / 3 - 0.7) * s * 0.3,
          paint,
        );
      }
      canvas.restore();
    }
  }

  void _halo(Canvas canvas, Offset c, double r, double t) {
    final bob = math.sin(t * 2) * r * 0.05;
    final hc = c + Offset(0, -r * 1.02 + bob);
    final rect = Rect.fromCenter(center: hc, width: r * 1.35, height: r * 0.34);
    if (!front) {
      canvas.drawCircle(
        c,
        r * 1.08,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.3
          ..color = const Color(0xFFFFF1C2).withValues(alpha: 0.35)
          ..maskFilter = _blur(r * 0.2),
      );
      canvas.drawOval(
        rect.inflate(r * 0.08),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.16
          ..color = const Color(0xFFFFE07A).withValues(alpha: 0.5)
          ..maskFilter = _blur(r * 0.1),
      );
      return;
    }
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.09
        ..shader = SweepGradient(
          colors: const [
            Color(0xFFFFF6D6),
            Color(0xFFFFC94D),
            Color(0xFFFFF6D6),
            Color(0xFFD9962A),
            Color(0xFFFFF6D6),
          ],
          transform: GradientRotation(t * 1.5),
        ).createShader(rect),
    );
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.025
        ..color = Colors.white.withValues(alpha: 0.9),
    );
    // Feathers drifting down either side.
    for (var i = 0; i < 6; i++) {
      final life = (t * 0.25 + _rand(i, 1)) % 1;
      final side = i.isEven ? -1.0 : 1.0;
      final x = side * r * (1.1 + 0.25 * math.sin(t * 1.5 + i * 2));
      final y = -r * 0.9 + r * 2.0 * life;
      canvas.save();
      canvas.translate(c.dx + x, c.dy + y);
      canvas.rotate(math.sin(t * 2 + i) * 0.6 + side * 0.4);
      final s = r * 0.16;
      final feather = Path()
        ..moveTo(0, -s)
        ..quadraticBezierTo(s * 0.55, -s * 0.2, 0, s)
        ..quadraticBezierTo(-s * 0.55, -s * 0.2, 0, -s)
        ..close();
      final alpha = math.sin(life * math.pi);
      canvas.drawPath(
        feather,
        Paint()..color = Colors.white.withValues(alpha: 0.85 * alpha),
      );
      canvas.drawLine(
        Offset(0, -s * 0.8),
        Offset(0, s * 1.1),
        Paint()
          ..strokeWidth = math.max(0.6, s * 0.07)
          ..color = const Color(0xFFD9C9A0).withValues(alpha: alpha),
      );
      canvas.restore();
    }
  }

  /// Hearts circling the picture, each beating twice in a row now and then.
  void _hearts(Canvas canvas, Offset c, double r, double t) {
    if (!front) {
      _glowRing(canvas, c, r, const Color(0x99FF6FA8), width: 0.22);
      return;
    }
    for (var i = 0; i < 8; i++) {
      final a = t * 0.6 + i * 2 * math.pi / 8;
      final phase = (t * 1.2 + i * 0.13) % 1;
      // A double beat: lub-dub.
      final beat =
          math.max(0.0, math.sin(phase * math.pi * 8)) * (phase < 0.25 ? 1 : 0);
      final s = r * (0.13 + 0.05 * beat);
      _heart(
        canvas,
        c + _dir(a) * r * 1.2,
        s,
        i.isEven ? const Color(0xFFFF4D8D) : const Color(0xFFFF8AB8),
      );
    }
  }

  void _heart(Canvas canvas, Offset p, double s, Color color) {
    final path = Path()
      ..moveTo(p.dx, p.dy + s * 0.75)
      ..cubicTo(
        p.dx - s * 1.2,
        p.dy - s * 0.05,
        p.dx - s * 0.6,
        p.dy - s * 1.0,
        p.dx,
        p.dy - s * 0.35,
      )
      ..cubicTo(
        p.dx + s * 0.6,
        p.dy - s * 1.0,
        p.dx + s * 1.2,
        p.dy - s * 0.05,
        p.dx,
        p.dy + s * 0.75,
      )
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [Color.lerp(color, Colors.white, 0.45)!, color],
        ).createShader(Rect.fromCircle(center: p, radius: s)),
    );
    canvas.drawCircle(
      p + Offset(-s * 0.35, -s * 0.35),
      s * 0.16,
      Paint()..color = Colors.white.withValues(alpha: 0.8),
    );
  }

  /// Fireflies wandering round the picture, blinking on and off.
  void _fireflies(Canvas canvas, Offset c, double r, double t) {
    if (!front) {
      _glowRing(canvas, c, r, const Color(0x55D8FF6A), width: 0.26, blur: 0.25);
      return;
    }
    for (var i = 0; i < 14; i++) {
      final a =
          i * 2 * math.pi / 14 +
          math.sin(t * (0.4 + _rand(i, 1) * 0.3) + i) * 0.5;
      final d = r * (1.15 + 0.2 * math.sin(t * (0.7 + _rand(i, 2)) + i * 2));
      final pos = c + _dir(a) * d;
      final blink = math.max(
        0.0,
        math.sin(t * (1.5 + _rand(i, 3) * 2) + i * 3),
      );
      if (blink <= 0.05) continue;
      canvas.drawCircle(
        pos,
        r * 0.09,
        Paint()
          ..color = const Color(0xFFD8FF6A).withValues(alpha: 0.5 * blink)
          ..maskFilter = _blur(r * 0.07),
      );
      canvas.drawCircle(
        pos,
        r * 0.028 + 0.5,
        Paint()..color = const Color(0xFFFFFFE0).withValues(alpha: blink),
      );
    }
  }

  /// Twinkling stars round the picture and a fine ring of stardust.
  void _starlight(Canvas canvas, Offset c, double r, double t) {
    if (!front) {
      _glowRing(canvas, c, r, const Color(0x77FFE7A3), width: 0.16);
      final dust = Paint()..color = const Color(0xCCFFF3CF);
      for (var i = 0; i < 36; i++) {
        final a = t * 0.25 + i * 2 * math.pi / 36;
        canvas.drawCircle(c + _dir(a) * r * 1.1, r * 0.012 + 0.4, dust);
      }
      return;
    }
    for (var i = 0; i < 10; i++) {
      final a = -t * 0.2 + i * 2 * math.pi / 10 + _rand(i, 1) * 0.4;
      final d = r * (1.18 + 0.15 * _rand(i, 2));
      final tw = math.max(0.0, math.sin(t * (1.6 + _rand(i, 3)) + i * 1.9));
      _sparkle(
        canvas,
        c + _dir(a) * d,
        r * (0.08 + 0.08 * tw),
        Color.lerp(const Color(0xFFFFE7A3), Colors.white, tw)!,
      );
    }
  }

  /// Autumn leaves swirling round on the wind, flipping as they go.
  void _autumn(Canvas canvas, Offset c, double r, double t) {
    if (!front) {
      _glowRing(canvas, c, r, const Color(0x88FF9A3D), width: 0.2);
      return;
    }
    const colors = [
      Color(0xFFFF8A2A),
      Color(0xFFE0452A),
      Color(0xFFFFC23A),
      Color(0xFFB8541A),
    ];
    for (var i = 0; i < 9; i++) {
      final a = t * 0.55 + i * 2 * math.pi / 9;
      final d = r * (1.16 + 0.1 * math.sin(t * 1.3 + i * 1.7));
      final pos = c + _dir(a) * d;
      final s = r * (0.14 + 0.03 * _rand(i, 4));
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(a + t * 1.8 + i);
      // Flipping in the wind.
      canvas.scale(math.cos(t * 2.4 + i).abs() * 0.7 + 0.3, 1);
      final leaf = Path()
        ..moveTo(0, -s)
        ..quadraticBezierTo(s * 0.8, -s * 0.3, 0, s)
        ..quadraticBezierTo(-s * 0.8, -s * 0.3, 0, -s)
        ..close();
      final color = colors[i % colors.length];
      canvas.drawPath(
        leaf,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(color, Colors.white, 0.25)!, color],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: s)),
      );
      canvas.drawLine(
        Offset(0, -s * 0.8),
        Offset(0, s * 1.15),
        Paint()
          ..strokeWidth = math.max(0.6, s * 0.08)
          ..color = Color.lerp(color, Colors.black, 0.35)!,
      );
      canvas.restore();
    }
  }

  void _sparkle(Canvas canvas, Offset p, double s, Color color) {
    if (s <= 0.2) return;
    final path = Path()
      ..moveTo(p.dx, p.dy - s)
      ..quadraticBezierTo(p.dx, p.dy, p.dx + s, p.dy)
      ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + s)
      ..quadraticBezierTo(p.dx, p.dy, p.dx - s, p.dy)
      ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - s);
    canvas.drawPath(path, Paint()..color = color);
  }
}
