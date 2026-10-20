part of 'coin_buddy.dart';

// What's drawn around Chip: his glow and mood props, the costume parts behind him, and his thinking dots.

/// Behind and around Chip: the hover glow and shadow, plus mood props (a
/// halo and hearts when peaceful, a red aura when evil, sparkles when
/// excited).
class _AuraPainter extends CustomPainter {
  _AuraPainter({
    required this.mood,
    this.flavor = ChipFlavor.none,
    required this.t,
    required this.center,
    required this.radius,
    required this.lift,
    required this.sinceMood,
  });

  final BuddyMood mood;
  final ChipFlavor flavor;
  final double t;
  final Offset center;
  final double radius;
  final double lift;
  final double sinceMood;

  @override
  void paint(Canvas canvas, Size size) {
    final ground = Offset(size.width / 2, size.height * 0.97);
    final hover = (1 - lift * 3).clamp(0.4, 1.2);

    // Hover glow pad and soft shadow.
    canvas.save();
    canvas.translate(ground.dx, ground.dy);
    canvas.scale(1, 0.24);
    final pad = Rect.fromCircle(center: Offset.zero, radius: radius * 1.1);
    canvas.drawCircle(
      Offset.zero,
      radius * 1.1 * hover,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.glowRing.withValues(alpha: 0.45),
            AppColors.glowRing.withValues(alpha: 0),
          ],
        ).createShader(pad),
    );
    canvas.drawCircle(
      Offset.zero,
      radius * 0.7 * hover,
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );
    canvas.restore();

    switch (mood) {
      case BuddyMood.evil:
        final pulse = 0.7 + 0.3 * math.sin(t * 6);
        canvas.drawCircle(
          center,
          radius * 1.7,
          Paint()
            ..shader =
                RadialGradient(
                  colors: [
                    const Color(0xFFFF3D6E).withValues(alpha: 0.35 * pulse),
                    const Color(0x00FF3D6E),
                  ],
                ).createShader(
                  Rect.fromCircle(center: center, radius: radius * 1.7),
                ),
        );
      case BuddyMood.peaceful:
        // Halo, settling in from above.
        final drop = Curves.easeOutBack.transform(
          (sinceMood / 0.8).clamp(0.0, 1.0),
        );
        final halo = center.translate(
          0,
          -radius * (1.55 + 0.6 * (1 - drop)) + math.sin(t * 2) * 2,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: halo,
            width: radius * 1.1,
            height: radius * 0.32,
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = radius * 0.1
            ..color = const Color(0xFFFFE29A).withValues(alpha: drop),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: halo,
            width: radius * 1.4,
            height: radius * 0.5,
          ),
          Paint()
            ..color = const Color(0xFFFFE29A).withValues(alpha: 0.18 * drop),
        );
        for (var i = 0; i < 4; i++) {
          final life = (t * 0.45 + i / 4) % 1.0;
          final p = center.translate(
            (i.isEven ? -1 : 1) * radius * (0.9 + 0.2 * math.sin(t + i)),
            -life * radius * 2.2,
          );
          _heart(canvas, p, radius * 0.16, math.sin(life * math.pi));
        }
      case BuddyMood.excited:
        for (var i = 0; i < 8; i++) {
          final a = t * 3 + i * math.pi / 4;
          final p = center + Offset(math.cos(a), math.sin(a)) * radius * 1.45;
          canvas.drawCircle(
            p,
            radius * 0.05 * (0.6 + 0.4 * math.sin(t * 8 + i)),
            Paint()..color = const Color(0xFFFFE29A),
          );
        }
      case BuddyMood.vibing:
        // Music notes floating up out of the headphones: hearts for a love
        // song, a halo for worship, sparkles flying for a hype track.
        final speed = switch (flavor) {
          ChipFlavor.hype || ChipFlavor.dance => 0.55,
          ChipFlavor.sad || ChipFlavor.worship => 0.2,
          _ => 0.32,
        };
        if (flavor == ChipFlavor.worship) _vibeHalo(canvas);
        for (var i = 0; i < 5; i++) {
          final life = (t * speed + i / 5) % 1.0;
          final side = i.isEven ? -1.0 : 1.0;
          final p = center.translate(
            side * radius * (1.1 + 0.35 * life) +
                math.sin(t * 2 + i) * radius * 0.1,
            -radius * 0.1 - life * radius * 1.8,
          );
          final a = math.sin(life * math.pi);
          if (flavor == ChipFlavor.romantic) {
            _heart(canvas, p, radius * 0.16, a);
          } else if (flavor == ChipFlavor.sad) {
            _note(canvas, p, radius * 0.18, a * 0.7, 1);
          } else {
            _note(canvas, p, radius * 0.2, a, i);
          }
        }
        if (flavor == ChipFlavor.hype || flavor == ChipFlavor.dance) {
          for (var i = 0; i < 6; i++) {
            final ang = t * 2.4 + i * math.pi / 3;
            final p =
                center + Offset(math.cos(ang), math.sin(ang)) * radius * 1.5;
            canvas.drawCircle(
              p,
              radius * 0.045 * (0.6 + 0.4 * math.sin(t * 9 + i)),
              Paint()..color = const Color(0xFFFFE29A),
            );
          }
        }
      case BuddyMood.listening:
        // Soft sound waves rolling out from both ear cups.
        final wave = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = radius * 0.06;
        for (final side in const [-1.0, 1.0]) {
          for (var i = 0; i < 3; i++) {
            final life = (t * 0.55 + i / 3) % 1.0;
            final rr = radius * (0.25 + 0.55 * life);
            wave.color = const Color(
              0xFF7DF5DA,
            ).withValues(alpha: 0.75 * math.sin(life * math.pi));
            canvas.drawArc(
              Rect.fromCircle(
                center: center.translate(side * radius * 1.05, 0),
                radius: rr,
              ),
              side > 0 ? -0.6 : math.pi - 0.6,
              1.2,
              false,
              wave,
            );
          }
        }
      case BuddyMood.watching:
        // Little play sparks drifting up, like light off a screen.
        for (var i = 0; i < 4; i++) {
          final life = (t * 0.28 + i / 4) % 1.0;
          final side = i.isEven ? -1.0 : 1.0;
          final p = center.translate(
            side * radius * (0.95 + 0.3 * life) +
                math.sin(t * 1.6 + i) * radius * 0.08,
            -radius * 0.2 - life * radius * 1.6,
          );
          final s = radius * 0.17;
          final alpha = math.sin(life * math.pi);
          switch (flavor) {
            case ChipFlavor.study:
              // Little bright ideas floating up.
              canvas.drawCircle(
                p,
                s * 0.42,
                Paint()
                  ..color = const Color(0xFFFFE29A).withValues(alpha: alpha),
              );
              canvas.drawCircle(
                p,
                s * 0.75,
                Paint()
                  ..color = const Color(
                    0xFFFFE29A,
                  ).withValues(alpha: 0.25 * alpha),
              );
            case ChipFlavor.gaming:
              // Pixels.
              canvas.drawRect(
                Rect.fromCenter(center: p, width: s * 0.7, height: s * 0.7),
                Paint()
                  ..color = [
                    const Color(0xFF7DF5DA),
                    const Color(0xFFFF9ECF),
                  ][i % 2].withValues(alpha: alpha),
              );
            default:
              final play = Path()
                ..moveTo(p.dx - s * 0.4, p.dy - s * 0.5)
                ..lineTo(p.dx + s * 0.55, p.dy)
                ..lineTo(p.dx - s * 0.4, p.dy + s * 0.5)
                ..close();
              canvas.drawPath(
                play,
                Paint()
                  ..color = [
                    const Color(0xFFFF9ECF),
                    const Color(0xFF8FD3FF),
                  ][i % 2].withValues(alpha: alpha),
              );
          }
        }
      case BuddyMood.hot:
        // A shimmer of heat round him.
        final pulse = 0.7 + 0.3 * math.sin(t * 5);
        canvas.drawCircle(
          center,
          radius * 1.6,
          Paint()
            ..shader =
                RadialGradient(
                  colors: [
                    const Color(0xFFFF6A1F).withValues(alpha: 0.38 * pulse),
                    const Color(0x00FF6A1F),
                  ],
                ).createShader(
                  Rect.fromCircle(center: center, radius: radius * 1.6),
                ),
        );
      case BuddyMood.idle:
      case BuddyMood.thinking:
      case BuddyMood.happy:
      case BuddyMood.sad:
        break;
    }
  }

  /// A soft gold halo over Chip, for worship songs.
  void _vibeHalo(Canvas canvas) {
    final halo = center.translate(0, -radius * 1.55 + math.sin(t * 1.4) * 2);
    canvas.drawOval(
      Rect.fromCenter(center: halo, width: radius * 1.4, height: radius * 0.5),
      Paint()..color = const Color(0xFFFFE29A).withValues(alpha: 0.16),
    );
    canvas.drawOval(
      Rect.fromCenter(center: halo, width: radius * 1.1, height: radius * 0.32),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.08
        ..color = const Color(0xFFFFE29A),
    );
  }

  /// A little eighth note (or a pair, beamed).
  void _note(Canvas canvas, Offset p, double s, double alpha, int i) {
    final colors = [
      const Color(0xFFFFE29A),
      const Color(0xFF7DF5DA),
      const Color(0xFFFF9ECF),
    ];
    final paint = Paint()..color = colors[i % 3].withValues(alpha: alpha);
    final stem = Paint()
      ..color = paint.color
      ..strokeWidth = s * 0.18
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(
      Rect.fromCenter(center: p, width: s * 0.75, height: s * 0.55),
      paint,
    );
    final top = p.translate(s * 0.32, -s * 1.3);
    canvas.drawLine(p.translate(s * 0.32, 0), top, stem);
    if (i.isEven) {
      final p2 = p.translate(s * 0.9, -s * 0.2);
      canvas.drawOval(
        Rect.fromCenter(center: p2, width: s * 0.75, height: s * 0.55),
        paint,
      );
      final top2 = p2.translate(s * 0.32, -s * 1.3);
      canvas.drawLine(p2.translate(s * 0.32, 0), top2, stem);
      canvas.drawLine(top, top2, stem..strokeWidth = s * 0.26);
    } else {
      canvas.drawLine(top, top.translate(s * 0.4, s * 0.35), stem);
    }
  }

  void _heart(Canvas canvas, Offset c, double s, double alpha) {
    final path = Path()
      ..moveTo(c.dx, c.dy + s * 0.9)
      ..cubicTo(
        c.dx - s * 1.4,
        c.dy - s * 0.1,
        c.dx - s * 0.6,
        c.dy - s,
        c.dx,
        c.dy - s * 0.35,
      )
      ..cubicTo(
        c.dx + s * 0.6,
        c.dy - s,
        c.dx + s * 1.4,
        c.dy - s * 0.1,
        c.dx,
        c.dy + s * 0.9,
      )
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = const Color(0xFFFF8FB8).withValues(alpha: alpha),
    );
  }

  @override
  bool shouldRepaint(covariant _AuraPainter oldDelegate) => true;
}

/// "…" thought bubbles rising beside Chip while it thinks.
/// What a set puts behind him: Heaven's feathered wings, beating gently,
/// and Hell's swishing spade-tipped tail.
class _CostumeBackPainter extends CustomPainter {
  _CostumeBackPainter({
    required this.t,
    required this.center,
    required this.radius,
    required this.angel,
    required this.devil,
    this.dj = 0,
    this.pumpkin = 0,
  });

  final double t;
  final Offset center;
  final double radius;
  final double angel;
  final double devil;
  final double dj;
  final double pumpkin;

  @override
  void paint(Canvas canvas, Size size) {
    if (angel > 0) _wings(canvas);
    if (devil > 0) _tail(canvas);
    if (dj > 0) _beatNotes(canvas);
    if (pumpkin > 0) _bats(canvas);
  }

  /// Jack-o'-lantern Chip: two little bats circling him.
  void _bats(Canvas canvas) {
    final r = radius;
    final ink = Paint()
      ..color = const Color(
        0xFF14081E,
      ).withValues(alpha: pumpkin.clamp(0.0, 1.0));
    for (var i = 0; i < 2; i++) {
      final a = t * 1.6 + i * math.pi;
      final p =
          center +
          Offset(math.cos(a) * r * 1.5, math.sin(a) * r * 0.5 - r * 0.7);
      final s = r * 0.13;
      final flap = math.sin(t * 16 + i);
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
        ink,
      );
    }
  }

  /// DJ Chip: notes popping out of his headphones on the beat and floating
  /// away, and a ring of sound pulsing out behind him.
  void _beatNotes(Canvas canvas) {
    final r = radius;
    final beats = worldSeconds * 2;
    final hit = math.exp(-(beats % 1.0) * 5);
    canvas.drawCircle(
      center,
      r * (1.2 + 0.25 * (beats % 1.0)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.06
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.35 * dj * hit),
    );
    const colors = [Color(0xFFFF2E9A), Color(0xFF00E5FF), Color(0xFFC6FF3D)];
    for (var i = 0; i < 4; i++) {
      final k = ((beats + i) / 4) % 1.0;
      final side = i.isEven ? -1.0 : 1.0;
      final p = center.translate(
        side * r * (1.05 + 0.5 * k),
        -r * (0.1 + 1.3 * k) + math.sin(k * 9) * r * 0.06,
      );
      final s = r * 0.22 * (0.6 + 0.4 * math.sin(k * math.pi));
      final paint = Paint()
        ..color = colors[i % 3].withValues(alpha: dj * math.sin(k * math.pi));
      canvas.drawOval(
        Rect.fromCenter(center: p, width: s, height: s * 0.72),
        paint,
      );
      canvas.drawRect(
        Rect.fromLTWH(p.dx + s * 0.34, p.dy - s * 1.5, s * 0.16, s * 1.5),
        paint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(p.dx + s * 0.5, p.dy - s * 1.5)
          ..quadraticBezierTo(
            p.dx + s * 1.1,
            p.dy - s * 1.1,
            p.dx + s * 0.85,
            p.dy - s * 0.6,
          ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.16
          ..color = paint.color,
      );
    }
  }

  void _wings(Canvas canvas) {
    final r = radius;
    final beat = math.sin(t * 2.6);
    final feather = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: angel),
          const Color(0xFFFFF1C4).withValues(alpha: angel),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: r * 2));
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.025
      ..color = const Color(0xFFD9C79A).withValues(alpha: 0.7 * angel);
    for (final side in const [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(center.dx + side * r * 0.75, center.dy - r * 0.15);
      canvas.scale(side, 1);
      canvas.rotate(-0.35 + beat * 0.2);
      // Three rows of feathers fanning out and up, longest at the back.
      for (var row = 0; row < 3; row++) {
        for (var k = 0; k < 4 - row; k++) {
          final len = r * (0.95 - row * 0.22 - k * 0.1);
          final at = Offset(r * (0.18 + k * 0.17), -r * (0.1 + row * 0.08));
          canvas.save();
          canvas.translate(at.dx, at.dy);
          canvas.rotate(-0.9 + k * 0.32);
          final f = Rect.fromLTWH(0, -r * 0.09, len, r * 0.18);
          canvas.drawOval(f, feather);
          canvas.drawOval(f, edge);
          canvas.restore();
        }
      }
      canvas.restore();
    }
  }

  void _tail(Canvas canvas) {
    final r = radius;
    final swish = math.sin(t * 2.2) * r * 0.18;
    final start = center.translate(r * 0.45, r * 0.75);
    final end = center.translate(r * 1.35, r * 0.15 + swish);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.09
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFB0141E).withValues(alpha: devil);
    canvas.drawPath(
      Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(
          center.dx + r * 1.25,
          center.dy + r * 0.95 + swish * 0.5,
          end.dx,
          end.dy,
        ),
      paint,
    );
    // The spade tip.
    final tip = Paint()
      ..color = const Color(0xFFD9262E).withValues(alpha: devil);
    canvas.drawPath(
      Path()
        ..moveTo(end.dx, end.dy - r * 0.2)
        ..quadraticBezierTo(
          end.dx + r * 0.18,
          end.dy - r * 0.02,
          end.dx + r * 0.03,
          end.dy + r * 0.06,
        )
        ..lineTo(end.dx - r * 0.03, end.dy + r * 0.06)
        ..quadraticBezierTo(
          end.dx - r * 0.18,
          end.dy - r * 0.02,
          end.dx,
          end.dy - r * 0.2,
        )
        ..close(),
      tip,
    );
  }

  @override
  bool shouldRepaint(covariant _CostumeBackPainter oldDelegate) => true;
}

class _ThoughtDotsPainter extends CustomPainter {
  _ThoughtDotsPainter({
    required this.t,
    required this.origin,
    required this.scale,
  });

  final double t;
  final Offset origin;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 3; i++) {
      final bob = math.sin(t * 3 + i) * scale * 0.012;
      final p = origin.translate(i * scale * 0.08, -i * scale * 0.1 + bob);
      final r = scale * (0.025 + i * 0.015);
      canvas.drawCircle(
        p,
        r,
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
      canvas.drawCircle(
        p,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = AppColors.glowRing,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ThoughtDotsPainter oldDelegate) => true;
}
