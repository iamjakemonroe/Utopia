import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../chess/domain/chess_types.dart';
import '../../../chess/presentation/widgets/chess_piece_styles.dart';
import '../../domain/checkers_engine.dart';

/// Checkers pieces wear the player's chess set: dark plays in the set's
/// dark finish, light in its light finish, and the character sets (Buddies,
/// Monsters, Robots) get faces.
ChessPieceFinish checkersFinish(String? set, CheckersSide side) =>
    ChessPieceStyle.byId(
      set,
    ).of(side == CheckersSide.dark ? PieceColor.black : PieceColor.white);

ChessCharacter checkersCharacter(String? set) =>
    ChessPieceStyle.byId(set).character;

enum DiscFace { calm, happy, sad, scared, ko }

const _gold = [Color(0xFFFFF0A8), Color(0xFFFFC93D), Color(0xFFB8860B)];
const _goldInk = Color(0xFF6E4300);
const _faceInk = Color(0xFF1B1433);

/// Paints one checkers piece centred on [c] with radius [r]: a thick glossy
/// disc with a groove and a rim light. A king is two discs stacked with a
/// gold crown on top ([crown] runs 0 to 1 as the crown drops on).
/// [ground] is where its shadow falls (below [c] while it's in the air).
void paintCheckersDisc(
  Canvas canvas,
  Offset c,
  double r, {
  required ChessPieceFinish finish,
  bool king = false,
  double crown = 1,
  ChessCharacter character = ChessCharacter.none,
  DiscFace face = DiscFace.calm,
  double blink = 0,
  Offset look = Offset.zero,
  Offset? ground,
  double opacity = 1,
  bool turned = false,
}) {
  final g = finish.gradient;
  final depth = r * 0.17;
  final air = ground == null ? 0.0 : (ground - c).distance / r;
  final shadowAt = ground ?? c;

  if (opacity < 1) {
    canvas.saveLayer(
      Rect.fromCircle(center: c, radius: r * 2.6),
      Paint()..color = Color.fromRGBO(0, 0, 0, opacity),
    );
  }

  // Shadow on the board: softer and paler the higher the piece is.
  canvas.drawOval(
    Rect.fromCenter(
      center: shadowAt.translate(r * 0.1, r * 0.26),
      width: r * 2.1,
      height: r * 1.75,
    ),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.38 / (1 + air * 0.8))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * (0.12 + air * 0.2)),
  );
  if (finish.glow != null) {
    canvas.drawCircle(
      c,
      r * 1.18,
      Paint()
        ..color = finish.glow!
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.35),
    );
  }

  final sideColor = Color.lerp(g.last, Colors.black, 0.42)!;
  void disc(Offset at) {
    // The edge of the disc, showing below its face.
    final edge = Rect.fromCircle(center: at.translate(0, depth), radius: r);
    canvas.drawCircle(
      at.translate(0, depth),
      r,
      Paint()
        ..shader = LinearGradient(
          colors: [sideColor, Color.lerp(sideColor, g.first, 0.25)!, sideColor],
          stops: const [0, 0.35, 1],
        ).createShader(edge),
    );
    // Ridges around the edge, like a real checker.
    final ridge = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..strokeWidth = r * 0.035;
    for (var i = 1; i < 12; i++) {
      final a = math.pi * i / 12;
      final x = at.dx - math.cos(a) * r * 0.98;
      final y = at.dy + math.sin(a) * r * 0.98;
      canvas.drawLine(Offset(x, y), Offset(x, y + depth * 0.9), ridge);
    }
    final face = Rect.fromCircle(center: at, radius: r);
    canvas.drawCircle(
      at,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 1.15,
          colors: g,
          stops: g.length == 3 ? const [0, 0.55, 1] : null,
        ).createShader(face),
    );
    // The groove and its lit lip.
    canvas.drawCircle(
      at,
      r * 0.7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08
        ..color = Colors.black.withValues(alpha: 0.2),
    );
    canvas.drawCircle(
      at.translate(0, r * 0.035),
      r * 0.7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.03
        ..color = Colors.white.withValues(alpha: 0.28),
    );
    canvas.drawCircle(
      at,
      r * 0.96,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08
        ..color = finish.rim
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, finish.rimBlur * 0.5),
    );
  }

  disc(c);
  final top = king ? c.translate(0, -depth * 1.35) : c;
  if (king) disc(top);

  // The shine.
  canvas.save();
  canvas.translate(top.dx - r * 0.34, top.dy - r * 0.42);
  canvas.rotate(-0.55);
  canvas.drawOval(
    Rect.fromCenter(center: Offset.zero, width: r * 0.72, height: r * 0.34),
    Paint()
      ..color = Colors.white.withValues(alpha: finish.highlight * 0.5)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.08),
  );
  canvas.restore();

  // Face to face over one phone, the face and crown turn round for the
  // player across the table; the disc itself is the same from both sides.
  canvas.save();
  if (turned) {
    canvas.translate(top.dx, top.dy);
    canvas.rotate(math.pi);
    canvas.translate(-top.dx, -top.dy);
  }
  if (character != ChessCharacter.none) {
    _face(
      canvas,
      top.translate(0, king ? r * 0.22 : 0),
      r,
      character,
      face,
      blink,
      look,
    );
  }
  if (king && crown > 0) {
    // On a face, the crown sits higher and a little smaller.
    final faced = character != ChessCharacter.none;
    _crown(
      canvas,
      top.translate(0, faced ? -r * 0.42 : -r * 0.05),
      faced ? r * 0.8 : r,
      crown,
    );
  }
  canvas.restore();

  if (opacity < 1) canvas.restore();
}

/// A gold crown dropping onto the disc: [t] 0 (high above, clear) to 1
/// (seated), with a little bounce on landing.
void _crown(Canvas canvas, Offset c, double r, double t) {
  final drop = t < 0.6
      ? Curves.easeIn.transform(t / 0.6)
      : 1 + 0.12 * math.sin((t - 0.6) / 0.4 * math.pi) * (1 - t);
  final at = c.translate(0, -(1 - drop) * r * 2.4);
  final alpha = (t * 3).clamp(0.0, 1.0);
  final w = r * 1.02;
  final h = r * 0.62;
  final base = at.dy + h * 0.42;
  final path = Path()
    ..moveTo(at.dx - w / 2, base)
    ..lineTo(at.dx - w / 2, at.dy - h * 0.1)
    ..lineTo(at.dx - w * 0.27, at.dy + h * 0.12)
    ..lineTo(at.dx, at.dy - h * 0.42)
    ..lineTo(at.dx + w * 0.27, at.dy + h * 0.12)
    ..lineTo(at.dx + w / 2, at.dy - h * 0.1)
    ..lineTo(at.dx + w / 2, base)
    ..close();
  final rect = Rect.fromCenter(center: at, width: w, height: h);
  canvas.drawPath(
    path.shift(Offset(0, r * 0.06)),
    Paint()..color = Colors.black.withValues(alpha: 0.3 * alpha),
  );
  canvas.drawPath(
    path,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [for (final c in _gold) c.withValues(alpha: alpha)],
      ).createShader(rect),
  );
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = r * 0.06
      ..color = _goldInk.withValues(alpha: alpha),
  );
  // The band and its jewels.
  canvas.drawLine(
    Offset(at.dx - w / 2, base - h * 0.2),
    Offset(at.dx + w / 2, base - h * 0.2),
    Paint()
      ..strokeWidth = r * 0.05
      ..color = _goldInk.withValues(alpha: 0.6 * alpha),
  );
  for (final (dx, color) in [
    (-0.5, const Color(0xFFFF4D6D)),
    (0.0, const Color(0xFF4DA3FF)),
    (0.5, const Color(0xFF2FD98E)),
  ]) {
    canvas.drawCircle(
      Offset(at.dx + dx * w * 0.97, at.dy - (dx == 0 ? h * 0.42 : h * 0.1)),
      r * 0.085,
      Paint()..color = color.withValues(alpha: alpha),
    );
  }
}

void _face(
  Canvas canvas,
  Offset c,
  double r,
  ChessCharacter character,
  DiscFace face,
  double blink,
  Offset look,
) {
  final ink = Paint()..color = _faceInk;
  final white = Paint()..color = Colors.white;
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = r * 0.07
    ..color = _faceInk;
  final pupil = look * r * 0.07;

  void xEye(Offset at, double s) {
    canvas.drawLine(at.translate(-s, -s), at.translate(s, s), stroke);
    canvas.drawLine(at.translate(-s, s), at.translate(s, -s), stroke);
  }

  void arcEye(Offset at, double s, {bool down = false}) {
    canvas.drawArc(
      Rect.fromCenter(center: at, width: s * 2, height: s * 1.6),
      down ? 0.2 : math.pi + 0.2,
      math.pi - 0.4,
      false,
      stroke,
    );
  }

  switch (character) {
    case ChessCharacter.none:
      return;
    case ChessCharacter.buddies:
      for (final side in [-1.0, 1.0]) {
        final at = c.translate(side * r * 0.26, -r * 0.08);
        switch (face) {
          case DiscFace.ko:
            xEye(at, r * 0.1);
          case DiscFace.happy:
            arcEye(at, r * 0.12);
          default:
            final big = face == DiscFace.scared ? 1.2 : 1.0;
            final h = r * 0.3 * big * (1 - blink).clamp(0.08, 1.0);
            canvas.drawOval(
              Rect.fromCenter(center: at, width: r * 0.24 * big, height: h),
              white,
            );
            if (blink < 0.6) {
              canvas.drawCircle(
                at + pupil,
                r * (face == DiscFace.scared ? 0.05 : 0.075),
                ink,
              );
            }
            if (face == DiscFace.sad) {
              canvas.drawLine(
                at.translate(-side * r * 0.12, -r * 0.24),
                at.translate(side * r * 0.1, -r * 0.18),
                stroke,
              );
            }
        }
      }
      final mouth = c.translate(0, r * 0.26);
      switch (face) {
        case DiscFace.scared || DiscFace.ko:
          canvas.drawOval(
            Rect.fromCenter(center: mouth, width: r * 0.16, height: r * 0.2),
            ink,
          );
        case DiscFace.sad:
          arcEye(mouth.translate(0, r * 0.06), r * 0.14);
        default:
          arcEye(mouth.translate(0, -r * 0.06), r * 0.16, down: true);
      }
    case ChessCharacter.monsters:
      final at = c.translate(0, -r * 0.06);
      if (face == DiscFace.ko) {
        xEye(at, r * 0.16);
      } else if (face == DiscFace.happy) {
        arcEye(at, r * 0.2);
      } else {
        final h = r * 0.46 * (1 - blink).clamp(0.08, 1.0);
        canvas.drawOval(
          Rect.fromCenter(center: at, width: r * 0.44, height: h),
          white,
        );
        if (blink < 0.6) {
          canvas.drawCircle(
            at + pupil * 1.4,
            r * (face == DiscFace.scared ? 0.07 : 0.12),
            ink,
          );
        }
      }
      // Two little fangs.
      final mouth = c.translate(0, r * 0.32);
      for (final side in [-1.0, 1.0]) {
        final fang = Path()
          ..moveTo(mouth.dx + side * r * 0.16, mouth.dy)
          ..lineTo(mouth.dx + side * r * 0.06, mouth.dy)
          ..lineTo(
            mouth.dx + side * r * 0.11,
            mouth.dy + (face == DiscFace.sad ? r * 0.08 : r * 0.14),
          )
          ..close();
        canvas.drawPath(fang, white);
      }
    case ChessCharacter.robots:
      final visor = Rect.fromCenter(
        center: c.translate(0, -r * 0.04),
        width: r * 0.92,
        height: r * 0.32,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(visor, Radius.circular(r * 0.14)),
        Paint()..color = const Color(0xFF101626),
      );
      final glow = Paint()
        ..color = face == DiscFace.sad || face == DiscFace.ko
            ? const Color(0xFFFF6B7A)
            : const Color(0xFF7DE8FF)
        ..maskFilter = MaskFilter.blur(BlurStyle.solid, r * 0.04);
      for (final side in [-1.0, 1.0]) {
        final at = visor.center.translate(side * r * 0.2, 0) + pupil;
        switch (face) {
          case DiscFace.ko:
            xEye(at, r * 0.07);
          case DiscFace.happy:
            canvas.drawArc(
              Rect.fromCenter(center: at, width: r * 0.18, height: r * 0.14),
              math.pi,
              math.pi,
              false,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = r * 0.05
                ..color = glow.color,
            );
          default:
            if (blink > 0.5) {
              canvas.drawLine(
                at.translate(-r * 0.07, 0),
                at.translate(r * 0.07, 0),
                Paint()
                  ..strokeWidth = r * 0.04
                  ..color = glow.color,
              );
            } else {
              canvas.drawCircle(
                at,
                r * (face == DiscFace.scared ? 0.09 : 0.065),
                glow,
              );
            }
        }
      }
  }
}
