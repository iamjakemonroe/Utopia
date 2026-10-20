part of 'utopia_world.dart';

/// The islands: floating islands with a waterfall, a blossom tree and a spinning crystal over a sea of clouds (and the cloud rows other worlds share).
extension _Islands on _ScenePainter {
  void _islandsBiome(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;
    // Back to front: a hazy distant island, two clouds, the two near
    // islands, one cloud drifting in front of them, then the cloud sea.
    _island(
      canvas,
      Offset(w * 0.56, h * 0.46),
      w * 0.15,
      t,
      phase: 2.1,
      haze: 0.55,
      tree: true,
    );
    _cloud(canvas, size, t, y: h * 0.36, scale: 0.75, speed: 6, offset: 0.1);
    _cloud(canvas, size, t, y: h * 0.52, scale: 1.0, speed: 9, offset: 0.62);
    _island(
      canvas,
      Offset(w * 0.2, h * 0.6),
      w * 0.38,
      t,
      phase: 0,
      tree: true,
      waterfall: true,
    );
    _island(
      canvas,
      Offset(w * 0.84, h * 0.71),
      w * 0.3,
      t,
      phase: 1.3,
      crystal: true,
    );
    _cloud(canvas, size, t, y: h * 0.67, scale: 0.9, speed: 13, offset: 0.35);
    _layerRows(canvas, size, t);
    _sparkles(canvas, size, t);
  }

  void _island(
    Canvas canvas,
    Offset anchor,
    double width,
    double t, {
    required double phase,
    double haze = 0,
    bool tree = false,
    bool crystal = false,
    bool waterfall = false,
  }) {
    Color hz(Color color) => _mix(color, style.haze, haze);
    final fade = 1 - haze;
    final w = width;
    final c = anchor.translate(0, math.sin(t * 0.55 + phase) * w * 0.035);

    // Soft levitation glow under the rock.
    final glowCenter = c.translate(0, w * 0.42);
    final pulse = 0.75 + 0.25 * math.sin(t * 1.3 + phase);
    canvas.drawCircle(
      glowCenter,
      w * 0.45,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _alpha(style.land[1], 0.2 * fade * pulse),
            _alpha(style.land[1], 0),
          ],
        ).createShader(Rect.fromCircle(center: glowCenter, radius: w * 0.45)),
    );

    // Rocky underside, tapering to a point.
    final left = c.translate(-w / 2, 0);
    final right = c.translate(w / 2, 0);
    final tip = c.translate(w * 0.04, w * 0.6);
    final rock = Path()
      ..moveTo(left.dx, left.dy)
      ..cubicTo(
        left.dx + w * 0.06,
        c.dy + w * 0.22,
        c.dx - w * 0.2,
        c.dy + w * 0.42,
        tip.dx,
        tip.dy,
      )
      ..cubicTo(
        c.dx + w * 0.18,
        c.dy + w * 0.4,
        right.dx - w * 0.05,
        c.dy + w * 0.2,
        right.dx,
        right.dy,
      )
      ..close();
    final rockBounds = Rect.fromLTRB(left.dx, c.dy, right.dx, tip.dy);
    canvas.drawPath(
      rock,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [hz(style.rock[0]), hz(style.rock[1]), hz(style.rock[2])],
        ).createShader(rockBounds),
    );
    // Lit from the upper left.
    canvas.drawPath(
      rock,
      Paint()
        ..shader = LinearGradient(
          stops: const [0.0, 0.45, 1.0],
          colors: [
            Colors.white.withValues(alpha: 0.1 * fade),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.28),
          ],
        ).createShader(rockBounds),
    );
    canvas.save();
    canvas.clipPath(rock);
    final strata = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.012
      ..color = Colors.black.withValues(alpha: 0.18);
    for (final depth in const [0.2, 0.38]) {
      final y = c.dy + w * depth;
      canvas.drawPath(
        Path()
          ..moveTo(left.dx, y)
          ..quadraticBezierTo(c.dx, y + w * 0.06, right.dx, y - w * 0.02),
        strata,
      );
    }
    canvas.restore();

    // A couple of pebbles hanging loose beneath, drifting on their own.
    final pebble = Paint()..color = hz(style.rock[1]);
    for (var i = 0; i < 2; i++) {
      final p = tip.translate(
        i == 0 ? -w * 0.12 : w * 0.1,
        w * (0.1 + i * 0.06) + math.sin(t * 0.9 + phase + i) * w * 0.02,
      );
      canvas.drawOval(
        Rect.fromCenter(center: p, width: w * 0.06, height: w * 0.07),
        pebble,
      );
    }

    // Grassy top, with a darker lip underneath for thickness.
    final cap = Rect.fromCenter(center: c, width: w * 1.04, height: w * 0.2);
    canvas.drawOval(
      cap.shift(Offset(0, w * 0.035)),
      Paint()..color = hz(_ColorMath.darken(style.land[2], 0.08)),
    );
    canvas.drawOval(
      cap,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [hz(style.land[0]), hz(style.land[1]), hz(style.land[2])],
        ).createShader(cap),
    );
    canvas.drawArc(
      cap.deflate(w * 0.02),
      math.pi * 1.1,
      math.pi * 0.8,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.012
        ..color = Colors.white.withValues(alpha: 0.35 * fade),
    );

    if (waterfall) {
      _waterfall(canvas, c.translate(w * 0.36, w * 0.05), w, t);
    }
    if (tree) {
      _tree(canvas, c.translate(-w * 0.18, -w * 0.02), w * 0.22, t, phase, hz);
    }
    if (crystal) {
      _crystal(canvas, c.translate(w * 0.12, -w * 0.1), w * 0.12, t, phase);
    }
  }

  void _waterfall(Canvas canvas, Offset top, double w, double t) {
    final length = w * 0.95;
    final bandWidth = w * 0.07;
    final band = Rect.fromLTWH(
      top.dx - bandWidth / 2,
      top.dy,
      bandWidth,
      length,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(band, Radius.circular(bandWidth / 2)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC9FE8FF), Color(0x005AB8FF)],
        ).createShader(band),
    );
    // Streaks of water sliding down the fall.
    final streak = Paint()
      ..strokeWidth = bandWidth * 0.22
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < 4; k++) {
      final p = (t * 0.9 + k / 4) % 1.0;
      final x = top.dx + (k.isEven ? -bandWidth * 0.18 : bandWidth * 0.18);
      final y = top.dy + p * length;
      streak.color = Colors.white.withValues(alpha: (1 - p) * 0.7);
      canvas.drawLine(Offset(x, y), Offset(x, y + length * 0.12), streak);
    }
    // Mist where it thins out.
    final mist = Paint();
    for (var k = 0; k < 3; k++) {
      final p = (t * 0.5 + k / 3) % 1.0;
      mist.color = Colors.white.withValues(alpha: 0.12 * (1 - p));
      canvas.drawCircle(
        Offset(
          top.dx + (k - 1) * bandWidth * 0.8,
          top.dy + length * 0.92 - p * bandWidth,
        ),
        bandWidth * (0.6 + p),
        mist,
      );
    }
  }

  void _tree(
    Canvas canvas,
    Offset base,
    double s,
    double t,
    double phase,
    Color Function(Color) hz,
  ) {
    final sway = math.sin(t * 1.1 + phase) * s * 0.06;
    final trunk = Path()
      ..moveTo(base.dx - s * 0.07, base.dy)
      ..quadraticBezierTo(
        base.dx - s * 0.02 + sway * 0.3,
        base.dy - s * 0.4,
        base.dx + sway * 0.5,
        base.dy - s * 0.65,
      )
      ..lineTo(base.dx + s * 0.05 + sway * 0.5, base.dy - s * 0.62)
      ..quadraticBezierTo(
        base.dx + s * 0.06,
        base.dy - s * 0.35,
        base.dx + s * 0.08,
        base.dy,
      )
      ..close();
    canvas.drawPath(trunk, Paint()..color = hz(style.rock[1]));

    final top = base.translate(sway, -s * 0.78);
    final canopy = Path()
      ..addOval(Rect.fromCircle(center: top, radius: s * 0.32))
      ..addOval(
        Rect.fromCircle(
          center: top.translate(-s * 0.26, s * 0.12),
          radius: s * 0.24,
        ),
      )
      ..addOval(
        Rect.fromCircle(
          center: top.translate(s * 0.26, s * 0.1),
          radius: s * 0.26,
        ),
      );
    canvas.drawPath(
      canopy,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.5),
          stops: const [0.0, 0.55, 1.0],
          colors: [
            hz(style.foliage[0]),
            hz(style.foliage[1]),
            hz(style.foliage[2]),
          ],
        ).createShader(Rect.fromCircle(center: top, radius: s * 0.5)),
    );
    canvas.drawCircle(
      top.translate(-s * 0.1, -s * 0.14),
      s * 0.08,
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
  }

  void _crystal(Canvas canvas, Offset c, double s, double t, double phase) {
    final center = c.translate(
      0,
      math.sin(t * 1.6 + phase) * s * 0.15 - s * 0.4,
    );
    // Squeezing the width with cos() reads as the gem turning in place.
    final halfWidth =
        s * 0.32 * (0.35 + 0.65 * math.cos(t * 0.9 + phase).abs());
    final pulse = 0.7 + 0.3 * math.sin(t * 2 + phase);

    canvas.drawCircle(
      center,
      s * 1.1,
      Paint()
        ..shader = RadialGradient(
          colors: [_alpha(style.glow, 0.35 * pulse), _alpha(style.glow, 0)],
        ).createShader(Rect.fromCircle(center: center, radius: s * 1.1)),
    );
    final gem = Path()
      ..moveTo(center.dx, center.dy - s * 0.6)
      ..lineTo(center.dx + halfWidth, center.dy)
      ..lineTo(center.dx, center.dy + s * 0.5)
      ..lineTo(center.dx - halfWidth, center.dy)
      ..close();
    canvas.drawPath(
      gem,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _mix(style.glow, Colors.white, 0.75),
            style.glow,
            _ColorMath.darken(style.glow, 0.2),
          ],
        ).createShader(gem.getBounds()),
    );
    canvas.drawLine(
      center.translate(0, -s * 0.6),
      center.translate(0, s * 0.5),
      Paint()
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.5),
    );
  }

  /// The cloud sea along the bottom: three rows of puffs, back to front.
  void _layerRows(Canvas canvas, Size size, double t) {
    final h = size.height;
    const baselines = [0.86, 0.9, 0.95];
    const puffs = [34.0, 30.0, 26.0];
    const speeds = [5.0, 9.0, 14.0];
    for (var i = 0; i < 3; i++) {
      _cloudRow(
        canvas,
        size,
        t,
        baseline: h * baselines[i],
        puff: puffs[i],
        speed: speeds[i],
        seed: i + 1,
        colors: [style.layers[i].$1, style.layers[i].$2],
      );
    }
  }

  /// One endless row of puffs scrolling sideways. Each puff's size comes
  /// from its position in the world rather than on screen, so puffs keep
  /// their shape as they scroll instead of resizing when the row wraps.
  void _cloudRow(
    Canvas canvas,
    Size size,
    double t, {
    required double baseline,
    required double puff,
    required double speed,
    required int seed,
    required List<Color> colors,
  }) {
    final spacing = puff * 1.25;
    final travelled = t * speed;
    final wrapped = (travelled / spacing).floor();
    final shift = travelled - wrapped * spacing;
    final top = baseline + math.sin(t * 0.5 + seed) * 3;

    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, baseline - puff),
        Offset(0, size.height),
        colors,
      );
    final body = Rect.fromLTRB(0, top, size.width, size.height);
    final count = (size.width / spacing).ceil() + 2;
    final puffs = <Rect>[];
    for (var i = -1; i < count; i++) {
      final r = puff * (0.7 + 0.5 * _rand(i - wrapped, seed));
      puffs.add(
        Rect.fromCircle(
          center: Offset(i * spacing + shift, top + r * 0.35),
          radius: r,
        ),
      );
    }
    if (dpr != null) {
      // In a browser, the row as one shape is filled pixel by pixel each
      // frame; its rectangle and round puffs on their own are the GPU's.
      // The colors are solid, so where they overlap looks the same.
      canvas.drawRect(body, paint);
      for (final p in puffs) {
        canvas.drawOval(p, paint);
      }
    } else {
      final row = Path()..addRect(body);
      for (final p in puffs) {
        row.addOval(p);
      }
      canvas.drawPath(row, paint);
    }
  }
}
