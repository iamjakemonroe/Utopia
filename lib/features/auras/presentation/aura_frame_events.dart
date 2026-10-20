part of 'aura_frame.dart';

const _partyColors = [
  Color(0xFFFF6FAE),
  Color(0xFFFFD166),
  Color(0xFF6EE7B7),
  Color(0xFF64B5F6),
  Color(0xFFB39DDB),
  Color(0xFFFF8A65),
];

const _stage = [
  Color(0xFF00E5FF),
  Color(0xFF7C8CFF),
  Color(0xFFB44CFF),
  Color(0xFFFF2E9A),
  Color(0xFFC6FF3D),
];

const _paints = [
  Color(0xFFFF5C9C),
  Color(0xFFFF8A3D),
  Color(0xFFFFD447),
  Color(0xFF3DDC97),
  Color(0xFF4DA3FF),
  Color(0xFF9B6BFF),
];

/// The frames that come with something: the Birthday frame, the event frames (Snow Globe, Jack's Lantern), Encore and Chip Maestro's.
extension _EventFrames on AuraPainter {
  /// The Birthday frame (only ever worn on the player's birthday): a ring of
  /// party ribbon in every color turning round the picture, a striped party
  /// hat tipped on the rim, balloons bobbing up behind, a little cake with
  /// its candle at the bottom, and confetti bursting off the ring every few
  /// seconds.
  void _birthday(Canvas canvas, Offset c, double r, double t) {
    const colors = _partyColors;
    if (!front) {
      _glowRing(
        canvas,
        c,
        r,
        const Color(0xFFFFB3D9).withValues(alpha: 0.5),
        width: 0.3,
        blur: 0.24,
        scale: 1.08,
      );
      // Balloons tied to the rim, bobbing up behind the top left.
      final tie = c + _dir(-2.3) * r * 1.02;
      for (var i = 0; i < 3; i++) {
        final a = -2.05 - i * 0.42 + math.sin(t * 1.4 + i * 2) * 0.05;
        final p = c + _dir(a) * r * (1.48 + 0.1 * i);
        final br = r * (0.2 - 0.02 * i);
        canvas.drawLine(
          p + Offset(0, br * 1.1),
          tie,
          Paint()
            ..strokeWidth = math.max(1, r * 0.015)
            ..color = Colors.white.withValues(alpha: 0.75),
        );
        final body = Rect.fromCenter(
          center: p,
          width: br * 1.8,
          height: br * 2.2,
        );
        final color = colors[(i * 2) % colors.length];
        canvas.drawOval(
          body,
          Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.35, -0.4),
              colors: [
                Color.lerp(color, Colors.white, 0.45)!,
                color,
                Color.lerp(color, Colors.black, 0.25)!,
              ],
              stops: const [0, 0.55, 1],
            ).createShader(body),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: p + Offset(-br * 0.35, -br * 0.5),
            width: br * 0.3,
            height: br * 0.5,
          ),
          Paint()..color = Colors.white.withValues(alpha: 0.5),
        );
      }
      return;
    }

    // The ribbon ring, turning.
    final ring = Rect.fromCircle(center: c, radius: r * 1.04);
    const pieces = 18;
    for (var k = 0; k < pieces; k++) {
      final start = k * 2 * math.pi / pieces + t * 0.6;
      canvas.drawArc(
        ring,
        start,
        2 * math.pi / pieces * 0.82,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.11
          ..color = colors[k % colors.length],
      );
    }
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, r * 0.02)
      ..color = const Color(0xFFFFF4E0);
    canvas.drawCircle(c, r * 0.985, edge);
    canvas.drawCircle(c, r * 1.095, edge);

    // Confetti bursting off the ring every few seconds and fluttering down.
    final burst = (t % 3.2) / 3.2;
    if (burst < 0.6 && !_lite) {
      final k = burst / 0.6;
      for (var i = 0; i < 16; i++) {
        final a = _rand(i + (t / 3.2).floor() * 16, 300) * math.pi * 2;
        final d = r * (1.1 + 0.55 * Curves.easeOut.transform(k));
        final p = c + _dir(a) * d + Offset(0, k * k * r * 0.35);
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.rotate(k * 9 + i);
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: r * 0.09,
            height: r * 0.05,
          ),
          Paint()..color = colors[i % colors.length].withValues(alpha: 1 - k),
        );
        canvas.restore();
      }
    }

    // The party hat, tipped on the rim at the top right.
    canvas.save();
    final base = c + _dir(-0.85) * r * 1.0;
    canvas.translate(base.dx, base.dy);
    canvas.rotate(0.62 + math.sin(t * 2.2) * 0.06);
    final hw = r * 0.34;
    final hh = r * 0.62;
    final cone = Path()
      ..moveTo(-hw / 2, 0)
      ..lineTo(hw / 2, 0)
      ..lineTo(0, -hh)
      ..close();
    canvas.drawPath(cone, Paint()..color = const Color(0xFF64B5F6));
    canvas.save();
    canvas.clipPath(cone);
    for (var s = 0; s < 4; s++) {
      final y = -hh * (s + 0.5) / 4.2;
      canvas.drawLine(
        Offset(-hw, y + hw * 0.25),
        Offset(hw, y - hw * 0.25),
        Paint()
          ..strokeWidth = hh * 0.08
          ..color = colors[(s * 2 + 1) % colors.length],
      );
    }
    canvas.restore();
    canvas.drawCircle(
      Offset(0, -hh),
      r * 0.075,
      Paint()..color = const Color(0xFFFFF4E0),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: hw * 1.1, height: r * 0.07),
        Radius.circular(r * 0.03),
      ),
      Paint()..color = const Color(0xFFFFD166),
    );
    canvas.restore();

    // The little cake at the bottom, its candle flickering.
    final cb = c + Offset(0, r * 1.22);
    final cw = r * 0.5;
    final lower = Rect.fromCenter(
      center: cb.translate(0, -r * 0.06),
      width: cw,
      height: r * 0.2,
    );
    final upper = Rect.fromCenter(
      center: cb.translate(0, -r * 0.23),
      width: cw * 0.7,
      height: r * 0.16,
    );
    for (final (rect, color) in [
      (lower, const Color(0xFFFF8FB9)),
      (upper, const Color(0xFFFFF4E0)),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(r * 0.04)),
        Paint()..color = color,
      );
      canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height * 0.28),
        Paint()..color = Colors.white.withValues(alpha: 0.6),
      );
    }
    final candle = Rect.fromCenter(
      center: upper.topCenter.translate(0, -r * 0.08),
      width: r * 0.05,
      height: r * 0.16,
    );
    canvas.drawRect(candle, Paint()..color = const Color(0xFF6EE7B7));
    final flick = 0.85 + 0.15 * math.sin(t * 17) + 0.06 * math.sin(t * 29);
    final tip = candle.topCenter + Offset(math.sin(t * 6) * r * 0.01, 0);
    canvas.drawCircle(
      tip.translate(0, -r * 0.06),
      r * 0.12 * flick,
      Paint()
        ..color = const Color(0x66FFD166)
        ..maskFilter = _blur(r * 0.05),
    );
    final fh = r * 0.13 * flick;
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy - fh)
        ..quadraticBezierTo(
          tip.dx + r * 0.04,
          tip.dy - fh * 0.3,
          tip.dx,
          tip.dy,
        )
        ..quadraticBezierTo(
          tip.dx - r * 0.04,
          tip.dy - fh * 0.3,
          tip.dx,
          tip.dy - fh,
        )
        ..close(),
      Paint()..color = const Color(0xFFFFB238),
    );

    // Sparkles twinkling round the ring.
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3 + 0.3;
      final tw = math.max(0.0, math.sin(t * 2.4 + i * 1.7));
      if (tw <= 0) continue;
      final p = c + _dir(a) * r * 1.24;
      final s = r * 0.07 * tw;
      final star = Path()
        ..moveTo(p.dx, p.dy - s)
        ..quadraticBezierTo(p.dx, p.dy, p.dx + s, p.dy)
        ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + s)
        ..quadraticBezierTo(p.dx, p.dy, p.dx - s, p.dy)
        ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - s)
        ..close();
      canvas.drawPath(star, Paint()..color = const Color(0xFFFFF4E0));
    }
  }

  /// Snow Globe: the picture sealed in a glass globe on a polished wooden
  /// stand, a snowy hill with little pines inside behind it. Every few
  /// seconds the globe's shaken: the snow swirls up round the picture and
  /// slowly settles again. A glint slides across the glass.
  void _snowGlobe(Canvas canvas, Offset c, double r, double t) {
    final big = r * 1.32;
    final globe = Rect.fromCircle(center: c, radius: big);
    // Each shake, the swirl starts fast and slows as the snow settles.
    const shakeEvery = 7.0;
    final since = t % shakeEvery;
    final spin = (1 - math.exp(-since * 0.9)) * 5.5;
    final settle = Curves.easeInOut.transform(
      ((since - 2.5) / (shakeEvery - 2.5)).clamp(0.0, 1.0),
    );
    final flakes = _lite ? 10 : 26;

    Offset flake(int i) {
      final a = _rand(i, 60) * 2 * math.pi + spin * (0.6 + 0.6 * _rand(i, 61));
      final d = r * 1.05 + (big * 0.93 - r * 1.05) * _rand(i, 62);
      final swirling = c + _dir(a) * d;
      // Settling, it sinks to the bottom of the globe.
      final floor =
          c.dy +
          math.sqrt(
            math.max(0, big * big * 0.8 - math.pow(swirling.dx - c.dx, 2)),
          );
      return Offset(
        swirling.dx,
        swirling.dy +
            (math.max(swirling.dy, floor - r * 0.08 * _rand(i, 63)) -
                    swirling.dy) *
                settle,
      );
    }

    if (!front) {
      _glowRing(
        canvas,
        c,
        r,
        const Color(0xFF9FD8FF).withValues(alpha: 0.35),
        width: 0.22,
        blur: 0.3,
        scale: 1.36,
      );
      // Inside the glass: a winter night, a snowy hill, two little pines.
      canvas.drawCircle(
        c,
        big,
        Paint()
          ..shader = RadialGradient(
            colors: const [Color(0xCC1A2A5A), Color(0xCC2E4478)],
          ).createShader(globe),
      );
      canvas.save();
      canvas.clipPath(Path()..addOval(globe));
      canvas.drawPath(
        Path()
          ..moveTo(c.dx - big, c.dy + big * 0.62)
          ..quadraticBezierTo(
            c.dx - big * 0.4,
            c.dy + big * 0.42,
            c.dx,
            c.dy + big * 0.6,
          )
          ..quadraticBezierTo(
            c.dx + big * 0.5,
            c.dy + big * 0.78,
            c.dx + big,
            c.dy + big * 0.5,
          )
          ..lineTo(c.dx + big, c.dy + big)
          ..lineTo(c.dx - big, c.dy + big)
          ..close(),
        Paint()..color = const Color(0xFFE6EEFF),
      );
      for (final (x, y, s) in const [
        (-0.9, 0.6, 0.5),
        (-0.76, 0.66, 0.34),
        (0.86, 0.58, 0.46),
      ]) {
        final base = c + Offset(big * x, big * y);
        final tall = r * s;
        for (var k = 0; k < 3; k++) {
          final bottom = base.dy - tall * k * 0.28;
          final half = tall * 0.32 * (1 - k * 0.25);
          canvas.drawPath(
            Path()
              ..moveTo(base.dx - half, bottom)
              ..lineTo(base.dx, bottom - tall * 0.42)
              ..lineTo(base.dx + half, bottom)
              ..close(),
            Paint()..color = const Color(0xFF1E5E46),
          );
          canvas.drawPath(
            Path()
              ..moveTo(base.dx - half * 0.4, bottom - tall * 0.24)
              ..lineTo(base.dx, bottom - tall * 0.42)
              ..lineTo(base.dx + half * 0.5, bottom - tall * 0.2)
              ..close(),
            Paint()..color = Colors.white.withValues(alpha: 0.9),
          );
        }
      }
      canvas.restore();
      final snow = Paint()..color = Colors.white.withValues(alpha: 0.85);
      for (var i = 0; i < flakes; i++) {
        canvas.drawCircle(flake(i), r * (0.025 + 0.025 * _rand(i, 64)), snow);
      }
      return;
    }

    // A few flakes drifting over the picture too, faint (it's all inside
    // the glass).
    final faint = Paint()..color = Colors.white.withValues(alpha: 0.5);
    for (var i = 0; i < (_lite ? 0 : 7); i++) {
      final a = _rand(i, 65) * 2 * math.pi + spin * 0.8;
      final p = c + _dir(a) * r * (0.35 + 0.55 * _rand(i, 66));
      canvas.drawCircle(
        p.translate(0, settle * r * 0.3 * _rand(i, 67)),
        r * 0.022,
        faint,
      );
    }
    // The glass: a thin bright rim, a curved highlight up one side, and a
    // glint sliding across now and then.
    canvas.drawCircle(
      c,
      big,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, r * 0.035)
        ..color = Colors.white.withValues(alpha: 0.45),
    );
    canvas.drawArc(
      globe.deflate(r * 0.07),
      math.pi * 1.08,
      math.pi * 0.36,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.07
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.5),
    );
    canvas.drawCircle(
      c + _dir(math.pi * 1.52) * big * 0.88,
      r * 0.04,
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
    final sweep = (t % 5.0) / 1.2;
    if (sweep < 1) {
      canvas.save();
      canvas.clipPath(Path()..addOval(globe));
      final x = c.dx - big * 1.4 + big * 2.8 * sweep;
      canvas.drawPath(
        Path()
          ..moveTo(x, c.dy - big)
          ..lineTo(x + big * 0.25, c.dy - big)
          ..lineTo(x - big * 0.35, c.dy + big)
          ..lineTo(x - big * 0.6, c.dy + big)
          ..close(),
        Paint()
          ..color = Colors.white.withValues(
            alpha: 0.12 * math.sin(sweep * math.pi),
          ),
      );
      canvas.restore();
    }

    // The stand: polished wood flaring out at the foot, a gold band and a
    // little brass plate with a snowflake on it.
    final top = c.dy + big * 0.84;
    final stand = Path()
      ..moveTo(c.dx - big * 0.62, top)
      ..lineTo(c.dx + big * 0.62, top)
      ..quadraticBezierTo(
        c.dx + big * 0.66,
        top + big * 0.22,
        c.dx + big * 0.8,
        top + big * 0.34,
      )
      ..lineTo(c.dx - big * 0.8, top + big * 0.34)
      ..quadraticBezierTo(
        c.dx - big * 0.66,
        top + big * 0.22,
        c.dx - big * 0.62,
        top,
      )
      ..close();
    canvas.drawPath(
      stand,
      Paint()
        ..shader =
            LinearGradient(
              colors: const [
                Color(0xFF3A160E),
                Color(0xFF8A3E22),
                Color(0xFF5A2414),
                Color(0xFF2A0E08),
              ],
              stops: const [0, 0.35, 0.7, 1],
            ).createShader(
              Rect.fromLTRB(
                c.dx - big * 0.8,
                top,
                c.dx + big * 0.8,
                top + big * 0.34,
              ),
            ),
    );
    canvas.drawRect(
      Rect.fromLTRB(
        c.dx - big * 0.63,
        top,
        c.dx + big * 0.63,
        top + big * 0.05,
      ),
      Paint()..color = const Color(0xFFFFD447),
    );
    final plate = Rect.fromCenter(
      center: Offset(c.dx, top + big * 0.19),
      width: big * 0.36,
      height: big * 0.12,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(plate, Radius.circular(big * 0.03)),
      Paint()..color = const Color(0xFFE8C060),
    );
    final etch = Paint()
      ..strokeWidth = math.max(0.6, r * 0.012)
      ..color = const Color(0xFF8A6420);
    for (var i = 0; i < 3; i++) {
      final a = i * math.pi / 3;
      final d = _dir(a) * plate.height * 0.32;
      canvas.drawLine(plate.center - d, plate.center + d, etch);
    }
  }

  /// Jack's Lantern: a ring of black brambles wound round the picture in a
  /// haze of candlelight and witch-violet; on the rim three carved
  /// jack-o'-lanterns flicker, a cobweb hangs across the top corner with a
  /// red-eyed spider dropping on its thread, bats circle and green wisps
  /// curl up.
  void _hallows(Canvas canvas, Offset c, double r, double t) {
    final flicker = 0.78 + 0.22 * math.sin(t * 9.1) * math.sin(t * 3.7 + 1);
    if (!front) {
      _glowRing(
        canvas,
        c,
        r,
        const Color(0xFFFF7A1A).withValues(alpha: 0.42 * flicker),
        width: 0.34,
        blur: 0.26,
        scale: 1.12,
      );
      _glowRing(
        canvas,
        c,
        r,
        const Color(0xFF8A4BFF).withValues(alpha: 0.3),
        width: 0.2,
        blur: 0.3,
        scale: 1.36,
      );
      // Brambles: three thorny vines twisting round each other.
      for (var v = 0; v < 3; v++) {
        final path = Path();
        final thorns = <(Offset, double)>[];
        for (var k = 0; k <= 64; k++) {
          final a = k / 64 * 2 * math.pi;
          final wave = math.sin(a * 5 + v * 2.1 + t * 0.3) * r * 0.06;
          final p = c + _dir(a) * (r * 1.1 + wave);
          if (k == 0) {
            path.moveTo(p.dx, p.dy);
          } else {
            path.lineTo(p.dx, p.dy);
          }
          if (k % 5 == v) thorns.add((p, a + (k.isEven ? 0.9 : -0.9)));
        }
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * (0.11 - v * 0.02)
            ..strokeCap = StrokeCap.round
            ..color = Color.lerp(
              const Color(0xFF0C0612),
              const Color(0xFF2A1636),
              v / 2,
            )!,
        );
        final thorn = Paint()..color = const Color(0xFF0C0612);
        for (final (p, a) in thorns) {
          final out = _dir(a);
          final side = Offset(-out.dy, out.dx);
          canvas.drawPath(
            Path()
              ..moveTo(p.dx + side.dx * r * 0.03, p.dy + side.dy * r * 0.03)
              ..lineTo(p.dx + out.dx * r * 0.16, p.dy + out.dy * r * 0.16)
              ..lineTo(p.dx - side.dx * r * 0.03, p.dy - side.dy * r * 0.03)
              ..close(),
            thorn,
          );
        }
      }
      // Bats circling behind.
      for (var i = 0; i < 4; i++) {
        final a = t * (0.8 + 0.2 * i) + i * math.pi / 2;
        final p = c + Offset(math.cos(a) * r * 1.55, math.sin(a) * r * 1.35);
        _batShape(canvas, p, r * 0.13, t * 15 + i, const Color(0xFF0C0612));
      }
      return;
    }

    // Green wisps curling up from the brambles.
    for (var i = 0; i < 5; i++) {
      final k = (t * 0.3 + i / 5) % 1.0;
      final a = math.pi * (0.15 + 0.7 * _rand(i, 40));
      final base = c + _dir(a + math.pi) * r * 1.1;
      final p = base.translate(math.sin(t * 2 + i) * r * 0.08, -k * r * 0.6);
      final puff = Rect.fromCircle(center: p, radius: r * (0.09 + 0.08 * k));
      canvas.drawOval(
        puff,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(
                0xFF8BFF4A,
              ).withValues(alpha: 0.4 * math.sin(k * math.pi)),
              const Color(0x008BFF4A),
            ],
          ).createShader(puff),
      );
    }

    // The cobweb across the top-left of the rim.
    final corner = c + _dir(-math.pi * 0.75) * r * 1.42;
    final silk = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, r * 0.012)
      ..color = Colors.white.withValues(alpha: 0.55);
    final spokes = [for (var k = 0; k < 5; k++) math.pi * (0.05 + k * 0.1)];
    for (final a in spokes) {
      canvas.drawLine(corner, corner + _dir(a) * r * 0.62, silk);
    }
    for (var ring = 1; ring <= 4; ring++) {
      final d = r * 0.62 * ring / 4.4;
      final web = Path();
      for (var k = 0; k < spokes.length; k++) {
        final p = corner + _dir(spokes[k]) * d;
        if (k == 0) {
          web.moveTo(p.dx, p.dy);
        } else {
          final prev = corner + _dir(spokes[k - 1]) * d;
          final mid = Offset.lerp(prev, p, 0.5)!;
          final sag = mid + (corner - mid) * 0.1;
          web.quadraticBezierTo(sag.dx, sag.dy, p.dx, p.dy);
        }
      }
      canvas.drawPath(web, silk);
    }
    // The spider dropping down its thread and climbing back.
    final hang = corner + _dir(math.pi * 0.25) * r * 0.42;
    final spider = hang.translate(
      0,
      r * (0.12 + 0.2 * (0.5 + 0.5 * math.sin(t * 0.9))),
    );
    canvas.drawLine(hang, spider, silk);
    final ink = Paint()..color = const Color(0xFF0C0612);
    final legs = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, r * 0.02)
      ..color = ink.color;
    final u = r * 0.045;
    for (final side in const [-1.0, 1.0]) {
      for (var k = 0; k < 4; k++) {
        final from = spider.translate(0, -u * 0.4 + k * u * 0.35);
        final wiggle = math.sin(t * 7 + k) * u * 0.3;
        canvas.drawPath(
          Path()
            ..moveTo(from.dx, from.dy)
            ..quadraticBezierTo(
              from.dx + side * u * 1.3,
              from.dy - u * (1.1 - k * 0.4) + wiggle,
              from.dx + side * u * 2,
              from.dy + u * (0.4 + k * 0.5),
            ),
          legs,
        );
      }
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: spider.translate(0, u * 0.4),
        width: u * 1.5,
        height: u * 1.9,
      ),
      ink,
    );
    canvas.drawCircle(spider.translate(0, -u * 0.6), u * 0.6, ink);
    for (final dx in const [-0.22, 0.22]) {
      canvas.drawCircle(
        spider.translate(u * dx, -u * 0.7),
        u * 0.16,
        Paint()..color = const Color(0xFFFF3A1A),
      );
    }

    // Three jack-o'-lanterns sitting on the rim.
    for (final (a, size, face) in const [
      (0.72, 0.5, 0),
      (0.2, 0.38, 1),
      (-0.28, 0.3, 2),
    ]) {
      _lanternOn(
        canvas,
        c + _dir(math.pi * a) * r * 1.12,
        r * size,
        t,
        face,
        flicker,
      );
    }
  }

  void _batShape(Canvas canvas, Offset p, double s, double beat, Color color) {
    final flap = math.sin(beat);
    canvas.drawPath(
      Path()
        ..moveTo(p.dx, p.dy)
        ..quadraticBezierTo(
          p.dx - s,
          p.dy - s * (0.4 + flap),
          p.dx - s * 2,
          p.dy - s * 0.2 * flap,
        )
        ..lineTo(p.dx - s * 1.4, p.dy + s * 0.2)
        ..lineTo(p.dx - s * 0.8, p.dy)
        ..lineTo(p.dx - s * 0.4, p.dy + s * 0.4)
        ..lineTo(p.dx, p.dy + s * 0.15)
        ..lineTo(p.dx + s * 0.4, p.dy + s * 0.4)
        ..lineTo(p.dx + s * 0.8, p.dy)
        ..lineTo(p.dx + s * 1.4, p.dy + s * 0.2)
        ..lineTo(p.dx + s * 2, p.dy - s * 0.2 * flap)
        ..quadraticBezierTo(p.dx + s, p.dy - s * (0.4 + flap), p.dx, p.dy)
        ..close(),
      Paint()..color = color,
    );
  }

  /// A small jack-o'-lantern of [size] centred at [at], carved [face]
  /// lit by its candle.
  void _lanternOn(
    Canvas canvas,
    Offset at,
    double size,
    double t,
    int face,
    double flicker,
  ) {
    final s = size;
    final light = flicker * (0.85 + 0.15 * math.sin(t * 5 + face));
    final halo = Rect.fromCircle(center: at, radius: s * 1.5);
    canvas.drawOval(
      halo,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFF7A1A).withValues(alpha: 0.45 * light),
            const Color(0x00FF7A1A),
          ],
        ).createShader(halo),
    );
    for (final (dx, wide, dark) in const [
      (-0.32, 0.62, 0.3),
      (0.32, 0.62, 0.3),
      (0.0, 0.66, 0.0),
    ]) {
      final lobe = Rect.fromCenter(
        center: at.translate(s * dx, 0),
        width: s * wide * 1.4,
        height: s * 1.0,
      );
      canvas.drawOval(
        lobe,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.4),
            colors: [
              Color.lerp(const Color(0xFFFFA24A), Colors.black, dark)!,
              Color.lerp(const Color(0xFFF2761A), Colors.black, dark + 0.1)!,
              Color.lerp(const Color(0xFF9A3A08), Colors.black, dark + 0.2)!,
            ],
            stops: const [0, 0.6, 1],
          ).createShader(lobe),
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(at.dx - s * 0.07, at.dy - s * 0.46)
        ..quadraticBezierTo(
          at.dx - s * 0.04,
          at.dy - s * 0.66,
          at.dx + s * 0.13,
          at.dy - s * 0.72,
        )
        ..lineTo(at.dx + s * 0.14, at.dy - s * 0.64)
        ..quadraticBezierTo(
          at.dx + s * 0.06,
          at.dy - s * 0.6,
          at.dx + s * 0.07,
          at.dy - s * 0.46,
        )
        ..close(),
      Paint()..color = const Color(0xFF3A3A16),
    );
    final cut = Path();
    for (final side in const [-1.0, 1.0]) {
      final e = at.translate(side * s * 0.26, -s * 0.12);
      if (face == 1) {
        // Angry, slanted.
        cut
          ..moveTo(e.dx - side * s * 0.14, e.dy - s * 0.04)
          ..lineTo(e.dx + side * s * 0.16, e.dy - s * 0.16)
          ..lineTo(e.dx + side * s * 0.1, e.dy + s * 0.08)
          ..close();
      } else {
        cut
          ..moveTo(e.dx - s * 0.12, e.dy + s * 0.08)
          ..lineTo(e.dx, e.dy - s * 0.14)
          ..lineTo(e.dx + s * 0.12, e.dy + s * 0.08)
          ..close();
      }
    }
    cut.moveTo(at.dx - s * 0.4, at.dy + s * 0.1);
    cut.quadraticBezierTo(
      at.dx,
      at.dy + s * (face == 2 ? 0.55 : 0.45),
      at.dx + s * 0.4,
      at.dy + s * 0.1,
    );
    for (var k = 1; k < 6; k++) {
      cut.lineTo(
        at.dx + s * (0.4 - k * 0.16),
        at.dy + s * (k.isEven ? 0.12 : 0.24),
      );
    }
    cut.close();
    canvas.drawPath(
      cut,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF2B0).withValues(alpha: light.clamp(0.0, 1.0)),
            const Color(0xFFFFC23D).withValues(alpha: light.clamp(0.0, 1.0)),
            const Color(0xFFFF7A1A).withValues(alpha: light.clamp(0.0, 1.0)),
          ],
        ).createShader(Rect.fromCircle(center: at, radius: s * 0.6)),
    );
  }

  /// Encore: the picture sits on a spinning record. Behind it, an
  /// equalizer of neon bars radiates all the way round, jumping on every
  /// beat (the same beat as the Music world); in front, the record's
  /// grooves catch the light, a ring of sound goes out on each beat, and
  /// notes orbit.
  void _music(Canvas canvas, Offset c, double r, double t) {
    final beats = worldSeconds * 2;
    final phase = beats % 1.0;
    final hit = math.exp(-phase * 6);
    if (!front) {
      _glowRing(
        canvas,
        c,
        r,
        const Color(0xFFB44CFF).withValues(alpha: 0.45 + 0.25 * hit),
        width: 0.3,
        blur: 0.24,
        scale: 1.12,
      );
      const bars = 40;
      for (var i = 0; i < bars; i++) {
        final a = i * 2 * math.pi / bars - math.pi / 2;
        // Mirrored left and right, the bass at the bottom thumping hardest.
        final band = (math.cos(a + math.pi / 2).abs());
        final flutter = 0.5 + 0.5 * math.sin(t * (7 + 9 * band) + i * 1.7);
        final level =
            0.25 + 0.45 * hit * (1 - band) + 0.3 * flutter * (0.4 + band);
        final from = c + _dir(a) * r * 1.13;
        final to = c + _dir(a) * r * (1.17 + 0.42 * level);
        final color = Color.lerp(
          _stage[(i ~/ 4) % _stage.length],
          _stage[(i ~/ 4 + 1) % _stage.length],
          (i % 4) / 4,
        )!;
        canvas.drawLine(
          from,
          to,
          Paint()
            ..strokeWidth = r * 0.075
            ..strokeCap = StrokeCap.round
            ..color = color,
        );
        canvas.drawCircle(
          to + _dir(a) * r * 0.07,
          r * 0.03,
          Paint()..color = Colors.white.withValues(alpha: 0.85),
        );
      }
      // The record under the picture.
      canvas.drawCircle(c, r * 1.11, Paint()..color = const Color(0xFF0B0812));
      return;
    }
    // The record's grooves, and the light sliding round them.
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, r * 0.012)
      ..color = Colors.white.withValues(alpha: 0.16);
    for (final k in const [1.03, 1.06, 1.09]) {
      canvas.drawCircle(c, r * k, groove);
    }
    final spin = t * 1.4;
    for (final off in const [0.0, math.pi]) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r * 1.06),
        spin + off,
        0.7,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.07
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            transform: GradientRotation(spin + off),
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.4),
              Colors.white.withValues(alpha: 0),
            ],
            stops: const [0, 0.05, 0.11],
          ).createShader(Rect.fromCircle(center: c, radius: r * 1.1)),
      );
    }
    // A neon rim, pulsing.
    canvas.drawCircle(
      c,
      r * 1.005,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..shader = SweepGradient(
          transform: GradientRotation(-t * 0.8),
          colors: const [
            Color(0xFF00E5FF),
            Color(0xFFFF2E9A),
            Color(0xFFC6FF3D),
            Color(0xFF00E5FF),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // A ring of sound going out on each beat.
    canvas.drawCircle(
      c,
      r * (1.12 + 0.5 * phase),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.04 * (1 - phase)
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.7 * (1 - phase)),
    );
    // Notes orbiting.
    for (var i = 0; i < 3; i++) {
      final a = -t * 0.9 + i * 2 * math.pi / 3;
      final at = c + _dir(a) * r * (1.42 + 0.05 * math.sin(t * 3 + i));
      final s = r * 0.17 * (1 + 0.12 * hit);
      final paint = Paint()..color = _stage[(i * 2 + 3) % _stage.length];
      final halo = Rect.fromCircle(center: at, radius: s * 1.3);
      canvas.drawOval(
        halo,
        Paint()
          ..shader = RadialGradient(
            colors: [
              paint.color.withValues(alpha: 0.4),
              paint.color.withValues(alpha: 0),
            ],
          ).createShader(halo),
      );
      canvas.drawOval(
        Rect.fromCenter(center: at, width: s, height: s * 0.74),
        paint,
      );
      canvas.drawRect(
        Rect.fromLTWH(at.dx + s * 0.34, at.dy - s * 1.45, s * 0.16, s * 1.45),
        paint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(at.dx + s * 0.5, at.dy - s * 1.45)
          ..quadraticBezierTo(
            at.dx + s * 1.1,
            at.dy - s * 1.05,
            at.dx + s * 0.85,
            at.dy - s * 0.55,
          ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.16
          ..color = paint.color,
      );
    }
  }

  /// Chip Maestro: a ring of thick rainbow brushstrokes slowly turning
  /// behind the picture; in front, fat splats of paint (the low ones drip),
  /// and a brush painting its way round, its wet stroke fading behind it.
  void _maestro(Canvas canvas, Offset c, double r, double t) {
    final ring = Rect.fromCircle(center: c, radius: r * 1.1);
    if (!front) {
      canvas.drawCircle(
        c,
        r * 1.1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.34
          ..color = const Color(0xFFFF8FC4).withValues(alpha: 0.25)
          ..maskFilter = _blur(r * 0.18),
      );
      // One fat stroke per color, overlapping like real paint.
      final turn = t * 0.25;
      for (var i = 0; i < _paints.length; i++) {
        final from = turn + i * 2 * math.pi / _paints.length;
        final wobble = 0.03 * math.sin(t * 1.1 + i * 2);
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r * (1.1 + wobble)),
          from,
          2 * math.pi / _paints.length + 0.32,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = r * (0.22 + 0.05 * _rand(i, 4))
            ..color = _paints[i],
        );
        // The shine of wet paint along each stroke.
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r * (1.06 + wobble)),
          from + 0.15,
          2 * math.pi / _paints.length - 0.2,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = r * 0.035
            ..color = Colors.white.withValues(alpha: 0.38),
        );
      }
      return;
    }
    // Splats round the ring; the lower ones drip.
    for (var i = 0; i < 7; i++) {
      final a = i * 2 * math.pi / 7 + 0.4;
      final swell = 0.88 + 0.12 * math.sin(t * 1.6 + i * 1.3);
      final at = c + _dir(a) * r * 1.2;
      final color = _paints[(i + 2) % _paints.length];
      final s = r * 0.14 * swell;
      final splat = Paint()..color = color;
      canvas.drawCircle(at, s, splat);
      for (var k = 0; k < 4; k++) {
        final d = a + (k - 1.5) * 0.55 + _rand(i, k) * 0.3;
        canvas.drawCircle(
          at + _dir(d) * s * (1.45 + _rand(i, k + 7) * 0.5),
          s * (0.2 + _rand(i, k + 3) * 0.22),
          splat,
        );
      }
      if (math.sin(a) > 0.25) {
        final drip = s * (0.9 + 0.9 * ((t * 0.35 + _rand(i, 9)) % 1));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(at.dx - s * 0.22, at.dy, s * 0.44, drip),
            Radius.circular(s * 0.22),
          ),
          splat,
        );
        canvas.drawCircle(Offset(at.dx, at.dy + drip), s * 0.3, splat);
      }
      canvas.drawCircle(
        at.translate(-s * 0.32, -s * 0.32),
        s * 0.3,
        Paint()..color = Colors.white.withValues(alpha: 0.5),
      );
    }
    // The brush going round, and the wet stroke it leaves.
    final spin = t * 0.8;
    final ink = _paints[(t * 0.3).floor() % _paints.length];
    for (var k = 0; k < 16; k++) {
      canvas.drawArc(
        ring,
        spin - 0.1 * (k + 1),
        0.11,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = r * 0.12 * (1 - k / 22)
          ..color = ink.withValues(alpha: 0.95 * (1 - k / 16)),
      );
    }
    final tip = c + _dir(spin) * r * 1.1;
    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.rotate(spin + math.pi * 0.8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-r * 0.045, r * 0.1, r * 0.09, r * 0.55),
        Radius.circular(r * 0.045),
      ),
      Paint()..color = const Color(0xFFC98A4B),
    );
    canvas.drawRect(
      Rect.fromLTWH(-r * 0.06, -r * 0.03, r * 0.12, r * 0.14),
      Paint()..color = const Color(0xFFCFD6E0),
    );
    canvas.drawPath(
      Path()
        ..moveTo(-r * 0.06, -r * 0.03)
        ..quadraticBezierTo(-r * 0.05, -r * 0.16, 0, -r * 0.22)
        ..quadraticBezierTo(r * 0.05, -r * 0.16, r * 0.06, -r * 0.03)
        ..close(),
      Paint()..color = ink,
    );
    canvas.restore();
  }
}
