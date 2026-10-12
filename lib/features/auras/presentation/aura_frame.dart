import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:flutter/scheduler.dart';

import '../../../core/theme/utopia_themes.dart';
import '../../../core/widgets/dojo_dragon.dart';
import '../../../core/widgets/fire_dragon.dart';
import '../../../core/widgets/utopia_world.dart' show worldSeconds;

/// Draws an aura around [child], an avatar of [radius]. The aura spills
/// outside the avatar's box (flames, lightning, petals), behind and in
/// front of it, and animates for as long as it's on screen.
class AuraFrame extends StatefulWidget {
  const AuraFrame({
    super.key,
    required this.aura,
    required this.radius,
    required this.child,
  });

  final String aura;
  final double radius;
  final Widget child;

  @override
  State<AuraFrame> createState() => _AuraFrameState();
}

class _AuraFrameState extends State<AuraFrame>
    with SingleTickerProviderStateMixin {
  final _t = ValueNotifier<double>(0);
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    // Started here, not lazily: a lazy ticker would never start.
    _ticker = createTicker((e) {
      _t.value = e.inMicroseconds / 1e6;
      _callDragon();
    })..start();
  }

  /// A big Dragon Coil frame in the Dojo world (a profile picture) calls
  /// the world's dragon down to circle it.
  void _callDragon() {
    final wants =
        widget.aura == 'dragon' &&
        widget.radius >= 40 &&
        UtopiaThemes.active.world.biome == WorldBiome.dojo;
    if (!wants) {
      DojoDragon.release(this, worldSeconds);
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    DojoDragon.claim(
      this,
      box.localToGlobal(box.size.center(Offset.zero)),
      widget.radius,
      worldSeconds,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    if (still && _ticker.isActive) _ticker.stop();
    if (!still && !_ticker.isActive) _ticker.start();
  }

  @override
  void dispose() {
    DojoDragon.release(this, worldSeconds);
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var child = widget.child;
    // Zombie Bite takes its chunk out of the picture too, border and all.
    if (widget.aura == 'zombie') {
      child = ClipPath(clipper: const _Bitten(), child: child);
    }
    return RepaintBoundary(
      child: CustomPaint(
        painter: AuraPainter(widget.aura, _t, front: false),
        foregroundPainter: AuraPainter(widget.aura, _t, front: true),
        child: SizedBox.square(dimension: widget.radius * 2, child: child),
      ),
    );
  }
}

/// Everything but the Zombie Bite's bite, for the picture inside it.
class _Bitten extends CustomClipper<Path> {
  const _Bitten();

  @override
  Path getClip(Size size) {
    final r = size.width / 2;
    final fit = (Matrix4.translationValues(
      r,
      r,
      0,
    )..scaleByDouble(r, r, 1, 1)).storage;
    return AuraPainter._biteShapes.unbitten.transform(fit);
  }

  @override
  bool shouldReclip(covariant _Bitten oldClipper) => false;
}

double _rand(int i, int salt) {
  final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

Offset _dir(double a) => Offset(math.cos(a), math.sin(a));

/// One layer of an aura: [front] draws over the avatar, otherwise behind.
class AuraPainter extends CustomPainter {
  AuraPainter(this.aura, this.clock, {required this.front})
    : super(repaint: clock);

  final String aura;
  final ValueNotifier<double> clock;
  final bool front;

  /// Small avatars (chat rows, lists) skip the blurs: they cost the most
  /// to draw every frame and barely show at that size.
  bool _lite = false;

  MaskFilter? _blur(double sigma) =>
      _lite ? null : MaskFilter.blur(BlurStyle.normal, sigma);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final t = clock.value;
    _lite = r < 20;
    switch (aura) {
      case 'dragon':
        _dragon(canvas, c, r, t);
      case 'flame':
        _flame(canvas, c, r, t);
      case 'storm' ||
          'storm_white' ||
          'storm_blue' ||
          'storm_green' ||
          'storm_gold' ||
          'storm_pink':
        _storm(canvas, c, r, t, _stormColors[aura]!);
      case 'supernova':
        _supernova(canvas, c, r, t);
      case 'blackhole':
        _blackhole(canvas, c, r, t);
      case 'frostfire':
        _frostfire(canvas, c, r, t);
      case 'sunburst':
        _sunburst(canvas, c, r, t);
      case 'prism':
        _prism(canvas, c, r, t);
      case 'cosmic':
        _cosmic(canvas, c, r, t);
      case 'bubbles':
        _bubbles(canvas, c, r, t);
      case 'sakura':
        _sakura(canvas, c, r, t);
      case 'frost':
        _frost(canvas, c, r, t);
      case 'fury':
        _fury(canvas, c, r, t);
      case 'phoenix':
        _phoenix(canvas, c, r, t);
      case 'galaxy':
        _galaxy(canvas, c, r, t);
      case 'shadow':
        _shadow(canvas, c, r, t);
      case 'neon':
        _neon(canvas, c, r, t);
      case 'tidal':
        _tidal(canvas, c, r, t);
      case 'halo':
        _halo(canvas, c, r, t);
      case 'zombie':
        _zombie(canvas, c, r, t);
      case 'demon':
        _demon(canvas, c, r, t);
      case 'hearts':
        _hearts(canvas, c, r, t);
      case 'fireflies':
        _fireflies(canvas, c, r, t);
      case 'starlight':
        _starlight(canvas, c, r, t);
      case 'autumn':
        _autumn(canvas, c, r, t);
    }
  }

  void _glowRing(
    Canvas canvas,
    Offset c,
    double r,
    Color color, {
    double width = 0.18,
    double blur = 0.18,
    double scale = 1.04,
  }) {
    canvas.drawCircle(
      c,
      r * scale,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * width
        ..color = color
        ..maskFilter = _blur(r * blur),
    );
  }

  // ── mythic ──────────────────────────────────────────────────────────────

  /// A crimson dragon wound round the picture: its coils pass behind the
  /// picture and over its lower rim, wings beating behind its head. Every
  /// few seconds it rears back and breathes a ring of fire all the way
  /// round. Heat and embers come off it. Only the lower coil and the
  /// firelight touch the picture, never the face.
  /// The fire dragon coiled round the picture, all of it behind (the
  /// picture is never covered).
  void _dragon(Canvas canvas, Offset c, double r, double t) {
    if (front) return;
    paintFireDragonCoiled(
      canvas,
      c,
      r,
      t,
      FireDragonColors.crimson,
      lite: _lite,
    );
  }

  // ── legendary ───────────────────────────────────────────────────────────

  /// A ring of fire: flames all round the picture with soft, wavy edges
  /// like real fire, licking outward and leaning up (heat rises, so they
  /// stand tallest over the top), flickering where they burn rather than
  /// spinning. Now and then a lick breaks off and floats away, and embers
  /// drift up. Warm, never blinding: red tips fade out softly.
  void _flame(Canvas canvas, Offset c, double r, double t) {
    final samples = _lite ? 96 : 220;
    // How tall the flame stands at angle [a]: tongues rise and fall where
    // waves running both ways round the ring meet, so they flicker in
    // place; tallest over the top, low under the bottom.
    double tongue(double a, double seed) {
      final raw =
          0.5 * math.sin(7 * a + t * 2.1 + seed) +
          0.27 * math.sin(11 * a - t * 3.3 + 1.7 + seed) +
          0.13 * math.sin(17 * a + t * 4.7 + 0.5 + seed * 2) +
          0.1 * math.sin(26 * a - t * 6.1 + seed * 3);
      // Raised to a power, the crests come to points and the troughs
      // flatten: tongues of flame rather than puffs.
      final peak = math.pow((raw + 1) / 2, 3.2).toDouble();
      final top = 0.55 - 0.45 * math.sin(a);
      final flicker = 0.85 + 0.15 * math.sin(t * 9 + a * 5 + seed);
      return (0.2 + 2.0 * peak) * (0.35 + 0.65 * top) * flicker;
    }

    // One layer of flame: from just inside the picture's edge out to a
    // wavy edge [height] (times r) tall at most, leaning up.
    Path layer(double height, double seed) {
      final path = Path();
      for (var i = 0; i <= samples; i++) {
        final a = i / samples * 2 * math.pi;
        final h = r * height * tongue(a, seed);
        final p = c + _dir(a) * (r + h) + Offset(0, -h * 0.35);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path
        ..close()
        ..addOval(Rect.fromCircle(center: c, radius: r * 0.96))
        ..fillType = PathFillType.evenOdd;
      return path;
    }

    // Colour by distance from the middle: gold at the picture's edge,
    // through orange to red tips that fade away.
    Paint fill(List<Color> colors, List<double> stops) => Paint()
      ..shader = RadialGradient(
        colors: colors,
        stops: stops,
      ).createShader(Rect.fromCircle(center: c, radius: r * 1.5));

    if (!front) {
      // A low, warm heat haze.
      canvas.drawCircle(
        c,
        r * 1.12,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.36
          ..color = const Color(0xFFFF6A1A).withValues(alpha: 0.16)
          ..maskFilter = _blur(r * 0.22),
      );
      // The outer flames, deep orange to red.
      canvas.drawPath(
        layer(0.42, 0),
        fill(
          const [
            Color(0xFFFFB03A),
            Color(0xFFFF6A1A),
            Color(0xFFE0361A),
            Color(0x00B8200E),
          ],
          const [0.64, 0.72, 0.84, 0.98],
        ),
      );
      if (_lite) return;
      // Licks of flame breaking off the top and floating away.
      for (var i = 0; i < 5; i++) {
        final life = (t * (0.45 + 0.2 * _rand(i, 30)) + _rand(i, 31)) % 1;
        final a = -math.pi / 2 + (_rand(i, 32) - 0.5) * 2.2;
        final start = c + _dir(a) * r * 1.28;
        final p =
            start + Offset(0, -r * 0.45 * life) + _dir(a) * r * 0.1 * life;
        final s = r * 0.09 * (1 - life * 0.7);
        final wisp = Path()
          ..moveTo(p.dx, p.dy - s * 1.6)
          ..quadraticBezierTo(p.dx + s, p.dy, p.dx, p.dy + s * 0.7)
          ..quadraticBezierTo(p.dx - s, p.dy, p.dx, p.dy - s * 1.6)
          ..close();
        canvas.drawPath(
          wisp,
          Paint()
            ..color = Color.lerp(
              const Color(0xFFFFA23A),
              const Color(0xFFE0361A),
              life,
            )!.withValues(alpha: 0.8 * math.sin(life * math.pi)),
        );
      }
      return;
    }

    // The bright inner flames over the rim: orange, then a gold core.
    canvas.drawPath(
      layer(0.26, 2.3),
      fill(
        const [
          Color(0xFFFFD45E),
          Color(0xFFFFA23A),
          Color(0xFFFF6A1A),
          Color(0x00FF5A1A),
        ],
        const [0.64, 0.7, 0.78, 0.88],
      ),
    );
    canvas.drawPath(
      layer(0.12, 4.1),
      fill(
        const [Color(0xFFFFEFA8), Color(0xFFFFD45E), Color(0x00FFB03A)],
        const [0.64, 0.68, 0.75],
      ),
    );

    if (_lite) return;
    // Embers drifting up off the flames.
    for (var i = 0; i < 12; i++) {
      final life = (t * (0.35 + _rand(i, 1) * 0.3) + _rand(i, 2)) % 1;
      final a = _rand(i, 3) * 2 * math.pi;
      final pos =
          c +
          _dir(a) * r * (1.15 + 0.2 * life) +
          Offset(math.sin(t * 2 + i) * r * 0.03, -r * 0.5 * life);
      canvas.drawCircle(
        pos,
        r * 0.022 * (1 - life) + 0.5,
        Paint()
          ..color = Color.lerp(
            const Color(0xFFFFE08A),
            const Color(0xFFE0361A),
            life,
          )!.withValues(alpha: (1 - life) * 0.85),
      );
    }
  }

  /// Flame tongues standing out from a ring of radius [r], leaning back
  /// against the direction of the spin.
  void _fireTongues(
    Canvas canvas,
    Offset c,
    double r,
    double t,
    double spin, {
    required int count,
    required double size,
    required int salt,
    List<Color> palette = const [
      Color(0xEEFFF2B0),
      Color(0xDDFFB43A),
      Color(0x99FF5A1A),
      Color(0x00E0301A),
    ],
    bool Function(double angle)? where,
  }) {
    final paint = Paint()..blendMode = BlendMode.plus;
    for (var i = 0; i < count; i++) {
      final a = spin + i * 2 * math.pi / count + (_rand(i, salt) - 0.5) * 0.25;
      if (where != null && !where(a)) continue;
      final flicker =
          0.5 +
          0.5 *
              math.sin(t * (7 + _rand(i, salt + 4) * 4) + i * 1.9) *
              math.sin(t * 4.3 + i * 0.7 + salt);
      // Uneven, like real fire: some flames tall, some small, and a slow
      // flare rolling round the ring so the big ones gather in places.
      final tall = 0.35 + 1.0 * _rand(i, salt + 9);
      final flare = 0.7 + 0.45 * math.sin(a * 3 - t * 1.7 + salt);
      final h = r * (0.14 + 0.3 * flicker) * size * tall * flare * 1.35;
      final w = r * 0.2 * size * (0.7 + 0.6 * _rand(i, salt + 11));
      final n = _dir(a);
      final tg = _dir(a + math.pi / 2);
      // Trailing: the tip bends back against the turn, and sways.
      final sway = math.sin(t * 6 + i * 2.3) * 0.25;
      final leanRaw = n - tg * (0.4 + 0.4 * _rand(i, salt + 13) - sway);
      final lean = leanRaw / leanRaw.distance;
      final base = c + n * r * 1.0;
      final left = base - tg * (w / 2);
      final right = base + tg * (w / 2);
      final tip = base + lean * h;
      final path = Path()
        ..moveTo(left.dx, left.dy)
        ..cubicTo(
          (left + n * h * 0.45).dx,
          (left + n * h * 0.45).dy,
          (tip - lean * h * 0.3 - tg * w * 0.15).dx,
          (tip - lean * h * 0.3 - tg * w * 0.15).dy,
          tip.dx,
          tip.dy,
        )
        ..cubicTo(
          (tip - lean * h * 0.25 + tg * w * 0.55).dx,
          (tip - lean * h * 0.25 + tg * w * 0.55).dy,
          (right + n * h * 0.35).dx,
          (right + n * h * 0.35).dy,
          right.dx,
          right.dy,
        )
        ..close();
      paint.shader = RadialGradient(
        colors: palette,
        stops: const [0.0, 0.3, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: base, radius: h * 1.05 + 1));
      canvas.drawPath(path, paint);
    }
  }

  /// Each storm's colors: (glow, ring, bolt, spark).
  static const _stormColors = {
    'storm': (
      Color(0xFF8B4DFF),
      Color(0xFFD9C2FF),
      Color(0xFFA86BFF),
      Color(0xFFF1E6FF),
    ),
    'storm_white': (
      Color(0xFFDCE8FF),
      Color(0xFFFFFFFF),
      Color(0xFFC9DCFF),
      Color(0xFFFFFFFF),
    ),
    'storm_blue': (
      Color(0xFF2F7BFF),
      Color(0xFFB8D6FF),
      Color(0xFF4DA3FF),
      Color(0xFFE0F0FF),
    ),
    'storm_green': (
      Color(0xFF1FB877),
      Color(0xFFB8FFD9),
      Color(0xFF3DFF9A),
      Color(0xFFE6FFF2),
    ),
    'storm_gold': (
      Color(0xFFFFA020),
      Color(0xFFFFE9A0),
      Color(0xFFFFC94D),
      Color(0xFFFFF6D6),
    ),
    'storm_pink': (
      Color(0xFFFF3D9A),
      Color(0xFFFFC2E0),
      Color(0xFFFF6FB8),
      Color(0xFFFFE6F2),
    ),
  };

  void _storm(
    Canvas canvas,
    Offset c,
    double r,
    double t,
    (Color, Color, Color, Color) colors,
  ) {
    final (glowColor, ringColor, boltColor, sparkColor) = colors;
    final pulse = 0.5 + 0.5 * math.sin(t * 4);
    if (!front) {
      _glowRing(
        canvas,
        c,
        r,
        glowColor.withValues(alpha: 0.55 + 0.35 * pulse),
        width: 0.32,
        blur: 0.25,
        scale: 1.08,
      );
      return;
    }
    canvas.drawCircle(
      c,
      r * 1.03,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..color = ringColor.withValues(alpha: 0.6 + 0.3 * pulse),
    );
    // New bolts about ten times a second, each living a few frames.
    final flash = (t * 11).floor();
    for (var b = 0; b < 4; b++) {
      final seed = flash * 7 + b * 31;
      if (_rand(seed, 9) < 0.35) continue;
      final start = _rand(seed, 1) * 2 * math.pi;
      final span = 0.7 + _rand(seed, 2) * 0.9;
      const segments = 9;
      final bolt = Path();
      for (var s = 0; s <= segments; s++) {
        final a = start + span * s / segments;
        final jitter = (s == 0 || s == segments)
            ? 0
            : (_rand(seed + s, 3) - 0.5) * 0.28;
        final p = c + _dir(a) * r * (1.12 + jitter);
        if (s == 0) {
          bolt.moveTo(p.dx, p.dy);
        } else {
          bolt.lineTo(p.dx, p.dy);
        }
      }
      // A fork shooting outward from the middle of the bolt.
      final forkA = start + span * 0.5;
      final forkFrom = c + _dir(forkA) * r * 1.12;
      final fork = Path()
        ..moveTo(forkFrom.dx, forkFrom.dy)
        ..lineTo(
          (c + _dir(forkA + 0.08) * r * 1.3).dx,
          (c + _dir(forkA + 0.08) * r * 1.3).dy,
        )
        ..lineTo(
          (c + _dir(forkA - 0.04) * r * 1.45).dx,
          (c + _dir(forkA - 0.04) * r * 1.45).dy,
        );
      for (final path in [bolt, fork]) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.11
            ..strokeJoin = StrokeJoin.round
            ..color = boltColor.withValues(alpha: 0.7)
            ..maskFilter = _blur(r * 0.06),
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.0, r * 0.03)
            ..strokeJoin = StrokeJoin.round
            ..color = Colors.white,
        );
      }
    }
    // Sparks skittering around the ring.
    for (var i = 0; i < 8; i++) {
      final a = t * (1.5 + _rand(i, 4)) + i * 0.8;
      final on = math.sin(t * 13 + i * 2) > 0.3;
      if (!on) continue;
      canvas.drawCircle(
        c + _dir(a) * r * 1.16,
        r * 0.03 + 0.5,
        Paint()..color = sparkColor,
      );
    }
  }

  // ── rare ────────────────────────────────────────────────────────────────

  void _sunburst(Canvas canvas, Offset c, double r, double t) {
    if (!front) {
      const rays = 16;
      for (var i = 0; i < rays; i++) {
        final a = t * 0.35 + i * 2 * math.pi / rays;
        final w = (i.isEven ? 0.11 : 0.07);
        final len = r * (i.isEven ? 1.55 : 1.38);
        final path = Path()
          ..moveTo(
            (c + _dir(a - w) * r * 0.9).dx,
            (c + _dir(a - w) * r * 0.9).dy,
          )
          ..lineTo((c + _dir(a) * len).dx, (c + _dir(a) * len).dy)
          ..lineTo(
            (c + _dir(a + w) * r * 0.9).dx,
            (c + _dir(a + w) * r * 0.9).dy,
          )
          ..close();
        canvas.drawPath(
          path,
          Paint()
            ..shader = RadialGradient(
              colors: [
                const Color(0xFFFFE29A).withValues(alpha: 0.9),
                const Color(0x00FFC94D),
              ],
            ).createShader(Rect.fromCircle(center: c, radius: len)),
        );
      }
      _glowRing(canvas, c, r, const Color(0xAAFFC94D), width: 0.2);
      return;
    }
    canvas.drawCircle(
      c,
      r * 1.02,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.09
        ..shader = SweepGradient(
          colors: const [
            Color(0xFFFFF0B8),
            Color(0xFFFFC94D),
            Color(0xFFD9962A),
            Color(0xFFFFF0B8),
          ],
          transform: GradientRotation(t * 1.2),
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    for (var i = 0; i < 4; i++) {
      final s = math.max(0.0, math.sin(t * 2.2 + i * 1.6));
      _sparkle(
        canvas,
        c + _dir(i * math.pi / 2 + math.pi / 4) * r * 1.08,
        r * 0.16 * s,
        Colors.white,
      );
    }
  }

  void _prism(Canvas canvas, Offset c, double r, double t) {
    final rect = Rect.fromCircle(center: c, radius: r * 1.06);
    const rainbow = [
      Color(0xFFFF5C6C),
      Color(0xFFFFC93D),
      Color(0xFF2FD98E),
      Color(0xFF4DA3FF),
      Color(0xFFB27BFF),
      Color(0xFFFF5C9C),
      Color(0xFFFF5C6C),
    ];
    if (!front) {
      canvas.drawCircle(
        c,
        r * 1.06,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.3
          ..shader = SweepGradient(
            colors: rainbow,
            transform: GradientRotation(t * 1.4),
          ).createShader(rect)
          ..maskFilter = _blur(r * 0.16),
      );
      return;
    }
    canvas.drawCircle(
      c,
      r * 1.04,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.1
        ..shader = SweepGradient(
          colors: rainbow,
          transform: GradientRotation(t * 1.4),
        ).createShader(rect),
    );
    for (var i = 0; i < 2; i++) {
      final a = -t * 2.1 + i * math.pi;
      canvas.drawCircle(
        c + _dir(a) * r * 1.04,
        r * 0.07,
        Paint()
          ..color = Colors.white
          ..maskFilter = _blur(r * 0.04),
      );
    }
  }

  void _cosmic(Canvas canvas, Offset c, double r, double t) {
    if (!front) {
      canvas.drawCircle(
        c,
        r * 1.12,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.36
          ..shader = SweepGradient(
            colors: const [
              Color(0x995A2BB0),
              Color(0x99FF5C9C),
              Color(0x993F6BFF),
              Color(0x995A2BB0),
            ],
            transform: GradientRotation(-t * 0.5),
          ).createShader(Rect.fromCircle(center: c, radius: r * 1.2))
          ..maskFilter = _blur(r * 0.14),
      );
      for (var i = 0; i < 16; i++) {
        final a = i * 2.39996;
        final d = r * (1.05 + _rand(i, 5) * 0.4);
        final tw = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(t * 3 + i * 1.3));
        canvas.drawCircle(
          c + _dir(a) * d,
          r * 0.022 + 0.4,
          Paint()..color = Colors.white.withValues(alpha: tw),
        );
      }
    }
    // Planets on a tilted orbit: behind the avatar on the far side.
    const tilt = -0.35;
    const planets = [
      (Color(0xFFFF9ECF), 0.13, 0.9),
      (Color(0xFF7FE3FF), 0.09, 1.4),
      (Color(0xFFFFD45E), 0.07, 2.1),
    ];
    for (final (i, (color, size, speed)) in planets.indexed) {
      final a = t * speed + i * 2.1;
      final ox = math.cos(a) * r * 1.38;
      final oy = math.sin(a) * r * 0.42;
      final p =
          c +
          Offset(
            ox * math.cos(tilt) - oy * math.sin(tilt),
            ox * math.sin(tilt) + oy * math.cos(tilt),
          );
      final far = math.sin(a) < 0;
      if (far == front) continue;
      final pr = r * size;
      canvas.drawCircle(
        p,
        pr,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.4),
            colors: [
              Colors.white,
              color,
              Color.lerp(color, Colors.black, 0.4)!,
            ],
          ).createShader(Rect.fromCircle(center: p, radius: pr)),
      );
      if (i == 0) {
        canvas.drawOval(
          Rect.fromCenter(center: p, width: pr * 3.4, height: pr * 0.9),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = pr * 0.25
            ..color = const Color(0xCCFFE29A),
        );
      }
    }
  }

  // ── common ──────────────────────────────────────────────────────────────

  void _bubbles(Canvas canvas, Offset c, double r, double t) {
    if (!front) {
      canvas.drawCircle(
        c,
        r * 1.05,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.18
          ..shader = SweepGradient(
            colors: const [
              Color(0x997FE3FF),
              Color(0x99FF9ECF),
              Color(0x99B9A8FF),
              Color(0x997FE3FF),
            ],
            transform: GradientRotation(t * 0.6),
          ).createShader(Rect.fromCircle(center: c, radius: r * 1.1))
          ..maskFilter = _blur(r * 0.1),
      );
      return;
    }
    for (var i = 0; i < 11; i++) {
      final p = (t * (0.22 + _rand(i, 1) * 0.12) + _rand(i, 2)) % 1;
      final a = i * 2 * math.pi / 11 + math.sin(t * 0.8 + i) * 0.25;
      final pos = c + _dir(a) * r * (1.0 + 0.3 * p) + Offset(0, -r * 0.45 * p);
      final s = r * (0.06 + 0.1 * math.sin(math.pi * p));
      final alpha = math.sin(math.pi * p);
      final rect = Rect.fromCircle(center: pos, radius: s);
      canvas.drawCircle(
        pos,
        s,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0x10FFFFFF),
              const Color(0x557FE3FF).withValues(alpha: 0.33 * alpha),
              const Color(0x88FF9ECF).withValues(alpha: 0.5 * alpha),
            ],
            stops: const [0.0, 0.75, 1.0],
          ).createShader(rect),
      );
      canvas.drawCircle(
        pos,
        s,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.8, s * 0.12)
          ..color = Colors.white.withValues(alpha: 0.75 * alpha),
      );
      canvas.drawCircle(
        pos + Offset(-s * 0.35, -s * 0.35),
        s * 0.22,
        Paint()..color = Colors.white.withValues(alpha: 0.9 * alpha),
      );
    }
  }

  void _sakura(Canvas canvas, Offset c, double r, double t) {
    if (!front) {
      _glowRing(canvas, c, r, const Color(0x99FF8FC4), width: 0.22);
      return;
    }
    for (var i = 0; i < 10; i++) {
      final a = t * 0.7 + i * 2 * math.pi / 10;
      final d = r * (1.14 + 0.1 * math.sin(t * 1.8 + i * 1.3));
      final pos = c + _dir(a) * d;
      final s = r * (0.13 + 0.04 * _rand(i, 6));
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(a + t * 2.4 + i);
      final petal = Path()
        ..moveTo(0, -s)
        ..quadraticBezierTo(s * 0.9, -s * 0.2, 0, s)
        ..quadraticBezierTo(-s * 0.9, -s * 0.2, 0, -s)
        ..close();
      canvas.drawPath(
        petal,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFE3F0), Color(0xFFFF8FC4)],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: s)),
      );
      canvas.drawLine(
        Offset(0, -s * 0.5),
        Offset(0, s * 0.6),
        Paint()
          ..strokeWidth = math.max(0.6, s * 0.08)
          ..color = const Color(0x66C2407A),
      );
      canvas.restore();
    }
  }

  void _frost(Canvas canvas, Offset c, double r, double t) {
    final pulse = 0.5 + 0.5 * math.sin(t * 2.5);
    if (!front) {
      _glowRing(
        canvas,
        c,
        r,
        const Color(0xFF7FE3FF).withValues(alpha: 0.45 + 0.3 * pulse),
        width: 0.24,
      );
      // Ice shards around the rim.
      const n = 14;
      for (var i = 0; i < n; i++) {
        final a = i * 2 * math.pi / n;
        final len = r * (0.12 + 0.1 * (0.5 + 0.5 * math.sin(t * 3 + i * 2)));
        final base = c + _dir(a) * r * 0.98;
        final shard = Path()
          ..moveTo(
            (base + _dir(a + math.pi / 2) * r * 0.05).dx,
            (base + _dir(a + math.pi / 2) * r * 0.05).dy,
          )
          ..lineTo((base + _dir(a) * len).dx, (base + _dir(a) * len).dy)
          ..lineTo(
            (base + _dir(a - math.pi / 2) * r * 0.05).dx,
            (base + _dir(a - math.pi / 2) * r * 0.05).dy,
          )
          ..close();
        canvas.drawPath(shard, Paint()..color = const Color(0xCCDDF6FF));
      }
      return;
    }
    for (var i = 0; i < 6; i++) {
      final a = -t * 0.5 + i * math.pi / 3;
      final p = c + _dir(a) * r * 1.22;
      final s = r * 0.11;
      final paint = Paint()
        ..strokeWidth = math.max(0.9, r * 0.025)
        ..strokeCap = StrokeCap.round
        ..color = Colors.white;
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(t * 1.2 + i);
      for (var k = 0; k < 6; k++) {
        final d = _dir(k * math.pi / 3);
        canvas.drawLine(Offset.zero, d * s, paint);
        final mid = d * s * 0.55;
        canvas.drawLine(
          mid,
          mid + _dir(k * math.pi / 3 + 0.7) * s * 0.3,
          paint,
        );
        canvas.drawLine(
          mid,
          mid + _dir(k * math.pi / 3 - 0.7) * s * 0.3,
          paint,
        );
      }
      canvas.restore();
    }
  }

  // ── mythic ────────────────────────────────────────────────────────────────

  /// Crimson Fury: a red fire vortex spinning fast, shockwaves pulsing out,
  /// red lightning cracking round the rim and energy orbs racing with
  /// trails. Everything surges together a few times a second.
  void _fury(Canvas canvas, Offset c, double r, double t) {
    const red = Color(0xFFFF1F3D);
    const palette = [
      Color(0xFFFFFFFF),
      Color(0xEEFF7A8A),
      Color(0xBBFF1F3D),
      Color(0x00700010),
    ];
    final spin = t * 2.2;
    final beat = (t * 2.4) % 1;
    final surge = beat < 0.12 ? 1 - beat / 0.12 : 0.0;

    if (!front) {
      // Shockwaves rolling outward.
      for (var k = 0; k < 3; k++) {
        final p = (t * 0.9 + k / 3) % 1;
        canvas.drawCircle(
          c,
          r * (1.0 + 0.85 * p),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.07 * (1 - p) + 0.6
            ..color = red.withValues(alpha: 0.55 * (1 - p)),
        );
      }
      canvas.drawCircle(
        c,
        r * 1.1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.6
          ..color = red.withValues(alpha: 0.4 + 0.3 * surge)
          ..maskFilter = _blur(r * 0.3),
      );
      _fireTongues(
        canvas,
        c,
        r,
        t * 1.3,
        spin,
        count: 16,
        size: 1.15 + 0.25 * surge,
        salt: 5,
        palette: palette,
      );
      _fireTongues(
        canvas,
        c,
        r,
        t * 1.3,
        spin + 0.2,
        count: 24,
        size: 0.65,
        salt: 6,
        palette: palette,
      );
      return;
    }

    // The burning band, spinning hard.
    final add = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..blendMode = BlendMode.plus;
    const bands = [
      (1.04, 0.16, 2.4, 1.0, Color(0xCCFF1F3D), 0.07),
      (1.02, 0.09, 2.0, 1.3, Color(0xEEFF6B7D), 0.03),
      (1.05, 0.04, 1.6, 1.7, Color(0xFFFFFFFF), 0.0),
    ];
    for (final (k, (radius, width, length, speed, color, blur))
        in bands.indexed) {
      for (var copy = 0; copy < 2; copy++) {
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(spin * speed + k * 1.3 + copy * math.pi);
        add
          ..strokeWidth = r * width * (1 + 0.3 * surge)
          ..maskFilter = blur > 0 ? _blur(r * blur) : null
          ..shader = SweepGradient(
            startAngle: 0,
            endAngle: length,
            colors: [
              color.withValues(alpha: 0),
              color,
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: r * 1.3));
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: r * radius),
          0,
          length,
          false,
          add,
        );
        canvas.restore();
      }
    }

    // Red lightning: new bolts about fifteen times a second.
    final flash = (t * 15).floor();
    for (var b = 0; b < 5; b++) {
      final seed = flash * 11 + b * 37;
      if (_rand(seed, 9) < 0.3) continue;
      final start = _rand(seed, 1) * 2 * math.pi;
      final span = 0.5 + _rand(seed, 2) * 1.1;
      const segments = 10;
      final bolt = Path();
      for (var s = 0; s <= segments; s++) {
        final a = start + span * s / segments;
        final jitter = (s == 0 || s == segments)
            ? 0
            : (_rand(seed + s, 3) - 0.5) * 0.38;
        final p = c + _dir(a) * r * (1.15 + jitter);
        if (s == 0) {
          bolt.moveTo(p.dx, p.dy);
        } else {
          bolt.lineTo(p.dx, p.dy);
        }
      }
      // A fork leaping outward.
      final forkA = start + span * _rand(seed, 4);
      final fork = Path()
        ..moveTo(
          (c + _dir(forkA) * r * 1.15).dx,
          (c + _dir(forkA) * r * 1.15).dy,
        )
        ..lineTo(
          (c + _dir(forkA + 0.1) * r * 1.4).dx,
          (c + _dir(forkA + 0.1) * r * 1.4).dy,
        )
        ..lineTo(
          (c + _dir(forkA - 0.05) * r * 1.62).dx,
          (c + _dir(forkA - 0.05) * r * 1.62).dy,
        );
      for (final path in [bolt, fork]) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.13
            ..strokeJoin = StrokeJoin.round
            ..color = red.withValues(alpha: 0.75)
            ..maskFilter = _blur(r * 0.07),
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.0, r * 0.035)
            ..strokeJoin = StrokeJoin.round
            ..color = Colors.white,
        );
      }
    }

    // Energy orbs racing round with trails.
    for (var i = 0; i < 3; i++) {
      final a = -t * (2.6 + i * 0.4) + i * 2 * math.pi / 3;
      for (var k = 6; k >= 0; k--) {
        final p = c + _dir(a + k * 0.09) * r * 1.3;
        canvas.drawCircle(
          p,
          r * (0.07 - k * 0.008),
          Paint()
            ..color = (k == 0 ? Colors.white : red).withValues(
              alpha: k == 0 ? 1 : 0.5 * (1 - k / 7),
            )
            ..maskFilter = _blur(r * 0.03),
        );
      }
    }

    // Sparks flung off.
    for (var i = 0; i < 18; i++) {
      final life = (t * (0.8 + _rand(i, 1) * 0.5) + _rand(i, 2)) % 1;
      final a = spin + _rand(i, 3) * 2 * math.pi + life * 1.2;
      final pos = c + _dir(a) * r * (1.1 + 0.7 * life);
      canvas.drawCircle(
        pos,
        r * 0.028 * (1 - life) + 0.5,
        Paint()
          ..color = Color.lerp(
            Colors.white,
            red,
            life,
          )!.withValues(alpha: 1 - life),
      );
    }
  }

  /// Supernova: a star going off around the picture. Rays spin and swell,
  /// a shock ring rolls out every beat, and sparks fly from the corona.
  void _supernova(Canvas canvas, Offset c, double r, double t) {
    final beat = (t * 0.7) % 1;
    final swell = beat < 0.15 ? 1 - beat / 0.15 : 0.0;
    if (!front) {
      canvas.drawCircle(
        c,
        r * (1.25 + 0.15 * swell),
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFFFFF).withValues(alpha: 0.9),
              const Color(0xFFFFD24D).withValues(alpha: 0.7),
              const Color(0xFFFF7A1A).withValues(alpha: 0.35),
              const Color(0x00FF3D0A),
            ],
            stops: const [0.55, 0.7, 0.85, 1.0],
          ).createShader(Rect.fromCircle(center: c, radius: r * 1.6)),
      );
      // Spinning rays, long and short.
      const rays = 18;
      for (var i = 0; i < rays; i++) {
        final a = t * 0.5 + i * 2 * math.pi / rays;
        final long = i.isEven;
        final len =
            r *
            (long ? 1.9 : 1.45) *
            (1 + 0.18 * swell + 0.06 * math.sin(t * 5 + i));
        const w = 0.05;
        final path = Path()
          ..moveTo((c + _dir(a - w) * r).dx, (c + _dir(a - w) * r).dy)
          ..lineTo((c + _dir(a) * len).dx, (c + _dir(a) * len).dy)
          ..lineTo((c + _dir(a + w) * r).dx, (c + _dir(a + w) * r).dy)
          ..close();
        canvas.drawPath(
          path,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = RadialGradient(
              colors: [
                const Color(0xFFFFF6D6).withValues(alpha: long ? 0.9 : 0.6),
                const Color(0x00FFC94D),
              ],
            ).createShader(Rect.fromCircle(center: c, radius: len)),
        );
      }
      // The shock ring.
      canvas.drawCircle(
        c,
        r * (1.05 + 0.95 * beat),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.08 * (1 - beat) + 0.5
          ..color = Colors.white.withValues(alpha: 0.8 * (1 - beat)),
      );
      return;
    }
    // The corona hugging the rim.
    canvas.drawCircle(
      c,
      r * 1.02,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * (0.08 + 0.05 * swell)
        ..shader = SweepGradient(
          colors: const [
            Color(0xFFFFFFFF),
            Color(0xFFFFD24D),
            Color(0xFFFFFFFF),
            Color(0xFFFF9A2E),
            Color(0xFFFFFFFF),
          ],
          transform: GradientRotation(-t * 2),
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.1)),
    );
    // A lens flare: four thin beams.
    for (var k = 0; k < 4; k++) {
      final a = math.pi / 4 + k * math.pi / 2;
      final len = r * (1.5 + 0.5 * swell);
      canvas.drawLine(
        c + _dir(a) * r * 1.02,
        c + _dir(a) * len,
        Paint()
          ..strokeWidth = math.max(1.0, r * 0.025)
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(
            colors: [Colors.white, Colors.white.withValues(alpha: 0)],
          ).createShader(Rect.fromPoints(c + _dir(a) * r, c + _dir(a) * len)),
      );
    }
    // Sparks thrown out of the blast.
    for (var i = 0; i < 20; i++) {
      final life = (t * (0.6 + _rand(i, 1) * 0.5) + _rand(i, 2)) % 1;
      final a = _rand(i, 3) * 2 * math.pi;
      final pos = c + _dir(a) * r * (1.05 + 0.9 * life);
      canvas.drawCircle(
        pos,
        r * 0.03 * (1 - life) + 0.5,
        Paint()
          ..color = Color.lerp(
            Colors.white,
            const Color(0xFFFFA020),
            life,
          )!.withValues(alpha: 1 - life),
      );
    }
  }

  /// Event Horizon: a black hole's blazing disk wraps round the picture,
  /// passing behind it on the far side and in front on the near side, with
  /// light bent into a ring and matter spiralling in.
  void _blackhole(Canvas canvas, Offset c, double r, double t) {
    const tilt = -0.22;
    Offset disk(double a, double scale) {
      final x = math.cos(a) * r * 1.75 * scale;
      final y = math.sin(a) * r * 0.5 * scale;
      return c +
          Offset(
            x * math.cos(tilt) - y * math.sin(tilt),
            x * math.sin(tilt) + y * math.cos(tilt),
          );
    }

    if (!front) {
      // Darkness pulled around the picture, then the bent-light ring.
      canvas.drawCircle(
        c,
        r * 1.35,
        Paint()
          ..shader = RadialGradient(
            colors: const [
              Color(0xFF000000),
              Color(0xCC1A0830),
              Color(0x00100018),
            ],
            stops: const [0.6, 0.8, 1.0],
          ).createShader(Rect.fromCircle(center: c, radius: r * 1.35)),
      );
      canvas.drawCircle(
        c,
        r * 1.12,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.06
          ..shader = SweepGradient(
            colors: const [
              Color(0xFFFFE9C2),
              Color(0xFFFF8A3D),
              Color(0xFFB25CFF),
              Color(0xFFFF8A3D),
              Color(0xFFFFE9C2),
            ],
            transform: GradientRotation(t * 2.4),
          ).createShader(Rect.fromCircle(center: c, radius: r * 1.2))
          ..maskFilter = _blur(r * 0.03),
      );
    }

    // The disk: bands of glowing matter racing round. Far side behind the
    // picture, near side in front.
    final dot = Paint()..blendMode = BlendMode.plus;
    for (var band = 0; band < 4; band++) {
      final scale = 0.78 + band * 0.1;
      final speed = 1.6 - band * 0.25;
      for (var i = 0; i < 48; i++) {
        final a = -t * speed + i * 2 * math.pi / 48 + band * 0.3;
        final near = math.sin(a + tilt) > 0;
        if (near != front) continue;
        final p = disk(a, scale);
        final hot = 1 - band / 4;
        dot.color = Color.lerp(
          const Color(0xFFB25CFF),
          Color.lerp(const Color(0xFFFF8A3D), Colors.white, hot * 0.6)!,
          0.4 + 0.6 * hot,
        )!.withValues(alpha: 0.55 + 0.35 * _rand(i + band * 60, 7));
        canvas.drawCircle(p, r * (0.05 - band * 0.008), dot);
      }
    }

    if (front) {
      // Matter spiralling in and vanishing at the edge.
      for (var i = 0; i < 12; i++) {
        final life = (t * 0.45 + _rand(i, 1)) % 1;
        final a = _rand(i, 2) * 2 * math.pi + life * 4;
        final d = r * (1.9 - 0.8 * life);
        canvas.drawCircle(
          c + _dir(a) * d,
          r * 0.025 + 0.4,
          Paint()
            ..color = const Color(
              0xFFFFE9C2,
            ).withValues(alpha: math.sin(life * math.pi)),
        );
      }
    }
  }

  /// Frostfire: half the ring is ice-blue flame, half is fire, the two
  /// chasing each other round with sparks where they meet.
  void _frostfire(Canvas canvas, Offset c, double r, double t) {
    final turn = t * 1.1;
    bool fire(double a) => math.cos(a - turn) >= 0;
    const ice = [
      Color(0xEEFFFFFF),
      Color(0xDDB8E8FF),
      Color(0x995AB8FF),
      Color(0x001A5CFF),
    ];
    if (!front) {
      canvas.drawCircle(
        c,
        r * 1.1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.5
          ..shader = SweepGradient(
            colors: const [
              Color(0x88FF6A1A),
              Color(0x885AB8FF),
              Color(0x88FF6A1A),
            ],
            transform: GradientRotation(turn - math.pi / 2),
          ).createShader(Rect.fromCircle(center: c, radius: r * 1.2))
          ..maskFilter = _blur(r * 0.25),
      );
      _fireTongues(
        canvas,
        c,
        r,
        t,
        turn * 0.6,
        count: 18,
        size: 1.05,
        salt: 7,
        where: fire,
      );
      _fireTongues(
        canvas,
        c,
        r,
        t,
        turn * 0.6,
        count: 18,
        size: 1.05,
        salt: 7,
        palette: ice,
        where: (a) => !fire(a),
      );
      return;
    }
    // The band: a fire half and an ice half.
    final rect = Rect.fromCircle(center: c, radius: r * 1.03);
    for (final (start, color) in [
      (turn - math.pi / 2, const Color(0xFFFF8A2E)),
      (turn + math.pi / 2, const Color(0xFF7FD8FF)),
    ]) {
      canvas.drawArc(
        rect,
        start,
        math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.1
          ..blendMode = BlendMode.plus
          ..color = color
          ..maskFilter = _blur(r * 0.03),
      );
    }
    // Where they meet: white-hot sparks and steam.
    for (final meet in [turn + math.pi / 2, turn - math.pi / 2]) {
      final p = c + _dir(meet) * r * 1.04;
      canvas.drawCircle(
        p,
        r * (0.12 + 0.05 * math.sin(t * 12)),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.85)
          ..maskFilter = _blur(r * 0.06),
      );
      for (var i = 0; i < 6; i++) {
        final life = (t * 1.5 + i / 6) % 1;
        final a = meet + (_rand(i, 4) - 0.5) * 1.6;
        canvas.drawCircle(
          p + _dir(a) * r * 0.45 * life,
          r * 0.025 * (1 - life) + 0.4,
          Paint()
            ..color = (i.isEven ? const Color(0xFFFFC23A) : Colors.white)
                .withValues(alpha: 1 - life),
        );
      }
    }
  }

  // ── legendary (more) ────────────────────────────────────────────────────

  /// Wings of flame beating behind the picture, a fiery ring and embers.
  void _phoenix(Canvas canvas, Offset c, double r, double t) {
    final beat = math.sin(t * 3.2);
    if (!front) {
      canvas.drawCircle(
        c,
        r * 1.1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.4
          ..color = const Color(0xFFFF6A1A).withValues(alpha: 0.3)
          ..maskFilter = _blur(r * 0.25),
      );
      final paint = Paint()..blendMode = BlendMode.plus;
      for (final side in const [-1.0, 1.0]) {
        // Five feathers per wing, fanned up and out, flapping together.
        for (var f = 0; f < 5; f++) {
          final spread = 0.25 + f * 0.28 + beat * 0.12;
          final a = -math.pi / 2 + side * (math.pi / 2 - 0.15 - spread * 0.55);
          final len = r * (0.95 + 0.18 * (4 - f) / 4) * (1 + 0.06 * beat);
          final root = c + Offset(side * r * 0.55, r * 0.1);
          final dir = _dir(a);
          final tg = _dir(a + math.pi / 2);
          final tip = root + dir * len;
          final w = r * 0.2;
          final flick = 0.5 + 0.5 * math.sin(t * 9 + f * 1.3 + side);
          final path = Path()
            ..moveTo((root - tg * w * 0.4).dx, (root - tg * w * 0.4).dy)
            ..quadraticBezierTo(
              (root + dir * len * 0.55 - tg * w).dx,
              (root + dir * len * 0.55 - tg * w).dy,
              (tip + tg * w * 0.2 * flick).dx,
              (tip + tg * w * 0.2 * flick).dy,
            )
            ..quadraticBezierTo(
              (root + dir * len * 0.5 + tg * w * 0.6).dx,
              (root + dir * len * 0.5 + tg * w * 0.6).dy,
              (root + tg * w * 0.4).dx,
              (root + tg * w * 0.4).dy,
            )
            ..close();
          paint.shader = RadialGradient(
            colors: const [
              Color(0xEEFFF2B0),
              Color(0xDDFFC23A),
              Color(0xAAFF6A1A),
              Color(0x00C4200F),
            ],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ).createShader(Rect.fromCircle(center: root, radius: len));
          canvas.drawPath(path, paint);
        }
      }
      return;
    }
    canvas.drawCircle(
      c,
      r * 1.02,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08
        ..shader = SweepGradient(
          colors: const [
            Color(0xFFFFE07A),
            Color(0xFFFF7A1A),
            Color(0xFFFFC23A),
            Color(0xFFFF4D1A),
            Color(0xFFFFE07A),
          ],
          transform: GradientRotation(t * 1.5),
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.1)),
    );
    for (var i = 0; i < 12; i++) {
      final p = (t * (0.4 + _rand(i, 1) * 0.3) + _rand(i, 2)) % 1;
      final a = -math.pi / 2 + (_rand(i, 3) - 0.5) * math.pi * 1.6;
      final pos = c + _dir(a) * r * 1.05 + Offset(0, -r * 0.9 * p);
      canvas.drawCircle(
        pos,
        r * 0.035 * (1 - p) + 0.6,
        Paint()
          ..color = Color.lerp(
            const Color(0xFFFFF2B0),
            const Color(0xFFFF4D1A),
            p,
          )!.withValues(alpha: 1 - p),
      );
    }
  }

  /// A spiral galaxy turning around the picture: two arms of stars over a
  /// soft nebula.
  void _galaxy(Canvas canvas, Offset c, double r, double t) {
    final turn = t * 0.45;
    if (!front) {
      // Nebula clouds.
      const clouds = [Color(0x998A5CFF), Color(0x88FF5CC8), Color(0x775C8AFF)];
      for (var i = 0; i < 3; i++) {
        final a = turn * 0.7 + i * 2.1;
        canvas.drawCircle(
          c + _dir(a) * r * 0.75,
          r * 0.7,
          Paint()
            ..color = clouds[i]
            ..maskFilter = _blur(r * 0.4),
        );
      }
      // Two spiral arms.
      final star = Paint();
      for (var arm = 0; arm < 2; arm++) {
        for (var i = 0; i < 34; i++) {
          final u = i / 34;
          final a = turn + arm * math.pi + u * 3.4;
          final d =
              r * (1.0 + u * 0.7) + (_rand(i + arm * 50, 4) - 0.5) * r * 0.12;
          final tw = 0.45 + 0.55 * (0.5 + 0.5 * math.sin(t * 3 + i * 1.7));
          star.color = Color.lerp(
            const Color(0xFFFFFFFF),
            const Color(0xFFB9A0FF),
            u,
          )!.withValues(alpha: tw * (1 - u * 0.5));
          canvas.drawCircle(
            c + _dir(a) * d,
            r * (0.03 - u * 0.015) + 0.4,
            star,
          );
        }
      }
      return;
    }
    canvas.drawCircle(
      c,
      r * 1.02,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..shader = SweepGradient(
          colors: const [
            Color(0xFFB9A0FF),
            Color(0xFFFF8AD8),
            Color(0xFF7FB0FF),
            Color(0xFFB9A0FF),
          ],
          transform: GradientRotation(-t * 0.8),
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.1)),
    );
    for (var i = 0; i < 4; i++) {
      final s = math.max(0.0, math.sin(t * 1.8 + i * 1.6));
      _sparkle(
        canvas,
        c + _dir(turn + i * math.pi / 2 + 0.6) * r * 1.3,
        r * 0.14 * s,
        Colors.white,
      );
    }
  }

  /// Dark violet flames with a glowing green heart, rising upward.
  void _shadow(Canvas canvas, Offset c, double r, double t) {
    if (!front) {
      canvas.drawCircle(
        c,
        r * 1.1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.5
          ..color = const Color(0xFF3A0F6B).withValues(alpha: 0.6)
          ..maskFilter = _blur(r * 0.25),
      );
      canvas.drawCircle(
        c,
        r * 1.04,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.16
          ..color = const Color(
            0xFF9DFF4D,
          ).withValues(alpha: 0.35 + 0.2 * math.sin(t * 3))
          ..maskFilter = _blur(r * 0.12),
      );
    }
    const n = 18;
    for (var i = 0; i < n; i++) {
      final a = i * 2 * math.pi / n + t * 0.3;
      // Back half behind the picture, front half over it.
      if ((i.isEven) == front) continue;
      final up = (1 - math.sin(a)) / 2;
      final flicker =
          0.5 + 0.5 * math.sin(t * 8 + i * 1.7) * math.sin(t * 4.7 + i * 0.9);
      final h = r * (0.15 + 0.25 * flicker + 0.25 * up);
      final lean = _dir(a) + const Offset(0, -0.9);
      final dir = lean / lean.distance;
      final w = math.pi / n * 1.2;
      final baseL = c + _dir(a - w) * r * 0.94;
      final baseR = c + _dir(a + w) * r * 0.94;
      final mid = c + _dir(a) * r * 0.94;
      final tip = mid + dir * h;
      final path = Path()
        ..moveTo(baseL.dx, baseL.dy)
        ..quadraticBezierTo(
          (baseL + tip).dx / 2 - dir.dy * h * 0.2,
          (baseL + tip).dy / 2 + dir.dx * h * 0.2,
          tip.dx,
          tip.dy,
        )
        ..quadraticBezierTo(
          (baseR + tip).dx / 2 + dir.dy * h * 0.2,
          (baseR + tip).dy / 2 - dir.dx * h * 0.2,
          baseR.dx,
          baseR.dy,
        )
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = RadialGradient(
            colors: const [
              Color(0xFFD8FF8A),
              Color(0xFF6BE03A),
              Color(0xCC4A1A8C),
              Color(0x0012051F),
            ],
            stops: const [0.0, 0.25, 0.6, 1.0],
          ).createShader(Rect.fromCircle(center: mid, radius: h * 1.05 + 1)),
      );
    }
    if (front) {
      for (var i = 0; i < 8; i++) {
        final p = (t * (0.35 + _rand(i, 1) * 0.25) + _rand(i, 2)) % 1;
        final a = -math.pi / 2 + (_rand(i, 3) - 0.5) * math.pi * 1.2;
        final pos = c + _dir(a) * r * 1.1 + Offset(0, -r * 0.8 * p);
        canvas.drawCircle(
          pos,
          r * 0.03 * (1 - p) + 0.5,
          Paint()
            ..color = const Color(0xFFB6FF6A).withValues(alpha: 1 - p)
            ..maskFilter = _blur(r * 0.02),
        );
      }
    }
  }

  // ── rare (more) ─────────────────────────────────────────────────────────

  /// Two neon rings, pink and cyan, racing opposite ways with a bright
  /// spark chasing round each.
  void _neon(Canvas canvas, Offset c, double r, double t) {
    final pulse = 0.5 + 0.5 * math.sin(t * 4);
    const pink = Color(0xFFFF3DF2);
    const cyan = Color(0xFF3DF5FF);
    if (!front) {
      for (final (color, scale) in const [(cyan, 1.06), (pink, 1.18)]) {
        canvas.drawCircle(
          c,
          r * scale,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.14
            ..color = color.withValues(alpha: 0.35 + 0.25 * pulse)
            ..maskFilter = _blur(r * 0.12),
        );
      }
      return;
    }
    void dashes(Color color, double scale, int count, double len, double turn) {
      final rect = Rect.fromCircle(center: c, radius: r * scale);
      for (var i = 0; i < count; i++) {
        final a = turn + i * 2 * math.pi / count;
        canvas.drawArc(
          rect,
          a,
          len,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = r * 0.07
            ..color = color,
        );
        canvas.drawArc(
          rect,
          a,
          len,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = r * 0.025
            ..color = Colors.white.withValues(alpha: 0.85),
        );
      }
      final spark = c + _dir(turn * 1.6) * r * scale;
      canvas.drawCircle(
        spark,
        r * 0.07,
        Paint()
          ..color = Colors.white
          ..maskFilter = _blur(r * 0.04),
      );
    }

    dashes(cyan, 1.06, 6, 0.6, t * 1.4);
    dashes(pink, 1.18, 4, 1.0, -t * 1.1);
  }

  /// Waves rolling round the picture, with droplets splashing off.
  void _tidal(Canvas canvas, Offset c, double r, double t) {
    if (!front) {
      canvas.drawCircle(
        c,
        r * 1.1,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.36
          ..color = const Color(0xFF1A6BFF).withValues(alpha: 0.35)
          ..maskFilter = _blur(r * 0.2),
      );
    }
    const waves = [
      (1.08, 5.0, 0.07, Color(0xFF1A6BFF), 0.16, 0.9),
      (1.05, 7.0, 0.05, Color(0xFF3FD8FF), 0.1, -1.3),
      (1.03, 9.0, 0.03, Color(0xFFE6FBFF), 0.04, 1.8),
    ];
    for (final (i, (scale, freq, amp, color, width, speed)) in waves.indexed) {
      // The deep wave behind, the crests in front.
      if ((i == 0) == front) continue;
      final path = Path();
      const steps = 90;
      for (var k = 0; k <= steps; k++) {
        final a = k / steps * 2 * math.pi;
        final d = r * (scale + amp * math.sin(a * freq + t * speed * 3));
        final p = c + _dir(a) * d;
        if (k == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * width
          ..strokeJoin = StrokeJoin.round
          ..color = color.withValues(alpha: i == 2 ? 0.9 : 0.8),
      );
    }
    if (front) {
      for (var i = 0; i < 10; i++) {
        final life = (t * 0.7 + _rand(i, 1)) % 1;
        final a = _rand(i, 2) * 2 * math.pi + t * 0.3;
        final d = r * (1.1 + 0.4 * life);
        final pos = c + _dir(a) * d + Offset(0, r * 0.3 * life * life);
        canvas.drawCircle(
          pos,
          r * 0.04 * (1 - life) + 0.5,
          Paint()..color = const Color(0xFFBFF4FF).withValues(alpha: 1 - life),
        );
      }
    }
  }

  /// A golden halo floating above the head, with feathers drifting down.
  // ── Zombie Bite ─────────────────────────────────────────────────────────

  /// The Zombie Bite frame's shapes for a picture of radius 1 at the
  /// origin, built once (path operations are too slow to redo every
  /// frame) and scaled to each picture: the chunk bitten out, top right (a
  /// round bite edged with tooth marks, right through the rim and into
  /// the picture), the rim, the rim with the bite gone, everywhere but the
  /// bite, and the frame with the picture in it (where the bite's torn
  /// edge shows).
  static final _biteShapes = () {
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
      whole: whole,
      disc: disc,
      band: Path.combine(PathOperation.difference, whole, bite),
      unbitten: Path.combine(PathOperation.difference, everywhere, bite),
      // The glow behind keeps going outside the frame; only the gap
      // bitten out of the frame and picture is left empty.
      gapless: Path.combine(
        PathOperation.difference,
        everywhere,
        Path.combine(PathOperation.intersect, bite, disc),
      ),
    );
  }();

  /// Undead, not on fire: the frame turns to rotting, stitched-up skin with
  /// a bite taken clean out of it (nothing there, just tooth marks round
  /// the gap), two zombie hands claw up from below to grab it, slime drips
  /// off the bottom and flies buzz round.
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
      canvas.save();
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

    canvas.restore();

    // The bitten edge, through the rim and the picture: torn skin, darker
    // where the teeth went in, and a drip of slime running off it.
    canvas.save();
    canvas.clipPath(_biteShapes.disc.transform(fit));
    canvas.drawPath(
      bite,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.07
        ..color = skinDark,
    );
    canvas.drawPath(
      bite,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.028
        ..strokeJoin = StrokeJoin.round
        ..color = ink,
    );
    canvas.restore();
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

  // ── Inferno ─────────────────────────────────────────────────────────────

  /// A frame of lava running down both sides of the picture, fire trying
  /// to catch round it, great obsidian horns sweeping out and curling in
  /// with white-hot tips, an obsidian tail curling out from behind, smoke
  /// and embers rising. No glow spills out past it.
  void _demon(Canvas canvas, Offset c, double r, double t) {
    if (!front) {
      _smoke(canvas, c, r, t);
      _obsidianTail(canvas, c, r, t);
      // The flames, behind the picture.
      _hellfire(canvas, c, r, t, back: true);
      for (final side in const [-1.0, 1.0]) {
        _obsidianHorn(canvas, c, r, t, side);
      }
      return;
    }
    _lavaFrame(canvas, c, r, t);
    // Short flames licking up over the rim, and embers.
    _hellfire(canvas, c, r, t, back: false);
    if (_lite) return;
    for (var i = 0; i < 16; i++) {
      final life = (t * (0.3 + _rand(i, 120) * 0.25) + _rand(i, 121)) % 1.0;
      final x =
          c.dx +
          (_rand(i, 122) - 0.5) * r * 2.4 +
          math.sin(t * 2 + i) * r * 0.06;
      final y = c.dy + r * (0.6 - life * 2.4);
      canvas.drawCircle(
        Offset(x, y),
        r * (0.012 + 0.018 * _rand(i, 123)) * (1 - life * 0.6),
        Paint()
          ..color = Color.lerp(
            const Color(0xFFFFF0B0),
            const Color(0xFFFF5A1F),
            life,
          )!.withValues(alpha: math.sin(life * math.pi)),
      );
    }
  }

  /// Fire trying to catch: round the top of the frame little flames keep
  /// flaring up, sputtering and dying back before they take hold, sparks
  /// spitting off as they go. [back] draws the ones behind the picture;
  /// otherwise the small ones licking at the rim.
  void _hellfire(
    Canvas canvas,
    Offset c,
    double r,
    double t, {
    required bool back,
  }) {
    final count = _lite ? 7 : 13;
    for (var k = 0; k < count; k++) {
      final u = k / (count - 1);
      // From just below the left side, over the top, to the right.
      final a = -math.pi - 0.2 + (math.pi + 0.4) * u;
      final high = 0.5 + 0.5 * -math.sin(a); // 1 at the top
      // Each flame keeps its own rhythm: a quick flare, a sputter, then
      // it dies back to an ember before trying again.
      final period = 1.3 + _rand(k, 130) * 1.4;
      final p = ((t + _rand(k, 131) * period) % period) / period;
      final flare = p < 0.22
          ? Curves.easeOut.transform(p / 0.22)
          : p < 0.5
          ? 1 - 0.5 * (p - 0.22) / 0.28
          : 0.5 * (1 - (p - 0.5) / 0.5);
      final sputter = 0.7 + 0.3 * math.sin(t * 23 + k * 3.1);
      final strength = (flare * sputter).clamp(0.0, 1.0);
      final base = c + _dir(a) * r * (back ? 1.1 : 1.17);
      final rise = Offset(_dir(a).dx * 0.3, -1);
      final len =
          r * 0.05 +
          r * (back ? 0.16 + 0.3 * high : 0.06 + 0.1 * high) * strength;
      final width = r * (back ? 0.16 : 0.1) * (0.65 + 0.35 * strength);
      _fireTongue(canvas, base, rise, len, width, t * 1.6 + k * 0.7);
      if (back && !_lite && p > 0.25 && p < 0.75) {
        // A spark spat off as the flame gutters.
        final q = (p - 0.25) / 0.5;
        final spark =
            base +
            Offset(math.sin(k * 1.7) * r * 0.12 * q, -r * (0.12 + 0.45 * q));
        canvas.drawCircle(
          spark,
          r * 0.018 * (1 - q),
          Paint()
            ..color = Color.lerp(
              const Color(0xFFFFF0B0),
              const Color(0xFFFF6A1F),
              q,
            )!.withValues(alpha: 1 - q),
        );
      }
    }
  }

  void _fireTongue(
    Canvas canvas,
    Offset base,
    Offset dir,
    double length,
    double width,
    double t,
  ) {
    final d = dir / dir.distance;
    final n = Offset(-d.dy, d.dx);
    Path tongue(double len, double w, double phase) {
      final wave = math.sin(t * 5 + phase) * len * 0.16;
      final tip = base + d * len + n * wave;
      final c1 = base + d * (len * 0.35) + n * (w * 0.75);
      final c2 = base + d * (len * 0.75) + n * (w * 0.3 + wave * 0.6);
      final c3 = base + d * (len * 0.75) - n * (w * 0.25 - wave * 0.6);
      final c4 = base + d * (len * 0.35) - n * (w * 0.7);
      return Path()
        ..moveTo((base + n * w * 0.5).dx, (base + n * w * 0.5).dy)
        ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, tip.dx, tip.dy)
        ..cubicTo(
          c3.dx,
          c3.dy,
          c4.dx,
          c4.dy,
          (base - n * w * 0.5).dx,
          (base - n * w * 0.5).dy,
        )
        ..close();
    }

    canvas.drawPath(
      tongue(length, width, 0),
      Paint()
        ..color = const Color(0xFFB3121B).withValues(alpha: 0.9)
        ..maskFilter = _blur(width * 0.12),
    );
    canvas.drawPath(
      tongue(length * 0.8, width * 0.72, 0.6),
      Paint()..color = const Color(0xFFFF4A1A),
    );
    canvas.drawPath(
      tongue(length * 0.58, width * 0.48, 1.1),
      Paint()..color = const Color(0xFFFFA43A),
    );
    canvas.drawPath(
      tongue(length * 0.32, width * 0.26, 1.7),
      Paint()..color = const Color(0xFFFFF2C2),
    );
  }

  /// Red-black smoke rolling up off the fire and thinning out.
  void _smoke(Canvas canvas, Offset c, double r, double t) {
    final puffs = _lite ? 5 : 11;
    for (var i = 0; i < puffs; i++) {
      final life = (t * (0.18 + _rand(i, 125) * 0.1) + _rand(i, 126)) % 1.0;
      final x =
          c.dx +
          (_rand(i, 127) - 0.5) * r * 1.8 +
          math.sin(t * 0.8 + i) * r * 0.15 * life;
      final y = c.dy - r * (0.9 + life * 1.5);
      canvas.drawCircle(
        Offset(x, y),
        r * (0.16 + 0.3 * life),
        Paint()
          ..color = Color.lerp(
            const Color(0xFF7A1A14),
            const Color(0xFF241414),
            life,
          )!.withValues(alpha: 0.45 * math.sin(life * math.pi))
          ..maskFilter = _blur(r * 0.12),
      );
    }
  }

  /// A great obsidian horn rising from the top of the frame: out and up
  /// from the base, then curling in, ridged, lit orange by the fire on its
  /// inner side, its tip glowing white-hot.
  void _obsidianHorn(Canvas canvas, Offset c, double r, double t, double side) {
    final base = c + _dir(-math.pi / 2 + side * 0.62) * r * 1.02;
    final sway = math.sin(t * 1.4) * r * 0.01;
    final pts = [
      base,
      base + Offset(side * r * 0.3, -r * 0.2),
      base + Offset(side * r * 0.52, -r * 0.55 + sway),
      base + Offset(side * r * 0.42, -r * 0.92 + sway),
      base + Offset(side * r * 0.16, -r * 1.06 + sway),
    ];
    const widths = [0.2, 0.17, 0.12, 0.065, 0.006];
    // Smooth the spine and taper along it.
    final spine = <Offset>[];
    final ws = <double>[];
    for (var i = 0; i < pts.length - 1; i++) {
      for (var k = 0; k < 8; k++) {
        final q = k / 8;
        final p0 = pts[math.max(0, i - 1)];
        final p1 = pts[i];
        final p2 = pts[i + 1];
        final p3 = pts[math.min(pts.length - 1, i + 2)];
        final q2 = q * q;
        final q3 = q2 * q;
        spine.add(
          (p1 * 2 +
                  (p2 - p0) * q +
                  (p0 * 2 - p1 * 5 + p2 * 4 - p3) * q2 +
                  (p1 * 3 - p0 - p2 * 3 + p3) * q3) *
              0.5,
        );
        ws.add(r * (widths[i] + (widths[i + 1] - widths[i]) * q));
      }
    }
    spine.add(pts.last);
    ws.add(r * widths.last);
    final normals = <Offset>[
      for (var i = 0; i < spine.length; i++)
        () {
          final d =
              spine[math.min(spine.length - 1, i + 1)] -
              spine[math.max(0, i - 1)];
          final l = d.distance;
          return l == 0 ? const Offset(1, 0) : Offset(-d.dy / l, d.dx / l);
        }(),
    ];
    final left = [
      for (var i = 0; i < spine.length; i++) spine[i] + normals[i] * ws[i],
    ];
    final right = [
      for (var i = 0; i < spine.length; i++) spine[i] - normals[i] * ws[i],
    ];
    final horn = Path()..addPolygon([...left, ...right.reversed], true);
    final box = horn.getBounds();
    canvas.drawPath(
      horn,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: const [
            Color(0xFF3A2620),
            Color(0xFF14090A),
            Color(0xFF2A0E08),
            Color(0xFFFF7A2A),
            Color(0xFFFFF0C0),
          ],
          stops: const [0.0, 0.45, 0.78, 0.94, 1.0],
        ).createShader(box),
    );
    // The inner edge, lit by the fire.
    final inner = side > 0 ? right : left;
    final rim = Path()..moveTo(inner.first.dx, inner.first.dy);
    for (final p in inner.skip(1)) {
      rim.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.02
        ..color = const Color(
          0xFFFF7A2A,
        ).withValues(alpha: 0.75 + 0.2 * math.sin(t * 4))
        ..maskFilter = _blur(r * 0.01),
    );
    if (_lite) return;
    // Ridges round it.
    final ridge = Paint()
      ..strokeWidth = r * 0.012
      ..color = Colors.black.withValues(alpha: 0.55);
    for (var i = 3; i < spine.length - 6; i += 3) {
      canvas.drawLine(left[i], right[i], ridge);
    }
    // The tip glowing.
    canvas.drawCircle(
      spine.last,
      r * 0.06,
      Paint()
        ..color = const Color(
          0xFFFFC04A,
        ).withValues(alpha: 0.6 + 0.3 * math.sin(t * 5))
        ..maskFilter = _blur(r * 0.05),
    );
  }

  /// The frame as a channel of lava, like a volcano's: molten, brightest
  /// down the middle, pouring from the top down both sides of the picture
  /// to meet at the bottom (it runs, it never spins). Only the lava moves:
  /// surges of heat and currents stream down it with fire riding the flow,
  /// past shelves of cooled magma that sit still on the banks, still hot
  /// enough to glow at their cracks. Rocky banks either side, and bubbles
  /// welling up and popping.
  void _lavaFrame(Canvas canvas, Offset c, double r, double t) {
    final outerR = r * 1.22;
    final innerR = r * 0.95;
    final mid = (outerR + innerR) / 2;
    final half = (outerR - innerR) / 2;
    final rect = Rect.fromCircle(center: c, radius: outerR);
    final band = Path()
      ..addOval(rect)
      ..addOval(Rect.fromCircle(center: c, radius: innerR))
      ..fillType = PathFillType.evenOdd;
    final pulse = 0.85 + 0.15 * math.sin(t * 3.1);
    final k0 = innerR / outerR;
    canvas.drawPath(
      band,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF8A1A0E),
            const Color(0xFFE8501A),
            Color.lerp(
              const Color(0xFFFFC04A),
              const Color(0xFFFFF0B0),
              0.4 * pulse,
            )!,
            const Color(0xFFE8501A),
            const Color(0xFF8A1A0E),
          ],
          stops: [
            k0,
            k0 + (1 - k0) * 0.25,
            k0 + (1 - k0) * 0.5,
            k0 + (1 - k0) * 0.78,
            1,
          ],
        ).createShader(rect),
    );

    canvas.save();
    canvas.clipPath(band);
    // Everything in the flow runs from the top (p = 0) down one side or
    // the other to the bottom (p = 1), fading in as it pours over the top
    // and out as it pools at the bottom.
    Offset along(double p, double side, double rr) =>
        c + _dir(-math.pi / 2 + side * p * math.pi) * rr;
    double fade(double p) =>
        Curves.easeOut.transform((p / 0.1).clamp(0.0, 1.0)) *
        (1 - Curves.easeIn.transform(((p - 0.88) / 0.12).clamp(0.0, 1.0)));
    // The direction the lava runs at [p] on [side].
    Offset downstream(double p, double side) {
      final a = -math.pi / 2 + side * p * math.pi;
      return Offset(-math.sin(a), math.cos(a)) * side;
    }

    // Surges of heat carried down by the flow: the whole river visibly
    // runs, brightening and dimming as each surge passes.
    final segments = _lite ? 28 : 56;
    final surge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..strokeWidth = half * 1.5
      ..maskFilter = _blur(half * 0.12);
    final channel = Rect.fromCircle(center: c, radius: mid);
    for (final side in const [-1.0, 1.0]) {
      for (var k = 0; k < segments; k++) {
        final p = (k + 0.5) / segments;
        final w1 = math.sin((p * 5 - t * 0.8) * 2 * math.pi);
        final w2 = math.sin((p * 9 - t * 1.3) * 2 * math.pi + side * 1.3);
        final heat = (0.5 + 0.38 * w1 + 0.22 * w2).clamp(0.0, 1.0);
        surge.color =
            (heat < 0.5
                    ? Color.lerp(
                        const Color(0xFFA8160E),
                        const Color(0xFFFF6A1F),
                        heat * 2,
                      )!
                    : Color.lerp(
                        const Color(0xFFFF6A1F),
                        const Color(0xFFFFF0B0),
                        heat * 2 - 1,
                      )!)
                .withValues(alpha: 0.8 * fade(p));
        canvas.drawArc(
          channel,
          -math.pi / 2 + side * (k / segments) * math.pi,
          side * math.pi / segments * 1.08,
          false,
          surge,
        );
      }
    }
    // Currents streaming down: fastest down the middle.
    final streaks = _lite ? 8 : 22;
    for (var i = 0; i < streaks; i++) {
      final side = i.isEven ? 1.0 : -1.0;
      final lane = (_rand(i, 140) - 0.5) * 1.6;
      final rr = mid + lane * half * 0.85;
      final speed = (0.1 + _rand(i, 141) * 0.12) * (1 - lane.abs() * 0.45);
      final p0 = (_rand(i, 142) + t * speed) % 1.0;
      final span = 0.08 + _rand(i, 143) * 0.14;
      final streak = Path();
      for (var j = 0; j <= 10; j++) {
        final p = p0 + span * j / 10;
        if (p > 1) break;
        final wobble = math.sin(j * 0.9 + t * 3 + i) * half * 0.08;
        final at = along(p, side, rr + wobble);
        j == 0 ? streak.moveTo(at.dx, at.dy) : streak.lineTo(at.dx, at.dy);
      }
      canvas.drawPath(
        streak,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = r * (0.01 + 0.014 * _rand(i, 144))
          ..color = Color.lerp(
            const Color(0xFFFFE07A),
            Colors.white,
            _rand(i, 145) * 0.5,
          )!.withValues(alpha: (0.35 + 0.45 * _rand(i, 146)) * fade(p0)),
      );
    }
    // Fire riding the flow: flames carried downstream, flickering, their
    // tails streaming out behind them.
    final flames = _lite ? 5 : 12;
    for (var i = 0; i < flames; i++) {
      final side = i.isEven ? 1.0 : -1.0;
      final lane = (_rand(i, 170) - 0.5) * 0.9;
      final speed = 0.09 + _rand(i, 171) * 0.08;
      final p = (_rand(i, 172) + t * speed) % 1.0;
      final o = fade(p);
      if (o < 0.05) continue;
      final flicker = 0.75 + 0.25 * math.sin(t * 11 + i * 2.3);
      _fireTongue(
        canvas,
        along(p, side, mid + lane * half),
        -downstream(p, side),
        half * (2.6 + 1.4 * _rand(i, 173)) * o * flicker,
        half * (1.1 + 0.4 * _rand(i, 174)) * o,
        t * 1.8 + i * 0.9,
      );
    }
    // Cooled magma: shelves of rock along the banks that stay put while
    // the lava runs past, still hot enough to glow at their cracks.
    final shelves = _lite ? 6 : 12;
    for (var i = 0; i < shelves; i++) {
      final side = i.isEven ? 1.0 : -1.0;
      final p0 = 0.04 + (i ~/ 2) / (shelves / 2) * 0.86 + _rand(i, 150) * 0.05;
      final span = 0.06 + _rand(i, 151) * 0.06;
      // Each grows from one bank partway across, leaving the middle open.
      final outer = _rand(i, 152) > 0.5;
      final bank = outer ? mid + half * 1.1 : mid - half * 1.1;
      final reach = half * (0.7 + 0.45 * _rand(i, 155));
      final edge = outer ? bank - reach : bank + reach;
      final pts = <Offset>[];
      const steps = 6;
      for (var k = 0; k <= steps; k++) {
        pts.add(along(p0 + span * k / steps, side, bank));
      }
      for (var k = steps; k >= 0; k--) {
        final q = k / steps;
        // Rounded at the ends, jagged along the lava side.
        final round = math.sin(q * math.pi);
        final jag = (_rand(i * 13 + k, 153) - 0.5) * half * 0.25;
        pts.add(
          along(
            p0 + span * q,
            side,
            bank + (edge - bank) * (0.35 + 0.65 * round) + jag,
          ),
        );
      }
      final shelf = Path()..addPolygon(pts, true);
      final heat = 0.7 + 0.3 * math.sin(t * 1.4 + i * 1.9);
      // The glow where lava meets rock.
      canvas.drawPath(
        shelf,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.04
          ..color = const Color(0xFFFF5A1F).withValues(alpha: 0.6 * heat)
          ..maskFilter = _blur(r * 0.02),
      );
      canvas.drawPath(
        shelf,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: const [
              Color(0xFF4A2A22),
              Color(0xFF22120E),
              Color(0xFF120806),
            ],
          ).createShader(shelf.getBounds()),
      );
      canvas.drawPath(
        shelf,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.012
          ..color = const Color(0xFFFF7A2A).withValues(alpha: 0.8 * heat),
      );
      // Cracks across it, glowing from the heat inside.
      final crack = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = r * 0.009
        ..color = const Color(0xFFFFB03A).withValues(alpha: 0.9 * heat);
      for (var k = 0; k < 2; k++) {
        final pm = p0 + span * (0.3 + 0.4 * k);
        final from = along(pm, side, bank + (edge - bank) * 0.15);
        final bend = along(
          pm + span * (_rand(i * 3 + k, 156) - 0.5) * 0.3,
          side,
          bank + (edge - bank) * 0.5,
        );
        final to = along(
          pm + span * (_rand(i * 3 + k, 157) - 0.5) * 0.4,
          side,
          bank + (edge - bank) * 0.8,
        );
        canvas.drawPath(
          Path()
            ..moveTo(from.dx, from.dy)
            ..lineTo(bend.dx, bend.dy)
            ..lineTo(to.dx, to.dy),
          crack,
        );
      }
    }
    canvas.restore();

    // Rocky banks on both sides, lit by the lava.
    for (final (edge, out) in [(outerR, 1.0), (innerR, -1.0)]) {
      final bank = <Offset>[];
      const n = 64;
      for (var k = 0; k <= n; k++) {
        final a = k / n * 2 * math.pi;
        bank.add(
          c +
              _dir(a) *
                  (edge -
                      out *
                          half *
                          (0.06 + 0.1 * _rand(k, out > 0 ? 160 : 161))),
        );
      }
      for (var k = n; k >= 0; k--) {
        final a = k / n * 2 * math.pi;
        bank.add(
          c +
              _dir(a) *
                  (edge +
                      out *
                          half *
                          (0.2 + 0.14 * _rand(k, out > 0 ? 162 : 163))),
        );
      }
      final path = Path()..addPolygon(bank, true);
      canvas.drawPath(path, Paint()..color = const Color(0xFF1E100C));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.012
          ..color = const Color(0xFFFF7A2A).withValues(alpha: 0.5 * pulse),
      );
    }

    if (_lite) return;
    // Bubbles welling up in the flow and popping.
    for (var i = 0; i < 8; i++) {
      final life = (t * (0.6 + _rand(i, 105) * 0.5) + _rand(i, 106)) % 1;
      // Each wells up in its own spot: the flow carries crust, not bubbles.
      final a =
          _rand(i, 107) * 2 * math.pi +
          (t * (0.6 + _rand(i, 105) * 0.5) + _rand(i, 106)).floor() * 2.1;
      final p = c + _dir(a) * (mid + (_rand(i, 108) - 0.5) * half);
      if (life < 0.8) {
        final s = r * 0.04 * Curves.easeOut.transform(life / 0.8);
        canvas.drawCircle(p, s, Paint()..color = const Color(0xFFFFE07A));
        canvas.drawCircle(
          p.translate(-s * 0.3, -s * 0.3),
          s * 0.35,
          Paint()..color = Colors.white.withValues(alpha: 0.8),
        );
      } else {
        final k = (life - 0.8) / 0.2;
        canvas.drawCircle(
          p,
          r * (0.04 + 0.045 * k),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.012
            ..color = const Color(0xFFFFD25A).withValues(alpha: 1 - k),
        );
      }
    }
  }

  /// An obsidian tail curling out from behind the frame, molten cracks
  /// glowing along it, ending in a barb with a white-hot edge.
  void _obsidianTail(Canvas canvas, Offset c, double r, double t) {
    final sway = math.sin(t * 1.3);
    final pts = [
      c + _dir(0.95) * r * 1.12,
      c + Offset(r * 1.42, r * 0.62 + sway * r * 0.03),
      c + Offset(r * 1.62, r * 0.12 + sway * r * 0.06),
      c + Offset(r * 1.5, -r * 0.32 + sway * r * 0.1),
      c + Offset(r * 1.3, -r * 0.52 + sway * r * 0.14),
    ];
    const widths = [0.1, 0.085, 0.065, 0.045, 0.03];
    final spine = <Offset>[];
    final ws = <double>[];
    for (var i = 0; i < pts.length - 1; i++) {
      for (var k = 0; k < 8; k++) {
        final q = k / 8;
        final p0 = pts[math.max(0, i - 1)];
        final p1 = pts[i];
        final p2 = pts[i + 1];
        final p3 = pts[math.min(pts.length - 1, i + 2)];
        final q2 = q * q;
        final q3 = q2 * q;
        spine.add(
          (p1 * 2 +
                  (p2 - p0) * q +
                  (p0 * 2 - p1 * 5 + p2 * 4 - p3) * q2 +
                  (p1 * 3 - p0 - p2 * 3 + p3) * q3) *
              0.5,
        );
        ws.add(r * (widths[i] + (widths[i + 1] - widths[i]) * q));
      }
    }
    spine.add(pts.last);
    ws.add(r * widths.last);
    final normals = [
      for (var i = 0; i < spine.length; i++)
        () {
          final d =
              spine[math.min(spine.length - 1, i + 1)] -
              spine[math.max(0, i - 1)];
          final l = d.distance;
          return l == 0 ? const Offset(1, 0) : Offset(-d.dy / l, d.dx / l);
        }(),
    ];
    final left = [
      for (var i = 0; i < spine.length; i++) spine[i] + normals[i] * ws[i],
    ];
    final right = [
      for (var i = 0; i < spine.length; i++) spine[i] - normals[i] * ws[i],
    ];
    final tail = Path()..addPolygon([...left, ...right.reversed], true);
    canvas.drawPath(
      tail,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A2620), Color(0xFF14090A), Color(0xFF241210)],
        ).createShader(tail.getBounds()),
    );
    if (!_lite) {
      // Molten cracks glowing through it.
      final crack = Paint()
        ..strokeWidth = r * 0.012
        ..strokeCap = StrokeCap.round
        ..color = const Color(
          0xFFFF7A2A,
        ).withValues(alpha: 0.7 + 0.25 * math.sin(t * 4));
      for (var i = 4; i < spine.length - 3; i += 4) {
        canvas.drawLine(
          spine[i] + normals[i] * ws[i] * 0.7,
          spine[i + 1] - normals[i] * ws[i] * 0.5,
          crack,
        );
      }
    }
    // The barb: a curved blade, edged white-hot.
    final tip = spine.last;
    final d = spine.last - spine[spine.length - 4];
    final td = d / (d.distance + 1e-6);
    final tn = Offset(-td.dy, td.dx);
    final s = r * 0.16;
    final barb = Path()
      ..moveTo((tip - tn * s * 0.35).dx, (tip - tn * s * 0.35).dy)
      ..quadraticBezierTo(
        (tip + td * s * 0.6 - tn * s * 0.8).dx,
        (tip + td * s * 0.6 - tn * s * 0.8).dy,
        (tip + td * s * 1.4 + tn * s * 0.1).dx,
        (tip + td * s * 1.4 + tn * s * 0.1).dy,
      )
      ..quadraticBezierTo(
        (tip + td * s * 0.5 + tn * s * 0.6).dx,
        (tip + td * s * 0.5 + tn * s * 0.6).dy,
        (tip + tn * s * 0.35).dx,
        (tip + tn * s * 0.35).dy,
      )
      ..close();
    canvas.drawPath(barb, Paint()..color = const Color(0xFF14090A));
    canvas.drawPath(
      barb,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.018
        ..color = const Color(0xFFFFB04A).withValues(alpha: 0.85)
        ..maskFilter = _blur(r * 0.01),
    );
  }

  void _halo(Canvas canvas, Offset c, double r, double t) {
    final bob = math.sin(t * 2) * r * 0.05;
    final hc = c + Offset(0, -r * 1.02 + bob);
    final rect = Rect.fromCenter(center: hc, width: r * 1.35, height: r * 0.34);
    if (!front) {
      canvas.drawCircle(
        c,
        r * 1.08,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.3
          ..color = const Color(0xFFFFF1C2).withValues(alpha: 0.35)
          ..maskFilter = _blur(r * 0.2),
      );
      canvas.drawOval(
        rect.inflate(r * 0.08),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.16
          ..color = const Color(0xFFFFE07A).withValues(alpha: 0.5)
          ..maskFilter = _blur(r * 0.1),
      );
      return;
    }
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.09
        ..shader = SweepGradient(
          colors: const [
            Color(0xFFFFF6D6),
            Color(0xFFFFC94D),
            Color(0xFFFFF6D6),
            Color(0xFFD9962A),
            Color(0xFFFFF6D6),
          ],
          transform: GradientRotation(t * 1.5),
        ).createShader(rect),
    );
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.025
        ..color = Colors.white.withValues(alpha: 0.9),
    );
    // Feathers drifting down either side.
    for (var i = 0; i < 6; i++) {
      final life = (t * 0.25 + _rand(i, 1)) % 1;
      final side = i.isEven ? -1.0 : 1.0;
      final x = side * r * (1.1 + 0.25 * math.sin(t * 1.5 + i * 2));
      final y = -r * 0.9 + r * 2.0 * life;
      canvas.save();
      canvas.translate(c.dx + x, c.dy + y);
      canvas.rotate(math.sin(t * 2 + i) * 0.6 + side * 0.4);
      final s = r * 0.16;
      final feather = Path()
        ..moveTo(0, -s)
        ..quadraticBezierTo(s * 0.55, -s * 0.2, 0, s)
        ..quadraticBezierTo(-s * 0.55, -s * 0.2, 0, -s)
        ..close();
      final alpha = math.sin(life * math.pi);
      canvas.drawPath(
        feather,
        Paint()..color = Colors.white.withValues(alpha: 0.85 * alpha),
      );
      canvas.drawLine(
        Offset(0, -s * 0.8),
        Offset(0, s * 1.1),
        Paint()
          ..strokeWidth = math.max(0.6, s * 0.07)
          ..color = const Color(0xFFD9C9A0).withValues(alpha: alpha),
      );
      canvas.restore();
    }
  }

  // ── common (more) ───────────────────────────────────────────────────────

  /// Hearts circling the picture, each beating twice in a row now and then.
  void _hearts(Canvas canvas, Offset c, double r, double t) {
    if (!front) {
      _glowRing(canvas, c, r, const Color(0x99FF6FA8), width: 0.22);
      return;
    }
    for (var i = 0; i < 8; i++) {
      final a = t * 0.6 + i * 2 * math.pi / 8;
      final phase = (t * 1.2 + i * 0.13) % 1;
      // A double beat: lub-dub.
      final beat =
          math.max(0.0, math.sin(phase * math.pi * 8)) * (phase < 0.25 ? 1 : 0);
      final s = r * (0.13 + 0.05 * beat);
      _heart(
        canvas,
        c + _dir(a) * r * 1.2,
        s,
        i.isEven ? const Color(0xFFFF4D8D) : const Color(0xFFFF8AB8),
      );
    }
  }

  void _heart(Canvas canvas, Offset p, double s, Color color) {
    final path = Path()
      ..moveTo(p.dx, p.dy + s * 0.75)
      ..cubicTo(
        p.dx - s * 1.2,
        p.dy - s * 0.05,
        p.dx - s * 0.6,
        p.dy - s * 1.0,
        p.dx,
        p.dy - s * 0.35,
      )
      ..cubicTo(
        p.dx + s * 0.6,
        p.dy - s * 1.0,
        p.dx + s * 1.2,
        p.dy - s * 0.05,
        p.dx,
        p.dy + s * 0.75,
      )
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [Color.lerp(color, Colors.white, 0.45)!, color],
        ).createShader(Rect.fromCircle(center: p, radius: s)),
    );
    canvas.drawCircle(
      p + Offset(-s * 0.35, -s * 0.35),
      s * 0.16,
      Paint()..color = Colors.white.withValues(alpha: 0.8),
    );
  }

  /// Fireflies wandering round the picture, blinking on and off.
  void _fireflies(Canvas canvas, Offset c, double r, double t) {
    if (!front) {
      _glowRing(canvas, c, r, const Color(0x55D8FF6A), width: 0.26, blur: 0.25);
      return;
    }
    for (var i = 0; i < 14; i++) {
      final a =
          i * 2 * math.pi / 14 +
          math.sin(t * (0.4 + _rand(i, 1) * 0.3) + i) * 0.5;
      final d = r * (1.15 + 0.2 * math.sin(t * (0.7 + _rand(i, 2)) + i * 2));
      final pos = c + _dir(a) * d;
      final blink = math.max(
        0.0,
        math.sin(t * (1.5 + _rand(i, 3) * 2) + i * 3),
      );
      if (blink <= 0.05) continue;
      canvas.drawCircle(
        pos,
        r * 0.09,
        Paint()
          ..color = const Color(0xFFD8FF6A).withValues(alpha: 0.5 * blink)
          ..maskFilter = _blur(r * 0.07),
      );
      canvas.drawCircle(
        pos,
        r * 0.028 + 0.5,
        Paint()..color = const Color(0xFFFFFFE0).withValues(alpha: blink),
      );
    }
  }

  /// Twinkling stars round the picture and a fine ring of stardust.
  void _starlight(Canvas canvas, Offset c, double r, double t) {
    if (!front) {
      _glowRing(canvas, c, r, const Color(0x77FFE7A3), width: 0.16);
      final dust = Paint()..color = const Color(0xCCFFF3CF);
      for (var i = 0; i < 36; i++) {
        final a = t * 0.25 + i * 2 * math.pi / 36;
        canvas.drawCircle(c + _dir(a) * r * 1.1, r * 0.012 + 0.4, dust);
      }
      return;
    }
    for (var i = 0; i < 10; i++) {
      final a = -t * 0.2 + i * 2 * math.pi / 10 + _rand(i, 1) * 0.4;
      final d = r * (1.18 + 0.15 * _rand(i, 2));
      final tw = math.max(0.0, math.sin(t * (1.6 + _rand(i, 3)) + i * 1.9));
      _sparkle(
        canvas,
        c + _dir(a) * d,
        r * (0.08 + 0.08 * tw),
        Color.lerp(const Color(0xFFFFE7A3), Colors.white, tw)!,
      );
    }
  }

  /// Autumn leaves swirling round on the wind, flipping as they go.
  void _autumn(Canvas canvas, Offset c, double r, double t) {
    if (!front) {
      _glowRing(canvas, c, r, const Color(0x88FF9A3D), width: 0.2);
      return;
    }
    const colors = [
      Color(0xFFFF8A2A),
      Color(0xFFE0452A),
      Color(0xFFFFC23A),
      Color(0xFFB8541A),
    ];
    for (var i = 0; i < 9; i++) {
      final a = t * 0.55 + i * 2 * math.pi / 9;
      final d = r * (1.16 + 0.1 * math.sin(t * 1.3 + i * 1.7));
      final pos = c + _dir(a) * d;
      final s = r * (0.14 + 0.03 * _rand(i, 4));
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(a + t * 1.8 + i);
      // Flipping in the wind.
      canvas.scale(math.cos(t * 2.4 + i).abs() * 0.7 + 0.3, 1);
      final leaf = Path()
        ..moveTo(0, -s)
        ..quadraticBezierTo(s * 0.8, -s * 0.3, 0, s)
        ..quadraticBezierTo(-s * 0.8, -s * 0.3, 0, -s)
        ..close();
      final color = colors[i % colors.length];
      canvas.drawPath(
        leaf,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(color, Colors.white, 0.25)!, color],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: s)),
      );
      canvas.drawLine(
        Offset(0, -s * 0.8),
        Offset(0, s * 1.15),
        Paint()
          ..strokeWidth = math.max(0.6, s * 0.08)
          ..color = Color.lerp(color, Colors.black, 0.35)!,
      );
      canvas.restore();
    }
  }

  void _sparkle(Canvas canvas, Offset p, double s, Color color) {
    if (s <= 0.2) return;
    final path = Path()
      ..moveTo(p.dx, p.dy - s)
      ..quadraticBezierTo(p.dx, p.dy, p.dx + s, p.dy)
      ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + s)
      ..quadraticBezierTo(p.dx, p.dy, p.dx - s, p.dy)
      ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - s);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant AuraPainter old) =>
      old.aura != aura || old.front != front;
}
