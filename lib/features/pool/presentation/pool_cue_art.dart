import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../domain/pool_cues.dart';

/// How cues look, and what they do when they strike.
///
/// A cue is one rectangle shaded on the GPU (shaders/pool_cue.frag): the
/// taper, the light, the ferrule and joint, and its design, moving when
/// it's animated and glowing more the higher its level. What flies off it
/// (the strike's burst, the trail the cue ball leaves, the light when a
/// ball drops) is a handful of particles in its colours ([PoolFx]), drawn
/// with a few circles and lines a frame.

/// A cue's two effect colours (the burst, the trail, the aura).
(Color, Color) cueColors(CueLook look) => switch (look) {
  CueLook.classic => (const Color(0xFFE6F0FF), const Color(0xFF9FC3FF)),
  CueLook.oak => (const Color(0xFFFFE2B0), const Color(0xFFC28A4A)),
  CueLook.carbon => (const Color(0xFFFFFFFF), const Color(0xFFFF4A3A)),
  CueLook.ivory => (const Color(0xFFFFF6E0), const Color(0xFFE8C26A)),
  CueLook.neon => (const Color(0xFFFF40D8), const Color(0xFF2BF6FF)),
  CueLook.frost => (const Color(0xFFE8FBFF), const Color(0xFF7FD4FF)),
  CueLook.inferno => (const Color(0xFFFFD25A), const Color(0xFFFF5A12)),
  CueLook.thunder => (const Color(0xFFFFFFFF), const Color(0xFF7FC8FF)),
  CueLook.galaxy => (const Color(0xFFFF8BF0), const Color(0xFF8C7BFF)),
  CueLook.phoenix => (const Color(0xFFFFE07A), const Color(0xFFFF3B1F)),
  CueLook.prism => (const Color(0xFFFFFFFF), const Color(0xFFB57BFF)),
  CueLook.dragon => (const Color(0xFFB8FFD9), const Color(0xFF2FE38F)),
};

/// How far along its levels a cue is, 0 at level 1 to 1 at the top.
double cueLevelShare(PoolCue cue, int level) =>
    cue.maxLevel <= 1 ? 1 : ((level - 1) / (cue.maxLevel - 1)).clamp(0.0, 1.0);

/// Draws a cue: with the GPU shader once it's loaded, else a plain painted
/// taper.
///
/// Each one keeps its own shader, and draws one cue a frame: a shader's
/// settings are read when the frame is put on screen, not when it's drawn
/// with, so two cues drawn from one in the same frame would both look like
/// the last. So every place a cue shows [load]s its own.
class CueArt {
  CueArt._(this._program);

  final ui.FragmentProgram? _program;
  ui.FragmentShader? _shader;
  static Future<ui.FragmentProgram?>? _loading;

  /// A cue's art, with the shader if it loads (the program's loaded once).
  static Future<CueArt> load() async {
    final program = await (_loading ??= () async {
      try {
        return await ui.FragmentProgram.fromAsset('shaders/pool_cue.frag');
      } catch (_) {
        return null;
      }
    }());
    return CueArt._(program);
  }

  /// A plain one (no shader), for tests and until the shader's loaded.
  static final plain = CueArt._(null);

  /// Loads the shader afresh next time (each test has its own clock).
  @visibleForTesting
  static void debugForget() => _loading = null;

  /// [cue] at [level], its tip at [tip] and its butt [length] away along
  /// [back] (a unit vector), [thick] the butt's radius, [time] the seconds
  /// its animation is at.
  void draw(
    Canvas canvas,
    PoolCue cue,
    int level, {
    required Offset tip,
    required Offset back,
    required double length,
    required double thick,
    required double time,
    required double dpr,
    double opacity = 1,
    bool shadow = true,
  }) {
    if (opacity <= 0.01) return;
    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.rotate(math.atan2(back.dy, back.dx));
    final taper = Path()
      ..moveTo(0, -thick * 0.34)
      ..lineTo(length, -thick)
      ..lineTo(length, thick)
      ..lineTo(0, thick * 0.34)
      ..close();
    if (shadow) {
      // Its shadow on the cloth, below and to the right of it on screen.
      final down = Offset(thick * 0.9, thick * 1.4);
      final angle = math.atan2(back.dy, back.dx);
      final local = Offset(
        down.dx * math.cos(-angle) - down.dy * math.sin(-angle),
        down.dx * math.sin(-angle) + down.dy * math.cos(-angle),
      );
      canvas.drawPath(
        taper.shift(local),
        Paint()..color = Colors.black.withValues(alpha: 0.26 * opacity),
      );
    }
    final program = _program;
    if (program != null) {
      final s = _shader ??= program.fragmentShader();
      final height = thick * 2 * (cue.animated ? 3.4 : 1.08);
      var i = 0;
      s
        ..setFloat(i++, length)
        ..setFloat(i++, height)
        ..setFloat(i++, thick)
        ..setFloat(i++, time)
        ..setFloat(i++, cue.look.index.toDouble())
        ..setFloat(i++, cueLevelShare(cue, level))
        ..setFloat(i++, 1 / dpr);
      canvas.drawRect(
        Rect.fromLTWH(0, -height / 2, length, height),
        Paint()
          ..shader = s
          ..color = Colors.black.withValues(alpha: opacity),
      );
    } else {
      _plain(canvas, cue, taper, length, thick, opacity);
    }
    canvas.restore();
  }

  static void _plain(
    Canvas canvas,
    PoolCue cue,
    Path taper,
    double length,
    double thick,
    double opacity,
  ) {
    final (a, b) = cueColors(cue.look);
    canvas.drawPath(
      taper,
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFF3B6FD8),
            const Color(0xFFF3E7CF),
            const Color(0xFFE0C79A),
            Color.lerp(b, Colors.black, 0.45)!,
            Color.lerp(a, Colors.black, 0.6)!,
          ],
          stops: const [0, 0.02, 0.5, 0.53, 1],
        ).createShader(Rect.fromLTWH(0, -thick, length, thick * 2))
        ..color = Colors.black.withValues(alpha: opacity),
    );
  }
}

// ── Effects ─────────────────────────────────────────────────────────────

/// What a particle looks like.
enum _Bit { spark, shard, ember, ring, bolt, flash }

/// The particles in play on the table: a strike's burst, the trail behind
/// the cue ball, a pocket's flash. Positions are in table units, sizes in
/// ball radii, so the table's painter places them; [advance] moves them on.
class PoolFx {
  static const _max = 160;

  final _x = Float64List(_max), _y = Float64List(_max);
  final _vx = Float64List(_max), _vy = Float64List(_max);
  final _life = Float64List(_max), _span = Float64List(_max);
  final _size = Float64List(_max);
  final _color = List<Color>.filled(_max, Colors.white);
  final _bit = List<_Bit>.filled(_max, _Bit.spark);
  int _n = 0;
  final _rng = math.Random(7);

  /// The cue ball's recent places (table units), newest last, and the
  /// trail's colours (null: no trail).
  final trail = <Offset>[];
  (Color, Color)? trailColors;

  bool get busy => _n > 0 || trail.isNotEmpty;

  void _add(
    _Bit bit,
    double x,
    double y,
    double vx,
    double vy,
    double span,
    double size,
    Color color,
  ) {
    if (_n >= _max) return;
    _x[_n] = x;
    _y[_n] = y;
    _vx[_n] = vx;
    _vy[_n] = vy;
    _life[_n] = 0;
    _span[_n] = span;
    _size[_n] = size;
    _color[_n] = color;
    _bit[_n] = bit;
    _n++;
  }

  /// The cue's tip meeting the cue ball at ([x], [y]), the shot going
  /// along ([dx], [dy]) at [power]: a burst in the cue's colours, flung
  /// out wide ahead of the tip, and for an animated cue its own kind of
  /// flourish.
  void strike(
    PoolCue cue,
    int level,
    double x,
    double y,
    double dx,
    double dy,
    double power,
  ) {
    final (a, b) = cueColors(cue.look);
    final share = cueLevelShare(cue, level);
    final count = cue.animated ? (18 + 18 * share).round() : 6;
    final speed = 0.35 + 0.9 * power;
    // The moment the tip meets the ball: a flash.
    _add(_Bit.flash, x, y, 0, 0, 0.14, cue.animated ? 2.2 + share : 1.4, a);
    for (var i = 0; i < count; i++) {
      // Out ahead of the tip, in a wide fan.
      final spread = (_rng.nextDouble() - 0.5) * 2.6;
      final c = math.cos(spread), s = math.sin(spread);
      final ux = dx * c - dy * s, uy = dx * s + dy * c;
      final v = speed * (0.4 + _rng.nextDouble());
      final color = cue.look == CueLook.prism
          ? HSVColor.fromAHSV(1, _rng.nextDouble() * 360, 0.8, 1).toColor()
          : (i.isEven ? a : b);
      final bit = switch (cue.look) {
        CueLook.frost => _Bit.shard,
        CueLook.inferno ||
        CueLook.phoenix ||
        CueLook.dragon => i % 3 == 0 ? _Bit.ember : _Bit.spark,
        _ => _Bit.spark,
      };
      _add(
        bit,
        x,
        y,
        ux * v,
        uy * v,
        0.45 + 0.45 * _rng.nextDouble(),
        cue.animated ? 0.3 + 0.12 * share : 0.16,
        color,
      );
    }
    if (cue.animated) {
      _add(_Bit.ring, x, y, 0, 0, 0.32, 2.2 + 1.6 * share, a);
      if (cue.look == CueLook.thunder) {
        for (var k = 0; k < 3; k++) {
          _add(
            _Bit.bolt,
            x,
            y,
            dx,
            dy,
            0.16 + 0.04 * k,
            3.5 + 2.0 * share,
            k.isEven ? a : b,
          );
        }
      }
    }
    trail.clear();
    trailColors = cue.animated ? (a, b) : null;
  }

  /// A ball dropping into the pocket at ([x], [y]): a flash in the
  /// shooter's cue colours.
  void pocket(PoolCue cue, int level, double x, double y) {
    final (a, b) = cueColors(cue.look);
    final share = cueLevelShare(cue, level);
    _add(_Bit.ring, x, y, 0, 0, 0.5, cue.animated ? 3.2 + 1.8 * share : 1.8, a);
    if (!cue.animated) return;
    _add(_Bit.flash, x, y, 0, 0, 0.2, 2.4 + share, b);
    for (var i = 0; i < 14; i++) {
      final ang = i / 14 * math.pi * 2;
      final v = 0.16 + 0.18 * _rng.nextDouble();
      _add(
        cue.look == CueLook.frost ? _Bit.shard : _Bit.spark,
        x,
        y,
        math.cos(ang) * v,
        math.sin(ang) * v,
        0.6,
        0.26,
        i.isEven ? a : b,
      );
    }
  }

  /// The cue ball's at ([x], [y]) now (while a shot plays).
  void follow(double x, double y) {
    if (trailColors == null) return;
    if (trail.isNotEmpty) {
      final last = trail.last;
      if ((last.dx - x) * (last.dx - x) + (last.dy - y) * (last.dy - y) <
          1e-8) {
        return;
      }
    }
    trail.add(Offset(x, y));
    if (trail.length > 30) trail.removeAt(0);
  }

  /// The trail fades from its tail once the balls stop.
  void fadeTrail() {
    if (trail.isNotEmpty) trail.removeAt(0);
    if (trail.isEmpty) trailColors = null;
  }

  void advance(double dt) {
    var j = 0;
    for (var i = 0; i < _n; i++) {
      final life = _life[i] + dt;
      if (life >= _span[i]) continue;
      final drag = _bit[i] == _Bit.ember ? 0.9 : 0.82;
      final k = math.pow(drag, dt * 60).toDouble();
      _x[j] = _x[i] + _vx[i] * dt;
      _y[j] = _y[i] + _vy[i] * dt;
      _vx[j] = _vx[i] * k;
      _vy[j] = _vy[i] * k;
      _life[j] = life;
      _span[j] = _span[i];
      _size[j] = _size[i];
      _color[j] = _color[i];
      _bit[j] = _bit[i];
      j++;
    }
    _n = j;
  }

  /// Draws the trail and the particles, [toScreen] placing table points
  /// and [r] a ball's radius on screen.
  void paint(
    Canvas canvas,
    Offset Function(double x, double y) toScreen,
    double r,
  ) {
    paintTrail(canvas, toScreen, r);
    paintBits(canvas, toScreen, r);
  }

  /// The glowing trail behind the cue ball (drawn under the balls).
  void paintTrail(
    Canvas canvas,
    Offset Function(double x, double y) toScreen,
    double r,
  ) {
    final colors = trailColors;
    if (colors != null && trail.length > 1) {
      // A streak: wide and bright at the ball, thin and faint at its tail,
      // with a softer, wider glow under it.
      final line = Paint()
        ..blendMode = BlendMode.plus
        ..strokeCap = StrokeCap.round;
      var from = toScreen(trail.first.dx, trail.first.dy);
      for (var i = 1; i < trail.length; i++) {
        final k = i / (trail.length - 1);
        final to = toScreen(trail[i].dx, trail[i].dy);
        final color = Color.lerp(colors.$2, colors.$1, k)!;
        line
          ..strokeWidth = r * (0.6 + 2.4 * k)
          ..color = color.withValues(alpha: 0.24 * k);
        canvas.drawLine(from, to, line);
        line
          ..strokeWidth = r * (0.25 + 1.1 * k)
          ..color = color.withValues(alpha: 0.8 * k);
        canvas.drawLine(from, to, line);
        from = to;
      }
    }
  }

  /// The particles (drawn over the balls).
  void paintBits(
    Canvas canvas,
    Offset Function(double x, double y) toScreen,
    double r,
  ) {
    final paint = Paint()..blendMode = BlendMode.plus;
    for (var i = 0; i < _n; i++) {
      final k = _life[i] / _span[i];
      final fade = 1 - k;
      final p = toScreen(_x[i], _y[i]);
      final size = _size[i] * r;
      paint
        ..color = _color[i].withValues(alpha: fade.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill
        ..strokeWidth = 1;
      switch (_bit[i]) {
        case _Bit.spark:
          // A streak of light, white-hot at its head.
          final q = toScreen(_x[i] - _vx[i] * 0.045, _y[i] - _vy[i] * 0.045);
          paint
            ..strokeWidth = size * 0.9
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(q, p, paint);
          paint
            ..strokeWidth = size * 0.4
            ..color = Colors.white.withValues(alpha: 0.8 * fade);
          canvas.drawLine(Offset.lerp(q, p, 0.5)!, p, paint);
        case _Bit.ember:
          // A glowing coal, fading as it drifts.
          final radius = size * (1.6 - 0.6 * k);
          paint.shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.8 * fade),
              _color[i].withValues(alpha: 0.75 * fade),
              _color[i].withValues(alpha: 0),
            ],
            stops: const [0, 0.3, 1],
          ).createShader(Rect.fromCircle(center: p, radius: radius));
          canvas.drawCircle(p, radius, paint);
          paint.shader = null;
        case _Bit.flash:
          // A burst of light where the tip met the ball, a white core in
          // the cue's colour.
          final radius = size * (0.7 + 0.5 * k);
          paint.shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.9 * fade),
              _color[i].withValues(alpha: 0.6 * fade),
              _color[i].withValues(alpha: 0),
            ],
            stops: const [0, 0.35, 1],
          ).createShader(Rect.fromCircle(center: p, radius: radius));
          canvas.drawCircle(p, radius, paint);
          paint.shader = null;
        case _Bit.shard:
          final path = Path()
            ..moveTo(p.dx, p.dy - size * 1.4)
            ..lineTo(p.dx + size * 0.6, p.dy)
            ..lineTo(p.dx, p.dy + size * 1.4)
            ..lineTo(p.dx - size * 0.6, p.dy)
            ..close();
          canvas.drawPath(path, paint);
        case _Bit.ring:
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.22 * fade;
          canvas.drawCircle(
            p,
            r * (0.6 + _size[i] * Curves.easeOut.transform(k)),
            paint,
          );
        case _Bit.bolt:
          // A jagged flash out along the shot's way.
          final ux = _vx[i], uy = _vy[i];
          final len = _size[i] * r;
          final rng = math.Random(i * 31 + (_life[i] * 40).floor());
          var at = p;
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.12
            ..strokeCap = StrokeCap.round;
          final dir = toScreen(_x[i] + ux * 0.1, _y[i] + uy * 0.1) - p;
          final d = dir / math.max(dir.distance, 1e-6);
          final side = Offset(-d.dy, d.dx);
          for (var s = 0; s < 5; s++) {
            final next =
                at +
                d * (len / 5) +
                side * ((rng.nextDouble() - 0.5) * len * 0.35);
            canvas.drawLine(at, next, paint);
            at = next;
          }
      }
    }
  }
}

// ── A cue on its own ────────────────────────────────────────────────────

/// [cue] at [level], lying across its box and moving as it does at the
/// table (and, now and then, striking), for the store, the collection
/// and the lobby.
class CuePreview extends StatefulWidget {
  const CuePreview({
    super.key,
    required this.cue,
    this.level = 1,
    this.angle = -0.18,
  });

  final PoolCue cue;
  final int level;

  /// How it's tilted (radians).
  final double angle;

  @override
  State<CuePreview> createState() => _CuePreviewState();
}

class _CuePreviewState extends State<CuePreview>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _time = ValueNotifier<double>(0);
  final _fx = PoolFx();
  CueArt _art = CueArt.plain;
  double _lastStrike = -10;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    CueArt.load().then((art) {
      if (mounted) setState(() => _art = art);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still =
        MediaQuery.disableAnimationsOf(context) || !widget.cue.animated;
    if (still && _ticker.isActive) _ticker.stop();
    if (!still && !_ticker.isActive) _ticker.start();
  }

  @override
  void didUpdateWidget(CuePreview old) {
    super.didUpdateWidget(old);
    if (old.cue != widget.cue) didChangeDependencies();
  }

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final t = elapsed.inMicroseconds / 1e6;
    if (t - _lastStrike > 2.8) {
      _lastStrike = t;
      // The shot goes away from the butt.
      _fx.strike(
        widget.cue,
        widget.level,
        0,
        0,
        -math.cos(widget.angle),
        -math.sin(widget.angle),
        0.8,
      );
    }
    _fx.advance(dt.clamp(0.0, 0.05));
    _time.value = t;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _PreviewPainter(
          widget.cue,
          widget.level,
          widget.angle,
          _art,
          _fx,
          _time,
          MediaQuery.devicePixelRatioOf(context),
        ),
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter(
    this.cue,
    this.level,
    this.angle,
    this.art,
    this.fx,
    this.time,
    this.dpr,
  ) : super(repaint: time);

  final PoolCue cue;
  final int level;
  final double angle;
  final CueArt art;
  final PoolFx fx;
  final ValueNotifier<double> time;
  final double dpr;

  @override
  void paint(Canvas canvas, Size size) {
    // Thicker than at the table, so its design shows.
    final length = size.width * 0.86;
    final thick = math.min(size.height * 0.09, length * 0.028);
    final back = Offset(math.cos(angle), math.sin(angle));
    final centre = size.center(Offset.zero);
    // A little glide back and forth, as if lining up.
    final t = time.value;
    final glide = cue.animated ? math.sin(t * 1.3) * thick * 1.2 : 0.0;
    final tip = centre - back * (length / 2) + back * glide;
    art.draw(
      canvas,
      cue,
      level,
      tip: tip,
      back: back,
      length: length,
      thick: thick,
      time: t,
      dpr: dpr,
    );
    // The strike's burst at the tip, scaled so a "ball" is about the
    // cue's thickness.
    final r = thick * 2.2;
    fx.paint(canvas, (x, y) => tip + Offset(x, y) * (r / 0.0255), r);
  }

  @override
  bool shouldRepaint(_PreviewPainter old) =>
      old.cue != cue || old.level != level || old.art != art;
}
