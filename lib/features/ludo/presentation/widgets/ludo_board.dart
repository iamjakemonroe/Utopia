import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_background.dart';
import '../../../../core/audio/game_audio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/ludo_engine.dart';
import 'ludo_board_geometry.dart';
import 'ludo_pieces.dart';
import 'ludo_capture_bubble.dart';

/// A capture reaction playing on one token, started at [startedAt]
/// (seconds on the board's clock, see [LudoBoardView.clockNow]).
class LudoTokenReaction {
  const LudoTokenReaction({
    required this.color,
    required this.token,
    required this.kind,
    required this.startedAt,
  });

  final LudoColor color;
  final int token;
  final TokenReaction kind;
  final double startedAt;

  static const duration = 2.6;
}

/// Something to float above one token (the capture thought bubble). It
/// shows once the token has stopped moving (a piece sent home gets its
/// bubble when it lands in its yard).
class LudoTokenAnchor {
  const LudoTokenAnchor({
    required this.color,
    required this.token,
    required this.child,
    this.width = 200,
    this.onTokenTap,
  });

  final LudoColor color;
  final int token;
  final Widget child;

  /// How wide [child] is: it's kept on the board by that.
  final double width;

  /// Tapping the token itself, when it can't move (the piece that
  /// captured, or the one sent home, to react).
  final VoidCallback? onTokenTap;
}

/// The Ludo board for any table size: the painted board (classic cross or
/// six-arm star, rotated so your own yard is bottom-left) with every token
/// on top. Tokens hop square by square when they move, with a bubbly
/// squash on each landing and a rising note per step; captured tokens fly
/// back to their yard spinning. Little bursts mark the moments: a comic
/// "pow" where a capture lands, a puff as a piece leaves its yard, a
/// firework as one gets home, and light rays when a player finishes. A
/// player who's finished gets a trophy over their yard with their place on
/// it (gold, silver, bronze), there while they watch the rest race on.
class LudoBoardView extends ConsumerStatefulWidget {
  const LudoBoardView({
    super.key,
    required this.game,
    required this.myColor,
    required this.movableTokens,
    required this.onTokenTap,
    required this.pieceSets,
    this.reactions = const [],
    this.anchors = const [],
  });

  final LudoState game;
  final LudoColor? myColor;

  /// My tokens that can move right now.
  final List<int> movableTokens;
  final ValueChanged<int> onTokenTap;

  /// Each color's piece set id.
  final Map<LudoColor, String> pieceSets;

  /// Reactions playing on tokens (the capturer's, the pieces sent home).
  final List<LudoTokenReaction> reactions;

  /// What's floating over tokens right now.
  final List<LudoTokenAnchor> anchors;

  /// The board's clock, for timing reactions.
  static double clockNow() => _clock.elapsedMicroseconds / 1e6;
  static final Stopwatch _clock = Stopwatch()..start();

  @override
  ConsumerState<LudoBoardView> createState() => _LudoBoardViewState();
}

/// A token travelling: hopping along [points], or (when [fly]) arcing back
/// to its yard after being captured.
class _Motion {
  _Motion({
    required this.origin,
    required this.points,
    required this.start,
    required this.stepSeconds,
    this.fly = false,
  });

  final Offset origin;
  final List<Offset> points;
  final double start;
  final double stepSeconds;
  final bool fly;
  int landed = 0;

  double get end => start + points.length * stepSeconds;
}

class _LudoBoardViewState extends ConsumerState<LudoBoardView>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _now = ValueNotifier(LudoBoardView.clockNow());
  // Pieces moving get every frame. Pieces just sitting there (breathing,
  // blinking, bobbing) look the same at 30 frames a second, so between
  // moves the board redraws half as often: a long game stays cool.
  late final Ticker _ticker = createTicker((_) {
    final now = LudoBoardView.clockNow();
    if (!_moving(now) && now - _now.value < 1 / 30) return;
    _now.value = now;
  });

  bool _moving(double now) {
    for (final m in _motions.values) {
      if (now <= m.end + 0.15) return true;
    }
    _bursts.removeWhere((b) => now > b.end);
    return _bursts.isNotEmpty;
  }

  /// Bursts playing (or about to): see [_Burst].
  final List<_Burst> _bursts = [];
  final _rng = math.Random();

  final Map<String, int> _lastPos = {};
  final Map<String, _Motion> _motions = {};

  /// When each finished player's trophy pops up over their yard (on the
  /// board's clock): just after their last piece gets home.
  final Map<LudoColor, double> _trophyAt = {};

  LudoGeometry get _geometry => LudoGeometry.of(widget.game.board);

  @override
  void initState() {
    super.initState();
    _remember(widget.game);
    _ticker.start();
  }

  void _remember(LudoState game) {
    // Finished before the board was shown (a game come back to): already up.
    for (final color in game.finished) {
      _trophyAt.putIfAbsent(color, () => -100);
    }
    for (final color in game.players) {
      final ps = game.tokens[color]!;
      for (var i = 0; i < ps.length; i++) {
        _lastPos['${color.name}$i'] = ps[i];
      }
    }
  }

  @override
  void didUpdateWidget(covariant LudoBoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.game.board != widget.game.board) {
      _motions.clear();
      _lastPos.clear();
      _trophyAt.clear();
      _remember(widget.game);
      return;
    }
    final now = LudoBoardView.clockNow();
    final g = _geometry;
    final victims = <(String, LudoColor, int, int)>[];
    var movesEnd = now;

    for (final color in widget.game.players) {
      final ps = widget.game.tokens[color]!;
      for (var i = 0; i < ps.length; i++) {
        final key = '${color.name}$i';
        final before = _lastPos[key];
        final after = ps[i];
        _lastPos[key] = after;
        if (before == null || before == after) continue;

        if (after == kLudoBase) {
          victims.add((key, color, i, before));
          continue;
        }
        final forward = before == kLudoBase || after > before;
        final steps = forward
            ? g.path(color, i, before, after)
            : const <Offset>[];
        if (steps.isEmpty || steps.length > 14) {
          _motions.remove(key); // a resync jump: just snap
          continue;
        }
        final motion = _Motion(
          origin: _restingOrDisplayed(key, color, i, before),
          points: steps,
          start: now,
          stepSeconds: before == kLudoBase ? 0.34 : 0.2,
        );
        _motions[key] = motion;
        movesEnd = math.max(movesEnd, motion.end);
        final rules = widget.game.rules;
        if (before == kLudoBase) {
          // Out of the yard on a six: a puff where it lands.
          _burst(_BurstKind.launch, steps.last, motion.end - 0.05, color);
        } else if (rules.isHome(after) && !rules.isHome(before)) {
          _burst(_BurstKind.home, steps.last, motion.end, color);
          // The last one home: this player's finished.
          if (ps.every(rules.isHome)) {
            _burst(_BurstKind.finish, Offset.zero, motion.end + 0.1, color);
            _trophyAt[color] = motion.end + 0.7;
          }
        }
      }
    }

    // Captured tokens wait for the capturing hop to land, then fly home.
    final by = widget.game.capture?.by;
    for (final (key, color, i, before) in victims) {
      final at = g.positionOf(color, i, before);
      _motions[key] = _Motion(
        origin: at,
        points: [g.yardSlots[color]![i]],
        start: movesEnd,
        stepSeconds: 0.8,
        fly: true,
      );
      _burst(_BurstKind.pow, at, movesEnd - 0.04, by ?? color);
    }

    final finished = widget.game.finished;
    _trophyAt.removeWhere((color, _) => !finished.contains(color));
    for (final color in finished) {
      _trophyAt.putIfAbsent(color, () => now);
    }
  }

  void _burst(_BurstKind kind, Offset at, double start, LudoColor color) {
    _bursts.add(
      _Burst(
        kind: kind,
        at: at,
        start: start,
        color: ludoColorPalette[color]!,
        seed: _rng.nextDouble() * 2 * math.pi,
      ),
    );
  }

  Offset _restingOrDisplayed(String key, LudoColor color, int i, int pos) {
    final active = _motions[key];
    if (active != null) return active.points.last;
    return _geometry.positionOf(color, i, pos);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _now.dispose();
    super.dispose();
  }

  void _playLandings(GameAudio audio, String key, _Motion m, double now) {
    if (now < m.start) return;
    final landed = ((now - m.start) / m.stepSeconds).floor().clamp(
      0,
      m.points.length,
    );
    if (m.fly) {
      if (m.landed == 0) {
        m.landed = 1;
        audio.play(Sfx.capture);
      }
      return;
    }
    while (m.landed < landed) {
      m.landed++;
      audio.play(
        m.landed == m.points.length ? Sfx.drop : Sfx.step(m.landed - 1),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final audio = ref.read(gameAudioProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final g = _geometry;
        final rotation = g.viewRotation(widget.myColor);
        final half = g.halfExtent(rotation + 0) + const Offset(0.45, 0.45);
        final cellPx = math.min(
          constraints.maxWidth / (2 * half.width),
          constraints.maxHeight / (2 * half.height),
        );
        final size = Size(2 * half.width * cellPx, 2 * half.height * cellPx);
        final center = size.center(Offset.zero);
        Offset toScreen(Offset model) =>
            center + LudoGeometry.rotate(model, rotation) * cellPx;

        final active = widget.game.activePlayers.toSet();
        final hub = center;

        return Center(
          child: SizedBox.fromSize(
            size: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                RepaintBoundary(
                  child: CustomPaint(
                    size: size,
                    painter: _BoardPainter(
                      geometry: g,
                      rotation: rotation,
                      cellPx: cellPx,
                      playing: widget.game.players.toSet(),
                      active: active,
                      surface: AppColors.surface,
                      surfaceElevated: AppColors.surfaceElevated,
                      trim: AppColors.goldBorder,
                      glow: AppColors.glowRing,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _BoardHubPainter(
                        center: center,
                        radius: g.innerRadius * cellPx,
                      ),
                    ),
                  ),
                ),
                // Built again with each tick of their clock: in a
                // LayoutIsland, so that lays out and draws the tokens, not
                // the board's hub or the screen around it.
                Positioned.fill(
                  child: LayoutIsland(
                    child: ValueListenableBuilder<double>(
                      valueListenable: _now,
                      builder: (context, now, _) => Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: _tokens(
                              now: now,
                              width: size.width,
                              cellPx: cellPx,
                              toScreen: toScreen,
                              audio: audio,
                            ),
                          ),
                          if (_bursts.isNotEmpty)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _BurstPainter(
                                    bursts: _bursts,
                                    now: now,
                                    cellPx: cellPx,
                                    toScreen: toScreen,
                                    hub: hub,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// What's anchored over a token, kept on the board (a piece by its edge
  /// had its card hanging off the screen), its point still on the piece.
  Widget _anchored(LudoTokenAnchor anchor, Offset top, double width) {
    final w = anchor.width;
    final childLeft = (top.dx - w / 2)
        .clamp(-6.0, math.max(-6.0, width - w + 6))
        .toDouble();
    return Positioned(
      key: ValueKey('anchor-${anchor.color.name}${anchor.token}'),
      left: childLeft - (200 - w) / 2,
      top: top.dy - 120,
      width: 200,
      height: 120,
      child: LudoAnchorTail(
        dx: top.dx - (childLeft + w / 2),
        child: Align(alignment: Alignment.bottomCenter, child: anchor.child),
      ),
    );
  }

  LudoTokenAnchor? _anchorOn(LudoColor color, int token) {
    for (final a in widget.anchors) {
      if (a.color == color && a.token == token) return a;
    }
    return null;
  }

  LudoTokenReaction? _reactionOn(LudoColor color, int token) {
    for (final r in widget.reactions) {
      if (r.color == color && r.token == token) return r;
    }
    return null;
  }

  Widget _tokens({
    required double now,
    required double width,
    required double cellPx,
    required Offset Function(Offset) toScreen,
    required GameAudio audio,
  }) {
    final g = _geometry;
    final game = widget.game;
    final tokenW = cellPx * 0.98;
    final tokenH = tokenW * LudoTokenPainter.aspect;

    // Resting tokens sharing a square cluster together.
    final resting = <String, List<String>>{};
    for (final color in game.players) {
      if (game.left.contains(color)) continue;
      final ps = game.tokens[color]!;
      for (var i = 0; i < ps.length; i++) {
        final key = '${color.name}$i';
        if (_motions.containsKey(key)) continue;
        final spot = g.positionOf(color, i, ps[i]);
        resting
            .putIfAbsent(
              '${spot.dx.toStringAsFixed(2)},${spot.dy.toStringAsFixed(2)}',
              () => [],
            )
            .add(key);
      }
    }
    const clusters = {
      2: [Offset(-0.2, 0), Offset(0.2, 0)],
      3: [Offset(-0.2, 0.1), Offset(0.2, 0.1), Offset(0, -0.16)],
      4: [
        Offset(-0.2, 0.12),
        Offset(0.2, 0.12),
        Offset(-0.2, -0.16),
        Offset(0.2, -0.16),
      ],
    };
    final clusterOffset = <String, Offset>{};
    for (final keys in resting.values) {
      if (keys.length < 2) continue;
      final offsets = clusters[math.min(keys.length, 4)]!;
      for (var k = 0; k < keys.length; k++) {
        clusterOffset[keys[k]] = offsets[k % offsets.length] * cellPx;
      }
    }

    final items = <(double, Widget)>[];
    final anchorTops = <(LudoTokenAnchor, Offset)>[];

    // Trophies over the finished players' yards, under every piece.
    final trophyW =
        cellPx * (g.rules.kind == LudoBoardKind.classic ? 4.4 : 3.6);
    for (final (i, color) in game.finished.indexed) {
      final at = _trophyAt[color] ?? -100;
      if (now < at) continue;
      final c = toScreen(g.yardCenter[color]!);
      items.add((
        -1e6 + i,
        Positioned(
          key: ValueKey('trophy-${color.name}'),
          left: c.dx - trophyW / 2,
          top: c.dy - trophyW * 0.65,
          width: trophyW,
          height: trophyW * 1.3,
          child: IgnorePointer(
            child: Semantics(
              label: '${ludoColorName(color)}: ${placeLabel(i + 1)}',
              child: CustomPaint(
                painter: _TrophyPainter(place: i + 1, age: now - at, now: now),
              ),
            ),
          ),
        ),
      ));
    }
    for (final color in game.players) {
      if (game.left.contains(color)) continue;
      final ps = game.tokens[color]!;
      for (var i = 0; i < ps.length; i++) {
        final key = '${color.name}$i';
        var lift = 0.0;
        var spin = 0.0;
        var scale = 1.0;
        Offset model;
        final motion = _motions[key];
        if (motion != null) {
          _playLandings(audio, key, motion, now);
          if (now >= motion.end) {
            _motions.remove(key);
            model = g.positionOf(color, i, ps[i]);
          } else if (now < motion.start) {
            model = motion.origin;
          } else {
            final elapsed = now - motion.start;
            final step = (elapsed / motion.stepSeconds).floor();
            final f = (elapsed / motion.stepSeconds) - step;
            final from = step == 0 ? motion.origin : motion.points[step - 1];
            final to = motion.points[step];
            model = Offset.lerp(from, to, Curves.easeInOut.transform(f))!;
            if (motion.fly) {
              lift = math.sin(f * math.pi) * 2.6;
              spin = f * 4 * math.pi;
              scale = 1 - 0.3 * math.sin(f * math.pi);
            } else {
              lift = math.sin(f * math.pi) * 0.55;
            }
          }
        } else {
          model = g.positionOf(color, i, ps[i]);
        }

        // Only the side on turn ever has movable pieces (a friend's too,
        // in a game passed around one phone).
        final movable =
            game.turn == color &&
            widget.movableTokens.contains(i) &&
            motion == null;
        final grouped = clusterOffset[key];
        if (grouped != null) scale *= 0.78;
        final bounce = movable ? (0.5 + 0.5 * math.sin(now * 7)) * 0.16 : 0.0;
        final ground =
            toScreen(model) +
            (grouped ?? Offset.zero) -
            Offset(0, (lift + bounce) * cellPx);

        final reaction = _reactionOn(color, i);
        final reacting = reaction != null;
        final progress = reacting
            ? ((now - reaction.startedAt) / LudoTokenReaction.duration).clamp(
                0.0,
                1.0,
              )
            : 0.0;

        // A reacting token swells up so the whole table sees its face.
        if (reacting && progress < 1) {
          final swell = progress < 0.15
              ? Curves.easeOutBack.transform(progress / 0.15)
              : (progress > 0.85 ? (1 - progress) / 0.15 : 1.0);
          scale *= 1 + 0.7 * swell;
        }
        final w = tokenW * scale;
        final h = tokenH * scale;
        final anchor = motion == null ? _anchorOn(color, i) : null;
        final anchored = anchor?.onTokenTap != null;
        if (anchor != null) {
          anchorTops.add((anchor, ground - Offset(0, h * 0.95)));
        }
        Widget token = CustomPaint(
          size: Size(w, h),
          painter: LudoTokenPainter(
            setId: widget.pieceSets[color] ?? 'classic',
            color: color,
            t: now,
            highlight: movable ? 1 : 0,
            reaction: reacting && progress < 1
                ? reaction.kind
                : TokenReaction.none,
            reactionProgress: progress,
            lift: (lift / 2.6).clamp(0.0, 1.0),
          ),
        );
        if (spin != 0) token = Transform.rotate(angle: spin, child: token);
        if (motion != null && !motion.fly && lift > 0) {
          // Stretch while airborne, squash on landing.
          final f = lift / 0.55;
          token = Transform.scale(
            scaleX: 1 - 0.08 * f,
            scaleY: 1 + 0.1 * f,
            child: token,
          );
        }
        items.add((
          ground.dy +
              (movable ? 1000 : 0) +
              (motion != null ? 2000 : 0) +
              (reacting && progress < 1 ? 3000 : 0),
          Positioned(
            key: ValueKey(key),
            left: ground.dx - w / 2,
            top: ground.dy - h * 0.92,
            width: w,
            height: h,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: movable
                  ? () => widget.onTokenTap(i)
                  : anchored
                  ? anchor!.onTokenTap
                  : null,
              child: Semantics(
                button: movable || anchored,
                label: '${ludoColorName(color)} token ${i + 1}',
                child: token,
              ),
            ),
          ),
        ));
      }
    }
    items.sort((a, b) => a.$1.compareTo(b.$1));

    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final (_, w) in items) w,
        for (final (anchor, top) in anchorTops) _anchored(anchor, top, width),
      ],
    );
  }
}

/// The static board, painted in cell units after rotating so the local
/// player's yard sits bottom-left.
class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.geometry,
    required this.rotation,
    required this.cellPx,
    required this.playing,
    required this.active,
    required this.surface,
    required this.surfaceElevated,
    required this.trim,
    required this.glow,
  });

  final LudoGeometry geometry;
  final double rotation;
  final double cellPx;
  final Set<LudoColor> playing;
  final Set<LudoColor> active;
  final Color surface;
  final Color surfaceElevated;
  final Color trim;
  final Color glow;

  static const _tileLight = Color(0xFFFFFBF4);
  static const _tileShade = Color(0xFFE6DDF2);

  Color _seat(LudoColor color) {
    final base = ludoColorPalette[color]!;
    if (active.contains(color)) return base;
    // Empty seats (and players who left) are muted.
    final grey = HSLColor.fromColor(base).withSaturation(0.12).toColor();
    return Color.lerp(grey, surfaceElevated, 0.35)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final g = geometry;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(rotation);
    canvas.scale(cellPx);

    _plate(canvas);
    for (final color in g.rules.seats) {
      _yard(canvas, g.rules.seatOf(color), color);
    }
    _track(canvas);
    _center(canvas);
    canvas.restore();
  }

  Path _rounded(List<Offset> points, double radius) {
    final path = Path();
    final n = points.length;
    for (var i = 0; i < n; i++) {
      final prev = points[(i - 1 + n) % n];
      final cur = points[i];
      final next = points[(i + 1) % n];
      final a =
          cur + _unit(prev - cur) * math.min(radius, (prev - cur).distance / 2);
      final b =
          cur + _unit(next - cur) * math.min(radius, (next - cur).distance / 2);
      if (i == 0) {
        path.moveTo(a.dx, a.dy);
      } else {
        path.lineTo(a.dx, a.dy);
      }
      path.quadraticBezierTo(cur.dx, cur.dy, b.dx, b.dy);
    }
    return path..close();
  }

  Offset _unit(Offset v) => v / v.distance;

  List<Offset> _inset(List<Offset> points, double amount) {
    final c = points.reduce((a, b) => a + b) / points.length.toDouble();
    return [for (final p in points) p + _unit(c - p) * amount];
  }

  void _plate(Canvas canvas) {
    final outer = _inset(geometry.outline, -0.42);
    final plate = _rounded(outer, 1.1);
    final bounds = plate.getBounds();
    canvas.drawPath(
      plate.shift(const Offset(0, 0.28)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.35),
    );
    canvas.drawPath(
      plate,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(surfaceElevated, Colors.white, 0.08)!, surface],
        ).createShader(bounds),
    );
    // Faint ripples from the center, like the board is glowing.
    final ripple = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.06
      ..color = glow.withValues(alpha: 0.08);
    canvas.save();
    canvas.clipPath(plate);
    for (var r = 2.0; r < 13; r += 1.4) {
      canvas.drawCircle(Offset.zero, r, ripple);
    }
    canvas.restore();
    canvas.drawPath(
      plate,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.16
        ..color = trim,
    );
    canvas.drawPath(
      _rounded(_inset(geometry.outline, -0.24), 0.95),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.05
        ..color = glow.withValues(alpha: 0.55),
    );
  }

  void _yard(Canvas canvas, int seat, LudoColor color) {
    final g = geometry;
    final base = _seat(color);
    final region = _rounded(_inset(g.yardRegion(seat), 0.22), 0.7);
    final bounds = region.getBounds();
    canvas.drawPath(
      region,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(base, Colors.white, 0.35)!,
            base,
            Color.lerp(base, Colors.black, 0.22)!,
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(bounds),
    );
    canvas.drawPath(
      region,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.07
        ..color = Colors.white.withValues(alpha: 0.4),
    );

    // The nest pad the four tokens sit in.
    final c = g.yardCenter[color]!;
    final slots = g.yardSlots[color]!;
    final padRadius = g.rules.kind == LudoBoardKind.classic ? 2.15 : 1.75;
    final pad = g.rules.kind == LudoBoardKind.classic
        ? (Path()..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: c,
                width: padRadius * 2,
                height: padRadius * 2,
              ),
              const Radius.circular(0.7),
            ),
          ))
        : (Path()..addOval(Rect.fromCircle(center: c, radius: padRadius)));
    canvas.save();
    if (g.rules.kind == LudoBoardKind.classic) {
      // Keep the classic pad square to the board's own axes.
      canvas.translate(c.dx, c.dy);
      canvas.rotate(g.armAngle(seat) - math.pi);
      canvas.translate(-c.dx, -c.dy);
    }
    canvas.drawPath(
      pad.shift(const Offset(0, 0.1)),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );
    canvas.drawPath(
      pad,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.95),
            Color.lerp(Colors.white, base, 0.25)!,
          ],
        ).createShader(pad.getBounds()),
    );
    canvas.restore();
    for (final slot in slots) {
      final nest = Rect.fromCircle(center: slot, radius: 0.5);
      canvas.drawCircle(
        slot,
        0.5,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0, -0.3),
            colors: [
              Color.lerp(base, Colors.black, 0.25)!,
              Color.lerp(base, Colors.white, 0.2)!,
            ],
            stops: const [0.45, 1.0],
          ).createShader(nest),
      );
      canvas.drawCircle(
        slot,
        0.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.05
          ..color = Colors.white.withValues(alpha: 0.7),
      );
    }
  }

  void _tile(
    Canvas canvas,
    Offset c,
    double angle,
    Color top,
    Color bottom, {
    double size = 0.9,
  }) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: size,
      height: size,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(0.22));
    canvas.restore();
    // The drop shadow is offset straight down on screen, whatever the
    // board's rotation, so the light always comes from above.
    canvas.save();
    final down = LudoGeometry.rotate(const Offset(0, 0.09), -rotation);
    canvas.translate(c.dx + down.dx, c.dy + down.dy);
    canvas.rotate(angle);
    canvas.drawRRect(
      rrect,
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );
    canvas.restore();

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [top, bottom],
        ).createShader(rect),
    );
    canvas.drawRRect(
      rrect.deflate(0.05),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.04
        ..color = Colors.white.withValues(alpha: 0.55),
    );
    canvas.restore();
  }

  void _track(Canvas canvas) {
    final g = geometry;
    final rules = g.rules;
    final starts = {for (final c in rules.seats) rules.startSquare(c): c};
    final stars = {
      for (final c in rules.seats) (rules.startSquare(c) + 8) % rules.ringSize,
    };
    final tint = Color.lerp(_tileShade, glow, 0.15)!;

    for (var i = 0; i < g.ring.length; i++) {
      final c = g.ring[i];
      final angle = g.armAngle(g.ringArm[i]);
      final startOf = starts[i];
      if (startOf != null) {
        final seatColor = _seat(startOf);
        _tile(
          canvas,
          c,
          angle,
          Color.lerp(seatColor, Colors.white, 0.4)!,
          seatColor,
        );
        final next = g.ring[(i + 1) % g.ring.length];
        _arrow(canvas, c, next - c);
      } else {
        _tile(canvas, c, angle, _tileLight, tint);
        if (stars.contains(i)) _star(canvas, c, 0.3, AppColors.coinGold);
      }
    }
    for (final color in rules.seats) {
      final cells = g.stretch[color]!;
      final seatColor = _seat(color);
      final angle = g.armAngle(rules.seatOf(color));
      for (var k = 0; k < cells.length; k++) {
        final t = k / (cells.length - 1);
        _tile(
          canvas,
          cells[k],
          angle,
          Color.lerp(seatColor, Colors.white, 0.55 - 0.35 * t)!,
          Color.lerp(seatColor, Colors.black, 0.05 + 0.1 * t)!,
        );
      }
    }
  }

  void _arrow(Canvas canvas, Offset c, Offset dir) {
    final d = _unit(dir);
    final p = Offset(-d.dy, d.dx);
    final tip = c + d * 0.26;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((c - d * 0.14 + p * 0.22).dx, (c - d * 0.14 + p * 0.22).dy)
      ..lineTo((c - d * 0.02).dx, (c - d * 0.02).dy)
      ..lineTo((c - d * 0.14 - p * 0.22).dx, (c - d * 0.14 - p * 0.22).dy)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );
  }

  void _star(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5 - rotation;
      final rr = i.isEven ? r : r * 0.45;
      final p = c + Offset(math.cos(a), math.sin(a)) * rr;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path.shift(const Offset(0.02, 0.04)),
      Paint()..color = Colors.black.withValues(alpha: 0.2),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          colors: [AppColors.coinGoldBright, color],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  void _center(Canvas canvas) {
    final g = geometry;
    final v = g.centerPolygon;
    final n = v.length;
    for (final color in g.rules.seats) {
      final s = g.rules.seatOf(color);
      final a = v[(s - 1 + n) % n];
      final b = v[s];
      final tri = Path()
        ..moveTo(0, 0)
        ..lineTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..close();
      canvas.drawPath(tri, Paint()..color = _seat(color));
      canvas.drawPath(
        tri,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.05
          ..color = Colors.white.withValues(alpha: 0.6),
      );
    }
    // One soft glow over the whole center (lighter toward the middle)
    // rather than a gradient per slice: a per-slice linear gradient whose
    // axis lands exactly horizontal fails to draw on some renderers.
    final hub = Path()..addPolygon(v, true);
    final radius = v.first.distance;
    canvas.save();
    canvas.clipPath(hub);
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.5),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius)),
    );
    canvas.restore();
    canvas.drawPath(
      hub,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.1
        ..color = trim,
    );
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) =>
      old.geometry != geometry ||
      old.rotation != rotation ||
      old.cellPx != cellPx ||
      old.active.length != active.length ||
      !old.active.containsAll(active) ||
      old.surface != surface ||
      old.trim != trim;
}

/// The gem at the heart of the board. It sits still: players found a
/// pulsing, spinning center pulled their eyes off their pieces.
class _BoardHubPainter extends CustomPainter {
  _BoardHubPainter({required this.center, required this.radius});

  final Offset center;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final r = radius * 0.3;
    // A faint warm halo so the gem sits in the light.
    canvas.drawCircle(
      center,
      r * 2.1,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.coinGoldBright.withValues(alpha: 0.22),
            AppColors.coinGoldBright.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: r * 2.1)),
    );
    final top = center + Offset(0, -r);
    final right = center + Offset(r * 0.78, 0);
    final bottom = center + Offset(0, r);
    final left = center + Offset(-r * 0.78, 0);
    final gem = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(bottom.dx, bottom.dy)
      ..lineTo(left.dx, left.dy)
      ..close();
    canvas.drawPath(
      gem,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF3C4), Color(0xFFFFC94D), Color(0xFFD98A12)],
        ).createShader(gem.getBounds()),
    );
    // Facets: a lit upper-left face and a shaded lower-right one.
    canvas.drawPath(
      Path()
        ..moveTo(top.dx, top.dy)
        ..lineTo(center.dx, center.dy)
        ..lineTo(left.dx, left.dy)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );
    canvas.drawPath(
      Path()
        ..moveTo(bottom.dx, bottom.dy)
        ..lineTo(center.dx, center.dy)
        ..lineTo(right.dx, right.dy)
        ..close(),
      Paint()..color = Colors.black.withValues(alpha: 0.12),
    );
    canvas.drawPath(
      gem,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08
        ..color = const Color(0xFFFFF6D6).withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(covariant _BoardHubPainter old) =>
      old.center != center || old.radius != radius;
}

enum _BurstKind { pow, launch, home, finish }

/// A moment worth a little burst, at [at] (board units; a [_BurstKind.finish]
/// plays at the hub), starting at [start] on the board's clock.
class _Burst {
  _Burst({
    required this.kind,
    required this.at,
    required this.start,
    required this.color,
    required this.seed,
  });

  final _BurstKind kind;
  final Offset at;
  final double start;
  final Color color;

  /// Turns each burst a little, so no two look the same.
  final double seed;

  double get length => switch (kind) {
    _BurstKind.pow => 0.7,
    _BurstKind.launch => 0.6,
    _BurstKind.home => 0.95,
    _BurstKind.finish => 1.7,
  };

  double get end => start + length;
}

/// Draws the bursts playing now, over the tokens.
class _BurstPainter extends CustomPainter {
  _BurstPainter({
    required this.bursts,
    required this.now,
    required this.cellPx,
    required this.toScreen,
    required this.hub,
  });

  final List<_Burst> bursts;
  final double now;
  final double cellPx;
  final Offset Function(Offset) toScreen;
  final Offset hub;

  /// A ten-point comic star, one unit across.
  static final Path _star = () {
    final path = Path();
    for (var i = 0; i < 20; i++) {
      final a = i * math.pi / 10 - math.pi / 2;
      final r = i.isEven ? 1.0 : 0.55;
      final p = Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }();

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in bursts) {
      final f = (now - b.start) / b.length;
      if (f < 0 || f > 1) continue;
      switch (b.kind) {
        case _BurstKind.pow:
          _pow(canvas, toScreen(b.at), f, b);
        case _BurstKind.launch:
          _launch(canvas, toScreen(b.at), f, b);
        case _BurstKind.home:
          _firework(canvas, toScreen(b.at), f, b, cellPx * 1.3, 12);
        case _BurstKind.finish:
          _rays(canvas, hub, f, b);
          _firework(canvas, hub, f, b, cellPx * 3.2, 22);
      }
    }
  }

  /// A comic "pow": a star slams in and fades, a ring goes out, and
  /// little stars fly off.
  void _pow(Canvas canvas, Offset c, double f, _Burst b) {
    final grow = Curves.easeOutBack.transform(math.min(1.0, f / 0.35));
    final fade = f < 0.55 ? 1.0 : 1 - (f - 0.55) / 0.45;
    final r = cellPx * 0.75 * grow;
    canvas.drawCircle(
      c,
      cellPx * (0.4 + 1.1 * f),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cellPx * 0.12 * (1 - f)
        ..color = Colors.white.withValues(alpha: 0.8 * (1 - f)),
    );
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(b.seed * 0.2 - 0.1);
    canvas.scale(r);
    canvas.drawPath(
      _star,
      Paint()..color = b.color.withValues(alpha: 0.95 * fade),
    );
    canvas.scale(0.72);
    canvas.drawPath(
      _star,
      Paint()..color = const Color(0xFFFFF3B0).withValues(alpha: fade),
    );
    canvas.restore();
    final spark = Paint()..color = Colors.white.withValues(alpha: fade);
    for (var k = 0; k < 7; k++) {
      final a = b.seed + k * 2 * math.pi / 7;
      final d = cellPx * (0.5 + 1.2 * Curves.easeOut.transform(f));
      final p = c + Offset(math.cos(a), math.sin(a)) * d;
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(f * 4 + k);
      canvas.scale(cellPx * 0.14 * (1 - f));
      canvas.drawPath(_star, spark);
      canvas.restore();
    }
  }

  /// A puff of dust as a piece hops out of its yard, and sparks of its
  /// color going up.
  void _launch(Canvas canvas, Offset c, double f, _Burst b) {
    final e = Curves.easeOut.transform(f);
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(0, cellPx * 0.1),
        width: cellPx * (0.6 + 1.3 * e),
        height: cellPx * (0.25 + 0.45 * e),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cellPx * 0.1 * (1 - f)
        ..color = Colors.white.withValues(alpha: 0.7 * (1 - f)),
    );
    final dot = Paint();
    for (var k = 0; k < 6; k++) {
      final a = -math.pi / 2 + (k - 2.5) * 0.35 + math.sin(b.seed + k) * 0.1;
      final d = cellPx * (0.3 + 1.1 * e);
      canvas.drawCircle(
        c + Offset(math.cos(a), math.sin(a)) * d,
        cellPx * 0.09 * (1 - f),
        dot
          ..color = (k.isEven ? b.color : Colors.white).withValues(
            alpha: 1 - f,
          ),
      );
    }
  }

  /// A firework of [n] sparks in the player's color, with a white flash.
  void _firework(
    Canvas canvas,
    Offset c,
    double f,
    _Burst b,
    double reach,
    int n,
  ) {
    final e = Curves.easeOutCubic.transform(f);
    if (f < 0.25) {
      canvas.drawCircle(
        c,
        reach * 0.35 * (f / 0.25),
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.9 * (1 - f / 0.25)),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: reach * 0.35)),
      );
    }
    final spark = Paint()..strokeCap = StrokeCap.round;
    for (var k = 0; k < n; k++) {
      final a = b.seed + k * 2 * math.pi / n;
      final dir = Offset(math.cos(a), math.sin(a));
      // A little gravity as they fall away.
      final p = c + dir * reach * e + Offset(0, reach * 0.25 * f * f);
      final tail =
          c +
          dir * reach * math.max(0.0, e - 0.18) +
          Offset(0, reach * 0.25 * f * f * 0.8);
      final light = k.isEven
          ? b.color
          : Color.lerp(b.color, Colors.white, 0.6)!;
      canvas.drawLine(
        tail,
        p,
        spark
          ..strokeWidth = cellPx * 0.1 * (1 - f * 0.7)
          ..color = light.withValues(alpha: 1 - f),
      );
    }
  }

  /// Soft light rays turning out from the hub, in the finisher's color.
  void _rays(Canvas canvas, Offset c, double f, _Burst b) {
    final alpha = f < 0.2 ? f / 0.2 : 1 - (f - 0.2) / 0.8;
    final reach = cellPx * (3 + 4 * Curves.easeOut.transform(f));
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          b.color.withValues(alpha: 0.55 * alpha),
          b.color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: reach));
    const n = 12;
    for (var k = 0; k < n; k++) {
      final a = b.seed + f * 0.8 + k * 2 * math.pi / n;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(
            c.dx + math.cos(a - 0.09) * reach,
            c.dy + math.sin(a - 0.09) * reach,
          )
          ..lineTo(
            c.dx + math.cos(a + 0.09) * reach,
            c.dy + math.sin(a + 0.09) * reach,
          )
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => true;
}

/// A trophy over a finished player's yard: a cup in their place's metal
/// (gold, silver, bronze) on a ribbon saying the place, with a glow behind
/// it so it reads on any yard color. It springs up when they finish
/// ([age] 0), then floats, a glint crossing it now and then.
class _TrophyPainter extends CustomPainter {
  _TrophyPainter({required this.place, required this.age, required this.now});

  final int place;

  /// Seconds since it appeared.
  final double age;
  final double now;

  static final Map<(int, int), TextPainter> _labels = {};

  @override
  void paint(Canvas canvas, Size size) {
    final pop = Curves.elasticOut.transform((age / 0.9).clamp(0.0, 1.0));
    if (pop <= 0.01) return;
    final metal = kPlaceMedals[place] ?? kPlaceMedals[3]!;
    final w = size.width;
    canvas.save();
    canvas.translate(w / 2, size.height / 2 + math.sin(now * 2.1) * w * 0.02);
    canvas.scale(pop);

    // The glow behind it.
    final halo = Rect.fromCircle(
      center: Offset(0, -w * 0.12),
      radius: w * 0.56,
    );
    canvas.drawOval(
      halo,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.85),
            metal[0].withValues(alpha: 0.45),
            metal[0].withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(halo),
    );

    final ink = Color.lerp(metal[2], Colors.black, 0.45)!;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.022
      ..strokeJoin = StrokeJoin.round
      ..color = ink;

    // Handles.
    for (final side in const [-1.0, 1.0]) {
      final handle = Path()
        ..moveTo(side * w * 0.27, -w * 0.38)
        ..cubicTo(
          side * w * 0.47,
          -w * 0.4,
          side * w * 0.47,
          -w * 0.12,
          side * w * 0.14,
          -w * 0.07,
        );
      canvas.drawPath(
        handle,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = w * 0.085
          ..color = ink,
      );
      canvas.drawPath(
        handle,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = w * 0.045
          ..color = metal[1],
      );
    }

    // Stem and base.
    final stem = RRect.fromRectAndRadius(
      Rect.fromLTRB(-w * 0.055, -w * 0.02, w * 0.055, w * 0.14),
      Radius.circular(w * 0.02),
    );
    final knot = Rect.fromCenter(
      center: Offset(0, w * 0.04),
      width: w * 0.17,
      height: w * 0.07,
    );
    final base = RRect.fromRectAndRadius(
      Rect.fromLTRB(-w * 0.2, w * 0.13, w * 0.2, w * 0.21),
      Radius.circular(w * 0.025),
    );
    final metalShader = LinearGradient(
      colors: [metal[2], metal[0], metal[1], metal[2]],
      stops: const [0, 0.32, 0.62, 1],
    ).createShader(Rect.fromLTRB(-w * 0.32, 0, w * 0.32, 1));
    for (final part in [stem, base]) {
      canvas.drawRRect(part, Paint()..shader = metalShader);
      canvas.drawRRect(part, outline);
    }
    canvas.drawOval(knot, Paint()..shader = metalShader);
    canvas.drawOval(knot, outline);

    // The cup.
    final bowl = Path()
      ..moveTo(-w * 0.3, -w * 0.42)
      ..lineTo(w * 0.3, -w * 0.42)
      ..cubicTo(w * 0.3, -w * 0.13, w * 0.16, -w * 0.01, 0, -w * 0.01)
      ..cubicTo(-w * 0.16, -w * 0.01, -w * 0.3, -w * 0.13, -w * 0.3, -w * 0.42)
      ..close();
    canvas.drawPath(bowl, Paint()..shader = metalShader);
    // A glint crossing it every few seconds.
    final glint = (now % 3.4) / 0.6;
    if (glint < 1) {
      canvas.save();
      canvas.clipPath(bowl);
      final x = -w * 0.45 + glint * w * 0.9;
      canvas.drawPath(
        Path()
          ..moveTo(x - w * 0.05, -w * 0.45)
          ..lineTo(x + w * 0.05, -w * 0.45)
          ..lineTo(x - w * 0.1, 0)
          ..lineTo(x - w * 0.2, 0)
          ..close(),
        Paint()..color = Colors.white.withValues(alpha: 0.7),
      );
      canvas.restore();
    }
    canvas.drawPath(bowl, outline);
    // Its rim, and a star on its front.
    final rim = Rect.fromCenter(
      center: Offset(0, -w * 0.42),
      width: w * 0.6,
      height: w * 0.09,
    );
    canvas.drawOval(rim, Paint()..color = metal[2]);
    canvas.drawOval(rim.deflate(w * 0.018), Paint()..color = ink);
    canvas.drawOval(rim, outline);
    final star = Path();
    for (var k = 0; k < 10; k++) {
      final r = k.isEven ? w * 0.085 : w * 0.036;
      final a = -math.pi / 2 + k * math.pi / 5;
      final p = Offset(math.cos(a) * r, -w * 0.22 + math.sin(a) * r);
      k == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    star.close();
    canvas.drawPath(star, Paint()..color = Colors.white.withValues(alpha: 0.9));

    // The ribbon with the place on it.
    final ribbon = RRect.fromRectAndRadius(
      Rect.fromLTRB(-w * 0.3, w * 0.22, w * 0.3, w * 0.4),
      Radius.circular(w * 0.05),
    );
    for (final side in const [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(side * w * 0.26, w * 0.25)
          ..lineTo(side * w * 0.42, w * 0.27)
          ..lineTo(side * w * 0.36, w * 0.33)
          ..lineTo(side * w * 0.42, w * 0.41)
          ..lineTo(side * w * 0.26, w * 0.38)
          ..close(),
        Paint()..color = const Color(0xFF1B1036),
      );
    }
    canvas.drawRRect(ribbon, Paint()..color = const Color(0xFF2A1B4D));
    canvas.drawRRect(
      ribbon,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.018
        ..color = metal[1],
    );
    final label = _labels.putIfAbsent(
      (place, (w * 0.14).round()),
      () => TextPainter(
        text: TextSpan(
          text: placeLabel(place),
          style: AppTextStyles.display(fontSize: w * 0.14, color: metal[0]),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
    label.paint(canvas, Offset(-label.width / 2, w * 0.31 - label.height / 2));

    // Twinkles around it.
    for (var k = 0; k < 3; k++) {
      final phase = (now * 0.9 + k * 0.37) % 1;
      final s = math.sin(phase * math.pi) * w * 0.05;
      if (s <= 0) continue;
      final at = [
        Offset(-w * 0.4, -w * 0.5),
        Offset(w * 0.42, -w * 0.3),
        Offset(-w * 0.36, w * 0.05),
      ][k];
      final twinkle = Path()
        ..moveTo(at.dx, at.dy - s)
        ..quadraticBezierTo(at.dx, at.dy, at.dx + s, at.dy)
        ..quadraticBezierTo(at.dx, at.dy, at.dx, at.dy + s)
        ..quadraticBezierTo(at.dx, at.dy, at.dx - s, at.dy)
        ..quadraticBezierTo(at.dx, at.dy, at.dx, at.dy - s)
        ..close();
      canvas.drawPath(twinkle, Paint()..color = Colors.white);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TrophyPainter old) =>
      old.place != place || old.age != age || old.now != now;
}
