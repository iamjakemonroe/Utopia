import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/theme/utopia_themes.dart';
import '../domain/pool_physics.dart';
import '../domain/pool_rules.dart';
import 'pool_art.dart';
import 'pool_cue_art.dart';
import 'pool_match_controller.dart';

/// Where the table sits on screen: [scale] logical pixels to a table unit,
/// its top-left, and whether it stands [upright] (on a phone held upright:
/// the long side up the screen, the kitchen at the bottom).
class PoolTableGeometry {
  PoolTableGeometry(Size size)
    : upright = size.height > size.width * 1.05,
      scale = _scale(size),
      origin = Offset.zero {
    final w = (upright ? _short : _long) * scale,
        h = (upright ? _long : _short) * scale;
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
      ? origin +
            Offset(
              (y + kTableMargin) * scale,
              (kPoolLength + kTableMargin - x) * scale,
            )
      : origin + Offset((x + kTableMargin) * scale, (y + kTableMargin) * scale);

  /// Screen point to table.
  (double, double) toTable(Offset p) {
    final q = p - origin;
    return upright
        ? (
            kPoolLength + kTableMargin - q.dy / scale,
            q.dx / scale - kTableMargin,
          )
        : (q.dx / scale - kTableMargin, q.dy / scale - kTableMargin);
  }

  /// A table direction on screen.
  Offset direction(double dx, double dy) =>
      upright ? Offset(dy, -dx) : Offset(dx, dy);
}

/// The table in play: the still table (drawn once), and over it what
/// moves (the balls, the cue, the aim, the effects), each frame; and the
/// player's hand on it: drag to aim, drag the cue ball when it's in hand,
/// tap a pocket to call it.
class PoolTableView extends StatefulWidget {
  const PoolTableView({super.key, required this.controller, required this.art});

  final PoolMatchController controller;
  final PoolBallArt art;

  @override
  State<PoolTableView> createState() => _PoolTableViewState();
}

class _PoolTableViewState extends State<PoolTableView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _frame = ValueNotifier<int>(0);
  Duration _last = Duration.zero;
  bool _draggingCue = false;
  CueArt _cueArt = CueArt.plain;

  PoolMatchController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_changed);
    CueArt.load().then((art) {
      if (mounted) setState(() => _cueArt = art);
    });
    _changed();
  }

  @override
  void didUpdateWidget(PoolTableView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      _c.addListener(_changed);
      _changed();
    }
  }

  /// The ticker runs while something moves, or while an animated cue is
  /// out (it shimmers); otherwise nothing moves on its own.
  void _changed() {
    final live = _c.moving || (!_c.over && _c.shooterCue.animated);
    if (live && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!live && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _c.advance(dt.clamp(0.0, 0.05));
    _frame.value++;
    _changed();
  }

  @override
  void dispose() {
    _c.removeListener(_changed);
    _ticker.dispose();
    _frame.dispose();
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
                painter: _Play(
                  _c,
                  geo,
                  widget.art,
                  _cueArt,
                  dpr,
                  palette,
                  _frame,
                ),
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
    _draggingCue =
        _c.placing && dx * dx + dy * dy < math.pow(kBallRadius * 3.5, 2);
    if (!_draggingCue) _aim(x, y);
  }

  void _move(PoolTableGeometry geo, Offset p) {
    final (x, y) = geo.toTable(p);
    if (_draggingCue) {
      final cx = _c.game.hand == PoolHand.kitchen
          ? math.min(x, kHeadString)
          : x;
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
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
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
  bool shouldRepaint(_StillTable old) =>
      old.table != table ||
      old.geo.scale != geo.scale ||
      old.geo.origin != geo.origin;
}

/// What moves: the balls (and those dropping), the aim, the cue, the
/// called pocket, the effects.
class _Play extends CustomPainter {
  _Play(
    this.c,
    this.geo,
    this.art,
    this.cueArt,
    this.dpr,
    this.palette,
    Listenable frame,
  ) : super(repaint: Listenable.merge([c, frame]));

  final PoolMatchController c;
  final PoolTableGeometry geo;
  final PoolBallArt art;
  final CueArt cueArt;
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
      final pulse = 0.5 + 0.5 * math.sin(c.clock * 4);
      for (var i = 0; i < kPockets.length; i++) {
        final p = geo.toScreen(kPockets[i].x, kPockets[i].y);
        final on = c.called == i;
        canvas.drawCircle(
          p,
          kPockets[i].radius * s * (on ? 1.5 : 1.3 + 0.08 * pulse),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = on ? 3 : 1.5
            ..color = (on ? palette.trimBright : Colors.white).withValues(
              alpha: on ? 0.95 : 0.3 + 0.2 * pulse,
            ),
        );
      }
    }

    // Ball in hand: a ring round the cue ball, inviting a drag.
    if (c.placing && b.on[kCueBall]) {
      canvas.drawCircle(
        geo.toScreen(b.x[kCueBall], b.y[kCueBall]),
        r * (2.1 + 0.15 * math.sin(c.clock * 5)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = Colors.white.withValues(alpha: 0.6),
      );
    }

    // The aiming guide, for the player shooting.
    final aiming = c.canPlay && b.on[kCueBall];
    if (aiming) _guide(canvas, b, s);

    // The trail behind the cue ball under the balls, the balls (and those
    // dropping), then what flies off them.
    c.fx.paintTrail(canvas, geo.toScreen, r);
    for (final sink in c.sinks) {
      _sink(canvas, sink, r);
    }
    for (var i = 0; i < kBalls; i++) {
      if (!b.on[i]) continue;
      art.draw(canvas, i, geo.toScreen(b.x[i], b.y[i]), r, c.spin, dpr);
    }
    c.fx.paintBits(canvas, geo.toScreen, r);

    // The cue, behind the cue ball: drawn back as hard as the shot, in on
    // the strike, then fading as the balls run.
    final showCue =
        (aiming || c.chipBusy || c.striking != null) ||
        (c.playing != null && c.playTime < 0.3);
    if (showCue && (b.on[kCueBall] || c.playing != null)) _cue(canvas, s);
  }

  /// A ball dropping: drawn into the pocket, smaller and darker.
  void _sink(Canvas canvas, PoolSink sink, double r) {
    final k = Curves.easeIn.transform(sink.t.clamp(0.0, 1.0));
    final at = geo.toScreen(
      sink.x + (sink.px - sink.x) * k,
      sink.y + (sink.py - sink.y) * k,
    );
    art.draw(canvas, sink.ball, at, r * (1 - 0.55 * k), c.spin, dpr);
    canvas.drawCircle(
      at,
      r * (1 - 0.55 * k),
      Paint()..color = Colors.black.withValues(alpha: 0.7 * k),
    );
  }

  void _guide(Canvas canvas, PoolBalls b, double s) {
    final stats = c.shooterStats;
    final aim = c.aim;
    final from = geo.toScreen(b.x[kCueBall], b.y[kCueBall]);
    final ghost = geo.toScreen(aim.gx, aim.gy);
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    // Dotted, from the cue ball to the ghost ball.
    _dots(canvas, from, ghost, kBallRadius * s * 1.4, kBallRadius * s, line);
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
    if (target == null) {
      // Into a cushion: with a sharp enough eye (aim), where it goes off.
      if (stats.guideBounce) {
        var dx = c.aimX, dy = c.aimY;
        const edge = kBallRadius + 1e-3;
        if (aim.gx <= edge || aim.gx >= kPoolLength - edge) dx = -dx;
        if (aim.gy <= edge || aim.gy >= kPoolWidth - edge) dy = -dy;
        final reach = stats.guideReach * 0.9;
        final end = geo.toScreen(aim.gx + dx * reach, aim.gy + dy * reach);
        _dots(
          canvas,
          ghost,
          end,
          r * 1.2,
          0,
          line..color = Colors.white.withValues(alpha: 0.4),
        );
      }
      return;
    }
    // Where the object ball goes (the further the fuller the hit and the
    // keener the cue's aim), and where the cue ball glances off.
    final legal = c.game.targets.contains(target);
    final o = geo.toScreen(b.x[target], b.y[target]);
    final od = geo.direction(aim.ox, aim.oy);
    final reach = stats.guideReach * (0.3 + 0.7 * aim.fullness);
    canvas.drawLine(
      o,
      o + od * s * reach,
      Paint()
        ..color = (legal ? Colors.white : const Color(0xFFFF6B6B)).withValues(
          alpha: 0.85,
        )
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
    final glance = 0.04 + (0.08 + 0.3 * stats.aim / 100) * (1 - aim.fullness);
    canvas.drawLine(
      ghost,
      ghost + cd * s * glance,
      line..color = Colors.white.withValues(alpha: 0.45),
    );
  }

  /// A dotted line from [a] to [b], starting [skip] in and stopping [stop]
  /// short.
  static void _dots(
    Canvas canvas,
    Offset a,
    Offset b,
    double skip,
    double stop,
    Paint paint,
  ) {
    final d = b - a;
    final len = d.distance;
    if (len <= 1) return;
    final u = d / len;
    for (var t = skip; t < len - stop; t += 9) {
      canvas.drawLine(a + u * t, a + u * math.min(t + 4.5, len - stop), paint);
    }
  }

  void _cue(Canvas canvas, double s) {
    final cue = c.shooterCue;
    final level = c.shooterLevel;
    final b = c.shown;
    // Where it strikes from: the cue ball now, or (as it runs) where it
    // was hit from.
    final at = c.playing != null ? c.game.balls : b;
    if (!at.on[kCueBall]) return;
    final ball = geo.toScreen(at.x[kCueBall], at.y[kCueBall]);
    final dir = geo.direction(c.aimX, c.aimY);
    final back = Offset(-dir.dx, -dir.dy);
    final strike = c.striking;
    final pull = strike != null
        ? c.strikeFrom * (1 - Curves.easeIn.transform(strike))
        : c.playing != null
        ? 0.0
        : c.power;
    final gap =
        (kBallRadius * 1.04 +
            (0.022 + pull * 0.2) *
                (strike == null && c.playing != null ? 0 : 1)) *
        s;
    final opacity = c.playing != null
        ? (1 - c.playTime / 0.3).clamp(0.0, 1.0)
        : 1.0;
    cueArt.draw(
      canvas,
      cue,
      level,
      tip: ball + back * gap,
      back: back,
      length: 1.15 * s,
      thick: 0.0135 * s,
      time: c.clock,
      dpr: dpr,
      opacity: opacity,
    );
  }

  @override
  bool shouldRepaint(_Play old) => true;
}
