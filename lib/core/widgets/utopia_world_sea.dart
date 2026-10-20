part of 'utopia_world.dart';

/// The ocean (swells, a glittering reflection, birds) and the reef (light shafts, coral, seaweed, fish, a whale, bubbles).
extension _Sea on _ScenePainter {
  void _oceanBiome(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;
    final horizon = h * 0.6;

    _cloud(canvas, size, t, y: h * 0.32, scale: 0.8, speed: 5, offset: 0.2);
    _cloud(canvas, size, t, y: h * 0.45, scale: 1.1, speed: 8, offset: 0.7);
    // A small floating isle far out, spilling a waterfall into the sea.
    _island(
      canvas,
      Offset(w * 0.22, horizon - h * 0.09),
      w * 0.17,
      t,
      phase: 0.8,
      haze: 0.45,
      tree: true,
      waterfall: true,
    );
    _birds(canvas, size, t);

    final sea = Rect.fromLTRB(0, horizon, w, h);
    canvas.drawRect(
      sea,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [style.layers[0].$1, style.layers[1].$2, style.layers[2].$2],
        ).createShader(sea),
    );
    // Haze where the sea meets the sky.
    canvas.drawRect(
      Rect.fromLTRB(0, horizon - 2, w, horizon + h * 0.03),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_alpha(style.sky[5], 0.7), _alpha(style.sky[5], 0)],
        ).createShader(Rect.fromLTRB(0, horizon - 2, w, horizon + h * 0.03)),
    );

    // Glittering reflection under the sun or moon.
    final light = _celestialAnchor(style, size);
    final glitter = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < 26; i++) {
      final depth = i / 26;
      final y = horizon + (h - horizon) * depth * depth + 4;
      final shimmer = math.sin(t * 2.2 + i * 1.7);
      final width = (8 + depth * 46) * (0.55 + 0.45 * shimmer.abs());
      glitter
        ..strokeWidth = 1.2 + depth * 2
        ..color = _alpha(style.celestialColors[0], 0.55 * (1 - depth * 0.7));
      final x = light.dx + math.sin(t * 0.8 + i) * depth * 10;
      canvas.drawLine(
        Offset(x - width / 2, y),
        Offset(x + width / 2, y),
        glitter,
      );
    }

    // Swells rolling in, bigger toward the viewer.
    for (var i = 0; i < 6; i++) {
      final depth = (i + 1) / 6;
      final y = horizon + (h - horizon) * depth * depth;
      final amp = 2 + depth * 9;
      final wavelength = 60 + depth * 120;
      final speed = 6 + depth * 18;
      final pair = style.layers[math.min(2, i ~/ 2)];
      final path = Path()..moveTo(0, h);
      for (var x = 0.0; x <= w + 8; x += 8) {
        path.lineTo(
          x,
          y + amp * math.sin((x + t * speed) / wavelength * 2 * math.pi + i),
        );
      }
      path
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, y - amp), Offset(0, h), [
            _alpha(pair.$1, 0.75),
            _alpha(pair.$2, 0.9),
          ]),
      );
      // Foam catching the light along each crest.
      final crest = Path();
      for (var x = 0.0; x <= w + 8; x += 8) {
        final cy =
            y + amp * math.sin((x + t * speed) / wavelength * 2 * math.pi + i);
        if (x == 0) {
          crest.moveTo(x, cy);
        } else {
          crest.lineTo(x, cy);
        }
      }
      canvas.drawPath(
        crest,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 + depth
          ..color = _alpha(style.cloudLight, 0.18 + 0.14 * depth),
      );
    }
    _sparkles(canvas, size, t, count: 12);
  }

  void _reefBiome(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;
    // The surface shimmering high above.
    final surface = Path()..moveTo(0, h * 0.05);
    for (var x = 0.0; x <= w; x += 8) {
      surface.lineTo(
        x,
        h * 0.05 +
            math.sin(x / w * 14 + t * 1.6) * 3 +
            math.sin(x / w * 31 - t) * 1.5,
      );
    }
    canvas.drawPath(
      surface,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _alpha(style.cloudLight, 0.45),
    );
    // Light shafts swaying down from the surface.
    for (var i = 0; i < 6; i++) {
      final x = w * (0.08 + i * 0.17) + math.sin(t * 0.3 + i * 1.7) * w * 0.04;
      final spread = w * (0.06 + 0.04 * _rand(i, 130));
      final shaft = Path()
        ..moveTo(x - spread * 0.3, 0)
        ..lineTo(x + spread * 0.3, 0)
        ..lineTo(x + spread + w * 0.05, h * 0.85)
        ..lineTo(x - spread + w * 0.05, h * 0.85)
        ..close();
      final a = 0.08 + 0.05 * math.sin(t * 0.7 + i * 2.3);
      canvas.drawPath(
        shaft,
        Paint()
          ..shader = ui.Gradient.linear(Offset(x, 0), Offset(x, h * 0.85), [
            _alpha(style.cloudLight, a),
            _alpha(style.cloudLight, 0),
          ]),
      );
    }
    _whale(canvas, size, t);
    _fish(canvas, size, t, far: true);

    // The seabed: a far rocky shelf, then sand.
    for (var i = 0; i < 3; i++) {
      final base = h * [0.74, 0.84, 0.93][i];
      final ridge = _ridge(
        w,
        base,
        h * [0.1, 0.05, 0.04][i],
        seed: i * 41 + 9,
        sharp: i == 0,
      );
      final pair = style.layers[i];
      canvas.drawPath(
        Path()..addPolygon([...ridge, Offset(w, h), Offset(0, h)], true),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, base - h * 0.1),
            Offset(0, h),
            [_mix(pair.$1, style.haze, i == 0 ? 0.4 : 0.15), pair.$2],
          ),
      );
      if (i == 0) {
        _seaweed(canvas, Offset(w * 0.08, base), h * 0.22, t, 0);
        _seaweed(canvas, Offset(w * 0.6, base + h * 0.01), h * 0.16, t, 1.4);
      }
      if (i == 1) {
        _coral(
          canvas,
          Offset(w * 0.25, base + h * 0.01),
          w * 0.16,
          style.foliage[0],
          0,
        );
        _coral(canvas, Offset(w * 0.78, base), w * 0.2, style.foliage[2], 2);
        _seaweed(canvas, Offset(w * 0.92, base + h * 0.01), h * 0.2, t, 2.2);
      }
      if (i == 2) {
        _coral(
          canvas,
          Offset(w * 0.5, base + h * 0.01),
          w * 0.13,
          style.foliage[1],
          4,
        );
        _seaweed(canvas, Offset(w * 0.36, base + h * 0.02), h * 0.13, t, 3.1);
      }
    }
    _fish(canvas, size, t, far: false);
    _jellies(canvas, size, t, count: 2, far: true);
    _bubbles(canvas, size, t);
  }

  void _seaweed(
    Canvas canvas,
    Offset base,
    double length,
    double t,
    double phase,
  ) {
    for (var k = 0; k < 3; k++) {
      final path = Path()..moveTo(base.dx + k * 6, base.dy);
      const steps = 10;
      for (var j = 1; j <= steps; j++) {
        final u = j / steps;
        path.lineTo(
          base.dx +
              k * 6 +
              math.sin(t * 1.2 + phase + u * 3 + k) * length * 0.08 * u,
          base.dy - length * u * (0.8 + 0.2 * k / 2),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5 - k.toDouble()
          ..strokeCap = StrokeCap.round
          ..color = _mix(const Color(0xFF2FB87E), style.haze, 0.25 + k * 0.1),
      );
    }
  }

  /// A branching coral fan.
  void _coral(Canvas canvas, Offset base, double s, Color color, int seed) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    void branch(Offset from, double angle, double len, int depth) {
      final to = from + Offset(math.cos(angle), math.sin(angle)) * len;
      paint.strokeWidth = math.max(1.5, depth * 2.2);
      canvas.drawLine(from, to, paint);
      if (depth == 0) {
        canvas.drawCircle(
          to,
          2.4,
          Paint()..color = _mix(color, Colors.white, 0.4),
        );
        return;
      }
      branch(
        to,
        angle - 0.42 - _rand(seed + depth, 140) * 0.2,
        len * 0.72,
        depth - 1,
      );
      branch(
        to,
        angle + 0.42 + _rand(seed + depth, 141) * 0.2,
        len * 0.72,
        depth - 1,
      );
    }

    branch(base, -math.pi / 2, s * 0.32, 3);
  }

  void _fish(Canvas canvas, Size size, double t, {required bool far}) {
    final count = far ? 7 : 5;
    final salt = far ? 150 : 160;
    for (var i = 0; i < count; i++) {
      final dir = _rand(i, salt) > 0.5 ? 1.0 : -1.0;
      final s = (far ? 5.0 : 9.0) * (0.8 + _rand(i, salt + 1) * 0.5);
      final span = size.width + s * 6;
      final p =
          (t * (far ? 14 : 24) * (0.7 + _rand(i, salt + 2) * 0.6) +
              _rand(i, salt + 3) * span) %
          span;
      final x = dir > 0 ? p - s * 3 : size.width + s * 3 - p;
      final y =
          size.height *
              (far
                  ? 0.3 + _rand(i, salt + 4) * 0.25
                  : 0.5 + _rand(i, salt + 4) * 0.25) +
          math.sin(t * 1.5 + i) * 6;
      final color = style.foliage[i % 3];
      final wag = math.sin(t * 10 + i) * s * 0.25;
      canvas.save();
      canvas.translate(x, y);
      canvas.scale(dir, 1);
      final body = Path()
        ..moveTo(s, 0)
        ..quadraticBezierTo(0, -s * 0.6, -s, 0)
        ..quadraticBezierTo(0, s * 0.6, s, 0)
        ..close();
      final tail = Path()
        ..moveTo(-s * 0.9, 0)
        ..lineTo(-s * 1.6, -s * 0.5 + wag)
        ..lineTo(-s * 1.6, s * 0.5 + wag)
        ..close();
      final paint = Paint()..color = _alpha(color, far ? 0.55 : 0.95);
      canvas.drawPath(tail, paint);
      canvas.drawPath(body, paint);
      canvas.drawCircle(
        Offset(s * 0.5, -s * 0.12),
        s * 0.12,
        Paint()..color = _alpha(Colors.white, far ? 0.5 : 1),
      );
      canvas.restore();
    }
  }

  /// A whale gliding by in the blue distance, now and then.
  void _whale(Canvas canvas, Size size, double t) {
    const period = 40.0;
    final k = (t / period).floor();
    final local = (t - k * period) / 30;
    if (local > 1) return;
    final w = size.width;
    final s = w * 0.28;
    final x = -s + local * (w + s * 2);
    final y = size.height * 0.3 + math.sin(local * 6) * 8;
    final body = Path()
      ..moveTo(x + s * 0.5, y)
      ..quadraticBezierTo(x + s * 0.4, y - s * 0.2, x, y - s * 0.14)
      ..quadraticBezierTo(x - s * 0.35, y - s * 0.1, x - s * 0.5, y - s * 0.02)
      ..lineTo(x - s * 0.7, y - s * 0.16)
      ..lineTo(x - s * 0.66, y + s * 0.02)
      ..lineTo(x - s * 0.72, y + s * 0.14)
      ..lineTo(x - s * 0.5, y + s * 0.03)
      ..quadraticBezierTo(x, y + s * 0.14, x + s * 0.5, y)
      ..close();
    canvas.drawPath(body, Paint()..color = _alpha(style.rock[2], 0.45));
  }

  void _bubbles(Canvas canvas, Size size, double t) {
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 22; i++) {
      final life = (t * (0.06 + _rand(i, 170) * 0.06) + _rand(i, 171)) % 1.0;
      final x = _rand(i, 172) * size.width + math.sin(t * 2 + i) * 6;
      final y = size.height * (1.02 - life * 1.0);
      final r = 1.5 + _rand(i, 173) * 4;
      final a = math.sin(life * math.pi);
      ring.color = _alpha(Colors.white, 0.55 * a);
      canvas.drawCircle(Offset(x, y), r, ring);
      canvas.drawCircle(
        Offset(x - r * 0.35, y - r * 0.35),
        r * 0.25,
        Paint()..color = _alpha(Colors.white, 0.7 * a),
      );
    }
  }
}
