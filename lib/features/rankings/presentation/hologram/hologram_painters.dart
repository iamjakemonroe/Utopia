import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/ranking.dart';

/// Stable pseudo-random 0-1 from an index.
double _rand(int i, int salt) {
  final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

Color _a(Color c, double alpha) =>
    c.withValues(alpha: (c.a * alpha).clamp(0.0, 1.0));

/// Legend's big strikes, in seconds after the hologram opens: the first
/// just after it's up, then every seven seconds or so. Its thunder plays
/// on the same beat (the hologram listens for them), so the boom lands
/// with the flash.
double legendStrikeAt(int k) => 1.2 + k * 7.0 + _rand(k, 77) * 1.6;

/// Which big strike is lighting things at [t], and how brightly (1 the
/// moment it hits, fading over half a second), or null between them.
({int k, double glow})? legendStrike(double t) {
  for (var k = 0; ; k++) {
    final at = legendStrikeAt(k);
    if (at > t) return null;
    if (t - at < 0.55) {
      final f = 1 - (t - at) / 0.55;
      return (k: k, glow: f * f);
    }
  }
}

/// Where the hologram is: its panel, and the projector under it.
class HoloStage {
  const HoloStage({required this.panel, required this.projector});

  final Rect panel;
  final Offset projector;
}

/// Behind the hologram: the projector and its beam, the panel's glassy
/// body (scanlines, a sweeping scan bar, glowing edges, corner brackets)
/// and the tier's aura around it.
class HoloBackPainter extends CustomPainter {
  HoloBackPainter({
    required this.tier,
    required this.stage,
    required this.clock,
    required this.reveal,
  }) : super(repaint: Listenable.merge([clock, reveal]));

  final RankTier tier;
  final HoloStage stage;

  /// Seconds.
  final ValueNotifier<double> clock;

  /// 0 (nothing yet) to 1 (fully there).
  final Animation<double> reveal;

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value;
    final r = reveal.value.clamp(0.0, 1.0);
    final color = tier.color;
    final panel = stage.panel;
    final p = stage.projector;

    _aura(canvas, size, t, r);

    // The beam, from the projector up to the panel.
    final beam = Path()
      ..moveTo(p.dx - 18, p.dy)
      ..lineTo(p.dx + 18, p.dy)
      ..lineTo(panel.right - panel.width * 0.08, panel.bottom)
      ..lineTo(panel.left + panel.width * 0.08, panel.bottom)
      ..close();
    canvas.drawPath(
      beam,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [_a(color, 0.38 * r), _a(color, 0.04 * r)],
        ).createShader(beam.getBounds()),
    );
    // Light streaks rising in the beam.
    for (var i = 0; i < 6; i++) {
      final k = (t * 0.6 + _rand(i, 1)) % 1;
      final x =
          p.dx +
          (_rand(i, 2) - 0.5) * 30 * (1 - k) +
          (_rand(i, 2) - 0.5) * (panel.width * 0.8) * k;
      final y = p.dy - (p.dy - panel.bottom) * k;
      canvas.drawLine(
        Offset(x, y),
        Offset(x, y - 14),
        Paint()
          ..strokeWidth = 1.4
          ..color = _a(Colors.white, 0.5 * r * (1 - k)),
      );
    }

    // The projector: a glowing disc.
    final pulse = 0.85 + 0.15 * math.sin(t * 3);
    final disc = Rect.fromCenter(center: p, width: 120, height: 26);
    canvas.drawOval(
      disc.inflate(16),
      Paint()
        ..shader = RadialGradient(
          colors: [_a(color, 0.45 * pulse), _a(color, 0)],
        ).createShader(disc.inflate(16)),
    );
    canvas.drawOval(
      disc,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.9 * pulse),
            _a(color, 0.8),
            _a(color, 0.1),
          ],
          stops: const [0, 0.35, 1],
        ).createShader(disc),
    );

    if (r <= 0) return;
    final rr = RRect.fromRectAndRadius(panel, const Radius.circular(24));
    // A flicker now and then, like a projection catching.
    final flicker = (t % 4.3) < 0.08 ? 0.75 : 1.0;

    // The glassy body.
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _a(color, 0.16 * r * flicker),
            _a(const Color(0xFF05030C), 0.55 * r),
            _a(color, 0.10 * r * flicker),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(panel),
    );
    canvas.save();
    canvas.clipRRect(rr);
    // Scanlines, drifting down.
    final scan = Paint()..color = _a(color, 0.07 * r);
    final shift = (t * 14) % 4;
    for (var y = panel.top + shift; y < panel.bottom; y += 4) {
      canvas.drawLine(Offset(panel.left, y), Offset(panel.right, y), scan);
    }
    // A scan bar sweeping down.
    final sweep = panel.top + (panel.height + 120) * ((t / 3.2) % 1) - 60;
    final bar = Rect.fromLTWH(panel.left, sweep - 40, panel.width, 80);
    canvas.drawRect(
      bar,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _a(color, 0),
            _a(color, 0.16 * r),
            _a(Colors.white, 0.10 * r),
            _a(color, 0),
          ],
          stops: const [0, 0.48, 0.5, 1],
        ).createShader(bar),
    );
    canvas.restore();

    // Edges: a soft glow, then the bright line.
    for (final (width, alpha) in const [
      (14.0, 0.06),
      (7.0, 0.14),
      (1.6, 0.9),
    ]) {
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = _a(color, alpha * r * flicker),
      );
    }
    // HUD corner brackets.
    final bracket = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = _a(Color.lerp(color, Colors.white, 0.45)!, r);
    const len = 22.0;
    const inset = 8.0;
    for (final (cx, cy, dx, dy) in [
      (panel.left + inset, panel.top + inset, 1.0, 1.0),
      (panel.right - inset, panel.top + inset, -1.0, 1.0),
      (panel.left + inset, panel.bottom - inset, 1.0, -1.0),
      (panel.right - inset, panel.bottom - inset, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(cx, cy + dy * len)
          ..lineTo(cx, cy)
          ..lineTo(cx + dx * len, cy),
        bracket,
      );
    }
  }

  /// The tier's aura, behind the panel.
  void _aura(Canvas canvas, Size size, double t, double r) {
    final panel = stage.panel;
    final color = tier.color;
    switch (tier) {
      case RankTier.bronze:
        // A little warm haze, and dust drifting up.
        _glow(canvas, panel, color, 0.14 * r, 40);
        for (var i = 0; i < 36; i++) {
          final period = 8 + _rand(i, 3) * 6;
          final k = ((t / period) + _rand(i, 4)) % 1;
          final x =
              panel.left -
              30 +
              (panel.width + 60) * _rand(i, 5) +
              math.sin(t * 0.7 + i) * 10;
          final y = panel.bottom + 20 - (panel.height + 60) * k;
          final twinkle = 0.5 + 0.5 * math.sin(t * 3 + i * 1.7);
          canvas.drawCircle(
            Offset(x, y),
            1.2 + 2 * _rand(i, 6),
            Paint()
              ..color = _a(
                Color.lerp(color, Colors.white, 0.3)!,
                (0.35 + 0.55 * twinkle) * r * math.sin(k * math.pi),
              ),
          );
        }
      case RankTier.silver:
        // Liquid silver pooling under the panel, rippling out from the
        // projector, droplets rising.
        _glow(canvas, panel, color, 0.16 * r, 50);
        for (var i = 0; i < 3; i++) {
          final k = ((t / 1.8) + i / 3) % 1;
          final ring = Rect.fromCenter(
            center: stage.projector,
            width: 120 + 320 * k,
            height: 26 + 60 * k,
          );
          canvas.drawOval(
            ring,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = _a(color, 0.5 * (1 - k) * r),
          );
        }
        for (var w = 0; w < 4; w++) {
          final base = panel.bottom - 8 - w * 9.0;
          final wave = Path()..moveTo(panel.left - 24, base);
          for (var x = panel.left - 24; x <= panel.right + 24; x += 8) {
            final y =
                base +
                math.sin(x / (26 + w * 6) + t * (1.6 + w * 0.4)) *
                    (4 + w * 1.5);
            wave.lineTo(x, y);
          }
          canvas.drawPath(
            wave,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.2 - w * 0.35
              ..color = _a(
                Color.lerp(color, Colors.white, 0.4)!,
                (0.55 - w * 0.1) * r,
              ),
          );
        }
        for (var i = 0; i < 10; i++) {
          final k = ((t / (4 + _rand(i, 7) * 3)) + _rand(i, 8)) % 1;
          final x =
              panel.left + panel.width * _rand(i, 9) + math.sin(t * 2 + i) * 6;
          final y = panel.bottom - 10 - panel.height * 0.9 * k;
          final drop = Offset(x, y);
          canvas.drawCircle(
            drop,
            2.4,
            Paint()..color = _a(color, 0.55 * r * (1 - k)),
          );
          canvas.drawCircle(
            drop.translate(-0.8, -0.8),
            0.9,
            Paint()..color = _a(Colors.white, 0.8 * r * (1 - k)),
          );
        }
      case RankTier.gold:
        // Rays turning slowly behind, flames licking up the sides.
        final c = panel.center;
        for (var i = 0; i < 16; i++) {
          final a = t * 0.15 + i * math.pi / 8;
          final reach = panel.longestSide * 0.9;
          final ray = Path()
            ..moveTo(c.dx, c.dy)
            ..lineTo(
              c.dx + math.cos(a - 0.07) * reach,
              c.dy + math.sin(a - 0.07) * reach,
            )
            ..lineTo(
              c.dx + math.cos(a + 0.07) * reach,
              c.dy + math.sin(a + 0.07) * reach,
            )
            ..close();
          canvas.drawPath(
            ray,
            Paint()
              ..shader = RadialGradient(
                colors: [_a(color, 0.22 * r), _a(color, 0)],
              ).createShader(Rect.fromCircle(center: c, radius: reach)),
          );
        }
        _glow(canvas, panel, color, 0.28 * r, 60);
        _flames(canvas, panel, t, r, color, const Color(0xFFFF8A1A));
      case RankTier.diamond:
        // Refracted light crossing behind, shards drifting round.
        _glow(canvas, panel, color, 0.22 * r, 56);
        for (var i = 0; i < 5; i++) {
          final x =
              panel.left - 60 + (panel.width + 120) * ((t * 0.05 + i / 5) % 1);
          final band = Path()
            ..moveTo(x, panel.top - 60)
            ..lineTo(x + 30, panel.top - 60)
            ..lineTo(x - 90, panel.bottom + 60)
            ..lineTo(x - 120, panel.bottom + 60)
            ..close();
          final hue = HSVColor.fromAHSV(
            1,
            (190 + i * 40) % 360,
            0.35,
            1,
          ).toColor();
          canvas.drawPath(band, Paint()..color = _a(hue, 0.07 * r));
        }
        _shards(canvas, panel, t, r, color, front: false);
      case RankTier.legend:
        // A red storm-glow, breathing, and bolts striking down out of the
        // dark at the hologram.
        final breath = 0.75 + 0.25 * math.sin(t * 2.4);
        _glow(canvas, panel, color, 0.4 * r * breath, 90);
        final frame = (t * 12).floor();
        for (var b = 0; b < 3; b++) {
          final seed = frame * 41 + b * 13 + 900;
          if (_rand(seed, 1) < 0.5) continue;
          final from = Offset(size.width * _rand(seed, 2), -10);
          final to = Offset(
            panel.left + panel.width * _rand(seed, 3),
            panel.top + panel.height * 0.15 * _rand(seed, 4),
          );
          final path = Path()..moveTo(from.dx, from.dy);
          const steps = 9;
          for (var s = 1; s <= steps; s++) {
            final q = Offset.lerp(from, to, s / steps)!;
            final j = s == steps ? 0.0 : (_rand(seed + s, 5) - 0.5) * 46;
            path.lineTo(q.dx + j, q.dy);
          }
          for (final (width, alpha, c) in [
            (12.0, 0.12, color),
            (4.0, 0.45, color),
            (1.4, 0.9, Colors.white),
          ]) {
            canvas.drawPath(
              path,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = width
                ..strokeJoin = StrokeJoin.round
                ..color = _a(c, alpha * r),
            );
          }
        }
        // A big strike: one bold bolt out of the sky into the hologram,
        // branching, with the thunder (see legendStrikeAt).
        if (legendStrike(t) case (:final k, :final glow)) {
          final from = Offset(size.width * (0.2 + 0.6 * _rand(k, 80)), -20);
          final to = Offset(
            panel.left + panel.width * (0.3 + 0.4 * _rand(k, 81)),
            panel.top + 4,
          );
          final main = Path()..moveTo(from.dx, from.dy);
          final points = <Offset>[];
          const steps = 12;
          for (var s = 1; s <= steps; s++) {
            final q = Offset.lerp(from, to, s / steps)!;
            final j = s == steps ? 0.0 : (_rand(k * 50 + s, 82) - 0.5) * 70;
            points.add(Offset(q.dx + j, q.dy));
            main.lineTo(q.dx + j, q.dy);
          }
          final bolt = [main];
          for (var b = 0; b < 3; b++) {
            final start = points[2 + (_rand(k * 9 + b, 83) * 6).floor()];
            final branch = Path()..moveTo(start.dx, start.dy);
            var p = start;
            for (var s = 0; s < 4; s++) {
              p += Offset((_rand(k * 31 + b * 7 + s, 84) - 0.5) * 60, 24);
              branch.lineTo(p.dx, p.dy);
            }
            bolt.add(branch);
          }
          for (final (path, main) in [
            for (final (i, p) in bolt.indexed) (p, i == 0),
          ]) {
            for (final (width, alpha, c) in [
              (main ? 26.0 : 12.0, 0.22, color),
              (main ? 9.0 : 4.0, 0.7, color),
              (main ? 3.2 : 1.6, 1.0, Colors.white),
            ]) {
              canvas.drawPath(
                path,
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = width
                  ..strokeJoin = StrokeJoin.round
                  ..strokeCap = StrokeCap.round
                  ..color = _a(c, alpha * glow * r),
              );
            }
          }
          // Where it hits the hologram, a burst.
          canvas.drawCircle(
            to,
            40 * glow,
            Paint()
              ..shader = RadialGradient(
                colors: [_a(Colors.white, 0.9 * glow * r), _a(color, 0)],
              ).createShader(Rect.fromCircle(center: to, radius: 40)),
          );
        }
        // Sparks spitting off the projector.
        for (var i = 0; i < 10; i++) {
          final k = ((t * 1.6) + _rand(i, 7)) % 1;
          final a = -math.pi * (0.1 + 0.8 * _rand(i, 8));
          final d = 70 * k;
          canvas.drawCircle(
            stage.projector + Offset(math.cos(a) * d, math.sin(a) * d * 0.6),
            1.8,
            Paint()..color = _a(Colors.white, (1 - k) * r),
          );
        }
    }
  }

  @override
  bool shouldRepaint(covariant HoloBackPainter old) =>
      old.tier != tier || old.stage.panel != stage.panel;
}

/// In front of the hologram: what plays over its edges (sparkles, shards,
/// lightning), kept off the middle so the numbers read.
class HoloFrontPainter extends CustomPainter {
  HoloFrontPainter({
    required this.tier,
    required this.stage,
    required this.clock,
    required this.reveal,
  }) : super(repaint: Listenable.merge([clock, reveal]));

  final RankTier tier;
  final HoloStage stage;
  final ValueNotifier<double> clock;
  final Animation<double> reveal;

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value;
    final r = reveal.value.clamp(0.0, 1.0);
    if (r <= 0) return;
    final panel = stage.panel;
    final color = tier.color;
    switch (tier) {
      case RankTier.bronze:
        break;
      case RankTier.silver:
        // Light running round the rim, like on liquid metal.
        _rimLight(
          canvas,
          panel,
          t * 0.18,
          Color.lerp(color, Colors.white, 0.6)!,
          r,
        );
      case RankTier.gold:
        _sparkles(canvas, panel, t, r, const Color(0xFFFFE6A0), 14);
      case RankTier.diamond:
        _shards(canvas, panel, t, r, color, front: true);
        _rimLight(canvas, panel, t * 0.12, Colors.white, r);
        _rimLight(canvas, panel, t * 0.12 + 0.5, color, r);
      case RankTier.legend:
        _lightning(canvas, size, panel, t, r, color);
    }
  }

  /// Electricity everywhere: arcs crawling the frame, arcs jumping off it,
  /// sparks, and now and then a flash.
  void _lightning(
    Canvas canvas,
    Size size,
    Rect panel,
    double t,
    double r,
    Color color,
  ) {
    final frame = (t * 14).floor();
    final perimeter = 2 * (panel.width + panel.height);
    Offset along(double d) {
      var x = d % perimeter;
      if (x < panel.width) return Offset(panel.left + x, panel.top);
      x -= panel.width;
      if (x < panel.height) return Offset(panel.right, panel.top + x);
      x -= panel.height;
      if (x < panel.width) return Offset(panel.right - x, panel.bottom);
      x -= panel.width;
      return Offset(panel.left, panel.bottom - x);
    }

    // Crawling the frame.
    for (var b = 0; b < 10; b++) {
      final seed = frame * 31 + b * 7;
      if (_rand(seed, 1) < 0.2) continue;
      final start = _rand(seed, 2) * perimeter;
      final length = 60 + _rand(seed, 3) * 160;
      final path = Path();
      const steps = 10;
      for (var s = 0; s <= steps; s++) {
        final p = along(start + length * s / steps);
        final j = (s == 0 || s == steps)
            ? 0.0
            : (_rand(seed + s, 4) - 0.5) * 16;
        final q = p + Offset(j, -j * 0.6);
        s == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
      }
      _bolt(canvas, path, color, r);
    }

    // Jumping off it into the air.
    for (var b = 0; b < 5; b++) {
      final seed = frame * 17 + b * 3 + 500;
      if (_rand(seed, 1) < 0.35) continue;
      final from = along(_rand(seed, 2) * perimeter);
      final out = (from - panel.center);
      final dir = out / out.distance;
      final to =
          from +
          dir * (50 + _rand(seed, 3) * 90) +
          Offset((_rand(seed, 4) - 0.5) * 80, (_rand(seed, 5) - 0.5) * 80);
      final path = Path()..moveTo(from.dx, from.dy);
      const steps = 6;
      for (var s = 1; s <= steps; s++) {
        final p = Offset.lerp(from, to, s / steps)!;
        final j = s == steps ? 0.0 : (_rand(seed + s, 6) - 0.5) * 22;
        path.lineTo(p.dx + j, p.dy - j * 0.5);
      }
      _bolt(canvas, path, color, r);
      canvas.drawCircle(to, 3, Paint()..color = _a(Colors.white, 0.9 * r));
    }

    // A big strike's flash: the whole sky lit, white into red.
    if (legendStrike(t) case (k: _, :final glow)) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = _a(Color.lerp(color, Colors.white, 0.6)!, 0.45 * glow * r),
      );
    }

    // A flash now and then.
    if (_rand(frame ~/ 3, 9) > 0.82) {
      canvas.drawRect(Offset.zero & size, Paint()..color = _a(color, 0.07 * r));
    }
  }

  void _bolt(Canvas canvas, Path path, Color color, double r) {
    for (final (width, alpha, c) in [
      (9.0, 0.16, color),
      (3.6, 0.55, color),
      (1.3, 1.0, Colors.white),
    ]) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..color = _a(c, alpha * r),
      );
    }
  }

  @override
  bool shouldRepaint(covariant HoloFrontPainter old) =>
      old.tier != tier || old.stage.panel != stage.panel;
}

/// A soft halo around [panel], [spread] wide.
void _glow(
  Canvas canvas,
  Rect panel,
  Color color,
  double alpha,
  double spread,
) {
  final outer = panel.inflate(spread);
  canvas.drawRRect(
    RRect.fromRectAndRadius(outer, Radius.circular(24 + spread)),
    Paint()
      ..shader = RadialGradient(
        radius: 0.75,
        colors: [_a(color, alpha), _a(color, 0)],
      ).createShader(outer),
  );
}

/// Flames licking up the sides and over the top.
void _flames(
  Canvas canvas,
  Rect panel,
  double t,
  double r,
  Color color,
  Color hot,
) {
  const count = 22;
  for (var i = 0; i < count; i++) {
    // Round the top and down the sides.
    final u = i / (count - 1);
    final Offset base;
    final double angle;
    if (u < 0.2) {
      base = Offset(panel.left, panel.bottom - panel.height * (u / 0.2));
      angle = -math.pi * 0.75;
    } else if (u > 0.8) {
      base = Offset(panel.right, panel.bottom - panel.height * ((1 - u) / 0.2));
      angle = -math.pi * 0.25;
    } else {
      base = Offset(panel.left + panel.width * ((u - 0.2) / 0.6), panel.top);
      angle = -math.pi / 2;
    }
    final flick = 0.6 + 0.4 * math.sin(t * (5 + _rand(i, 1) * 3) + i * 2.1);
    final height = (16 + 22 * _rand(i, 2)) * flick;
    final width = 9 + 6 * _rand(i, 3);
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(angle + math.pi / 2 + math.sin(t * 2 + i) * 0.15);
    final flame = Path()
      ..moveTo(-width / 2, 0)
      ..quadraticBezierTo(-width * 0.6, -height * 0.55, 0, -height)
      ..quadraticBezierTo(width * 0.6, -height * 0.55, width / 2, 0)
      ..close();
    canvas.drawPath(
      flame,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [_a(hot, 0.55 * r), _a(color, 0.4 * r), _a(color, 0)],
        ).createShader(Rect.fromLTWH(-width, -height, width * 2, height)),
    );
    canvas.restore();
  }
}

/// Four-point sparkles twinkling round [panel].
void _sparkles(
  Canvas canvas,
  Rect panel,
  double t,
  double r,
  Color color,
  int count,
) {
  for (var i = 0; i < count; i++) {
    final phase = (t * 0.7 + _rand(i, 1)) % 1.6;
    if (phase > 1) continue;
    final s = math.sin(phase * math.pi) * (4 + 5 * _rand(i, 2));
    final edge = _rand(i, 3);
    final p = edge < 0.5
        ? Offset(
            panel.left + panel.width * _rand(i, 4),
            edge < 0.25 ? panel.top : panel.bottom,
          )
        : Offset(
            edge < 0.75 ? panel.left : panel.right,
            panel.top + panel.height * _rand(i, 5),
          );
    final q = p + Offset((_rand(i, 6) - 0.5) * 24, (_rand(i, 7) - 0.5) * 24);
    canvas.drawPath(
      Path()
        ..moveTo(q.dx, q.dy - s)
        ..quadraticBezierTo(q.dx, q.dy, q.dx + s, q.dy)
        ..quadraticBezierTo(q.dx, q.dy, q.dx, q.dy + s)
        ..quadraticBezierTo(q.dx, q.dy, q.dx - s, q.dy)
        ..quadraticBezierTo(q.dx, q.dy, q.dx, q.dy - s),
      Paint()..color = _a(color, r),
    );
  }
}

/// Cut diamonds drifting round [panel], turning, catching the light;
/// half behind it, half in front.
void _shards(
  Canvas canvas,
  Rect panel,
  double t,
  double r,
  Color color, {
  required bool front,
}) {
  const count = 16;
  for (var i = 0; i < count; i++) {
    if ((i.isEven) != front) continue;
    final orbit = (t * (0.03 + _rand(i, 1) * 0.03) + _rand(i, 2)) % 1;
    final a = orbit * 2 * math.pi;
    final rx = panel.width / 2 + 26 + 30 * _rand(i, 3);
    final ry = panel.height / 2 + 20 + 26 * _rand(i, 4);
    final c = panel.center + Offset(math.cos(a) * rx, math.sin(a) * ry);
    final s = 6 + 10 * _rand(i, 5);
    final spin = t * (0.6 + _rand(i, 6)) + i;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(math.sin(spin) * 0.5);
    canvas.scale(0.6 + 0.4 * math.cos(spin).abs(), 1);
    final top = Path()
      ..moveTo(-s * 0.6, -s * 0.15)
      ..lineTo(-s * 0.3, -s * 0.55)
      ..lineTo(s * 0.3, -s * 0.55)
      ..lineTo(s * 0.6, -s * 0.15)
      ..close();
    final body = Path()
      ..moveTo(-s * 0.6, -s * 0.15)
      ..lineTo(s * 0.6, -s * 0.15)
      ..lineTo(0, s * 0.75)
      ..close();
    canvas.drawPath(body, Paint()..color = _a(color, 0.55 * r));
    canvas.drawPath(
      top,
      Paint()..color = _a(Color.lerp(color, Colors.white, 0.55)!, 0.75 * r),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, s * 0.75)
        ..lineTo(-s * 0.15, -s * 0.15)
        ..lineTo(s * 0.15, -s * 0.15)
        ..close(),
      Paint()..color = _a(Colors.white, 0.3 * r),
    );
    // A glint.
    if ((spin % 3.0) < 0.25) {
      final g = 3 + 5 * math.sin((spin % 3.0) / 0.25 * math.pi);
      final glint = Paint()
        ..strokeWidth = 1.2
        ..color = _a(Colors.white, r);
      canvas.drawLine(Offset(-g, -s * 0.4), Offset(g, -s * 0.4), glint);
      canvas.drawLine(Offset(0, -s * 0.4 - g), Offset(0, -s * 0.4 + g), glint);
    }
    canvas.restore();
  }
}

/// A bright streak running round [panel]'s rim ([phase] 0-1 how far).
void _rimLight(Canvas canvas, Rect panel, double phase, Color color, double r) {
  final rr = RRect.fromRectAndRadius(panel, const Radius.circular(24));
  final metric = (Path()..addRRect(rr)).computeMetrics().first;
  final at = metric.length * (phase % 1);
  final piece = metric.extractPath(at, at + metric.length * 0.12);
  for (final (width, alpha) in const [(7.0, 0.2), (2.4, 0.95)]) {
    canvas.drawPath(
      piece,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..color = _a(color, alpha * r),
    );
  }
}
