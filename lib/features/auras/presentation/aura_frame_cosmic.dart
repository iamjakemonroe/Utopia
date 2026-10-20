part of 'aura_frame.dart';

/// Each storm's colors: (glow, ring, bolt, spark).
const _stormColors = {
  'storm': (
    Color(0xFF8B4DFF),
    Color(0xFFD9C2FF),
    Color(0xFFA86BFF),
    Color(0xFFF1E6FF),
  ),
  'storm_white': (
    Color(0xFFDCE8FF),
    Color(0xFFFFFFFF),
    Color(0xFFC9DCFF),
    Color(0xFFFFFFFF),
  ),
  'storm_blue': (
    Color(0xFF2F7BFF),
    Color(0xFFB8D6FF),
    Color(0xFF4DA3FF),
    Color(0xFFE0F0FF),
  ),
  'storm_green': (
    Color(0xFF1FB877),
    Color(0xFFB8FFD9),
    Color(0xFF3DFF9A),
    Color(0xFFE6FFF2),
  ),
  'storm_gold': (
    Color(0xFFFFA020),
    Color(0xFFFFE9A0),
    Color(0xFFFFC94D),
    Color(0xFFFFF6D6),
  ),
  'storm_pink': (
    Color(0xFFFF3D9A),
    Color(0xFFFFC2E0),
    Color(0xFFFF6FB8),
    Color(0xFFFFE6F2),
  ),
};

/// Light, storms and space: the storms, Sunburst, Prism, Cosmic, Fury, Supernova, Black Hole, Frostfire, Galaxy, Shadow, Neon and Tidal.
extension _CosmicFrames on AuraPainter {
  void _storm(
    Canvas canvas,
    Offset c,
    double r,
    double t,
    (Color, Color, Color, Color) colors,
  ) {
    final (glowColor, ringColor, boltColor, sparkColor) = colors;
    final pulse = 0.5 + 0.5 * math.sin(t * 4);
    if (!front) {
      _glowRing(
        canvas,
        c,
        r,
        glowColor.withValues(alpha: 0.55 + 0.35 * pulse),
        width: 0.32,
        blur: 0.25,
        scale: 1.08,
      );
      return;
    }
    canvas.drawCircle(
      c,
      r * 1.03,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..color = ringColor.withValues(alpha: 0.6 + 0.3 * pulse),
    );
    // New bolts about ten times a second, each living a few frames.
    final flash = (t * 11).floor();
    for (var b = 0; b < 4; b++) {
      final seed = flash * 7 + b * 31;
      if (_rand(seed, 9) < 0.35) continue;
      final start = _rand(seed, 1) * 2 * math.pi;
      final span = 0.7 + _rand(seed, 2) * 0.9;
      const segments = 9;
      final bolt = Path();
      for (var s = 0; s <= segments; s++) {
        final a = start + span * s / segments;
        final jitter = (s == 0 || s == segments)
            ? 0
            : (_rand(seed + s, 3) - 0.5) * 0.28;
        final p = c + _dir(a) * r * (1.12 + jitter);
        if (s == 0) {
          bolt.moveTo(p.dx, p.dy);
        } else {
          bolt.lineTo(p.dx, p.dy);
        }
      }
      // A fork shooting outward from the middle of the bolt.
      final forkA = start + span * 0.5;
      final forkFrom = c + _dir(forkA) * r * 1.12;
      final fork = Path()
        ..moveTo(forkFrom.dx, forkFrom.dy)
        ..lineTo(
          (c + _dir(forkA + 0.08) * r * 1.3).dx,
          (c + _dir(forkA + 0.08) * r * 1.3).dy,
        )
        ..lineTo(
          (c + _dir(forkA - 0.04) * r * 1.45).dx,
          (c + _dir(forkA - 0.04) * r * 1.45).dy,
        );
      for (final path in [bolt, fork]) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.11
            ..strokeJoin = StrokeJoin.round
            ..color = boltColor.withValues(alpha: 0.7)
            ..maskFilter = _blur(r * 0.06),
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.0, r * 0.03)
            ..strokeJoin = StrokeJoin.round
            ..color = Colors.white,
        );
      }
    }
    // Sparks skittering around the ring.
    for (var i = 0; i < 8; i++) {
      final a = t * (1.5 + _rand(i, 4)) + i * 0.8;
      final on = math.sin(t * 13 + i * 2) > 0.3;
      if (!on) continue;
      canvas.drawCircle(
        c + _dir(a) * r * 1.16,
        r * 0.03 + 0.5,
        Paint()..color = sparkColor,
      );
    }
  }

  void _sunburst(Canvas canvas, Offset c, double r, double t) {
    if (!front) {
      const rays = 16;
      for (var i = 0; i < rays; i++) {
        final a = t * 0.35 + i * 2 * math.pi / rays;
        final w = (i.isEven ? 0.11 : 0.07);
        final len = r * (i.isEven ? 1.55 : 1.38);
        final path = Path()
          ..moveTo(
            (c + _dir(a - w) * r * 0.9).dx,
            (c + _dir(a - w) * r * 0.9).dy,
          )
          ..lineTo((c + _dir(a) * len).dx, (c + _dir(a) * len).dy)
          ..lineTo(
            (c + _dir(a + w) * r * 0.9).dx,
            (c + _dir(a + w) * r * 0.9).dy,
          )
          ..close();
        canvas.drawPath(
          path,
          Paint()
            ..shader = RadialGradient(
              colors: [
                const Color(0xFFFFE29A).withValues(alpha: 0.9),
                const Color(0x00FFC94D),
              ],
            ).createShader(Rect.fromCircle(center: c, radius: len)),
        );
      }
      _glowRing(canvas, c, r, const Color(0xAAFFC94D), width: 0.2);
      return;
    }
    canvas.drawCircle(
      c,
      r * 1.02,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.09
        ..shader = SweepGradient(
          colors: const [
            Color(0xFFFFF0B8),
            Color(0xFFFFC94D),
            Color(0xFFD9962A),
            Color(0xFFFFF0B8),
          ],
          transform: GradientRotation(t * 1.2),
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    for (var i = 0; i < 4; i++) {
      final s = math.max(0.0, math.sin(t * 2.2 + i * 1.6));
      _sparkle(
        canvas,
        c + _dir(i * math.pi / 2 + math.pi / 4) * r * 1.08,
        r * 0.16 * s,
        Colors.white,
      );
    }
  }

  void _prism(Canvas canvas, Offset c, double r, double t) {
    final rect = Rect.fromCircle(center: c, radius: r * 1.06);
    const rainbow = [
      Color(0xFFFF5C6C),
      Color(0xFFFFC93D),
      Color(0xFF2FD98E),
      Color(0xFF4DA3FF),
      Color(0xFFB27BFF),
      Color(0xFFFF5C9C),
      Color(0xFFFF5C6C),
    ];
    if (!front) {
      canvas.drawCircle(
        c,
        r * 1.06,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.3
          ..shader = SweepGradient(
            colors: rainbow,
            transform: GradientRotation(t * 1.4),
          ).createShader(rect)
          ..maskFilter = _blur(r * 0.16),
      );
      return;
    }
    canvas.drawCircle(
      c,
      r * 1.04,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.1
        ..shader = SweepGradient(
          colors: rainbow,
          transform: GradientRotation(t * 1.4),
        ).createShader(rect),
    );
    for (var i = 0; i < 2; i++) {
      final a = -t * 2.1 + i * math.pi;
      canvas.drawCircle(
        c + _dir(a) * r * 1.04,
        r * 0.07,
        Paint()
          ..color = Colors.white
          ..maskFilter = _blur(r * 0.04),
      );
    }
  }

  void _cosmic(Canvas canvas, Offset c, double r, double t) {
    if (!front) {
      canvas.drawCircle(
        c,
        r * 1.12,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.36
          ..shader = SweepGradient(
            colors: const [
              Color(0x995A2BB0),
              Color(0x99FF5C9C),
              Color(0x993F6BFF),
              Color(0x995A2BB0),
            ],
            transform: GradientRotation(-t * 0.5),
          ).createShader(Rect.fromCircle(center: c, radius: r * 1.2))
          ..maskFilter = _blur(r * 0.14),
      );
      for (var i = 0; i < 16; i++) {
        final a = i * 2.39996;
        final d = r * (1.05 + _rand(i, 5) * 0.4);
        final tw = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(t * 3 + i * 1.3));
        canvas.drawCircle(
          c + _dir(a) * d,
          r * 0.022 + 0.4,
          Paint()..color = Colors.white.withValues(alpha: tw),
        );
      }
    }
    // Planets on a tilted orbit: behind the avatar on the far side.
    const tilt = -0.35;
    const planets = [
      (Color(0xFFFF9ECF), 0.13, 0.9),
      (Color(0xFF7FE3FF), 0.09, 1.4),
      (Color(0xFFFFD45E), 0.07, 2.1),
    ];
    for (final (i, (color, size, speed)) in planets.indexed) {
      final a = t * speed + i * 2.1;
      final ox = math.cos(a) * r * 1.38;
      final oy = math.sin(a) * r * 0.42;
      final p =
          c +
          Offset(
            ox * math.cos(tilt) - oy * math.sin(tilt),
            ox * math.sin(tilt) + oy * math.cos(tilt),
          );
      final far = math.sin(a) < 0;
      if (far == front) continue;
      final pr = r * size;
      canvas.drawCircle(
        p,
        pr,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.4),
            colors: [
              Colors.white,
              color,
              Color.lerp(color, Colors.black, 0.4)!,
            ],
          ).createShader(Rect.fromCircle(center: p, radius: pr)),
      );
      if (i == 0) {
        canvas.drawOval(
          Rect.fromCenter(center: p, width: pr * 3.4, height: pr * 0.9),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = pr * 0.25
            ..color = const Color(0xCCFFE29A),
        );
      }
    }
  }

  /// Crimson Fury: a red fire vortex spinning fast, shockwaves pulsing out,
  /// red lightning cracking round the rim and energy orbs racing with
  /// trails. Everything surges together a few times a second.
  void _fury(Canvas canvas, Offset c, double r, double t) {
    const red = Color(0xFFFF1F3D);
    const palette = [
      Color(0xFFFFFFFF),
      Color(0xEEFF7A8A),
      Color(0xBBFF1F3D),
      Color(0x00700010),
    ];
    final spin = t * 2.2;
    final beat = (t * 2.4) % 1;
    final surge = beat < 0.12 ? 1 - beat / 0.12 : 0.0;

    if (!front) {
      // Shockwaves rolling outward.
      for (var k = 0; k < 3; k++) {
        final p = (t * 0.9 + k / 3) % 1;
        canvas.drawCircle(
          c,
          r * (1.0 + 0.85 * p),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.07 * (1 - p) + 0.6
            ..color = red.withValues(alpha: 0.55 * (1 - p)),
        );
      }
      canvas.drawCircle(
        c,
        r * 1.1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.6
          ..color = red.withValues(alpha: 0.4 + 0.3 * surge)
          ..maskFilter = _blur(r * 0.3),
      );
      _fireTongues(
        canvas,
        c,
        r,
        t * 1.3,
        spin,
        count: 16,
        size: 1.15 + 0.25 * surge,
        salt: 5,
        palette: palette,
      );
      _fireTongues(
        canvas,
        c,
        r,
        t * 1.3,
        spin + 0.2,
        count: 24,
        size: 0.65,
        salt: 6,
        palette: palette,
      );
      return;
    }

    // The burning band, spinning hard.
    final add = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..blendMode = BlendMode.plus;
    const bands = [
      (1.04, 0.16, 2.4, 1.0, Color(0xCCFF1F3D), 0.07),
      (1.02, 0.09, 2.0, 1.3, Color(0xEEFF6B7D), 0.03),
      (1.05, 0.04, 1.6, 1.7, Color(0xFFFFFFFF), 0.0),
    ];
    for (final (k, (radius, width, length, speed, color, blur))
        in bands.indexed) {
      for (var copy = 0; copy < 2; copy++) {
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(spin * speed + k * 1.3 + copy * math.pi);
        add
          ..strokeWidth = r * width * (1 + 0.3 * surge)
          ..maskFilter = blur > 0 ? _blur(r * blur) : null
          ..shader = SweepGradient(
            startAngle: 0,
            endAngle: length,
            colors: [
              color.withValues(alpha: 0),
              color,
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: r * 1.3));
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: r * radius),
          0,
          length,
          false,
          add,
        );
        canvas.restore();
      }
    }

    // Red lightning: new bolts about fifteen times a second.
    final flash = (t * 15).floor();
    for (var b = 0; b < 5; b++) {
      final seed = flash * 11 + b * 37;
      if (_rand(seed, 9) < 0.3) continue;
      final start = _rand(seed, 1) * 2 * math.pi;
      final span = 0.5 + _rand(seed, 2) * 1.1;
      const segments = 10;
      final bolt = Path();
      for (var s = 0; s <= segments; s++) {
        final a = start + span * s / segments;
        final jitter = (s == 0 || s == segments)
            ? 0
            : (_rand(seed + s, 3) - 0.5) * 0.38;
        final p = c + _dir(a) * r * (1.15 + jitter);
        if (s == 0) {
          bolt.moveTo(p.dx, p.dy);
        } else {
          bolt.lineTo(p.dx, p.dy);
        }
      }
      // A fork leaping outward.
      final forkA = start + span * _rand(seed, 4);
      final fork = Path()
        ..moveTo(
          (c + _dir(forkA) * r * 1.15).dx,
          (c + _dir(forkA) * r * 1.15).dy,
        )
        ..lineTo(
          (c + _dir(forkA + 0.1) * r * 1.4).dx,
          (c + _dir(forkA + 0.1) * r * 1.4).dy,
        )
        ..lineTo(
          (c + _dir(forkA - 0.05) * r * 1.62).dx,
          (c + _dir(forkA - 0.05) * r * 1.62).dy,
        );
      for (final path in [bolt, fork]) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.13
            ..strokeJoin = StrokeJoin.round
            ..color = red.withValues(alpha: 0.75)
            ..maskFilter = _blur(r * 0.07),
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.0, r * 0.035)
            ..strokeJoin = StrokeJoin.round
            ..color = Colors.white,
        );
      }
    }

    // Energy orbs racing round with trails.
    for (var i = 0; i < 3; i++) {
      final a = -t * (2.6 + i * 0.4) + i * 2 * math.pi / 3;
      for (var k = 6; k >= 0; k--) {
        final p = c + _dir(a + k * 0.09) * r * 1.3;
        canvas.drawCircle(
          p,
          r * (0.07 - k * 0.008),
          Paint()
            ..color = (k == 0 ? Colors.white : red).withValues(
              alpha: k == 0 ? 1 : 0.5 * (1 - k / 7),
            )
            ..maskFilter = _blur(r * 0.03),
        );
      }
    }

    // Sparks flung off.
    for (var i = 0; i < 18; i++) {
      final life = (t * (0.8 + _rand(i, 1) * 0.5) + _rand(i, 2)) % 1;
      final a = spin + _rand(i, 3) * 2 * math.pi + life * 1.2;
      final pos = c + _dir(a) * r * (1.1 + 0.7 * life);
      canvas.drawCircle(
        pos,
        r * 0.028 * (1 - life) + 0.5,
        Paint()
          ..color = Color.lerp(
            Colors.white,
            red,
            life,
          )!.withValues(alpha: 1 - life),
      );
    }
  }

  /// Supernova: a star going off around the picture. Rays spin and swell,
  /// a shock ring rolls out every beat, and sparks fly from the corona.
  void _supernova(Canvas canvas, Offset c, double r, double t) {
    final beat = (t * 0.7) % 1;
    final swell = beat < 0.15 ? 1 - beat / 0.15 : 0.0;
    if (!front) {
      canvas.drawCircle(
        c,
        r * (1.25 + 0.15 * swell),
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFFFFF).withValues(alpha: 0.9),
              const Color(0xFFFFD24D).withValues(alpha: 0.7),
              const Color(0xFFFF7A1A).withValues(alpha: 0.35),
              const Color(0x00FF3D0A),
            ],
            stops: const [0.55, 0.7, 0.85, 1.0],
          ).createShader(Rect.fromCircle(center: c, radius: r * 1.6)),
      );
      // Spinning rays, long and short.
      const rays = 18;
      for (var i = 0; i < rays; i++) {
        final a = t * 0.5 + i * 2 * math.pi / rays;
        final long = i.isEven;
        final len =
            r *
            (long ? 1.9 : 1.45) *
            (1 + 0.18 * swell + 0.06 * math.sin(t * 5 + i));
        const w = 0.05;
        final path = Path()
          ..moveTo((c + _dir(a - w) * r).dx, (c + _dir(a - w) * r).dy)
          ..lineTo((c + _dir(a) * len).dx, (c + _dir(a) * len).dy)
          ..lineTo((c + _dir(a + w) * r).dx, (c + _dir(a + w) * r).dy)
          ..close();
        canvas.drawPath(
          path,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = RadialGradient(
              colors: [
                const Color(0xFFFFF6D6).withValues(alpha: long ? 0.9 : 0.6),
                const Color(0x00FFC94D),
              ],
            ).createShader(Rect.fromCircle(center: c, radius: len)),
        );
      }
      // The shock ring.
      canvas.drawCircle(
        c,
        r * (1.05 + 0.95 * beat),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.08 * (1 - beat) + 0.5
          ..color = Colors.white.withValues(alpha: 0.8 * (1 - beat)),
      );
      return;
    }
    // The corona hugging the rim.
    canvas.drawCircle(
      c,
      r * 1.02,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * (0.08 + 0.05 * swell)
        ..shader = SweepGradient(
          colors: const [
            Color(0xFFFFFFFF),
            Color(0xFFFFD24D),
            Color(0xFFFFFFFF),
            Color(0xFFFF9A2E),
            Color(0xFFFFFFFF),
          ],
          transform: GradientRotation(-t * 2),
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.1)),
    );
    // A lens flare: four thin beams.
    for (var k = 0; k < 4; k++) {
      final a = math.pi / 4 + k * math.pi / 2;
      final len = r * (1.5 + 0.5 * swell);
      canvas.drawLine(
        c + _dir(a) * r * 1.02,
        c + _dir(a) * len,
        Paint()
          ..strokeWidth = math.max(1.0, r * 0.025)
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(
            colors: [Colors.white, Colors.white.withValues(alpha: 0)],
          ).createShader(Rect.fromPoints(c + _dir(a) * r, c + _dir(a) * len)),
      );
    }
    // Sparks thrown out of the blast.
    for (var i = 0; i < 20; i++) {
      final life = (t * (0.6 + _rand(i, 1) * 0.5) + _rand(i, 2)) % 1;
      final a = _rand(i, 3) * 2 * math.pi;
      final pos = c + _dir(a) * r * (1.05 + 0.9 * life);
      canvas.drawCircle(
        pos,
        r * 0.03 * (1 - life) + 0.5,
        Paint()
          ..color = Color.lerp(
            Colors.white,
            const Color(0xFFFFA020),
            life,
          )!.withValues(alpha: 1 - life),
      );
    }
  }

  /// Event Horizon: a black hole's blazing disk wraps round the picture,
  /// passing behind it on the far side and in front on the near side, with
  /// light bent into a ring and matter spiralling in.
  void _blackhole(Canvas canvas, Offset c, double r, double t) {
    const tilt = -0.22;
    Offset disk(double a, double scale) {
      final x = math.cos(a) * r * 1.75 * scale;
      final y = math.sin(a) * r * 0.5 * scale;
      return c +
          Offset(
            x * math.cos(tilt) - y * math.sin(tilt),
            x * math.sin(tilt) + y * math.cos(tilt),
          );
    }

    if (!front) {
      // Darkness pulled around the picture, then the bent-light ring.
      canvas.drawCircle(
        c,
        r * 1.35,
        Paint()
          ..shader = RadialGradient(
            colors: const [
              Color(0xFF000000),
              Color(0xCC1A0830),
              Color(0x00100018),
            ],
            stops: const [0.6, 0.8, 1.0],
          ).createShader(Rect.fromCircle(center: c, radius: r * 1.35)),
      );
      canvas.drawCircle(
        c,
        r * 1.12,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.06
          ..shader = SweepGradient(
            colors: const [
              Color(0xFFFFE9C2),
              Color(0xFFFF8A3D),
              Color(0xFFB25CFF),
              Color(0xFFFF8A3D),
              Color(0xFFFFE9C2),
            ],
            transform: GradientRotation(t * 2.4),
          ).createShader(Rect.fromCircle(center: c, radius: r * 1.2))
          ..maskFilter = _blur(r * 0.03),
      );
    }

    // The disk: bands of glowing matter racing round. Far side behind the
    // picture, near side in front.
    final dot = Paint()..blendMode = BlendMode.plus;
    for (var band = 0; band < 4; band++) {
      final scale = 0.78 + band * 0.1;
      final speed = 1.6 - band * 0.25;
      for (var i = 0; i < 48; i++) {
        final a = -t * speed + i * 2 * math.pi / 48 + band * 0.3;
        final near = math.sin(a + tilt) > 0;
        if (near != front) continue;
        final p = disk(a, scale);
        final hot = 1 - band / 4;
        dot.color = Color.lerp(
          const Color(0xFFB25CFF),
          Color.lerp(const Color(0xFFFF8A3D), Colors.white, hot * 0.6)!,
          0.4 + 0.6 * hot,
        )!.withValues(alpha: 0.55 + 0.35 * _rand(i + band * 60, 7));
        canvas.drawCircle(p, r * (0.05 - band * 0.008), dot);
      }
    }

    if (front) {
      // Matter spiralling in and vanishing at the edge.
      for (var i = 0; i < 12; i++) {
        final life = (t * 0.45 + _rand(i, 1)) % 1;
        final a = _rand(i, 2) * 2 * math.pi + life * 4;
        final d = r * (1.9 - 0.8 * life);
        canvas.drawCircle(
          c + _dir(a) * d,
          r * 0.025 + 0.4,
          Paint()
            ..color = const Color(
              0xFFFFE9C2,
            ).withValues(alpha: math.sin(life * math.pi)),
        );
      }
    }
  }

  /// Frostfire: half the ring is ice-blue flame, half is fire, the two
  /// chasing each other round with sparks where they meet.
  void _frostfire(Canvas canvas, Offset c, double r, double t) {
    final turn = t * 1.1;
    bool fire(double a) => math.cos(a - turn) >= 0;
    const ice = [
      Color(0xEEFFFFFF),
      Color(0xDDB8E8FF),
      Color(0x995AB8FF),
      Color(0x001A5CFF),
    ];
    if (!front) {
      canvas.drawCircle(
        c,
        r * 1.1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.5
          ..shader = SweepGradient(
            colors: const [
              Color(0x88FF6A1A),
              Color(0x885AB8FF),
              Color(0x88FF6A1A),
            ],
            transform: GradientRotation(turn - math.pi / 2),
          ).createShader(Rect.fromCircle(center: c, radius: r * 1.2))
          ..maskFilter = _blur(r * 0.25),
      );
      _fireTongues(
        canvas,
        c,
        r,
        t,
        turn * 0.6,
        count: 18,
        size: 1.05,
        salt: 7,
        where: fire,
      );
      _fireTongues(
        canvas,
        c,
        r,
        t,
        turn * 0.6,
        count: 18,
        size: 1.05,
        salt: 7,
        palette: ice,
        where: (a) => !fire(a),
      );
      return;
    }
    // The band: a fire half and an ice half.
    final rect = Rect.fromCircle(center: c, radius: r * 1.03);
    for (final (start, color) in [
      (turn - math.pi / 2, const Color(0xFFFF8A2E)),
      (turn + math.pi / 2, const Color(0xFF7FD8FF)),
    ]) {
      canvas.drawArc(
        rect,
        start,
        math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.1
          ..blendMode = BlendMode.plus
          ..color = color
          ..maskFilter = _blur(r * 0.03),
      );
    }
    // Where they meet: white-hot sparks and steam.
    for (final meet in [turn + math.pi / 2, turn - math.pi / 2]) {
      final p = c + _dir(meet) * r * 1.04;
      canvas.drawCircle(
        p,
        r * (0.12 + 0.05 * math.sin(t * 12)),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.85)
          ..maskFilter = _blur(r * 0.06),
      );
      for (var i = 0; i < 6; i++) {
        final life = (t * 1.5 + i / 6) % 1;
        final a = meet + (_rand(i, 4) - 0.5) * 1.6;
        canvas.drawCircle(
          p + _dir(a) * r * 0.45 * life,
          r * 0.025 * (1 - life) + 0.4,
          Paint()
            ..color = (i.isEven ? const Color(0xFFFFC23A) : Colors.white)
                .withValues(alpha: 1 - life),
        );
      }
    }
  }

  /// A spiral galaxy turning around the picture: two arms of stars over a
  /// soft nebula.
  void _galaxy(Canvas canvas, Offset c, double r, double t) {
    final turn = t * 0.45;
    if (!front) {
      // Nebula clouds.
      const clouds = [Color(0x998A5CFF), Color(0x88FF5CC8), Color(0x775C8AFF)];
      for (var i = 0; i < 3; i++) {
        final a = turn * 0.7 + i * 2.1;
        canvas.drawCircle(
          c + _dir(a) * r * 0.75,
          r * 0.7,
          Paint()
            ..color = clouds[i]
            ..maskFilter = _blur(r * 0.4),
        );
      }
      // Two spiral arms.
      final star = Paint();
      for (var arm = 0; arm < 2; arm++) {
        for (var i = 0; i < 34; i++) {
          final u = i / 34;
          final a = turn + arm * math.pi + u * 3.4;
          final d =
              r * (1.0 + u * 0.7) + (_rand(i + arm * 50, 4) - 0.5) * r * 0.12;
          final tw = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(t * 3 + i * 1.7));
          star.color = Color.lerp(
            const Color(0xFFFFFFFF),
            const Color(0xFFB9A0FF),
            u,
          )!.withValues(alpha: tw * (1 - u * 0.5));
          canvas.drawCircle(
            c + _dir(a) * d,
            r * (0.03 - u * 0.015) + 0.4,
            star,
          );
        }
      }
      return;
    }
    canvas.drawCircle(
      c,
      r * 1.02,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..shader = SweepGradient(
          colors: const [
            Color(0xFFB9A0FF),
            Color(0xFFFF8AD8),
            Color(0xFF7FB0FF),
            Color(0xFFB9A0FF),
          ],
          transform: GradientRotation(-t * 0.8),
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.1)),
    );
    for (var i = 0; i < 4; i++) {
      final s = math.max(0.0, math.sin(t * 1.8 + i * 1.6));
      _sparkle(
        canvas,
        c + _dir(turn + i * math.pi / 2 + 0.6) * r * 1.3,
        r * 0.14 * s,
        Colors.white,
      );
    }
  }

  /// Dark violet flames with a glowing green heart, rising upward.
  void _shadow(Canvas canvas, Offset c, double r, double t) {
    if (!front) {
      canvas.drawCircle(
        c,
        r * 1.1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.5
          ..color = const Color(0xFF3A0F6B).withValues(alpha: 0.6)
          ..maskFilter = _blur(r * 0.25),
      );
      canvas.drawCircle(
        c,
        r * 1.04,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.16
          ..color = const Color(
            0xFF9DFF4D,
          ).withValues(alpha: 0.35 + 0.2 * math.sin(t * 3))
          ..maskFilter = _blur(r * 0.12),
      );
    }
    const n = 18;
    for (var i = 0; i < n; i++) {
      final a = i * 2 * math.pi / n + t * 0.3;
      // Back half behind the picture, front half over it.
      if ((i.isEven) == front) continue;
      final up = (1 - math.sin(a)) / 2;
      final flicker =
          0.5 + 0.5 * math.sin(t * 8 + i * 1.7) * math.sin(t * 4.7 + i * 0.9);
      final h = r * (0.15 + 0.25 * flicker + 0.25 * up);
      final lean = _dir(a) + const Offset(0, -0.9);
      final dir = lean / lean.distance;
      final w = math.pi / n * 1.2;
      final baseL = c + _dir(a - w) * r * 0.94;
      final baseR = c + _dir(a + w) * r * 0.94;
      final mid = c + _dir(a) * r * 0.94;
      final tip = mid + dir * h;
      final path = Path()
        ..moveTo(baseL.dx, baseL.dy)
        ..quadraticBezierTo(
          (baseL + tip).dx / 2 - dir.dy * h * 0.2,
          (baseL + tip).dy / 2 + dir.dx * h * 0.2,
          tip.dx,
          tip.dy,
        )
        ..quadraticBezierTo(
          (baseR + tip).dx / 2 + dir.dy * h * 0.2,
          (baseR + tip).dy / 2 - dir.dx * h * 0.2,
          baseR.dx,
          baseR.dy,
        )
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = RadialGradient(
            colors: const [
              Color(0xFFD8FF8A),
              Color(0xFF6BE03A),
              Color(0xCC4A1A8C),
              Color(0x0012051F),
            ],
            stops: const [0.0, 0.25, 0.6, 1.0],
          ).createShader(Rect.fromCircle(center: mid, radius: h * 1.05 + 1)),
      );
    }
    if (front) {
      for (var i = 0; i < 8; i++) {
        final p = (t * (0.35 + _rand(i, 1) * 0.25) + _rand(i, 2)) % 1;
        final a = -math.pi / 2 + (_rand(i, 3) - 0.5) * math.pi * 1.2;
        final pos = c + _dir(a) * r * 1.1 + Offset(0, -r * 0.8 * p);
        canvas.drawCircle(
          pos,
          r * 0.03 * (1 - p) + 0.5,
          Paint()
            ..color = const Color(0xFFB6FF6A).withValues(alpha: 1 - p)
            ..maskFilter = _blur(r * 0.02),
        );
      }
    }
  }

  /// Two neon rings, pink and cyan, racing opposite ways with a bright
  /// spark chasing round each.
  void _neon(Canvas canvas, Offset c, double r, double t) {
    final pulse = 0.5 + 0.5 * math.sin(t * 4);
    const pink = Color(0xFFFF3DF2);
    const cyan = Color(0xFF3DF5FF);
    if (!front) {
      for (final (color, scale) in const [(cyan, 1.06), (pink, 1.18)]) {
        canvas.drawCircle(
          c,
          r * scale,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.14
            ..color = color.withValues(alpha: 0.35 + 0.25 * pulse)
            ..maskFilter = _blur(r * 0.12),
        );
      }
      return;
    }
    void dashes(Color color, double scale, int count, double len, double turn) {
      final rect = Rect.fromCircle(center: c, radius: r * scale);
      for (var i = 0; i < count; i++) {
        final a = turn + i * 2 * math.pi / count;
        canvas.drawArc(
          rect,
          a,
          len,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = r * 0.07
            ..color = color,
        );
        canvas.drawArc(
          rect,
          a,
          len,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = r * 0.025
            ..color = Colors.white.withValues(alpha: 0.85),
        );
      }
      final spark = c + _dir(turn * 1.6) * r * scale;
      canvas.drawCircle(
        spark,
        r * 0.07,
        Paint()
          ..color = Colors.white
          ..maskFilter = _blur(r * 0.04),
      );
    }

    dashes(cyan, 1.06, 6, 0.6, t * 1.4);
    dashes(pink, 1.18, 4, 1.0, -t * 1.1);
  }

  /// Waves rolling round the picture, with droplets splashing off.
  void _tidal(Canvas canvas, Offset c, double r, double t) {
    if (!front) {
      canvas.drawCircle(
        c,
        r * 1.1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.36
          ..color = const Color(0xFF1A6BFF).withValues(alpha: 0.35)
          ..maskFilter = _blur(r * 0.2),
      );
    }
    const waves = [
      (1.08, 5.0, 0.07, Color(0xFF1A6BFF), 0.16, 0.9),
      (1.05, 7.0, 0.05, Color(0xFF3FD8FF), 0.1, -1.3),
      (1.03, 9.0, 0.03, Color(0xFFE6FBFF), 0.04, 1.8),
    ];
    for (final (i, (scale, freq, amp, color, width, speed)) in waves.indexed) {
      // The deep wave behind, the crests in front.
      if ((i == 0) == front) continue;
      final path = Path();
      const steps = 90;
      for (var k = 0; k <= steps; k++) {
        final a = k / steps * 2 * math.pi;
        final d = r * (scale + amp * math.sin(a * freq + t * speed * 3));
        final p = c + _dir(a) * d;
        if (k == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * width
          ..strokeJoin = StrokeJoin.round
          ..color = color.withValues(alpha: i == 2 ? 0.9 : 0.8),
      );
    }
    if (front) {
      for (var i = 0; i < 10; i++) {
        final life = (t * 0.7 + _rand(i, 1)) % 1;
        final a = _rand(i, 2) * 2 * math.pi + t * 0.3;
        final d = r * (1.1 + 0.4 * life);
        final pos = c + _dir(a) * d + Offset(0, r * 0.3 * life * life);
        canvas.drawCircle(
          pos,
          r * 0.04 * (1 - life) + 0.5,
          Paint()..color = const Color(0xFFBFF4FF).withValues(alpha: 1 - life),
        );
      }
    }
  }

  /// A golden halo floating above the head, with feathers drifting down.
}
