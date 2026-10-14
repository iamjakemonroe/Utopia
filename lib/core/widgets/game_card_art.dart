import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../features/chess/domain/chess_types.dart';
import '../../features/chess/presentation/widgets/chess_piece_art.dart';
import '../../features/chess/presentation/widgets/chess_piece_styles.dart';
import '../../features/checkers/domain/checkers_engine.dart';
import '../../features/checkers/presentation/widgets/checkers_disc.dart';
import 'package:flutter/scheduler.dart';

import '../theme/utopia_themes.dart';
import 'ambient_tick.dart';

enum GameKind { chess, ludo, checkers, doodle }

/// A game's banner art: a little living diorama in the current world. A
/// floating island drifts in the theme's sky with the game set up on top:
/// for Ludo a mini board with pieces hopping around it and a die tumbling
/// overhead; for chess a checkered island where the knight hops in L-shapes
/// while the king and queen sway; for checkers a king double-jumping two
/// pieces, which pop and come back for another go; for Guess My Doodle an
/// easel where a pencil sketches a cat while guesses pop up around it, the
/// last one right. A waterfall spills off the edge and sparkles rise.
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
  late final Ticker _ticker = createTicker(
    ambientTick((elapsed) => _t.value = elapsed.inMicroseconds / 1e6),
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
          ),
        ),
      ),
    );
  }
}

class _DioramaPainter extends CustomPainter {
  _DioramaPainter({
    required this.clock,
    required this.game,
    required this.style,
    required this.accent,
  }) : super(repaint: clock);

  final ValueNotifier<double> clock;
  final GameKind game;
  final WorldStyle style;
  final Color accent;

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
    final sun = Offset(w * 0.86, h * 0.24);
    canvas.drawCircle(
      sun,
      h * 0.32,
      Paint()
        ..shader = RadialGradient(
          colors: [
            style.celestialColors[1].withValues(alpha: 0.4),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: sun, radius: h * 0.32)),
    );
    canvas.drawCircle(
      sun,
      h * 0.13,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: style.celestialColors,
          stops: const [0.0, 0.4, 0.8, 1.0],
        ).createShader(Rect.fromCircle(center: sun, radius: h * 0.13)),
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
    _island(canvas, top, iw, h, t);

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

  void _island(Canvas canvas, Offset top, double iw, double h, double t) {
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

  void _ludo(Canvas canvas, Offset top, double iw, double h, double t) {
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

  void _chess(Canvas canvas, Offset top, double iw, double h, double t) {
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

  void _checkers(Canvas canvas, Offset top, double iw, double h, double t) {
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

  /// An easel with a cat being sketched on it, over and over: the pencil
  /// follows the line as it goes down, guesses bubble up beside it, and
  /// once the cat is done a green bubble with a check says someone got it.
  void _doodle(Canvas canvas, Offset top, double iw, double h, double t) {
    const cycle = 6.5;
    final k = (t % cycle) / cycle;
    final draw = (k / 0.68).clamp(0.0, 1.0);

    // The easel: back leg, front legs, the paper, the ledge.
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

    // The cat, in board units (0-1), drawn up to [draw] of its length.
    Offset at(double u, double v) =>
        Offset(board.left + u * bw, board.top + v * bh);
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
    var left = total * draw;
    final drawn = Path();
    Offset? tip;
    for (final m in metrics) {
      if (left <= 0) break;
      final len = math.min(left, m.length);
      drawn.addPath(m.extractPath(0, len), Offset.zero);
      tip = m.getTangentForOffset(len)?.position;
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
