part of 'utopia_world.dart';

/// How long the dragon takes to fly between the sky and a frame.
const _flight = 2.5;

/// The Dojo: a samurai castle, shadow fighters sparring, bamboo, lanterns, maple leaves and the dragon.
extension _Dojo on _ScenePainter {
  void _dojoBiome(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;
    // Low mist over everything far away.
    _cloud(canvas, size, t, y: h * 0.42, scale: 1.3, speed: 4, offset: 0.1);
    // The dragon circles the castle high in the sky, behind the hills,
    // unless it's flying free or has come down to circle a frame.
    final roaming = _dragonRoaming(t);
    if (!roaming) _dojoDragon(canvas, size, t, roaming: false);
    _cloud(canvas, size, t, y: h * 0.26, scale: 0.8, speed: 6, offset: 0.55);

    // Three ink-wash mountain ranges, darker as they come forward.
    const bases = [0.64, 0.74, 0.86];
    const heights = [0.16, 0.12, 0.07];
    for (var i = 0; i < 3; i++) {
      final base = h * bases[i];
      final ridge = _ridge(
        w,
        base,
        h * heights[i],
        seed: 70 + i * 13,
        sharp: i < 2,
      );
      final pair = style.layers[i];
      canvas.drawPath(
        Path()..addPolygon([...ridge, Offset(w, h), Offset(0, h)], true),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, base - h * heights[i]),
            Offset(0, base + h * 0.12),
            [pair.$1, pair.$2],
          ),
      );
      if (i == 0) _castleGrounds(canvas, size, t);
    }

    _bamboo(canvas, size, t);
    _hangingLanterns(canvas, size, t);
    _mapleLeaves(canvas, size, t, far: true);
    _dojoFloor(canvas, size, t);
    paintShadowDuel(
      canvas,
      w * 0.52,
      h * 0.905,
      h * 0.15,
      t,
      ink: const Color(0xFF0A0503),
      rim: style.sparkles[1],
      sash: style.glow,
    );
    _mapleLeaves(canvas, size, t, far: false);
    _embers(canvas, size, t);
    if (roaming) _dojoDragon(canvas, size, t, roaming: true);
  }

  /// The castle on the far ridge, standing against the setting sun: the
  /// keep, a turret down its wall, and a pagoda further off.
  void _castleGrounds(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;
    final wall = _ColorMath.darken(style.rock[2], 0.02);
    final roof = _ColorMath.darken(style.rock[2], 0.07);
    final stone = style.rock[1];
    final light = style.sparkles[2];
    final rim = style.sparkles[1];
    _pagoda(canvas, Offset(w * 0.92, h * 0.645), w * 0.16, t);
    // The outer wall, roofed, running from the turret to the keep.
    final wallTop = h * 0.648;
    canvas.drawRect(
      Rect.fromLTRB(w * 0.27, wallTop, w * 0.5, wallTop + h * 0.03),
      Paint()..color = stone,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.265, wallTop + h * 0.002)
        ..lineTo(w * 0.505, wallTop + h * 0.002)
        ..lineTo(w * 0.5, wallTop - h * 0.008)
        ..lineTo(w * 0.27, wallTop - h * 0.008)
        ..close(),
      Paint()..color = roof,
    );
    canvas.drawLine(
      Offset(w * 0.27, wallTop - h * 0.008),
      Offset(w * 0.5, wallTop - h * 0.008),
      Paint()
        ..color = rim
        ..strokeWidth = 1,
    );
    paintTurret(
      canvas,
      Offset(w * 0.28, h * 0.672),
      w * 0.13,
      t,
      wall: wall,
      roof: roof,
      stone: stone,
      light: light,
      rim: rim,
    );
    paintCastle(
      canvas,
      Offset(w * 0.63, h * 0.672),
      w * 0.44,
      t,
      wall: wall,
      roof: roof,
      stone: stone,
      light: light,
      rim: rim,
    );
  }

  /// The dojo's wooden floor in the foreground, where the fighters spar:
  /// planks running away from you, a warm pool of light under the duel,
  /// banners at the side.
  void _dojoFloor(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;
    final top = h * 0.895;
    final front = h * 0.935;
    // Light from the sun behind, picking the fighters out of the dusk.
    canvas.drawCircle(
      Offset(w * 0.52, h * 0.83),
      w * 0.5,
      Paint()
        ..shader = ui.Gradient.radial(Offset(w * 0.52, h * 0.83), w * 0.5, [
          style.sparkles[0].withValues(alpha: 0.32),
          style.sparkles[0].withValues(alpha: 0),
        ]),
    );
    final deck = Path()
      ..moveTo(w * 0.04, top)
      ..lineTo(w * 1.02, top)
      ..lineTo(w * 1.02, front)
      ..lineTo(-w * 0.02, front)
      ..close();
    canvas.drawPath(
      deck,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, top), Offset(0, front), [
          const Color(0xFF5A3018),
          const Color(0xFF3A1E0E),
        ]),
    );
    // Planks, converging toward the castle.
    final seam = Paint()
      ..color = const Color(0xFF241208)
      ..strokeWidth = 1;
    for (var k = 0; k <= 14; k++) {
      final x0 = -w * 0.02 + w * 1.04 * k / 14;
      final x1 = w * 0.52 + (x0 - w * 0.52) * 0.86;
      canvas.drawLine(Offset(x1, top), Offset(x0, front), seam);
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.52, (top + front) / 2),
        width: w * 0.62,
        height: (front - top) * 0.9,
      ),
      Paint()
        ..color = style.sparkles[0].withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    // The front beam and the dark beneath it.
    canvas.drawRect(
      Rect.fromLTRB(-2, front, w + 2, front + h * 0.012),
      Paint()..color = const Color(0xFF2A160A),
    );
    canvas.drawLine(
      Offset(0, front),
      Offset(w, front),
      Paint()
        ..color = style.sparkles[1].withValues(alpha: 0.55)
        ..strokeWidth = 1,
    );
    canvas.drawRect(
      Rect.fromLTRB(-2, front + h * 0.012, w + 2, h + 2),
      Paint()..color = const Color(0xFF120804),
    );
    paintBanner(
      canvas,
      Offset(w * 0.9, top + h * 0.004),
      h * 0.13,
      t,
      style.glow,
      const Color(0xFFFFE2B0),
      const Color(0xFF120804),
    );
    paintBanner(
      canvas,
      Offset(w * 0.96, top + h * 0.004),
      h * 0.11,
      t + 0.7,
      _ColorMath.darken(style.glow, 0.12),
      const Color(0xFFFFE2B0),
      const Color(0xFF120804),
    );
  }

  /// Maple leaves drifting down through the dusk, turning as they fall.
  void _mapleLeaves(Canvas canvas, Size size, double t, {required bool far}) {
    final count = far ? 8 : 6;
    for (var i = 0; i < count; i++) {
      final seed = i + (far ? 0 : 50);
      final speed = (far ? 0.035 : 0.06) + _rand(seed, 160) * 0.03;
      final life = (t * speed + _rand(seed, 161)) % 1.0;
      final x =
          (_rand(seed, 162) * size.width * 1.2 - size.width * 0.1) +
          life * size.width * 0.25 +
          math.sin(t * 1.3 + seed) * 14;
      final y = -20 + life * (size.height + 40);
      final s = (far ? 4.5 : 8.0) + _rand(seed, 163) * 3;
      final color = [
        style.glow,
        style.sparkles[1],
        style.sparkles[0],
      ][seed % 3].withValues(alpha: far ? 0.55 : 0.9);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * (1.5 + _rand(seed, 164)) + seed);
      canvas.scale(1, 0.55 + 0.45 * math.cos(t * 2.2 + seed));
      final leaf = Path();
      for (var k = 0; k < 10; k++) {
        final a = -math.pi / 2 + k * math.pi / 5;
        final r = k.isEven ? s : s * 0.45;
        final p = Offset(math.cos(a), math.sin(a)) * r;
        k == 0 ? leaf.moveTo(p.dx, p.dy) : leaf.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(leaf..close(), Paint()..color = color);
      canvas.restore();
    }
  }

  /// Whether the dragon is out of the sky: flying free, at a frame, or on
  /// its way back from one.
  bool _dragonRoaming(double t) {
    if (DojoDragon.free.value || DojoDragon.perch != null) return true;
    if (DojoDragon.lastPerch == null) return false;
    final back = t - DojoDragon.perchChangedAt;
    return back < _flight;
  }

  /// Where the dragon's head is at [time].
  Offset _dragonAt(Size size, double time) {
    final w = size.width;
    final h = size.height;
    final base = DojoDragon.free.value
        // Free: it roams the whole screen.
        ? Offset(
            w * (0.5 + 0.62 * math.sin(time * 0.16)),
            h * (0.5 + 0.36 * math.sin(time * 0.23 + 0.6)),
          )
        // A long loop round the castle, turning off the edges of the sky.
        : Offset(
            w * (0.5 + 0.6 * math.cos(time * 0.12)),
            h * (0.23 + 0.08 * math.sin(time * 0.12)),
          );
    final perch = DojoDragon.lastPerch;
    if (perch == null) return base;
    final since = ((time - DojoDragon.perchChangedAt) / _flight).clamp(
      0.0,
      1.0,
    );
    final k = Curves.easeInOutCubic.transform(
      DojoDragon.perch != null ? since : 1 - since,
    );
    if (k <= 0) return base;
    final (globalCentre, r) = perch;
    final centre = globalCentre - (origin?.call() ?? Offset.zero);
    final orbit =
        centre +
        Offset(math.cos(time * 0.55), math.sin(time * 0.55) * 0.8) * (r * 2);
    return Offset.lerp(base, orbit, k)!;
  }

  void _dojoDragon(
    Canvas canvas,
    Size size,
    double t, {
    required bool roaming,
  }) {
    final free = DojoDragon.free.value;
    final at = _dragonAt(size, t);
    final v = _dragonAt(size, t + 0.05) - at;
    final left = v.dx < 0;
    // The nose tips the way it's heading, within reason.
    final pitch = math.atan2(v.dy, v.dx.abs()).clamp(-0.4, 0.4);
    if (free) {
      // Set free, it glows with the heat it carries.
      canvas.drawCircle(
        at,
        size.width * 0.2,
        Paint()
          ..color = const Color(0x40FF6A2A)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.08),
      );
    }
    // Circling the castle it breathes fire every so often; set free it's
    // bigger, hotter and breathes far more.
    paintFireDragon(
      canvas,
      at,
      size.width * (roaming ? 0.085 : 0.055),
      t,
      free ? FireDragonColors.blazing : FireDragonColors.crimson,
      facingLeft: left,
      tilt: left ? -pitch : pitch,
      breathEvery: free ? 4.5 : 8,
      fireScale: free ? 1.2 : 0.8,
    );
  }

  /// A three-tier pagoda with upturned eaves and warm windows.
  void _pagoda(Canvas canvas, Offset base, double s, double t) {
    final dark = Paint()..color = style.rock[2];
    final roof = Paint()..color = _ColorMath.darken(style.rock[2], 0.04);
    final light = Paint()
      ..color = style.sparkles[2].withValues(
        alpha: 0.85 + 0.15 * math.sin(t * 3),
      );
    var y = base.dy;
    var width = s * 0.5;
    for (var tier = 0; tier < 3; tier++) {
      final body = width * 0.62;
      final bh = s * (tier == 0 ? 0.16 : 0.12);
      canvas.drawRect(
        Rect.fromLTWH(base.dx - body / 2, y - bh, body, bh),
        dark,
      );
      // Glowing windows.
      for (var k = -1; k <= 1; k++) {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(base.dx + k * body * 0.28, y - bh * 0.5),
            width: body * 0.12,
            height: bh * 0.4,
          ),
          light,
        );
      }
      y -= bh;
      // The roof, its corners curling up.
      final rw = width * 0.62;
      final eave = Path()
        ..moveTo(base.dx - rw, y - s * 0.03)
        ..quadraticBezierTo(
          base.dx - rw * 0.7,
          y + s * 0.01,
          base.dx - rw * 0.45,
          y,
        )
        ..lineTo(base.dx + rw * 0.45, y)
        ..quadraticBezierTo(
          base.dx + rw * 0.7,
          y + s * 0.01,
          base.dx + rw,
          y - s * 0.03,
        )
        ..lineTo(base.dx + rw * 0.3, y - s * 0.07)
        ..lineTo(base.dx - rw * 0.3, y - s * 0.07)
        ..close();
      canvas.drawPath(eave, roof);
      y -= s * 0.07;
      width *= 0.74;
    }
    // The spire, and a pennant in the wind.
    canvas.drawRect(
      Rect.fromLTWH(base.dx - s * 0.01, y - s * 0.12, s * 0.02, s * 0.12),
      dark,
    );
    final flutter = math.sin(t * 4) * s * 0.012;
    canvas.drawPath(
      Path()
        ..moveTo(base.dx + s * 0.01, y - s * 0.12)
        ..quadraticBezierTo(
          base.dx + s * 0.06,
          y - s * 0.11 + flutter,
          base.dx + s * 0.11,
          y - s * 0.1 + flutter * 2,
        )
        ..lineTo(base.dx + s * 0.01, y - s * 0.08)
        ..close(),
      Paint()..color = style.glow,
    );
  }

  /// Bamboo along the left edge, swaying.
  void _bamboo(Canvas canvas, Size size, double t) {
    final h = size.height;
    for (var i = 0; i < 4; i++) {
      final x = size.width * (0.02 + i * 0.045);
      final top = h * (0.42 + _rand(i, 140) * 0.12);
      final sway = math.sin(t * 0.8 + i) * 6;
      final stalkW = 5.0 + _rand(i, 141) * 3;
      final color = _mix(style.foliage[1], style.foliage[2], i / 4);
      final stalk = Path()
        ..moveTo(x, h)
        ..quadraticBezierTo(x + sway * 0.2, (top + h) / 2, x + sway, top)
        ..lineTo(x + sway + stalkW, top)
        ..quadraticBezierTo(
          x + stalkW + sway * 0.2,
          (top + h) / 2,
          x + stalkW,
          h,
        )
        ..close();
      canvas.drawPath(stalk, Paint()..color = color);
      // Nodes.
      final node = Paint()
        ..color = _ColorMath.darken(color, 0.12)
        ..strokeWidth = 1.6;
      for (var y = h - 30.0; y > top; y -= 34) {
        final f = (h - y) / (h - top);
        final nx = x + sway * f * f;
        canvas.drawLine(Offset(nx - 1, y), Offset(nx + stalkW + 1, y), node);
      }
      // Leaves near the top.
      for (var k = 0; k < 3; k++) {
        final ly = top + 10 + k * 22;
        final f = (h - ly) / (h - top);
        final lx = x + sway * f * f + stalkW / 2;
        final dir = k.isEven ? 1.0 : -1.0;
        canvas.save();
        canvas.translate(lx, ly);
        canvas.rotate(dir * (0.5 + math.sin(t * 1.2 + i + k) * 0.08));
        canvas.drawOval(
          Rect.fromLTWH(0, -3, dir * 26, 6),
          Paint()..color = style.foliage[0].withValues(alpha: 0.9),
        );
        canvas.restore();
      }
    }
  }

  /// Red paper lanterns on a string, swaying and glowing.
  void _hangingLanterns(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;
    final a = Offset(-10, h * 0.1);
    final b = Offset(w * 0.6, h * 0.14);
    final sag = h * 0.05;
    Offset along(double u) => Offset(
      a.dx + (b.dx - a.dx) * u,
      a.dy + (b.dy - a.dy) * u + math.sin(u * math.pi) * sag,
    );
    final rope = Path()..moveTo(a.dx, a.dy);
    for (var k = 1; k <= 20; k++) {
      final p = along(k / 20);
      rope.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      rope,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = style.rock[2],
    );
    for (var i = 0; i < 4; i++) {
      final top = along(0.2 + i * 0.22);
      final swing = math.sin(t * 1.3 + i * 1.1) * 0.12;
      final s = 18.0 + (i.isEven ? 3 : 0);
      canvas.save();
      canvas.translate(top.dx, top.dy);
      canvas.rotate(swing);
      final body = Rect.fromCenter(
        center: Offset(0, s * 0.9),
        width: s * 1.1,
        height: s * 1.3,
      );
      canvas.drawOval(
        body.inflate(s * 0.5),
        Paint()
          ..color = style.glow.withValues(
            alpha: 0.18 + 0.06 * math.sin(t * 2 + i),
          )
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.4),
      );
      canvas.drawOval(
        body,
        Paint()
          ..shader = RadialGradient(
            colors: [
              style.sparkles[2],
              style.glow,
              _ColorMath.darken(style.glow, 0.15),
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(body),
      );
      final cap = Paint()..color = style.land[0];
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(0, body.top),
          width: s * 0.55,
          height: s * 0.16,
        ),
        cap,
      );
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(0, body.bottom),
          width: s * 0.55,
          height: s * 0.16,
        ),
        cap,
      );
      canvas.drawLine(
        Offset(0, body.bottom),
        Offset(math.sin(t * 2 + i) * 2, body.bottom + s * 0.5),
        Paint()
          ..color = style.land[0]
          ..strokeWidth = 1.6,
      );
      canvas.restore();
    }
  }

  /// A Chinese dragon, gliding through the clouds every so often.
  /// Embers drifting up from below, flickering.
  void _embers(Canvas canvas, Size size, double t) {
    for (var i = 0; i < 26; i++) {
      final life = (t * (0.05 + _rand(i, 150) * 0.05) + _rand(i, 151)) % 1.0;
      final x = _rand(i, 152) * size.width + math.sin(t * 1.4 + i) * 10;
      final y = size.height * (1.02 - life * 0.75);
      final flicker = 0.5 + 0.5 * math.sin(t * 9 + i * 2);
      canvas.drawCircle(
        Offset(x, y),
        1.2 + _rand(i, 153) * 1.6,
        Paint()
          ..color = style.sparkles[i % 3].withValues(
            alpha: math.sin(life * math.pi) * (0.4 + 0.6 * flicker),
          ),
      );
    }
  }
}
