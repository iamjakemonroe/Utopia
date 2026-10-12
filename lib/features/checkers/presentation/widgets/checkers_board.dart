import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../chess/presentation/widgets/chess_piece_styles.dart';
import '../../domain/checkers_engine.dart';
import 'checkers_disc.dart';

const _lightSquare = Color(0xFFEFDFAE);
const _darkSquare = Color(0xFF45368C);
const _lastMoveGlow = Color(0xFFFFC94D);
const _selectGlow = Color(0xFFFFE27A);
const _mustCapture = Color(0xFFFF7A45);

/// How long a move takes to play out on the board: one hop per step or
/// jump, then a moment for a crown to drop on. Bots wait this long before
/// answering, so a reply never lands mid-hop.
Duration checkersFlightTime(CheckersMove move) {
  var s = 0.0;
  for (var i = 1; i < move.path.length; i++) {
    s += move.isCapture ? _jumpSecs : _stepSecs;
  }
  if (move.promotes) s += _crownSecs;
  return Duration(milliseconds: (s * 1000).round());
}

const _stepSecs = 0.26;
const _jumpSecs = 0.32;
const _crownSecs = 0.55;
const _popSecs = 0.36;

/// The checkers board, alive: pieces hop along their path (jumps arc high),
/// the pieces they jump pop off the board, a crowned man gets its crown
/// dropped on, and in a character set the pieces watch the play, blink,
/// look worried when they can be taken, and cheer or sulk at the end.
///
/// Dark starts at the bottom unless [bottom] says otherwise (the light
/// player sees the board turned around).
class CheckersBoard extends StatefulWidget {
  const CheckersBoard({
    super.key,
    required this.position,
    this.lastMove,
    this.fly,
    this.selected,
    this.targets = const [],
    this.movable = const {},
    this.mustCapture = false,
    this.bottom = CheckersSide.dark,
    this.interactive = false,
    this.onSquareTap,
    this.darkSet,
    this.lightSet,
    this.gameOver = false,
    this.winner,
    this.onHop,
    this.onCrown,
    this.turnedFor,
  });

  /// Two people face to face over one phone: this side's faces and crowns
  /// are drawn turned around, so the player across the table sees them
  /// upright.
  final CheckersSide? turnedFor;

  final CheckersPosition position;

  /// Highlighted: where the last move went.
  final CheckersMove? lastMove;

  /// The move to animate. A new object starts a new flight; [position] is
  /// already the position after it.
  final CheckersMove? fly;

  final int? selected;

  /// The moves open to the selected piece.
  final List<CheckersMove> targets;

  /// Pieces that can move now, pulsing when [interactive].
  final Set<int> movable;

  /// A capture is on, so [movable] pulse in a warning orange.
  final bool mustCapture;
  final CheckersSide bottom;
  final bool interactive;
  final ValueChanged<int>? onSquareTap;

  /// Each side's equipped chess set, which their discs wear.
  final String? darkSet;
  final String? lightSet;
  final bool gameOver;

  /// Null for a draw (with [gameOver]).
  final CheckersSide? winner;

  /// Each landing of a flight: which hop, and whether it took a piece.
  final void Function(int hop, bool capture)? onHop;

  /// A man was crowned at the end of a flight.
  final VoidCallback? onCrown;

  @override
  State<CheckersBoard> createState() => _CheckersBoardState();
}

class _Flight {
  _Flight(this.move, this.victims, this.started);

  final CheckersMove move;

  /// The pieces it jumps, in order (taken from the position before).
  final List<CheckersPiece> victims;
  final double started;
  int hopsHeard = 0;
  bool crownHeard = false;

  double get hopSecs => move.isCapture ? _jumpSecs : _stepSecs;
  int get hops => move.path.length - 1;
  double get travel => hops * hopSecs;
  double get length => travel + (move.promotes ? _crownSecs : 0) + _popSecs;
}

class _CheckersBoardState extends State<CheckersBoard>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _clock = ValueNotifier<double>(0);
  _Flight? _flight;
  double _overAt = 0;
  int _frame = 0;

  double get _now =>
      SchedulerBinding.instance.currentSystemFrameTimeStamp.inMicroseconds /
      1e6;

  bool get _faced =>
      checkersCharacter(widget.darkSet) != ChessCharacter.none ||
      checkersCharacter(widget.lightSet) != ChessCharacter.none;

  /// Anything moving on its own right now.
  bool get _alive =>
      _flight != null ||
      widget.interactive ||
      widget.gameOver ||
      widget.selected != null ||
      _faced;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    _wake();
  }

  void _tick(Duration _) {
    final now = _now;
    final f = _flight;
    if (f != null) {
      final e = now - f.started;
      while (f.hopsHeard < f.hops && e >= (f.hopsHeard + 1) * f.hopSecs) {
        f.hopsHeard++;
        widget.onHop?.call(f.hopsHeard, f.move.isCapture);
      }
      if (f.move.promotes &&
          !f.crownHeard &&
          e >= f.travel + _crownSecs * 0.6) {
        f.crownHeard = true;
        widget.onCrown?.call();
      }
      if (e > f.length) _flight = null;
      _clock.value = now;
    } else {
      // Nothing urgent: faces and pulses are fine at half the frame rate.
      if ((++_frame).isOdd) _clock.value = now;
    }
    if (!_alive) _ticker.stop();
  }

  void _wake() {
    if (_alive && !_ticker.isActive) _ticker.start();
  }

  @override
  void didUpdateWidget(covariant CheckersBoard old) {
    super.didUpdateWidget(old);
    final fly = widget.fly;
    if (fly != null && !identical(fly, old.fly)) {
      _flight = _Flight(fly, [
        for (final s in fly.captured)
          old.position.at(s) ?? CheckersPiece(fly.piece.side.opponent),
      ], _now);
    } else if (fly == null) {
      _flight = null;
    }
    if (widget.gameOver && !old.gameOver) _overAt = _now;
    _wake();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  bool get _flipped => widget.bottom == CheckersSide.light;

  int? _squareAtPoint(Offset p, double sq) {
    var col = (p.dx / sq).floor();
    var row = (p.dy / sq).floor();
    if (_flipped) {
      col = 7 - col;
      row = 7 - row;
    }
    return squareAt(row, col);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        final sq = size / 8;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: widget.interactive && widget.onSquareTap != null
              ? (d) {
                  final s = _squareAtPoint(d.localPosition, sq);
                  if (s != null) widget.onSquareTap!(s);
                }
              : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size.square(size),
                painter: _BoardPainter(
                  board: widget,
                  clock: _clock,
                  flight: () => _flight,
                  overAt: _overAt,
                  flipped: _flipped,
                  accent: AppColors.accent,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.board,
    required this.clock,
    required this.flight,
    required this.overAt,
    required this.flipped,
    required this.accent,
  }) : super(repaint: clock);

  final CheckersBoard board;
  final ValueNotifier<double> clock;
  final _Flight? Function() flight;
  final double overAt;
  final bool flipped;
  final Color accent;

  late double _sq;

  Offset _center(int s) {
    var r = rowOf(s);
    var c = colOf(s);
    if (flipped) {
      r = 7 - r;
      c = 7 - c;
    }
    return Offset((c + 0.5) * _sq, (r + 0.5) * _sq);
  }

  Rect _rect(int s) =>
      Rect.fromCenter(center: _center(s), width: _sq, height: _sq);

  String? _setOf(CheckersSide side) =>
      side == CheckersSide.dark ? board.darkSet : board.lightSet;

  @override
  void paint(Canvas canvas, Size size) {
    _sq = size.width / 8;
    final now = clock.value;
    final f = flight();

    _squares(canvas, size);
    _highlights(canvas, now, f);

    // Pieces (the flyer and its victims are drawn separately).
    final r = _sq * 0.38;
    final scared = {for (final m in board.targets) ...m.captured};
    for (var s = 0; s < 32; s++) {
      final piece = board.position.at(s);
      if (piece == null) continue;
      if (f != null && s == f.move.to) continue;
      var c = _center(s);
      final phase = s * 0.73;
      var face = DiscFace.calm;
      Offset? ground;
      if (board.gameOver) {
        final won = board.winner == piece.side;
        final lost = board.winner != null && !won;
        face = won ? DiscFace.happy : (lost ? DiscFace.sad : DiscFace.calm);
        if (won) {
          final hop = math.max(0.0, math.sin((now - overAt) * 6 - phase));
          ground = c;
          c = c.translate(0, -_sq * 0.14 * hop);
        }
      } else if (scared.contains(s)) {
        face = DiscFace.scared;
        c = c.translate(_sq * 0.012 * math.sin(now * 40 + phase), 0);
      } else if (s == board.selected) {
        ground = c;
        c = c.translate(0, -_sq * (0.08 + 0.02 * math.sin(now * 5)));
      }
      _disc(canvas, c, r, piece, now, phase, face: face, ground: ground);
    }

    if (f != null) _flying(canvas, now, f, r);
  }

  void _disc(
    Canvas canvas,
    Offset c,
    double r,
    CheckersPiece piece,
    double now,
    double phase, {
    DiscFace face = DiscFace.calm,
    Offset? ground,
    double crown = 1,
    double opacity = 1,
    Offset? lookAt,
  }) {
    final set = _setOf(piece.side);
    final character = checkersCharacter(set);
    var blink = 0.0;
    var look = Offset(math.sin(now * 0.6 + phase) * 0.5, 0);
    if (character != ChessCharacter.none) {
      final k = (now + phase) % 4.4;
      if (k < 0.16) blink = math.sin(k / 0.16 * math.pi);
      if (lookAt != null) {
        final d = lookAt - c;
        if (d.distance > 1) look = d / d.distance;
      }
    }
    paintCheckersDisc(
      canvas,
      c,
      r,
      finish: checkersFinish(set, piece.side),
      king: piece.king,
      crown: crown,
      character: character,
      face: face,
      blink: blink,
      look: look,
      ground: ground,
      opacity: opacity,
      turned: piece.side == board.turnedFor,
    );
  }

  void _squares(Canvas canvas, Size size) {
    final dark = Color.lerp(_darkSquare, accent, 0.18)!;
    canvas.drawRect(Offset.zero & size, Paint()..color = _lightSquare);
    for (var row = 0; row < 8; row++) {
      for (var col = 0; col < 8; col++) {
        if ((row + col).isEven) continue;
        final rect = Rect.fromLTWH(col * _sq, row * _sq, _sq, _sq);
        canvas.drawRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color.lerp(dark, Colors.white, 0.08)!, dark],
            ).createShader(rect),
        );
        // A soft inner edge, so the squares read as inlaid.
        canvas.drawRect(
          rect.deflate(_sq * 0.03),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = _sq * 0.03
            ..color = Colors.black.withValues(alpha: 0.12),
        );
      }
    }
  }

  void _highlights(Canvas canvas, double now, _Flight? f) {
    final last = board.lastMove;
    if (last != null) {
      final glow = Paint()..color = _lastMoveGlow.withValues(alpha: 0.26);
      canvas.drawRect(_rect(last.from), glow);
      canvas.drawRect(
        _rect(last.to),
        Paint()..color = _lastMoveGlow.withValues(alpha: 0.4),
      );
      if (last.path.length > 2 || last.isCapture) {
        _pathLine(canvas, last.path, _lastMoveGlow.withValues(alpha: 0.55));
      }
    }

    final pulse = 0.5 + 0.5 * math.sin(now * 4);
    final mustCapture = board.mustCapture;
    if (board.interactive && board.selected == null) {
      for (final s in board.movable) {
        final color = mustCapture ? _mustCapture : AppColors.mint;
        canvas.drawCircle(
          _center(s),
          _sq * (0.44 + 0.03 * pulse),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = _sq * 0.05
            ..color = color.withValues(alpha: 0.45 + 0.4 * pulse)
            ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3),
        );
      }
    }

    final sel = board.selected;
    if (sel != null) {
      canvas.drawRect(
        _rect(sel),
        Paint()..color = _selectGlow.withValues(alpha: 0.32),
      );
    }

    for (final m in board.targets) {
      final c = _center(m.to);
      if (m.isCapture) {
        _pathLine(canvas, m.path, _mustCapture.withValues(alpha: 0.75));
        for (final v in m.captured) {
          canvas.drawCircle(
            _center(v),
            _sq * 0.46,
            Paint()
              ..color = _mustCapture.withValues(alpha: 0.18 + 0.12 * pulse),
          );
        }
        canvas.drawCircle(
          c,
          _sq * 0.36,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = _sq * 0.07
            ..color = _mustCapture.withValues(alpha: 0.9),
        );
      } else {
        canvas.drawCircle(
          c,
          _sq * (0.14 + 0.02 * pulse),
          Paint()..color = AppColors.mint.withValues(alpha: 0.85),
        );
      }
    }
  }

  void _pathLine(Canvas canvas, List<int> path, Color color) {
    final p = Path()..moveTo(_center(path.first).dx, _center(path.first).dy);
    for (final s in path.skip(1)) {
      p.lineTo(_center(s).dx, _center(s).dy);
    }
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = _sq * 0.08
        ..color = color,
    );
    for (final s in path.skip(1).take(path.length - 2)) {
      canvas.drawCircle(_center(s), _sq * 0.1, Paint()..color = color);
    }
  }

  void _flying(Canvas canvas, double now, _Flight f, double r) {
    final e = now - f.started;
    final move = f.move;

    // The jumped pieces: there until the flyer passes over, then they pop.
    for (final (i, s) in move.captured.indexed) {
      final hit = (i + 0.5) * f.hopSecs;
      final k = (e - hit) / _popSecs;
      final c = _center(s);
      final victim = i < f.victims.length
          ? f.victims[i]
          : CheckersPiece(move.piece.side.opponent);
      if (k < 0) {
        _disc(canvas, c, r, victim, now, s * 0.73, face: DiscFace.scared);
        continue;
      }
      if (k > 1) continue;
      final grow = k < 0.25
          ? 1 + 0.25 * (k / 0.25)
          : 1.25 * (1 - (k - 0.25) / 0.75);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(k * 2.4);
      canvas.translate(-c.dx, -c.dy);
      _disc(
        canvas,
        c,
        r * grow,
        victim,
        now,
        0,
        face: DiscFace.ko,
        opacity: (1 - k).clamp(0.0, 1.0),
      );
      canvas.restore();
      // A burst of sparks in the victim's colour.
      final finish = checkersFinish(_setOf(victim.side), victim.side);
      final spark = Paint()
        ..color = finish.gradient[1].withValues(alpha: (1 - k) * 0.9);
      for (var j = 0; j < 9; j++) {
        final a = j * 2 * math.pi / 9 + s;
        final d = _sq * (0.2 + 0.55 * Curves.easeOut.transform(k));
        canvas.drawCircle(
          c + Offset(math.cos(a), math.sin(a)) * d,
          _sq * 0.045 * (1 - k),
          spark,
        );
      }
    }

    // The mover.
    final hop = math.min((e / f.hopSecs).floor(), f.hops - 1);
    final t = e >= f.travel
        ? 1.0
        : ((e - hop * f.hopSecs) / f.hopSecs).clamp(0.0, 1.0);
    final from = _center(move.path[hop]);
    final to = _center(move.path[hop + 1]);
    final ground = Offset.lerp(from, to, Curves.easeInOutCubic.transform(t))!;
    final arc = math.sin(t * math.pi) * (move.isCapture ? 0.62 : 0.28);
    final air = ground.translate(0, -_sq * arc);
    final landed = e >= f.travel;
    final crown = move.promotes && landed
        ? ((e - f.travel) / _crownSecs).clamp(0.0, 1.0)
        : (move.piece.king ? 1.0 : 0.0);
    final piece = move.promotes && landed ? move.piece.crowned() : move.piece;
    // Lands with a little squash.
    final squash = landed
        ? 1 + 0.08 * math.sin(((e - f.travel) / 0.2).clamp(0.0, 1.0) * math.pi)
        : 1 + arc * 0.25;
    _disc(
      canvas,
      air,
      r * squash,
      piece,
      now,
      0,
      face: landed ? DiscFace.happy : DiscFace.calm,
      ground: arc > 0.01 ? ground : null,
      crown: crown,
      lookAt: to,
    );

    // Sparkles as the crown lands.
    if (move.promotes && landed) {
      final k = ((e - f.travel) / _crownSecs).clamp(0.0, 1.0);
      if (k > 0.55) {
        final s = (k - 0.55) / 0.45;
        final p = Paint()
          ..color = const Color(0xFFFFE27A).withValues(alpha: 1 - s);
        for (var j = 0; j < 8; j++) {
          final a = j * math.pi / 4 + 0.3;
          canvas.drawCircle(
            air + Offset(math.cos(a), math.sin(a)) * _sq * (0.3 + 0.35 * s),
            _sq * 0.04 * (1 - s),
            p,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}
