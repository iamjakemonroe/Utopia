import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/theme/utopia_themes.dart';
import '../domain/pool_physics.dart';
import '../domain/pool_rules.dart';
import 'pool_art.dart';
import 'pool_match_controller.dart';

/// Where the table sits on screen: [scale] logical pixels to a table unit,
/// its top-left, and whether it stands [upright] (on a phone held upright:
/// the long side up the screen, the kitchen at the bottom).
class PoolTableGeometry {
  PoolTableGeometry(Size size)
    : upright = size.height > size.width * 1.05,
      scale = _scale(size),
      origin = Offset.zero {
    final w = (upright ? _short : _long) * scale, h = (upright ? _long : _short) * scale;
    origin = Offset((size.width - w) / 2, (size.height - h) / 2);
  }

  static const _long = kPoolLength + 2 * kTableMargin;
  static const _short = kPoolWidth + 2 * kTableMargin;

  static double _scale(Size size) => size.height > size.width * 1.05
      ? math.min(size.width / _short, size.height / _long)
      : math.min(size.width / _long, size.height / _short);

  final bool upright;
  final double scale;
  Offset origin;

  /// Table point to screen.
  Offset toScreen(double x, double y) => upright
      ? origin + Offset((y + kTableMargin) * scale, (kPoolLength + kTableMargin - x) * scale)
      : origin + Offset((x + kTableMargin) * scale, (y + kTableMargin) * scale);

  /// Screen point to table.
  (double, double) toTable(Offset p) {
    final q = p - origin;
    return upright
        ? (kPoolLength + kTableMargin - q.dy / scale, q.dx / scale - kTableMargin)
        : (q.dx / scale - kTableMargin, q.dy / scale - kTableMargin);
  }

  /// A table direction on screen.
  Offset direction(double dx, double dy) => upright ? Offset(dy, -dx) : Offset(dx, dy);
}

/// The table in play: the still table (drawn once), the balls and the cue
/// (each frame), and the player's hand on it: drag to aim, drag the cue
/// ball when it's in hand, tap a pocket to call it.
class PoolTableView extends StatefulWidget {
  const PoolTableView({super.key, required this.controller, required this.art});

  final PoolMatchController controller;
  final PoolBallArt art;

  @override
  State<PoolTableView> createState() => _PoolTableViewState();
}

class _PoolTableViewState extends State<PoolTableView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  bool _draggingCue = false;

  PoolMatchController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_changed);
  }

  @override
  void didUpdateWidget(PoolTableView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      _c.addListener(_changed);
    }
  }

  /// A shot playing runs the ticker; otherwise nothing moves on its own.
  void _changed() {
    if (_c.playing != null && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (_c.playing == null && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero ? 1 / 60 : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _c.advance(dt.clamp(0.0, 0.05));
  }

  @override
  void dispose() {
    _c.removeListener(_changed);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = PoolPalette(UtopiaThemes.active);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        final geo = PoolTableGeometry(box.biggest);
        final table = PoolTableImage.of(geo.scale, dpr, palette);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => _down(geo, d.localPosition),
          onPanUpdate: (d) => _move(geo, d.localPosition),
          onPanEnd: (_) => _draggingCue = false,
          onTapUp: (d) => _tap(geo, d.localPosition),
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: CustomPaint(painter: _StillTable(geo, table)),
              ),
              CustomPaint(
                painter: _Play(_c, geo, widget.art, dpr, palette),
              ),
            ],
          ),
        );
      },
    );
  }

  void _down(PoolTableGeometry geo, Offset p) {
    final (x, y) = geo.toTable(p);
    final b = _c.shown;
    final dx = x - b.x[kCueBall], dy = y - b.y[kCueBall];
    _draggingCue = _c.placing && dx * dx + dy * dy < math.pow(kBallRadius * 3.5, 2);
    if (!_draggingCue) _aim(x, y);
  }

  void _move(PoolTableGeometry geo, Offset p) {
    final (x, y) = geo.toTable(p);
    if (_draggingCue) {
      final cx = _c.game.hand == PoolHand.kitchen ? math.min(x, kHeadString) : x;
      _c.placeCue(
        cx.clamp(kBallRadius, kPoolLength - kBallRadius),
        y.clamp(kBallRadius, kPoolWidth - kBallRadius),
      );
    } else {
      _aim(x, y);
    }
  }

  void _tap(PoolTableGeometry geo, Offset p) {
    final (x, y) = geo.toTable(p);
    if (_c.canPlay && _c.game.callsPocket) {
      for (var i = 0; i < kPockets.length; i++) {
        final dx = x - kPockets[i].x, dy = y - kPockets[i].y;
        if (dx * dx + dy * dy < 0.13 * 0.13) {
          _c.callPocket(i);
          return;
        }
      }
    }
    _aim(x, y);
  }

  void _aim(double x, double y) {
    if (_c.canPlay) _c.aimAt(x, y);
  }
}

/// The still table: one picture of pixels, turned upright on a phone.
class _StillTable extends CustomPainter {
  _StillTable(this.geo, this.table);

  final PoolTableGeometry geo;
  final PoolTableImage table;

  @override
  void paint(Canvas canvas, Size size) {
    final image = table.image;
    final w = (kPoolLength + 2 * kTableMargin) * geo.scale;
    final h = (kPoolWidth + 2 * kTableMargin) * geo.scale;
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final paint = Paint()..filterQuality = FilterQuality.medium;
    canvas.save();
    if (geo.upright) {
      canvas.translate(geo.origin.dx, geo.origin.dy + w);
      canvas.rotate(-math.pi / 2);
    } else {
      canvas.translate(geo.origin.dx, geo.origin.dy);
    }
    canvas.drawImageRect(image, src, Rect.fromLTWH(0, 0, w, h), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StillTable old) => old.table != table || old.geo.scale != geo.scale || old.geo.origin != geo.origin;
}

/// What moves: the balls, the aim, the cue, the called pocket.
class _Play extends CustomPainter {
  _Play(this.c, this.geo, this.art, this.dpr, this.palette) : super(repaint: c);

  final PoolMatchController c;
  final PoolTableGeometry geo;
  final PoolBallArt art;
  final double dpr;
  final PoolPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final s = geo.scale;
    final b = c.shown;
    final r = kBallRadius * s;
    final game = c.game;

    // Pockets to call: glowing, the called one bright.
    if ((c.canPlay || c.chipBusy) && game.callsPocket) {
      for (var i = 0; i < kPockets.length; i++) {
        final p = geo.toScreen(kPockets[i].x, kPockets[i].y);
        final on = c.called == i;
        canvas.drawCircle(
          p,
          kPockets[i].radius * s * (on ? 1.5 : 1.3),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = on ? 3 : 1.5
            ..color = (on ? palette.trimBright : Colors.white).withValues(alpha: on ? 0.95 : 0.4),
        );
      }
    }

    // Ball in hand: a ring round the cue ball, inviting a drag.
    if (c.placing && b.on[kCueBall]) {
      canvas.drawCircle(
        geo.toScreen(b.x[kCueBall], b.y[kCueBall]),
        r * 2.2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = Colors.white.withValues(alpha: 0.55),
      );
    }

    // The aiming guide, for the player shooting.
    final aiming = c.canPlay && b.on[kCueBall];
    if (aiming) _guide(canvas, b, s);

    for (var i = 0; i < kBalls; i++) {
      if (!b.on[i]) continue;
      art.draw(canvas, i, geo.toScreen(b.x[i], b.y[i]), r, c.spin, dpr);
    }

    // The cue, behind the cue ball, pulled back as hard as the shot.
    if ((aiming || c.chipBusy) && c.playing == null && b.on[kCueBall]) _cue(canvas, b, s);
  }

  void _guide(Canvas canvas, PoolBalls b, double s) {
    final aim = c.aim;
    final from = geo.toScreen(b.x[kCueBall], b.y[kCueBall]);
    final ghost = geo.toScreen(aim.gx, aim.gy);
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    // Dotted, from the cue ball to the ghost ball.
    final d = ghost - from;
    final len = d.distance;
    if (len > 1) {
      final u = d / len;
      for (var t = kBallRadius * s * 1.4; t < len - kBallRadius * s; t += 9) {
        canvas.drawLine(from + u * t, from + u * math.min(t + 4.5, len), line);
      }
    }
    final r = kBallRadius * s;
    canvas.drawCircle(
      ghost,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.white.withValues(alpha: 0.85),
    );
    final target = aim.target;
    if (target == null) return;
    // Where the object ball goes (longer the fuller the hit), and where
    // the cue ball glances off.
    final legal = c.game.targets.contains(target);
    final o = geo.toScreen(b.x[target], b.y[target]);
    final od = geo.direction(aim.ox, aim.oy);
    canvas.drawLine(
      o,
      o + od * s * (0.08 + 0.32 * aim.fullness),
      Paint()
        ..color = (legal ? Colors.white : const Color(0xFFFF6B6B)).withValues(alpha: 0.85)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
    if (!legal) {
      // Not theirs to hit: a cross on the ghost ball.
      final x = r * 0.6;
      final red = Paint()
        ..color = const Color(0xFFFF6B6B)
        ..strokeWidth = 2;
      canvas.drawLine(ghost.translate(-x, -x), ghost.translate(x, x), red);
      canvas.drawLine(ghost.translate(x, -x), ghost.translate(-x, x), red);
    }
    final cd = geo.direction(aim.cx, aim.cy);
    canvas.drawLine(
      ghost,
      ghost + cd * s * (0.04 + 0.14 * (1 - aim.fullness)),
      line..color = Colors.white.withValues(alpha: 0.45),
    );
  }

  void _cue(Canvas canvas, PoolBalls b, double s) {
    final cue = geo.toScreen(b.x[kCueBall], b.y[kCueBall]);
    final dir = geo.direction(c.aimX, c.aimY);
    final back = Offset(-dir.dx, -dir.dy);
    final side = Offset(-dir.dy, dir.dx);
    final gap = (kBallRadius * 1.25 + 0.02 + c.power * 0.2) * s;
    final length = 1.15 * s;
    final tip = cue + back * gap;
    final butt = tip + back * length;
    final tipW = 0.0055 * s, buttW = 0.014 * s;
    final shape = Path()
      ..moveTo((tip + side * tipW).dx, (tip + side * tipW).dy)
      ..lineTo((butt + side * buttW).dx, (butt + side * buttW).dy)
      ..lineTo((butt - side * buttW).dx, (butt - side * buttW).dy)
      ..lineTo((tip - side * tipW).dx, (tip - side * tipW).dy)
      ..close();
    canvas.drawPath(
      shape.shift(Offset(s * 0.012, s * 0.018)),
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );
    canvas.drawPath(
      shape,
      Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFFF3E7CF),
            const Color(0xFFE0C79A),
            const Color(0xFF9A6A3A),
            const Color(0xFF3B2416),
          ],
          stops: const [0, 0.55, 0.62, 1],
        ).createShader(Rect.fromPoints(tip, butt)),
    );
    // The tip, a gold ferrule and a trim band near the butt.
    canvas.drawCircle(tip, tipW * 1.1, Paint()..color = const Color(0xFF4A7BD8));
    final ring = Paint()
      ..color = palette.trimBright
      ..strokeWidth = buttW * 1.4;
    final at = tip + back * (length * 0.6);
    canvas.drawLine(at - side * buttW * 0.75, at + side * buttW * 0.75, ring);
  }

  @override
  bool shouldRepaint(_Play old) => true;
}
