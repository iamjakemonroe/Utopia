import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/chess_types.dart';
import 'chess_piece_styles.dart';

/// How a piece feels about the game right now. Character sets show it on
/// their faces; every set moves with it (see the board).
enum PieceMood {
  idle,

  /// Picked up, about to move.
  ready,

  /// Just moved.
  happy,

  /// Just took a piece.
  proud,

  /// Under attack.
  scared,

  /// A king in check.
  panic,

  /// Taken, or a checkmated king.
  ko,

  /// On the losing side.
  sad,

  /// On the winning side.
  cheer,

  /// A draw.
  meh,
}

/// Solid, drawn chess pieces: Staunton silhouettes filled with a piece
/// set's finish, outlined in a contrasting color so they read clearly on
/// any square. Drawn in a 100×100 box and scaled to fit. Character sets add
/// a face (and horns, or an antenna) that blinks, glances toward [look] and
/// shows its [mood].
class ChessPieceArt extends StatelessWidget {
  const ChessPieceArt({
    super.key,
    required this.type,
    required this.finish,
    required this.size,
    this.glowColor,
    this.character = ChessCharacter.none,
    this.mood = PieceMood.idle,
    this.t = 0,
    this.look = 0,
    this.seed = 0,
  });

  final PieceType type;
  final ChessPieceFinish finish;
  final double size;

  /// An extra halo, e.g. for the selected piece.
  final Color? glowColor;
  final ChessCharacter character;
  final PieceMood mood;

  /// Seconds, for blinks and LED scans.
  final double t;

  /// Where the eyes look, -1 (left) to 1 (right).
  final double look;

  /// Keeps pieces from blinking in unison.
  final double seed;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: ChessPieceArtPainter(
        type: type,
        finish: finish,
        glowColor: glowColor,
        character: character,
        mood: mood,
        t: t,
        look: look,
        seed: seed,
      ),
    );
  }
}

class ChessPieceArtPainter extends CustomPainter {
  ChessPieceArtPainter({
    required this.type,
    required this.finish,
    this.glowColor,
    this.character = ChessCharacter.none,
    this.mood = PieceMood.idle,
    this.t = 0,
    this.look = 0,
    this.seed = 0,
  });

  final PieceType type;
  final ChessPieceFinish finish;
  final Color? glowColor;
  final ChessCharacter character;
  final PieceMood mood;
  final double t;
  final double look;
  final double seed;

  bool get _faced => character != ChessCharacter.none;

  static final Map<PieceType, Path> _bodies = {};

  /// What never changes in a piece, recorded once and replayed after.
  /// A browser builds a path again every frame it's drawn (a piece's
  /// outline is a union of its parts, worked out again each time) and a
  /// recording keeps them built. It's the same drawing, at any size.
  static final _recorded = <Object, ui.Picture>{};

  static void _replay(
    Canvas canvas,
    Object key,
    void Function(Canvas canvas) draw,
  ) {
    final picture = _recorded.putIfAbsent(key, () {
      final recorder = ui.PictureRecorder();
      draw(Canvas(recorder));
      return recorder.endRecording();
    });
    canvas.drawPicture(picture);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final light = finish.gradient[1].computeLuminance() > 0.3;
    final outline = light
        ? Color.lerp(finish.gradient.last, const Color(0xFF120C24), 0.68)!
        : finish.rim.withValues(alpha: 1);

    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);

    if (glowColor != null || finish.glow != null) {
      _replay(canvas, ('glow', type, finish, glowColor), _glows);
    }

    if (_faced) _behind(canvas, outline);

    // Faces, and a knight's mane that sways with them, change as they're
    // shown; without them, every bit of the piece stays as it is.
    _replay(canvas, ('piece', type, finish, _faced), (canvas) {
      _piece(canvas, outline);
      if (!_faced) _finishing(canvas, outline);
    });
    if (_faced) _finishing(canvas, outline);

    if (_faced) _face(canvas, light);
    if (mood == PieceMood.ko) _dizzy(canvas);

    canvas.restore();
  }

  void _glows(Canvas canvas) {
    final body = _bodies.putIfAbsent(type, () => _body(type));
    if (glowColor != null) {
      canvas.drawPath(
        body,
        Paint()
          ..color = glowColor!
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
    }
    if (finish.glow != null) {
      canvas.drawPath(
        body,
        Paint()
          ..color = finish.glow!
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
  }

  /// The piece itself: its contact shadow, body, sheen and outline.
  void _piece(Canvas canvas, Color outline) {
    final body = _bodies.putIfAbsent(type, () => _body(type));
    const box = Rect.fromLTWH(10, 6, 80, 90);

    // Contact shadow, then the piece itself.
    canvas.drawPath(
      body.shift(const Offset(0, 2.5)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.55, 1.0],
          colors: finish.gradient,
        ).createShader(box),
    );

    // Light from the upper left: a soft sheen on the left, shade on the
    // right, so the flat shape reads as a turned, rounded piece.
    canvas.save();
    canvas.clipPath(body);
    canvas.drawRect(
      box,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.38 * finish.highlight),
            Colors.white.withValues(alpha: 0),
            Colors.black.withValues(alpha: 0),
            Colors.black.withValues(alpha: 0.24),
          ],
          stops: const [0.0, 0.38, 0.62, 1.0],
        ).createShader(const Rect.fromLTWH(24, 0, 52, 100)),
    );
    canvas.restore();

    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeJoin = StrokeJoin.round
        ..color = outline,
    );
  }

  /// The carved details and the specular glint.
  void _finishing(Canvas canvas, Color outline) {
    final detail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = outline.withValues(alpha: 0.8);
    _details(canvas, detail, outline);

    // Specular glint.
    final glint = _glint[type]!;
    canvas.drawOval(
      Rect.fromCenter(center: glint, width: 7, height: 4.5),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.75 * finish.highlight)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
    );
  }

  // ── character extras ─────────────────────────────────────────────────────

  /// Where each piece's face sits, and how big it is.
  static const _faces = {
    PieceType.pawn: (Offset(50, 37), 1.3),
    PieceType.rook: (Offset(50, 57), 1.55),
    PieceType.bishop: (Offset(50, 36), 1.35),
    PieceType.queen: (Offset(50, 62), 1.35),
    PieceType.king: (Offset(50, 39), 1.45),
    PieceType.knight: (Offset(31, 35), 1.4),
  };

  /// The top of each piece's head, for horns and antennas.
  static const _heads = {
    PieceType.pawn: Offset(50, 23),
    PieceType.rook: Offset(50, 16),
    PieceType.bishop: Offset(50, 8),
    PieceType.knight: Offset(43, 10),
  };

  bool get _blinking {
    if (mood == PieceMood.ko || mood == PieceMood.happy) return false;
    return (t + seed * 1.7) % 3.6 < 0.12;
  }

  /// Horns or an antenna, drawn behind the piece.
  void _behind(Canvas canvas, Color outline) {
    final head = _heads[type];
    if (head == null) return;
    switch (character) {
      case ChessCharacter.monsters:
        for (final side in const [-1.0, 1.0]) {
          final base = head.translate(side * 7, 4);
          final horn = Path()
            ..moveTo(base.dx - 4, base.dy + 2)
            ..quadraticBezierTo(
              base.dx + side * 2,
              base.dy - 6,
              base.dx + side * 7,
              base.dy - 12,
            )
            ..quadraticBezierTo(
              base.dx + side * 3,
              base.dy - 2,
              base.dx + 4,
              base.dy + 2,
            )
            ..close();
          canvas.drawPath(horn, Paint()..color = const Color(0xFFFFF2D6));
          canvas.drawPath(
            horn,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = outline,
          );
        }
      case ChessCharacter.robots:
        final top = head.translate(0, -11);
        canvas.drawLine(
          head.translate(0, 3),
          top,
          Paint()
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round
            ..color = outline,
        );
        final on = ((t + seed) % 1.2) < 0.6;
        final led = _ledColor;
        canvas.drawCircle(
          top,
          4.2,
          Paint()
            ..color = on ? led : Color.lerp(led, Colors.black, 0.6)!
            ..maskFilter = on
                ? const MaskFilter.blur(BlurStyle.solid, 2.5)
                : null,
        );
      default:
    }
  }

  Color get _ledColor => switch (mood) {
    PieceMood.happy || PieceMood.cheer => const Color(0xFF5CFF9A),
    PieceMood.proud => const Color(0xFFFFD24D),
    PieceMood.scared => const Color(0xFFFFB020),
    PieceMood.panic || PieceMood.ko => const Color(0xFFFF3D5A),
    PieceMood.sad => const Color(0xFF5AA8FF),
    PieceMood.meh => const Color(0xFF9AA4B8),
    _ => const Color(0xFF3DF5FF),
  };

  void _face(Canvas canvas, bool lightBody) {
    final (c, s) = _faces[type]!;
    switch (character) {
      case ChessCharacter.robots:
        _robotFace(canvas, c, s);
      case ChessCharacter.monsters:
        _creatureFace(canvas, c, s, monster: true);
      default:
        _creatureFace(canvas, c, s, monster: false);
    }
  }

  /// Eyes, brows and a mouth that change with the mood. Monsters get heavy
  /// brows and fangs (and pawns get one big eye).
  void _creatureFace(
    Canvas canvas,
    Offset c,
    double s, {
    required bool monster,
  }) {
    const ink = AppColors.faceInk;
    final inkPaint = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 1.9 * s;
    final fill = Paint()..color = ink;
    final cyclops = monster && type == PieceType.pawn;
    final knight = type == PieceType.knight;
    // A knight is seen side-on: one eye.
    final eyes = knight || cyclops
        ? [c]
        : [c.translate(-5.0 * s, 0), c.translate(5.0 * s, 0)];
    final eyeW = (cyclops ? 9.4 : 6.0) * s;
    final eyeH = (cyclops ? 10.0 : 7.2) * s;
    final wide = mood == PieceMood.scared || mood == PieceMood.panic;
    // Eyes dart now and then instead of shaking all the time.
    final burst = ((t + seed) % 2.4) < 0.35;
    final tremble = mood == PieceMood.panic && burst
        ? math.sin(t * 26) * 0.5 * s
        : 0.0;

    for (final (i, e0) in eyes.indexed) {
      final e = e0.translate(tremble, 0);
      switch (mood) {
        case PieceMood.happy || PieceMood.proud || PieceMood.cheer:
          // Smiling eyes: ^ ^
          canvas.drawArc(
            Rect.fromCenter(
              center: e.translate(0, 1.2 * s),
              width: eyeW,
              height: eyeH * 0.9,
            ),
            math.pi * 1.1,
            math.pi * 0.8,
            false,
            inkPaint,
          );
        case PieceMood.ko:
          final d = eyeW * 0.38;
          canvas.drawLine(e.translate(-d, -d), e.translate(d, d), inkPaint);
          canvas.drawLine(e.translate(-d, d), e.translate(d, -d), inkPaint);
        default:
          if (_blinking) {
            canvas.drawLine(
              e.translate(-eyeW * 0.45, 0),
              e.translate(eyeW * 0.45, 0),
              inkPaint,
            );
            continue;
          }
          final w = eyeW * (wide ? 1.18 : 1);
          final h = eyeH * (wide ? 1.18 : 1);
          final eyeRect = Rect.fromCenter(center: e, width: w, height: h);
          canvas.drawOval(eyeRect, Paint()..color = Colors.white);
          canvas.drawOval(
            eyeRect,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.9 * s
              ..color = ink.withValues(alpha: 0.5),
          );
          final pr = (wide ? 1.4 : 2.2) * s * (cyclops ? 1.7 : 1);
          final down = mood == PieceMood.sad ? h * 0.22 : 0.0;
          final pupil = e.translate(look * w * 0.22, down + h * 0.04);
          canvas.drawCircle(pupil, pr, fill);
          canvas.drawCircle(
            pupil.translate(-pr * 0.35, -pr * 0.4),
            pr * 0.35,
            Paint()..color = Colors.white,
          );
          if (mood == PieceMood.meh) {
            // Heavy lids.
            canvas.drawRect(
              Rect.fromLTRB(eyeRect.left, eyeRect.top, eyeRect.right, e.dy),
              Paint()..color = ink.withValues(alpha: 0.85),
            );
          }
      }

      // Brows.
      final browY = e.dy - eyeH * 0.82;
      final dir = eyes.length == 1 ? 1.0 : (i == 0 ? -1.0 : 1.0);
      final browPaint = Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = (monster ? 2.8 : 1.6) * s;
      final half = eyeW * 0.5;
      switch (mood) {
        case PieceMood.ready || PieceMood.proud:
          // Determined: slanting down toward the middle.
          canvas.drawLine(
            Offset(e.dx - dir * half, browY - 1.6 * s),
            Offset(e.dx + dir * half * 0.6, browY + 1.2 * s),
            browPaint,
          );
        case PieceMood.scared || PieceMood.panic || PieceMood.sad:
          // Worried: slanting up toward the middle.
          canvas.drawLine(
            Offset(e.dx - dir * half, browY + 1.4 * s),
            Offset(e.dx + dir * half * 0.6, browY - 1.6 * s),
            browPaint,
          );
        default:
          if (monster) {
            canvas.drawLine(
              Offset(e.dx - half, browY),
              Offset(e.dx + half, browY - 0.6 * s),
              browPaint,
            );
          }
      }
    }

    // Mouth.
    final m = knight ? const Offset(21, 54) : c.translate(0, 7.0 * s);
    final mw = (knight ? 6.0 : 7.0) * s;
    switch (mood) {
      case PieceMood.happy || PieceMood.proud || PieceMood.cheer:
        final open = Path()
          ..moveTo(m.dx - mw * 0.7, m.dy - 1 * s)
          ..quadraticBezierTo(
            m.dx,
            m.dy + mw * 1.1,
            m.dx + mw * 0.7,
            m.dy - 1 * s,
          )
          ..close();
        canvas.drawPath(open, fill);
        canvas.drawCircle(
          m.translate(0, mw * 0.42),
          mw * 0.24,
          Paint()..color = const Color(0xFFFF6B8A),
        );
        if (mood != PieceMood.happy && !knight) {
          // Rosy cheeks.
          for (final side in const [-1.0, 1.0]) {
            canvas.drawOval(
              Rect.fromCenter(
                center: c.translate(side * 9.5 * s, 4 * s),
                width: 4.5 * s,
                height: 2.6 * s,
              ),
              Paint()..color = const Color(0x88FF6B8A),
            );
          }
        }
      case PieceMood.scared:
        canvas.drawOval(
          Rect.fromCenter(
            center: m.translate(0, 1 * s),
            width: mw * 0.45,
            height: mw * 0.6,
          ),
          fill,
        );
      case PieceMood.panic:
        final wave = Path()..moveTo(m.dx - mw * 0.7, m.dy);
        for (var k = 1; k <= 4; k++) {
          wave.lineTo(
            m.dx - mw * 0.7 + k * mw * 0.35,
            m.dy + (k.isOdd ? -1.2 : 1.2) * s,
          );
        }
        canvas.drawPath(wave, inkPaint);
        if (!knight) _sweat(canvas, c, s);
      case PieceMood.ko:
        canvas.drawLine(
          m.translate(-mw * 0.5, 0),
          m.translate(mw * 0.5, 0),
          inkPaint,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: m.translate(mw * 0.2, mw * 0.3),
            width: mw * 0.4,
            height: mw * 0.55,
          ),
          Paint()..color = const Color(0xFFFF6B8A),
        );
      case PieceMood.sad:
        canvas.drawArc(
          Rect.fromCenter(
            center: m.translate(0, 2.5 * s),
            width: mw,
            height: mw * 0.8,
          ),
          math.pi * 1.15,
          math.pi * 0.7,
          false,
          inkPaint,
        );
      case PieceMood.meh:
        canvas.drawLine(
          m.translate(-mw * 0.45, 0.5 * s),
          m.translate(mw * 0.45, 0.5 * s),
          inkPaint,
        );
      default:
        canvas.drawArc(
          Rect.fromCenter(
            center: m.translate(0, -1 * s),
            width: mw,
            height: mw * 0.7,
          ),
          math.pi * 0.15,
          math.pi * 0.7,
          false,
          inkPaint,
        );
    }

    if (monster && mood != PieceMood.ko) {
      // Two little fangs.
      for (final side in const [-1.0, 1.0]) {
        final f = m.translate(side * mw * 0.3, -0.5 * s);
        final fang = Path()
          ..moveTo(f.dx - 1.3 * s, f.dy)
          ..lineTo(f.dx + 1.3 * s, f.dy)
          ..lineTo(f.dx, f.dy + 3 * s)
          ..close();
        canvas.drawPath(fang, Paint()..color = Colors.white);
      }
    }
  }

  void _sweat(Canvas canvas, Offset c, double s) {
    final drip = (t * 1.4) % 1;
    final p = c.translate(11 * s, -6 * s + 6 * s * drip);
    final drop = Path()
      ..moveTo(p.dx, p.dy - 3.5 * s)
      ..quadraticBezierTo(p.dx + 2.6 * s, p.dy, p.dx, p.dy + 2.2 * s)
      ..quadraticBezierTo(p.dx - 2.6 * s, p.dy, p.dx, p.dy - 3.5 * s)
      ..close();
    canvas.drawPath(
      drop,
      Paint()
        ..color = const Color(0xFF7FD8FF).withValues(alpha: 1 - drip * 0.6),
    );
  }

  /// A dark visor with LED eyes that change with the mood, and a light
  /// that sweeps across it now and then.
  void _robotFace(Canvas canvas, Offset c, double s) {
    final knight = type == PieceType.knight;
    final visor = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: knight ? c.translate(2 * s, 1 * s) : c,
        width: (knight ? 14 : 21) * s,
        height: 9 * s,
      ),
      Radius.circular(4.5 * s),
    );
    canvas.drawRRect(visor, Paint()..color = const Color(0xFF0B1020));
    final led = _ledColor;
    canvas.drawRRect(
      visor,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 * s
        ..color = led.withValues(alpha: 0.7),
    );
    canvas.save();
    canvas.clipRRect(visor);
    final glow = Paint()
      ..color = led
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * s
      ..maskFilter = MaskFilter.blur(BlurStyle.solid, 1.2 * s);
    final dot = Paint()
      ..color = led
      ..maskFilter = MaskFilter.blur(BlurStyle.solid, 1.2 * s);
    final vc = visor.center;
    final eyes = knight
        ? [vc]
        : [vc.translate(-4.6 * s, 0), vc.translate(4.6 * s, 0)];
    final shake = mood == PieceMood.scared ? math.sin(t * 35) * 0.5 * s : 0.0;
    for (final (i, e0) in eyes.indexed) {
      final e = e0.translate(look * 1.6 * s + shake, 0);
      switch (mood) {
        case PieceMood.happy || PieceMood.cheer:
          canvas.drawArc(
            Rect.fromCenter(
              center: e.translate(0, 1.2 * s),
              width: 4.6 * s,
              height: 4 * s,
            ),
            math.pi * 1.1,
            math.pi * 0.8,
            false,
            glow,
          );
        case PieceMood.proud:
          _sparkle(canvas, e, 2.6 * s, dot);
        case PieceMood.panic:
          if ((t * 6).floor().isEven) {
            canvas.drawLine(
              e.translate(0, -2.4 * s),
              e.translate(0, 0.6 * s),
              glow,
            );
            canvas.drawCircle(e.translate(0, 2.2 * s), 0.8 * s, dot);
          }
        case PieceMood.ko:
          final d = 1.8 * s;
          canvas.drawLine(e.translate(-d, -d), e.translate(d, d), glow);
          canvas.drawLine(e.translate(-d, d), e.translate(d, -d), glow);
        case PieceMood.sad:
          canvas.drawArc(
            Rect.fromCenter(
              center: e.translate(0, 2 * s),
              width: 4.4 * s,
              height: 3.6 * s,
            ),
            math.pi * 1.15,
            math.pi * 0.7,
            false,
            glow,
          );
        case PieceMood.meh:
          canvas.drawLine(
            e.translate(-1.8 * s, 0),
            e.translate(1.8 * s, 0),
            glow,
          );
        case PieceMood.ready:
          final dir = eyes.length == 1 ? 1.0 : (i == 0 ? 1.0 : -1.0);
          canvas.drawLine(
            e.translate(-1.8 * s, -1.2 * s * dir),
            e.translate(1.8 * s, 1.2 * s * dir),
            glow,
          );
        case PieceMood.scared:
          canvas.drawCircle(e, 1.1 * s, dot);
        case PieceMood.idle:
          if (_blinking) {
            canvas.drawLine(
              e.translate(-1.8 * s, 0),
              e.translate(1.8 * s, 0),
              glow,
            );
          } else {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(center: e, width: 3.2 * s, height: 3.6 * s),
                Radius.circular(1 * s),
              ),
              dot,
            );
          }
      }
    }
    // The scan line sweeping across the glass.
    final sweep = (t * 0.6 + seed) % 1;
    if (sweep < 0.35) {
      final x = visor.left + visor.width * (sweep / 0.35);
      canvas.drawRect(
        Rect.fromLTWH(x - 2 * s, visor.top, 4 * s, visor.height),
        Paint()..color = Colors.white.withValues(alpha: 0.22),
      );
    }
    canvas.restore();
  }

  void _sparkle(Canvas canvas, Offset p, double r, Paint paint) {
    final path = Path()
      ..moveTo(p.dx, p.dy - r)
      ..quadraticBezierTo(p.dx, p.dy, p.dx + r, p.dy)
      ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + r)
      ..quadraticBezierTo(p.dx, p.dy, p.dx - r, p.dy)
      ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - r);
    canvas.drawPath(path, paint);
  }

  /// Little stars circling a knocked-out piece's head.
  void _dizzy(Canvas canvas) {
    final head = _heads[type] ?? const Offset(50, 14);
    final star = Paint()..color = const Color(0xFFFFE07A);
    for (var i = 0; i < 3; i++) {
      final a = t * 4 + i * 2 * math.pi / 3;
      final p = head.translate(math.cos(a) * 13, -4 + math.sin(a) * 4);
      _sparkle(canvas, p, 3.4, star);
    }
  }

  static const _glint = {
    PieceType.pawn: Offset(44, 30),
    PieceType.knight: Offset(28, 39),
    PieceType.bishop: Offset(44, 26),
    PieceType.rook: Offset(35, 34),
    PieceType.queen: Offset(44, 39),
    PieceType.king: Offset(38, 37),
  };

  void _details(Canvas canvas, Paint line, Color ink) {
    // Every piece sits on the same plinth: a seam where the lip meets it.
    canvas.drawLine(const Offset(27, 82.5), const Offset(73, 82.5), line);
    // Every knight gets its mane, character or not.
    if (type == PieceType.knight) _mane(canvas, ink);
    // Character sets have faces where the carved details would go.
    if (_faced) return;
    switch (type) {
      case PieceType.pawn:
        canvas.drawLine(const Offset(39, 55.5), const Offset(61, 55.5), line);
      case PieceType.rook:
        canvas.drawLine(const Offset(31, 43.5), const Offset(69, 43.5), line);
        canvas.drawLine(const Offset(35, 70), const Offset(65, 70), line);
      case PieceType.bishop:
        canvas.drawLine(const Offset(39, 57.5), const Offset(61, 57.5), line);
        canvas.drawLine(
          const Offset(55.5, 27),
          const Offset(47, 38),
          line..strokeWidth = 3,
        );
      case PieceType.queen:
        canvas.drawLine(const Offset(37, 52.5), const Offset(63, 52.5), line);
        canvas.drawLine(const Offset(36, 44), const Offset(64, 44), line);
      case PieceType.king:
        canvas.drawLine(const Offset(36, 54.5), const Offset(64, 54.5), line);
        canvas.drawLine(const Offset(37, 47), const Offset(63, 47), line);
      case PieceType.knight:
        // A narrow almond eye under a sharp, low brow, a flared nostril
        // and the line of the cheek.
        final eye = Path()
          ..moveTo(28, 35.5)
          ..quadraticBezierTo(32, 31.5, 36.5, 34)
          ..quadraticBezierTo(32, 38, 28, 35.5)
          ..close();
        canvas.drawPath(eye, Paint()..color = ink);
        canvas.drawLine(
          const Offset(26.5, 32.5),
          const Offset(37.5, 29.5),
          line..strokeWidth = 2.4,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: const Offset(20, 48.5),
            width: 3.6,
            height: 2.4,
          ),
          Paint()..color = ink.withValues(alpha: 0.85),
        );
        canvas.drawPath(
          Path()
            ..moveTo(18, 54.5)
            ..quadraticBezierTo(22, 56, 27, 54.5),
          line..strokeWidth = 1.8,
        );
        canvas.drawPath(
          Path()
            ..moveTo(43, 58.5)
            ..cubicTo(40, 51, 37.5, 46.5, 36, 42),
          line..color = ink.withValues(alpha: 0.4),
        );
    }
  }

  static const _locks = 6;

  /// Where the mane's locks start and end along the crest of the neck,
  /// measured once (a faced knight's mane is drawn every frame).
  static final List<ui.Tangent> _crest = () {
    final edge = Path()
      ..moveTo(48, 18)
      ..cubicTo(58, 20.5, 64, 30, 63.5, 45)
      ..cubicTo(63.3, 53, 62.8, 60, 62.6, 66);
    final metric = edge.computeMetrics().first;
    return [
      for (var i = 0; i <= _locks; i++)
        metric.getTangentForOffset(metric.length * i / _locks)!,
    ];
  }();

  /// The knight's mane: sharp locks swept back off the crest of the neck
  /// like flames in the wind, in the set's rim color so they stand out.
  void _mane(Canvas canvas, Color ink) {
    final mane = Color.lerp(finish.rim.withValues(alpha: 1), ink, 0.25)!;
    final crest = _crest;
    final locks = Path();
    const count = _locks;
    for (var i = 0; i < count; i++) {
      final a = crest[i];
      final b = crest[i + 1];
      final along = a.vector;
      final outward = Offset(along.dy, -along.dx);
      final sway = math.sin(t * 2.2 + i * 0.8 + seed) * (_faced ? 1.0 : 0);
      final reach = (i.isEven ? 7.0 : 5.0) * (1 - i / count * 0.35);
      final tip =
          Offset.lerp(a.position, b.position, 0.5)! +
          outward * reach +
          along * 4 +
          Offset(sway, 0);
      final c1 = Offset.lerp(a.position, tip, 0.5)! + outward * 1.5;
      final c2 = Offset.lerp(b.position, tip, 0.6)! - along * 1.0;
      locks
        ..moveTo(a.position.dx, a.position.dy)
        ..quadraticBezierTo(c1.dx, c1.dy, tip.dx, tip.dy)
        ..quadraticBezierTo(c2.dx, c2.dy, b.position.dx, b.position.dy)
        ..close();
    }
    canvas.drawPath(locks, Paint()..color = mane);
    canvas.drawPath(
      locks,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round
        ..color = ink.withValues(alpha: 0.7),
    );
    // A forelock falling over the brow.
    canvas.drawPath(
      Path()
        ..moveTo(40.5, 21)
        ..quadraticBezierTo(37, 25, 34.5, 28.5)
        ..quadraticBezierTo(39.5, 26.5, 43.5, 21.5)
        ..close(),
      Paint()..color = mane,
    );
  }

  static Path _body(PieceType type) {
    final plinth = Path()
      ..addRRect(RRect.fromLTRBR(22, 82, 78, 93, const Radius.circular(4)))
      ..addRRect(RRect.fromLTRBR(27, 75, 73, 83, const Radius.circular(3)));

    final shape = switch (type) {
      PieceType.pawn =>
        Path()
          ..moveTo(36, 77)
          ..cubicTo(38, 66, 42, 60, 43, 54)
          ..lineTo(57, 54)
          ..cubicTo(58, 60, 62, 66, 64, 77)
          ..close()
          ..addRRect(RRect.fromLTRBR(37, 49, 63, 56, const Radius.circular(3)))
          ..addOval(
            Rect.fromCircle(center: const Offset(50, 36), radius: 13.5),
          ),
      PieceType.rook =>
        Path()
          ..moveTo(33, 77)
          ..lineTo(36, 42)
          ..lineTo(64, 42)
          ..lineTo(67, 77)
          ..close()
          ..addRRect(RRect.fromLTRBR(29, 30, 71, 44, const Radius.circular(2)))
          ..addRRect(
            RRect.fromLTRBR(29, 16, 39, 31, const Radius.circular(1.5)),
          )
          ..addRRect(
            RRect.fromLTRBR(45, 16, 55, 31, const Radius.circular(1.5)),
          )
          ..addRRect(
            RRect.fromLTRBR(61, 16, 71, 31, const Radius.circular(1.5)),
          ),
      PieceType.bishop =>
        Path()
          ..moveTo(37, 77)
          ..cubicTo(40, 68, 44, 62, 44, 57)
          ..lineTo(56, 57)
          ..cubicTo(56, 62, 60, 68, 63, 77)
          ..close()
          ..addRRect(RRect.fromLTRBR(37, 51, 63, 58, const Radius.circular(3)))
          ..moveTo(50, 15)
          ..cubicTo(61, 23, 67, 33, 63, 43)
          ..quadraticBezierTo(60, 52, 50, 52)
          ..quadraticBezierTo(40, 52, 37, 43)
          ..cubicTo(33, 33, 39, 23, 50, 15)
          ..close()
          ..addOval(
            Rect.fromCircle(center: const Offset(50, 11.5), radius: 4.5),
          ),
      PieceType.queen =>
        Path()
          ..moveTo(33, 77)
          ..cubicTo(37, 66, 41, 58, 41, 52)
          ..lineTo(59, 52)
          ..cubicTo(59, 58, 63, 66, 67, 77)
          ..close()
          ..addRRect(RRect.fromLTRBR(35, 45, 65, 53, const Radius.circular(3)))
          ..moveTo(34, 46)
          ..lineTo(24, 22)
          ..lineTo(32, 34)
          ..lineTo(37, 18)
          ..lineTo(44, 33)
          ..lineTo(50, 14)
          ..lineTo(56, 33)
          ..lineTo(63, 18)
          ..lineTo(68, 34)
          ..lineTo(76, 22)
          ..lineTo(66, 46)
          ..close()
          ..addOval(Rect.fromCircle(center: const Offset(24, 20), radius: 4))
          ..addOval(Rect.fromCircle(center: const Offset(37, 16), radius: 4))
          ..addOval(
            Rect.fromCircle(center: const Offset(50, 11.5), radius: 4.5),
          )
          ..addOval(Rect.fromCircle(center: const Offset(63, 16), radius: 4))
          ..addOval(Rect.fromCircle(center: const Offset(76, 20), radius: 4)),
      PieceType.king =>
        Path()
          ..moveTo(33, 77)
          ..cubicTo(37, 66, 41, 60, 41, 54)
          ..lineTo(59, 54)
          ..cubicTo(59, 60, 63, 66, 67, 77)
          ..close()
          ..addRRect(RRect.fromLTRBR(34, 47, 66, 55, const Radius.circular(3)))
          ..moveTo(35, 48)
          ..cubicTo(26, 40, 30, 27, 42, 28)
          ..cubicTo(46, 28.5, 49, 31, 50, 34)
          ..cubicTo(51, 31, 54, 28.5, 58, 28)
          ..cubicTo(70, 27, 74, 40, 65, 48)
          ..close()
          ..addRRect(
            RRect.fromLTRBR(46.5, 6, 53.5, 32, const Radius.circular(2)),
          )
          ..addRRect(RRect.fromLTRBR(40, 12, 60, 19, const Radius.circular(2))),
      // A sleek horse: a slim arched neck, a narrow head and a sharp ear.
      PieceType.knight =>
        Path()
          ..moveTo(36, 77)
          ..cubicTo(35, 69, 38, 63, 43, 58.5)
          ..cubicTo(38, 59.5, 32, 59.5, 27, 58)
          ..cubicTo(21, 56.5, 16.5, 53, 17.5, 48.5)
          ..cubicTo(18.5, 45, 22, 43, 26, 40.5)
          ..cubicTo(30, 34, 34, 28.5, 39, 24)
          ..lineTo(43, 7.5)
          ..lineTo(48, 18)
          ..cubicTo(58, 20.5, 64, 30, 63.5, 45)
          ..cubicTo(63, 58, 62, 68, 64, 77)
          ..close(),
    };

    // One clean silhouette, so the outline only traces the outside.
    var union = Path.combine(PathOperation.union, plinth, Path());
    for (final metric in shape.computeMetrics()) {
      final part = metric.extractPath(0, metric.length)..close();
      union = Path.combine(PathOperation.union, union, part);
    }
    return union;
  }

  @override
  bool shouldRepaint(covariant ChessPieceArtPainter old) =>
      old.type != type ||
      old.finish != finish ||
      old.glowColor != glowColor ||
      old.character != character ||
      old.mood != mood ||
      old.look != look ||
      (_faced || mood == PieceMood.ko) && old.t != t;
}
