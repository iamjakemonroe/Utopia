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
import 'winter_world.dart';
import 'birthday_world.dart';
import 'zombie_world.dart';
import 'ambient_tick.dart';
import 'soft_band.dart';

part 'utopia_world_islands.dart';
part 'utopia_world_sea.dart';
part 'utopia_world_lands.dart';
part 'utopia_world_night.dart';
part 'utopia_world_dojo.dart';

/// One clock shared by every copy of the world, so screens that each paint
/// their own background (and fade or slide between each other) always
/// agree on where the clouds, islands and stars are.
final Stopwatch _worldClock = Stopwatch()..start();

/// Tests set this to hold every world at one moment.
@visibleForTesting
double? debugWorldSeconds;

/// Tests set this to draw the skies as a browser does (see [_Skies]).
@visibleForTesting
bool? debugShareSkies;

double get worldSeconds =>
    debugWorldSeconds ?? _worldClock.elapsedMicroseconds / 1e6;

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

  /// A layer that never moves ([sky], for [world]). In the apps Flutter
  /// keeps it as a picture by itself; a browser redraws everything every
  /// frame, so there it's drawn once into pixels that are shown from then
  /// on (the same pixels, a fraction of the work), shared by every copy of
  /// that world at that size (see [_Skies]).
  Widget _still(Object world, CustomPainter sky) => RepaintBoundary(
    child: CustomPaint(
      painter: debugShareSkies ?? kIsWeb
          ? _SkyStill(world, sky, MediaQuery.devicePixelRatioOf(context))
          : sky,
    ),
  );

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
    // In a browser, the busiest worlds keep their slow parts as pixels at
    // the screen's sharpness (see SpriteCache).
    final dpr = kIsWeb ? MediaQuery.devicePixelRatioOf(context) : null;
    return IgnorePointer(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The sky and its planet, sun or moon never move, so they're
            // painted once into their own layer; only the scene on top
            // repaints per frame.
            if (style.biome == WorldBiome.doodle) ...[
              _still(WorldBiome.doodle, const DoodleSkyPainter()),
              RepaintBoundary(
                child: CustomPaint(
                  painter: DoodleScenePainter(_time, dpr: dpr),
                ),
              ),
            ] else ...[
              _still(style, _SkyPainter(style)),
              RepaintBoundary(
                child: CustomPaint(
                  key: _sceneKey,
                  painter: _ScenePainter(
                    _time,
                    style,
                    origin: _origin,
                    dpr: dpr,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The skies in a browser, each drawn into pixels once per world, size and
/// sharpness and shared by every copy showing it: home's, a screen opening
/// over it, the side menu's header, a card. Each copy once made its own,
/// so every screen opened drew a whole sky again first. The pixels are
/// those Flutter's SnapshotWidget made: drawn at the screen's sharpness
/// and shown scaled back with medium filtering.
abstract final class _Skies {
  static const _maxBytes = 40 << 20;

  /// Most recently shown last.
  static final _images = <(Object, Size, double), ui.Image>{};
  static int _bytes = 0;

  static int get debugCount => _images.length;

  static ui.Image of(Object world, Size size, double dpr, CustomPainter sky) {
    final key = (world, size, dpr);
    final kept = _images.remove(key);
    if (kept != null) return _images[key] = kept;
    final recorder = ui.PictureRecorder();
    sky.paint(Canvas(recorder)..scale(dpr), size);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(
      (size.width * dpr).ceil(),
      (size.height * dpr).ceil(),
    );
    picture.dispose();
    final bytes = image.width * image.height * 4;
    // What's on screen keeps its pixels in the pictures already drawn.
    while (_images.isNotEmpty && _bytes + bytes > _maxBytes) {
      final gone = _images.remove(_images.keys.first)!;
      _bytes -= gone.width * gone.height * 4;
      gone.dispose();
    }
    _bytes += bytes;
    return _images[key] = image;
  }
}

class _SkyStill extends CustomPainter {
  const _SkyStill(this.world, this.sky, this.dpr);

  final Object world;
  final CustomPainter sky;
  final double dpr;

  static final _paint = Paint()..filterQuality = FilterQuality.medium;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawImageRect(
      _Skies.of(world, size, dpr, sky),
      Rect.fromLTWH(0, 0, size.width * dpr, size.height * dpr),
      Offset.zero & size,
      _paint,
    );
  }

  @override
  bool shouldRepaint(_SkyStill old) => old.world != world || old.dpr != dpr;
}

/// How many skies are kept as pixels (tests).
@visibleForTesting
int get debugSharedSkies => _Skies.debugCount;

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
    WorldBiome.winter => Offset(w * WinterTimeline.moonAcross, h * 0.15),
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
          // Winter's is bigger (Santa's sleigh crosses it), but not
          // huge on a wide screen.
          _paintMoon(
            canvas,
            anchor,
            style.biome == WorldBiome.winter
                ? math.min(w * 0.1, size.height * 0.075)
                : w * 0.075,
          );
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
  _ScenePainter(this.clock, this.style, {this.origin, this.dpr})
    : super(repaint: clock);

  final ValueListenable<double> clock;
  final WorldStyle style;
  final Offset Function()? origin;

  /// In a browser, the screen's pixels a point (see [DoodleScenePainter.dpr]).
  final double? dpr;

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
          dpr: dpr,
        );
      case WorldBiome.winter:
        paintWinterScene(
          canvas,
          size,
          t,
          style,
          moon: _celestialAnchor(style, size),
          dpr: dpr,
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
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, baseY + amp * 1.5),
        Offset(0, baseY - amp - height),
        [_alpha(glow, 0.28 * strength), _alpha(glow, 0)],
      );
    final dpr = this.dpr;
    if (dpr != null) {
      // A browser would fill this wide, wavy band pixel by pixel each
      // frame; as triangles it's the GPU's (see softBand).
      canvas.drawVertices(
        softBand(lower, upper, dpr),
        BlendMode.modulate,
        paint,
      );
    } else {
      canvas.drawPath(
        Path()..addPolygon([...lower, ...upper.reversed], true),
        paint,
      );
    }
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

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) =>
      oldDelegate.clock != clock ||
      oldDelegate.style != style ||
      oldDelegate.dpr != dpr;
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
