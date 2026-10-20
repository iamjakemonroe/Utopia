part of 'coin_buddy.dart';

const _santaRed = Color(0xFFD7263D);
const _fur = Color(0xFFF7F8FF);

/// What the sets and the day dress Chip in: the Santa hat and scarf, the party hat, the beret, a zombie's face, baby horns, the halo, the headband, DJ headphones and shades, and the carved jack-o'-lantern in its witch's hat.
extension _Costumes on _FacePainter {
  /// The Winter world's set: a red Santa hat with a white fur brim, its tip
  /// flopping over to one side with a pom-pom bouncing on the end.
  void _santaHat(Canvas canvas, Offset c, double r) {
    final a = winter.clamp(0.0, 1.0);
    final sway = math.sin(t * 1.4) * 0.05;
    canvas.save();
    canvas.translate(c.dx + r * 0.05, c.dy - r * 0.74);
    canvas.rotate(0.14 + sway);
    final tip = Offset(r * (0.95 + sway), -r * (0.42 - sway * 2));
    final hat = Path()
      ..moveTo(-r * 0.74, 0)
      ..quadraticBezierTo(-r * 0.62, -r * 0.88, r * 0.1, -r * 0.98)
      ..quadraticBezierTo(r * 0.78, -r * 1.02, tip.dx, tip.dy)
      ..quadraticBezierTo(r * 0.62, -r * 0.64, r * 0.48, -r * 0.6)
      ..quadraticBezierTo(r * 0.62, -r * 0.3, r * 0.74, 0)
      ..close();
    canvas.drawPath(
      hat,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFF5A68).withValues(alpha: a),
            _santaRed.withValues(alpha: a),
            const Color(0xFF8A1424).withValues(alpha: a),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromLTWH(-r, -r * 1.1, r * 2, r * 1.2)),
    );
    // A soft fold of light down its front.
    canvas.drawPath(
      Path()
        ..moveTo(-r * 0.5, -r * 0.05)
        ..quadraticBezierTo(-r * 0.42, -r * 0.7, r * 0.05, -r * 0.9)
        ..quadraticBezierTo(-r * 0.25, -r * 0.6, -r * 0.28, -r * 0.05)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.16 * a),
    );
    // The fur brim: a fat white band, fluffed along its edges.
    final fur = Paint()..color = _fur.withValues(alpha: a);
    final shade = Paint()..color = const Color(0xFFC9D2EE).withValues(alpha: a);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, r * 0.02),
          width: r * 1.7,
          height: r * 0.34,
        ),
        Radius.circular(r * 0.17),
      ),
      shade,
    );
    for (var i = 0; i < 9; i++) {
      final x = -r * 0.72 + r * 1.44 * i / 8;
      canvas.drawCircle(Offset(x, -r * 0.04), r * 0.13, fur);
      canvas.drawCircle(
        Offset(x + r * 0.08, r * 0.07),
        r * 0.1,
        i.isEven ? fur : shade,
      );
    }
    // The pom-pom.
    final bob = tip.translate(r * 0.02, r * (0.08 + 0.04 * math.sin(t * 3)));
    canvas.drawCircle(bob, r * 0.19, shade);
    for (var k = 0; k < 6; k++) {
      final ang = k / 6 * math.pi * 2;
      canvas.drawCircle(
        bob + Offset(math.cos(ang), math.sin(ang)) * r * 0.07,
        r * 0.12,
        fur,
      );
    }
    canvas.restore();
  }

  /// The Winter world's set: a striped knitted scarf wrapped round the
  /// bottom of him, knotted at one side, its ends blowing in the wind.
  void _scarf(Canvas canvas, Offset c, double r) {
    final a = winter.clamp(0.0, 1.0);
    final red = _santaRed.withValues(alpha: a);
    final ring = Rect.fromCircle(center: c, radius: r * 0.92);
    canvas.drawArc(
      ring,
      math.pi * 0.16,
      math.pi * 0.7,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.26
        ..color = red,
    );
    // Its knit: stripes across it, and a darker edge.
    final stripe = Paint()
      ..strokeWidth = r * 0.07
      ..color = _fur.withValues(alpha: 0.95 * a);
    for (var i = 0; i < 6; i++) {
      final ang = math.pi * (0.27 + i * 0.11);
      final dir = Offset(math.cos(ang), math.sin(ang));
      canvas.drawLine(c + dir * r * 0.8, c + dir * r * 1.04, stripe);
    }
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 1.04),
      math.pi * 0.16,
      math.pi * 0.7,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.03
        ..color = const Color(0xFF8A1424).withValues(alpha: a),
    );
    // The knot at his side, and the two ends hanging from it, blowing.
    final knot =
        c + Offset(math.cos(math.pi * 0.2), math.sin(math.pi * 0.2)) * r * 0.92;
    for (final (lean, long) in const [(0.1, 0.62), (0.42, 0.5)]) {
      final blow = math.sin(t * 2.6 + lean * 9) * r * 0.06;
      final end = knot + Offset(r * lean + blow, r * long);
      canvas.drawLine(
        knot,
        end,
        Paint()
          ..strokeWidth = r * 0.17
          ..strokeCap = StrokeCap.butt
          ..color = red,
      );
      final along = end - knot;
      for (final k in const [0.45, 0.75]) {
        final p = knot + along * k;
        final side = Offset(-along.dy, along.dx) / along.distance * r * 0.085;
        canvas.drawLine(p - side, p + side, stripe);
      }
      // The fringe.
      final side = Offset(-along.dy, along.dx) / along.distance;
      for (var f = -1; f <= 1; f++) {
        final from = end + side * (f * r * 0.06);
        canvas.drawLine(
          from,
          from + along / along.distance * r * 0.09,
          Paint()
            ..strokeWidth = r * 0.025
            ..strokeCap = StrokeCap.round
            ..color = _fur.withValues(alpha: a),
        );
      }
    }
    canvas.drawCircle(knot, r * 0.13, Paint()..color = red);
    canvas.drawCircle(
      knot.translate(-r * 0.03, -r * 0.04),
      r * 0.05,
      Paint()..color = Colors.white.withValues(alpha: 0.25 * a),
    );
  }

  /// His breath puffing out in the cold now and then, drifting up and
  /// away.
  void _breath(Canvas canvas, Offset c, double r) {
    final mouth = c.translate(r * 0.05, r * 0.36);
    for (var i = 0; i < 2; i++) {
      final k = ((t + i * 0.35) % 3.4) / 1.4;
      if (k > 1) continue;
      final p = mouth.translate(r * (0.15 + k * 0.7), -r * k * 0.35);
      final puff = Rect.fromCircle(center: p, radius: r * (0.07 + 0.16 * k));
      canvas.drawOval(
        puff,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(
                alpha: 0.55 * (1 - k) * winter.clamp(0.0, 1.0),
              ),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(puff),
      );
    }
  }

  /// His birthday party hat: a striped cone tipped to one side with a fluffy
  /// pom-pom, bobbing as he does.
  void _partyHat(Canvas canvas, Offset c, double r) {
    final a = party.clamp(0.0, 1.0);
    const stripes = [Color(0xFFFFD166), Color(0xFF6EE7B7), Color(0xFFFFF4E0)];
    canvas.save();
    canvas.translate(c.dx + r * 0.22, c.dy - r * 0.78);
    canvas.rotate(0.32 + math.sin(t * 1.6) * 0.05);
    final w = r * 0.78;
    final h = r * 1.0;
    final cone = Path()
      ..moveTo(-w / 2, 0)
      ..quadraticBezierTo(0, r * 0.08, w / 2, 0)
      ..lineTo(0, -h)
      ..close();
    canvas.drawPath(
      cone,
      Paint()..color = const Color(0xFFFF6FAE).withValues(alpha: a),
    );
    canvas.save();
    canvas.clipPath(cone);
    for (var s = 0; s < 4; s++) {
      final y = -h * (s + 0.55) / 4.4;
      canvas.drawLine(
        Offset(-w, y + w * 0.22),
        Offset(w, y - w * 0.22),
        Paint()
          ..strokeWidth = h * 0.09
          ..color = stripes[s % stripes.length].withValues(alpha: a),
      );
    }
    // A sheen down one side.
    canvas.drawPath(
      Path()
        ..moveTo(-w * 0.32, 0)
        ..lineTo(-w * 0.12, 0)
        ..lineTo(0, -h)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.22 * a),
    );
    canvas.restore();
    // The pom-pom.
    for (var k = 0; k < 7; k++) {
      final ang = k / 7 * math.pi * 2 + t;
      canvas.drawCircle(
        Offset(0, -h) + Offset(math.cos(ang), math.sin(ang)) * r * 0.07,
        r * 0.08,
        Paint()..color = const Color(0xFFFFF4E0).withValues(alpha: a),
      );
    }
    canvas.drawCircle(
      Offset(0, -h),
      r * 0.09,
      Paint()..color = const Color(0xFFFFD166).withValues(alpha: a),
    );
    canvas.restore();
  }

  /// Chip Maestro: a red artist's beret tipped over one side (his sprout
  /// grows out of the top), and a paintbrush tucked behind him, its tip
  /// slowly changing color.
  void _beret(Canvas canvas, Offset c, double r) {
    final a = artist.clamp(0.0, 1.0);
    final sway = math.sin(t * 1.3) * 0.03;

    // The brush, behind the beret, angled up and out on his right.
    canvas.save();
    canvas.translate(c.dx + r * 0.8, c.dy - r * 0.46);
    canvas.rotate(0.6 + sway);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-r * 0.045, -r * 0.72, r * 0.09, r * 0.72),
        Radius.circular(r * 0.045),
      ),
      Paint()..color = const Color(0xFFC98A4B).withValues(alpha: a),
    );
    canvas.drawRect(
      Rect.fromLTWH(-r * 0.055, -r * 0.84, r * 0.11, r * 0.13),
      Paint()..color = const Color(0xFFCFD6E0).withValues(alpha: a),
    );
    final paint = Color.lerp(
      const Color(0xFFFF5C9C),
      const Color(0xFF4DA3FF),
      (math.sin(t * 0.7) + 1) / 2,
    )!;
    canvas.drawPath(
      Path()
        ..moveTo(-r * 0.055, -r * 0.84)
        ..quadraticBezierTo(-r * 0.065, -r * 1.0, 0, -r * 1.1)
        ..quadraticBezierTo(r * 0.065, -r * 1.0, r * 0.055, -r * 0.84)
        ..close(),
      Paint()..color = paint.withValues(alpha: a),
    );
    canvas.restore();

    // The beret.
    canvas.save();
    canvas.translate(c.dx + r * 0.1, c.dy - r * 0.86);
    canvas.rotate(-0.22 + sway);
    final crown = Rect.fromCenter(
      center: Offset.zero,
      width: r * 1.55,
      height: r * 0.62,
    );
    canvas.drawOval(
      crown.shift(Offset(0, r * 0.05)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18 * a)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.05),
    );
    canvas.drawOval(
      crown,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.5),
          radius: 0.9,
          colors: [
            const Color(0xFFE5484D).withValues(alpha: a),
            const Color(0xFFB3202B).withValues(alpha: a),
            const Color(0xFF7A1018).withValues(alpha: a),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(crown),
    );
    // The band where it sits on his head.
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(0, r * 0.2),
        width: r * 1.15,
        height: r * 0.22,
      ),
      0.1,
      math.pi - 0.2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.07
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF5E0C12).withValues(alpha: a),
    );
    // A soft shine across the top.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-r * 0.3, -r * 0.12),
        width: r * 0.42,
        height: r * 0.13,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.22 * a),
    );
    canvas.restore();
  }

  /// Fully turned, his face is a zombie's whatever his mood: one eye
  /// staring wide with a pinprick pupil, the other half shut, no brows, a
  /// slack jaw slowly working, and now and then a drop of drool.
  void _zombieFace(Canvas canvas, Offset c, double r) {
    final ink = Paint()..color = AppColors.faceInk;
    final sclera = Paint()..color = const Color(0xFFDCE3B8);
    final drift = Offset(
      math.sin(t * 0.37) * r * 0.03,
      math.cos(t * 0.29) * r * 0.02,
    );
    final wide = c.translate(-r * 0.3, -r * 0.1);
    canvas.drawOval(
      Rect.fromCenter(center: wide, width: r * 0.4, height: r * 0.46),
      sclera,
    );
    canvas.drawCircle(wide + drift, r * 0.045, ink);
    final shut = c.translate(r * 0.3, -r * 0.06);
    canvas.drawOval(
      Rect.fromCenter(center: shut, width: r * 0.36, height: r * 0.4),
      sclera,
    );
    canvas.drawCircle(shut + drift * 0.7 + Offset(0, r * 0.05), r * 0.035, ink);
    _droopyLid(canvas, shut, r, 0.9);

    // The jaw, hanging crooked, opening and closing slowly.
    final open = 0.55 + 0.45 * (0.5 + 0.5 * math.sin(t * 1.3));
    canvas.save();
    canvas.translate(c.dx + r * 0.02, c.dy + r * 0.36);
    canvas.rotate(0.1);
    final jaw = Rect.fromCenter(
      center: Offset.zero,
      width: r * 0.38,
      height: r * (0.06 + 0.18 * open),
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        jaw,
        topLeft: Radius.circular(r * 0.05),
        topRight: Radius.circular(r * 0.1),
        bottomLeft: Radius.circular(r * 0.12),
        bottomRight: Radius.circular(r * 0.08),
      ),
      Paint()..color = const Color(0xFF2A1A12),
    );
    // Teeth along the top, one missing.
    final tooth = Paint()..color = const Color(0xFFE8E2C4);
    for (var i = 0; i < 4; i++) {
      if (i == 2) continue;
      canvas.drawRect(
        Rect.fromLTWH(
          jaw.left + r * 0.04 + i * r * 0.08,
          jaw.top,
          r * 0.055,
          r * 0.06,
        ),
        tooth,
      );
    }
    // Drool from the corner every few seconds, stretching and dropping.
    final k = (t % 4.0) / 4.0;
    if (k < 0.6) {
      final len = r * 0.22 * (k / 0.6);
      final at = Offset(jaw.right - r * 0.04, jaw.bottom - r * 0.01);
      final drool = Paint()
        ..color = const Color(0xFFCFE6C2).withValues(alpha: 0.85);
      canvas.drawLine(
        at,
        at.translate(0, len),
        drool
          ..strokeWidth = r * 0.025
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(at.translate(0, len), r * 0.03, drool);
    }
    canvas.restore();
  }

  /// Turned: rot blotches, a stitched scar and sunken sockets.
  void _rot(Canvas canvas, Offset c, double r) {
    final rot = Paint()
      ..color = const Color(0xFF55663F).withValues(alpha: 0.65 * zombie);
    for (final (dx, dy, w, h) in const [
      (-0.42, -0.42, 0.26, 0.18),
      (0.48, 0.36, 0.18, 0.13),
      (-0.18, 0.6, 0.12, 0.08),
      (0.12, -0.66, 0.1, 0.07),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(dx * r, dy * r),
          width: w * r,
          height: h * r,
        ),
        rot,
      );
    }
    final thread = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = r * 0.03
      ..color = const Color(0xFF3B2E22).withValues(alpha: zombie);
    final from = c.translate(-r * 0.62, r * 0.02);
    final to = c.translate(-r * 0.4, r * 0.42);
    canvas.drawLine(from, to, thread);
    final along = to - from;
    final across = Offset(-along.dy, along.dx) / along.distance * r * 0.07;
    for (var i = 1; i <= 3; i++) {
      final p = from + along * (i / 4);
      canvas.drawLine(p - across, p + across, thread);
    }
    final socket = Paint()
      ..color = const Color(0xFF2E3A26).withValues(alpha: 0.5 * zombie)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.04);
    for (final side in const [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(side * r * 0.3, -r * 0.1),
          width: r * 0.48,
          height: r * 0.56,
        ),
        socket,
      );
    }
  }

  /// Hell's set: two baby horns poking up, growing in as it comes on.
  void _babyHorns(Canvas canvas, Offset c, double r) {
    final grow = Curves.easeOutBack.transform(devil.clamp(0.0, 1.0));
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Color(0xFF8E1010), Color(0xFFFF4D4D)],
      ).createShader(Rect.fromCircle(center: c, radius: r * 1.3));
    for (final side in const [-1.0, 1.0]) {
      final base = c.translate(side * r * 0.42, -r * 0.8);
      final tip = base.translate(side * r * 0.12 * grow, -r * 0.32 * grow);
      canvas.drawPath(
        Path()
          ..moveTo(base.dx - side * r * 0.13, base.dy + r * 0.08)
          ..quadraticBezierTo(base.dx, base.dy - r * 0.2 * grow, tip.dx, tip.dy)
          ..quadraticBezierTo(
            base.dx + side * r * 0.16,
            base.dy - r * 0.05,
            base.dx + side * r * 0.14,
            base.dy + r * 0.1,
          )
          ..close(),
        paint,
      );
    }
  }

  /// Heaven's set: a gold halo floating over him, bobbing, glowing.
  void _halo(Canvas canvas, Offset c, double r) {
    final at = c.translate(0, -r * 1.68 + math.sin(t * 1.6) * r * 0.05);
    final ring = Rect.fromCenter(center: at, width: r * 1.0, height: r * 0.26);
    canvas.drawOval(
      ring.inflate(r * 0.06),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.14
        ..color = const Color(0xFFFFE08A).withValues(alpha: 0.35 * angel)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.08),
    );
    canvas.drawOval(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08
        ..shader = LinearGradient(
          colors: [
            const Color(0xFFFFF4C9).withValues(alpha: angel),
            const Color(0xFFE0A93A).withValues(alpha: angel),
          ],
        ).createShader(ring),
    );
  }

  /// The Dojo's set: a white headband across his brow with 勇 ("courage")
  /// on a red disc, knotted at the side, its tails fluttering.
  void _headband(Canvas canvas, Offset c, double r) {
    final a = fighter.clamp(0.0, 1.0);
    final top = c.dy - r * 0.76;
    final bottom = c.dy - r * 0.58;
    final band = Path()
      ..moveTo(c.dx - r, top + r * 0.06)
      ..quadraticBezierTo(c.dx, top - r * 0.04, c.dx + r, top + r * 0.06)
      ..lineTo(c.dx + r, bottom + r * 0.06)
      ..quadraticBezierTo(c.dx, bottom - r * 0.04, c.dx - r, bottom + r * 0.06)
      ..close();
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    canvas.drawPath(
      band,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: a),
            const Color(0xFFDCDCE6).withValues(alpha: a),
          ],
        ).createShader(Rect.fromLTRB(c.dx - r, top, c.dx + r, bottom)),
    );
    canvas.drawPath(
      band,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.03
        ..color = const Color(0xFFC8102E).withValues(alpha: a),
    );
    canvas.restore();

    // Knot and tails at his right side, fluttering.
    final knot = c.translate(r * 0.9, -r * 0.62);
    final tail = Paint()..color = Colors.white.withValues(alpha: a);
    for (var k = 0; k < 2; k++) {
      final flutter = math.sin(t * 9 + k * 1.7) * r * 0.06;
      canvas.drawPath(
        Path()
          ..moveTo(knot.dx, knot.dy - r * 0.04)
          ..quadraticBezierTo(
            knot.dx + r * 0.25,
            knot.dy + r * (0.02 + k * 0.12) + flutter,
            knot.dx + r * 0.5,
            knot.dy + r * (0.1 + k * 0.2) + flutter * 1.6,
          )
          ..lineTo(knot.dx + r * 0.46, knot.dy + r * (0.2 + k * 0.2) + flutter)
          ..quadraticBezierTo(
            knot.dx + r * 0.22,
            knot.dy + r * (0.12 + k * 0.12) + flutter,
            knot.dx,
            knot.dy + r * 0.05,
          )
          ..close(),
        tail,
      );
    }
    canvas.drawCircle(
      knot,
      r * 0.07,
      Paint()..color = const Color(0xFFEDEDF3).withValues(alpha: a),
    );

    // The emblem.
    final e = Offset(c.dx, (top + bottom) / 2 - r * 0.01);
    canvas.drawCircle(
      e,
      r * 0.15,
      Paint()..color = const Color(0xFFC8102E).withValues(alpha: a),
    );
    final glyph = TextPainter(
      text: TextSpan(
        text: '勇',
        style: TextStyle(
          color: Colors.white.withValues(alpha: a),
          fontSize: r * 0.19,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    glyph.paint(canvas, e - Offset(glyph.width / 2, glyph.height / 2));
    glyph.dispose();
  }

  /// Big comfy headphones: a band over the top and glowing cups.
  void _headphones(Canvas canvas, Offset c, double r) {
    final band = Rect.fromCircle(center: c, radius: r * 1.06);
    canvas.drawArc(
      band,
      math.pi * 1.08,
      math.pi * 0.84,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.16
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF2A2050),
    );
    canvas.drawArc(
      band,
      math.pi * 1.12,
      math.pi * 0.76,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.25),
    );
    final pulse = 0.6 + 0.4 * math.sin(t * 5.2).abs();
    for (final side in const [-1.0, 1.0]) {
      final cup = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: c.translate(side * r * 0.98, r * 0.02),
          width: r * 0.34,
          height: r * 0.62,
        ),
        Radius.circular(r * 0.16),
      );
      canvas.drawRRect(
        cup.inflate(r * 0.06),
        Paint()..color = AppColors.accent.withValues(alpha: 0.35 * pulse),
      );
      canvas.drawRRect(
        cup,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(AppColors.accent, Colors.white, 0.35)!,
              AppColors.accent,
              const Color(0xFF2A2050),
            ],
          ).createShader(cup.outerRect),
      );
      canvas.drawCircle(
        cup.center,
        r * 0.07,
        Paint()..color = Colors.white.withValues(alpha: 0.5 + 0.4 * pulse),
      );
    }
  }

  /// DJ shades: two wide neon-rimmed lenses with the stage lights sliding
  /// across them.
  void _shades(Canvas canvas, Offset c, double r) {
    final a = dj.clamp(0.0, 1.0);
    final lenses = <Path>[];
    for (final side in const [-1.0, 1.0]) {
      final e = c.translate(side * r * 0.3, -r * 0.1);
      lenses.add(
        Path()..addRRect(
          RRect.fromRectAndCorners(
            Rect.fromCenter(center: e, width: r * 0.46, height: r * 0.3),
            topLeft: Radius.circular(r * (side < 0 ? 0.06 : 0.04)),
            topRight: Radius.circular(r * (side < 0 ? 0.04 : 0.06)),
            bottomLeft: Radius.circular(r * (side < 0 ? 0.16 : 0.1)),
            bottomRight: Radius.circular(r * (side < 0 ? 0.1 : 0.16)),
          ),
        ),
      );
    }
    final frame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.05
      ..strokeJoin = StrokeJoin.round
      ..shader = LinearGradient(
        colors: [
          const Color(0xFFFF2E9A).withValues(alpha: a),
          const Color(0xFF00E5FF).withValues(alpha: a),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: r * 0.6));
    // The bridge and the arms back to the headphones.
    canvas.drawLine(
      c.translate(-r * 0.08, -r * 0.14),
      c.translate(r * 0.08, -r * 0.14),
      frame,
    );
    for (final side in const [-1.0, 1.0]) {
      canvas.drawLine(
        c.translate(side * r * 0.53, -r * 0.16),
        c.translate(side * r * 0.78, -r * 0.12),
        frame,
      );
    }
    final slide = (t * 0.45) % 1.6 - 0.3;
    for (final lens in lenses) {
      final box = lens.getBounds();
      canvas.drawPath(
        lens,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF2A1450).withValues(alpha: a),
              const Color(0xFF0A0618).withValues(alpha: a),
            ],
          ).createShader(box),
      );
      canvas.save();
      canvas.clipPath(lens);
      final x = c.dx - r * 0.6 + slide * r * 1.2;
      canvas.drawPath(
        Path()
          ..moveTo(x, box.top)
          ..lineTo(x + r * 0.12, box.top)
          ..lineTo(x - r * 0.02, box.bottom)
          ..lineTo(x - r * 0.14, box.bottom)
          ..close(),
        Paint()..color = Colors.white.withValues(alpha: 0.45 * a),
      );
      canvas.drawRect(
        Rect.fromLTRB(
          box.left,
          box.bottom - box.height * 0.3,
          box.right,
          box.bottom,
        ),
        Paint()..color = const Color(0xFFFF2E9A).withValues(alpha: 0.25 * a),
      );
      canvas.restore();
      canvas.drawPath(lens, frame);
    }
  }

  /// A pumpkin's ribs curving down his face.
  void _ribs(Canvas canvas, Offset c, double enamelR) {
    final a = pumpkin.clamp(0.0, 1.0);
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: c, radius: enamelR)),
    );
    final rib = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = enamelR * 0.05
      ..color = const Color(0xFF8A3A08).withValues(alpha: 0.45 * a);
    for (final k in const [-0.62, -0.25, 0.25, 0.62]) {
      canvas.drawArc(
        Rect.fromCenter(
          center: c.translate(enamelR * k * 0.4, 0),
          width: enamelR * 2 * k.abs(),
          height: enamelR * 2.1,
        ),
        k < 0 ? math.pi * 0.6 : -math.pi * 0.4,
        math.pi * 0.8,
        false,
        rib,
      );
    }
    canvas.restore();
  }

  /// Carved: triangle eyes, a triangle nose and a jagged grin, all lit by
  /// a candle flickering inside him. The eyes still look about.
  void _carved(Canvas canvas, Offset c, double r) {
    final a = ((pumpkin - 0.5) * 2).clamp(0.0, 1.0);
    final flicker = 0.75 + 0.25 * math.sin(t * 9.3) * math.sin(t * 4.1 + 1.3);
    final shift = Offset(look.dx * r * 0.05, look.dy * r * 0.04);
    final cut = Path();
    for (final side in const [-1.0, 1.0]) {
      final e = c.translate(side * r * 0.3, -r * 0.1) + shift;
      final shut = blink > 0.5;
      if (shut) {
        cut.addRect(
          Rect.fromCenter(center: e, width: r * 0.3, height: r * 0.05),
        );
      } else {
        cut
          ..moveTo(e.dx - r * 0.15, e.dy + r * 0.1)
          ..lineTo(e.dx + side * r * 0.04, e.dy - r * 0.16)
          ..lineTo(e.dx + r * 0.15, e.dy + r * 0.1)
          ..close();
      }
    }
    cut
      ..moveTo(c.dx - r * 0.06, c.dy + r * 0.1)
      ..lineTo(c.dx, c.dy)
      ..lineTo(c.dx + r * 0.06, c.dy + r * 0.1)
      ..close();
    // The grin, with two square teeth left in.
    cut.moveTo(c.dx - r * 0.5, c.dy + r * 0.16);
    cut.quadraticBezierTo(
      c.dx,
      c.dy + r * 0.66,
      c.dx + r * 0.5,
      c.dy + r * 0.16,
    );
    for (final (x, y) in const [
      (0.32, 0.24),
      (0.22, 0.18),
      (0.12, 0.3),
      (-0.06, 0.22),
      (-0.16, 0.3),
      (-0.28, 0.2),
      (-0.36, 0.26),
    ]) {
      cut.lineTo(c.dx + r * x, c.dy + r * y);
    }
    cut.close();
    final spill = Rect.fromCircle(
      center: c.translate(0, r * 0.1),
      radius: r * 0.7,
    );
    canvas.drawOval(
      spill,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFB02A).withValues(alpha: 0.4 * a * flicker),
            const Color(0x00FFB02A),
          ],
        ).createShader(spill),
    );
    canvas.drawPath(
      cut,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF4B8).withValues(alpha: a),
            const Color(0xFFFFC23D).withValues(alpha: a * flicker),
            const Color(0xFFFF7A1A).withValues(alpha: a * flicker),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r * 0.7)),
    );
  }

  /// A crooked witch's hat, its tip bent over, an orange band and buckle.
  void _witchHat(Canvas canvas, Offset c, double r) {
    final a = pumpkin.clamp(0.0, 1.0);
    final sway = math.sin(t * 1.2) * 0.04;
    canvas.save();
    canvas.translate(c.dx - r * 0.05, c.dy - r * 0.8);
    canvas.rotate(-0.16 + sway);
    final felt = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF4A2A66).withValues(alpha: a),
          const Color(0xFF1C0E2A).withValues(alpha: a),
        ],
      ).createShader(Rect.fromLTWH(-r, -r * 1.4, r * 2, r * 1.6));
    // The brim.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, r * 0.08),
        width: r * 1.9,
        height: r * 0.34,
      ),
      felt,
    );
    // The cone, bending over at the tip.
    canvas.drawPath(
      Path()
        ..moveTo(-r * 0.52, r * 0.06)
        ..quadraticBezierTo(-r * 0.3, -r * 0.6, -r * 0.05, -r * 0.95)
        ..quadraticBezierTo(r * 0.2, -r * 1.3, r * 0.62 + sway * r, -r * 1.12)
        ..quadraticBezierTo(r * 0.28, -r * 1.05, r * 0.18, -r * 0.78)
        ..quadraticBezierTo(r * 0.36, -r * 0.4, r * 0.52, r * 0.06)
        ..close(),
      felt,
    );
    canvas.drawRect(
      Rect.fromLTRB(-r * 0.47, -r * 0.14, r * 0.47, r * 0.02),
      Paint()..color = const Color(0xFFE8701A).withValues(alpha: a),
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(0, -r * 0.06),
        width: r * 0.18,
        height: r * 0.16,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.04
        ..color = const Color(0xFFFFD447).withValues(alpha: a),
    );
    canvas.restore();
  }
}
