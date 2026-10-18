import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/utopia_themes.dart';
import 'dojo_art.dart';
import 'dojo_dragon.dart';
import 'fire_dragon.dart';
import 'doodle_world.dart';
import 'heaven_world.dart';
import 'hell_world.dart';
import 'music_world.dart';
import 'halloween_world.dart';
import 'birthday_world.dart';
import 'zombie_world.dart';
import 'ambient_tick.dart';

/// One clock shared by every copy of the world, so screens that each paint
/// their own background (and fade or slide between each other) always
/// agree on where the clouds, islands and stars are.
final Stopwatch _worldClock = Stopwatch()..start();

double get worldSeconds => _worldClock.elapsedMicroseconds / 1e6;

/// Utopia's living world, painted behind every screen in the active theme's
/// style (see [WorldStyle]). Every biome shares the sky: stars, a shooting
/// star, aurora ribbons, a planet, sun or moon, drifting clouds and
/// sparkles rising. Then each has its own land:
///
/// * islands: floating islands with a waterfall, a blossom tree and a
///   spinning crystal over a sea of clouds;
/// * ocean: rolling swells, a glittering reflection and birds;
/// * peaks: layered mountain ranges, floating rocks and a hot-air balloon;
/// * dunes: rolling sand dunes under a huge sun, sky lanterns rising.
///
/// Everything is painted (no image assets) from a single ticker. The ticker
/// only runs while its screen is visible, because Flutter mutes tickers on
/// covered routes. When the OS asks for reduced motion, the world is
/// painted once and holds still.
class UtopiaWorld extends StatefulWidget {
  const UtopiaWorld({super.key, this.style});

  /// Defaults to the active theme's world.
  final WorldStyle? style;

  @override
  State<UtopiaWorld> createState() => _UtopiaWorldState();
}

class _UtopiaWorldState extends State<UtopiaWorld>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _time = ValueNotifier(worldSeconds);
  final _sceneKey = GlobalKey();

  /// Where this world sits on screen, so things placed in screen terms
  /// (the frame the Dojo's dragon circles) land in the right spot.
  Offset _origin() {
    final box = _sceneKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return Offset.zero;
    return box.localToGlobal(Offset.zero);
  }

  late final Ticker _ticker = createTicker(
    ambientTick((_) => _time.value = worldSeconds),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    if (still && _ticker.isActive) _ticker.stop();
    if (!still && !_ticker.isActive) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style ?? UtopiaThemes.active.world;
    return IgnorePointer(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The sky and its planet, sun or moon never move, so they're
            // painted once into their own layer; only the scene on top
            // repaints per frame.
            if (style.biome == WorldBiome.doodle) ...[
              const RepaintBoundary(
                child: CustomPaint(painter: DoodleSkyPainter()),
              ),
              RepaintBoundary(
                child: CustomPaint(painter: DoodleScenePainter(_time)),
              ),
            ] else ...[
              RepaintBoundary(child: CustomPaint(painter: _SkyPainter(style))),
              RepaintBoundary(
                child: CustomPaint(
                  key: _sceneKey,
                  painter: _ScenePainter(_time, style, origin: _origin),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Stable pseudo-random 0-1 from an index, so every star, puff and firefly
/// keeps the same size and place across frames and rebuilds.
double _rand(int i, int salt) {
  final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

Color _alpha(Color color, double alpha) =>
    color.withValues(alpha: (color.a * alpha).clamp(0.0, 1.0));

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

const _skyStops = [0.0, 0.28, 0.52, 0.74, 0.9, 1.0];

/// Where each biome puts its celestial body, as fractions of the size.
Offset _celestialAnchor(WorldStyle style, Size size) {
  final w = size.width;
  final h = size.height;
  return switch (style.biome) {
    WorldBiome.islands => Offset(
      w * 0.9,
      math.max(w * 0.17 * 1.9 + 4, h * 0.14),
    ),
    WorldBiome.ocean => Offset(w * 0.7, h * 0.5),
    WorldBiome.peaks => Offset(w * 0.24, h * 0.24),
    WorldBiome.dunes => Offset(w * 0.5, h * 0.6),
    WorldBiome.alien => Offset(w * 0.74, h * 0.2),
    // The synthwave sun sinking behind the skyline.
    WorldBiome.city => Offset(w * 0.5, h * 0.56),
    WorldBiome.sakura => Offset(w * 0.78, h * 0.17),
    // Sunlight seen from under the surface.
    WorldBiome.reef => Offset(w * 0.5, -h * 0.02),
    WorldBiome.doodle => Offset(w * 0.84, h * 0.13),
    // A huge red sun setting behind the mountains.
    WorldBiome.dojo => Offset(w * 0.62, h * 0.5),
    // A sick green moon over the graveyard.
    WorldBiome.zombie => Offset(w * 0.74, h * 0.15),
    // The light everything pours from, high in the middle.
    WorldBiome.heaven => Offset(w * 0.5, h * 0.1),
    // A blood-red moon through the smoke.
    WorldBiome.hell => Offset(w * 0.78, h * 0.15),
    // A giant vinyl record turning over the stage.
    WorldBiome.music => Offset(w * 0.74, h * 0.15),
    // A huge harvest moon over the hollow.
    WorldBiome.halloween => Offset(w * 0.32, h * 0.2),
    // A low, warm sun setting behind the party island.
    WorldBiome.birthday => Offset(w * 0.5, h * 0.66),
  };
}

class _SkyPainter extends CustomPainter {
  const _SkyPainter(this.style);

  final WorldStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: _skyStops,
          colors: style.sky,
        ).createShader(rect),
    );

    _ellipticalGlow(
      canvas,
      Offset(w * 0.5, h * 0.8),
      radius: w * 0.9,
      squash: 0.4,
      color: style.horizonGlow,
    );

    final anchor = _celestialAnchor(style, size);
    switch (style.celestial) {
      case CelestialKind.ringedPlanet:
        _paintPlanet(canvas, anchor, w * 0.17);
        _paintMoon(canvas, Offset(w * 0.14, h * 0.21), w * 0.028);
      case CelestialKind.sun:
        final big =
            style.biome == WorldBiome.dunes ||
            style.biome == WorldBiome.city ||
            style.biome == WorldBiome.reef ||
            style.biome == WorldBiome.dojo ||
            style.biome == WorldBiome.birthday;
        _paintSun(canvas, anchor, w * (big ? 0.2 : 0.1));
      case CelestialKind.moon:
        // The Music world's moon is a record and Halloween's a huge
        // harvest moon, both drawn with the scene.
        if (style.biome != WorldBiome.music &&
            style.biome != WorldBiome.halloween) {
          _paintMoon(canvas, anchor, w * 0.075);
        }
    }
  }

  void _ellipticalGlow(
    Canvas canvas,
    Offset center, {
    required double radius,
    required double squash,
    required Color color,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1, squash);
    final bounds = Rect.fromCircle(center: Offset.zero, radius: radius);
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color, _alpha(color, 0)],
        ).createShader(bounds),
    );
    canvas.restore();
  }

  void _paintPlanet(Canvas canvas, Offset c, double r) {
    final colors = style.celestialColors;
    final halo = Rect.fromCircle(center: c, radius: r * 1.9);
    canvas.drawCircle(
      c,
      r * 1.9,
      Paint()
        ..shader = RadialGradient(
          stops: const [0.45, 1.0],
          colors: [_alpha(colors[1], 0.33), _alpha(colors[1], 0)],
        ).createShader(halo),
    );

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-0.38);

    final ringRect = Rect.fromCenter(
      center: Offset.zero,
      width: r * 3.4,
      height: r * 0.85,
    );
    final innerRingRect = ringRect.deflate(r * 0.22);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.14
      ..shader = LinearGradient(
        colors: [
          _alpha(style.ringColors[0], 0),
          _alpha(style.ringColors[0], 0.8),
          _alpha(style.ringColors[1], 0.8),
          _alpha(style.ringColors[1], 0),
        ],
      ).createShader(ringRect);
    final innerRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.05
      ..color = const Color(0x55FFFFFF);

    // The far half of the rings passes behind the planet...
    canvas.drawArc(ringRect, math.pi, math.pi, false, ring);
    canvas.drawArc(innerRingRect, math.pi, math.pi, false, innerRing);

    final body = Rect.fromCircle(center: Offset.zero, radius: r);
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 1.1,
          stops: const [0.0, 0.4, 0.8, 1.0],
          colors: colors,
        ).createShader(body),
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(body));
    for (final (y, alpha) in const [(-0.35, 0.10), (0.05, 0.14), (0.42, 0.1)]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, r * y),
          width: r * 2.4,
          height: r * 0.18,
        ),
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }
    canvas.restore();

    // ...and the near half crosses in front of it.
    canvas.drawArc(ringRect, 0, math.pi, false, ring);
    canvas.drawArc(innerRingRect, 0, math.pi, false, innerRing);
    canvas.restore();
  }

  void _paintMoon(Canvas canvas, Offset c, double r) {
    final colors = style.celestial == CelestialKind.moon
        ? style.celestialColors
        : const [
            Colors.white,
            Color(0xFFE9E1FF),
            Color(0xFFB9A8F0),
            Color(0xFF8F7FD0),
          ];
    canvas.drawCircle(
      c,
      r * 3.2,
      Paint()
        ..shader = RadialGradient(
          colors: [_alpha(colors[1], 0.3), _alpha(colors[1], 0)],
        ).createShader(Rect.fromCircle(center: c, radius: r * 3.2)),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.3),
          stops: const [0.0, 0.55, 0.85, 1.0],
          colors: colors,
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // A few soft craters.
    final crater = Paint()..color = _alpha(colors[3], 0.25);
    canvas.drawCircle(c.translate(r * 0.3, r * 0.15), r * 0.18, crater);
    canvas.drawCircle(c.translate(-r * 0.25, r * 0.35), r * 0.12, crater);
    canvas.drawCircle(c.translate(r * 0.05, -r * 0.4), r * 0.1, crater);
  }

  void _paintSun(Canvas canvas, Offset c, double r) {
    final colors = style.celestialColors;
    for (final (scale, alpha) in const [(3.4, 0.12), (2.3, 0.2), (1.5, 0.3)]) {
      canvas.drawCircle(
        c,
        r * scale,
        Paint()
          ..shader = RadialGradient(
            colors: [_alpha(colors[1], alpha), _alpha(colors[1], 0)],
          ).createShader(Rect.fromCircle(center: c, radius: r * scale)),
      );
    }
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.2),
          stops: const [0.0, 0.5, 0.85, 1.0],
          colors: colors,
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  bool shouldRepaint(covariant _SkyPainter oldDelegate) =>
      oldDelegate.style != style;
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.clock, this.style, {this.origin}) : super(repaint: clock);

  final ValueListenable<double> clock;
  final WorldStyle style;
  final Offset Function()? origin;

  static const _starCount = 70;

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value;
    _stars(canvas, size, t);
    _shootingStar(canvas, size, t);
    _aurora(canvas, size, t);
    switch (style.biome) {
      case WorldBiome.islands:
        _islandsBiome(canvas, size, t);
      case WorldBiome.ocean:
        _oceanBiome(canvas, size, t);
      case WorldBiome.peaks:
        _peaksBiome(canvas, size, t);
      case WorldBiome.dunes:
        _dunesBiome(canvas, size, t);
      case WorldBiome.alien:
        _alienBiome(canvas, size, t);
      case WorldBiome.city:
        _cityBiome(canvas, size, t);
      case WorldBiome.sakura:
        _sakuraBiome(canvas, size, t);
      case WorldBiome.reef:
        _reefBiome(canvas, size, t);
      case WorldBiome.doodle:
        // Drawn by DoodleScenePainter instead.
        break;
      case WorldBiome.dojo:
        _dojoBiome(canvas, size, t);
      case WorldBiome.zombie:
        paintZombieScene(
          canvas,
          size,
          t,
          style,
          moon: _celestialAnchor(style, size),
        );
      case WorldBiome.heaven:
        paintHeavenScene(
          canvas,
          size,
          t,
          style,
          sun: _celestialAnchor(style, size),
        );
      case WorldBiome.hell:
        paintHellScene(
          canvas,
          size,
          t,
          style,
          moon: _celestialAnchor(style, size),
        );
      case WorldBiome.music:
        paintMusicScene(
          canvas,
          size,
          t,
          style,
          moon: _celestialAnchor(style, size),
        );
      case WorldBiome.halloween:
        paintHalloweenScene(
          canvas,
          size,
          t,
          style,
          moon: _celestialAnchor(style, size),
        );
      case WorldBiome.birthday:
        paintBirthdayScene(
          canvas,
          size,
          t,
          style,
          sun: _celestialAnchor(style, size),
        );
    }
  }

  // ── Sky, shared by every biome ──────────────────────────────────────────

  void _stars(Canvas canvas, Size size, double t) {
    final count = (_starCount * style.starDensity).round();
    final dot = Paint();
    final glint = Paint()..strokeWidth = 0.8;
    for (var i = 0; i < count; i++) {
      final p = Offset(
        _rand(i, 1) * size.width,
        math.pow(_rand(i, 2), 1.5) * size.height * 0.6,
      );
      final r = 0.5 + _rand(i, 3) * 1.3;
      final twinkle =
          0.5 +
          0.5 * math.sin(t * (0.8 + _rand(i, 4) * 2.2) + _rand(i, 5) * 6.28);
      final alpha = 0.25 + 0.7 * twinkle;
      dot.color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(p, r, dot);
      // Every ninth star is a bright one with a four-point glint.
      if (i % 9 == 0) {
        final len = r * 4.5 * twinkle;
        glint.color = Colors.white.withValues(alpha: alpha * 0.7);
        canvas.drawLine(p.translate(-len, 0), p.translate(len, 0), glint);
        canvas.drawLine(p.translate(0, -len), p.translate(0, len), glint);
      }
    }
  }

  void _shootingStar(Canvas canvas, Size size, double t) {
    if (style.starDensity < 0.3) return;
    const period = 7.0;
    const duration = 1.1;
    final k = (t / period).floor();
    final local = t - k * period;
    if (local > duration) return;

    final p = local / duration;
    final fade = math.sin(p * math.pi);
    final start = Offset(
      size.width * (0.35 + _rand(k, 7) * 0.6),
      size.height * (0.03 + _rand(k, 8) * 0.2),
    );
    const dir = Offset(-0.86, 0.5);
    final head = start + dir * (size.width * 0.55 * Curves.easeIn.transform(p));
    final tail = head - dir * (10 + 70 * fade);

    canvas.drawLine(
      tail,
      head,
      Paint()
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(tail, head, [
          const Color(0x00FFFFFF),
          Colors.white.withValues(alpha: fade),
        ]),
    );
    canvas.drawCircle(
      head,
      6,
      Paint()..color = const Color(0xFFBFE9FF).withValues(alpha: 0.25 * fade),
    );
    canvas.drawCircle(
      head,
      1.8,
      Paint()..color = Colors.white.withValues(alpha: fade),
    );
  }

  void _aurora(Canvas canvas, Size size, double t) {
    final strength = style.starDensity.clamp(0.4, 1.0);
    _ribbon(
      canvas,
      size,
      t,
      baseY: size.height * 0.17,
      amp: size.height * 0.03,
      height: size.height * 0.12,
      speed: 0.25,
      phase: 0,
      glow: style.aurora[0],
      strength: strength,
    );
    _ribbon(
      canvas,
      size,
      t,
      baseY: size.height * 0.28,
      amp: size.height * 0.035,
      height: size.height * 0.1,
      speed: -0.18,
      phase: 2,
      glow: style.aurora[1],
      strength: strength,
    );
  }

  /// An aurora curtain: bright along its wavy lower edge, fading upward.
  void _ribbon(
    Canvas canvas,
    Size size,
    double t, {
    required double baseY,
    required double amp,
    required double height,
    required double speed,
    required double phase,
    required Color glow,
    required double strength,
  }) {
    const steps = 28;
    final lower = <Offset>[];
    final upper = <Offset>[];
    for (var s = 0; s <= steps; s++) {
      final u = s / steps;
      final y =
          baseY +
          amp * math.sin(u * 5 + t * speed + phase) +
          amp * 0.5 * math.sin(u * 11 - t * speed * 1.7 + phase);
      final curtain =
          height * (0.55 + 0.45 * math.sin(u * 7 + t * speed * 1.3 + phase));
      lower.add(Offset(size.width * u, y));
      upper.add(Offset(size.width * u, y - curtain));
    }
    final band = Path()..addPolygon([...lower, ...upper.reversed], true);
    canvas.drawPath(
      band,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, baseY + amp * 1.5),
          Offset(0, baseY - amp - height),
          [_alpha(glow, 0.28 * strength), _alpha(glow, 0)],
        ),
    );
    canvas.drawPath(
      Path()..addPolygon(lower, false),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = _alpha(glow, 0.35 * strength),
    );
  }

  void _cloud(
    Canvas canvas,
    Size size,
    double t, {
    required double y,
    required double scale,
    required double speed,
    required double offset,
  }) {
    final width = 100 * scale;
    final span = size.width + width * 2;
    final x = (t * speed + offset * span) % span - width;
    final base = Offset(x, y + math.sin(t * 0.4 + offset * 6) * 4);
    Rect puff(double dx, double dy, double r) => Rect.fromCircle(
      center: base.translate(dx * scale, dy * scale),
      radius: r * scale,
    );
    // Overlapping ovals in one path fill as a single union, so the
    // translucent cloud has no darker seams where its puffs overlap.
    final cloud = Path()
      ..addOval(puff(0, 0, 20))
      ..addOval(puff(26, -12, 27))
      ..addOval(puff(56, -4, 23))
      ..addOval(puff(80, 4, 15))
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            base.dx - 8 * scale,
            base.dy,
            base.dx + 90 * scale,
            base.dy + 18 * scale,
          ),
          Radius.circular(9 * scale),
        ),
      );
    canvas.drawPath(
      cloud,
      Paint()
        ..shader = ui.Gradient.linear(
          base.translate(0, -40 * scale),
          base.translate(0, 18 * scale),
          [_alpha(style.cloudLight, 0.6), _alpha(style.cloudShade, 0.33)],
        ),
    );
  }

  void _sparkles(Canvas canvas, Size size, double t, {int count = 20}) {
    final glow = Paint();
    for (var i = 0; i < count; i++) {
      final life = (t * (0.035 + _rand(i, 11) * 0.04) + _rand(i, 12)) % 1.0;
      final p = Offset(
        _rand(i, 13) * size.width + math.sin(t * (0.6 + _rand(i, 14)) + i) * 16,
        size.height * (1.02 - life * 1.04),
      );
      final flicker = 0.55 + 0.45 * math.sin(t * (2 + _rand(i, 15) * 3) + i);
      final alpha = math.sin(life * math.pi) * flicker;
      final tint = style.sparkles[i % style.sparkles.length];
      glow.color = _alpha(tint, 0.12 * alpha);
      canvas.drawCircle(p, 7, glow);
      glow.color = _alpha(tint, 0.3 * alpha);
      canvas.drawCircle(p, 3.2, glow);
      glow.color = Colors.white.withValues(alpha: 0.9 * alpha);
      canvas.drawCircle(p, 1.3, glow);
    }
  }

  void _birds(Canvas canvas, Size size, double t) {
    final wing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = _alpha(style.rock[2], 0.75);
    for (var i = 0; i < 3; i++) {
      final speed = 14 + i * 4.0;
      final span = size.width + 80;
      final x = (t * speed + _rand(i, 30) * span) % span - 40;
      final y =
          size.height * (0.2 + 0.12 * _rand(i, 31)) +
          math.sin(t * 0.7 + i) * 10;
      final flap = math.sin(t * 7 + i * 2);
      final span2 = 7 + i * 1.5;
      final path = Path()
        ..moveTo(x - span2, y - flap * 4)
        ..quadraticBezierTo(x - span2 * 0.4, y - 3 - flap * 2, x, y)
        ..quadraticBezierTo(
          x + span2 * 0.4,
          y - 3 - flap * 2,
          x + span2,
          y - flap * 4,
        );
      canvas.drawPath(path, wing);
    }
  }

  // ── Islands ─────────────────────────────────────────────────────────────

  void _islandsBiome(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;
    // Back to front: a hazy distant island, two clouds, the two near
    // islands, one cloud drifting in front of them, then the cloud sea.
    _island(
      canvas,
      Offset(w * 0.56, h * 0.46),
      w * 0.15,
      t,
      phase: 2.1,
      haze: 0.55,
      tree: true,
    );
    _cloud(canvas, size, t, y: h * 0.36, scale: 0.75, speed: 6, offset: 0.1);
    _cloud(canvas, size, t, y: h * 0.52, scale: 1.0, speed: 9, offset: 0.62);
    _island(
      canvas,
      Offset(w * 0.2, h * 0.6),
      w * 0.38,
      t,
      phase: 0,
      tree: true,
      waterfall: true,
    );
    _island(
      canvas,
      Offset(w * 0.84, h * 0.71),
      w * 0.3,
      t,
      phase: 1.3,
      crystal: true,
    );
    _cloud(canvas, size, t, y: h * 0.67, scale: 0.9, speed: 13, offset: 0.35);
    _layerRows(canvas, size, t);
    _sparkles(canvas, size, t);
  }

  void _island(
    Canvas canvas,
    Offset anchor,
    double width,
    double t, {
    required double phase,
    double haze = 0,
    bool tree = false,
    bool crystal = false,
    bool waterfall = false,
  }) {
    Color hz(Color color) => _mix(color, style.haze, haze);
    final fade = 1 - haze;
    final w = width;
    final c = anchor.translate(0, math.sin(t * 0.55 + phase) * w * 0.035);

    // Soft levitation glow under the rock.
    final glowCenter = c.translate(0, w * 0.42);
    final pulse = 0.75 + 0.25 * math.sin(t * 1.3 + phase);
    canvas.drawCircle(
      glowCenter,
      w * 0.45,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _alpha(style.land[1], 0.2 * fade * pulse),
            _alpha(style.land[1], 0),
          ],
        ).createShader(Rect.fromCircle(center: glowCenter, radius: w * 0.45)),
    );

    // Rocky underside, tapering to a point.
    final left = c.translate(-w / 2, 0);
    final right = c.translate(w / 2, 0);
    final tip = c.translate(w * 0.04, w * 0.6);
    final rock = Path()
      ..moveTo(left.dx, left.dy)
      ..cubicTo(
        left.dx + w * 0.06,
        c.dy + w * 0.22,
        c.dx - w * 0.2,
        c.dy + w * 0.42,
        tip.dx,
        tip.dy,
      )
      ..cubicTo(
        c.dx + w * 0.18,
        c.dy + w * 0.4,
        right.dx - w * 0.05,
        c.dy + w * 0.2,
        right.dx,
        right.dy,
      )
      ..close();
    final rockBounds = Rect.fromLTRB(left.dx, c.dy, right.dx, tip.dy);
    canvas.drawPath(
      rock,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [hz(style.rock[0]), hz(style.rock[1]), hz(style.rock[2])],
        ).createShader(rockBounds),
    );
    // Lit from the upper left.
    canvas.drawPath(
      rock,
      Paint()
        ..shader = LinearGradient(
          stops: const [0.0, 0.45, 1.0],
          colors: [
            Colors.white.withValues(alpha: 0.1 * fade),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.28),
          ],
        ).createShader(rockBounds),
    );
    canvas.save();
    canvas.clipPath(rock);
    final strata = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.012
      ..color = Colors.black.withValues(alpha: 0.18);
    for (final depth in const [0.2, 0.38]) {
      final y = c.dy + w * depth;
      canvas.drawPath(
        Path()
          ..moveTo(left.dx, y)
          ..quadraticBezierTo(c.dx, y + w * 0.06, right.dx, y - w * 0.02),
        strata,
      );
    }
    canvas.restore();

    // A couple of pebbles hanging loose beneath, drifting on their own.
    final pebble = Paint()..color = hz(style.rock[1]);
    for (var i = 0; i < 2; i++) {
      final p = tip.translate(
        i == 0 ? -w * 0.12 : w * 0.1,
        w * (0.1 + i * 0.06) + math.sin(t * 0.9 + phase + i) * w * 0.02,
      );
      canvas.drawOval(
        Rect.fromCenter(center: p, width: w * 0.06, height: w * 0.07),
        pebble,
      );
    }

    // Grassy top, with a darker lip underneath for thickness.
    final cap = Rect.fromCenter(center: c, width: w * 1.04, height: w * 0.2);
    canvas.drawOval(
      cap.shift(Offset(0, w * 0.035)),
      Paint()..color = hz(_ColorMath.darken(style.land[2], 0.08)),
    );
    canvas.drawOval(
      cap,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [hz(style.land[0]), hz(style.land[1]), hz(style.land[2])],
        ).createShader(cap),
    );
    canvas.drawArc(
      cap.deflate(w * 0.02),
      math.pi * 1.1,
      math.pi * 0.8,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.012
        ..color = Colors.white.withValues(alpha: 0.35 * fade),
    );

    if (waterfall) {
      _waterfall(canvas, c.translate(w * 0.36, w * 0.05), w, t);
    }
    if (tree) {
      _tree(canvas, c.translate(-w * 0.18, -w * 0.02), w * 0.22, t, phase, hz);
    }
    if (crystal) {
      _crystal(canvas, c.translate(w * 0.12, -w * 0.1), w * 0.12, t, phase);
    }
  }

  void _waterfall(Canvas canvas, Offset top, double w, double t) {
    final length = w * 0.95;
    final bandWidth = w * 0.07;
    final band = Rect.fromLTWH(
      top.dx - bandWidth / 2,
      top.dy,
      bandWidth,
      length,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(band, Radius.circular(bandWidth / 2)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC9FE8FF), Color(0x005AB8FF)],
        ).createShader(band),
    );
    // Streaks of water sliding down the fall.
    final streak = Paint()
      ..strokeWidth = bandWidth * 0.22
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < 4; k++) {
      final p = (t * 0.9 + k / 4) % 1.0;
      final x = top.dx + (k.isEven ? -bandWidth * 0.18 : bandWidth * 0.18);
      final y = top.dy + p * length;
      streak.color = Colors.white.withValues(alpha: (1 - p) * 0.7);
      canvas.drawLine(Offset(x, y), Offset(x, y + length * 0.12), streak);
    }
    // Mist where it thins out.
    final mist = Paint();
    for (var k = 0; k < 3; k++) {
      final p = (t * 0.5 + k / 3) % 1.0;
      mist.color = Colors.white.withValues(alpha: 0.12 * (1 - p));
      canvas.drawCircle(
        Offset(
          top.dx + (k - 1) * bandWidth * 0.8,
          top.dy + length * 0.92 - p * bandWidth,
        ),
        bandWidth * (0.6 + p),
        mist,
      );
    }
  }

  void _tree(
    Canvas canvas,
    Offset base,
    double s,
    double t,
    double phase,
    Color Function(Color) hz,
  ) {
    final sway = math.sin(t * 1.1 + phase) * s * 0.06;
    final trunk = Path()
      ..moveTo(base.dx - s * 0.07, base.dy)
      ..quadraticBezierTo(
        base.dx - s * 0.02 + sway * 0.3,
        base.dy - s * 0.4,
        base.dx + sway * 0.5,
        base.dy - s * 0.65,
      )
      ..lineTo(base.dx + s * 0.05 + sway * 0.5, base.dy - s * 0.62)
      ..quadraticBezierTo(
        base.dx + s * 0.06,
        base.dy - s * 0.35,
        base.dx + s * 0.08,
        base.dy,
      )
      ..close();
    canvas.drawPath(trunk, Paint()..color = hz(style.rock[1]));

    final top = base.translate(sway, -s * 0.78);
    final canopy = Path()
      ..addOval(Rect.fromCircle(center: top, radius: s * 0.32))
      ..addOval(
        Rect.fromCircle(
          center: top.translate(-s * 0.26, s * 0.12),
          radius: s * 0.24,
        ),
      )
      ..addOval(
        Rect.fromCircle(
          center: top.translate(s * 0.26, s * 0.1),
          radius: s * 0.26,
        ),
      );
    canvas.drawPath(
      canopy,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.5),
          stops: const [0.0, 0.55, 1.0],
          colors: [
            hz(style.foliage[0]),
            hz(style.foliage[1]),
            hz(style.foliage[2]),
          ],
        ).createShader(Rect.fromCircle(center: top, radius: s * 0.5)),
    );
    canvas.drawCircle(
      top.translate(-s * 0.1, -s * 0.14),
      s * 0.08,
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
  }

  void _crystal(Canvas canvas, Offset c, double s, double t, double phase) {
    final center = c.translate(
      0,
      math.sin(t * 1.6 + phase) * s * 0.15 - s * 0.4,
    );
    // Squeezing the width with cos() reads as the gem turning in place.
    final halfWidth =
        s * 0.32 * (0.35 + 0.65 * math.cos(t * 0.9 + phase).abs());
    final pulse = 0.7 + 0.3 * math.sin(t * 2 + phase);

    canvas.drawCircle(
      center,
      s * 1.1,
      Paint()
        ..shader = RadialGradient(
          colors: [_alpha(style.glow, 0.35 * pulse), _alpha(style.glow, 0)],
        ).createShader(Rect.fromCircle(center: center, radius: s * 1.1)),
    );
    final gem = Path()
      ..moveTo(center.dx, center.dy - s * 0.6)
      ..lineTo(center.dx + halfWidth, center.dy)
      ..lineTo(center.dx, center.dy + s * 0.5)
      ..lineTo(center.dx - halfWidth, center.dy)
      ..close();
    canvas.drawPath(
      gem,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _mix(style.glow, Colors.white, 0.75),
            style.glow,
            _ColorMath.darken(style.glow, 0.2),
          ],
        ).createShader(gem.getBounds()),
    );
    canvas.drawLine(
      center.translate(0, -s * 0.6),
      center.translate(0, s * 0.5),
      Paint()
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.5),
    );
  }

  /// The cloud sea along the bottom: three rows of puffs, back to front.
  void _layerRows(Canvas canvas, Size size, double t) {
    final h = size.height;
    const baselines = [0.86, 0.9, 0.95];
    const puffs = [34.0, 30.0, 26.0];
    const speeds = [5.0, 9.0, 14.0];
    for (var i = 0; i < 3; i++) {
      _cloudRow(
        canvas,
        size,
        t,
        baseline: h * baselines[i],
        puff: puffs[i],
        speed: speeds[i],
        seed: i + 1,
        colors: [style.layers[i].$1, style.layers[i].$2],
      );
    }
  }

  /// One endless row of puffs scrolling sideways. Each puff's size comes
  /// from its position in the world rather than on screen, so puffs keep
  /// their shape as they scroll instead of resizing when the row wraps.
  void _cloudRow(
    Canvas canvas,
    Size size,
    double t, {
    required double baseline,
    required double puff,
    required double speed,
    required int seed,
    required List<Color> colors,
  }) {
    final spacing = puff * 1.25;
    final travelled = t * speed;
    final wrapped = (travelled / spacing).floor();
    final shift = travelled - wrapped * spacing;
    final top = baseline + math.sin(t * 0.5 + seed) * 3;

    final row = Path()..addRect(Rect.fromLTRB(0, top, size.width, size.height));
    final count = (size.width / spacing).ceil() + 2;
    for (var i = -1; i < count; i++) {
      final r = puff * (0.7 + 0.5 * _rand(i - wrapped, seed));
      row.addOval(
        Rect.fromCircle(
          center: Offset(i * spacing + shift, top + r * 0.35),
          radius: r,
        ),
      );
    }
    canvas.drawPath(
      row,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, baseline - puff),
          Offset(0, size.height),
          colors,
        ),
    );
  }

  // ── Ocean ───────────────────────────────────────────────────────────────

  void _oceanBiome(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;
    final horizon = h * 0.6;

    _cloud(canvas, size, t, y: h * 0.32, scale: 0.8, speed: 5, offset: 0.2);
    _cloud(canvas, size, t, y: h * 0.45, scale: 1.1, speed: 8, offset: 0.7);
    // A small floating isle far out, spilling a waterfall into the sea.
    _island(
      canvas,
      Offset(w * 0.22, horizon - h * 0.09),
      w * 0.17,
      t,
      phase: 0.8,
      haze: 0.45,
      tree: true,
      waterfall: true,
    );
    _birds(canvas, size, t);

    final sea = Rect.fromLTRB(0, horizon, w, h);
    canvas.drawRect(
      sea,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [style.layers[0].$1, style.layers[1].$2, style.layers[2].$2],
        ).createShader(sea),
    );
    // Haze where the sea meets the sky.
    canvas.drawRect(
      Rect.fromLTRB(0, horizon - 2, w, horizon + h * 0.03),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_alpha(style.sky[5], 0.7), _alpha(style.sky[5], 0)],
        ).createShader(Rect.fromLTRB(0, horizon - 2, w, horizon + h * 0.03)),
    );

    // Glittering reflection under the sun or moon.
    final light = _celestialAnchor(style, size);
    final glitter = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < 26; i++) {
      final depth = i / 26;
      final y = horizon + (h - horizon) * depth * depth + 4;
      final shimmer = math.sin(t * 2.2 + i * 1.7);
      final width = (8 + depth * 46) * (0.55 + 0.45 * shimmer.abs());
      glitter
        ..strokeWidth = 1.2 + depth * 2
        ..color = _alpha(style.celestialColors[0], 0.55 * (1 - depth * 0.7));
      final x = light.dx + math.sin(t * 0.8 + i) * depth * 10;
      canvas.drawLine(
        Offset(x - width / 2, y),
        Offset(x + width / 2, y),
        glitter,
      );
    }

    // Swells rolling in, bigger toward the viewer.
    for (var i = 0; i < 6; i++) {
      final depth = (i + 1) / 6;
      final y = horizon + (h - horizon) * depth * depth;
      final amp = 2 + depth * 9;
      final wavelength = 60 + depth * 120;
      final speed = 6 + depth * 18;
      final pair = style.layers[math.min(2, i ~/ 2)];
      final path = Path()..moveTo(0, h);
      for (var x = 0.0; x <= w + 8; x += 8) {
        path.lineTo(
          x,
          y + amp * math.sin((x + t * speed) / wavelength * 2 * math.pi + i),
        );
      }
      path
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, y - amp), Offset(0, h), [
            _alpha(pair.$1, 0.75),
            _alpha(pair.$2, 0.9),
          ]),
      );
      // Foam catching the light along each crest.
      final crest = Path();
      for (var x = 0.0; x <= w + 8; x += 8) {
        final cy =
            y + amp * math.sin((x + t * speed) / wavelength * 2 * math.pi + i);
        if (x == 0) {
          crest.moveTo(x, cy);
        } else {
          crest.lineTo(x, cy);
        }
      }
      canvas.drawPath(
        crest,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 + depth
          ..color = _alpha(style.cloudLight, 0.18 + 0.14 * depth),
      );
    }
    _sparkles(canvas, size, t, count: 12);
  }

  // ── Peaks ───────────────────────────────────────────────────────────────

  void _peaksBiome(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;
    _cloud(canvas, size, t, y: h * 0.3, scale: 0.8, speed: 6, offset: 0.4);
    _birds(canvas, size, t);
    _balloon(canvas, size, t);

    const baselines = [0.62, 0.76, 0.9];
    const heights = [0.3, 0.2, 0.12];
    for (var i = 0; i < 3; i++) {
      final base = h * baselines[i];
      // The far range is sharp and craggy; nearer ones roll into hills.
      final ridge = _ridge(
        w,
        base,
        h * heights[i],
        seed: i * 17 + 3,
        sharp: i < 2,
      );
      final fill = Path()
        ..addPolygon([...ridge, Offset(w, h), Offset(0, h)], true);
      final pair = style.layers[i];
      final top = base - h * heights[i];
      canvas.drawPath(
        fill,
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, top), Offset(0, h), [
            _mix(pair.$1, style.haze, i == 0 ? 0.35 : 0),
            pair.$2,
          ]),
      );
      if (i < 2) _litFacets(canvas, ridge, base, h);
      if (i == 0) _snowcaps(canvas, ridge, base - h * heights[i] * 0.55);
      // Mist pooling in front of each range.
      final mistY = base + h * 0.02;
      final mistRect = Rect.fromLTRB(0, mistY - h * 0.05, w, mistY + h * 0.04);
      canvas.drawRect(
        mistRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _alpha(style.cloudLight, 0),
              _alpha(style.cloudLight, 0.14 + 0.04 * math.sin(t * 0.6 + i)),
              _alpha(style.cloudLight, 0),
            ],
          ).createShader(mistRect),
      );
      if (i == 0) {
        _island(
          canvas,
          Offset(w * 0.78, h * 0.42),
          w * 0.22,
          t,
          phase: 1.1,
          crystal: true,
          waterfall: true,
        );
      }
      if (i == 1) {
        _island(
          canvas,
          Offset(w * 0.2, h * 0.58),
          w * 0.2,
          t,
          phase: 2.4,
          tree: true,
        );
      }
    }
    _sparkles(canvas, size, t, count: 14);
  }

  /// A mountain ridgeline across the full width: "ridged" sine noise for
  /// sharp peaks of uneven height, or smooth sines for rolling hills.
  List<Offset> _ridge(
    double width,
    double base,
    double height, {
    required int seed,
    required bool sharp,
  }) {
    final freqs = [
      1.1 + _rand(seed, 1) * 0.6,
      2.3 + _rand(seed, 2),
      5.0 + _rand(seed, 3) * 2,
    ];
    final phases = [_rand(seed, 4), _rand(seed, 5), _rand(seed, 6)];
    const amps = [0.62, 0.28, 0.1];
    final points = <Offset>[Offset(0, base)];
    const steps = 48;
    for (var s = 0; s <= steps; s++) {
      final u = s / steps;
      var y = 0.0;
      for (var k = 0; k < 3; k++) {
        final x = u * freqs[k] + phases[k];
        final v = sharp
            ? math.pow(1 - math.cos(math.pi * x).abs(), 1.5).toDouble()
            : 0.5 + 0.5 * math.sin(2 * math.pi * x);
        y += amps[k] * v;
      }
      points.add(Offset(width * u, base - height * y.clamp(0.0, 1.0)));
    }
    points.add(Offset(width, base));
    return points;
  }

  /// Brightens every slope that faces the light (rising left to right), so
  /// the range reads as faceted rock rather than a flat cut-out.
  void _litFacets(Canvas canvas, List<Offset> ridge, double base, double h) {
    final lit = Path();
    for (var i = 1; i < ridge.length - 2; i++) {
      final a = ridge[i];
      final b = ridge[i + 1];
      if (b.dy < a.dy) {
        lit.addPolygon([
          a,
          b,
          Offset(b.dx, base + h * 0.04),
          Offset(a.dx, base + h * 0.04),
        ], true);
      }
    }
    canvas.drawPath(
      lit,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, base - h * 0.3),
          Offset(0, base),
          [
            Colors.white.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0),
          ],
        ),
    );
  }

  void _snowcaps(Canvas canvas, List<Offset> ridge, double snowline) {
    final cap = Path();
    var open = false;
    for (final p in ridge) {
      if (p.dy < snowline) {
        if (!open) {
          cap.moveTo(p.dx, snowline);
          open = true;
        }
        cap.lineTo(p.dx, p.dy);
      } else if (open) {
        cap.lineTo(p.dx, snowline);
        cap.close();
        open = false;
      }
    }
    canvas.drawPath(
      cap,
      Paint()..color = _alpha(_mix(style.land[0], style.haze, 0.25), 0.9),
    );
  }

  void _balloon(Canvas canvas, Size size, double t) {
    final span = size.width + 120;
    final x = (t * 7 + span * 0.3) % span - 60;
    final y = size.height * 0.36 + math.sin(t * 0.5) * 14;
    final c = Offset(x, y);
    const r = 22.0;
    // Envelope: a rounded teardrop.
    final envelope = Path()
      ..moveTo(c.dx, c.dy + r * 1.25)
      ..cubicTo(
        c.dx - r * 0.35,
        c.dy + r * 0.9,
        c.dx - r * 1.05,
        c.dy + r * 0.3,
        c.dx - r,
        c.dy - r * 0.2,
      )
      ..cubicTo(
        c.dx - r * 0.95,
        c.dy - r * 1.25,
        c.dx + r * 0.95,
        c.dy - r * 1.25,
        c.dx + r,
        c.dy - r * 0.2,
      )
      ..cubicTo(
        c.dx + r * 1.05,
        c.dy + r * 0.3,
        c.dx + r * 0.35,
        c.dy + r * 0.9,
        c.dx,
        c.dy + r * 1.25,
      )
      ..close();
    final bounds = envelope.getBounds();
    canvas.drawPath(
      envelope,
      Paint()
        ..shader = LinearGradient(
          colors: [
            _mix(style.glow, Colors.white, 0.3),
            style.glow,
            _ColorMath.darken(style.glow, 0.25),
          ],
        ).createShader(bounds),
    );
    // Stripes.
    canvas.save();
    canvas.clipPath(envelope);
    final stripe = Paint()..color = _alpha(style.foliage[1], 0.85);
    for (final dx in const [-0.55, 0.0, 0.55]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(dx * r, -r * 0.1),
          width: r * 0.28,
          height: r * 2.8,
        ),
        stripe,
      );
    }
    canvas.restore();
    canvas.drawCircle(
      c.translate(-r * 0.4, -r * 0.55),
      r * 0.16,
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );
    // Ropes, basket and a flickering flame.
    final rope = Paint()
      ..strokeWidth = 1
      ..color = _alpha(style.rock[2], 0.8);
    final basketTop = c.dy + r * 1.75;
    canvas.drawLine(
      c.translate(-r * 0.3, r * 1.15),
      Offset(c.dx - r * 0.25, basketTop),
      rope,
    );
    canvas.drawLine(
      c.translate(r * 0.3, r * 1.15),
      Offset(c.dx + r * 0.25, basketTop),
      rope,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(c.dx - r * 0.3, basketTop, r * 0.6, r * 0.42),
        const Radius.circular(2),
      ),
      Paint()..color = style.rock[1],
    );
    final flicker = 0.7 + 0.3 * math.sin(t * 13);
    canvas.drawCircle(
      c.translate(0, r * 1.4),
      r * 0.28 * flicker,
      Paint()..color = _alpha(style.glow, 0.6),
    );
  }

  // ── Dunes ───────────────────────────────────────────────────────────────

  void _dunesBiome(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;
    // Thin clouds streaking across the sun.
    for (var i = 0; i < 3; i++) {
      final y = h * (0.5 + i * 0.035);
      final drift = (t * (6 + i * 3) + i * 120) % (w + 200) - 100;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(drift, y, w * (0.35 + 0.1 * i), 5 + i * 1.5),
          const Radius.circular(4),
        ),
        Paint()..color = _alpha(style.cloudLight, 0.35),
      );
    }
    _lanterns(canvas, size, t, far: true);

    const baselines = [0.68, 0.79, 0.9];
    for (var i = 0; i < 3; i++) {
      final base = h * baselines[i];
      final path = Path()..moveTo(0, h);
      final crest = Path();
      for (var x = 0.0; x <= w + 6; x += 6) {
        final y =
            base -
            h * 0.04 * math.sin(x / w * math.pi * (1.2 + i * 0.5) + i * 1.7) -
            h * 0.006 * math.sin(x / w * math.pi * 3 + i);
        path.lineTo(x, y);
        if (x == 0) {
          crest.moveTo(x, y);
        } else {
          crest.lineTo(x, y);
        }
      }
      path
        ..lineTo(w, h)
        ..close();
      final pair = style.layers[i];
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, base - h * 0.05),
            Offset(0, h),
            [pair.$1, pair.$2],
          ),
      );
      canvas.drawPath(
        crest,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = _alpha(style.land[0], 0.35),
      );
    }

    // Sand blowing off the front dune.
    final grain = Paint();
    for (var i = 0; i < 24; i++) {
      final life = (t * (0.12 + _rand(i, 40) * 0.1) + _rand(i, 41)) % 1.0;
      final p = Offset(
        w * life * 1.2 - w * 0.1,
        h * (0.86 + _rand(i, 42) * 0.08) - math.sin(life * math.pi) * 18,
      );
      grain.color = _alpha(style.land[0], 0.5 * math.sin(life * math.pi));
      canvas.drawCircle(p, 1 + _rand(i, 43), grain);
    }
    _lanterns(canvas, size, t, far: false);
  }

  /// Paper sky lanterns floating up. The far set is smaller and fainter.
  void _lanterns(Canvas canvas, Size size, double t, {required bool far}) {
    final count = far ? 9 : 6;
    final salt = far ? 50 : 60;
    for (var i = 0; i < count; i++) {
      final life =
          (t * (0.02 + _rand(i, salt) * 0.02) + _rand(i, salt + 1)) % 1.0;
      final scale = far
          ? 0.55 + _rand(i, salt + 2) * 0.25
          : 0.9 + _rand(i, salt + 2) * 0.4;
      final x =
          _rand(i, salt + 3) * size.width +
          math.sin(t * 0.5 + i * 2) * 14 * scale;
      final y = size.height * (1.05 - life * 1.1);
      final alpha =
          math.min(1.0, math.sin(life * math.pi) * 1.6) * (far ? 0.6 : 0.95);
      final flicker = 0.85 + 0.15 * math.sin(t * 9 + i * 3);
      final c = Offset(x, y);
      final bw = 6.5 * scale;
      final bh = 9 * scale;

      canvas.drawCircle(
        c,
        bh * 2.2,
        Paint()
          ..shader = RadialGradient(
            colors: [
              _alpha(style.glow, 0.32 * alpha * flicker),
              _alpha(style.glow, 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: bh * 2.2)),
      );
      // Paper body: a rounded top, tapering to an open base.
      final body = Path()
        ..moveTo(c.dx - bw * 0.62, c.dy + bh * 0.7)
        ..quadraticBezierTo(
          c.dx - bw * 1.05,
          c.dy - bh * 0.1,
          c.dx - bw * 0.8,
          c.dy - bh * 0.62,
        )
        ..quadraticBezierTo(
          c.dx,
          c.dy - bh * 1.05,
          c.dx + bw * 0.8,
          c.dy - bh * 0.62,
        )
        ..quadraticBezierTo(
          c.dx + bw * 1.05,
          c.dy - bh * 0.1,
          c.dx + bw * 0.62,
          c.dy + bh * 0.7,
        )
        ..close();
      canvas.drawPath(
        body,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              _alpha(_mix(style.glow, Colors.white, 0.7), alpha * flicker),
              _alpha(style.glow, alpha),
              _alpha(_ColorMath.darken(style.glow, 0.22), alpha),
            ],
          ).createShader(body.getBounds()),
      );
      // Paper ribs and the flame glowing at the base.
      final rib = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = _alpha(_ColorMath.darken(style.glow, 0.3), 0.5 * alpha);
      canvas.drawLine(
        c.translate(0, -bh * 0.85),
        c.translate(0, bh * 0.7),
        rib,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(0, bh * 0.62),
          width: bw * 0.7,
          height: bh * 0.28,
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.85 * alpha * flicker),
      );
    }
  }

  // ── Alien ───────────────────────────────────────────────────────────────

  void _alienBiome(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;
    _cloud(canvas, size, t, y: h * 0.32, scale: 0.7, speed: 5, offset: 0.3);
    _ufo(canvas, size, t);
    _jellies(canvas, size, t, count: 3, far: true);

    const baselines = [0.64, 0.77, 0.9];
    const heights = [0.12, 0.08, 0.06];
    for (var i = 0; i < 3; i++) {
      final base = h * baselines[i];
      final ridge = _ridge(
        w,
        base,
        h * heights[i],
        seed: i * 23 + 5,
        sharp: false,
      );
      final pair = style.layers[i];
      canvas.drawPath(
        Path()..addPolygon([...ridge, Offset(w, h), Offset(0, h)], true),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, base - h * heights[i]),
            Offset(0, h),
            [_mix(pair.$1, style.haze, i == 0 ? 0.3 : 0), pair.$2],
          ),
      );
      // Glowing pools in the hills.
      if (i == 1) {
        for (final x in const [0.32, 0.7]) {
          final c = Offset(w * x, base + h * 0.03);
          final pulse = 0.6 + 0.4 * math.sin(t * 1.4 + x * 9);
          canvas.drawOval(
            Rect.fromCenter(center: c, width: w * 0.16, height: h * 0.014),
            Paint()..color = _alpha(style.glow, 0.55 * pulse),
          );
        }
      }
      if (i == 0) {
        _crystal(canvas, Offset(w * 0.12, base - h * 0.02), w * 0.07, t, 0.7);
        _crystal(canvas, Offset(w * 0.9, base - h * 0.03), w * 0.09, t, 2.2);
      }
      if (i == 1) {
        _mushroom(canvas, Offset(w * 0.86, base + h * 0.01), w * 0.2, t, 1.3);
      }
      if (i == 2) {
        _mushroom(canvas, Offset(w * 0.14, base + h * 0.02), w * 0.26, t, 0);
        _mushroom(canvas, Offset(w * 0.32, base + h * 0.04), w * 0.12, t, 2.6);
      }
    }
    _jellies(canvas, size, t, count: 2, far: false);
    _sparkles(canvas, size, t, count: 26);
  }

  /// A giant glowing mushroom: a curving stem and a spotted cap that
  /// breathes light.
  void _mushroom(Canvas canvas, Offset base, double s, double t, double phase) {
    final sway = math.sin(t * 0.8 + phase) * s * 0.03;
    final top = base.translate(sway, -s * 0.85);
    final stem = Path()
      ..moveTo(base.dx - s * 0.09, base.dy)
      ..quadraticBezierTo(
        base.dx - s * 0.12,
        base.dy - s * 0.45,
        top.dx - s * 0.06,
        top.dy,
      )
      ..lineTo(top.dx + s * 0.06, top.dy)
      ..quadraticBezierTo(
        base.dx + s * 0.1,
        base.dy - s * 0.45,
        base.dx + s * 0.09,
        base.dy,
      )
      ..close();
    canvas.drawPath(
      stem,
      Paint()
        ..shader = ui.Gradient.linear(top, base, [
          style.land[0],
          style.land[2],
        ]),
    );
    final pulse = 0.65 + 0.35 * math.sin(t * 1.6 + phase);
    final capRect = Rect.fromCenter(
      center: top.translate(0, s * 0.02),
      width: s * 0.95,
      height: s * 0.62,
    );
    canvas.drawCircle(
      capRect.center,
      s * 0.75,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                _alpha(style.foliage[1], 0.35 * pulse),
                _alpha(style.foliage[1], 0),
              ],
            ).createShader(
              Rect.fromCircle(center: capRect.center, radius: s * 0.75),
            ),
    );
    final cap = Path()
      ..moveTo(capRect.left, capRect.center.dy)
      ..arcTo(capRect, math.pi, math.pi, false)
      ..quadraticBezierTo(
        capRect.center.dx,
        capRect.center.dy + s * 0.12,
        capRect.left,
        capRect.center.dy,
      )
      ..close();
    canvas.drawPath(
      cap,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.5),
          colors: [style.foliage[0], style.foliage[1], style.foliage[2]],
        ).createShader(capRect),
    );
    final spot = Paint()
      ..color = Colors.white.withValues(alpha: 0.55 + 0.3 * pulse);
    for (var i = 0; i < 5; i++) {
      final a = math.pi * (1.15 + i * 0.17);
      final p =
          capRect.center +
          Offset(math.cos(a) * s * 0.3, math.sin(a) * s * 0.18);
      canvas.drawCircle(p, s * (0.035 + 0.015 * (i % 2)), spot);
    }
  }

  /// Translucent jellyfish creatures drifting through the air.
  void _jellies(
    Canvas canvas,
    Size size,
    double t, {
    required int count,
    required bool far,
  }) {
    final salt = far ? 70 : 80;
    for (var i = 0; i < count; i++) {
      final s = size.width * (far ? 0.05 : 0.08) * (0.8 + _rand(i, salt) * 0.4);
      final span = size.width + s * 4;
      final x = (t * (far ? 4 : 7) + _rand(i, salt + 1) * span) % span - s * 2;
      final y =
          size.height * (far ? 0.38 : 0.55) * (0.8 + _rand(i, salt + 2) * 0.4) +
          math.sin(t * 0.9 + i * 2) * s * 0.6;
      _jellyfish(
        canvas,
        Offset(x, y),
        s,
        t,
        i * 1.7,
        style.sparkles[i % style.sparkles.length],
        far ? 0.5 : 0.8,
      );
    }
  }

  void _jellyfish(
    Canvas canvas,
    Offset c,
    double s,
    double t,
    double phase,
    Color tint,
    double alpha,
  ) {
    final pulse = math.sin(t * 2.2 + phase);
    final bell = Rect.fromCenter(
      center: c,
      width: s * (1 + 0.08 * pulse),
      height: s * (0.75 - 0.06 * pulse),
    );
    canvas.drawCircle(
      c,
      s * 1.1,
      Paint()
        ..shader = RadialGradient(
          colors: [_alpha(tint, 0.25 * alpha), _alpha(tint, 0)],
        ).createShader(Rect.fromCircle(center: c, radius: s * 1.1)),
    );
    final dome = Path()
      ..moveTo(bell.left, bell.center.dy)
      ..arcTo(bell, math.pi, math.pi, false)
      ..close();
    canvas.drawPath(
      dome,
      Paint()
        ..shader = ui.Gradient.linear(bell.topCenter, bell.bottomCenter, [
          _alpha(Colors.white, 0.75 * alpha),
          _alpha(tint, 0.55 * alpha),
        ]),
    );
    final tentacle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, s * 0.05)
      ..strokeCap = StrokeCap.round
      ..color = _alpha(tint, 0.6 * alpha);
    for (var k = 0; k < 4; k++) {
      final x0 = bell.left + bell.width * (0.2 + k * 0.2);
      final path = Path()..moveTo(x0, bell.center.dy);
      for (var j = 1; j <= 6; j++) {
        path.lineTo(
          x0 + math.sin(t * 3 + phase + j * 0.9 + k) * s * 0.08,
          bell.center.dy + j * s * 0.14,
        );
      }
      canvas.drawPath(path, tentacle);
    }
  }

  /// Now and then a flying saucer glides across, beaming something up.
  void _ufo(Canvas canvas, Size size, double t) {
    const period = 22.0;
    final k = (t / period).floor();
    final local = (t - k * period) / 9;
    if (local > 1) return;
    final w = size.width;
    final x = -w * 0.15 + local * w * 1.3;
    final y =
        size.height * (0.24 + 0.06 * _rand(k, 90)) + math.sin(local * 18) * 4;
    final s = w * 0.07;
    final c = Offset(x, y);
    if (local > 0.4 && local < 0.6) {
      final beam = Path()
        ..moveTo(c.dx - s * 0.2, c.dy)
        ..lineTo(c.dx + s * 0.2, c.dy)
        ..lineTo(c.dx + s * 0.7, c.dy + s * 2.6)
        ..lineTo(c.dx - s * 0.7, c.dy + s * 2.6)
        ..close();
      final fade = math.sin((local - 0.4) / 0.2 * math.pi);
      canvas.drawPath(
        beam,
        Paint()
          ..shader = ui.Gradient.linear(c, c.translate(0, s * 2.6), [
            _alpha(style.glow, 0.45 * fade),
            _alpha(style.glow, 0),
          ]),
      );
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(0, -s * 0.18),
        width: s * 0.55,
        height: s * 0.5,
      ),
      Paint()..color = _alpha(style.cloudLight, 0.8),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c, width: s * 1.4, height: s * 0.38),
      Paint()
        ..shader = ui.Gradient.linear(
          c.translate(0, -s * 0.2),
          c.translate(0, s * 0.2),
          [style.rock[0], style.rock[2]],
        ),
    );
    for (var i = 0; i < 4; i++) {
      final on = ((t * 4).floor() + i).isEven;
      canvas.drawCircle(
        c.translate((i - 1.5) * s * 0.3, s * 0.04),
        s * 0.05,
        Paint()..color = on ? style.glow : _alpha(style.glow, 0.3),
      );
    }
  }

  // ── City ────────────────────────────────────────────────────────────────

  void _cityBiome(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;
    // Bands across the sun, synthwave style.
    final sun = _celestialAnchor(style, size);
    final sunR = w * 0.2;
    for (var i = 0; i < 5; i++) {
      final y = sun.dy + sunR * (0.12 + i * 0.17);
      canvas.drawRect(
        Rect.fromLTWH(sun.dx - sunR, y, sunR * 2, 2.0 + i * 1.6),
        Paint()..color = style.sky[3],
      );
    }
    _skyline(
      canvas,
      size,
      t,
      base: h * 0.7,
      maxHeight: h * 0.3,
      seed: 3,
      layer: 0,
    );
    _flyingCars(canvas, size, t, y0: h * 0.42, far: true);
    _skyline(
      canvas,
      size,
      t,
      base: h * 0.8,
      maxHeight: h * 0.24,
      seed: 11,
      layer: 1,
    );
    _flyingCars(canvas, size, t, y0: h * 0.58, far: false);
    _grid(canvas, size, t, top: h * 0.8);
    _sparkles(canvas, size, t, count: 10);
  }

  /// A row of towers with lit windows, blinking rooftop lights and a few
  /// neon signs.
  void _skyline(
    Canvas canvas,
    Size size,
    double t, {
    required double base,
    required double maxHeight,
    required int seed,
    required int layer,
  }) {
    final w = size.width;
    final pair = style.layers[layer];
    final window = Paint();
    var x = -w * 0.02;
    var i = 0;
    while (x < w) {
      final bw = w * (0.07 + _rand(i, seed) * 0.08);
      final bh = maxHeight * (0.35 + 0.65 * _rand(i, seed + 1));
      final top = base - bh;
      final rect = Rect.fromLTWH(x, top, bw - 2, bh + size.height);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(rect.topCenter, Offset(x, base), [
            _mix(pair.$1, style.haze, layer == 0 ? 0.25 : 0),
            pair.$2,
          ]),
      );
      // Windows: a grid, some lit, a few flickering now and then.
      final cols = math.max(2, (bw / 9).floor());
      final rows = math.max(2, (bh / 11).floor());
      final cw = (bw - 4) / cols;
      for (var r = 0; r < rows; r++) {
        for (var col = 0; col < cols; col++) {
          final n = i * 97 + r * 13 + col;
          if (_rand(n, seed + 2) > 0.42) continue;
          final flick = _rand(n + (t * 0.3).floor() * 7, seed + 3) > 0.94;
          if (flick) continue;
          final tint = _rand(n, seed + 4) > 0.8
              ? style.foliage[(n % 3)]
              : _mix(style.glow, Colors.white, 0.65);
          window.color = _alpha(tint, layer == 0 ? 0.45 : 0.8);
          canvas.drawRect(
            Rect.fromLTWH(
              x + 2 + col * cw + cw * 0.2,
              top + 6 + r * 11.0,
              cw * 0.55,
              5,
            ),
            window,
          );
        }
      }
      // A rooftop light on the tall ones.
      if (bh > maxHeight * 0.7) {
        final on = ((t * 1.2) + i).floor().isEven;
        canvas.drawLine(
          Offset(x + bw / 2, top),
          Offset(x + bw / 2, top - 10),
          Paint()
            ..strokeWidth = 1.4
            ..color = pair.$1,
        );
        canvas.drawCircle(
          Offset(x + bw / 2, top - 11),
          on ? 2.6 : 1.6,
          Paint()
            ..color = on
                ? const Color(0xFFFF4D5E)
                : _alpha(const Color(0xFFFF4D5E), 0.4),
        );
      }
      // Now and then a neon sign down the side.
      if (layer == 1 && _rand(i, seed + 5) > 0.6) {
        final neon = style.foliage[i % 3];
        final glow = 0.7 + 0.3 * math.sin(t * 3 + i * 2);
        final sign = Rect.fromLTWH(x + bw * 0.12, top + bh * 0.2, 4, bh * 0.35);
        canvas.drawRRect(
          RRect.fromRectAndRadius(sign.inflate(4), const Radius.circular(4)),
          Paint()..color = _alpha(neon, 0.25 * glow),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(sign, const Radius.circular(2)),
          Paint()..color = _alpha(neon, glow),
        );
      }
      x += bw;
      i++;
    }
  }

  /// Light streaks of flying cars: headlights one way, tail lights the
  /// other.
  void _flyingCars(
    Canvas canvas,
    Size size,
    double t, {
    required double y0,
    required bool far,
  }) {
    final w = size.width;
    for (var i = 0; i < (far ? 4 : 3); i++) {
      final dir = i.isEven ? 1.0 : -1.0;
      final speed = (far ? 40 : 70) + _rand(i, far ? 100 : 110) * 30;
      final span = w + 120;
      final p = (t * speed + _rand(i, far ? 101 : 111) * span) % span;
      final x = dir > 0 ? p - 60 : w + 60 - p;
      final y = y0 + i * (far ? 14 : 20);
      final color = dir > 0 ? const Color(0xFFFFF6D6) : const Color(0xFFFF4D5E);
      final tail = Offset(x - dir * (far ? 22 : 36), y);
      canvas.drawLine(
        tail,
        Offset(x, y),
        Paint()
          ..strokeWidth = far ? 1.6 : 2.4
          ..strokeCap = StrokeCap.round
          ..shader = ui.Gradient.linear(tail, Offset(x, y), [
            _alpha(color, 0),
            color,
          ]),
      );
      canvas.drawCircle(Offset(x, y), far ? 1.6 : 2.6, Paint()..color = color);
    }
  }

  /// A neon grid floor rolling toward you.
  void _grid(Canvas canvas, Size size, double t, {required double top}) {
    final w = size.width;
    final h = size.height;
    final floor = Rect.fromLTRB(0, top, w, h);
    canvas.drawRect(
      floor,
      Paint()
        ..shader = ui.Gradient.linear(floor.topCenter, floor.bottomCenter, [
          style.layers[2].$1,
          style.layers[2].$2,
        ]),
    );
    final line = Paint()
      ..strokeWidth = 1.2
      ..color = _alpha(style.land[0], 0.55);
    const rows = 9;
    final scroll = (t * 0.35) % 1;
    for (var k = 0; k < rows; k++) {
      final u = (k + scroll) / rows;
      final y = top + (h - top) * u * u;
      line.color = _alpha(style.land[0], 0.15 + 0.5 * u);
      canvas.drawLine(Offset(0, y), Offset(w, y), line);
    }
    // Lines running from the horizon toward you, meeting far beyond it.
    final vanish = Offset(w / 2, top - (h - top) * 0.4);
    final atHorizon = (top - vanish.dy) / (h - vanish.dy);
    line.color = _alpha(style.land[0], 0.4);
    for (var k = -8; k <= 8; k++) {
      final bottom = Offset(w / 2 + k * w * 0.16, h);
      canvas.drawLine(Offset.lerp(vanish, bottom, atHorizon)!, bottom, line);
    }
    // The horizon line glowing.
    canvas.drawLine(
      Offset(0, top),
      Offset(w, top),
      Paint()
        ..strokeWidth = 2
        ..color = _alpha(style.glow, 0.85),
    );
  }

  // ── Sakura ──────────────────────────────────────────────────────────────

  void _sakuraBiome(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;
    // The great mountain, snow-capped.
    final apex = Offset(w * 0.5, h * 0.36);
    final mountain = Path()
      ..moveTo(-w * 0.1, h * 0.74)
      ..quadraticBezierTo(
        w * 0.28,
        h * 0.58,
        apex.dx - w * 0.07,
        apex.dy + h * 0.02,
      )
      ..lineTo(apex.dx + w * 0.07, apex.dy + h * 0.02)
      ..quadraticBezierTo(w * 0.72, h * 0.58, w * 1.1, h * 0.74)
      ..close();
    canvas.drawPath(
      mountain,
      Paint()
        ..shader = ui.Gradient.linear(apex, Offset(apex.dx, h * 0.74), [
          _mix(style.rock[0], style.haze, 0.2),
          style.layers[0].$2,
        ]),
    );
    final snow = Path()
      ..moveTo(apex.dx - w * 0.07, apex.dy + h * 0.02)
      ..lineTo(apex.dx + w * 0.07, apex.dy + h * 0.02)
      ..lineTo(apex.dx + w * 0.15, apex.dy + h * 0.1)
      ..lineTo(apex.dx + w * 0.1, apex.dy + h * 0.085)
      ..lineTo(apex.dx + w * 0.06, apex.dy + h * 0.11)
      ..lineTo(apex.dx + w * 0.02, apex.dy + h * 0.08)
      ..lineTo(apex.dx - w * 0.03, apex.dy + h * 0.115)
      ..lineTo(apex.dx - w * 0.08, apex.dy + h * 0.085)
      ..lineTo(apex.dx - w * 0.15, apex.dy + h * 0.1)
      ..close();
    canvas.drawPath(
      snow,
      Paint()
        ..shader = ui.Gradient.linear(apex, apex.translate(0, h * 0.1), [
          style.land[0],
          style.land[2],
        ]),
    );
    _cloud(canvas, size, t, y: h * 0.52, scale: 1.1, speed: 5, offset: 0.2);
    _cloud(canvas, size, t, y: h * 0.3, scale: 0.6, speed: 3, offset: 0.7);

    // Two rolling hills, a shrine gate on the left one.
    for (var i = 1; i < 3; i++) {
      final base = h * (i == 1 ? 0.8 : 0.9);
      final ridge = _ridge(
        w,
        base,
        h * (i == 1 ? 0.08 : 0.06),
        seed: i * 31 + 2,
        sharp: false,
      );
      final pair = style.layers[i];
      canvas.drawPath(
        Path()..addPolygon([...ridge, Offset(w, h), Offset(0, h)], true),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, base - h * 0.08),
            Offset(0, h),
            [pair.$1, pair.$2],
          ),
      );
      if (i == 1) {
        _torii(canvas, Offset(w * 0.24, base - h * 0.04), w * 0.16);
        _sakuraTree(canvas, Offset(w * 0.82, base - h * 0.02), w * 0.3, t, 0.8);
      } else {
        _sakuraTree(canvas, Offset(w * 0.06, base), w * 0.34, t, 2.1);
      }
    }
    _petals(canvas, size, t);
  }

  void _torii(Canvas canvas, Offset base, double s) {
    final red = Paint()..color = style.glow;
    final dark = Paint()..color = _ColorMath.darken(style.glow, 0.25);
    // Two posts.
    for (final x in const [-0.32, 0.32]) {
      canvas.drawRect(
        Rect.fromLTWH(
          base.dx + x * s - s * 0.05,
          base.dy - s * 0.78,
          s * 0.1,
          s * 0.78,
        ),
        red,
      );
    }
    // The tie beam, then the curved top beam.
    canvas.drawRect(
      Rect.fromLTWH(base.dx - s * 0.42, base.dy - s * 0.6, s * 0.84, s * 0.07),
      red,
    );
    final top = Path()
      ..moveTo(base.dx - s * 0.58, base.dy - s * 0.86)
      ..quadraticBezierTo(
        base.dx,
        base.dy - s * 0.78,
        base.dx + s * 0.58,
        base.dy - s * 0.86,
      )
      ..lineTo(base.dx + s * 0.55, base.dy - s * 0.76)
      ..quadraticBezierTo(
        base.dx,
        base.dy - s * 0.69,
        base.dx - s * 0.55,
        base.dy - s * 0.76,
      )
      ..close();
    canvas.drawPath(top, dark);
    canvas.drawRect(
      Rect.fromLTWH(base.dx - s * 0.04, base.dy - s * 0.76, s * 0.08, s * 0.16),
      red,
    );
  }

  void _sakuraTree(
    Canvas canvas,
    Offset base,
    double s,
    double t,
    double phase,
  ) {
    final sway = math.sin(t * 0.9 + phase) * s * 0.02;
    final trunk = Path()
      ..moveTo(base.dx - s * 0.04, base.dy)
      ..quadraticBezierTo(
        base.dx - s * 0.06,
        base.dy - s * 0.3,
        base.dx + sway,
        base.dy - s * 0.5,
      )
      ..lineTo(base.dx + s * 0.04 + sway, base.dy - s * 0.5)
      ..quadraticBezierTo(
        base.dx + s * 0.02,
        base.dy - s * 0.3,
        base.dx + s * 0.05,
        base.dy,
      )
      ..close();
    canvas.drawPath(trunk, Paint()..color = style.rock[2]);
    final canopy = base.translate(sway, -s * 0.6);
    const puffs = [
      (0.0, 0.0, 0.26),
      (-0.22, 0.06, 0.2),
      (0.22, 0.05, 0.21),
      (-0.1, -0.15, 0.2),
      (0.13, -0.14, 0.19),
      (0.0, 0.14, 0.17),
    ];
    for (final (k, (dx, dy, r)) in puffs.indexed) {
      final c = canopy.translate(
        dx * s + math.sin(t + k + phase) * s * 0.008,
        dy * s,
      );
      canvas.drawCircle(
        c,
        r * s,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.4),
            colors: [style.foliage[0], style.foliage[1], style.foliage[2]],
          ).createShader(Rect.fromCircle(center: c, radius: r * s)),
      );
    }
  }

  /// Cherry petals drifting down across the whole scene.
  void _petals(Canvas canvas, Size size, double t) {
    for (var i = 0; i < 36; i++) {
      final life = (t * (0.045 + _rand(i, 120) * 0.04) + _rand(i, 121)) % 1.0;
      final x =
          (_rand(i, 122) * 1.3 - 0.15) * size.width +
          life * size.width * 0.35 +
          math.sin(t * 1.3 + i) * 12;
      final y = -10 + life * (size.height + 20);
      final s = 3.0 + _rand(i, 123) * 3;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * (1 + _rand(i, 124)) + i);
      canvas.scale(1, 0.55 + 0.45 * math.sin(t * 2.4 + i).abs());
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: s * 1.6, height: s),
        Paint()..color = _alpha(style.foliage[i.isEven ? 0 : 1], 0.85),
      );
      canvas.restore();
    }
  }

  // ── Reef ────────────────────────────────────────────────────────────────

  void _reefBiome(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;
    // The surface shimmering high above.
    final surface = Path()..moveTo(0, h * 0.05);
    for (var x = 0.0; x <= w; x += 8) {
      surface.lineTo(
        x,
        h * 0.05 +
            math.sin(x / w * 14 + t * 1.6) * 3 +
            math.sin(x / w * 31 - t) * 1.5,
      );
    }
    canvas.drawPath(
      surface,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _alpha(style.cloudLight, 0.45),
    );
    // Light shafts swaying down from the surface.
    for (var i = 0; i < 6; i++) {
      final x = w * (0.08 + i * 0.17) + math.sin(t * 0.3 + i * 1.7) * w * 0.04;
      final spread = w * (0.06 + 0.04 * _rand(i, 130));
      final shaft = Path()
        ..moveTo(x - spread * 0.3, 0)
        ..lineTo(x + spread * 0.3, 0)
        ..lineTo(x + spread + w * 0.05, h * 0.85)
        ..lineTo(x - spread + w * 0.05, h * 0.85)
        ..close();
      final a = 0.08 + 0.05 * math.sin(t * 0.7 + i * 2.3);
      canvas.drawPath(
        shaft,
        Paint()
          ..shader = ui.Gradient.linear(Offset(x, 0), Offset(x, h * 0.85), [
            _alpha(style.cloudLight, a),
            _alpha(style.cloudLight, 0),
          ]),
      );
    }
    _whale(canvas, size, t);
    _fish(canvas, size, t, far: true);

    // The seabed: a far rocky shelf, then sand.
    for (var i = 0; i < 3; i++) {
      final base = h * [0.74, 0.84, 0.93][i];
      final ridge = _ridge(
        w,
        base,
        h * [0.1, 0.05, 0.04][i],
        seed: i * 41 + 9,
        sharp: i == 0,
      );
      final pair = style.layers[i];
      canvas.drawPath(
        Path()..addPolygon([...ridge, Offset(w, h), Offset(0, h)], true),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, base - h * 0.1),
            Offset(0, h),
            [_mix(pair.$1, style.haze, i == 0 ? 0.4 : 0.15), pair.$2],
          ),
      );
      if (i == 0) {
        _seaweed(canvas, Offset(w * 0.08, base), h * 0.22, t, 0);
        _seaweed(canvas, Offset(w * 0.6, base + h * 0.01), h * 0.16, t, 1.4);
      }
      if (i == 1) {
        _coral(
          canvas,
          Offset(w * 0.25, base + h * 0.01),
          w * 0.16,
          style.foliage[0],
          0,
        );
        _coral(canvas, Offset(w * 0.78, base), w * 0.2, style.foliage[2], 2);
        _seaweed(canvas, Offset(w * 0.92, base + h * 0.01), h * 0.2, t, 2.2);
      }
      if (i == 2) {
        _coral(
          canvas,
          Offset(w * 0.5, base + h * 0.01),
          w * 0.13,
          style.foliage[1],
          4,
        );
        _seaweed(canvas, Offset(w * 0.36, base + h * 0.02), h * 0.13, t, 3.1);
      }
    }
    _fish(canvas, size, t, far: false);
    _jellies(canvas, size, t, count: 2, far: true);
    _bubbles(canvas, size, t);
  }

  void _seaweed(
    Canvas canvas,
    Offset base,
    double length,
    double t,
    double phase,
  ) {
    for (var k = 0; k < 3; k++) {
      final path = Path()..moveTo(base.dx + k * 6, base.dy);
      const steps = 10;
      for (var j = 1; j <= steps; j++) {
        final u = j / steps;
        path.lineTo(
          base.dx +
              k * 6 +
              math.sin(t * 1.2 + phase + u * 3 + k) * length * 0.08 * u,
          base.dy - length * u * (0.8 + 0.2 * k / 2),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5 - k.toDouble()
          ..strokeCap = StrokeCap.round
          ..color = _mix(const Color(0xFF2FB87E), style.haze, 0.25 + k * 0.1),
      );
    }
  }

  /// A branching coral fan.
  void _coral(Canvas canvas, Offset base, double s, Color color, int seed) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    void branch(Offset from, double angle, double len, int depth) {
      final to = from + Offset(math.cos(angle), math.sin(angle)) * len;
      paint.strokeWidth = math.max(1.5, depth * 2.2);
      canvas.drawLine(from, to, paint);
      if (depth == 0) {
        canvas.drawCircle(
          to,
          2.4,
          Paint()..color = _mix(color, Colors.white, 0.4),
        );
        return;
      }
      branch(
        to,
        angle - 0.42 - _rand(seed + depth, 140) * 0.2,
        len * 0.72,
        depth - 1,
      );
      branch(
        to,
        angle + 0.42 + _rand(seed + depth, 141) * 0.2,
        len * 0.72,
        depth - 1,
      );
    }

    branch(base, -math.pi / 2, s * 0.32, 3);
  }

  void _fish(Canvas canvas, Size size, double t, {required bool far}) {
    final count = far ? 7 : 5;
    final salt = far ? 150 : 160;
    for (var i = 0; i < count; i++) {
      final dir = _rand(i, salt) > 0.5 ? 1.0 : -1.0;
      final s = (far ? 5.0 : 9.0) * (0.8 + _rand(i, salt + 1) * 0.5);
      final span = size.width + s * 6;
      final p =
          (t * (far ? 14 : 24) * (0.7 + _rand(i, salt + 2) * 0.6) +
              _rand(i, salt + 3) * span) %
          span;
      final x = dir > 0 ? p - s * 3 : size.width + s * 3 - p;
      final y =
          size.height *
              (far
                  ? 0.3 + _rand(i, salt + 4) * 0.25
                  : 0.5 + _rand(i, salt + 4) * 0.25) +
          math.sin(t * 1.5 + i) * 6;
      final color = style.foliage[i % 3];
      final wag = math.sin(t * 10 + i) * s * 0.25;
      canvas.save();
      canvas.translate(x, y);
      canvas.scale(dir, 1);
      final body = Path()
        ..moveTo(s, 0)
        ..quadraticBezierTo(0, -s * 0.6, -s, 0)
        ..quadraticBezierTo(0, s * 0.6, s, 0)
        ..close();
      final tail = Path()
        ..moveTo(-s * 0.9, 0)
        ..lineTo(-s * 1.6, -s * 0.5 + wag)
        ..lineTo(-s * 1.6, s * 0.5 + wag)
        ..close();
      final paint = Paint()..color = _alpha(color, far ? 0.55 : 0.95);
      canvas.drawPath(tail, paint);
      canvas.drawPath(body, paint);
      canvas.drawCircle(
        Offset(s * 0.5, -s * 0.12),
        s * 0.12,
        Paint()..color = _alpha(Colors.white, far ? 0.5 : 1),
      );
      canvas.restore();
    }
  }

  /// A whale gliding by in the blue distance, now and then.
  void _whale(Canvas canvas, Size size, double t) {
    const period = 40.0;
    final k = (t / period).floor();
    final local = (t - k * period) / 30;
    if (local > 1) return;
    final w = size.width;
    final s = w * 0.28;
    final x = -s + local * (w + s * 2);
    final y = size.height * 0.3 + math.sin(local * 6) * 8;
    final body = Path()
      ..moveTo(x + s * 0.5, y)
      ..quadraticBezierTo(x + s * 0.4, y - s * 0.2, x, y - s * 0.14)
      ..quadraticBezierTo(x - s * 0.35, y - s * 0.1, x - s * 0.5, y - s * 0.02)
      ..lineTo(x - s * 0.7, y - s * 0.16)
      ..lineTo(x - s * 0.66, y + s * 0.02)
      ..lineTo(x - s * 0.72, y + s * 0.14)
      ..lineTo(x - s * 0.5, y + s * 0.03)
      ..quadraticBezierTo(x, y + s * 0.14, x + s * 0.5, y)
      ..close();
    canvas.drawPath(body, Paint()..color = _alpha(style.rock[2], 0.45));
  }

  void _bubbles(Canvas canvas, Size size, double t) {
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 22; i++) {
      final life = (t * (0.06 + _rand(i, 170) * 0.06) + _rand(i, 171)) % 1.0;
      final x = _rand(i, 172) * size.width + math.sin(t * 2 + i) * 6;
      final y = size.height * (1.02 - life * 1.0);
      final r = 1.5 + _rand(i, 173) * 4;
      final a = math.sin(life * math.pi);
      ring.color = _alpha(Colors.white, 0.55 * a);
      canvas.drawCircle(Offset(x, y), r, ring);
      canvas.drawCircle(
        Offset(x - r * 0.35, y - r * 0.35),
        r * 0.25,
        Paint()..color = _alpha(Colors.white, 0.7 * a),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) =>
      oldDelegate.clock != clock || oldDelegate.style != style;

  // ── Dojo: a mountain temple at dusk ──────────────────────────────────────

  void _dojoBiome(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;
    // Low mist over everything far away.
    _cloud(canvas, size, t, y: h * 0.42, scale: 1.3, speed: 4, offset: 0.1);
    // The dragon circles the castle high in the sky, behind the hills,
    // unless it's flying free or has come down to circle a frame.
    final roaming = _dragonRoaming(t);
    if (!roaming) _dojoDragon(canvas, size, t, roaming: false);
    _cloud(canvas, size, t, y: h * 0.26, scale: 0.8, speed: 6, offset: 0.55);

    // Three ink-wash mountain ranges, darker as they come forward.
    const bases = [0.64, 0.74, 0.86];
    const heights = [0.16, 0.12, 0.07];
    for (var i = 0; i < 3; i++) {
      final base = h * bases[i];
      final ridge = _ridge(
        w,
        base,
        h * heights[i],
        seed: 70 + i * 13,
        sharp: i < 2,
      );
      final pair = style.layers[i];
      canvas.drawPath(
        Path()..addPolygon([...ridge, Offset(w, h), Offset(0, h)], true),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, base - h * heights[i]),
            Offset(0, base + h * 0.12),
            [pair.$1, pair.$2],
          ),
      );
      if (i == 0) _castleGrounds(canvas, size, t);
    }

    _bamboo(canvas, size, t);
    _hangingLanterns(canvas, size, t);
    _mapleLeaves(canvas, size, t, far: true);
    _dojoFloor(canvas, size, t);
    paintShadowDuel(
      canvas,
      w * 0.52,
      h * 0.905,
      h * 0.15,
      t,
      ink: const Color(0xFF0A0503),
      rim: style.sparkles[1],
      sash: style.glow,
    );
    _mapleLeaves(canvas, size, t, far: false);
    _embers(canvas, size, t);
    if (roaming) _dojoDragon(canvas, size, t, roaming: true);
  }

  /// The castle on the far ridge, standing against the setting sun: the
  /// keep, a turret down its wall, and a pagoda further off.
  void _castleGrounds(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;
    final wall = _ColorMath.darken(style.rock[2], 0.02);
    final roof = _ColorMath.darken(style.rock[2], 0.07);
    final stone = style.rock[1];
    final light = style.sparkles[2];
    final rim = style.sparkles[1];
    _pagoda(canvas, Offset(w * 0.92, h * 0.645), w * 0.16, t);
    // The outer wall, roofed, running from the turret to the keep.
    final wallTop = h * 0.648;
    canvas.drawRect(
      Rect.fromLTRB(w * 0.27, wallTop, w * 0.5, wallTop + h * 0.03),
      Paint()..color = stone,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.265, wallTop + h * 0.002)
        ..lineTo(w * 0.505, wallTop + h * 0.002)
        ..lineTo(w * 0.5, wallTop - h * 0.008)
        ..lineTo(w * 0.27, wallTop - h * 0.008)
        ..close(),
      Paint()..color = roof,
    );
    canvas.drawLine(
      Offset(w * 0.27, wallTop - h * 0.008),
      Offset(w * 0.5, wallTop - h * 0.008),
      Paint()
        ..color = rim
        ..strokeWidth = 1,
    );
    paintTurret(
      canvas,
      Offset(w * 0.28, h * 0.672),
      w * 0.13,
      t,
      wall: wall,
      roof: roof,
      stone: stone,
      light: light,
      rim: rim,
    );
    paintCastle(
      canvas,
      Offset(w * 0.63, h * 0.672),
      w * 0.44,
      t,
      wall: wall,
      roof: roof,
      stone: stone,
      light: light,
      rim: rim,
    );
  }

  /// The dojo's wooden floor in the foreground, where the fighters spar:
  /// planks running away from you, a warm pool of light under the duel,
  /// banners at the side.
  void _dojoFloor(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;
    final top = h * 0.895;
    final front = h * 0.935;
    // Light from the sun behind, picking the fighters out of the dusk.
    canvas.drawCircle(
      Offset(w * 0.52, h * 0.83),
      w * 0.5,
      Paint()
        ..shader = ui.Gradient.radial(Offset(w * 0.52, h * 0.83), w * 0.5, [
          style.sparkles[0].withValues(alpha: 0.32),
          style.sparkles[0].withValues(alpha: 0),
        ]),
    );
    final deck = Path()
      ..moveTo(w * 0.04, top)
      ..lineTo(w * 1.02, top)
      ..lineTo(w * 1.02, front)
      ..lineTo(-w * 0.02, front)
      ..close();
    canvas.drawPath(
      deck,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, top), Offset(0, front), [
          const Color(0xFF5A3018),
          const Color(0xFF3A1E0E),
        ]),
    );
    // Planks, converging toward the castle.
    final seam = Paint()
      ..color = const Color(0xFF241208)
      ..strokeWidth = 1;
    for (var k = 0; k <= 14; k++) {
      final x0 = -w * 0.02 + w * 1.04 * k / 14;
      final x1 = w * 0.52 + (x0 - w * 0.52) * 0.86;
      canvas.drawLine(Offset(x1, top), Offset(x0, front), seam);
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.52, (top + front) / 2),
        width: w * 0.62,
        height: (front - top) * 0.9,
      ),
      Paint()
        ..color = style.sparkles[0].withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    // The front beam and the dark beneath it.
    canvas.drawRect(
      Rect.fromLTRB(-2, front, w + 2, front + h * 0.012),
      Paint()..color = const Color(0xFF2A160A),
    );
    canvas.drawLine(
      Offset(0, front),
      Offset(w, front),
      Paint()
        ..color = style.sparkles[1].withValues(alpha: 0.55)
        ..strokeWidth = 1,
    );
    canvas.drawRect(
      Rect.fromLTRB(-2, front + h * 0.012, w + 2, h + 2),
      Paint()..color = const Color(0xFF120804),
    );
    paintBanner(
      canvas,
      Offset(w * 0.9, top + h * 0.004),
      h * 0.13,
      t,
      style.glow,
      const Color(0xFFFFE2B0),
      const Color(0xFF120804),
    );
    paintBanner(
      canvas,
      Offset(w * 0.96, top + h * 0.004),
      h * 0.11,
      t + 0.7,
      _ColorMath.darken(style.glow, 0.12),
      const Color(0xFFFFE2B0),
      const Color(0xFF120804),
    );
  }

  /// Maple leaves drifting down through the dusk, turning as they fall.
  void _mapleLeaves(Canvas canvas, Size size, double t, {required bool far}) {
    final count = far ? 8 : 6;
    for (var i = 0; i < count; i++) {
      final seed = i + (far ? 0 : 50);
      final speed = (far ? 0.035 : 0.06) + _rand(seed, 160) * 0.03;
      final life = (t * speed + _rand(seed, 161)) % 1.0;
      final x =
          (_rand(seed, 162) * size.width * 1.2 - size.width * 0.1) +
          life * size.width * 0.25 +
          math.sin(t * 1.3 + seed) * 14;
      final y = -20 + life * (size.height + 40);
      final s = (far ? 4.5 : 8.0) + _rand(seed, 163) * 3;
      final color = [
        style.glow,
        style.sparkles[1],
        style.sparkles[0],
      ][seed % 3].withValues(alpha: far ? 0.55 : 0.9);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * (1.5 + _rand(seed, 164)) + seed);
      canvas.scale(1, 0.55 + 0.45 * math.cos(t * 2.2 + seed));
      final leaf = Path();
      for (var k = 0; k < 10; k++) {
        final a = -math.pi / 2 + k * math.pi / 5;
        final r = k.isEven ? s : s * 0.45;
        final p = Offset(math.cos(a), math.sin(a)) * r;
        k == 0 ? leaf.moveTo(p.dx, p.dy) : leaf.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(leaf..close(), Paint()..color = color);
      canvas.restore();
    }
  }

  // ── the dragon ──────────────────────────────────────────────────────────

  /// How long the dragon takes to fly between the sky and a frame.
  static const _flight = 2.5;

  /// Whether the dragon is out of the sky: flying free, at a frame, or on
  /// its way back from one.
  bool _dragonRoaming(double t) {
    if (DojoDragon.free.value || DojoDragon.perch != null) return true;
    if (DojoDragon.lastPerch == null) return false;
    final back = t - DojoDragon.perchChangedAt;
    return back < _flight;
  }

  /// Where the dragon's head is at [time].
  Offset _dragonAt(Size size, double time) {
    final w = size.width;
    final h = size.height;
    final base = DojoDragon.free.value
        // Free: it roams the whole screen.
        ? Offset(
            w * (0.5 + 0.62 * math.sin(time * 0.16)),
            h * (0.5 + 0.36 * math.sin(time * 0.23 + 0.6)),
          )
        // A long loop round the castle, turning off the edges of the sky.
        : Offset(
            w * (0.5 + 0.6 * math.cos(time * 0.12)),
            h * (0.23 + 0.08 * math.sin(time * 0.12)),
          );
    final perch = DojoDragon.lastPerch;
    if (perch == null) return base;
    final since = ((time - DojoDragon.perchChangedAt) / _flight).clamp(
      0.0,
      1.0,
    );
    final k = Curves.easeInOutCubic.transform(
      DojoDragon.perch != null ? since : 1 - since,
    );
    if (k <= 0) return base;
    final (globalCentre, r) = perch;
    final centre = globalCentre - (origin?.call() ?? Offset.zero);
    final orbit =
        centre +
        Offset(math.cos(time * 0.55), math.sin(time * 0.55) * 0.8) * (r * 2);
    return Offset.lerp(base, orbit, k)!;
  }

  void _dojoDragon(
    Canvas canvas,
    Size size,
    double t, {
    required bool roaming,
  }) {
    final free = DojoDragon.free.value;
    final at = _dragonAt(size, t);
    final v = _dragonAt(size, t + 0.05) - at;
    final left = v.dx < 0;
    // The nose tips the way it's heading, within reason.
    final pitch = math.atan2(v.dy, v.dx.abs()).clamp(-0.4, 0.4);
    if (free) {
      // Set free, it glows with the heat it carries.
      canvas.drawCircle(
        at,
        size.width * 0.2,
        Paint()
          ..color = const Color(0x40FF6A2A)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.08),
      );
    }
    // Circling the castle it breathes fire every so often; set free it's
    // bigger, hotter and breathes far more.
    paintFireDragon(
      canvas,
      at,
      size.width * (roaming ? 0.085 : 0.055),
      t,
      free ? FireDragonColors.blazing : FireDragonColors.crimson,
      facingLeft: left,
      tilt: left ? -pitch : pitch,
      breathEvery: free ? 4.5 : 8,
      fireScale: free ? 1.2 : 0.8,
    );
  }

  /// A three-tier pagoda with upturned eaves and warm windows.
  void _pagoda(Canvas canvas, Offset base, double s, double t) {
    final dark = Paint()..color = style.rock[2];
    final roof = Paint()..color = _ColorMath.darken(style.rock[2], 0.04);
    final light = Paint()
      ..color = style.sparkles[2].withValues(
        alpha: 0.85 + 0.15 * math.sin(t * 3),
      );
    var y = base.dy;
    var width = s * 0.5;
    for (var tier = 0; tier < 3; tier++) {
      final body = width * 0.62;
      final bh = s * (tier == 0 ? 0.16 : 0.12);
      canvas.drawRect(
        Rect.fromLTWH(base.dx - body / 2, y - bh, body, bh),
        dark,
      );
      // Glowing windows.
      for (var k = -1; k <= 1; k++) {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(base.dx + k * body * 0.28, y - bh * 0.5),
            width: body * 0.12,
            height: bh * 0.4,
          ),
          light,
        );
      }
      y -= bh;
      // The roof, its corners curling up.
      final rw = width * 0.62;
      final eave = Path()
        ..moveTo(base.dx - rw, y - s * 0.03)
        ..quadraticBezierTo(
          base.dx - rw * 0.7,
          y + s * 0.01,
          base.dx - rw * 0.45,
          y,
        )
        ..lineTo(base.dx + rw * 0.45, y)
        ..quadraticBezierTo(
          base.dx + rw * 0.7,
          y + s * 0.01,
          base.dx + rw,
          y - s * 0.03,
        )
        ..lineTo(base.dx + rw * 0.3, y - s * 0.07)
        ..lineTo(base.dx - rw * 0.3, y - s * 0.07)
        ..close();
      canvas.drawPath(eave, roof);
      y -= s * 0.07;
      width *= 0.74;
    }
    // The spire, and a pennant in the wind.
    canvas.drawRect(
      Rect.fromLTWH(base.dx - s * 0.01, y - s * 0.12, s * 0.02, s * 0.12),
      dark,
    );
    final flutter = math.sin(t * 4) * s * 0.012;
    canvas.drawPath(
      Path()
        ..moveTo(base.dx + s * 0.01, y - s * 0.12)
        ..quadraticBezierTo(
          base.dx + s * 0.06,
          y - s * 0.11 + flutter,
          base.dx + s * 0.11,
          y - s * 0.1 + flutter * 2,
        )
        ..lineTo(base.dx + s * 0.01, y - s * 0.08)
        ..close(),
      Paint()..color = style.glow,
    );
  }

  /// Bamboo along the left edge, swaying.
  void _bamboo(Canvas canvas, Size size, double t) {
    final h = size.height;
    for (var i = 0; i < 4; i++) {
      final x = size.width * (0.02 + i * 0.045);
      final top = h * (0.42 + _rand(i, 140) * 0.12);
      final sway = math.sin(t * 0.8 + i) * 6;
      final stalkW = 5.0 + _rand(i, 141) * 3;
      final color = _mix(style.foliage[1], style.foliage[2], i / 4);
      final stalk = Path()
        ..moveTo(x, h)
        ..quadraticBezierTo(x + sway * 0.2, (top + h) / 2, x + sway, top)
        ..lineTo(x + sway + stalkW, top)
        ..quadraticBezierTo(
          x + stalkW + sway * 0.2,
          (top + h) / 2,
          x + stalkW,
          h,
        )
        ..close();
      canvas.drawPath(stalk, Paint()..color = color);
      // Nodes.
      final node = Paint()
        ..color = _ColorMath.darken(color, 0.12)
        ..strokeWidth = 1.6;
      for (var y = h - 30.0; y > top; y -= 34) {
        final f = (h - y) / (h - top);
        final nx = x + sway * f * f;
        canvas.drawLine(Offset(nx - 1, y), Offset(nx + stalkW + 1, y), node);
      }
      // Leaves near the top.
      for (var k = 0; k < 3; k++) {
        final ly = top + 10 + k * 22;
        final f = (h - ly) / (h - top);
        final lx = x + sway * f * f + stalkW / 2;
        final dir = k.isEven ? 1.0 : -1.0;
        canvas.save();
        canvas.translate(lx, ly);
        canvas.rotate(dir * (0.5 + math.sin(t * 1.2 + i + k) * 0.08));
        canvas.drawOval(
          Rect.fromLTWH(0, -3, dir * 26, 6),
          Paint()..color = style.foliage[0].withValues(alpha: 0.9),
        );
        canvas.restore();
      }
    }
  }

  /// Red paper lanterns on a string, swaying and glowing.
  void _hangingLanterns(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;
    final a = Offset(-10, h * 0.1);
    final b = Offset(w * 0.6, h * 0.14);
    final sag = h * 0.05;
    Offset along(double u) => Offset(
      a.dx + (b.dx - a.dx) * u,
      a.dy + (b.dy - a.dy) * u + math.sin(u * math.pi) * sag,
    );
    final rope = Path()..moveTo(a.dx, a.dy);
    for (var k = 1; k <= 20; k++) {
      final p = along(k / 20);
      rope.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      rope,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = style.rock[2],
    );
    for (var i = 0; i < 4; i++) {
      final top = along(0.2 + i * 0.22);
      final swing = math.sin(t * 1.3 + i * 1.1) * 0.12;
      final s = 18.0 + (i.isEven ? 3 : 0);
      canvas.save();
      canvas.translate(top.dx, top.dy);
      canvas.rotate(swing);
      final body = Rect.fromCenter(
        center: Offset(0, s * 0.9),
        width: s * 1.1,
        height: s * 1.3,
      );
      canvas.drawOval(
        body.inflate(s * 0.5),
        Paint()
          ..color = style.glow.withValues(
            alpha: 0.18 + 0.06 * math.sin(t * 2 + i),
          )
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.4),
      );
      canvas.drawOval(
        body,
        Paint()
          ..shader = RadialGradient(
            colors: [
              style.sparkles[2],
              style.glow,
              _ColorMath.darken(style.glow, 0.15),
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(body),
      );
      final cap = Paint()..color = style.land[0];
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(0, body.top),
          width: s * 0.55,
          height: s * 0.16,
        ),
        cap,
      );
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(0, body.bottom),
          width: s * 0.55,
          height: s * 0.16,
        ),
        cap,
      );
      canvas.drawLine(
        Offset(0, body.bottom),
        Offset(math.sin(t * 2 + i) * 2, body.bottom + s * 0.5),
        Paint()
          ..color = style.land[0]
          ..strokeWidth = 1.6,
      );
      canvas.restore();
    }
  }

  /// A Chinese dragon, gliding through the clouds every so often.
  /// Embers drifting up from below, flickering.
  void _embers(Canvas canvas, Size size, double t) {
    for (var i = 0; i < 26; i++) {
      final life = (t * (0.05 + _rand(i, 150) * 0.05) + _rand(i, 151)) % 1.0;
      final x = _rand(i, 152) * size.width + math.sin(t * 1.4 + i) * 10;
      final y = size.height * (1.02 - life * 0.75);
      final flicker = 0.5 + 0.5 * math.sin(t * 9 + i * 2);
      canvas.drawCircle(
        Offset(x, y),
        1.2 + _rand(i, 153) * 1.6,
        Paint()
          ..color = style.sparkles[i % 3].withValues(
            alpha: math.sin(life * math.pi) * (0.4 + 0.6 * flicker),
          ),
      );
    }
  }
}

/// Small color helpers for the painters above.
abstract final class _ColorMath {
  static Color darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }
}
