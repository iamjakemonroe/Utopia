part of 'aura_frame.dart';

/// The Zombie Bite frame's shapes for a picture of radius 1 at the
/// origin, built once (path operations are too slow to redo every
/// frame) and scaled to each picture: the chunk bitten out, top right (a
/// round bite edged with tooth marks, right through the rim and into
/// the picture), the rim with the bite gone, the frame with the picture
/// in it, everywhere but the bite, and everywhere but where the bite
/// goes through the frame.
final _biteShapes = () {
  final at = _dir(-0.75) * 1.06;
  var bite = Path()..addOval(Rect.fromCircle(center: at, radius: 0.27));
  for (var k = 0; k < 13; k++) {
    final a = k * 2 * math.pi / 13 + 0.2;
    bite = Path.combine(
      PathOperation.union,
      bite,
      Path()..addOval(
        Rect.fromCircle(
          center: at + _dir(a) * 0.272,
          radius: 0.05 + 0.014 * _rand(k, 98),
        ),
      ),
    );
  }
  final whole = Path()
    ..addOval(Rect.fromCircle(center: Offset.zero, radius: 1.13))
    ..addOval(Rect.fromCircle(center: Offset.zero, radius: 0.97))
    ..fillType = PathFillType.evenOdd;
  final disc = Path()
    ..addOval(Rect.fromCircle(center: Offset.zero, radius: 1.13));
  final everywhere = Path()
    ..addRect(Rect.fromCircle(center: Offset.zero, radius: 3));
  return (
    bite: bite,
    disc: disc,
    band: Path.combine(PathOperation.difference, whole, bite),
    // Nothing is ever drawn in the bite: not the picture, nor the frame's
    // own edges.
    unbitten: Path.combine(PathOperation.difference, everywhere, bite),
    // Where the bite goes through the frame and picture: the glow behind
    // is cut away there too (and fades out round it, see _zombie).
    gapless: Path.combine(
      PathOperation.difference,
      everywhere,
      Path.combine(PathOperation.intersect, bite, disc),
    ),
  );
}();

/// Zombie Bite: a chunk bitten out of the picture, and hands clawing at it.
extension _ZombieFrame on AuraPainter {
  /// Undead, not on fire: the frame turns to rotting, stitched-up skin with
  /// a bite taken clean out of it (nothing there, not even the glow behind:
  /// just tooth marks round the gap), two zombie hands claw up from below
  /// to grab it, slime drips off the bottom and flies buzz round.
  void _zombie(Canvas canvas, Offset c, double r, double t) {
    const skin = Color(0xFF8C9E72);
    const skinDark = Color(0xFF5E6E48);
    const ink = Color(0xFF26301C);
    const slime = Color(0xFF9DFF5A);
    final fit = (Matrix4.translationValues(
      c.dx,
      c.dy,
      0,
    )..scaleByDouble(r, r, 1, 1)).storage;
    final bite = _biteShapes.bite.transform(fit);
    // Everything but the bitten-out gap.
    final unbitten = _biteShapes.unbitten.transform(fit);

    if (!front) {
      canvas.saveLayer(Rect.fromCircle(center: c, radius: r * 2.2), Paint());
      canvas.clipPath(_biteShapes.gapless.transform(fit));
      // Sickly green mist pooling round the bottom, rising and fading.
      for (var i = 0; i < 9; i++) {
        final life = (t * 0.12 + _rand(i, 91)) % 1;
        final a = math.pi * (0.1 + 0.8 * _rand(i, 92));
        final p =
            c +
            _dir(a) * r * (0.9 + 0.25 * _rand(i, 93)) +
            Offset(0, -life * r * 0.6);
        canvas.drawCircle(
          p,
          r * (0.22 + 0.12 * _rand(i, 94)),
          Paint()
            ..color = const Color(
              0xFF7FD957,
            ).withValues(alpha: 0.28 * math.sin(life * math.pi))
            ..maskFilter = _blur(r * 0.14),
        );
      }
      _glowRing(
        canvas,
        c,
        r,
        const Color(0xFF7DFF3D).withValues(alpha: 0.28),
        width: 0.22,
        blur: 0.22,
        scale: 1.06,
      );
      // The glow fades away round the bite, so nothing shows through the
      // gap and no outline of it hangs outside the frame.
      canvas.drawCircle(
        c + _dir(-0.75) * r * 1.06,
        r * 0.42,
        Paint()
          ..blendMode = BlendMode.dstOut
          ..maskFilter = _blur(r * 0.06),
      );
      canvas.restore();
      return;
    }

    // The rotting rim, with the bite gone from it.
    final outerR = r * 1.13;
    final innerR = r * 0.97;
    final band = _biteShapes.band.transform(fit);
    canvas.drawPath(band, Paint()..color = skin);
    canvas.save();
    canvas.clipPath(band);
    // Rot blotches and bruises.
    for (var i = 0; i < 14; i++) {
      final a = _rand(i, 95) * 2 * math.pi;
      final p = c + _dir(a) * r * (1.0 + 0.12 * _rand(i, 96));
      canvas.drawCircle(
        p,
        r * (0.05 + 0.06 * _rand(i, 97)),
        Paint()
          ..color = (i % 4 == 0 ? const Color(0xFF6E4A6A) : skinDark)
              .withValues(alpha: 0.55),
      );
    }
    canvas.restore();

    // From here on, nothing reaches into the bite.
    canvas.save();
    canvas.clipPath(unbitten);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.03
      ..color = ink;
    canvas.drawCircle(c, outerR, edge);
    canvas.drawCircle(c, innerR, edge);

    // Two stitched-up cuts along the rim.
    for (final (start, len) in const [(2.2, 0.75), (4.75, 0.6)]) {
      final mid = (outerR + innerR) / 2;
      final cut = Path();
      for (var k = 0; k <= 10; k++) {
        final p = c + _dir(start + len * k / 10) * mid;
        k == 0 ? cut.moveTo(p.dx, p.dy) : cut.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        cut,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.025
          ..color = const Color(0xFF4A1E24),
      );
      for (var k = 1; k < 6; k++) {
        final a = start + len * k / 6;
        final n = _dir(a);
        final tg = _dir(a + math.pi / 2);
        final p = c + n * mid;
        canvas.drawLine(
          p - n * r * 0.065 - tg * r * 0.015,
          p + n * r * 0.065 + tg * r * 0.015,
          Paint()
            ..strokeWidth = r * 0.022
            ..strokeCap = StrokeCap.round
            ..color = ink,
        );
      }
    }

    // The bitten edge, through the rim and the picture: torn skin, darker
    // where the teeth went in (drawn twice as wide, since the half inside
    // the bite is clipped away), and a drip of slime running off it.
    canvas.clipPath(_biteShapes.disc.transform(fit));
    canvas.drawPath(
      bite,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.14
        ..color = skinDark,
    );
    canvas.drawPath(
      bite,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.056
        ..strokeJoin = StrokeJoin.round
        ..color = ink,
    );
    canvas.restore();
    canvas.save();
    canvas.clipPath(unbitten);
    final ooze = (t * 0.5) % 1;
    final dropStart = c + _dir(-0.75 - 0.3) * innerR;
    canvas.drawLine(
      dropStart,
      dropStart.translate(0, r * 0.25 * ooze),
      Paint()
        ..strokeWidth = r * 0.04
        ..strokeCap = StrokeCap.round
        ..color = slime.withValues(alpha: 0.9 * (1 - ooze * 0.6)),
    );
    canvas.restore();

    // Slime dripping off the bottom.
    for (var i = 0; i < 3; i++) {
      final life = (t * 0.45 + i * 0.37) % 1;
      final x = c.dx + (i - 1) * r * 0.42;
      final y0 =
          c.dy +
          math.sqrt(math.max(0.0, outerR * outerR - math.pow(x - c.dx, 2))) -
          r * 0.02;
      final len = r * 0.35 * Curves.easeIn.transform(life);
      final a = 1 - life;
      canvas.drawLine(
        Offset(x, y0),
        Offset(x, y0 + len),
        Paint()
          ..strokeWidth = r * 0.035
          ..strokeCap = StrokeCap.round
          ..color = slime.withValues(alpha: 0.85 * a),
      );
      canvas.drawCircle(
        Offset(x, y0 + len),
        r * 0.045,
        Paint()..color = slime.withValues(alpha: 0.9 * a),
      );
    }

    // Two hands clawing up from below to grab the frame, tugging now and
    // then.
    for (final (side, phase) in const [(-1.0, 0.0), (1.0, 1.7)]) {
      final cycle = (t * 0.55 + phase) % 1;
      final tug = cycle < 0.15
          ? math.sin(cycle / 0.15 * math.pi) * r * 0.07
          : 0.0;
      final grip = 0.5 + 0.5 * math.sin(t * 2.2 + phase * 3);
      final wrist =
          c +
          Offset(side * r * 0.62, r * 1.02 + tug) +
          Offset(0, math.sin(t * 1.3 + phase) * r * 0.025);
      _zombieHand(
        canvas,
        wrist,
        // Leaning in toward the middle.
        side * -0.42,
        r,
        grip,
        side,
        skin,
        skinDark,
        ink,
      );
    }

    // Flies buzzing round the top.
    for (var i = 0; i < 3; i++) {
      final p =
          c +
          Offset(
            math.cos(t * 2.6 + i * 2.1) * r * 1.2 +
                math.sin(t * 9.3 + i) * r * 0.06,
            -r * 0.95 +
                math.sin(t * 3.7 + i * 1.7) * r * 0.22 +
                math.cos(t * 11 + i) * r * 0.04,
          );
      final flap = 0.5 + 0.5 * math.sin(t * 60 + i);
      for (final s in const [-1.0, 1.0]) {
        canvas.drawOval(
          Rect.fromCenter(
            center: p.translate(s * r * 0.03, -r * 0.03),
            width: r * 0.05,
            height: r * 0.035 * (0.4 + 0.6 * flap),
          ),
          Paint()..color = Colors.white.withValues(alpha: 0.6),
        );
      }
      canvas.drawCircle(p, r * 0.038, Paint()..color = const Color(0xFF151515));
    }
  }

  /// A rotting hand reaching up from below: torn sleeve, bony fingers
  /// hooking over the frame. [lean] tilts it (radians), [grip] 0..1 curls
  /// the fingers.
  void _zombieHand(
    Canvas canvas,
    Offset wrist,
    double lean,
    double r,
    double grip,
    double side,
    Color skin,
    Color skinDark,
    Color ink,
  ) {
    final up = Offset(math.sin(lean), -math.cos(lean));
    final across = Offset(-up.dy, up.dx);
    final w = r * 0.1;
    Paint stroke(Color color, double width) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    // Forearm, then the hand on top.
    final elbow = wrist - up * r * 0.55;
    final palm = wrist + up * r * 0.12;
    final fingers = <List<Offset>>[];
    for (var k = 0; k < 4; k++) {
      final spread = (k - 1.5) * 0.28;
      final d1 = Offset(
        up.dx * math.cos(spread) - up.dy * math.sin(spread),
        up.dx * math.sin(spread) + up.dy * math.cos(spread),
      );
      final base = palm + across * ((k - 1.5) * r * 0.085) + up * r * 0.07;
      final knuckle = base + d1 * r * (k == 0 || k == 3 ? 0.16 : 0.2);
      // Curl toward the middle of the picture.
      final curl = (0.6 + 0.6 * grip) * -side;
      final d2 = Offset(
        d1.dx * math.cos(curl) - d1.dy * math.sin(curl),
        d1.dx * math.sin(curl) + d1.dy * math.cos(curl),
      );
      final tip = knuckle + d2 * r * 0.13;
      fingers.add([base, knuckle, tip]);
    }
    final thumbBase = palm + across * (side * r * 0.15);
    final thumbTip = thumbBase + (across * side + up) * (r * 0.11);

    // Dark outline pass, then skin on top.
    for (final (color, extra) in [(ink, r * 0.045), (skin, 0.0)]) {
      canvas.drawLine(elbow, wrist, stroke(color, w * 1.5 + extra));
      canvas.drawCircle(palm, r * 0.18 + extra / 2, Paint()..color = color);
      for (final f in fingers) {
        canvas.drawPath(
          Path()
            ..moveTo(f[0].dx, f[0].dy)
            ..lineTo(f[1].dx, f[1].dy)
            ..lineTo(f[2].dx, f[2].dy),
          stroke(color, w + extra),
        );
      }
      canvas.drawLine(thumbBase, thumbTip, stroke(color, w + extra));
    }
    // Shading and rot on the palm.
    canvas.drawCircle(
      palm.translate(-side * r * 0.04, r * 0.04),
      r * 0.07,
      Paint()..color = skinDark.withValues(alpha: 0.6),
    );
    // Dark nails, and one bony fingertip.
    for (final (k, f) in fingers.indexed) {
      canvas.drawCircle(
        f[2],
        w * 0.32,
        Paint()
          ..color = k == 2 ? const Color(0xFFF0E8D0) : const Color(0xFF2E2620),
      );
    }
    // A ragged sleeve cuff.
    final cuff = Path();
    final c0 = wrist - up * r * 0.26;
    final end = elbow - up * r * 0.12;
    for (var k = 0; k <= 6; k++) {
      final u = k / 6 - 0.5;
      final p =
          c0 + across * (u * r * 0.3) + up * ((k.isEven ? 0.0 : 0.06) * r);
      k == 0 ? cuff.moveTo(p.dx, p.dy) : cuff.lineTo(p.dx, p.dy);
    }
    cuff
      ..lineTo((end + across * r * 0.16).dx, (end + across * r * 0.16).dy)
      ..lineTo((end - across * r * 0.16).dx, (end - across * r * 0.16).dy)
      ..close();
    canvas.drawPath(cuff, Paint()..color = const Color(0xFF4A3B5C));
    canvas.drawPath(cuff, stroke(ink, r * 0.02));
  }
}
