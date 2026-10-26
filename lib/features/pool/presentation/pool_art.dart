import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/utopia_themes.dart';
import '../domain/pool_physics.dart';

/// How a pool table and its balls look, in the player's world: the cloth
/// takes the world's accent, the rails its surfaces, the trim its gold.
///
/// Everything still (the frame, the rails, the cloth, the pockets) is drawn
/// once into a picture of pixels ([PoolTableImage]); each frame then draws
/// only the balls: each a single square shaded on the GPU (shaders/
/// pool_ball.frag), turning as it rolls, with its number on top. So a
/// table in play costs a frame next to nothing, on a phone or in a browser.

/// The cushions' and rails' width around the cloth, in table units.
const kCushionWidth = 0.045;
const kRailWidth = 0.11;

/// The whole table, rails and all, in table units: x from -[kTableMargin]
/// to [kPoolLength] + [kTableMargin], and the same around y.
const kTableMargin = kCushionWidth + kRailWidth;

/// The table's colours in [theme].
class PoolPalette {
  PoolPalette(UtopiaTheme theme)
    : felt = _felt(theme.accent),
      feltEdge = Color.lerp(_felt(theme.accent), Colors.black, 0.35)!,
      cushion = Color.lerp(_felt(theme.accent), Colors.black, 0.22)!,
      rail = Color.lerp(theme.surfaceElevated, Colors.black, 0.2)!,
      railLight = Color.lerp(theme.surfaceElevated, Colors.white, 0.08)!,
      trim = theme.trim,
      trimBright = theme.trimBright,
      id = theme.id;

  final Color felt, feltEdge, cushion, rail, railLight, trim, trimBright;
  final String id;

  /// Cloth: the accent's hue, deep and calm (a table, not a light).
  static Color _felt(Color accent) {
    final hsl = HSLColor.fromColor(accent);
    return hsl.withSaturation(math.min(0.62, hsl.saturation)).withLightness(0.3).toColor();
  }
}

/// The ball colours: the usual set, a little brighter.
const kPoolBallColors = <int, Color>{
  0: Color(0xFFF7F4EC),
  1: Color(0xFFFFC21F),
  2: Color(0xFF2A62E8),
  3: Color(0xFFE8382F),
  4: Color(0xFF7A3FD1),
  5: Color(0xFFFF7A1A),
  6: Color(0xFF1B9E5A),
  7: Color(0xFF8C2232),
  8: Color(0xFF16141C),
};

Color poolBallColor(int ball) => kPoolBallColors[ball > 8 ? ball - 8 : ball]!;

/// The still table, drawn into pixels once for a size, a sharpness and a
/// palette, and kept.
class PoolTableImage {
  PoolTableImage._(this.image, this.key);

  final ui.Image image;
  final Object key;

  static PoolTableImage? _kept;

  /// The table [scale] logical pixels to a table unit, at [dpr].
  static PoolTableImage of(double scale, double dpr, PoolPalette palette) {
    final key = (scale, dpr, palette.id);
    final kept = _kept;
    if (kept != null && kept.key == key) return kept;
    kept?.image.dispose();
    const w = kPoolLength + 2 * kTableMargin, h = kPoolWidth + 2 * kTableMargin;
    final px = (w * scale * dpr).ceil(), py = (h * scale * dpr).ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(scale * dpr)
      ..translate(kTableMargin, kTableMargin);
    paintPoolTable(canvas, palette);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(px, py);
    picture.dispose();
    return _kept = PoolTableImage._(image, key);
  }
}

/// Paints the still table in table units (the cloth from (0, 0) to
/// ([kPoolLength], [kPoolWidth])).
void paintPoolTable(Canvas canvas, PoolPalette p) {
  const m = kTableMargin;
  const outer = Rect.fromLTRB(-m, -m, kPoolLength + m, kPoolWidth + m);
  // A soft shadow under the whole table.
  canvas.drawRRect(
    RRect.fromRectAndRadius(outer.shift(const Offset(0, 0.02)), const Radius.circular(0.09)),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.03),
  );
  // The rails: a deep frame with a light edge, rounded at the corners.
  final railRect = RRect.fromRectAndRadius(outer, const Radius.circular(0.08));
  canvas.drawRRect(
    railRect,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [p.railLight, p.rail],
      ).createShader(outer),
  );
  canvas.drawRRect(
    railRect.deflate(0.006),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.008
      ..color = p.trim.withValues(alpha: 0.9),
  );
  // Gold diamonds along the rails.
  final diamond = Paint()..color = p.trimBright;
  for (var i = 1; i < 8; i++) {
    if (i == 4) continue;
    final x = kPoolLength * i / 8;
    for (final y in [-m + kRailWidth * 0.5, kPoolWidth + m - kRailWidth * 0.5]) {
      _diamond(canvas, Offset(x, y), 0.012, diamond);
    }
  }
  for (var i = 1; i < 4; i++) {
    final y = kPoolWidth * i / 4;
    for (final x in [-m + kRailWidth * 0.5, kPoolLength + m - kRailWidth * 0.5]) {
      _diamond(canvas, Offset(x, y), 0.012, diamond);
    }
  }

  // The cloth, out under the cushions: lit in the middle, darker at the edge.
  const cloth = Rect.fromLTRB(-kCushionWidth, -kCushionWidth, kPoolLength + kCushionWidth, kPoolWidth + kCushionWidth);
  canvas.drawRect(
    cloth,
    Paint()
      ..shader = RadialGradient(
        radius: 0.75,
        colors: [Color.lerp(p.felt, Colors.white, 0.08)!, p.felt, p.feltEdge],
        stops: const [0, 0.6, 1],
      ).createShader(cloth),
  );
  // A fine weave, very faint.
  final weave = Paint()
    ..color = Colors.white.withValues(alpha: 0.025)
    ..strokeWidth = 0.002;
  for (var x = -kCushionWidth; x < kPoolLength + kCushionWidth; x += 0.012) {
    canvas.drawLine(Offset(x, -kCushionWidth), Offset(x + 0.04, kPoolWidth + kCushionWidth), weave);
  }

  // The cushions: a darker strip of cloth between the pockets, with a lit
  // nose (the edge a ball meets).
  final cushion = Paint()..color = p.cushion;
  final nose = Paint()
    ..color = Color.lerp(p.felt, Colors.white, 0.14)!
    ..strokeWidth = 0.004
    ..style = PaintingStyle.stroke;
  for (final c in kCushions.take(6)) {
    final horizontal = c.ay == c.by;
    final out = horizontal ? (c.ay == 0 ? -1.0 : 1.0) : (c.ax == 0 ? -1.0 : 1.0);
    final path = Path();
    if (horizontal) {
      final y = c.ay, yo = y + out * kCushionWidth;
      path
        ..moveTo(c.ax, y)
        ..lineTo(c.bx, y)
        ..lineTo(c.bx + 0.03 * (c.bx > c.ax ? 1 : -1), yo)
        ..lineTo(c.ax - 0.03 * (c.bx > c.ax ? 1 : -1), yo)
        ..close();
    } else {
      final x = c.ax, xo = x + out * kCushionWidth;
      path
        ..moveTo(x, c.ay)
        ..lineTo(x, c.by)
        ..lineTo(xo, c.by + 0.03)
        ..lineTo(xo, c.ay - 0.03)
        ..close();
    }
    canvas.drawPath(path, cushion);
    canvas.drawLine(Offset(c.ax, c.ay), Offset(c.bx, c.by), nose);
  }

  // Pockets: deep holes with a gold rim.
  for (final k in kPockets) {
    final c = Offset(k.x, k.y);
    final r = k.radius * 1.12;
    canvas.drawCircle(c, r + 0.012, Paint()..color = p.trim.withValues(alpha: 0.85));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.black, const Color(0xFF0B0812), Colors.black.withValues(alpha: 0.9)],
          stops: const [0, 0.7, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  // The head string and the foot spot, faintly.
  final mark = Paint()
    ..color = Colors.white.withValues(alpha: 0.1)
    ..strokeWidth = 0.003;
  canvas.drawLine(const Offset(kHeadString, 0), const Offset(kHeadString, kPoolWidth), mark);
  canvas.drawCircle(Offset(kFootSpot.$1, kFootSpot.$2), 0.006, Paint()..color = Colors.white.withValues(alpha: 0.25));
}

void _diamond(Canvas canvas, Offset c, double r, Paint paint) {
  canvas.drawPath(
    Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r * 0.6, c.dy)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r * 0.6, c.dy)
      ..close(),
    paint,
  );
}

/// Each ball's orientation: a 3x3 rotation from the ball to the table
/// (row by row; its columns are the ball's own axes as seen from above,
/// x right, y down, z up at us), turned as it rolls: a roll of distance d
/// turns it d / r about the axis across its path, so its top moves the way
/// it goes. Only for looks: the physics doesn't need it.
class PoolSpin {
  PoolSpin() {
    for (var i = 0; i < kBalls; i++) {
      // Each starts turned its own way, so a rack isn't all numbers up.
      final a = i * 1.7, b = i * 0.9;
      _set(i, _mul(_rotX(a), _rotY(b)));
    }
  }

  final Float64List m = Float64List(9 * kBalls);

  /// Ball [i] rolled by ([dx], [dy]) (table units).
  void roll(int i, double dx, double dy) {
    final d = math.sqrt(dx * dx + dy * dy);
    if (d < 1e-7) return;
    final angle = d / kBallRadius;
    // Axis across the path: (-dy, dx, 0), unit.
    final ax = -dy / d, ay = dx / d;
    final c = math.cos(angle), s = math.sin(angle), t = 1 - c;
    // Rodrigues' rotation about (ax, ay, 0).
    final r = Float64List.fromList([
      t * ax * ax + c, t * ax * ay, s * ay,
      t * ax * ay, t * ay * ay + c, -s * ax,
      -s * ay, s * ax, c,
    ]);
    _set(i, _mul(r, _get(i)));
  }

  Float64List _get(int i) => Float64List.sublistView(m, 9 * i, 9 * i + 9);

  void _set(int i, Float64List r) {
    // Kept a true rotation: rows re-made unit and square to each other.
    var r0 = [r[0], r[1], r[2]], r1 = [r[3], r[4], r[5]];
    r0 = _unit(r0);
    final dot = r0[0] * r1[0] + r0[1] * r1[1] + r0[2] * r1[2];
    r1 = _unit([r1[0] - dot * r0[0], r1[1] - dot * r0[1], r1[2] - dot * r0[2]]);
    final r2 = [
      r0[1] * r1[2] - r0[2] * r1[1],
      r0[2] * r1[0] - r0[0] * r1[2],
      r0[0] * r1[1] - r0[1] * r1[0],
    ];
    m.setRange(9 * i, 9 * i + 9, [...r0, ...r1, ...r2]);
  }

  static List<double> _unit(List<double> v) {
    final l = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
    return [v[0] / l, v[1] / l, v[2] / l];
  }

  static Float64List _rotX(double a) => Float64List.fromList(
    [1, 0, 0, 0, math.cos(a), -math.sin(a), 0, math.sin(a), math.cos(a)],
  );

  static Float64List _rotY(double a) => Float64List.fromList(
    [math.cos(a), 0, math.sin(a), 0, 1, 0, -math.sin(a), 0, math.cos(a)],
  );

  static Float64List _mul(List<double> a, List<double> b) {
    final out = Float64List(9);
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        out[3 * r + c] = a[3 * r] * b[c] + a[3 * r + 1] * b[3 + c] + a[3 * r + 2] * b[6 + c];
      }
    }
    return out;
  }
}

/// Draws the balls: one GPU-shaded square each, a shadow under it, its
/// number on top. Made once (the shader loads), then cheap to draw with.
class PoolBallArt {
  PoolBallArt._(this._program);

  final ui.FragmentProgram? _program;
  final _shaders = <ui.FragmentShader>[];
  static final _numbers = <int, ui.Picture>{};
  static Future<PoolBallArt>? _loading;

  /// The art, with the GPU shader if it loads (else balls are shaded
  /// plainly).
  static Future<PoolBallArt> load() => _loading ??= () async {
    try {
      return PoolBallArt._(await ui.FragmentProgram.fromAsset('shaders/pool_ball.frag'));
    } catch (_) {
      return PoolBallArt._(null);
    }
  }();

  /// Ball [ball] at [c] (logical pixels), [r] across, turned as in [spin].
  void draw(Canvas canvas, int ball, Offset c, double r, PoolSpin spin, double dpr) {
    // Its shadow, soft (a gradient, not a blur: cheap every frame), the
    // light being from the top left.
    final shade = Rect.fromCenter(center: c.translate(r * 0.25, r * 0.35), width: r * 2.6, height: r * 2.4);
    canvas.drawOval(
      shade,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.black.withValues(alpha: 0.42), Colors.black.withValues(alpha: 0)],
          stops: const [0.45, 1],
        ).createShader(shade),
    );
    final rect = Rect.fromCircle(center: c, radius: r);
    final program = _program;
    final m = spin.m;
    final o = 9 * ball;
    final kind = ball == kCueBall ? 2.0 : (ball > 8 ? 1.0 : 0.0);
    final color = poolBallColor(ball);
    if (program != null) {
      while (_shaders.length <= ball) {
        _shaders.add(program.fragmentShader());
      }
      final s = _shaders[ball];
      var i = 0;
      s
        ..setFloat(i++, rect.left)
        ..setFloat(i++, rect.top)
        ..setFloat(i++, rect.width)
        ..setFloat(i++, rect.height);
      // The shader wants view to ball: the transpose (row r = column r).
      for (var row = 0; row < 3; row++) {
        for (var col = 0; col < 3; col++) {
          s.setFloat(i++, m[o + 3 * col + row]);
        }
      }
      s
        ..setFloat(i++, color.r)
        ..setFloat(i++, color.g)
        ..setFloat(i++, color.b)
        ..setFloat(i++, 1)
        ..setFloat(i++, kind)
        ..setFloat(i++, 1 / (r * dpr));
      canvas.drawRect(rect, Paint()..shader = s);
    } else {
      _plain(canvas, ball, c, r, color);
    }
    if (ball == kCueBall) return;

    // The number, on its disc: at the ball's own z for a solid, its own x
    // (the band's front) for a stripe; as seen, that axis is the column.
    final axis = ball > 8 ? 0 : 2;
    final vx = m[o + axis], vy = m[o + 3 + axis], vz = m[o + 6 + axis];
    if (vz < 0.25) return;
    final label = _numbers[ball] ??= _number(ball);
    canvas.save();
    canvas.translate(c.dx + vx * r, c.dy + vy * r);
    canvas.scale(r / 10 * (0.55 + 0.45 * vz));
    canvas.drawPicture(label);
    canvas.restore();
  }

  static void _plain(Canvas canvas, int ball, Offset c, double r, Color color) {
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: [Color.lerp(ball > 8 ? Colors.white : color, Colors.white, 0.35)!, ball > 8 ? Colors.white : color, Color.lerp(color, Colors.black, 0.35)!],
          stops: const [0, 0.45, 1],
        ).createShader(rect),
    );
    if (ball > 8) {
      canvas.save();
      canvas.clipPath(Path()..addOval(rect));
      canvas.drawRect(Rect.fromCenter(center: c, width: r * 2, height: r * 1.1), Paint()..color = color);
      canvas.restore();
    }
  }

  /// [ball]'s number on its white disc, about 10 across, centred.
  static ui.Picture _number(int ball) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final text = TextPainter(
      text: TextSpan(
        text: '$ball',
        style: AppTextStyles.display(
          fontSize: ball > 9 ? 6.4 : 7.4,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF16141C),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, Offset(-text.width / 2, -text.height / 2));
    return recorder.endRecording();
  }
}
