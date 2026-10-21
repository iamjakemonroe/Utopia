import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/ludo_engine.dart';

/// Each seat's color. Kept bright and well apart so six players stay easy
/// to tell apart on any theme.
const Map<LudoColor, Color> ludoColorPalette = {
  LudoColor.red: Color(0xFFFF5C6C),
  LudoColor.green: Color(0xFF2FD98E),
  LudoColor.yellow: Color(0xFFFFC93D),
  LudoColor.blue: Color(0xFF4DA3FF),
  LudoColor.orange: Color(0xFFFF8A3D),
  LudoColor.purple: Color(0xFFB27BFF),
};

String ludoColorName(LudoColor color) =>
    '${color.name[0].toUpperCase()}${color.name.substring(1)}';

/// "1st", "2nd", "3rd", "4th"...
String placeLabel(int place) => switch (place) {
  1 => '1st',
  2 => '2nd',
  3 => '3rd',
  _ => '${place}th',
};

/// The medal colors for the first three places (light, mid, dark).
const Map<int, List<Color>> kPlaceMedals = {
  1: [Color(0xFFFFF0B8), Color(0xFFFFC94D), Color(0xFFD9962A)],
  2: [Color(0xFFFFFFFF), Color(0xFFD5DCE8), Color(0xFF9AA6B8)],
  3: [Color(0xFFFFD9B8), Color(0xFFE09A5E), Color(0xFFA8622E)],
};

/// A capture reaction playing on a token: the piece that captured goes
/// [war] or [peace]; the piece sent home goes [sad], or [again] (not
/// giving up).
enum TokenReaction { none, war, peace, sad, again }

/// Paints one Ludo token in a piece set's style, standing on the bottom
/// center of its box (the box is taller than wide: [aspect]). Every style
/// shares the ground shadow, the "you can move this" glow ring, and the
/// reaction overlays (war, peace, sad, again).
class LudoTokenPainter extends CustomPainter {
  LudoTokenPainter({
    required this.setId,
    required this.color,
    required this.t,
    this.highlight = 0,
    this.reaction = TokenReaction.none,
    this.reactionProgress = 0,
    this.lift = 0,
  });

  /// Height / width of the box a token is painted in.
  static const aspect = 1.3;

  final String setId;
  final LudoColor color;

  /// Seconds, for idle motion (blinks, sparkles, orbiting moons).
  final double t;

  /// 0-1: how strongly the "movable" ring glows.
  final double highlight;
  final TokenReaction reaction;
  final double reactionProgress;

  /// 0-1: how high the token is mid-hop (shrinks its shadow).
  final double lift;

  Color get _base => ludoColorPalette[color]!;
  Color _light(double a) => Color.lerp(_base, Colors.white, a)!;
  Color _dark(double a) => Color.lerp(_base, Colors.black, a)!;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final ground = Offset(w / 2, size.height * 0.92);
    _shadow(canvas, ground, w);
    if (highlight > 0) _ring(canvas, ground, w);

    final shake = reaction == TokenReaction.war && reactionProgress < 0.85
        ? math.sin(t * 40) * 0.06 * math.sin(reactionProgress * math.pi)
        : 0.0;
    final s = _strength;
    // Fired up: flames licking up behind it, and it pumps on the spot.
    if (reaction == TokenReaction.again && s > 0) {
      _flames(canvas, ground, w, s);
    }
    final pump = reaction == TokenReaction.again
        ? (math.sin(t * 9)).abs() * w * 0.07 * s
        : 0.0;
    canvas.save();
    canvas.translate(ground.dx, ground.dy - pump);
    canvas.rotate(shake);
    // Sad: it slumps.
    if (reaction == TokenReaction.sad) {
      canvas.scale(1 + 0.05 * s, 1 - 0.08 * s);
    }
    canvas.translate(-ground.dx, -ground.dy);

    final Offset face;
    switch (setId) {
      case 'bubble':
        face = _bubble(canvas, ground, w);
      case 'jelly':
        face = _jelly(canvas, ground, w);
      case 'crystal':
        face = _crystal(canvas, ground, w);
      case 'candy':
        face = _candy(canvas, ground, w);
      case 'cosmic':
        face = _cosmic(canvas, ground, w);
      case 'royal':
        face = _royal(canvas, ground, w);
      default:
        face = _classic(canvas, ground, w);
    }

    if (reaction != TokenReaction.none) _reaction(canvas, face, w);
    canvas.restore();
  }

  // ── shared ───────────────────────────────────────────────────────────────

  void _shadow(Canvas canvas, Offset ground, double w) {
    final s = 1 - 0.45 * lift;
    canvas.drawOval(
      Rect.fromCenter(
        center: ground.translate(0, w * 0.02),
        width: w * 0.72 * s,
        height: w * 0.2 * s,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.32 * (1 - 0.5 * lift)),
    );
  }

  void _ring(Canvas canvas, Offset ground, double w) {
    final pulse = 0.5 + 0.5 * math.sin(t * 6);
    final rect = Rect.fromCenter(
      center: ground,
      width: w * (0.95 + 0.12 * pulse),
      height: w * (0.34 + 0.05 * pulse),
    );
    canvas.drawOval(
      rect.inflate(w * 0.06),
      Paint()..color = AppColors.coinGold.withValues(alpha: 0.25 * highlight),
    );
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.06
        ..color = AppColors.coinGoldBright.withValues(alpha: highlight),
    );
  }

  void _gloss(Canvas canvas, Offset c, double r) {
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(-r * 0.35, -r * 0.42),
        width: r * 0.7,
        height: r * 0.42,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.75),
    );
  }

  Paint _sphere(Offset c, double r, List<Color> colors) => Paint()
    ..shader = RadialGradient(
      center: const Alignment(-0.35, -0.4),
      radius: 1.05,
      colors: colors,
    ).createShader(Rect.fromCircle(center: c, radius: r));

  // ── styles (each returns where a reaction face goes) ────────────────────

  Offset _classic(Canvas canvas, Offset g, double w) {
    final base = Rect.fromCenter(
      center: g.translate(0, -w * 0.05),
      width: w * 0.78,
      height: w * 0.26,
    );
    canvas.drawOval(
      base.shift(Offset(0, w * 0.03)),
      Paint()..color = _dark(0.45),
    );
    canvas.drawOval(
      base,
      Paint()
        ..shader = LinearGradient(
          colors: [_light(0.35), _base, _dark(0.3)],
        ).createShader(base),
    );
    final body = Path()
      ..moveTo(g.dx - w * 0.3, g.dy - w * 0.08)
      ..quadraticBezierTo(
        g.dx - w * 0.2,
        g.dy - w * 0.3,
        g.dx - w * 0.11,
        g.dy - w * 0.52,
      )
      ..lineTo(g.dx + w * 0.11, g.dy - w * 0.52)
      ..quadraticBezierTo(
        g.dx + w * 0.2,
        g.dy - w * 0.3,
        g.dx + w * 0.3,
        g.dy - w * 0.08,
      )
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          stops: const [0.0, 0.35, 1.0],
          colors: [_light(0.45), _base, _dark(0.35)],
        ).createShader(body.getBounds()),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: g.translate(0, -w * 0.52),
        width: w * 0.32,
        height: w * 0.1,
      ),
      Paint()..color = _light(0.5),
    );
    final head = g.translate(0, -w * 0.74);
    final r = w * 0.24;
    canvas.drawCircle(
      head,
      r,
      _sphere(head, r, [_light(0.75), _base, _dark(0.35)]),
    );
    _gloss(canvas, head, r);
    return head;
  }

  Offset _bubble(Canvas canvas, Offset g, double w) {
    final bob = math.sin(t * 2.4 + color.index) * w * 0.03;
    final c = g.translate(0, -w * 0.42 + bob);
    final r = w * 0.36;
    canvas.drawOval(
      Rect.fromCenter(
        center: g.translate(0, -w * 0.03),
        width: w * 0.5,
        height: w * 0.14,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.04
        ..color = _light(0.3),
    );
    // A solid core floating inside the glassy shell.
    canvas.drawCircle(
      c.translate(0, w * 0.03),
      r * 0.45,
      _sphere(c, r * 0.45, [_light(0.6), _base, _dark(0.3)]),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          stops: const [0.0, 0.7, 1.0],
          colors: [
            _base.withValues(alpha: 0.05),
            _base.withValues(alpha: 0.18),
            _light(0.4).withValues(alpha: 0.6),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r * 0.97,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.035
        ..shader = SweepGradient(
          colors: [
            _light(0.5),
            const Color(0xFF8FD3FF),
            const Color(0xFFFF9ECF),
            _light(0.5),
          ],
          transform: GradientRotation(t * 0.8),
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.78),
      math.pi * 1.1,
      math.pi * 0.35,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = w * 0.05
        ..color = Colors.white.withValues(alpha: 0.7),
    );
    return c;
  }

  Offset _jelly(Canvas canvas, Offset g, double w) {
    final wobble = math.sin(t * 5 + color.index * 1.3) * 0.045;
    canvas.save();
    canvas.translate(g.dx, g.dy);
    canvas.scale(1 + wobble, 1 - wobble);
    canvas.translate(-g.dx, -g.dy);
    final body = Path()
      ..moveTo(g.dx - w * 0.38, g.dy - w * 0.04)
      ..quadraticBezierTo(
        g.dx - w * 0.42,
        g.dy - w * 0.72,
        g.dx,
        g.dy - w * 0.76,
      )
      ..quadraticBezierTo(
        g.dx + w * 0.42,
        g.dy - w * 0.72,
        g.dx + w * 0.38,
        g.dy - w * 0.04,
      )
      ..quadraticBezierTo(
        g.dx,
        g.dy + w * 0.04,
        g.dx - w * 0.38,
        g.dy - w * 0.04,
      )
      ..close();
    final bounds = body.getBounds();
    canvas.drawPath(
      body,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.2, -0.3),
          colors: [_light(0.55), _base, _dark(0.25)],
        ).createShader(bounds),
    );
    // Sugar sparkles.
    final sugar = Paint()..color = Colors.white.withValues(alpha: 0.55);
    for (var i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(
          g.dx + (i - 2) * w * 0.12,
          g.dy - w * (0.18 + 0.1 * ((i * 7) % 3)),
        ),
        w * 0.018,
        sugar,
      );
    }
    _gloss(canvas, g.translate(-w * 0.04, -w * 0.5), w * 0.3);
    final face = g.translate(0, -w * 0.4);
    if (reaction == TokenReaction.none) _cuteFace(canvas, face, w);
    canvas.restore();
    return face;
  }

  void _cuteFace(Canvas canvas, Offset c, double w) {
    final blink = (t + color.index) % 3.4 < 0.13;
    final ink = Paint()..color = AppColors.faceInk;
    for (final side in const [-1.0, 1.0]) {
      final e = c.translate(side * w * 0.11, -w * 0.02);
      if (blink) {
        canvas.drawLine(
          e.translate(-w * 0.04, 0),
          e.translate(w * 0.04, 0),
          ink..strokeWidth = w * 0.025,
        );
      } else {
        canvas.drawOval(
          Rect.fromCenter(center: e, width: w * 0.09, height: w * 0.11),
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(e.translate(0, w * 0.01), w * 0.03, ink);
      }
    }
    canvas.drawArc(
      Rect.fromCenter(
        center: c.translate(0, w * 0.05),
        width: w * 0.12,
        height: w * 0.08,
      ),
      0.15 * math.pi,
      0.7 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.022
        ..strokeCap = StrokeCap.round
        ..color = AppColors.faceInk,
    );
  }

  Offset _crystal(Canvas canvas, Offset g, double w) {
    final c = g.translate(0, -w * 0.42);
    final top = g.translate(0, -w * 0.9);
    final bottom = g.translate(0, -w * 0.02);
    final ul = Offset(g.dx - w * 0.24, g.dy - w * 0.68);
    final ur = Offset(g.dx + w * 0.24, g.dy - w * 0.68);
    final ml = Offset(g.dx - w * 0.3, g.dy - w * 0.36);
    final mr = Offset(g.dx + w * 0.3, g.dy - w * 0.36);
    final mid = Offset(g.dx + w * 0.02, g.dy - w * 0.5);
    void facet(List<Offset> pts, Color fill) {
      canvas.drawPath(Path()..addPolygon(pts, true), Paint()..color = fill);
    }

    facet([top, ul, mid], _light(0.7));
    facet([top, mid, ur], _light(0.35));
    facet([ul, ml, mid], _light(0.5));
    facet([ur, mid, mr], _dark(0.1));
    facet([ml, bottom, mid], _base);
    facet([mid, bottom, mr], _dark(0.3));
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.015
      ..color = Colors.white.withValues(alpha: 0.6);
    canvas.drawPath(
      Path()..addPolygon([top, ur, mr, bottom, ml, ul], true),
      edge,
    );
    // A glint that flares every couple of seconds.
    final flare = math.max(0.0, math.sin(t * 2.2 + color.index));
    if (flare > 0.6) {
      final s = w * 0.16 * (flare - 0.6) / 0.4;
      final p = top.translate(-w * 0.06, w * 0.12);
      final glint = Paint()
        ..strokeWidth = w * 0.02
        ..strokeCap = StrokeCap.round
        ..color = Colors.white;
      canvas.drawLine(p.translate(-s, 0), p.translate(s, 0), glint);
      canvas.drawLine(p.translate(0, -s), p.translate(0, s), glint);
    }
    return c;
  }

  Offset _candy(Canvas canvas, Offset g, double w) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: g.translate(0, -w * 0.18),
          width: w * 0.08,
          height: w * 0.36,
        ),
        Radius.circular(w * 0.04),
      ),
      Paint()..color = const Color(0xFFFFF4F8),
    );
    final c = g.translate(0, -w * 0.58);
    final r = w * 0.33;
    canvas.drawCircle(c, r, _sphere(c, r, [_light(0.5), _base, _dark(0.2)]));
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    final swirl = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.22
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.75);
    final spiral = Path();
    for (var i = 0; i <= 60; i++) {
      final a = i / 60 * 4 * math.pi + t * 1.5;
      final rr = r * i / 60;
      final p = c + Offset(math.cos(a), math.sin(a)) * rr;
      if (i == 0) {
        spiral.moveTo(p.dx, p.dy);
      } else {
        spiral.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(spiral, swirl);
    canvas.restore();
    _gloss(canvas, c, r);
    return c;
  }

  Offset _cosmic(Canvas canvas, Offset g, double w) {
    final c = g.translate(
      0,
      -w * 0.46 + math.sin(t * 1.8 + color.index) * w * 0.025,
    );
    final r = w * 0.27;
    final ring = Rect.fromCenter(center: c, width: w * 0.92, height: w * 0.26);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045
      ..color = _light(0.6).withValues(alpha: 0.9);
    final moonAngle = t * 2.2 + color.index;
    final moon =
        c +
        Offset(math.cos(moonAngle) * w * 0.44, math.sin(moonAngle) * w * 0.12);
    final moonPaint = Paint()..color = const Color(0xFFEFF3FF);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-0.3);
    canvas.translate(-c.dx, -c.dy);
    canvas.drawArc(ring, math.pi, math.pi, false, ringPaint);
    if (math.sin(moonAngle) < 0) canvas.drawCircle(moon, w * 0.05, moonPaint);
    canvas.drawCircle(c, r, _sphere(c, r, [_light(0.6), _base, _dark(0.45)]));
    final speck = Paint()..color = Colors.white.withValues(alpha: 0.4);
    canvas.drawCircle(c.translate(r * 0.3, r * 0.2), r * 0.12, speck);
    canvas.drawCircle(c.translate(-r * 0.2, r * 0.45), r * 0.08, speck);
    canvas.drawArc(ring, 0, math.pi, false, ringPaint);
    if (math.sin(moonAngle) >= 0) canvas.drawCircle(moon, w * 0.05, moonPaint);
    canvas.restore();
    _gloss(canvas, c, r);
    return c;
  }

  Offset _royal(Canvas canvas, Offset g, double w) {
    const gold = [Color(0xFFFFF0B8), Color(0xFFFFC94D), Color(0xFFB8801F)];
    final base = Rect.fromCenter(
      center: g.translate(0, -w * 0.05),
      width: w * 0.8,
      height: w * 0.26,
    );
    canvas.drawOval(
      base.shift(Offset(0, w * 0.03)),
      Paint()..color = const Color(0xFF7A5210),
    );
    canvas.drawOval(
      base,
      Paint()..shader = const LinearGradient(colors: gold).createShader(base),
    );
    canvas.drawOval(
      base.deflate(w * 0.05),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.035
        ..color = _base,
    );
    final body = Path()
      ..moveTo(g.dx - w * 0.28, g.dy - w * 0.08)
      ..quadraticBezierTo(
        g.dx - w * 0.16,
        g.dy - w * 0.3,
        g.dx - w * 0.12,
        g.dy - w * 0.5,
      )
      ..lineTo(g.dx + w * 0.12, g.dy - w * 0.5)
      ..quadraticBezierTo(
        g.dx + w * 0.16,
        g.dy - w * 0.3,
        g.dx + w * 0.28,
        g.dy - w * 0.08,
      )
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          colors: gold,
        ).createShader(body.getBounds()),
    );
    final jewel = g.translate(0, -w * 0.66);
    final r = w * 0.19;
    canvas.drawCircle(
      jewel,
      r,
      _sphere(jewel, r, [_light(0.7), _base, _dark(0.4)]),
    );
    _gloss(canvas, jewel, r);
    // Crown.
    final cy = jewel.dy - r * 0.9;
    final crown = Path()
      ..moveTo(jewel.dx - w * 0.2, cy)
      ..lineTo(jewel.dx - w * 0.22, cy - w * 0.16)
      ..lineTo(jewel.dx - w * 0.1, cy - w * 0.07)
      ..lineTo(jewel.dx, cy - w * 0.2)
      ..lineTo(jewel.dx + w * 0.1, cy - w * 0.07)
      ..lineTo(jewel.dx + w * 0.22, cy - w * 0.16)
      ..lineTo(jewel.dx + w * 0.2, cy)
      ..close();
    canvas.drawPath(
      crown,
      Paint()
        ..shader = const LinearGradient(
          colors: gold,
        ).createShader(crown.getBounds()),
    );
    for (final dx in const [-0.22, 0.0, 0.22]) {
      canvas.drawCircle(
        Offset(jewel.dx + w * dx, cy - w * (dx == 0 ? 0.2 : 0.16)),
        w * 0.028,
        Paint()..color = Colors.white,
      );
    }
    return jewel;
  }

  // ── reactions ────────────────────────────────────────────────────────────

  /// How much the reaction shows: in fast, hold, then fade back to the
  /// plain piece.
  double get _strength {
    if (reaction == TokenReaction.none) return 0;
    final p = reactionProgress;
    return p < 0.15
        ? Curves.easeOutBack.transform(p / 0.15)
        : (p > 0.82 ? (1 - p) / 0.18 : 1.0);
  }

  void _reaction(Canvas canvas, Offset face, double w) {
    final strength = _strength;
    if (strength <= 0) return;
    switch (reaction) {
      case TokenReaction.war:
        _warFace(canvas, face, w, strength);
      case TokenReaction.peace:
        _peaceFace(canvas, face, w, strength);
      case TokenReaction.sad:
        _sadFace(canvas, face, w, strength);
      case TokenReaction.again:
        _againFace(canvas, face, w, strength);
      case TokenReaction.none:
    }
  }

  /// Sent home and sad about it: a little rain cloud of its own, brows up,
  /// a wobbling frown, and tears running down.
  void _sadFace(Canvas canvas, Offset c, double w, double s) {
    final a = s.clamp(0.0, 1.0);
    canvas.drawCircle(
      c,
      w * 0.55,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF7FB8FF).withValues(alpha: 0.35 * a),
            const Color(0x007FB8FF),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: w * 0.55)),
    );
    final ink = AppColors.faceInk.withValues(alpha: a);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * 0.024
      ..color = ink;
    for (final side in const [-1.0, 1.0]) {
      // Brows up in the middle.
      canvas.drawLine(
        c.translate(side * w * 0.04, -w * 0.085),
        c.translate(side * w * 0.14, -w * 0.05),
        line,
      );
      // Big wet eyes looking down.
      final e = c.translate(side * w * 0.09, -w * 0.005);
      canvas.drawOval(
        Rect.fromCenter(center: e, width: w * 0.06, height: w * 0.07),
        Paint()..color = ink,
      );
      canvas.drawCircle(
        e.translate(-w * 0.012, -w * 0.016),
        w * 0.013,
        Paint()..color = Colors.white.withValues(alpha: a),
      );
      canvas.drawArc(
        Rect.fromCenter(
          center: e.translate(0, w * 0.012),
          width: w * 0.07,
          height: w * 0.06,
        ),
        0.15 * math.pi,
        0.7 * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.014
          ..color = const Color(0xFF8FD8FF).withValues(alpha: a),
      );
      // Tears, one after another.
      for (var k = 0; k < 3; k++) {
        final life = (t * 1.3 + k / 3 + (side > 0 ? 0.17 : 0)) % 1.0;
        _tear(
          canvas,
          e.translate(side * w * 0.025, w * 0.05 + life * w * 0.32),
          w * 0.03 * (1 - 0.3 * life),
          a * (1 - life),
        );
      }
    }
    // A trembling frown.
    final wobble = math.sin(t * 28) * w * 0.004;
    canvas.drawArc(
      Rect.fromCenter(
        center: c.translate(wobble, w * 0.115),
        width: w * 0.13,
        height: w * 0.08,
      ),
      1.15 * math.pi,
      0.7 * math.pi,
      false,
      line,
    );
    // Its own little rain cloud.
    final cloud = c.translate(
      math.sin(t * 1.6) * w * 0.03,
      -w * (0.46 + 0.1 * (1 - a)),
    );
    final grey = Paint()..color = const Color(0xFF9AA6B8).withValues(alpha: a);
    final dark = Paint()..color = const Color(0xFF6E7A8E).withValues(alpha: a);
    for (final (dx, dy, r) in const [
      (-0.1, 0.02, 0.07),
      (0.0, -0.02, 0.09),
      (0.1, 0.02, 0.065),
    ]) {
      canvas.drawCircle(
        cloud.translate(dx * w, dy * w + w * 0.012),
        r * w,
        dark,
      );
      canvas.drawCircle(cloud.translate(dx * w, dy * w), r * w, grey);
    }
    final rain = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * 0.014;
    for (var k = 0; k < 4; k++) {
      final life = (t * 2.2 + k * 0.27) % 1.0;
      final x = cloud.dx + (k - 1.5) * w * 0.06;
      final y = cloud.dy + w * 0.08 + life * w * 0.16;
      canvas.drawLine(
        Offset(x, y),
        Offset(x - w * 0.008, y + w * 0.035),
        rain..color = const Color(0xFF8FD8FF).withValues(alpha: a * (1 - life)),
      );
    }
  }

  void _tear(Canvas canvas, Offset c, double r, double alpha) {
    if (alpha <= 0) return;
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - r * 1.8)
        ..quadraticBezierTo(c.dx + r * 1.1, c.dy - r * 0.2, c.dx, c.dy + r)
        ..quadraticBezierTo(
          c.dx - r * 1.1,
          c.dy - r * 0.2,
          c.dx,
          c.dy - r * 1.8,
        )
        ..close(),
      Paint()..color = const Color(0xFF8FD8FF).withValues(alpha: alpha),
    );
  }

  /// Sent home and not giving up: flames behind it (see [_flames]), a
  /// headband with its ends flying, brows down and a gritted grin.
  void _againFace(Canvas canvas, Offset c, double w, double s) {
    final a = s.clamp(0.0, 1.0);
    final ink = AppColors.faceInk.withValues(alpha: a);
    // The headband, its two ends streaming out behind.
    const red = Color(0xFFFF3B4E);
    final band = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: c.translate(0, -w * 0.115),
        width: w * 0.42 * (0.6 + 0.4 * a),
        height: w * 0.065,
      ),
      Radius.circular(w * 0.03),
    );
    for (var k = 0; k < 2; k++) {
      final flap = math.sin(t * 14 + k * 1.7) * w * 0.035;
      final from = Offset(band.right - w * 0.02, band.center.dy);
      canvas.drawPath(
        Path()
          ..moveTo(from.dx, from.dy - w * 0.02)
          ..quadraticBezierTo(
            from.dx + w * 0.1,
            from.dy - w * 0.02 + flap + k * w * 0.04,
            from.dx + w * 0.2,
            from.dy + flap * 1.6 + k * w * 0.07,
          )
          ..lineTo(
            from.dx + w * 0.17,
            from.dy + w * 0.035 + flap + k * w * 0.07,
          )
          ..quadraticBezierTo(
            from.dx + w * 0.08,
            from.dy + w * 0.02 + flap * 0.5,
            from.dx,
            from.dy + w * 0.02,
          )
          ..close(),
        Paint()
          ..color = Color.lerp(
            red,
            Colors.black,
            0.15 * k,
          )!.withValues(alpha: a),
      );
    }
    canvas.drawRRect(band, Paint()..color = red.withValues(alpha: a));
    canvas.drawCircle(
      band.center,
      w * 0.022,
      Paint()..color = Colors.white.withValues(alpha: a),
    );
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * 0.03
      ..color = ink;
    for (final side in const [-1.0, 1.0]) {
      // Brows down toward the middle: determined.
      canvas.drawLine(
        c.translate(side * w * 0.035, -w * 0.045),
        c.translate(side * w * 0.14, -w * 0.075),
        line,
      );
      final e = c.translate(side * w * 0.09, -w * 0.005);
      canvas.drawOval(
        Rect.fromCenter(center: e, width: w * 0.055, height: w * 0.05),
        Paint()..color = ink,
      );
      canvas.drawCircle(
        e.translate(-w * 0.01, -w * 0.01),
        w * 0.01,
        Paint()..color = Colors.white.withValues(alpha: a),
      );
    }
    // A gritted, can-do grin.
    final teeth = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: c.translate(0, w * 0.085),
        width: w * 0.15,
        height: w * 0.055,
      ),
      Radius.circular(w * 0.022),
    );
    canvas.drawRRect(teeth, Paint()..color = Colors.white.withValues(alpha: a));
    canvas.drawRRect(
      teeth,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.016
        ..color = ink,
    );
    canvas.drawLine(
      Offset(teeth.left + w * 0.01, teeth.center.dy),
      Offset(teeth.right - w * 0.01, teeth.center.dy),
      Paint()
        ..strokeWidth = w * 0.01
        ..color = ink,
    );
  }

  /// Flames licking up behind a fired-up piece, and sparks rising off them.
  void _flames(Canvas canvas, Offset g, double w, double s) {
    final a = s.clamp(0.0, 1.0);
    final base = g.translate(0, -w * 0.18);
    final rect = Rect.fromCenter(
      center: g.translate(0, -w * 0.6),
      width: w,
      height: w * 1.1,
    );
    final fire = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          const Color(0xFFFF4D2E).withValues(alpha: 0.9 * a),
          const Color(0xFFFFB02E).withValues(alpha: 0.85 * a),
          const Color(0x00FFE066),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect);
    for (var k = 0; k < 5; k++) {
      final x = (k - 2) * w * 0.16;
      final lick = 0.75 + 0.25 * math.sin(t * 11 + k * 1.9);
      final h =
          w * (0.55 + 0.25 * (2 - (k - 2).abs()) / 2) * lick * (0.4 + 0.6 * a);
      final half = w * 0.12;
      final foot = base.translate(x, 0);
      final sway = math.sin(t * 7 + k) * w * 0.04;
      canvas.drawPath(
        Path()
          ..moveTo(foot.dx - half, foot.dy)
          ..quadraticBezierTo(
            foot.dx - half,
            foot.dy - h * 0.6,
            foot.dx + sway,
            foot.dy - h,
          )
          ..quadraticBezierTo(
            foot.dx + half,
            foot.dy - h * 0.6,
            foot.dx + half,
            foot.dy,
          )
          ..close(),
        fire,
      );
    }
    final spark = Paint();
    for (var k = 0; k < 6; k++) {
      final life = (t * 1.5 + k / 6) % 1.0;
      final p = base.translate(
        (k - 2.5) * w * 0.13 + math.sin(t * 5 + k) * w * 0.03,
        -w * (0.5 + 0.6 * life),
      );
      canvas.drawCircle(
        p,
        w * 0.018 * (1 - life),
        spark
          ..color = const Color(0xFFFFE066).withValues(alpha: a * (1 - life)),
      );
    }
  }

  void _warFace(Canvas canvas, Offset c, double w, double s) {
    final glow = 0.6 + 0.4 * math.sin(t * 12);
    canvas.drawCircle(
      c,
      w * 0.6,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFF2D55).withValues(alpha: 0.5 * s * glow),
            const Color(0x00FF2D55),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: w * 0.6)),
    );
    // Horns.
    final horn = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Color(0xFF8A0F2E), Color(0xFFFF4D6D)],
      ).createShader(Rect.fromCircle(center: c, radius: w * 0.5));
    for (final side in const [-1.0, 1.0]) {
      final base = c.translate(side * w * 0.14, -w * 0.2);
      canvas.drawPath(
        Path()
          ..moveTo(base.dx - side * w * 0.06, base.dy + w * 0.03)
          ..quadraticBezierTo(
            base.dx + side * w * 0.02,
            base.dy - w * 0.12 * s,
            base.dx + side * w * 0.12 * s,
            base.dy - w * 0.2 * s,
          )
          ..quadraticBezierTo(
            base.dx + side * w * 0.1,
            base.dy - w * 0.02,
            base.dx + side * w * 0.07,
            base.dy + w * 0.05,
          )
          ..close(),
        horn,
      );
    }
    // Narrowed eyes and a fanged grin.
    final ink = Paint()..color = AppColors.faceInk;
    for (final side in const [-1.0, 1.0]) {
      final e = c.translate(side * w * 0.09, -w * 0.02);
      canvas.drawPath(
        Path()
          ..moveTo(e.dx - w * 0.06, e.dy - side * 0.0 - w * 0.03 * side)
          ..lineTo(e.dx + w * 0.06, e.dy + w * 0.03 * side)
          ..lineTo(e.dx, e.dy + w * 0.04)
          ..close(),
        Paint()..color = const Color(0xFFFFE066).withValues(alpha: s),
      );
    }
    final grin = Path()
      ..moveTo(c.dx - w * 0.13, c.dy + w * 0.06)
      ..quadraticBezierTo(
        c.dx,
        c.dy + w * 0.11,
        c.dx + w * 0.13,
        c.dy + w * 0.06,
      )
      ..quadraticBezierTo(
        c.dx,
        c.dy + w * 0.2,
        c.dx - w * 0.13,
        c.dy + w * 0.06,
      )
      ..close();
    canvas.drawPath(grin, ink..color = AppColors.faceInk.withValues(alpha: s));
    final fang = Paint()..color = Colors.white.withValues(alpha: s);
    for (final side in const [-1.0, 1.0]) {
      final f = c.translate(side * w * 0.05, w * 0.085);
      canvas.drawPath(
        Path()
          ..moveTo(f.dx - w * 0.02, f.dy)
          ..lineTo(f.dx + w * 0.02, f.dy)
          ..lineTo(f.dx, f.dy + w * 0.04)
          ..close(),
        fang,
      );
    }
  }

  void _peaceFace(Canvas canvas, Offset c, double w, double s) {
    canvas.drawCircle(
      c,
      w * 0.55,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.45 * s),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: w * 0.55)),
    );
    // Halo.
    final halo = c.translate(0, -w * (0.36 + 0.03 * math.sin(t * 3)));
    canvas.drawOval(
      Rect.fromCenter(center: halo, width: w * 0.36, height: w * 0.1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.035
        ..color = AppColors.coinGoldBright.withValues(alpha: s),
    );
    // Closed happy eyes and a soft smile.
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * 0.025
      ..color = AppColors.faceInk.withValues(alpha: s);
    for (final side in const [-1.0, 1.0]) {
      canvas.drawArc(
        Rect.fromCenter(
          center: c.translate(side * w * 0.09, 0),
          width: w * 0.08,
          height: w * 0.07,
        ),
        math.pi * 1.1,
        math.pi * 0.8,
        false,
        line,
      );
    }
    canvas.drawArc(
      Rect.fromCenter(
        center: c.translate(0, w * 0.06),
        width: w * 0.14,
        height: w * 0.1,
      ),
      0.12 * math.pi,
      0.76 * math.pi,
      false,
      line,
    );
    // Hearts drifting up.
    for (var i = 0; i < 3; i++) {
      final life = (reactionProgress * 2 + i / 3) % 1.0;
      final p = c.translate((i - 1) * w * 0.25, -w * 0.3 - life * w * 0.5);
      _heart(canvas, p, w * 0.06, s * math.sin(life * math.pi));
    }
  }

  void _heart(Canvas canvas, Offset c, double r, double alpha) {
    final path = Path()
      ..moveTo(c.dx, c.dy + r * 0.9)
      ..cubicTo(
        c.dx - r * 1.4,
        c.dy - r * 0.1,
        c.dx - r * 0.6,
        c.dy - r,
        c.dx,
        c.dy - r * 0.35,
      )
      ..cubicTo(
        c.dx + r * 0.6,
        c.dy - r,
        c.dx + r * 1.4,
        c.dy - r * 0.1,
        c.dx,
        c.dy + r * 0.9,
      )
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = const Color(0xFFFF8FB8).withValues(alpha: alpha),
    );
  }

  @override
  bool shouldRepaint(covariant LudoTokenPainter old) =>
      old.setId != setId ||
      old.color != color ||
      old.highlight != highlight ||
      old.reaction != reaction ||
      old.reactionProgress != reactionProgress ||
      old.lift != lift ||
      (old.t != t && _animatesIdle);

  /// Styles with idle motion repaint every frame; the rest only on change.
  bool get _animatesIdle =>
      highlight > 0 ||
      reaction != TokenReaction.none ||
      const {'bubble', 'jelly', 'crystal', 'candy', 'cosmic'}.contains(setId);
}
