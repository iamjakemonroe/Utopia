import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../features/chess/domain/chess_types.dart';
import '../../features/chess/presentation/widgets/chess_piece_art.dart';
import '../../features/chess/presentation/widgets/chess_piece_styles.dart';
import '../../features/checkers/domain/checkers_engine.dart';
import '../../features/checkers/presentation/widgets/checkers_disc.dart';
import '../../features/eights/domain/eights_engine.dart';
import '../../features/eights/presentation/widgets/card_art.dart';
import 'package:flutter/scheduler.dart';

import '../theme/utopia_themes.dart';
import 'ambient_tick.dart';
import 'sprite_cache.dart';

enum GameKind { chess, ludo, checkers, doodle, eights, pool }

/// A game's banner art: a little living diorama in the current world. A
/// floating island drifts in the theme's sky with the game set up on top:
/// for Ludo a mini board with pieces hopping around it and a die tumbling
/// overhead; for chess a checkered island where the knight hops in L-shapes
/// while the king and queen sway; for checkers a king double-jumping two
/// pieces, which pop and come back for another go; for Guess My Doodle an
/// easel where a pencil sketches a cat while guesses pop up around it, the
/// last one right; for Crazy Eights a fanned hand where a card flips up and
/// sails onto the pile, now and then a rainbow eight. A waterfall spills off
/// the edge and sparkles rise.
class GameSceneArt extends StatefulWidget {
  const GameSceneArt({super.key, required this.game, this.height = 136});

  final GameKind game;
  final double height;

  @override
  State<GameSceneArt> createState() => _GameSceneArtState();
}

class _GameSceneArtState extends State<GameSceneArt>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _t = ValueNotifier(0);

  /// Where the scene had got to when it last stopped: it carries on from
  /// there (a ticker counts from zero each time it starts).
  double _from = 0;
  late final Ticker _ticker = createTicker(
    ambientTick((elapsed) => _t.value = _from + elapsed.inMicroseconds / 1e6),
  );
  bool _still = false;

  /// Whether any of the scene is on screen: one scrolled out of sight
  /// (home's game tiles below the fold) neither moves nor draws.
  bool _inView = true;
  final _scrolls = <ScrollPosition>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    _watchScrolls();
    _sync();
    WidgetsBinding.instance.addPostFrameCallback((_) => _look());
  }

  /// Listens to every scrolling list the scene sits in.
  void _watchScrolls() {
    for (final p in _scrolls) {
      p.removeListener(_look);
    }
    _scrolls.clear();
    var scrollable = context.findAncestorStateOfType<ScrollableState>();
    while (scrollable != null) {
      _scrolls.add(scrollable.position..addListener(_look));
      scrollable = scrollable.context.findAncestorStateOfType<ScrollableState>();
    }
  }

  /// Whether it's on screen now.
  void _look() {
    if (!mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final height = MediaQuery.sizeOf(context).height;
    final inView = top + box.size.height > 0 && top < height;
    if (inView == _inView) return;
    _inView = inView;
    _sync();
  }

  void _sync() {
    final run = !_still && _inView;
    if (run && !_ticker.isActive) {
      _from = _t.value;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    for (final p in _scrolls) {
      p.removeListener(_look);
    }
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: widget.height,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _DioramaPainter(
            clock: _t,
            game: widget.game,
            style: UtopiaThemes.active.world,
            accent: UtopiaThemes.active.accent,
            dpr: kIsWeb || debugDioramaSprites
                ? MediaQuery.devicePixelRatioOf(context)
                : null,
          ),
        ),
      ),
    );
  }
}

/// The dioramas' still parts (the sun, the rock, the grass and the board on
/// it) kept as pixels in a browser: see [_DioramaPainter._still].
final _dioramaSprites = SpriteCache(maxBytes: 24 << 20);

/// Draws the dioramas' still parts from pixels outside a browser too, to
/// test that path.
@visibleForTesting
bool debugDioramaSprites = false;

/// Lets go of the dioramas' pixels, for tests.
@visibleForTesting
void debugClearDioramaSprites() => _dioramaSprites.clear();

/// How many of the dioramas' drawings are kept as pixels, for tests.
@visibleForTesting
// ignore: invalid_use_of_visible_for_testing_member
int get debugDioramaSpriteCount => _dioramaSprites.length;

class _DioramaPainter extends CustomPainter {
  _DioramaPainter({
    required this.clock,
    required this.game,
    required this.style,
    required this.accent,
    this.dpr,
  }) : super(repaint: clock);

  final ValueNotifier<double> clock;
  final GameKind game;
  final WorldStyle style;
  final Color accent;

  /// In a browser, the screen's pixels per point: what doesn't move (or
  /// only moves as a whole) is drawn once into pixels at that sharpness and
  /// placed each frame, rather than drawn again shape by shape. Null in the
  /// apps, which keep what hasn't changed by themselves.
  final double? dpr;

  /// Draws what [paint] draws around the origin, at [at]: from pixels made
  /// once (in a browser), or directly.
  void _still(
    Canvas canvas,
    Object key,
    Rect bounds,
    Offset at,
    void Function(Canvas canvas) paint,
  ) {
    final dpr = this.dpr;
    if (dpr == null) {
      canvas.save();
      canvas.translate(at.dx, at.dy);
      paint(canvas);
      canvas.restore();
      return;
    }
    _dioramaSprites.draw(
      canvas,
      key,
      bounds: bounds,
      dpr: dpr,
      at: at,
      paint: paint,
    );
  }

  static const _red = Color(0xFFFF5C6C);
  static const _green = Color(0xFF2FD98E);
  static const _yellow = Color(0xFFFFC93D);
  static const _blue = Color(0xFF4DA3FF);

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value;
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    // Sky.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [style.sky[1], style.sky[3], style.sky[5]],
        ).createShader(rect),
    );
    final star = Paint();
    for (var i = 0; i < 18; i++) {
      final tw = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(t * 2 + i * 1.7));
      star.color = Colors.white.withValues(
        alpha: tw * style.starDensity.clamp(0.4, 1.0),
      );
      canvas.drawCircle(
        Offset((i * 73 % 100) / 100 * w, (i * 37 % 50) / 100 * h),
        0.6 + (i % 3) * 0.4,
        star,
      );
    }
    _still(
      canvas,
      ('sun', style, h),
      Rect.fromCircle(center: Offset.zero, radius: h * 0.33),
      Offset(w * 0.86, h * 0.24),
      (canvas) {
        canvas.drawCircle(
          Offset.zero,
          h * 0.32,
          Paint()
            ..shader =
                RadialGradient(
                  colors: [
                    style.celestialColors[1].withValues(alpha: 0.4),
                    Colors.transparent,
                  ],
                ).createShader(
                  Rect.fromCircle(center: Offset.zero, radius: h * 0.32),
                ),
        );
        canvas.drawCircle(
          Offset.zero,
          h * 0.13,
          Paint()
            ..shader =
                RadialGradient(
                  center: const Alignment(-0.3, -0.3),
                  colors: style.celestialColors,
                  stops: const [0.0, 0.4, 0.8, 1.0],
                ).createShader(
                  Rect.fromCircle(center: Offset.zero, radius: h * 0.13),
                ),
        );
      },
    );
    _cloud(canvas, Offset((t * 9) % (w + 120) - 60, h * 0.22), h * 0.16, 0.5);
    _cloud(
      canvas,
      Offset((t * 6 + w * 0.6) % (w + 120) - 60, h * 0.42),
      h * 0.12,
      0.35,
    );

    // The floating island.
    final bob = math.sin(t * 1.4) * h * 0.025;
    final top = Offset(w * 0.5, h * 0.66 + bob);
    final iw = math.min(w * 0.66, h * 2.5);
    // The rock under the island, the waterfall's falling streaks, then the
    // grass on top and the game's board on it: the rock and the grass with
    // its board are still (they only bob, as a whole).
    _still(
      canvas,
      ('rock', style, iw, h),
      Rect.fromLTRB(-iw * 0.56, -h * 0.02, iw * 0.56, h * 0.68),
      top,
      (canvas) => _rock(canvas, Offset.zero, iw, h),
    );
    _streaks(canvas, top, iw, h, t);
    _still(
      canvas,
      ('deck', game, style, accent, iw, h),
      // The easel stands tall; the boards lie flat.
      Rect.fromLTRB(
        -iw * 0.62,
        h * (game == GameKind.doodle ? -0.72 : -0.3),
        iw * 0.62,
        h * 0.24,
      ),
      top,
      (canvas) {
        _cap(canvas, Offset.zero, iw, h);
        switch (game) {
          case GameKind.ludo:
            _ludoBoard(canvas, Offset.zero, iw, h);
          case GameKind.chess:
            _chessBoard(canvas, Offset.zero, iw, h);
          case GameKind.checkers:
            _checkersBoard(canvas, Offset.zero, iw, h);
          case GameKind.doodle:
            _easel(canvas, Offset.zero, iw, h);
          case GameKind.eights:
            _eightsTable(canvas, Offset.zero, iw, h);
          case GameKind.pool:
            _poolTable(canvas, Offset.zero, iw, h);
        }
      },
    );

    canvas.save();
    canvas.clipRect(rect);
    switch (game) {
      case GameKind.ludo:
        _ludo(canvas, top, iw, h, t);
      case GameKind.chess:
        _chess(canvas, top, iw, h, t);
      case GameKind.checkers:
        _checkers(canvas, top, iw, h, t);
      case GameKind.doodle:
        _doodle(canvas, top, iw, h, t);
      case GameKind.eights:
        _eights(canvas, top, iw, h, t);
      case GameKind.pool:
        _pool(canvas, top, iw, h, t);
    }
    canvas.restore();

    // Sparkles rising past the island.
    final spark = Paint();
    for (var i = 0; i < 10; i++) {
      final life = (t * (0.12 + (i % 4) * 0.03) + i / 10) % 1.0;
      final p = Offset((i * 41 % 100) / 100 * w, h * (1.05 - life * 1.1));
      spark.color = style.sparkles[i % 3].withValues(
        alpha: math.sin(life * math.pi) * 0.9,
      );
      canvas.drawCircle(p, 1.6, spark);
    }
  }

  void _cloud(Canvas canvas, Offset c, double r, double alpha) {
    final path = Path()
      ..addOval(Rect.fromCircle(center: c, radius: r))
      ..addOval(
        Rect.fromCircle(
          center: c.translate(r * 1.1, -r * 0.3),
          radius: r * 1.2,
        ),
      )
      ..addOval(
        Rect.fromCircle(center: c.translate(r * 2.2, 0), radius: r * 0.9),
      );
    canvas.drawPath(
      path,
      Paint()..color = style.cloudLight.withValues(alpha: alpha),
    );
  }

  /// The rock under the island, and the waterfall's water down its side.
  void _rock(Canvas canvas, Offset top, double iw, double h) {
    final left = top.translate(-iw / 2, 0);
    final right = top.translate(iw / 2, 0);
    final tip = top.translate(iw * 0.05, h * 0.62);
    final rock = Path()
      ..moveTo(left.dx, left.dy)
      ..cubicTo(
        left.dx + iw * 0.08,
        top.dy + h * 0.25,
        top.dx - iw * 0.2,
        top.dy + h * 0.45,
        tip.dx,
        tip.dy,
      )
      ..cubicTo(
        top.dx + iw * 0.2,
        top.dy + h * 0.42,
        right.dx - iw * 0.06,
        top.dy + h * 0.22,
        right.dx,
        right.dy,
      )
      ..close();
    canvas.drawPath(
      rock,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: style.rock,
        ).createShader(rock.getBounds()),
    );
    // Waterfall off the right edge.
    final fallTop = top.translate(iw * 0.4, h * 0.03);
    final band = Rect.fromLTWH(fallTop.dx - 3, fallTop.dy, 6, h * 0.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(band, const Radius.circular(3)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC9FE8FF), Color(0x005AB8FF)],
        ).createShader(band),
    );
  }

  /// The waterfall's streaks of light, falling.
  void _streaks(Canvas canvas, Offset top, double iw, double h, double t) {
    final fallTop = top.translate(iw * 0.4, h * 0.03);
    final streak = Paint()
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < 3; k++) {
      final p = (t * 1.2 + k / 3) % 1.0;
      streak.color = Colors.white.withValues(alpha: (1 - p) * 0.8);
      canvas.drawLine(
        Offset(fallTop.dx, fallTop.dy + p * h * 0.45),
        Offset(fallTop.dx, fallTop.dy + p * h * 0.45 + 6),
        streak,
      );
    }
  }

  /// The grass on top of the island.
  void _cap(Canvas canvas, Offset top, double iw, double h) {
    final cap = Rect.fromCenter(center: top, width: iw * 1.04, height: h * 0.2);
    canvas.drawOval(
      cap.shift(Offset(0, h * 0.03)),
      Paint()..color = style.land[2],
    );
    canvas.drawOval(
      cap,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: style.land,
        ).createShader(cap),
    );
  }

  /// Maps board coordinates (0-1 across, 0-1 deep) onto the island top in
  /// perspective: the far edge is narrower and higher.
  Offset _board(Offset top, double bw, double h, double u, double v) {
    final depth = h * 0.16;
    final widthAt = bw * (0.72 + 0.28 * v);
    return Offset(
      top.dx + (u - 0.5) * widthAt,
      top.dy - depth + v * depth * 0.95,
    );
  }

  Path _quad(
    Offset top,
    double bw,
    double h,
    double u0,
    double v0,
    double u1,
    double v1,
  ) {
    final a = _board(top, bw, h, u0, v0);
    final b = _board(top, bw, h, u1, v0);
    final c = _board(top, bw, h, u1, v1);
    final d = _board(top, bw, h, u0, v1);
    return Path()..addPolygon([a, b, c, d], true);
  }

  /// The Ludo board on the island: still.
  void _ludoBoard(Canvas canvas, Offset top, double iw, double h) {
    final bw = iw * 0.62;
    canvas.drawPath(
      _quad(top, bw, h, -0.04, -0.06, 1.04, 1.06),
      Paint()..color = const Color(0xFF241A4D),
    );
    canvas.drawPath(
      _quad(top, bw, h, 0, 0, 1, 1),
      Paint()..color = const Color(0xFFFFFBF4),
    );
    const yards = [
      (0.0, 0.0, _green),
      (0.6, 0.0, _yellow),
      (0.0, 0.6, _red),
      (0.6, 0.6, _blue),
    ];
    for (final (u, v, c) in yards) {
      canvas.drawPath(
        _quad(top, bw, h, u, v, u + 0.4, v + 0.4),
        Paint()..color = c,
      );
      canvas.drawPath(
        _quad(top, bw, h, u + 0.08, v + 0.08, u + 0.32, v + 0.32),
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
    }
    // Home stretches and the center.
    canvas.drawPath(
      _quad(top, bw, h, 0.4, 0.4, 0.6, 0.6),
      Paint()..color = style.glow,
    );
    for (final (u0, v0, u1, v1, c) in const [
      (0.07, 0.46, 0.4, 0.54, _red),
      (0.46, 0.07, 0.54, 0.4, _green),
      (0.6, 0.46, 0.93, 0.54, _yellow),
      (0.46, 0.6, 0.54, 0.93, _blue),
    ]) {
      canvas.drawPath(
        _quad(top, bw, h, u0, v0, u1, v1),
        Paint()..color = c.withValues(alpha: 0.75),
      );
    }
  }

  void _ludo(Canvas canvas, Offset top, double iw, double h, double t) {
    final bw = iw * 0.62;

    // Pieces hopping around the track, one square at a time.
    const ring = [
      (0.45, 0.95),
      (0.45, 0.75),
      (0.45, 0.6),
      (0.3, 0.55),
      (0.1, 0.55),
      (0.05, 0.45),
      (0.1, 0.42),
      (0.3, 0.42),
      (0.42, 0.3),
      (0.42, 0.1),
      (0.5, 0.04),
      (0.58, 0.1),
      (0.58, 0.3),
      (0.7, 0.42),
      (0.9, 0.42),
      (0.95, 0.5),
      (0.9, 0.58),
      (0.7, 0.58),
      (0.58, 0.7),
      (0.58, 0.9),
      (0.5, 0.96),
    ];
    final pieces = [
      (_red, 0.0),
      (_green, 0.27),
      (_yellow, 0.52),
      (_blue, 0.77),
    ];
    final hopping = <(double, Offset, Color, double)>[];
    for (final (color, offset) in pieces) {
      final s = (t * 1.6 + offset * ring.length) % ring.length;
      final i = s.floor();
      final f = s - i;
      final a = ring[i];
      final b = ring[(i + 1) % ring.length];
      final hop = Curves.easeInOut.transform(f);
      final pos = _board(
        top,
        bw,
        h,
        a.$1 + (b.$1 - a.$1) * hop,
        a.$2 + (b.$2 - a.$2) * hop,
      );
      hopping.add((pos.dy, pos, color, math.sin(f * math.pi)));
    }
    hopping.sort((x, y) => x.$1.compareTo(y.$1));
    for (final (_, pos, color, lift) in hopping) {
      _pin(canvas, pos, h * 0.13, color, lift * h * 0.06);
    }

    // A die tumbling above the board.
    final dieCenter = Offset(
      top.dx + bw * 0.42,
      top.dy - h * 0.48 + math.sin(t * 2.2) * h * 0.04,
    );
    _cube(canvas, dieCenter, h * 0.13, t * 1.6);
  }

  void _pin(Canvas canvas, Offset ground, double s, Color color, double lift) {
    canvas.drawOval(
      Rect.fromCenter(center: ground, width: s * 0.7, height: s * 0.22),
      Paint()..color = Colors.black.withValues(alpha: 0.3),
    );
    final g = ground.translate(0, -lift);
    final body = Path()
      ..moveTo(g.dx - s * 0.3, g.dy)
      ..quadraticBezierTo(
        g.dx - s * 0.18,
        g.dy - s * 0.35,
        g.dx - s * 0.08,
        g.dy - s * 0.55,
      )
      ..lineTo(g.dx + s * 0.08, g.dy - s * 0.55)
      ..quadraticBezierTo(
        g.dx + s * 0.18,
        g.dy - s * 0.35,
        g.dx + s * 0.3,
        g.dy,
      )
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Color.lerp(color, Colors.white, 0.4)!,
            color,
            Color.lerp(color, Colors.black, 0.3)!,
          ],
        ).createShader(body.getBounds()),
    );
    final head = g.translate(0, -s * 0.7);
    canvas.drawCircle(
      head,
      s * 0.2,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.4),
          colors: [
            Color.lerp(color, Colors.white, 0.7)!,
            color,
            Color.lerp(color, Colors.black, 0.3)!,
          ],
        ).createShader(Rect.fromCircle(center: head, radius: s * 0.2)),
    );
  }

  /// A small die drawn in 3D, turning about its vertical axis.
  void _cube(Canvas canvas, Offset c, double s, double angle) {
    const tilt = 0.5;
    Offset project(double x, double y, double z) {
      final ca = math.cos(angle), sa = math.sin(angle);
      final rx = x * ca + z * sa;
      final rz = -x * sa + z * ca;
      final ct = math.cos(tilt), st = math.sin(tilt);
      final ry = y * ct - rz * st;
      return c + Offset(rx, ry) * s;
    }

    // A cube is convex, so culling faces that point away (by their winding
    // on screen, see _facing) is all the depth handling it needs.
    final faces = <(List<(double, double, double)>, int)>[];
    void face(List<(double, double, double)> pts, int pips) =>
        faces.add((pts, pips));

    face([(-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1)], 1);
    for (var k = 0; k < 4; k++) {
      final a = k * math.pi / 2;
      final nx = math.sin(a), nz = -math.cos(a);
      final px = math.cos(a), pz = math.sin(a);
      face([
        (nx - px, -1, nz - pz),
        (nx + px, -1, nz + pz),
        (nx + px, 1, nz + pz),
        (nx - px, 1, nz - pz),
      ], k + 2);
    }
    final visible = [
      for (final f in faces)
        if (_facing(f.$1, project)) f,
    ];
    for (final (pts, pips) in visible) {
      final poly = [
        for (final (x, y, z) in pts) project(x * 0.5, y * 0.5, z * 0.5),
      ];
      final shade = (pts.first.$2 == -1 && pts[2].$2 == -1) ? 1.0 : 0.82;
      canvas.drawPath(
        Path()..addPolygon(poly, true),
        Paint()
          ..color = Color.lerp(const Color(0xFFD3C6EC), Colors.white, shade)!,
      );
      canvas.drawPath(
        Path()..addPolygon(poly, true),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFFFFC94D),
      );
      final center = poly.reduce((a, b) => a + b) / 4;
      final dot = Paint()..color = const Color(0xFF241C3B);
      for (var p = 0; p < math.min(pips, 4); p++) {
        final o = pips == 1
            ? Offset.zero
            : Offset(
                (p.isEven ? -1 : 1) * 0.18,
                (p < 2 ? -1 : 1) * 0.18 * (pips > 2 ? 1 : 0),
              );
        final onFace =
            center + (poly[1] - poly[0]) * o.dx + (poly[3] - poly[0]) * o.dy;
        canvas.drawCircle(onFace, s * 0.07, dot);
      }
    }
  }

  bool _facing(
    List<(double, double, double)> pts,
    Offset Function(double, double, double) project,
  ) {
    final a = project(pts[0].$1, pts[0].$2, pts[0].$3);
    final b = project(pts[1].$1, pts[1].$2, pts[1].$3);
    final c = project(pts[2].$1, pts[2].$2, pts[2].$3);
    // Counter-clockwise on screen means facing the viewer.
    return (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx) > 0;
  }

  /// The chessboard on the island: still.
  void _chessBoard(Canvas canvas, Offset top, double iw, double h) {
    final bw = iw * 0.66;
    const cols = 6;
    const rows = 4;
    canvas.drawPath(
      _quad(top, bw, h, -0.04, -0.08, 1.04, 1.08),
      Paint()..color = const Color(0xFF241A4D),
    );
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final light = (r + c).isEven;
        canvas.drawPath(
          _quad(top, bw, h, c / cols, r / rows, (c + 1) / cols, (r + 1) / rows),
          Paint()
            ..color = light
                ? const Color(0xFFEFDFAE)
                : Color.lerp(const Color(0xFF2E2260), accent, 0.35)!,
        );
      }
    }
  }

  void _chess(Canvas canvas, Offset top, double iw, double h, double t) {
    final bw = iw * 0.66;
    const cols = 6;
    const rows = 4;
    Offset cell(double c, double r) =>
        _board(top, bw, h, (c + 0.5) / cols, (r + 0.5) / rows);

    final style = ChessPieceStyle.byId('classic');
    final white = style.white;
    final black = style.black;
    final size = h * 0.4;
    void piece(
      PieceType type,
      Offset ground,
      ChessPieceFinish finish, {
      double lift = 0,
      double sway = 0,
    }) {
      canvas.drawOval(
        Rect.fromCenter(center: ground, width: size * 0.5, height: size * 0.14),
        Paint()..color = Colors.black.withValues(alpha: 0.3),
      );
      canvas.save();
      canvas.translate(ground.dx, ground.dy - lift);
      canvas.rotate(sway);
      // The art stands on y = 93 of its 100-unit box.
      canvas.translate(-size / 2, -size * 0.93);
      ChessPieceArtPainter(
        type: type,
        finish: finish,
      ).paint(canvas, Size.square(size));
      canvas.restore();
    }

    // The knight hops an L: two squares over, one across, and back.
    final k = (t * 0.7) % 2.0;
    final going = k < 1;
    final f = Curves.easeInOut.transform(going ? k : k - 1);
    final from = going ? cell(1, 1) : cell(3, 2);
    final to = going ? cell(3, 2) : cell(1, 1);
    final knightAt = Offset.lerp(from, to, f)!;

    final pieces = <(double, VoidCallback)>[
      (
        cell(4, 0).dy,
        () => piece(
          PieceType.king,
          cell(4, 0),
          black,
          sway: math.sin(t * 1.3) * 0.06,
        ),
      ),
      (
        cell(2, 0).dy,
        () => piece(
          PieceType.queen,
          cell(2, 0),
          black,
          sway: math.sin(t * 1.3 + 1) * 0.06,
        ),
      ),
      (cell(0, 3).dy, () => piece(PieceType.pawn, cell(0, 3), white)),
      (
        cell(5, 3).dy,
        () => piece(
          PieceType.king,
          cell(5, 3),
          white,
          sway: math.sin(t * 1.1) * 0.05,
        ),
      ),
      (
        knightAt.dy,
        () => piece(
          PieceType.knight,
          knightAt,
          white,
          lift: math.sin(f * math.pi) * h * 0.2,
        ),
      ),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    for (final (_, paint) in pieces) {
      paint();
    }
  }

  /// The checkerboard on the island: still.
  void _checkersBoard(Canvas canvas, Offset top, double iw, double h) {
    final bw = iw * 0.66;
    const cols = 6;
    const rows = 4;
    canvas.drawPath(
      _quad(top, bw, h, -0.04, -0.08, 1.04, 1.08),
      Paint()..color = const Color(0xFF3A1F2E),
    );
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final light = (r + c).isEven;
        canvas.drawPath(
          _quad(top, bw, h, c / cols, r / rows, (c + 1) / cols, (r + 1) / rows),
          Paint()
            ..color = light
                ? const Color(0xFFEFDFAE)
                : Color.lerp(const Color(0xFF45368C), accent, 0.3)!,
        );
      }
    }
  }

  void _checkers(Canvas canvas, Offset top, double iw, double h, double t) {
    final bw = iw * 0.66;
    const cols = 6;
    const rows = 4;
    Offset cell(double c, double r) =>
        _board(top, bw, h, (c + 0.5) / cols, (r + 0.5) / rows);
    double radius(double r) =>
        bw / cols * 0.44 * (0.72 + 0.28 * (r + 0.5) / rows);

    final dark = checkersFinish('classic', CheckersSide.dark);
    final light = checkersFinish('classic', CheckersSide.light);
    const squash = 0.68;
    final draws = <(double, VoidCallback)>[];
    void disc(
      double c,
      double r,
      ChessPieceFinish finish, {
      bool king = false,
      double lift = 0,
      double scale = 1,
      double spin = 0,
    }) {
      if (scale <= 0.01) return;
      final ground = cell(c, r);
      final rad = radius(r) * scale;
      // One sitting still on a square: always the same disc, so from
      // pixels in a browser (see [_still]).
      final sitting =
          lift == 0 &&
          scale == 1 &&
          spin == 0 &&
          c == c.roundToDouble() &&
          r == r.roundToDouble();
      if (sitting) {
        draws.add((
          ground.dy,
          () => _still(
            canvas,
            ('disc', identical(finish, dark), king, rad),
            Rect.fromCircle(center: Offset.zero, radius: rad * 2.6),
            ground,
            (canvas) {
              canvas.scale(1, squash);
              paintCheckersDisc(
                canvas,
                Offset.zero,
                rad,
                finish: finish,
                king: king,
              );
            },
          ),
        ));
        return;
      }
      draws.add((
        ground.dy,
        () {
          canvas.save();
          canvas.translate(ground.dx, ground.dy - lift);
          canvas.rotate(spin);
          canvas.scale(1, squash);
          paintCheckersDisc(
            canvas,
            Offset.zero,
            rad,
            finish: finish,
            king: king,
            ground: lift > 0 ? Offset(0, lift / squash) : null,
          );
          canvas.restore();
        },
      ));
    }

    // A five-second loop: two jumps, a rest, the taken pieces come back,
    // and the king glides home.
    final k = (t * 0.9) % 5.0;
    const hops = [(0.0, 3.0), (2.0, 1.0), (4.0, 3.0)];
    var kc = 0.0, kr = 3.0, lift = 0.0;
    if (k < 1.2) {
      final i = k < 0.6 ? 0 : 1;
      final f = Curves.easeInOut.transform((k - i * 0.6) / 0.6);
      kc = hops[i].$1 + (hops[i + 1].$1 - hops[i].$1) * f;
      kr = hops[i].$2 + (hops[i + 1].$2 - hops[i].$2) * f;
      lift = math.sin(f * math.pi) * h * 0.2;
    } else if (k < 3.0) {
      (kc, kr) = (4, 3);
      lift = math.max(0.0, math.sin((k - 1.2) * 7)) * h * 0.03;
    } else if (k < 4.0) {
      final f = Curves.easeInOut.transform(k - 3.0);
      kc = 4 - 4 * f;
      lift = math.sin(f * math.pi) * h * 0.12;
    }

    // The two pieces it takes: they pop as it passes, and grow back.
    double victim(double hit) {
      if (k < hit) return 1;
      if (k < hit + 0.3) return 1 - (k - hit) / 0.3;
      if (k < 2.4) return 0;
      if (k < 2.9) return Curves.elasticOut.transform((k - 2.4) / 0.5);
      return 1;
    }

    disc(1, 2, light, scale: victim(0.3), spin: k < 0.6 ? 0 : (k - 0.3) * 4);
    disc(3, 2, light, scale: victim(0.9), spin: k < 1.2 ? 0 : (k - 0.9) * 4);
    disc(1, 0, light);
    disc(5, 0, light);
    disc(3, 0, light, king: true);
    disc(5, 2, dark);
    disc(kc, kr, dark, king: true, lift: lift);
    draws.sort((a, b) => a.$1.compareTo(b.$1));
    for (final (_, paint) in draws) {
      paint();
    }
  }

  /// A card table: a hand of cards fanned at the back, the deck to one
  /// side and the pile to the other. Every couple of seconds a card lifts
  /// out of the hand, flips and sails onto the pile; every fourth one is a
  /// wild eight, which flashes its suit.
  /// The card table's felt and the deck on it: still.
  /// The pool table on the island: a wooden frame, the felt in the
  /// world's accent, six pockets. Still.
  void _poolTable(Canvas canvas, Offset top, double iw, double h) {
    final bw = iw * 0.7;
    canvas.drawPath(
      _quad(top, bw, h, -0.07, -0.16, 1.07, 1.16),
      Paint()..color = const Color(0xFF4A2A18),
    );
    canvas.drawPath(
      _quad(top, bw, h, -0.05, -0.12, 1.05, 1.12),
      Paint()..color = const Color(0xFF6B3D22),
    );
    final felt = HSLColor.fromColor(accent);
    final cloth = felt.withSaturation(math.min(0.6, felt.saturation)).withLightness(0.34).toColor();
    canvas.drawPath(
      _quad(top, bw, h, 0, 0, 1, 1),
      Paint()..color = cloth,
    );
    canvas.drawPath(
      _quad(top, bw, h, 0.06, 0.12, 0.94, 0.88),
      Paint()..color = Color.lerp(cloth, Colors.white, 0.06)!,
    );
    final hole = Paint()..color = const Color(0xFF120A08);
    for (final (u, v) in const [(0.0, 0.0), (0.5, -0.03), (1.0, 0.0), (0.0, 1.0), (0.5, 1.03), (1.0, 1.0)]) {
      final at = _board(top, bw, h, u, v);
      final w = bw * 0.045 * (0.75 + 0.25 * v);
      canvas.drawOval(Rect.fromCenter(center: at, width: w * 2, height: w * 1.2), hole);
    }
  }

  /// A break, over and over: the cue draws back and strikes, the white
  /// runs into the rack, the rack jumps and one ball rolls into a pocket.
  void _pool(Canvas canvas, Offset top, double iw, double h, double t) {
    final bw = iw * 0.7;
    const period = 3.4;
    final f = (t % period) / period;
    Offset at(double u, double v) => _board(top, bw, h, u, v);
    double radius(double v) => bw * 0.03 * (0.75 + 0.25 * v);

    void ball(double u, double v, Color color, {bool stripe = false}) {
      final c = at(u, v);
      final r = radius(v);
      canvas.drawOval(
        Rect.fromCenter(center: c.translate(r * 0.2, r * 0.5), width: r * 2.2, height: r * 0.9),
        Paint()..color = Colors.black.withValues(alpha: 0.3),
      );
      final rect = Rect.fromCircle(center: c, radius: r);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.45),
            colors: [Color.lerp(stripe ? Colors.white : color, Colors.white, 0.45)!, stripe ? Colors.white : color, Color.lerp(color, Colors.black, 0.35)!],
            stops: const [0, 0.5, 1],
          ).createShader(rect),
      );
      if (stripe) {
        canvas.save();
        canvas.clipPath(Path()..addOval(rect));
        canvas.drawRect(Rect.fromCenter(center: c, width: r * 2, height: r * 0.9), Paint()..color = color);
        canvas.restore();
      }
    }

    // The rack, at the far right; after the hit it jumps a little apart.
    final hit = ((f - 0.42) / 0.12).clamp(0.0, 1.0);
    final spread = Curves.easeOut.transform(hit) * (1 - Curves.easeIn.transform(((f - 0.7) / 0.3).clamp(0.0, 1.0)));
    const rack = [
      (0, 0.0, _red),
      (1, -0.5, _blue),
      (1, 0.5, _yellow),
      (2, -1.0, Color(0xFF16141C)),
      (2, 0.0, _green),
      (2, 1.0, Color(0xFFFF7A1A)),
    ];
    for (final (row, side, color) in rack) {
      final u = 0.68 + row * 0.055 + spread * (0.02 + row * 0.03);
      final v = 0.5 + side * 0.11 * (1 + spread * 0.9);
      ball(u, v, color, stripe: row == 2 && side > 0);
    }

    // One ball off the rack and into the far corner pocket.
    final run = ((f - 0.48) / 0.3).clamp(0.0, 1.0);
    if (run > 0 && run < 1) {
      final k = Curves.easeOut.transform(run);
      ball(0.84 + k * 0.16, 0.5 - k * 0.5, const Color(0xFF7A3FD1));
    }

    // The white: still until the strike, then into the rack, and back for
    // the next break while the table resets.
    final roll = ((f - 0.3) / 0.13).clamp(0.0, 1.0);
    final back = ((f - 0.82) / 0.18).clamp(0.0, 1.0);
    final cueU = 0.22 + Curves.easeIn.transform(roll) * 0.4 - Curves.easeInOut.transform(back) * 0.4;
    ball(cueU, 0.5, const Color(0xFFF7F4EC));

    // The cue: drawn back, then thrust in, then away after the strike.
    if (f < 0.42) {
      final draw = f < 0.26 ? math.sin(f / 0.26 * math.pi * 1.5).abs() : 0.0;
      final thrust = ((f - 0.26) / 0.04).clamp(0.0, 1.0);
      final gap = 0.04 + draw * 0.07 - thrust * 0.03;
      final tip = at(0.22 - gap, 0.5);
      final butt = at(-0.32 - gap, 0.62);
      final fade = f > 0.32 ? 1 - ((f - 0.32) / 0.1).clamp(0.0, 1.0) : 1.0;
      canvas.drawLine(
        tip,
        butt,
        Paint()
          ..shader = LinearGradient(
            colors: [const Color(0xFFF3E7CF), const Color(0xFFD9B98A), Color.lerp(accent, Colors.black, 0.4)!],
            stops: const [0, 0.55, 1],
          ).createShader(Rect.fromPoints(tip, butt))
          ..strokeWidth = h * 0.028
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: fade),
      );
      canvas.drawCircle(tip, h * 0.015, Paint()..color = const Color(0xFF4A7BD8).withValues(alpha: fade));
    }
  }

  void _eightsTable(Canvas canvas, Offset top, double iw, double h) {
    canvas.drawOval(
      Rect.fromCenter(
        center: top.translate(0, -h * 0.06),
        width: iw * 0.86,
        height: h * 0.3,
      ),
      Paint()..color = const Color(0xFF1F6B57),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: top.translate(0, -h * 0.07),
        width: iw * 0.78,
        height: h * 0.24,
      ),
      Paint()..color = const Color(0xFF2E9C7D),
    );
  }

  void _eights(Canvas canvas, Offset top, double iw, double h, double t) {
    final dpr =
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    final cw = (iw * 0.15).roundToDouble();
    const plays = [
      PlayingCard(7, CardSuit.hearts),
      PlayingCard(7, CardSuit.clubs),
      PlayingCard(12, CardSuit.clubs),
      PlayingCard(8, CardSuit.diamonds),
      PlayingCard(1, CardSuit.diamonds),
      PlayingCard(13, CardSuit.diamonds),
      PlayingCard(13, CardSuit.spades),
      PlayingCard(8, CardSuit.hearts),
    ];
    const period = 2.2;
    final n = (t / period).floor();
    final f = (t % period) / period;
    final playing = plays[n % plays.length];
    final under = plays[(n - 1) % plays.length];
    final deck = top.translate(-iw * 0.24, -h * 0.07);
    final pile = top.translate(iw * 0.24, -h * 0.07);
    final hand = top.translate(0, -h * 0.34);

    for (var i = 0; i < 3; i++) {
      drawCard(
        canvas,
        null,
        at: deck.translate(-i * 1.2, -i * 1.6),
        width: cw * 0.9,
        dpr: dpr,
        angle: -0.08,
      );
    }
    drawCard(canvas, under, at: pile, width: cw, dpr: dpr, angle: 0.1);

    // The hand, fanned, bobbing a little.
    final fan = [
      const PlayingCard(1, CardSuit.spades),
      const PlayingCard(10, CardSuit.hearts),
      playing,
      const PlayingCard(4, CardSuit.clubs),
      const PlayingCard(11, CardSuit.diamonds),
    ];
    for (var i = 0; i < fan.length; i++) {
      if (i == 2 && f > 0.15) continue;
      final k = i - 2;
      final lift = i == 2 ? math.sin(f / 0.15 * math.pi / 2) * h * 0.05 : 0.0;
      drawCard(
        canvas,
        fan[i],
        at: hand.translate(
          k * cw * 0.55,
          k * k * cw * 0.06 - lift + math.sin(t * 2 + i) * 1.5,
        ),
        width: cw,
        dpr: dpr,
        angle: k * 0.16,
      );
    }

    // The card flying to the pile, turning as it goes.
    if (f > 0.15 && f < 0.6) {
      final p = Curves.easeInOut.transform((f - 0.15) / 0.45);
      final at =
          Offset.lerp(hand, pile, p)! -
          Offset(0, math.sin(p * math.pi) * h * 0.22);
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(p * math.pi * 2 + 0.1 * p);
      drawCard(canvas, playing, at: Offset.zero, width: cw, dpr: dpr);
      canvas.restore();
    } else if (f >= 0.6) {
      drawCard(canvas, playing, at: pile, width: cw, dpr: dpr, angle: -0.06);
      // A wild eight: its suit flashes over the pile.
      if (playing.isEight) {
        final b = ((f - 0.6) / 0.35).clamp(0.0, 1.0);
        final r = cw * (0.3 + 0.5 * Curves.easeOutBack.transform(b));
        canvas.drawCircle(
          pile,
          r,
          Paint()..color = Colors.white.withValues(alpha: 0.85 * (1 - b)),
        );
        drawSuit(
          canvas,
          playing.suit,
          pile,
          r * 1.2,
          color: suitColor(playing.suit).withValues(alpha: 1 - b),
        );
      }
    }
  }

  /// The easel on the island (legs, the paper, the ledge): still.
  void _easel(Canvas canvas, Offset top, double iw, double h) {
    final bw = math.min(iw * 0.42, h * 0.62);
    final bh = bw * 0.82;
    final board = Rect.fromCenter(
      center: top.translate(0, -h * 0.06 - bh / 2),
      width: bw,
      height: bh,
    );
    final wood = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = bw * 0.05;
    wood.color = const Color(0xFF7A4A24);
    canvas.drawLine(
      board.topCenter.translate(0, -bh * 0.08),
      top.translate(0, -h * 0.02),
      wood,
    );
    wood.color = const Color(0xFFB0743C);
    canvas.drawLine(
      board.topCenter.translate(0, -bh * 0.1),
      top.translate(-bw * 0.42, h * 0.02),
      wood,
    );
    canvas.drawLine(
      board.topCenter.translate(0, -bh * 0.1),
      top.translate(bw * 0.42, h * 0.02),
      wood,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        board.shift(const Offset(2, 3)),
        Radius.circular(bw * 0.04),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(board, Radius.circular(bw * 0.04)),
      Paint()..color = const Color(0xFFFFFDF7),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          board.left - bw * 0.06,
          board.bottom - bh * 0.02,
          bw * 1.12,
          bh * 0.08,
        ),
        Radius.circular(bw * 0.02),
      ),
      Paint()..color = const Color(0xFF9A6233),
    );
  }

  /// The cat's line, around the board's top-left corner, and its pieces
  /// measured: made once for a board's size, not each frame.
  static (double, double, List<PathMetric>, double)? _cat;
  static (List<PathMetric>, double) _catLines(double bw, double bh) {
    final made = _cat;
    if (made != null && made.$1 == bw && made.$2 == bh) {
      return (made.$3, made.$4);
    }
    // In board units (0-1).
    Offset at(double u, double v) => Offset(u * bw, v * bh);
    final cat = Path()
      ..moveTo(at(0.3, 0.42).dx, at(0.3, 0.42).dy)
      ..lineTo(at(0.33, 0.18).dx, at(0.33, 0.18).dy)
      ..lineTo(at(0.44, 0.32).dx, at(0.44, 0.32).dy)
      ..quadraticBezierTo(
        at(0.5, 0.3).dx,
        at(0.5, 0.3).dy,
        at(0.56, 0.32).dx,
        at(0.56, 0.32).dy,
      )
      ..lineTo(at(0.67, 0.18).dx, at(0.67, 0.18).dy)
      ..lineTo(at(0.7, 0.42).dx, at(0.7, 0.42).dy)
      ..quadraticBezierTo(
        at(0.76, 0.8).dx,
        at(0.76, 0.8).dy,
        at(0.5, 0.82).dx,
        at(0.5, 0.82).dy,
      )
      ..quadraticBezierTo(
        at(0.24, 0.8).dx,
        at(0.24, 0.8).dy,
        at(0.3, 0.42).dx,
        at(0.3, 0.42).dy,
      )
      ..addOval(Rect.fromCircle(center: at(0.41, 0.5), radius: bw * 0.03))
      ..addOval(Rect.fromCircle(center: at(0.59, 0.5), radius: bw * 0.03))
      ..moveTo(at(0.44, 0.64).dx, at(0.44, 0.64).dy)
      ..quadraticBezierTo(
        at(0.5, 0.7).dx,
        at(0.5, 0.7).dy,
        at(0.56, 0.64).dx,
        at(0.56, 0.64).dy,
      )
      ..moveTo(at(0.33, 0.6).dx, at(0.33, 0.6).dy)
      ..lineTo(at(0.14, 0.56).dx, at(0.14, 0.56).dy)
      ..moveTo(at(0.33, 0.66).dx, at(0.33, 0.66).dy)
      ..lineTo(at(0.15, 0.7).dx, at(0.15, 0.7).dy)
      ..moveTo(at(0.67, 0.6).dx, at(0.67, 0.6).dy)
      ..lineTo(at(0.86, 0.56).dx, at(0.86, 0.56).dy)
      ..moveTo(at(0.67, 0.66).dx, at(0.67, 0.66).dy)
      ..lineTo(at(0.85, 0.7).dx, at(0.85, 0.7).dy);
    final metrics = cat.computeMetrics().toList();
    final total = metrics.fold<double>(0, (a, m) => a + m.length);
    _cat = (bw, bh, metrics, total);
    return (metrics, total);
  }

  /// An easel with a cat being sketched on it, over and over: the pencil
  /// follows the line as it goes down, guesses bubble up beside it, and
  /// once the cat is done a green bubble with a check says someone got it.
  void _doodle(Canvas canvas, Offset top, double iw, double h, double t) {
    const cycle = 6.5;
    final k = (t % cycle) / cycle;
    final draw = (k / 0.68).clamp(0.0, 1.0);

    final bw = math.min(iw * 0.42, h * 0.62);
    final bh = bw * 0.82;
    final board = Rect.fromCenter(
      center: top.translate(0, -h * 0.06 - bh / 2),
      width: bw,
      height: bh,
    );

    // The cat, drawn up to [draw] of its length.
    final (metrics, total) = _catLines(bw, bh);
    var left = total * draw;
    final drawn = Path();
    Offset? tip;
    for (final m in metrics) {
      if (left <= 0) break;
      final len = math.min(left, m.length);
      drawn.addPath(m.extractPath(0, len), board.topLeft);
      final at = m.getTangentForOffset(len)?.position;
      tip = at == null ? null : at + board.topLeft;
      left -= len;
    }
    canvas.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = bw * 0.028
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF1F1E1B),
    );

    // The pencil, at the end of the line while it draws, then lifting off.
    final rest = board.bottomRight.translate(-bw * 0.08, -bh * 0.02);
    final lift = ((k - 0.68) / 0.12).clamp(0.0, 1.0);
    final pen = Offset.lerp(tip ?? rest, rest, lift)!;
    canvas.save();
    canvas.translate(pen.dx, pen.dy);
    canvas.rotate(-0.7);
    final pl = bw * 0.36;
    final pwid = bw * 0.07;
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(pwid / 2, -pl * 0.16)
        ..lineTo(-pwid / 2, -pl * 0.16)
        ..close(),
      Paint()..color = const Color(0xFFF2C79A),
    );
    canvas.drawCircle(
      Offset(0, -pl * 0.03),
      pwid * 0.18,
      Paint()..color = const Color(0xFF1F1E1B),
    );
    canvas.drawRect(
      Rect.fromLTWH(-pwid / 2, -pl * 0.86, pwid, pl * 0.7),
      Paint()..color = const Color(0xFFFFC93D),
    );
    canvas.drawRect(
      Rect.fromLTWH(-pwid / 2, -pl * 0.86, pwid * 0.35, pl * 0.7),
      Paint()..color = const Color(0xFFFFE08A),
    );
    canvas.drawRect(
      Rect.fromLTWH(-pwid / 2, -pl * 0.94, pwid, pl * 0.08),
      Paint()..color = const Color(0xFFC9CCD6),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-pwid / 2, -pl, pwid, pl * 0.07),
        Radius.circular(pwid * 0.3),
      ),
      Paint()..color = const Color(0xFFFF8FB8),
    );
    canvas.restore();

    // Guesses popping up beside the easel: two wrong, then the right one.
    void bubble(Offset c, double appear, bool right) {
      if (k < appear) return;
      final grow = Curves.elasticOut.transform(
        ((k - appear) / 0.12).clamp(0.0, 1.0),
      );
      final fade = k > 0.94 ? 1 - (k - 0.94) / 0.06 : 1.0;
      final r = h * 0.075 * grow;
      if (r <= 0.5) return;
      final p = c.translate(0, math.sin(t * 2.4 + c.dx) * h * 0.01);
      final fill = right ? const Color(0xFF2FD98E) : Colors.white;
      final paint = Paint()..color = fill.withValues(alpha: fade);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: p, width: r * 2.4, height: r * 1.7),
          Radius.circular(r * 0.8),
        ),
        paint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(p.dx - r * 0.5, p.dy + r * 0.7)
          ..lineTo(p.dx - r * 0.9, p.dy + r * 1.25)
          ..lineTo(p.dx - r * 0.05, p.dy + r * 0.75)
          ..close(),
        paint,
      );
      final ink = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = r * 0.24
        ..color = (right ? Colors.white : const Color(0xFF7B5CFF)).withValues(
          alpha: fade,
        );
      if (right) {
        canvas.drawPath(
          Path()
            ..moveTo(p.dx - r * 0.45, p.dy)
            ..lineTo(p.dx - r * 0.1, p.dy + r * 0.35)
            ..lineTo(p.dx + r * 0.5, p.dy - r * 0.35),
          ink,
        );
      } else {
        // A question mark.
        canvas.drawArc(
          Rect.fromCircle(center: p.translate(0, -r * 0.18), radius: r * 0.3),
          math.pi * 1.0,
          math.pi * 1.4,
          false,
          ink,
        );
        canvas.drawLine(
          p.translate(r * 0.02, r * 0.14),
          p.translate(0, r * 0.22),
          ink,
        );
        canvas.drawCircle(
          p.translate(0, r * 0.5),
          r * 0.12,
          Paint()..color = ink.color,
        );
      }
    }

    bubble(board.centerLeft.translate(-bw * 0.36, -bh * 0.3), 0.22, false);
    bubble(board.centerRight.translate(bw * 0.36, -bh * 0.05), 0.42, false);
    bubble(board.topRight.translate(bw * 0.24, -bh * 0.04), 0.72, true);
  }

  @override
  bool shouldRepaint(covariant _DioramaPainter old) =>
      old.game != game || old.style != style || old.accent != accent;
}
