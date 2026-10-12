import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Every account starts with one of these — a small vector character
/// rendered client-side from just a kind + seed (nothing to upload, nothing
/// to store as an image), so nobody sees a bare initial letter before
/// they've picked a real photo. See `set_generated_avatar` / `avatar_kind` +
/// `avatar_seed` on the profile row.
class GeneratedAvatar extends StatelessWidget {
  const GeneratedAvatar({
    super.key,
    required this.kind,
    required this.seed,
    this.size = 96,
  });

  final String kind;
  final int seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: switch (kind) {
        'animal' => _AnimalAvatarPainter(seed: seed),
        'human' => _HumanAvatarPainter(seed: seed),
        _ => _PlantAvatarPainter(seed: seed),
      },
    );
  }
}

/// How many variants per kind the profile picker offers (seeds 0 to 7).
/// The database assigns and accepts seeds in the same range — keep
/// `set_generated_avatar` / `handle_new_user` in sync if this changes, so
/// the picker can ring the avatar a user currently has.
const int kAvatarChoicesPerKind = 8;

/// Six brand-consistent palettes, cycled by seed — plenty of visible
/// variety between accounts without needing a real color picker.
final List<List<Color>> kAvatarPalettes = [
  [AppColors.accent, Color(0xFF5B32D6)],
  [AppColors.accentSecondary, Color(0xFFE08A00)],
  [AppColors.mint, Color(0xFF00A88C)],
  [AppColors.coral, Color(0xFFE04A4A)],
  [AppColors.sky, Color(0xFF2E86D6)],
  [Color(0xFFB47CFF), Color(0xFF7A3FE0)],
];

const _blushPink = Color(0xFFFF8FA3);

List<Color> _paletteFor(int seed) =>
    kAvatarPalettes[seed % kAvatarPalettes.length];

/// Dark disc + colored rim, then clips all further drawing to the inside
/// of the rim so ears, leaves, hair and shoulders never poke out over it.
/// Callers must `canvas.restore()` when done.
void _beginBackdrop(Canvas canvas, double r, Color accent) {
  final center = Offset(r, r);
  canvas.drawCircle(
    center,
    r * 0.98,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.4),
        colors: [AppColors.surfaceElevated, AppColors.surface],
      ).createShader(Rect.fromCircle(center: center, radius: r)),
  );
  canvas.drawCircle(
    center,
    r * 0.9,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.08
      ..color = accent,
  );
  canvas.save();
  canvas.clipPath(
    Path()..addOval(Rect.fromCircle(center: center, radius: r * 0.86)),
  );
}

Paint _shaded(Color base, Offset center, double radius) {
  return Paint()
    ..shader = RadialGradient(
      center: const Alignment(-0.3, -0.5),
      stops: const [0.0, 0.55, 1.0],
      colors: [
        Color.lerp(base, Colors.white, 0.5)!,
        base,
        Color.lerp(base, Colors.black, 0.22)!,
      ],
    ).createShader(Rect.fromCircle(center: center, radius: radius));
}

/// Two eyes, a smile, pink cheeks, and a small specular glint — the face
/// every character shares, scaled by [s] around [c].
void _face(Canvas canvas, Offset c, double s) {
  final blush = Paint()..color = _blushPink.withValues(alpha: 0.45);
  for (final side in [-1.0, 1.0]) {
    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(side * s * 0.34, s * 0.12),
        width: s * 0.2,
        height: s * 0.12,
      ),
      blush,
    );
  }

  final ink = Paint()..color = AppColors.faceInk;
  final glint = Paint()..color = Colors.white.withValues(alpha: 0.9);
  for (final side in [-1.0, 1.0]) {
    final eye = c + Offset(side * s * 0.17, -s * 0.03);
    canvas.drawCircle(eye, s * 0.065, ink);
    canvas.drawCircle(eye + Offset(-s * 0.02, -s * 0.02), s * 0.022, glint);
  }

  final smile = Path()
    ..moveTo(c.dx - s * 0.13, c.dy + s * 0.14)
    ..quadraticBezierTo(
      c.dx,
      c.dy + s * 0.25,
      c.dx + s * 0.13,
      c.dy + s * 0.14,
    );
  canvas.drawPath(
    smile,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.04
      ..strokeCap = StrokeCap.round
      ..color = AppColors.faceInk,
  );
}

class _PlantAvatarPainter extends CustomPainter {
  _PlantAvatarPainter({required this.seed});
  final int seed;

  static const _leafLight = Color(0xFF8BE36A);
  static const _leafDark = Color(0xFF2E9E4F);

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final palette = _paletteFor(seed);
    _beginBackdrop(canvas, r, palette[0]);

    final body = Offset(r, r * 1.2);
    final bodyTop = body.dy - r * 0.46;
    final sproutTop = Offset(r, bodyTop - r * 0.16);

    // Stem.
    canvas.drawLine(
      Offset(r, bodyTop + r * 0.04),
      sproutTop,
      Paint()
        ..color = _leafDark
        ..strokeWidth = r * 0.07
        ..strokeCap = StrokeCap.round,
    );

    // Leaves: always green (a plant reads as a plant by its leaves, not
    // its body color), splay angle varies with the seed, and odd seeds get
    // a third small upright leaf.
    final splay = 0.95 + (seed % 5) * 0.08;
    void leaf(double angle, double length) {
      canvas.save();
      canvas.translate(sproutTop.dx, sproutTop.dy);
      canvas.rotate(angle);
      final shape = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(length * 0.55, -length * 0.45, 0, -length)
        ..quadraticBezierTo(-length * 0.55, -length * 0.45, 0, 0);
      canvas.drawPath(
        shape,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_leafLight, _leafDark],
          ).createShader(Rect.fromLTWH(-length, -length, length * 2, length)),
      );
      canvas.drawLine(
        Offset.zero,
        Offset(0, -length * 0.8),
        Paint()
          ..color = _leafDark.withValues(alpha: 0.7)
          ..strokeWidth = r * 0.025
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
    }

    leaf(-splay, r * 0.4);
    leaf(splay, r * 0.4);
    if (seed.isOdd) leaf(0, r * 0.28);

    canvas.drawOval(
      Rect.fromCenter(center: body, width: r * 1.05, height: r * 0.92),
      _shaded(palette[0], body, r * 0.55),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: body + Offset(-r * 0.22, -r * 0.24),
        width: r * 0.18,
        height: r * 0.1,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );

    _face(canvas, body + Offset(0, r * 0.02), r);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PlantAvatarPainter oldDelegate) =>
      oldDelegate.seed != seed;
}

class _AnimalAvatarPainter extends CustomPainter {
  _AnimalAvatarPainter({required this.seed});
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final palette = _paletteFor(seed);
    _beginBackdrop(canvas, r, palette[0]);

    final head = Offset(r, r * 1.12);
    final fur = _shaded(palette[0], head, r * 0.62);
    final innerEar = Paint()..color = _blushPink.withValues(alpha: 0.6);

    // Even seeds: pointed cat ears. Odd seeds: round bear ears.
    final pointedEars = seed.isEven;
    for (final side in [-1.0, 1.0]) {
      final ear = head + Offset(side * r * 0.4, -r * 0.46);
      if (pointedEars) {
        Path tri(double scale) => Path()
          ..moveTo(ear.dx - r * 0.17 * scale, ear.dy + r * 0.17 * scale)
          ..lineTo(ear.dx + side * r * 0.04 * scale, ear.dy - r * 0.22 * scale)
          ..lineTo(ear.dx + r * 0.17 * scale, ear.dy + r * 0.17 * scale)
          ..close();
        canvas.drawPath(tri(1), fur);
        canvas.drawPath(tri(0.55), innerEar);
      } else {
        canvas.drawCircle(ear, r * 0.17, fur);
        canvas.drawCircle(ear, r * 0.09, innerEar);
      }
    }

    canvas.drawOval(
      Rect.fromCenter(center: head, width: r * 1.12, height: r * 0.98),
      fur,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: head + Offset(-r * 0.24, -r * 0.26),
        width: r * 0.2,
        height: r * 0.1,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.5),
    );

    // Muzzle + nose.
    canvas.drawOval(
      Rect.fromCenter(
        center: head + Offset(0, r * 0.16),
        width: r * 0.46,
        height: r * 0.3,
      ),
      Paint()..color = Color.lerp(palette[0], Colors.white, 0.78)!,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: head + Offset(0, r * 0.08),
        width: r * 0.1,
        height: r * 0.07,
      ),
      Paint()..color = AppColors.faceInk,
    );

    _face(canvas, head + Offset(0, -r * 0.02), r * 0.95);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AnimalAvatarPainter oldDelegate) =>
      oldDelegate.seed != seed;
}

class _HumanAvatarPainter extends CustomPainter {
  _HumanAvatarPainter({required this.seed});
  final int seed;

  // Four skin tones, each paired with two different hair styles across the
  // eight seeds (skin = seed ~/ 2, hair style = seed % 4), so the picker
  // shows a genuinely varied set of people rather than one face recolored.
  static const _skinTones = [
    Color(0xFFF6D5B8),
    Color(0xFFE3B28A),
    Color(0xFFC0855B),
    Color(0xFF8A5638),
  ];
  static const _hairColors = [
    Color(0xFF3B2A20),
    Color(0xFF1E1A1A),
    Color(0xFFE0B456),
    Color(0xFF9A4A2B),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final palette = _paletteFor(seed);
    _beginBackdrop(canvas, r, palette[0]);

    final skin = _skinTones[(seed ~/ 2) % _skinTones.length];
    final hairColor = _hairColors[(seed * 3 + 1) % _hairColors.length];
    final hairStyle = seed % 4;
    final hair = Paint()..color = hairColor;

    final face = Offset(r, r * 0.98);
    final a = r * 0.36; // face half-width
    final b = r * 0.41; // face half-height

    // Long hair falls behind the head and shoulders.
    if (hairStyle == 2) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            face.dx - a - r * 0.08,
            face.dy - b * 0.6,
            face.dx + a + r * 0.08,
            face.dy + r * 0.62,
          ),
          Radius.circular(r * 0.2),
        ),
        hair,
      );
    }

    // Shoulders: a symmetric shirt in the palette color, clipped by the rim.
    final shoulders = Offset(r, r * 1.95);
    canvas.drawOval(
      Rect.fromCenter(center: shoulders, width: r * 1.35, height: r * 0.95),
      _shaded(palette[0], shoulders, r * 0.7),
    );

    // Neck.
    canvas.drawRect(
      Rect.fromCenter(
        center: face + Offset(0, b + r * 0.02),
        width: r * 0.26,
        height: r * 0.2,
      ),
      Paint()..color = Color.lerp(skin, Colors.black, 0.12)!,
    );

    // Head.
    canvas.drawOval(
      Rect.fromCenter(center: face, width: a * 2, height: b * 2),
      _shaded(skin, face, b),
    );

    // Hair cap: a dome over the top of the head with a swept fringe for a
    // hairline, rather than a flat wedge across the face.
    final cap = Path()
      ..moveTo(face.dx - a - r * 0.03, face.dy - r * 0.02)
      ..cubicTo(
        face.dx - a - r * 0.06,
        face.dy - b - r * 0.28,
        face.dx + a + r * 0.06,
        face.dy - b - r * 0.28,
        face.dx + a + r * 0.03,
        face.dy - r * 0.02,
      )
      ..quadraticBezierTo(
        face.dx + a * 0.55,
        face.dy - b * 0.45,
        face.dx + r * 0.04,
        face.dy - b * 0.6,
      )
      ..quadraticBezierTo(
        face.dx - a * 0.6,
        face.dy - b * 0.4,
        face.dx - a - r * 0.03,
        face.dy - r * 0.02,
      )
      ..close();
    canvas.drawPath(cap, hair);

    if (hairStyle == 1) {
      // Top bun.
      canvas.drawCircle(face + Offset(0, -b - r * 0.14), r * 0.14, hair);
    } else if (hairStyle == 3) {
      // Curls along the crown.
      for (var i = 0; i < 5; i++) {
        final t = i / 4;
        final x = face.dx + (t - 0.5) * a * 1.8;
        final y = face.dy - b - r * 0.06 + (t - 0.5).abs() * r * 0.18;
        canvas.drawCircle(Offset(x, y), r * 0.1, hair);
      }
    }

    _face(canvas, face + Offset(0, r * 0.06), r * 0.9);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HumanAvatarPainter oldDelegate) =>
      oldDelegate.seed != seed;
}
