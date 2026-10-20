part of 'utopia_world.dart';

/// Peaks (mountain ranges, a hot-air balloon), dunes (a huge sun, sky lanterns) and sakura (a torii gate, cherry trees, petals).
extension _Lands on _ScenePainter {
  void _peaksBiome(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;
    _cloud(canvas, size, t, y: h * 0.3, scale: 0.8, speed: 6, offset: 0.4);
    _birds(canvas, size, t);
    _balloon(canvas, size, t);

    const baselines = [0.62, 0.76, 0.9];
    const heights = [0.3, 0.2, 0.12];
    for (var i = 0; i < 3; i++) {
      final base = h * baselines[i];
      // The far range is sharp and craggy; nearer ones roll into hills.
      final ridge = _ridge(
        w,
        base,
        h * heights[i],
        seed: i * 17 + 3,
        sharp: i < 2,
      );
      final fill = Path()
        ..addPolygon([...ridge, Offset(w, h), Offset(0, h)], true);
      final pair = style.layers[i];
      final top = base - h * heights[i];
      canvas.drawPath(
        fill,
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, top), Offset(0, h), [
            _mix(pair.$1, style.haze, i == 0 ? 0.35 : 0),
            pair.$2,
          ]),
      );
      if (i < 2) _litFacets(canvas, ridge, base, h);
      if (i == 0) _snowcaps(canvas, ridge, base - h * heights[i] * 0.55);
      // Mist pooling in front of each range.
      final mistY = base + h * 0.02;
      final mistRect = Rect.fromLTRB(0, mistY - h * 0.05, w, mistY + h * 0.04);
      canvas.drawRect(
        mistRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _alpha(style.cloudLight, 0),
              _alpha(style.cloudLight, 0.14 + 0.04 * math.sin(t * 0.6 + i)),
              _alpha(style.cloudLight, 0),
            ],
          ).createShader(mistRect),
      );
      if (i == 0) {
        _island(
          canvas,
          Offset(w * 0.78, h * 0.42),
          w * 0.22,
          t,
          phase: 1.1,
          crystal: true,
          waterfall: true,
        );
      }
      if (i == 1) {
        _island(
          canvas,
          Offset(w * 0.2, h * 0.58),
          w * 0.2,
          t,
          phase: 2.4,
          tree: true,
        );
      }
    }
    _sparkles(canvas, size, t, count: 14);
  }

  /// Brightens every slope that faces the light (rising left to right), so
  /// the range reads as faceted rock rather than a flat cut-out.
  void _litFacets(Canvas canvas, List<Offset> ridge, double base, double h) {
    final lit = Path();
    for (var i = 1; i < ridge.length - 2; i++) {
      final a = ridge[i];
      final b = ridge[i + 1];
      if (b.dy < a.dy) {
        lit.addPolygon([
          a,
          b,
          Offset(b.dx, base + h * 0.04),
          Offset(a.dx, base + h * 0.04),
        ], true);
      }
    }
    canvas.drawPath(
      lit,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, base - h * 0.3),
          Offset(0, base),
          [
            Colors.white.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0),
          ],
        ),
    );
  }

  void _snowcaps(Canvas canvas, List<Offset> ridge, double snowline) {
    final cap = Path();
    var open = false;
    for (final p in ridge) {
      if (p.dy < snowline) {
        if (!open) {
          cap.moveTo(p.dx, snowline);
          open = true;
        }
        cap.lineTo(p.dx, p.dy);
      } else if (open) {
        cap.lineTo(p.dx, snowline);
        cap.close();
        open = false;
      }
    }
    canvas.drawPath(
      cap,
      Paint()..color = _alpha(_mix(style.land[0], style.haze, 0.25), 0.9),
    );
  }

  void _balloon(Canvas canvas, Size size, double t) {
    final span = size.width + 120;
    final x = (t * 7 + span * 0.3) % span - 60;
    final y = size.height * 0.36 + math.sin(t * 0.5) * 14;
    final c = Offset(x, y);
    const r = 22.0;
    // Envelope: a rounded teardrop.
    final envelope = Path()
      ..moveTo(c.dx, c.dy + r * 1.25)
      ..cubicTo(
        c.dx - r * 0.35,
        c.dy + r * 0.9,
        c.dx - r * 1.05,
        c.dy + r * 0.3,
        c.dx - r,
        c.dy - r * 0.2,
      )
      ..cubicTo(
        c.dx - r * 0.95,
        c.dy - r * 1.25,
        c.dx + r * 0.95,
        c.dy - r * 1.25,
        c.dx + r,
        c.dy - r * 0.2,
      )
      ..cubicTo(
        c.dx + r * 1.05,
        c.dy + r * 0.3,
        c.dx + r * 0.35,
        c.dy + r * 0.9,
        c.dx,
        c.dy + r * 1.25,
      )
      ..close();
    final bounds = envelope.getBounds();
    canvas.drawPath(
      envelope,
      Paint()
        ..shader = LinearGradient(
          colors: [
            _mix(style.glow, Colors.white, 0.3),
            style.glow,
            _ColorMath.darken(style.glow, 0.25),
          ],
        ).createShader(bounds),
    );
    // Stripes.
    canvas.save();
    canvas.clipPath(envelope);
    final stripe = Paint()..color = _alpha(style.foliage[1], 0.85);
    for (final dx in const [-0.55, 0.0, 0.55]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(dx * r, -r * 0.1),
          width: r * 0.28,
          height: r * 2.8,
        ),
        stripe,
      );
    }
    canvas.restore();
    canvas.drawCircle(
      c.translate(-r * 0.4, -r * 0.55),
      r * 0.16,
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );
    // Ropes, basket and a flickering flame.
    final rope = Paint()
      ..strokeWidth = 1
      ..color = _alpha(style.rock[2], 0.8);
    final basketTop = c.dy + r * 1.75;
    canvas.drawLine(
      c.translate(-r * 0.3, r * 1.15),
      Offset(c.dx - r * 0.25, basketTop),
      rope,
    );
    canvas.drawLine(
      c.translate(r * 0.3, r * 1.15),
      Offset(c.dx + r * 0.25, basketTop),
      rope,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(c.dx - r * 0.3, basketTop, r * 0.6, r * 0.42),
        const Radius.circular(2),
      ),
      Paint()..color = style.rock[1],
    );
    final flicker = 0.7 + 0.3 * math.sin(t * 13);
    canvas.drawCircle(
      c.translate(0, r * 1.4),
      r * 0.28 * flicker,
      Paint()..color = _alpha(style.glow, 0.6),
    );
  }

  void _dunesBiome(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;
    // Thin clouds streaking across the sun.
    for (var i = 0; i < 3; i++) {
      final y = h * (0.5 + i * 0.035);
      final drift = (t * (6 + i * 3) + i * 120) % (w + 200) - 100;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(drift, y, w * (0.35 + 0.1 * i), 5 + i * 1.5),
          const Radius.circular(4),
        ),
        Paint()..color = _alpha(style.cloudLight, 0.35),
      );
    }
    _lanterns(canvas, size, t, far: true);

    const baselines = [0.68, 0.79, 0.9];
    for (var i = 0; i < 3; i++) {
      final base = h * baselines[i];
      final path = Path()..moveTo(0, h);
      final crest = Path();
      for (var x = 0.0; x <= w + 6; x += 6) {
        final y =
            base -
            h * 0.04 * math.sin(x / w * math.pi * (1.2 + i * 0.5) + i * 1.7) -
            h * 0.006 * math.sin(x / w * math.pi * 3 + i);
        path.lineTo(x, y);
        if (x == 0) {
          crest.moveTo(x, y);
        } else {
          crest.lineTo(x, y);
        }
      }
      path
        ..lineTo(w, h)
        ..close();
      final pair = style.layers[i];
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, base - h * 0.05),
            Offset(0, h),
            [pair.$1, pair.$2],
          ),
      );
      canvas.drawPath(
        crest,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = _alpha(style.land[0], 0.35),
      );
    }

    // Sand blowing off the front dune.
    final grain = Paint();
    for (var i = 0; i < 24; i++) {
      final life = (t * (0.12 + _rand(i, 40) * 0.1) + _rand(i, 41)) % 1.0;
      final p = Offset(
        w * life * 1.2 - w * 0.1,
        h * (0.86 + _rand(i, 42) * 0.08) - math.sin(life * math.pi) * 18,
      );
      grain.color = _alpha(style.land[0], 0.5 * math.sin(life * math.pi));
      canvas.drawCircle(p, 1 + _rand(i, 43), grain);
    }
    _lanterns(canvas, size, t, far: false);
  }

  /// Paper sky lanterns floating up. The far set is smaller and fainter.
  void _lanterns(Canvas canvas, Size size, double t, {required bool far}) {
    final count = far ? 9 : 6;
    final salt = far ? 50 : 60;
    for (var i = 0; i < count; i++) {
      final life =
          (t * (0.02 + _rand(i, salt) * 0.02) + _rand(i, salt + 1)) % 1.0;
      final scale = far
          ? 0.55 + _rand(i, salt + 2) * 0.25
          : 0.9 + _rand(i, salt + 2) * 0.4;
      final x =
          _rand(i, salt + 3) * size.width +
          math.sin(t * 0.5 + i * 2) * 14 * scale;
      final y = size.height * (1.05 - life * 1.1);
      final alpha =
          math.min(1.0, math.sin(life * math.pi) * 1.6) * (far ? 0.6 : 0.95);
      final flicker = 0.85 + 0.15 * math.sin(t * 9 + i * 3);
      final c = Offset(x, y);
      final bw = 6.5 * scale;
      final bh = 9 * scale;

      canvas.drawCircle(
        c,
        bh * 2.2,
        Paint()
          ..shader = RadialGradient(
            colors: [
              _alpha(style.glow, 0.32 * alpha * flicker),
              _alpha(style.glow, 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: bh * 2.2)),
      );
      // Paper body: a rounded top, tapering to an open base.
      final body = Path()
        ..moveTo(c.dx - bw * 0.62, c.dy + bh * 0.7)
        ..quadraticBezierTo(
          c.dx - bw * 1.05,
          c.dy - bh * 0.1,
          c.dx - bw * 0.8,
          c.dy - bh * 0.62,
        )
        ..quadraticBezierTo(
          c.dx,
          c.dy - bh * 1.05,
          c.dx + bw * 0.8,
          c.dy - bh * 0.62,
        )
        ..quadraticBezierTo(
          c.dx + bw * 1.05,
          c.dy - bh * 0.1,
          c.dx + bw * 0.62,
          c.dy + bh * 0.7,
        )
        ..close();
      canvas.drawPath(
        body,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              _alpha(_mix(style.glow, Colors.white, 0.7), alpha * flicker),
              _alpha(style.glow, alpha),
              _alpha(_ColorMath.darken(style.glow, 0.22), alpha),
            ],
          ).createShader(body.getBounds()),
      );
      // Paper ribs and the flame glowing at the base.
      final rib = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = _alpha(_ColorMath.darken(style.glow, 0.3), 0.5 * alpha);
      canvas.drawLine(
        c.translate(0, -bh * 0.85),
        c.translate(0, bh * 0.7),
        rib,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(0, bh * 0.62),
          width: bw * 0.7,
          height: bh * 0.28,
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.85 * alpha * flicker),
      );
    }
  }

  void _sakuraBiome(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;
    // The great mountain, snow-capped.
    final apex = Offset(w * 0.5, h * 0.36);
    final mountain = Path()
      ..moveTo(-w * 0.1, h * 0.74)
      ..quadraticBezierTo(
        w * 0.28,
        h * 0.58,
        apex.dx - w * 0.07,
        apex.dy + h * 0.02,
      )
      ..lineTo(apex.dx + w * 0.07, apex.dy + h * 0.02)
      ..quadraticBezierTo(w * 0.72, h * 0.58, w * 1.1, h * 0.74)
      ..close();
    canvas.drawPath(
      mountain,
      Paint()
        ..shader = ui.Gradient.linear(apex, Offset(apex.dx, h * 0.74), [
          _mix(style.rock[0], style.haze, 0.2),
          style.layers[0].$2,
        ]),
    );
    final snow = Path()
      ..moveTo(apex.dx - w * 0.07, apex.dy + h * 0.02)
      ..lineTo(apex.dx + w * 0.07, apex.dy + h * 0.02)
      ..lineTo(apex.dx + w * 0.15, apex.dy + h * 0.1)
      ..lineTo(apex.dx + w * 0.1, apex.dy + h * 0.085)
      ..lineTo(apex.dx + w * 0.06, apex.dy + h * 0.11)
      ..lineTo(apex.dx + w * 0.02, apex.dy + h * 0.08)
      ..lineTo(apex.dx - w * 0.03, apex.dy + h * 0.115)
      ..lineTo(apex.dx - w * 0.08, apex.dy + h * 0.085)
      ..lineTo(apex.dx - w * 0.15, apex.dy + h * 0.1)
      ..close();
    canvas.drawPath(
      snow,
      Paint()
        ..shader = ui.Gradient.linear(apex, apex.translate(0, h * 0.1), [
          style.land[0],
          style.land[2],
        ]),
    );
    _cloud(canvas, size, t, y: h * 0.52, scale: 1.1, speed: 5, offset: 0.2);
    _cloud(canvas, size, t, y: h * 0.3, scale: 0.6, speed: 3, offset: 0.7);

    // Two rolling hills, a shrine gate on the left one.
    for (var i = 1; i < 3; i++) {
      final base = h * (i == 1 ? 0.8 : 0.9);
      final ridge = _ridge(
        w,
        base,
        h * (i == 1 ? 0.08 : 0.06),
        seed: i * 31 + 2,
        sharp: false,
      );
      final pair = style.layers[i];
      canvas.drawPath(
        Path()..addPolygon([...ridge, Offset(w, h), Offset(0, h)], true),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, base - h * 0.08),
            Offset(0, h),
            [pair.$1, pair.$2],
          ),
      );
      if (i == 1) {
        _torii(canvas, Offset(w * 0.24, base - h * 0.04), w * 0.16);
        _sakuraTree(canvas, Offset(w * 0.82, base - h * 0.02), w * 0.3, t, 0.8);
      } else {
        _sakuraTree(canvas, Offset(w * 0.06, base), w * 0.34, t, 2.1);
      }
    }
    _petals(canvas, size, t);
  }

  void _torii(Canvas canvas, Offset base, double s) {
    final red = Paint()..color = style.glow;
    final dark = Paint()..color = _ColorMath.darken(style.glow, 0.25);
    // Two posts.
    for (final x in const [-0.32, 0.32]) {
      canvas.drawRect(
        Rect.fromLTWH(
          base.dx + x * s - s * 0.05,
          base.dy - s * 0.78,
          s * 0.1,
          s * 0.78,
        ),
        red,
      );
    }
    // The tie beam, then the curved top beam.
    canvas.drawRect(
      Rect.fromLTWH(base.dx - s * 0.42, base.dy - s * 0.6, s * 0.84, s * 0.07),
      red,
    );
    final top = Path()
      ..moveTo(base.dx - s * 0.58, base.dy - s * 0.86)
      ..quadraticBezierTo(
        base.dx,
        base.dy - s * 0.78,
        base.dx + s * 0.58,
        base.dy - s * 0.86,
      )
      ..lineTo(base.dx + s * 0.55, base.dy - s * 0.76)
      ..quadraticBezierTo(
        base.dx,
        base.dy - s * 0.69,
        base.dx - s * 0.55,
        base.dy - s * 0.76,
      )
      ..close();
    canvas.drawPath(top, dark);
    canvas.drawRect(
      Rect.fromLTWH(base.dx - s * 0.04, base.dy - s * 0.76, s * 0.08, s * 0.16),
      red,
    );
  }

  void _sakuraTree(
    Canvas canvas,
    Offset base,
    double s,
    double t,
    double phase,
  ) {
    final sway = math.sin(t * 0.9 + phase) * s * 0.02;
    final trunk = Path()
      ..moveTo(base.dx - s * 0.04, base.dy)
      ..quadraticBezierTo(
        base.dx - s * 0.06,
        base.dy - s * 0.3,
        base.dx + sway,
        base.dy - s * 0.5,
      )
      ..lineTo(base.dx + s * 0.04 + sway, base.dy - s * 0.5)
      ..quadraticBezierTo(
        base.dx + s * 0.02,
        base.dy - s * 0.3,
        base.dx + s * 0.05,
        base.dy,
      )
      ..close();
    canvas.drawPath(trunk, Paint()..color = style.rock[2]);
    final canopy = base.translate(sway, -s * 0.6);
    const puffs = [
      (0.0, 0.0, 0.26),
      (-0.22, 0.06, 0.2),
      (0.22, 0.05, 0.21),
      (-0.1, -0.15, 0.2),
      (0.13, -0.14, 0.19),
      (0.0, 0.14, 0.17),
    ];
    for (final (k, (dx, dy, r)) in puffs.indexed) {
      final c = canopy.translate(
        dx * s + math.sin(t + k + phase) * s * 0.008,
        dy * s,
      );
      canvas.drawCircle(
        c,
        r * s,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.4),
            colors: [style.foliage[0], style.foliage[1], style.foliage[2]],
          ).createShader(Rect.fromCircle(center: c, radius: r * s)),
      );
    }
  }

  /// Cherry petals drifting down across the whole scene.
  void _petals(Canvas canvas, Size size, double t) {
    for (var i = 0; i < 36; i++) {
      final life = (t * (0.045 + _rand(i, 120) * 0.04) + _rand(i, 121)) % 1.0;
      final x =
          (_rand(i, 122) * 1.3 - 0.15) * size.width +
          life * size.width * 0.35 +
          math.sin(t * 1.3 + i) * 12;
      final y = -10 + life * (size.height + 20);
      final s = 3.0 + _rand(i, 123) * 3;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * (1 + _rand(i, 124)) + i);
      canvas.scale(1, 0.55 + 0.45 * math.sin(t * 2.4 + i).abs());
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: s * 1.6, height: s),
        Paint()..color = _alpha(style.foliage[i.isEven ? 0 : 1], 0.85),
      );
      canvas.restore();
    }
  }
}
