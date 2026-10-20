part of 'aura_frame.dart';

/// The fire frames: Dragon Coil, Flame, Phoenix and Inferno.
extension _FireFrames on AuraPainter {
  /// A crimson dragon wound round the picture: its coils pass behind the
  /// picture and over its lower rim, wings beating behind its head. Every
  /// few seconds it rears back and breathes a ring of fire all the way
  /// round. Heat and embers come off it. Only the lower coil and the
  /// firelight touch the picture, never the face.
  /// The fire dragon coiled round the picture, all of it behind (the
  /// picture is never covered).
  void _dragon(Canvas canvas, Offset c, double r, double t) {
    if (front) return;
    paintFireDragonCoiled(
      canvas,
      c,
      r,
      t,
      FireDragonColors.crimson,
      lite: _lite,
    );
  }

  /// A ring of fire: flames all round the picture with soft, wavy edges
  /// like real fire, licking outward and leaning up (heat rises, so they
  /// stand tallest over the top), flickering where they burn rather than
  /// spinning. Now and then a lick breaks off and floats away, and embers
  /// drift up. Warm, never blinding: red tips fade out softly.
  void _flame(Canvas canvas, Offset c, double r, double t) {
    final samples = _lite ? 96 : 220;
    // How tall the flame stands at angle [a]: tongues rise and fall where
    // waves running both ways round the ring meet, so they flicker in
    // place; tallest over the top, low under the bottom.
    double tongue(double a, double seed) {
      final raw =
          0.5 * math.sin(7 * a + t * 2.1 + seed) +
          0.27 * math.sin(11 * a - t * 3.3 + 1.7 + seed) +
          0.13 * math.sin(17 * a + t * 4.7 + 0.5 + seed * 2) +
          0.1 * math.sin(26 * a - t * 6.1 + seed * 3);
      // Raised to a power, the crests come to points and the troughs
      // flatten: tongues of flame rather than puffs.
      final peak = math.pow((raw + 1) / 2, 3.2).toDouble();
      final top = 0.55 - 0.45 * math.sin(a);
      final flicker = 0.85 + 0.15 * math.sin(t * 9 + a * 5 + seed);
      return (0.2 + 2.0 * peak) * (0.35 + 0.65 * top) * flicker;
    }

    // One layer of flame: from just inside the picture's edge out to a
    // wavy edge [height] (times r) tall at most, leaning up.
    Path layer(double height, double seed) {
      final path = Path();
      for (var i = 0; i <= samples; i++) {
        final a = i / samples * 2 * math.pi;
        final h = r * height * tongue(a, seed);
        final p = c + _dir(a) * (r + h) + Offset(0, -h * 0.35);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path
        ..close()
        ..addOval(Rect.fromCircle(center: c, radius: r * 0.96))
        ..fillType = PathFillType.evenOdd;
      return path;
    }

    // Colour by distance from the middle: gold at the picture's edge,
    // through orange to red tips that fade away.
    Paint fill(List<Color> colors, List<double> stops) => Paint()
      ..shader = RadialGradient(
        colors: colors,
        stops: stops,
      ).createShader(Rect.fromCircle(center: c, radius: r * 1.5));

    if (!front) {
      // A low, warm heat haze.
      canvas.drawCircle(
        c,
        r * 1.12,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.36
          ..color = const Color(0xFFFF6A1A).withValues(alpha: 0.16)
          ..maskFilter = _blur(r * 0.22),
      );
      // The outer flames, deep orange to red.
      canvas.drawPath(
        layer(0.42, 0),
        fill(
          const [
            Color(0xFFFFB03A),
            Color(0xFFFF6A1A),
            Color(0xFFE0361A),
            Color(0x00B8200E),
          ],
          const [0.64, 0.72, 0.84, 0.98],
        ),
      );
      if (_lite) return;
      // Licks of flame breaking off the top and floating away.
      for (var i = 0; i < 5; i++) {
        final life = (t * (0.45 + 0.2 * _rand(i, 30)) + _rand(i, 31)) % 1;
        final a = -math.pi / 2 + (_rand(i, 32) - 0.5) * 2.2;
        final start = c + _dir(a) * r * 1.28;
        final p =
            start + Offset(0, -r * 0.45 * life) + _dir(a) * r * 0.1 * life;
        final s = r * 0.09 * (1 - life * 0.7);
        final wisp = Path()
          ..moveTo(p.dx, p.dy - s * 1.6)
          ..quadraticBezierTo(p.dx + s, p.dy, p.dx, p.dy + s * 0.7)
          ..quadraticBezierTo(p.dx - s, p.dy, p.dx, p.dy - s * 1.6)
          ..close();
        canvas.drawPath(
          wisp,
          Paint()
            ..color = Color.lerp(
              const Color(0xFFFFA23A),
              const Color(0xFFE0361A),
              life,
            )!.withValues(alpha: 0.8 * math.sin(life * math.pi)),
        );
      }
      return;
    }

    // The bright inner flames over the rim: orange, then a gold core.
    canvas.drawPath(
      layer(0.26, 2.3),
      fill(
        const [
          Color(0xFFFFD45E),
          Color(0xFFFFA23A),
          Color(0xFFFF6A1A),
          Color(0x00FF5A1A),
        ],
        const [0.64, 0.7, 0.78, 0.88],
      ),
    );
    canvas.drawPath(
      layer(0.12, 4.1),
      fill(
        const [Color(0xFFFFEFA8), Color(0xFFFFD45E), Color(0x00FFB03A)],
        const [0.64, 0.68, 0.75],
      ),
    );

    if (_lite) return;
    // Embers drifting up off the flames.
    for (var i = 0; i < 12; i++) {
      final life = (t * (0.35 + _rand(i, 1) * 0.3) + _rand(i, 2)) % 1;
      final a = _rand(i, 3) * 2 * math.pi;
      final pos =
          c +
          _dir(a) * r * (1.15 + 0.2 * life) +
          Offset(math.sin(t * 2 + i) * r * 0.03, -r * 0.5 * life);
      canvas.drawCircle(
        pos,
        r * 0.022 * (1 - life) + 0.5,
        Paint()
          ..color = Color.lerp(
            const Color(0xFFFFE08A),
            const Color(0xFFE0361A),
            life,
          )!.withValues(alpha: (1 - life) * 0.85),
      );
    }
  }

  /// Flame tongues standing out from a ring of radius [r], leaning back
  /// against the direction of the spin.
  void _fireTongues(
    Canvas canvas,
    Offset c,
    double r,
    double t,
    double spin, {
    required int count,
    required double size,
    required int salt,
    List<Color> palette = const [
      Color(0xEEFFF2B0),
      Color(0xDDFFB43A),
      Color(0x99FF5A1A),
      Color(0x00E0301A),
    ],
    bool Function(double angle)? where,
  }) {
    final paint = Paint()..blendMode = BlendMode.plus;
    for (var i = 0; i < count; i++) {
      final a = spin + i * 2 * math.pi / count + (_rand(i, salt) - 0.5) * 0.25;
      if (where != null && !where(a)) continue;
      final flicker =
          0.5 +
          0.5 *
              math.sin(t * (7 + _rand(i, salt + 4) * 4) + i * 1.9) *
              math.sin(t * 4.3 + i * 0.7 + salt);
      // Uneven, like real fire: some flames tall, some small, and a slow
      // flare rolling round the ring so the big ones gather in places.
      final tall = 0.35 + 1.0 * _rand(i, salt + 9);
      final flare = 0.7 + 0.45 * math.sin(a * 3 - t * 1.7 + salt);
      final h = r * (0.14 + 0.3 * flicker) * size * tall * flare * 1.35;
      final w = r * 0.2 * size * (0.7 + 0.6 * _rand(i, salt + 11));
      final n = _dir(a);
      final tg = _dir(a + math.pi / 2);
      // Trailing: the tip bends back against the turn, and sways.
      final sway = math.sin(t * 6 + i * 2.3) * 0.25;
      final leanRaw = n - tg * (0.4 + 0.4 * _rand(i, salt + 13) - sway);
      final lean = leanRaw / leanRaw.distance;
      final base = c + n * r * 1.0;
      final left = base - tg * (w / 2);
      final right = base + tg * (w / 2);
      final tip = base + lean * h;
      final path = Path()
        ..moveTo(left.dx, left.dy)
        ..cubicTo(
          (left + n * h * 0.45).dx,
          (left + n * h * 0.45).dy,
          (tip - lean * h * 0.3 - tg * w * 0.15).dx,
          (tip - lean * h * 0.3 - tg * w * 0.15).dy,
          tip.dx,
          tip.dy,
        )
        ..cubicTo(
          (tip - lean * h * 0.25 + tg * w * 0.55).dx,
          (tip - lean * h * 0.25 + tg * w * 0.55).dy,
          (right + n * h * 0.35).dx,
          (right + n * h * 0.35).dy,
          right.dx,
          right.dy,
        )
        ..close();
      paint.shader = RadialGradient(
        colors: palette,
        stops: const [0.0, 0.3, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: base, radius: h * 1.05 + 1));
      canvas.drawPath(path, paint);
    }
  }

  /// Wings of flame beating behind the picture, a fiery ring and embers.
  void _phoenix(Canvas canvas, Offset c, double r, double t) {
    final beat = math.sin(t * 3.2);
    if (!front) {
      canvas.drawCircle(
        c,
        r * 1.1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.4
          ..color = const Color(0xFFFF6A1A).withValues(alpha: 0.3)
          ..maskFilter = _blur(r * 0.25),
      );
      final paint = Paint()..blendMode = BlendMode.plus;
      for (final side in const [-1.0, 1.0]) {
        // Five feathers per wing, fanned up and out, flapping together.
        for (var f = 0; f < 5; f++) {
          final spread = 0.25 + f * 0.28 + beat * 0.12;
          final a = -math.pi / 2 + side * (math.pi / 2 - 0.15 - spread * 0.55);
          final len = r * (0.95 + 0.18 * (4 - f) / 4) * (1 + 0.06 * beat);
          final root = c + Offset(side * r * 0.55, r * 0.1);
          final dir = _dir(a);
          final tg = _dir(a + math.pi / 2);
          final tip = root + dir * len;
          final w = r * 0.2;
          final flick = 0.5 + 0.5 * math.sin(t * 9 + f * 1.3 + side);
          final path = Path()
            ..moveTo((root - tg * w * 0.4).dx, (root - tg * w * 0.4).dy)
            ..quadraticBezierTo(
              (root + dir * len * 0.55 - tg * w).dx,
              (root + dir * len * 0.55 - tg * w).dy,
              (tip + tg * w * 0.2 * flick).dx,
              (tip + tg * w * 0.2 * flick).dy,
            )
            ..quadraticBezierTo(
              (root + dir * len * 0.5 + tg * w * 0.6).dx,
              (root + dir * len * 0.5 + tg * w * 0.6).dy,
              (root + tg * w * 0.4).dx,
              (root + tg * w * 0.4).dy,
            )
            ..close();
          paint.shader = RadialGradient(
            colors: const [
              Color(0xEEFFF2B0),
              Color(0xDDFFC23A),
              Color(0xAAFF6A1A),
              Color(0x00C4200F),
            ],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ).createShader(Rect.fromCircle(center: root, radius: len));
          canvas.drawPath(path, paint);
        }
      }
      return;
    }
    canvas.drawCircle(
      c,
      r * 1.02,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08
        ..shader = SweepGradient(
          colors: const [
            Color(0xFFFFE07A),
            Color(0xFFFF7A1A),
            Color(0xFFFFC23A),
            Color(0xFFFF4D1A),
            Color(0xFFFFE07A),
          ],
          transform: GradientRotation(t * 1.5),
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.1)),
    );
    for (var i = 0; i < 12; i++) {
      final p = (t * (0.4 + _rand(i, 1) * 0.3) + _rand(i, 2)) % 1;
      final a = -math.pi / 2 + (_rand(i, 3) - 0.5) * math.pi * 1.6;
      final pos = c + _dir(a) * r * 1.05 + Offset(0, -r * 0.9 * p);
      canvas.drawCircle(
        pos,
        r * 0.035 * (1 - p) + 0.6,
        Paint()
          ..color = Color.lerp(
            const Color(0xFFFFF2B0),
            const Color(0xFFFF4D1A),
            p,
          )!.withValues(alpha: 1 - p),
      );
    }
  }

  /// A frame of lava running down both sides of the picture, fire trying
  /// to catch round it, great obsidian horns sweeping out and curling in
  /// with white-hot tips, an obsidian tail curling out from behind, smoke
  /// and embers rising. No glow spills out past it.
  void _demon(Canvas canvas, Offset c, double r, double t) {
    if (!front) {
      _smoke(canvas, c, r, t);
      _obsidianTail(canvas, c, r, t);
      // A crown of fire that never goes out, then the flames trying to
      // catch, behind the picture.
      _blaze(canvas, c, r, t);
      _hellfire(canvas, c, r, t, back: true);
      for (final side in const [-1.0, 1.0]) {
        _obsidianHorn(canvas, c, r, t, side);
      }
      return;
    }
    _lavaFrame(canvas, c, r, t);
    // Short flames licking up over the rim, and embers.
    _hellfire(canvas, c, r, t, back: false);
    if (_lite) return;
    for (var i = 0; i < 16; i++) {
      final life = (t * (0.3 + _rand(i, 120) * 0.25) + _rand(i, 121)) % 1.0;
      final x =
          c.dx +
          (_rand(i, 122) - 0.5) * r * 2.4 +
          math.sin(t * 2 + i) * r * 0.06;
      final y = c.dy + r * (0.6 - life * 2.4);
      canvas.drawCircle(
        Offset(x, y),
        r * (0.012 + 0.018 * _rand(i, 123)) * (1 - life * 0.6),
        Paint()
          ..color = Color.lerp(
            const Color(0xFFFFF0B0),
            const Color(0xFFFF5A1F),
            life,
          )!.withValues(alpha: math.sin(life * math.pi)),
      );
    }
  }

  /// Big flames always burning out from the upper half of the ring,
  /// tallest over the top, each leaping and swaying on its own.
  void _blaze(Canvas canvas, Offset c, double r, double t) {
    final count = _lite ? 6 : 12;
    const colors = [
      Color(0xFF8A0A03),
      Color(0xFFD9381F),
      Color(0xFFFF7A1A),
      Color(0xFFFFD27A),
    ];
    if (!_lite) {
      canvas.drawCircle(
        c.translate(0, -r * 0.35),
        r * 1.55,
        Paint()
          ..shader =
              RadialGradient(
                colors: const [Color(0x55FF4A10), Color(0x00FF4A10)],
              ).createShader(
                Rect.fromCircle(
                  center: c.translate(0, -r * 0.35),
                  radius: r * 1.55,
                ),
              ),
      );
    }
    for (var k = 0; k < count; k++) {
      final u = k / (count - 1);
      final a = -math.pi + 0.62 + (math.pi - 1.24) * u;
      final high = -math.sin(a); // 1 at the top
      final base = c + _dir(a) * r * 0.96;
      final size = r * (0.18 + 0.12 * high);
      canvas.save();
      canvas.translate(base.dx, base.dy);
      canvas.rotate((a + math.pi / 2) * 0.6);
      for (var layer = 0; layer < 4; layer++) {
        final scale = 1 - layer * 0.22;
        final sway =
            (math.sin(t * (5 + layer * 1.7) + k * 2.1) +
                0.5 * math.sin(t * 11.3 + k * 3 + layer)) *
            size *
            0.12;
        final lick =
            1 +
            0.25 * math.sin(t * (8 + layer * 2.3) + k * 1.7) +
            0.1 * math.sin(t * 17 + k);
        final hgt = size * (1.5 + 1.1 * high) * scale * lick;
        final wid = size * 0.95 * scale;
        canvas.drawPath(
          Path()
            ..moveTo(-wid, 0)
            ..cubicTo(
              -wid * 1.25,
              -hgt * 0.35,
              -wid * 0.2 + sway * 0.6,
              -hgt * 0.7,
              sway,
              -hgt,
            )
            ..cubicTo(
              wid * 0.3 + sway * 0.6,
              -hgt * 0.65,
              wid * 1.25,
              -hgt * 0.35,
              wid,
              0,
            )
            ..close(),
          Paint()..color = colors[layer],
        );
      }
      canvas.restore();
    }
  }

  /// Fire trying to catch: round the top of the frame little flames keep
  /// flaring up, sputtering and dying back before they take hold, sparks
  /// spitting off as they go. [back] draws the ones behind the picture;
  /// otherwise the small ones licking at the rim.
  void _hellfire(
    Canvas canvas,
    Offset c,
    double r,
    double t, {
    required bool back,
  }) {
    final count = _lite ? 7 : 13;
    for (var k = 0; k < count; k++) {
      final u = k / (count - 1);
      // From just below the left side, over the top, to the right.
      final a = -math.pi - 0.2 + (math.pi + 0.4) * u;
      final high = 0.5 + 0.5 * -math.sin(a); // 1 at the top
      // Each flame keeps its own rhythm: a quick flare, a sputter, then
      // it dies back to an ember before trying again.
      final period = 1.3 + _rand(k, 130) * 1.4;
      final p = ((t + _rand(k, 131) * period) % period) / period;
      final flare = p < 0.22
          ? Curves.easeOut.transform(p / 0.22)
          : p < 0.5
          ? 1 - 0.5 * (p - 0.22) / 0.28
          : 0.5 * (1 - (p - 0.5) / 0.5);
      final sputter = 0.7 + 0.3 * math.sin(t * 23 + k * 3.1);
      final strength = (flare * sputter).clamp(0.0, 1.0);
      final base = c + _dir(a) * r * (back ? 1.1 : 1.17);
      final rise = Offset(_dir(a).dx * 0.3, -1);
      final len =
          r * 0.05 +
          r * (back ? 0.16 + 0.3 * high : 0.06 + 0.1 * high) * strength;
      final width = r * (back ? 0.16 : 0.1) * (0.65 + 0.35 * strength);
      _fireTongue(canvas, base, rise, len, width, t * 1.6 + k * 0.7);
      if (back && !_lite && p > 0.25 && p < 0.75) {
        // A spark spat off as the flame gutters.
        final q = (p - 0.25) / 0.5;
        final spark =
            base +
            Offset(math.sin(k * 1.7) * r * 0.12 * q, -r * (0.12 + 0.45 * q));
        canvas.drawCircle(
          spark,
          r * 0.018 * (1 - q),
          Paint()
            ..color = Color.lerp(
              const Color(0xFFFFF0B0),
              const Color(0xFFFF6A1F),
              q,
            )!.withValues(alpha: 1 - q),
        );
      }
    }
  }

  void _fireTongue(
    Canvas canvas,
    Offset base,
    Offset dir,
    double length,
    double width,
    double t,
  ) {
    final d = dir / dir.distance;
    final n = Offset(-d.dy, d.dx);
    Path tongue(double len, double w, double phase) {
      final wave = math.sin(t * 5 + phase) * len * 0.16;
      final tip = base + d * len + n * wave;
      final c1 = base + d * (len * 0.35) + n * (w * 0.75);
      final c2 = base + d * (len * 0.75) + n * (w * 0.3 + wave * 0.6);
      final c3 = base + d * (len * 0.75) - n * (w * 0.25 - wave * 0.6);
      final c4 = base + d * (len * 0.35) - n * (w * 0.7);
      return Path()
        ..moveTo((base + n * w * 0.5).dx, (base + n * w * 0.5).dy)
        ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, tip.dx, tip.dy)
        ..cubicTo(
          c3.dx,
          c3.dy,
          c4.dx,
          c4.dy,
          (base - n * w * 0.5).dx,
          (base - n * w * 0.5).dy,
        )
        ..close();
    }

    canvas.drawPath(
      tongue(length, width, 0),
      Paint()
        ..color = const Color(0xFFB3121B).withValues(alpha: 0.9)
        ..maskFilter = _blur(width * 0.12),
    );
    canvas.drawPath(
      tongue(length * 0.8, width * 0.72, 0.6),
      Paint()..color = const Color(0xFFFF4A1A),
    );
    canvas.drawPath(
      tongue(length * 0.58, width * 0.48, 1.1),
      Paint()..color = const Color(0xFFFFA43A),
    );
    canvas.drawPath(
      tongue(length * 0.32, width * 0.26, 1.7),
      Paint()..color = const Color(0xFFFFF2C2),
    );
  }

  /// Red-black smoke rolling up off the fire and thinning out.
  void _smoke(Canvas canvas, Offset c, double r, double t) {
    final puffs = _lite ? 5 : 11;
    for (var i = 0; i < puffs; i++) {
      final life = (t * (0.18 + _rand(i, 125) * 0.1) + _rand(i, 126)) % 1.0;
      final x =
          c.dx +
          (_rand(i, 127) - 0.5) * r * 1.8 +
          math.sin(t * 0.8 + i) * r * 0.15 * life;
      final y = c.dy - r * (0.9 + life * 1.5);
      canvas.drawCircle(
        Offset(x, y),
        r * (0.16 + 0.3 * life),
        Paint()
          ..color = Color.lerp(
            const Color(0xFF7A1A14),
            const Color(0xFF241414),
            life,
          )!.withValues(alpha: 0.45 * math.sin(life * math.pi))
          ..maskFilter = _blur(r * 0.12),
      );
    }
  }

  /// A great obsidian horn rising from the top of the frame: out and up
  /// from the base, then curling in, ridged, lit orange by the fire on its
  /// inner side, its tip glowing white-hot.
  void _obsidianHorn(Canvas canvas, Offset c, double r, double t, double side) {
    final base = c + _dir(-math.pi / 2 + side * 0.62) * r * 1.02;
    final sway = math.sin(t * 1.4) * r * 0.01;
    final pts = [
      base,
      base + Offset(side * r * 0.3, -r * 0.2),
      base + Offset(side * r * 0.52, -r * 0.55 + sway),
      base + Offset(side * r * 0.42, -r * 0.92 + sway),
      base + Offset(side * r * 0.16, -r * 1.06 + sway),
    ];
    const widths = [0.2, 0.17, 0.12, 0.065, 0.006];
    // Smooth the spine and taper along it.
    final spine = <Offset>[];
    final ws = <double>[];
    for (var i = 0; i < pts.length - 1; i++) {
      for (var k = 0; k < 8; k++) {
        final q = k / 8;
        final p0 = pts[math.max(0, i - 1)];
        final p1 = pts[i];
        final p2 = pts[i + 1];
        final p3 = pts[math.min(pts.length - 1, i + 2)];
        final q2 = q * q;
        final q3 = q2 * q;
        spine.add(
          (p1 * 2 +
                  (p2 - p0) * q +
                  (p0 * 2 - p1 * 5 + p2 * 4 - p3) * q2 +
                  (p1 * 3 - p0 - p2 * 3 + p3) * q3) *
              0.5,
        );
        ws.add(r * (widths[i] + (widths[i + 1] - widths[i]) * q));
      }
    }
    spine.add(pts.last);
    ws.add(r * widths.last);
    final normals = <Offset>[
      for (var i = 0; i < spine.length; i++)
        () {
          final d =
              spine[math.min(spine.length - 1, i + 1)] -
              spine[math.max(0, i - 1)];
          final l = d.distance;
          return l == 0 ? const Offset(1, 0) : Offset(-d.dy / l, d.dx / l);
        }(),
    ];
    final left = [
      for (var i = 0; i < spine.length; i++) spine[i] + normals[i] * ws[i],
    ];
    final right = [
      for (var i = 0; i < spine.length; i++) spine[i] - normals[i] * ws[i],
    ];
    final horn = Path()..addPolygon([...left, ...right.reversed], true);
    final box = horn.getBounds();
    canvas.drawPath(
      horn,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: const [
            Color(0xFF3A2620),
            Color(0xFF14090A),
            Color(0xFF2A0E08),
            Color(0xFFFF7A2A),
            Color(0xFFFFF0C0),
          ],
          stops: const [0.0, 0.45, 0.78, 0.94, 1.0],
        ).createShader(box),
    );
    // The inner edge, lit by the fire.
    final inner = side > 0 ? right : left;
    final rim = Path()..moveTo(inner.first.dx, inner.first.dy);
    for (final p in inner.skip(1)) {
      rim.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.02
        ..color = const Color(
          0xFFFF7A2A,
        ).withValues(alpha: 0.75 + 0.2 * math.sin(t * 4))
        ..maskFilter = _blur(r * 0.01),
    );
    if (_lite) return;
    // Ridges round it.
    final ridge = Paint()
      ..strokeWidth = r * 0.012
      ..color = Colors.black.withValues(alpha: 0.55);
    for (var i = 3; i < spine.length - 6; i += 3) {
      canvas.drawLine(left[i], right[i], ridge);
    }
    // The tip glowing.
    canvas.drawCircle(
      spine.last,
      r * 0.06,
      Paint()
        ..color = const Color(
          0xFFFFC04A,
        ).withValues(alpha: 0.6 + 0.3 * math.sin(t * 5))
        ..maskFilter = _blur(r * 0.05),
    );
  }

  /// The frame as a channel of lava, like a volcano's: molten, brightest
  /// down the middle, pouring from the top down both sides of the picture
  /// to meet at the bottom (it runs, it never spins). Only the lava moves:
  /// surges of heat and currents stream down it with fire riding the flow,
  /// past shelves of cooled magma that sit still on the banks, still hot
  /// enough to glow at their cracks. Rocky banks either side, and bubbles
  /// welling up and popping.
  void _lavaFrame(Canvas canvas, Offset c, double r, double t) {
    final outerR = r * 1.22;
    final innerR = r * 0.95;
    final mid = (outerR + innerR) / 2;
    final half = (outerR - innerR) / 2;
    final rect = Rect.fromCircle(center: c, radius: outerR);
    final band = Path()
      ..addOval(rect)
      ..addOval(Rect.fromCircle(center: c, radius: innerR))
      ..fillType = PathFillType.evenOdd;
    final pulse = 0.85 + 0.15 * math.sin(t * 3.1);
    final k0 = innerR / outerR;
    canvas.drawPath(
      band,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF8A1A0E),
            const Color(0xFFE8501A),
            Color.lerp(
              const Color(0xFFFFC04A),
              const Color(0xFFFFF0B0),
              0.4 * pulse,
            )!,
            const Color(0xFFE8501A),
            const Color(0xFF8A1A0E),
          ],
          stops: [
            k0,
            k0 + (1 - k0) * 0.25,
            k0 + (1 - k0) * 0.5,
            k0 + (1 - k0) * 0.78,
            1,
          ],
        ).createShader(rect),
    );

    canvas.save();
    canvas.clipPath(band);
    // Everything in the flow runs from the top (p = 0) down one side or
    // the other to the bottom (p = 1), fading in as it pours over the top
    // and out as it pools at the bottom.
    Offset along(double p, double side, double rr) =>
        c + _dir(-math.pi / 2 + side * p * math.pi) * rr;
    double fade(double p) =>
        Curves.easeOut.transform((p / 0.1).clamp(0.0, 1.0)) *
        (1 - Curves.easeIn.transform(((p - 0.88) / 0.12).clamp(0.0, 1.0)));
    // The direction the lava runs at [p] on [side].
    Offset downstream(double p, double side) {
      final a = -math.pi / 2 + side * p * math.pi;
      return Offset(-math.sin(a), math.cos(a)) * side;
    }

    // Surges of heat carried down by the flow: the whole river visibly
    // runs, brightening and dimming as each surge passes.
    final segments = _lite ? 28 : 56;
    final surge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeWidth = half * 1.5
      ..maskFilter = _blur(half * 0.12);
    final channel = Rect.fromCircle(center: c, radius: mid);
    for (final side in const [-1.0, 1.0]) {
      for (var k = 0; k < segments; k++) {
        final p = (k + 0.5) / segments;
        final w1 = math.sin((p * 5 - t * 0.8) * 2 * math.pi);
        final w2 = math.sin((p * 9 - t * 1.3) * 2 * math.pi + side * 1.3);
        final heat = (0.5 + 0.38 * w1 + 0.22 * w2).clamp(0.0, 1.0);
        surge.color =
            (heat < 0.5
                    ? Color.lerp(
                        const Color(0xFFA8160E),
                        const Color(0xFFFF6A1F),
                        heat * 2,
                      )!
                    : Color.lerp(
                        const Color(0xFFFF6A1F),
                        const Color(0xFFFFF0B0),
                        heat * 2 - 1,
                      )!)
                .withValues(alpha: 0.8 * fade(p));
        canvas.drawArc(
          channel,
          -math.pi / 2 + side * (k / segments) * math.pi,
          side * math.pi / segments * 1.08,
          false,
          surge,
        );
      }
    }
    // Currents streaming down: fastest down the middle.
    final streaks = _lite ? 8 : 22;
    for (var i = 0; i < streaks; i++) {
      final side = i.isEven ? 1.0 : -1.0;
      final lane = (_rand(i, 140) - 0.5) * 1.6;
      final rr = mid + lane * half * 0.85;
      final speed = (0.1 + _rand(i, 141) * 0.12) * (1 - lane.abs() * 0.45);
      final p0 = (_rand(i, 142) + t * speed) % 1.0;
      final span = 0.08 + _rand(i, 143) * 0.14;
      final streak = Path();
      for (var j = 0; j <= 10; j++) {
        final p = p0 + span * j / 10;
        if (p > 1) break;
        final wobble = math.sin(j * 0.9 + t * 3 + i) * half * 0.08;
        final at = along(p, side, rr + wobble);
        j == 0 ? streak.moveTo(at.dx, at.dy) : streak.lineTo(at.dx, at.dy);
      }
      canvas.drawPath(
        streak,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = r * (0.01 + 0.014 * _rand(i, 144))
          ..color = Color.lerp(
            const Color(0xFFFFE07A),
            Colors.white,
            _rand(i, 145) * 0.5,
          )!.withValues(alpha: (0.35 + 0.45 * _rand(i, 146)) * fade(p0)),
      );
    }
    // Fire riding the flow: flames carried downstream, flickering, their
    // tails streaming out behind them.
    final flames = _lite ? 5 : 12;
    for (var i = 0; i < flames; i++) {
      final side = i.isEven ? 1.0 : -1.0;
      final lane = (_rand(i, 170) - 0.5) * 0.9;
      final speed = 0.09 + _rand(i, 171) * 0.08;
      final p = (_rand(i, 172) + t * speed) % 1.0;
      final o = fade(p);
      if (o < 0.05) continue;
      final flicker = 0.75 + 0.25 * math.sin(t * 11 + i * 2.3);
      _fireTongue(
        canvas,
        along(p, side, mid + lane * half),
        -downstream(p, side),
        half * (2.6 + 1.4 * _rand(i, 173)) * o * flicker,
        half * (1.1 + 0.4 * _rand(i, 174)) * o,
        t * 1.8 + i * 0.9,
      );
    }
    // Cooled magma: shelves of rock along the banks that stay put while
    // the lava runs past, still hot enough to glow at their cracks.
    final shelves = _lite ? 6 : 12;
    for (var i = 0; i < shelves; i++) {
      final side = i.isEven ? 1.0 : -1.0;
      final p0 = 0.04 + (i ~/ 2) / (shelves / 2) * 0.86 + _rand(i, 150) * 0.05;
      final span = 0.06 + _rand(i, 151) * 0.06;
      // Each grows from one bank partway across, leaving the middle open.
      final outer = _rand(i, 152) > 0.5;
      final bank = outer ? mid + half * 1.1 : mid - half * 1.1;
      final reach = half * (0.7 + 0.45 * _rand(i, 155));
      final edge = outer ? bank - reach : bank + reach;
      final pts = <Offset>[];
      const steps = 6;
      for (var k = 0; k <= steps; k++) {
        pts.add(along(p0 + span * k / steps, side, bank));
      }
      for (var k = steps; k >= 0; k--) {
        final q = k / steps;
        // Rounded at the ends, jagged along the lava side.
        final round = math.sin(q * math.pi);
        final jag = (_rand(i * 13 + k, 153) - 0.5) * half * 0.25;
        pts.add(
          along(
            p0 + span * q,
            side,
            bank + (edge - bank) * (0.35 + 0.65 * round) + jag,
          ),
        );
      }
      final shelf = Path()..addPolygon(pts, true);
      final heat = 0.7 + 0.3 * math.sin(t * 1.4 + i * 1.9);
      // The glow where lava meets rock.
      canvas.drawPath(
        shelf,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.04
          ..color = const Color(0xFFFF5A1F).withValues(alpha: 0.6 * heat)
          ..maskFilter = _blur(r * 0.02),
      );
      canvas.drawPath(
        shelf,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: const [
              Color(0xFF4A2A22),
              Color(0xFF22120E),
              Color(0xFF120806),
            ],
          ).createShader(shelf.getBounds()),
      );
      canvas.drawPath(
        shelf,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.012
          ..color = const Color(0xFFFF7A2A).withValues(alpha: 0.8 * heat),
      );
      // Cracks across it, glowing from the heat inside.
      final crack = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = r * 0.009
        ..color = const Color(0xFFFFB03A).withValues(alpha: 0.9 * heat);
      for (var k = 0; k < 2; k++) {
        final pm = p0 + span * (0.3 + 0.4 * k);
        final from = along(pm, side, bank + (edge - bank) * 0.15);
        final bend = along(
          pm + span * (_rand(i * 3 + k, 156) - 0.5) * 0.3,
          side,
          bank + (edge - bank) * 0.5,
        );
        final to = along(
          pm + span * (_rand(i * 3 + k, 157) - 0.5) * 0.4,
          side,
          bank + (edge - bank) * 0.8,
        );
        canvas.drawPath(
          Path()
            ..moveTo(from.dx, from.dy)
            ..lineTo(bend.dx, bend.dy)
            ..lineTo(to.dx, to.dy),
          crack,
        );
      }
    }
    canvas.restore();

    // Rocky banks on both sides, lit by the lava.
    for (final (edge, out) in [(outerR, 1.0), (innerR, -1.0)]) {
      final bank = <Offset>[];
      const n = 64;
      for (var k = 0; k <= n; k++) {
        final a = k / n * 2 * math.pi;
        bank.add(
          c +
              _dir(a) *
                  (edge -
                      out *
                          half *
                          (0.06 + 0.1 * _rand(k, out > 0 ? 160 : 161))),
        );
      }
      for (var k = n; k >= 0; k--) {
        final a = k / n * 2 * math.pi;
        bank.add(
          c +
              _dir(a) *
                  (edge +
                      out *
                          half *
                          (0.2 + 0.14 * _rand(k, out > 0 ? 162 : 163))),
        );
      }
      final path = Path()..addPolygon(bank, true);
      canvas.drawPath(path, Paint()..color = const Color(0xFF1E100C));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.012
          ..color = const Color(0xFFFF7A2A).withValues(alpha: 0.5 * pulse),
      );
    }

    if (_lite) return;
    // Bubbles welling up in the flow and popping.
    for (var i = 0; i < 8; i++) {
      final life = (t * (0.6 + _rand(i, 105) * 0.5) + _rand(i, 106)) % 1;
      // Each wells up in its own spot: the flow carries crust, not bubbles.
      final a =
          _rand(i, 107) * 2 * math.pi +
          (t * (0.6 + _rand(i, 105) * 0.5) + _rand(i, 106)).floor() * 2.1;
      final p = c + _dir(a) * (mid + (_rand(i, 108) - 0.5) * half);
      if (life < 0.8) {
        final s = r * 0.04 * Curves.easeOut.transform(life / 0.8);
        canvas.drawCircle(p, s, Paint()..color = const Color(0xFFFFE07A));
        canvas.drawCircle(
          p.translate(-s * 0.3, -s * 0.3),
          s * 0.35,
          Paint()..color = Colors.white.withValues(alpha: 0.8),
        );
      } else {
        final k = (life - 0.8) / 0.2;
        canvas.drawCircle(
          p,
          r * (0.04 + 0.045 * k),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.012
            ..color = const Color(0xFFFFD25A).withValues(alpha: 1 - k),
        );
      }
    }
  }

  /// An obsidian tail curling out from behind the frame, molten cracks
  /// glowing along it, ending in a barb with a white-hot edge.
  void _obsidianTail(Canvas canvas, Offset c, double r, double t) {
    final sway = math.sin(t * 1.3);
    final pts = [
      c + _dir(0.95) * r * 1.12,
      c + Offset(r * 1.42, r * 0.62 + sway * r * 0.03),
      c + Offset(r * 1.62, r * 0.12 + sway * r * 0.06),
      c + Offset(r * 1.5, -r * 0.32 + sway * r * 0.1),
      c + Offset(r * 1.3, -r * 0.52 + sway * r * 0.14),
    ];
    const widths = [0.1, 0.085, 0.065, 0.045, 0.03];
    final spine = <Offset>[];
    final ws = <double>[];
    for (var i = 0; i < pts.length - 1; i++) {
      for (var k = 0; k < 8; k++) {
        final q = k / 8;
        final p0 = pts[math.max(0, i - 1)];
        final p1 = pts[i];
        final p2 = pts[i + 1];
        final p3 = pts[math.min(pts.length - 1, i + 2)];
        final q2 = q * q;
        final q3 = q2 * q;
        spine.add(
          (p1 * 2 +
                  (p2 - p0) * q +
                  (p0 * 2 - p1 * 5 + p2 * 4 - p3) * q2 +
                  (p1 * 3 - p0 - p2 * 3 + p3) * q3) *
              0.5,
        );
        ws.add(r * (widths[i] + (widths[i + 1] - widths[i]) * q));
      }
    }
    spine.add(pts.last);
    ws.add(r * widths.last);
    final normals = [
      for (var i = 0; i < spine.length; i++)
        () {
          final d =
              spine[math.min(spine.length - 1, i + 1)] -
              spine[math.max(0, i - 1)];
          final l = d.distance;
          return l == 0 ? const Offset(1, 0) : Offset(-d.dy / l, d.dx / l);
        }(),
    ];
    final left = [
      for (var i = 0; i < spine.length; i++) spine[i] + normals[i] * ws[i],
    ];
    final right = [
      for (var i = 0; i < spine.length; i++) spine[i] - normals[i] * ws[i],
    ];
    final tail = Path()..addPolygon([...left, ...right.reversed], true);
    canvas.drawPath(
      tail,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A2620), Color(0xFF14090A), Color(0xFF241210)],
        ).createShader(tail.getBounds()),
    );
    if (!_lite) {
      // Molten cracks glowing through it.
      final crack = Paint()
        ..strokeWidth = r * 0.012
        ..strokeCap = StrokeCap.round
        ..color = const Color(
          0xFFFF7A2A,
        ).withValues(alpha: 0.7 + 0.25 * math.sin(t * 4));
      for (var i = 4; i < spine.length - 3; i += 4) {
        canvas.drawLine(
          spine[i] + normals[i] * ws[i] * 0.7,
          spine[i + 1] - normals[i] * ws[i] * 0.5,
          crack,
        );
      }
    }
    // The barb: a curved blade, edged white-hot.
    final tip = spine.last;
    final d = spine.last - spine[spine.length - 4];
    final td = d / (d.distance + 1e-6);
    final tn = Offset(-td.dy, td.dx);
    final s = r * 0.16;
    final barb = Path()
      ..moveTo((tip - tn * s * 0.35).dx, (tip - tn * s * 0.35).dy)
      ..quadraticBezierTo(
        (tip + td * s * 0.6 - tn * s * 0.8).dx,
        (tip + td * s * 0.6 - tn * s * 0.8).dy,
        (tip + td * s * 1.4 + tn * s * 0.1).dx,
        (tip + td * s * 1.4 + tn * s * 0.1).dy,
      )
      ..quadraticBezierTo(
        (tip + td * s * 0.5 + tn * s * 0.6).dx,
        (tip + td * s * 0.5 + tn * s * 0.6).dy,
        (tip + tn * s * 0.35).dx,
        (tip + tn * s * 0.35).dy,
      )
      ..close();
    canvas.drawPath(barb, Paint()..color = const Color(0xFF14090A));
    canvas.drawPath(
      barb,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.018
        ..color = const Color(0xFFFFB04A).withValues(alpha: 0.85)
        ..maskFilter = _blur(r * 0.01),
    );
  }
}
