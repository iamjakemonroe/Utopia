part of 'utopia_world.dart';

/// Alien hills (glowing mushrooms, jellyfish, a UFO) and the neon city (a skyline, flying cars, a synthwave grid).
extension _NightLands on _ScenePainter {
  void _alienBiome(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;
    _cloud(canvas, size, t, y: h * 0.32, scale: 0.7, speed: 5, offset: 0.3);
    _ufo(canvas, size, t);
    _jellies(canvas, size, t, count: 3, far: true);

    const baselines = [0.64, 0.77, 0.9];
    const heights = [0.12, 0.08, 0.06];
    for (var i = 0; i < 3; i++) {
      final base = h * baselines[i];
      final ridge = _ridge(
        w,
        base,
        h * heights[i],
        seed: i * 23 + 5,
        sharp: false,
      );
      final pair = style.layers[i];
      canvas.drawPath(
        Path()..addPolygon([...ridge, Offset(w, h), Offset(0, h)], true),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, base - h * heights[i]),
            Offset(0, h),
            [_mix(pair.$1, style.haze, i == 0 ? 0.3 : 0), pair.$2],
          ),
      );
      // Glowing pools in the hills.
      if (i == 1) {
        for (final x in const [0.32, 0.7]) {
          final c = Offset(w * x, base + h * 0.03);
          final pulse = 0.6 + 0.4 * math.sin(t * 1.4 + x * 9);
          canvas.drawOval(
            Rect.fromCenter(center: c, width: w * 0.16, height: h * 0.014),
            Paint()..color = _alpha(style.glow, 0.55 * pulse),
          );
        }
      }
      if (i == 0) {
        _crystal(canvas, Offset(w * 0.12, base - h * 0.02), w * 0.07, t, 0.7);
        _crystal(canvas, Offset(w * 0.9, base - h * 0.03), w * 0.09, t, 2.2);
      }
      if (i == 1) {
        _mushroom(canvas, Offset(w * 0.86, base + h * 0.01), w * 0.2, t, 1.3);
      }
      if (i == 2) {
        _mushroom(canvas, Offset(w * 0.14, base + h * 0.02), w * 0.26, t, 0);
        _mushroom(canvas, Offset(w * 0.32, base + h * 0.04), w * 0.12, t, 2.6);
      }
    }
    _jellies(canvas, size, t, count: 2, far: false);
    _sparkles(canvas, size, t, count: 26);
  }

  /// A giant glowing mushroom: a curving stem and a spotted cap that
  /// breathes light.
  void _mushroom(Canvas canvas, Offset base, double s, double t, double phase) {
    final sway = math.sin(t * 0.8 + phase) * s * 0.03;
    final top = base.translate(sway, -s * 0.85);
    final stem = Path()
      ..moveTo(base.dx - s * 0.09, base.dy)
      ..quadraticBezierTo(
        base.dx - s * 0.12,
        base.dy - s * 0.45,
        top.dx - s * 0.06,
        top.dy,
      )
      ..lineTo(top.dx + s * 0.06, top.dy)
      ..quadraticBezierTo(
        base.dx + s * 0.1,
        base.dy - s * 0.45,
        base.dx + s * 0.09,
        base.dy,
      )
      ..close();
    canvas.drawPath(
      stem,
      Paint()
        ..shader = ui.Gradient.linear(top, base, [
          style.land[0],
          style.land[2],
        ]),
    );
    final pulse = 0.65 + 0.35 * math.sin(t * 1.6 + phase);
    final capRect = Rect.fromCenter(
      center: top.translate(0, s * 0.02),
      width: s * 0.95,
      height: s * 0.62,
    );
    canvas.drawCircle(
      capRect.center,
      s * 0.75,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                _alpha(style.foliage[1], 0.35 * pulse),
                _alpha(style.foliage[1], 0),
              ],
            ).createShader(
              Rect.fromCircle(center: capRect.center, radius: s * 0.75),
            ),
    );
    final cap = Path()
      ..moveTo(capRect.left, capRect.center.dy)
      ..arcTo(capRect, math.pi, math.pi, false)
      ..quadraticBezierTo(
        capRect.center.dx,
        capRect.center.dy + s * 0.12,
        capRect.left,
        capRect.center.dy,
      )
      ..close();
    canvas.drawPath(
      cap,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.5),
          colors: [style.foliage[0], style.foliage[1], style.foliage[2]],
        ).createShader(capRect),
    );
    final spot = Paint()
      ..color = Colors.white.withValues(alpha: 0.55 + 0.3 * pulse);
    for (var i = 0; i < 5; i++) {
      final a = math.pi * (1.15 + i * 0.17);
      final p =
          capRect.center +
          Offset(math.cos(a) * s * 0.3, math.sin(a) * s * 0.18);
      canvas.drawCircle(p, s * (0.035 + 0.015 * (i % 2)), spot);
    }
  }

  /// Translucent jellyfish creatures drifting through the air.
  void _jellies(
    Canvas canvas,
    Size size,
    double t, {
    required int count,
    required bool far,
  }) {
    final salt = far ? 70 : 80;
    for (var i = 0; i < count; i++) {
      final s = size.width * (far ? 0.05 : 0.08) * (0.8 + _rand(i, salt) * 0.4);
      final span = size.width + s * 4;
      final x = (t * (far ? 4 : 7) + _rand(i, salt + 1) * span) % span - s * 2;
      final y =
          size.height * (far ? 0.38 : 0.55) * (0.8 + _rand(i, salt + 2) * 0.4) +
          math.sin(t * 0.9 + i * 2) * s * 0.6;
      _jellyfish(
        canvas,
        Offset(x, y),
        s,
        t,
        i * 1.7,
        style.sparkles[i % style.sparkles.length],
        far ? 0.5 : 0.8,
      );
    }
  }

  void _jellyfish(
    Canvas canvas,
    Offset c,
    double s,
    double t,
    double phase,
    Color tint,
    double alpha,
  ) {
    final pulse = math.sin(t * 2.2 + phase);
    final bell = Rect.fromCenter(
      center: c,
      width: s * (1 + 0.08 * pulse),
      height: s * (0.75 - 0.06 * pulse),
    );
    canvas.drawCircle(
      c,
      s * 1.1,
      Paint()
        ..shader = RadialGradient(
          colors: [_alpha(tint, 0.25 * alpha), _alpha(tint, 0)],
        ).createShader(Rect.fromCircle(center: c, radius: s * 1.1)),
    );
    final dome = Path()
      ..moveTo(bell.left, bell.center.dy)
      ..arcTo(bell, math.pi, math.pi, false)
      ..close();
    canvas.drawPath(
      dome,
      Paint()
        ..shader = ui.Gradient.linear(bell.topCenter, bell.bottomCenter, [
          _alpha(Colors.white, 0.75 * alpha),
          _alpha(tint, 0.55 * alpha),
        ]),
    );
    final tentacle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, s * 0.05)
      ..strokeCap = StrokeCap.round
      ..color = _alpha(tint, 0.6 * alpha);
    for (var k = 0; k < 4; k++) {
      final x0 = bell.left + bell.width * (0.2 + k * 0.2);
      final path = Path()..moveTo(x0, bell.center.dy);
      for (var j = 1; j <= 6; j++) {
        path.lineTo(
          x0 + math.sin(t * 3 + phase + j * 0.9 + k) * s * 0.08,
          bell.center.dy + j * s * 0.14,
        );
      }
      canvas.drawPath(path, tentacle);
    }
  }

  /// Now and then a flying saucer glides across, beaming something up.
  void _ufo(Canvas canvas, Size size, double t) {
    const period = 22.0;
    final k = (t / period).floor();
    final local = (t - k * period) / 9;
    if (local > 1) return;
    final w = size.width;
    final x = -w * 0.15 + local * w * 1.3;
    final y =
        size.height * (0.24 + 0.06 * _rand(k, 90)) + math.sin(local * 18) * 4;
    final s = w * 0.07;
    final c = Offset(x, y);
    if (local > 0.4 && local < 0.6) {
      final beam = Path()
        ..moveTo(c.dx - s * 0.2, c.dy)
        ..lineTo(c.dx + s * 0.2, c.dy)
        ..lineTo(c.dx + s * 0.7, c.dy + s * 2.6)
        ..lineTo(c.dx - s * 0.7, c.dy + s * 2.6)
        ..close();
      final fade = math.sin((local - 0.4) / 0.2 * math.pi);
      canvas.drawPath(
        beam,
        Paint()
          ..shader = ui.Gradient.linear(c, c.translate(0, s * 2.6), [
            _alpha(style.glow, 0.45 * fade),
            _alpha(style.glow, 0),
          ]),
      );
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(0, -s * 0.18),
        width: s * 0.55,
        height: s * 0.5,
      ),
      Paint()..color = _alpha(style.cloudLight, 0.8),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c, width: s * 1.4, height: s * 0.38),
      Paint()
        ..shader = ui.Gradient.linear(
          c.translate(0, -s * 0.2),
          c.translate(0, s * 0.2),
          [style.rock[0], style.rock[2]],
        ),
    );
    for (var i = 0; i < 4; i++) {
      final on = ((t * 4).floor() + i).isEven;
      canvas.drawCircle(
        c.translate((i - 1.5) * s * 0.3, s * 0.04),
        s * 0.05,
        Paint()..color = on ? style.glow : _alpha(style.glow, 0.3),
      );
    }
  }

  void _cityBiome(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;
    // Bands across the sun, synthwave style.
    final sun = _celestialAnchor(style, size);
    final sunR = w * 0.2;
    for (var i = 0; i < 5; i++) {
      final y = sun.dy + sunR * (0.12 + i * 0.17);
      canvas.drawRect(
        Rect.fromLTWH(sun.dx - sunR, y, sunR * 2, 2.0 + i * 1.6),
        Paint()..color = style.sky[3],
      );
    }
    _skyline(
      canvas,
      size,
      t,
      base: h * 0.7,
      maxHeight: h * 0.3,
      seed: 3,
      layer: 0,
    );
    _flyingCars(canvas, size, t, y0: h * 0.42, far: true);
    _skyline(
      canvas,
      size,
      t,
      base: h * 0.8,
      maxHeight: h * 0.24,
      seed: 11,
      layer: 1,
    );
    _flyingCars(canvas, size, t, y0: h * 0.58, far: false);
    _grid(canvas, size, t, top: h * 0.8);
    _sparkles(canvas, size, t, count: 10);
  }

  /// A row of towers with lit windows, blinking rooftop lights and a few
  /// neon signs.
  void _skyline(
    Canvas canvas,
    Size size,
    double t, {
    required double base,
    required double maxHeight,
    required int seed,
    required int layer,
  }) {
    final w = size.width;
    final pair = style.layers[layer];
    final window = Paint();
    var x = -w * 0.02;
    var i = 0;
    while (x < w) {
      final bw = w * (0.07 + _rand(i, seed) * 0.08);
      final bh = maxHeight * (0.35 + 0.65 * _rand(i, seed + 1));
      final top = base - bh;
      final rect = Rect.fromLTWH(x, top, bw - 2, bh + size.height);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(rect.topCenter, Offset(x, base), [
            _mix(pair.$1, style.haze, layer == 0 ? 0.25 : 0),
            pair.$2,
          ]),
      );
      // Windows: a grid, some lit, a few flickering now and then.
      final cols = math.max(2, (bw / 9).floor());
      final rows = math.max(2, (bh / 11).floor());
      final cw = (bw - 4) / cols;
      for (var r = 0; r < rows; r++) {
        for (var col = 0; col < cols; col++) {
          final n = i * 97 + r * 13 + col;
          if (_rand(n, seed + 2) > 0.42) continue;
          final flick = _rand(n + (t * 0.3).floor() * 7, seed + 3) > 0.94;
          if (flick) continue;
          final tint = _rand(n, seed + 4) > 0.8
              ? style.foliage[(n % 3)]
              : _mix(style.glow, Colors.white, 0.65);
          window.color = _alpha(tint, layer == 0 ? 0.45 : 0.8);
          canvas.drawRect(
            Rect.fromLTWH(
              x + 2 + col * cw + cw * 0.2,
              top + 6 + r * 11.0,
              cw * 0.55,
              5,
            ),
            window,
          );
        }
      }
      // A rooftop light on the tall ones.
      if (bh > maxHeight * 0.7) {
        final on = ((t * 1.2) + i).floor().isEven;
        canvas.drawLine(
          Offset(x + bw / 2, top),
          Offset(x + bw / 2, top - 10),
          Paint()
            ..strokeWidth = 1.4
            ..color = pair.$1,
        );
        canvas.drawCircle(
          Offset(x + bw / 2, top - 11),
          on ? 2.6 : 1.6,
          Paint()
            ..color = on
                ? const Color(0xFFFF4D5E)
                : _alpha(const Color(0xFFFF4D5E), 0.4),
        );
      }
      // Now and then a neon sign down the side.
      if (layer == 1 && _rand(i, seed + 5) > 0.6) {
        final neon = style.foliage[i % 3];
        final glow = 0.7 + 0.3 * math.sin(t * 3 + i * 2);
        final sign = Rect.fromLTWH(x + bw * 0.12, top + bh * 0.2, 4, bh * 0.35);
        canvas.drawRRect(
          RRect.fromRectAndRadius(sign.inflate(4), const Radius.circular(4)),
          Paint()..color = _alpha(neon, 0.25 * glow),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(sign, const Radius.circular(2)),
          Paint()..color = _alpha(neon, glow),
        );
      }
      x += bw;
      i++;
    }
  }

  /// Light streaks of flying cars: headlights one way, tail lights the
  /// other.
  void _flyingCars(
    Canvas canvas,
    Size size,
    double t, {
    required double y0,
    required bool far,
  }) {
    final w = size.width;
    for (var i = 0; i < (far ? 4 : 3); i++) {
      final dir = i.isEven ? 1.0 : -1.0;
      final speed = (far ? 40 : 70) + _rand(i, far ? 100 : 110) * 30;
      final span = w + 120;
      final p = (t * speed + _rand(i, far ? 101 : 111) * span) % span;
      final x = dir > 0 ? p - 60 : w + 60 - p;
      final y = y0 + i * (far ? 14 : 20);
      final color = dir > 0 ? const Color(0xFFFFF6D6) : const Color(0xFFFF4D5E);
      final tail = Offset(x - dir * (far ? 22 : 36), y);
      canvas.drawLine(
        tail,
        Offset(x, y),
        Paint()
          ..strokeWidth = far ? 1.6 : 2.4
          ..strokeCap = StrokeCap.round
          ..shader = ui.Gradient.linear(tail, Offset(x, y), [
            _alpha(color, 0),
            color,
          ]),
      );
      canvas.drawCircle(Offset(x, y), far ? 1.6 : 2.6, Paint()..color = color);
    }
  }

  /// A neon grid floor rolling toward you.
  void _grid(Canvas canvas, Size size, double t, {required double top}) {
    final w = size.width;
    final h = size.height;
    final floor = Rect.fromLTRB(0, top, w, h);
    canvas.drawRect(
      floor,
      Paint()
        ..shader = ui.Gradient.linear(floor.topCenter, floor.bottomCenter, [
          style.layers[2].$1,
          style.layers[2].$2,
        ]),
    );
    final line = Paint()
      ..strokeWidth = 1.2
      ..color = _alpha(style.land[0], 0.55);
    const rows = 9;
    final scroll = (t * 0.35) % 1;
    for (var k = 0; k < rows; k++) {
      final u = (k + scroll) / rows;
      final y = top + (h - top) * u * u;
      line.color = _alpha(style.land[0], 0.15 + 0.5 * u);
      canvas.drawLine(Offset(0, y), Offset(w, y), line);
    }
    // Lines running from the horizon toward you, meeting far beyond it.
    final vanish = Offset(w / 2, top - (h - top) * 0.4);
    final atHorizon = (top - vanish.dy) / (h - vanish.dy);
    line.color = _alpha(style.land[0], 0.4);
    for (var k = -8; k <= 8; k++) {
      final bottom = Offset(w / 2 + k * w * 0.16, h);
      canvas.drawLine(Offset.lerp(vanish, bottom, atHorizon)!, bottom, line);
    }
    // The horizon line glowing.
    canvas.drawLine(
      Offset(0, top),
      Offset(w, top),
      Paint()
        ..strokeWidth = 2
        ..color = _alpha(style.glow, 0.85),
    );
  }
}
