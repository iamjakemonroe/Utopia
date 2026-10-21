import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/sprite_cache.dart';
import '../../domain/eights_engine.dart';

/// Height / width of a card.
const double kCardAspect = 1.4;

const Color kSuitRed = Color(0xFFE8284F);
const Color kSuitInk = Color(0xFF26234A);

Color suitColor(CardSuit suit) => suit.red ? kSuitRed : kSuitInk;

/// A suit's shape, in a box from -1 to 1 each way.
Path suitPath(CardSuit suit) => switch (suit) {
  CardSuit.hearts => _heart,
  CardSuit.diamonds => _diamond,
  CardSuit.spades => _spade,
  CardSuit.clubs => _club,
};

final Path _heart = Path()
  ..moveTo(0, 0.92)
  ..cubicTo(-0.55, 0.45, -1.0, 0.1, -1.0, -0.38)
  ..cubicTo(-1.0, -0.78, -0.68, -0.98, -0.44, -0.98)
  ..cubicTo(-0.2, -0.98, -0.05, -0.82, 0, -0.62)
  ..cubicTo(0.05, -0.82, 0.2, -0.98, 0.44, -0.98)
  ..cubicTo(0.68, -0.98, 1.0, -0.78, 1.0, -0.38)
  ..cubicTo(1.0, 0.1, 0.55, 0.45, 0, 0.92)
  ..close();

final Path _diamond = Path()
  ..moveTo(0, -1)
  ..quadraticBezierTo(0.32, -0.42, 0.78, 0)
  ..quadraticBezierTo(0.32, 0.42, 0, 1)
  ..quadraticBezierTo(-0.32, 0.42, -0.78, 0)
  ..quadraticBezierTo(-0.32, -0.42, 0, -1)
  ..close();

final Path _spade = Path()
  ..moveTo(0, -0.98)
  ..cubicTo(0.3, -0.58, 1.0, -0.28, 1.0, 0.2)
  ..cubicTo(1.0, 0.56, 0.72, 0.72, 0.46, 0.72)
  ..cubicTo(0.3, 0.72, 0.16, 0.64, 0.08, 0.52)
  ..quadraticBezierTo(0.14, 0.82, 0.42, 0.98)
  ..lineTo(-0.42, 0.98)
  ..quadraticBezierTo(-0.14, 0.82, -0.08, 0.52)
  ..cubicTo(-0.16, 0.64, -0.3, 0.72, -0.46, 0.72)
  ..cubicTo(-0.72, 0.72, -1.0, 0.56, -1.0, 0.2)
  ..cubicTo(-1.0, -0.28, -0.3, -0.58, 0, -0.98)
  ..close();

final Path _club = Path()
  ..addOval(Rect.fromCircle(center: const Offset(0, -0.5), radius: 0.4))
  ..addOval(Rect.fromCircle(center: const Offset(-0.5, 0.12), radius: 0.4))
  ..addOval(Rect.fromCircle(center: const Offset(0.5, 0.12), radius: 0.4))
  ..addOval(Rect.fromCircle(center: const Offset(0, 0.02), radius: 0.24))
  ..moveTo(-0.08, 0.2)
  ..quadraticBezierTo(-0.1, 0.78, -0.42, 0.98)
  ..lineTo(0.42, 0.98)
  ..quadraticBezierTo(0.1, 0.78, 0.08, 0.2)
  ..close();

/// Draws a suit [size] across (its full -1..1 box) centered at [c].
void drawSuit(
  Canvas canvas,
  CardSuit suit,
  Offset c,
  double size, {
  Color? color,
  bool upsideDown = false,
}) {
  canvas.save();
  canvas.translate(c.dx, c.dy);
  if (upsideDown) canvas.rotate(math.pi);
  canvas.scale(size / 2);
  canvas.drawPath(suitPath(suit), Paint()..color = color ?? suitColor(suit));
  canvas.restore();
}

/// Where the pips sit on a number card, as (column, row) in 0..1 across
/// the middle of the card: the classic layouts.
const Map<int, List<(double, double)>> _pips = {
  2: [(0.5, 0), (0.5, 1)],
  3: [(0.5, 0), (0.5, 0.5), (0.5, 1)],
  4: [(0, 0), (1, 0), (0, 1), (1, 1)],
  5: [(0, 0), (1, 0), (0.5, 0.5), (0, 1), (1, 1)],
  6: [(0, 0), (1, 0), (0, 0.5), (1, 0.5), (0, 1), (1, 1)],
  7: [(0, 0), (1, 0), (0.5, 0.25), (0, 0.5), (1, 0.5), (0, 1), (1, 1)],
  8: [
    (0, 0),
    (1, 0),
    (0.5, 0.25),
    (0, 0.5),
    (1, 0.5),
    (0.5, 0.75),
    (0, 1),
    (1, 1),
  ],
  9: [
    (0, 0),
    (1, 0),
    (0, 1 / 3),
    (1, 1 / 3),
    (0.5, 0.5),
    (0, 2 / 3),
    (1, 2 / 3),
    (0, 1),
    (1, 1),
  ],
  10: [
    (0, 0),
    (1, 0),
    (0.5, 1 / 6),
    (0, 1 / 3),
    (1, 1 / 3),
    (0, 2 / 3),
    (1, 2 / 3),
    (0.5, 5 / 6),
    (0, 1),
    (1, 1),
  ],
};

/// Card faces and backs, drawn in code: a white card with the rank and
/// suit in two corners, the classic pips in the middle (a big suit for an
/// ace, a portrait panel for J, Q and K), and a rainbow rim on the eights,
/// which are wild. The back is Utopia's: deep violet, gold lattice, and a
/// gold coin in the middle.
abstract final class CardArt {
  /// Paints [card] (or the back, when null) filling a card [w] wide whose
  /// top-left is at the origin.
  static void paint(Canvas canvas, PlayingCard? card, double w) {
    if (card == null) {
      _back(canvas, w);
    } else {
      _face(canvas, card, w);
    }
  }

  static RRect _shape(double w) => RRect.fromRectAndRadius(
    Rect.fromLTWH(0, 0, w, w * kCardAspect),
    Radius.circular(w * 0.1),
  );

  static void _face(Canvas canvas, PlayingCard card, double w) {
    final h = w * kCardAspect;
    final shape = _shape(w);
    final ink = suitColor(card.suit);
    canvas.drawRRect(
      shape,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF6F1FF)],
        ).createShader(shape.outerRect),
    );
    if (card.isEight) {
      // Wild: a rainbow rim.
      canvas.drawRRect(
        shape.deflate(w * 0.025),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.035
          ..shader = const SweepGradient(
            colors: [
              Color(0xFFFF5C6C),
              Color(0xFFFFC93D),
              Color(0xFF2FD98E),
              Color(0xFF4DA3FF),
              Color(0xFFB27BFF),
              Color(0xFFFF5C6C),
            ],
          ).createShader(shape.outerRect),
      );
    }
    canvas.drawRRect(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.012
        ..color = const Color(0xFFD9D2EA),
    );

    // The corners: rank over a small suit, top left and (turned) bottom
    // right.
    for (final flip in const [false, true]) {
      canvas.save();
      if (flip) {
        canvas.translate(w, h);
        canvas.rotate(math.pi);
      }
      final label = TextPainter(
        text: TextSpan(
          text: card.label,
          style: AppTextStyles.display(
            fontSize: w * (card.rank == 10 ? 0.2 : 0.23),
            color: ink,
          ).copyWith(height: 1),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final cx = w * 0.14;
      label.paint(canvas, Offset(cx - label.width / 2, w * 0.07));
      drawSuit(
        canvas,
        card.suit,
        Offset(cx, w * 0.07 + label.height + w * 0.075),
        w * 0.13,
      );
      label.dispose();
      canvas.restore();
    }

    final middle = Rect.fromLTRB(w * 0.33, h * 0.17, w * 0.67, h * 0.83);
    if (card.rank == 1) {
      if (card.suit == CardSuit.spades) {
        // The ace of spades gets its ring.
        canvas.drawCircle(
          middle.center,
          w * 0.3,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.02
            ..color = const Color(0xFFFFC94D),
        );
      }
      drawSuit(canvas, card.suit, middle.center, w * 0.4);
    } else if (card.rank > 10) {
      _portrait(canvas, card, middle.inflate(w * 0.03));
    } else {
      final size = w * (card.rank > 8 ? 0.14 : 0.155);
      for (final (cx, cy) in _pips[card.rank]!) {
        drawSuit(
          canvas,
          card.suit,
          Offset(
            middle.left + middle.width * cx,
            middle.top + size / 2 + (middle.height - size) * cy,
          ),
          size,
          upsideDown: cy > 0.5,
        );
      }
    }
  }

  /// A jack, queen or king: a framed panel in the suit's colors with the
  /// letter big, its headwear over it, and the suit under it.
  static void _portrait(Canvas canvas, PlayingCard card, Rect r) {
    final w = r.width;
    final ink = suitColor(card.suit);
    final panel = RRect.fromRectAndRadius(r, Radius.circular(w * 0.14));
    final colors = card.suit.red
        ? const [Color(0xFFFF8FA6), Color(0xFFE8284F), Color(0xFF9E1035)]
        : const [Color(0xFF8C86E8), Color(0xFF4A3FB5), Color(0xFF26234A)];
    canvas.drawRRect(
      panel,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ).createShader(r),
    );
    canvas.drawRRect(
      panel.deflate(w * 0.05),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.03
        ..color = const Color(0xFFFFD86B),
    );
    final letter = TextPainter(
      text: TextSpan(
        text: card.label,
        style: AppTextStyles.display(
          fontSize: w * 0.62,
          color: Colors.white,
        ).copyWith(height: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final at = Offset(
      r.center.dx - letter.width / 2,
      r.center.dy - letter.height * 0.42,
    );
    letter.paint(canvas, at.translate(0, w * 0.03));
    letter.dispose();
    _headwear(
      canvas,
      card.rank,
      Offset(r.center.dx, r.top + r.height * 0.2),
      w,
    );
    drawSuit(
      canvas,
      card.suit,
      Offset(r.center.dx, r.bottom - r.height * 0.15),
      w * 0.2,
      color: Colors.white,
    );
    // Keep the corner color visible against the panel's edge.
    canvas.drawRRect(
      panel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.015
        ..color = ink.withValues(alpha: 0.6),
    );
  }

  /// A crown for the king, a tiara for the queen, a feathered cap for the
  /// jack.
  static void _headwear(Canvas canvas, int rank, Offset c, double w) {
    final gold = Paint()
      ..shader =
          const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF0B8), Color(0xFFFFC94D), Color(0xFFD9962A)],
          ).createShader(
            Rect.fromCenter(center: c, width: w * 0.5, height: w * 0.3),
          );
    final s = w * 0.22;
    switch (rank) {
      case 13:
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - s, c.dy + s * 0.45)
            ..lineTo(c.dx - s, c.dy - s * 0.35)
            ..lineTo(c.dx - s * 0.5, c.dy + s * 0.05)
            ..lineTo(c.dx, c.dy - s * 0.6)
            ..lineTo(c.dx + s * 0.5, c.dy + s * 0.05)
            ..lineTo(c.dx + s, c.dy - s * 0.35)
            ..lineTo(c.dx + s, c.dy + s * 0.45)
            ..close(),
          gold,
        );
        for (final dx in const [-1.0, 0.0, 1.0]) {
          canvas.drawCircle(
            Offset(
              c.dx + dx * s * (dx == 0 ? 0 : 1),
              c.dy - s * (dx == 0 ? 0.62 : 0.38),
            ),
            s * 0.12,
            Paint()..color = const Color(0xFFFFF6D6),
          );
        }
      case 12:
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - s, c.dy + s * 0.35)
            ..quadraticBezierTo(
              c.dx - s * 0.6,
              c.dy - s * 0.45,
              c.dx,
              c.dy - s * 0.5,
            )
            ..quadraticBezierTo(
              c.dx + s * 0.6,
              c.dy - s * 0.45,
              c.dx + s,
              c.dy + s * 0.35,
            )
            ..close(),
          gold,
        );
        canvas.drawCircle(
          Offset(c.dx, c.dy - s * 0.1),
          s * 0.2,
          Paint()..color = const Color(0xFF7FE0FF),
        );
      default:
        // A cap with a feather sweeping back.
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - s, c.dy + s * 0.35)
            ..quadraticBezierTo(
              c.dx - s * 0.8,
              c.dy - s * 0.45,
              c.dx,
              c.dy - s * 0.4,
            )
            ..quadraticBezierTo(
              c.dx + s * 0.8,
              c.dy - s * 0.35,
              c.dx + s,
              c.dy + s * 0.35,
            )
            ..close(),
          gold,
        );
        canvas.drawPath(
          Path()
            ..moveTo(c.dx + s * 0.2, c.dy - s * 0.3)
            ..quadraticBezierTo(
              c.dx + s * 0.9,
              c.dy - s * 1.1,
              c.dx + s * 1.25,
              c.dy - s * 0.85,
            )
            ..quadraticBezierTo(
              c.dx + s * 0.8,
              c.dy - s * 0.55,
              c.dx + s * 0.35,
              c.dy - s * 0.15,
            )
            ..close(),
          Paint()..color = const Color(0xFFFFF6D6),
        );
    }
  }

  static void _back(Canvas canvas, double w) {
    final h = w * kCardAspect;
    final shape = _shape(w);
    canvas.drawRRect(
      shape,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7B5CFF), Color(0xFF4A2FC9), Color(0xFF2B1A85)],
        ).createShader(shape.outerRect),
    );
    final inner = shape.deflate(w * 0.07);
    canvas.save();
    canvas.clipRRect(inner);
    final lattice = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.012
      ..color = Colors.white.withValues(alpha: 0.13);
    for (var k = -6; k <= 12; k++) {
      final x = k * w * 0.16;
      canvas.drawLine(Offset(x, 0), Offset(x + h, h), lattice);
      canvas.drawLine(Offset(x + h, 0), Offset(x, h), lattice);
    }
    canvas.restore();
    canvas.drawRRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.025
        ..color = const Color(0xFFFFC94D),
    );
    // A gold coin in the middle, with a star.
    final c = Offset(w / 2, h / 2);
    final r = w * 0.2;
    canvas.drawCircle(
      c,
      r * 1.25,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFE27A).withValues(alpha: 0.45),
            const Color(0x00FFE27A),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.25)),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.35),
          colors: [Color(0xFFFFF3B8), Color(0xFFFFC94D), Color(0xFFD08A1E)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r * 0.78,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.014
        ..color = const Color(0xFFB8721A),
    );
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rr = i.isEven ? r * 0.5 : r * 0.22;
      final p = c + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(star..close(), Paint()..color = Colors.white);
  }
}

/// Card drawings kept as pixels: drawn once per card and size, then placed.
final cardSprites = SpriteCache(maxBytes: 24 << 20);

/// A font arriving (the corner letters are text) redraws the cards, so one
/// drawn before it came never keeps its stand-in letters.
bool _watchingFonts = false;

/// Draws [card] (a back when null) [width] wide, centered at [at], turned
/// [angle], from [cardSprites].
void drawCard(
  Canvas canvas,
  PlayingCard? card, {
  required Offset at,
  required double width,
  required double dpr,
  double angle = 0,
}) {
  if (!_watchingFonts) {
    _watchingFonts = true;
    PaintingBinding.instance.systemFonts.addListener(cardSprites.clear);
  }
  final w = width.roundToDouble();
  final h = w * kCardAspect;
  cardSprites.draw(
    canvas,
    ('card', card?.code ?? 'back', w),
    bounds: Rect.fromLTWH(-w / 2 - 2, -h / 2 - 2, w + 4, h + 4),
    dpr: dpr,
    at: at,
    angle: angle,
    paint: (c) {
      c.translate(-w / 2, -h / 2);
      CardArt.paint(c, card, w);
    },
  );
}

/// One card as a widget (the rules, the suit picker).
class PlayingCardView extends StatelessWidget {
  const PlayingCardView({super.key, required this.card, this.width = 64});

  /// Null shows the back.
  final PlayingCard? card;
  final double width;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(width, width * kCardAspect),
    painter: _CardPainter(card),
  );
}

class _CardPainter extends CustomPainter {
  _CardPainter(this.card);

  final PlayingCard? card;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (Offset(0, size.width * 0.03) & size),
        Radius.circular(size.width * 0.1),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.04),
    );
    CardArt.paint(canvas, card, size.width);
  }

  @override
  bool shouldRepaint(covariant _CardPainter old) => old.card != card;
}
