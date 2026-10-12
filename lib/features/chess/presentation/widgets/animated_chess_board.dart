import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/chess_engine.dart';
import '../../domain/chess_move.dart';
import '../../domain/chess_position.dart';
import '../../domain/chess_types.dart';
import 'chess_piece_styles.dart';
import 'chess_piece_art.dart';

const ChessEngine _engine = ChessEngine();

// Warm cream / deep violet pair — a "royal chess set" look matching the
// app's gold-trim-on-dark-violet theme, while keeping enough contrast for
// both piece colors to read clearly on either square.
const Color _lightSquare = Color(0xFFEFDFAE);
const Color _darkSquare = Color(0xFF2E2260);
const Color _selectedGlow = Color(0xFF7C4DFF);
const Color _lastMoveGlow = Color(0xFFFFC94D);
const Color _checkGlow = Color(0xFFFF5A5F);

/// The animated 8x8 board: static piece layer, move/selection highlights,
/// and a "flying piece" overlay that tweens position+scale for the most
/// recent move instead of pieces just teleporting to their new square.
///
/// Orientation follows [myColor] — a black player sees their own back rank
/// at the bottom, mirroring both axes, the same way physical boards are
/// turned around.
class AnimatedChessBoard extends StatefulWidget {
  const AnimatedChessBoard({
    super.key,
    required this.position,
    required this.lastMove,
    required this.legalDestinations,
    required this.selectedSquare,
    required this.myColor,
    required this.interactive,
    required this.onSquareTap,
    this.fly,
    this.trail = false,
    this.whiteSet = 'classic',
    this.blackSet = 'classic',
    this.gameOver = false,
    this.winner,
    this.turnedFor,
  });

  /// Two people face to face over one phone: this side's pieces are drawn
  /// turned around, so the player across the table sees them upright.
  final PieceColor? turnedFor;

  /// The game has ended: the winners cheer, the losing king topples.
  final bool gameOver;

  /// Who won, or null for a draw (with [gameOver]).
  final PieceColor? winner;

  /// The move to animate. A new object starts a new flight; stepping back
  /// through a game passes the move in reverse. Null for none.
  final ChessMove? fly;

  /// Draws a glowing trail along [lastMove], so the opponent's move stands
  /// out at a glance.
  final bool trail;

  /// Each side's equipped piece set (see [ChessPieceStyle]).
  final String whiteSet;
  final String blackSet;

  final ChessPosition position;
  final ChessMove? lastMove;
  final List<ChessMove> legalDestinations;
  final Square? selectedSquare;
  final PieceColor? myColor;
  final bool interactive;
  final ValueChanged<Square> onSquareTap;

  @override
  State<AnimatedChessBoard> createState() => _AnimatedChessBoardState();
}

class _AnimatedChessBoardState extends State<AnimatedChessBoard>
    with TickerProviderStateMixin {
  late final AnimationController _moveController;
  ChessPosition? _priorPosition;
  ChessMove? _animatingMove;

  /// Seconds, for the pieces' reactions and faces. Its ticker only runs
  /// while something on the board is moving or has a face.
  final _clock = ValueNotifier<double>(0);
  late final Ticker _ticker;
  final _started = Stopwatch()..start();
  double _lastTick = -1;

  /// When the latest move landed, and when the game ended (seconds on
  /// [_clock]'s stopwatch).
  double _movedAt = -100;
  double _overAt = -100;

  /// How long the piece that just moved celebrates.
  static const _celebrate = 1.6;

  bool get _flipped => widget.myColor == PieceColor.black;

  double get _now => _started.elapsedMicroseconds / 1e6;

  @override
  void initState() {
    super.initState();
    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _ticker = createTicker((_) => _tick());
    if (widget.gameOver) _overAt = _now;
  }

  void _tick() {
    final now = _now;
    if (!_needsMotion(now)) {
      _ticker.stop();
      _clock.value = now;
      return;
    }
    // Faces alone (blinks, LED scans) only need a gentle rate; reactions
    // get every frame.
    final gentle = !_reacting(now);
    if (gentle && now - _lastTick < 1 / 20) return;
    _lastTick = now;
    _clock.value = now;
  }

  bool get _hasFaces =>
      _characterOf(PieceColor.white) != ChessCharacter.none ||
      _characterOf(PieceColor.black) != ChessCharacter.none;

  /// Something is hopping, shaking or toppling right now.
  bool _reacting(double now) {
    if (widget.selectedSquare != null) return true;
    if (now - _movedAt < _celebrate) return true;
    if (widget.gameOver) return true;
    _positionMoods();
    return _moodsCheck;
  }

  bool _needsMotion(double now) => _hasFaces || _reacting(now);

  void _wake() {
    if (!_ticker.isActive && _needsMotion(_now)) _ticker.start();
  }

  @override
  void didUpdateWidget(covariant AnimatedChessBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newFlight = !identical(widget.fly, oldWidget.fly);
    if (newFlight && widget.fly != null) {
      _priorPosition = oldWidget.position;
      _animatingMove = widget.fly;
      _moveController.forward(from: 0);
      _movedAt = _now;
    } else if (newFlight || !identical(widget.position, oldWidget.position)) {
      // The board jumped (back to live, a refused move): show it as is.
      _animatingMove = null;
    }
    if (widget.gameOver && !oldWidget.gameOver) _overAt = _now;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    _moveController.dispose();
    super.dispose();
  }

  ChessCharacter _characterOf(PieceColor color) => ChessPieceStyle.byId(
    color == PieceColor.white ? widget.whiteSet : widget.blackSet,
  ).character;

  // ── moods ────────────────────────────────────────────────────────────────

  ChessPosition? _moodsFor;
  bool? _moodsOver;
  PieceColor? _moodsWinner;
  Map<Square, PieceMood> _moods = const {};
  bool _moodsCheck = false;

  /// How each piece feels about the position: worked out once per
  /// position, not per frame.
  Map<Square, PieceMood> _positionMoods() {
    final p = widget.position;
    if (identical(p, _moodsFor) &&
        _moodsOver == widget.gameOver &&
        _moodsWinner == widget.winner) {
      return _moods;
    }
    final moods = <Square, PieceMood>{};
    final toMove = p.sideToMove;
    final inCheck = !widget.gameOver && _engine.isInCheck(p, toMove);
    for (var rank = 0; rank < 8; rank++) {
      for (var file = 0; file < 8; file++) {
        final piece = p.board[rank][file];
        if (piece == null) continue;
        final square = Square(file, rank);
        PieceMood mood = PieceMood.idle;
        if (widget.gameOver) {
          final winner = widget.winner;
          if (winner == null) {
            mood = PieceMood.meh;
          } else if (piece.color == winner) {
            mood = PieceMood.cheer;
          } else {
            mood = piece.type == PieceType.king ? PieceMood.ko : PieceMood.sad;
          }
        } else if (piece.type == PieceType.king &&
            piece.color == toMove &&
            inCheck) {
          mood = PieceMood.panic;
        } else if (piece.type != PieceType.king &&
            _engine.isSquareAttacked(p, square, piece.color.opponent)) {
          mood = PieceMood.scared;
        }
        moods[square] = mood;
      }
    }
    _moodsFor = p;
    _moodsOver = widget.gameOver;
    _moodsWinner = widget.winner;
    _moodsCheck = inCheck;
    return _moods = moods;
  }

  /// The mood right now: the position's, unless the piece was just picked
  /// up or just moved.
  PieceMood _moodAt(Square square, ChessPiece piece, double now) {
    final base = _positionMoods()[square] ?? PieceMood.idle;
    if (widget.gameOver) return base;
    if (square == widget.selectedSquare) return PieceMood.ready;
    final last = widget.lastMove;
    if (last != null && square == last.to && now - _movedAt < _celebrate) {
      if (base == PieceMood.scared) return base;
      return last.isCapture || _justCaptured
          ? PieceMood.proud
          : PieceMood.happy;
    }
    return base;
  }

  bool get _justCaptured {
    final move = _animatingMove;
    if (move == null) return false;
    final prior = _priorPosition?.at(move.to);
    return prior != null && prior.color != move.piece.color;
  }

  /// Where a piece glances: toward the piece in hand, or the one that just
  /// moved.
  double _lookFor(Square square, double now) {
    final target =
        widget.selectedSquare ??
        (now - _movedAt < 3 ? widget.lastMove?.to : null);
    if (target == null || target == square) return 0;
    return ((_screenCol(target.file) - _screenCol(square.file)) / 3).clamp(
      -1.0,
      1.0,
    );
  }

  /// The motion that goes with a mood: a hop, a shake, a topple. Pieces
  /// pivot on their base.
  Matrix4? _motion(
    PieceMood mood,
    double now,
    double phase,
    double size,
    bool faced,
  ) {
    final since = now - _movedAt;
    double dx = 0, dy = 0, rot = 0, sx = 1, sy = 1;
    switch (mood) {
      case PieceMood.ready:
        dy = -size * (0.08 + 0.03 * math.sin(now * 6));
      case PieceMood.happy || PieceMood.proud:
        final hops = mood == PieceMood.proud ? 3 : 2;
        final k = (since / _celebrate).clamp(0.0, 1.0);
        dy =
            -size *
            (mood == PieceMood.proud ? 0.2 : 0.14) *
            (1 - k) *
            math.sin(k * hops * math.pi).abs();
        if (mood == PieceMood.proud) {
          rot = math.sin(since * 14) * 0.08 * (1 - k);
        }
      // Gentle, in short bursts: a board full of shaking pieces was too
      // much to look at. A king in check jolts now and then; a piece under
      // attack gives the odd little shiver.
      case PieceMood.panic:
        final k = (now % 1.8) / 0.45;
        if (k < 1) dx = size * 0.018 * math.sin(k * 6 * math.pi) * (1 - k);
        sy = 1 + 0.015 * math.sin(now * 5);
      case PieceMood.scared:
        if (faced) {
          final k = ((now + phase) % 4.2) / 0.3;
          if (k < 1) dx = size * 0.008 * math.sin(k * 4 * math.pi);
        }
      case PieceMood.cheer:
        dy = -size * 0.14 * math.max(0.0, math.sin(now * 6 - phase));
      case PieceMood.ko:
        final k = Curves.easeInBack.transform(
          ((now - _overAt) / 0.9).clamp(0.0, 1.0),
        );
        rot = 1.35 * k;
        dy = size * 0.05 * k;
      case PieceMood.sad:
        rot = -0.06;
        dy = size * 0.02;
      default:
        if (faced) {
          sy = 1 + 0.025 * math.sin(now * 2.2 + phase);
          sx = 1 - 0.012 * math.sin(now * 2.2 + phase);
        }
    }
    if (dx == 0 && dy == 0 && rot == 0 && sx == 1 && sy == 1) return null;
    return Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..translateByDouble(size / 2, size * 0.92, 0, 1)
      ..rotateZ(rot)
      ..scaleByDouble(sx, sy, 1, 1)
      ..translateByDouble(-size / 2, -size * 0.92, 0, 1);
  }

  ChessPieceFinish _finish(PieceColor color) => ChessPieceStyle.byId(
    color == PieceColor.white ? widget.whiteSet : widget.blackSet,
  ).of(color);

  /// [piece] the right way up for whoever it belongs to (see
  /// [AnimatedChessBoard.turnedFor]).
  Widget _upright(PieceColor color, Widget piece) => color == widget.turnedFor
      ? RotatedBox(quarterTurns: 2, child: piece)
      : piece;

  int _screenRow(int rank) => _flipped ? rank : 7 - rank;
  int _screenCol(int file) => _flipped ? 7 - file : file;

  Offset _squareOffset(Square s, double size) =>
      Offset(_screenCol(s.file) * size, _screenRow(s.rank) * size);

  Offset _squareCenter(Square s, double size) =>
      _squareOffset(s, size) + Offset(size / 2, size / 2);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        final squareSize = size / 8;
        final kingInCheckSquare = _kingInCheckSquare();

        return SizedBox(
          width: size,
          height: size,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                _boardSquares(squareSize),
                _highlights(squareSize, kingInCheckSquare),
                if (widget.trail && widget.lastMove != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _TrailPainter(
                          from: _squareCenter(
                            widget.lastMove!.from,
                            squareSize,
                          ),
                          to: _squareCenter(widget.lastMove!.to, squareSize),
                          knight:
                              widget.lastMove!.piece.type == PieceType.knight,
                          squareSize: squareSize,
                        ),
                      ),
                    ),
                  ),
                _staticPieces(squareSize),
                if (_animatingMove != null) _capturedPieceFade(squareSize),
                if (_animatingMove != null) _flyingPiece(squareSize),
                if (widget.trail && widget.lastMove != null)
                  _LandingRing(
                    key: ValueKey(widget.lastMove),
                    offset: _squareOffset(widget.lastMove!.to, squareSize),
                    squareSize: squareSize,
                  ),
                _tapTargets(squareSize),
              ],
            ),
          ),
        );
      },
    );
  }

  Square? _kingInCheckSquare() {
    final color = widget.position.sideToMove;
    if (!_engine.isInCheck(widget.position, color)) return null;
    for (var rank = 0; rank < 8; rank++) {
      for (var file = 0; file < 8; file++) {
        final piece = widget.position.board[rank][file];
        if (piece != null &&
            piece.type == PieceType.king &&
            piece.color == color) {
          return Square(file, rank);
        }
      }
    }
    return null;
  }

  Widget _boardSquares(double squareSize) {
    return Column(
      children: List.generate(8, (screenRow) {
        return Row(
          children: List.generate(8, (screenCol) {
            final isLight = (screenRow + screenCol) % 2 == 0;
            return Container(
              width: squareSize,
              height: squareSize,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isLight
                      ? [_lightSquare, _lightSquare.withValues(alpha: 0.85)]
                      : [_darkSquare, _darkSquare.withValues(alpha: 0.95)],
                ),
              ),
            );
          }),
        );
      }),
    );
  }

  Widget _highlights(double squareSize, Square? kingInCheckSquare) {
    final children = <Widget>[];

    void glow(Square s, Color color, {double opacity = 0.55}) {
      final offset = _squareOffset(s, squareSize);
      children.add(
        Positioned(
          left: offset.dx,
          top: offset.dy,
          width: squareSize,
          height: squareSize,
          child: DecoratedBox(
            decoration: BoxDecoration(color: color.withValues(alpha: opacity)),
          ),
        ),
      );
    }

    final lastMove = widget.lastMove;
    if (lastMove != null) {
      glow(lastMove.from, _lastMoveGlow, opacity: widget.trail ? 0.3 : 0.22);
      glow(lastMove.to, _lastMoveGlow, opacity: widget.trail ? 0.48 : 0.3);
    }

    if (widget.selectedSquare != null) {
      glow(widget.selectedSquare!, _selectedGlow, opacity: 0.45);
    }

    if (kingInCheckSquare != null) {
      children.add(
        _PulsingCheckRing(
          square: kingInCheckSquare,
          squareSize: squareSize,
          offset: _squareOffset(kingInCheckSquare, squareSize),
        ),
      );
    }

    for (final move in widget.legalDestinations) {
      final offset = _squareOffset(move.to, squareSize);
      final isCapture = move.isCapture;
      children.add(
        Positioned(
          left: offset.dx,
          top: offset.dy,
          width: squareSize,
          height: squareSize,
          child: Center(
            child: isCapture
                ? Container(
                    width: squareSize * 0.82,
                    height: squareSize * 0.82,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accentSecondary.withValues(
                          alpha: 0.85,
                        ),
                        width: 3,
                      ),
                    ),
                  )
                : Container(
                    width: squareSize * 0.28,
                    height: squareSize * 0.28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accentSecondary.withValues(alpha: 0.75),
                    ),
                  ),
          ),
        ),
      );
    }

    return Stack(children: children);
  }

  Widget _staticPieces(double squareSize) {
    _wake();
    return ValueListenableBuilder<double>(
      valueListenable: _clock,
      builder: (context, _, _) {
        final now = _now;
        final children = <Widget>[];
        for (var rank = 0; rank < 8; rank++) {
          for (var file = 0; file < 8; file++) {
            final square = Square(file, rank);
            if (_animatingMove != null && square == _animatingMove!.to) {
              continue;
            }
            final piece = widget.position.board[rank][file];
            if (piece == null) continue;
            final offset = _squareOffset(square, squareSize);
            final character = _characterOf(piece.color);
            final faced = character != ChessCharacter.none;
            final mood = _moodAt(square, piece, now);
            final phase = (file + rank) * 0.55;
            final glyph = ChessPieceGlyph(
              type: piece.type,
              color: piece.color,
              finish: _finish(piece.color),
              size: squareSize,
              character: character,
              mood: mood,
              t: now,
              look: faced ? _lookFor(square, now) : 0,
              seed: file * 0.37 + rank * 0.71,
            );
            final motion = _motion(mood, now, phase, squareSize, faced);
            children.add(
              Positioned(
                left: offset.dx,
                top: offset.dy,
                width: squareSize,
                height: squareSize,
                child: _upright(
                  piece.color,
                  motion == null
                      ? glyph
                      : Transform(transform: motion, child: glyph),
                ),
              ),
            );
            // The big moments get a badge over the piece, so the reaction
            // reads at a glance: "!" for a king in check, a starburst for a
            // capture.
            final badge = switch (mood) {
              PieceMood.panic => _BadgeKind.alarm,
              PieceMood.proud => _BadgeKind.pow,
              _ => null,
            };
            if (badge != null) {
              final b = squareSize * 0.5;
              children.add(
                Positioned(
                  left: offset.dx + squareSize * 0.62,
                  top: offset.dy - b * 0.45,
                  width: b,
                  height: b,
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _BadgePainter(
                        kind: badge,
                        t: now - (badge == _BadgeKind.pow ? _movedAt : 0),
                      ),
                    ),
                  ),
                ),
              );
            }
          }
        }
        return Stack(clipBehavior: Clip.none, children: children);
      },
    );
  }

  Widget _capturedPieceFade(double squareSize) {
    final move = _animatingMove!;
    final priorPiece = _priorPosition?.at(move.to);
    if (priorPiece == null || priorPiece.color == move.piece.color) {
      return const SizedBox.shrink();
    }

    final offset = _squareOffset(move.to, squareSize);
    return AnimatedBuilder(
      animation: _moveController,
      builder: (context, child) {
        final t = _moveController.value.clamp(0.0, 1.0);
        return Positioned(
          left: offset.dx,
          top: offset.dy,
          width: squareSize,
          height: squareSize,
          child: Opacity(
            opacity: (1 - t).clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: t * 2.4,
              child: Transform.scale(
                scale: 1 - (t * 0.5),
                child: _upright(
                  priorPiece.color,
                  ChessPieceGlyph(
                    type: priorPiece.type,
                    color: priorPiece.color,
                    finish: _finish(priorPiece.color),
                    size: squareSize,
                    character: _characterOf(priorPiece.color),
                    mood: PieceMood.ko,
                    t: _now,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Flies the moved piece from square to square with real 3D motion —
  /// an actual `Matrix4` perspective + rotation, not a flat slide with a
  /// scale pulse. The piece arcs upward (as if lifted off the board),
  /// tilts into the direction of travel the way a carried object leans,
  /// levels out on approach, and squashes on landing for weight. A ground
  /// shadow tracks the piece's un-lifted position and shrinks as it
  /// rises, which is what actually sells "this is above the board" — the
  /// tilt alone reads flat without something fixed to be above.
  Widget _flyingPiece(double squareSize) {
    final move = _animatingMove!;
    final start = _squareOffset(move.from, squareSize);
    final end = _squareOffset(move.to, squareSize);
    final curved = CurvedAnimation(
      parent: _moveController,
      curve: Curves.easeOutCubic,
    );

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final travelDist = math.sqrt(dx * dx + dy * dy);
    final nx = travelDist == 0 ? 0.0 : dx / travelDist;
    final ny = travelDist == 0 ? 0.0 : dy / travelDist;

    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        final t = curved.value;
        final groundPos = Offset.lerp(start, end, t)!;

        // Arc: 0 at takeoff/landing, peaks mid-flight.
        final lift = math.sin(t * math.pi);
        final liftPixels = lift * squareSize * 0.4;

        // Landing squash: a brief flatten-then-recover right at touchdown.
        final squashT = ((t - 0.86) / 0.14).clamp(0.0, 1.0);
        final squash = math.sin(squashT * math.pi) * 0.22;

        final tiltAmount = lift * 0.34;
        final scaleXY = 1.0 + (lift * 0.1);

        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0022) // real perspective, not a fake shadow
          ..rotateY(nx * tiltAmount)
          ..rotateX(-ny * tiltAmount)
          ..scaleByDouble(scaleXY + squash, scaleXY - squash, 1, 1);

        return Stack(
          children: [
            // Ground shadow — fixed to the un-lifted path, shrinks and
            // fades as the piece rises away from it.
            Positioned(
              left: groundPos.dx,
              top: groundPos.dy,
              width: squareSize,
              height: squareSize,
              child: Center(
                child: Container(
                  width: squareSize * (0.5 - lift * 0.16),
                  height: squareSize * (0.16 - lift * 0.06),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.28 - lift * 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            Positioned(
              left: groundPos.dx,
              top: groundPos.dy - liftPixels,
              width: squareSize,
              height: squareSize,
              child: Transform(
                alignment: Alignment.center,
                transform: matrix,
                child: _upright(
                  move.piece.color,
                  ChessPieceGlyph(
                    type: move.piece.type,
                    color: move.piece.color,
                    finish: _finish(move.piece.color),
                    size: squareSize,
                    glowing: true,
                    character: _characterOf(move.piece.color),
                    mood: _justCaptured ? PieceMood.proud : PieceMood.happy,
                    t: _now,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _tapTargets(double squareSize) {
    final children = <Widget>[];
    for (var rank = 0; rank < 8; rank++) {
      for (var file = 0; file < 8; file++) {
        final square = Square(file, rank);
        final offset = _squareOffset(square, squareSize);
        children.add(
          Positioned(
            left: offset.dx,
            top: offset.dy,
            width: squareSize,
            height: squareSize,
            child: widget.interactive
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onSquareTap(square),
                  )
                : const SizedBox.shrink(),
          ),
        );
      }
    }
    return Stack(children: children);
  }
}

/// One chess piece, finished in a piece set's style. Also used by the
/// store to preview piece sets.
class ChessPieceGlyph extends StatelessWidget {
  const ChessPieceGlyph({
    super.key,
    required this.type,
    required this.color,
    required this.size,
    required this.finish,
    this.glowing = false,
    this.character = ChessCharacter.none,
    this.mood = PieceMood.idle,
    this.t = 0,
    this.look = 0,
    this.seed = 0,
  });

  final PieceType type;
  final PieceColor color;
  final double size;
  final ChessPieceFinish finish;
  final bool glowing;
  final ChessCharacter character;
  final PieceMood mood;
  final double t;
  final double look;
  final double seed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: ChessPieceArt(
            type: type,
            finish: finish,
            size: size * 0.88,
            glowColor: glowing ? AppColors.accent.withValues(alpha: 0.9) : null,
            character: character,
            mood: mood,
            t: t,
            look: look,
            seed: seed,
          ),
        ),
      ),
    );
  }
}

class _PulsingCheckRing extends StatefulWidget {
  const _PulsingCheckRing({
    required this.square,
    required this.squareSize,
    required this.offset,
  });

  final Square square;
  final double squareSize;
  final Offset offset;

  @override
  State<_PulsingCheckRing> createState() => _PulsingCheckRingState();
}

class _PulsingCheckRingState extends State<_PulsingCheckRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.offset.dx,
      top: widget.offset.dy,
      width: widget.squareSize,
      height: widget.squareSize,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  _checkGlow.withValues(
                    alpha: 0.15 + (_controller.value * 0.35),
                  ),
                  _checkGlow.withValues(alpha: 0.0),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A glowing trail from where the last move started to where it landed
/// (an L for a knight), drawn under the pieces.
class _TrailPainter extends CustomPainter {
  _TrailPainter({
    required this.from,
    required this.to,
    required this.knight,
    required this.squareSize,
  });

  final Offset from;
  final Offset to;
  final bool knight;
  final double squareSize;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(from.dx, from.dy);
    if (knight) {
      // Along the long leg first, then the short one.
      final d = to - from;
      final corner = d.dx.abs() > d.dy.abs()
          ? Offset(to.dx, from.dy)
          : Offset(from.dx, to.dy);
      path.lineTo(corner.dx, corner.dy);
    }
    path.lineTo(to.dx, to.dy);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = squareSize * 0.3
        ..color = _lastMoveGlow.withValues(alpha: 0.28)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, squareSize * 0.08),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = squareSize * 0.12
        ..color = _lastMoveGlow.withValues(alpha: 0.75),
    );
    canvas.drawCircle(
      from,
      squareSize * 0.12,
      Paint()..color = _lastMoveGlow.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant _TrailPainter old) =>
      old.from != from || old.to != to || old.squareSize != squareSize;
}

/// A ring that pops around the square a move just landed on, then settles
/// into a soft outline.
class _LandingRing extends StatefulWidget {
  const _LandingRing({
    super.key,
    required this.offset,
    required this.squareSize,
  });

  final Offset offset;
  final double squareSize;

  @override
  State<_LandingRing> createState() => _LandingRingState();
}

class _LandingRingState extends State<_LandingRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.offset.dx,
      top: widget.offset.dy,
      width: widget.squareSize,
      height: widget.squareSize,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _pop,
          builder: (context, _) {
            final t = Curves.easeOut.transform(_pop.value);
            final burst = 1 - t;
            return Stack(
              fit: StackFit.expand,
              children: [
                if (burst > 0)
                  Transform.scale(
                    scale: 0.7 + 0.6 * t,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _lastMoveGlow.withValues(alpha: burst),
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(2),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _lastMoveGlow.withValues(alpha: 0.9 * t),
                        width: 2.4,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

enum _BadgeKind { alarm, pow }

/// A little badge over a reacting piece: a red "!" bubble that pulses for a
/// king in check, or a gold starburst that pops when a piece captures.
class _BadgePainter extends CustomPainter {
  _BadgePainter({required this.kind, required this.t});

  final _BadgeKind kind;

  /// Seconds: the clock for the alarm, time since the capture for the pow.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    switch (kind) {
      case _BadgeKind.alarm:
        final pulse = 1 + 0.08 * math.sin(t * 6);
        canvas.drawCircle(
          c,
          r * 0.95 * pulse,
          Paint()..color = const Color(0xFFFF3D5A),
        );
        canvas.drawCircle(
          c,
          r * 0.95 * pulse,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.14
            ..color = Colors.white,
        );
        final bar = Paint()
          ..color = Colors.white
          ..strokeWidth = r * 0.22
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          c.translate(0, -r * 0.42),
          c.translate(0, r * 0.12),
          bar,
        );
        canvas.drawCircle(
          c.translate(0, r * 0.45),
          r * 0.12,
          Paint()..color = Colors.white,
        );
      case _BadgeKind.pow:
        // Pops in, holds, fades.
        final k = (t / 1.4).clamp(0.0, 1.0);
        if (k >= 1) return;
        final pop = Curves.elasticOut.transform((t / 0.5).clamp(0.0, 1.0));
        final alpha = k < 0.7 ? 1.0 : 1 - (k - 0.7) / 0.3;
        final star = Path();
        for (var i = 0; i < 16; i++) {
          final a = i * math.pi / 8 - math.pi / 2;
          final rr = (i.isEven ? r : r * 0.55) * pop;
          final p = c + Offset(math.cos(a), math.sin(a)) * rr;
          i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
        }
        star.close();
        canvas.drawPath(
          star,
          Paint()..color = const Color(0xFFFFC94D).withValues(alpha: alpha),
        );
        canvas.drawPath(
          star,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.1
            ..strokeJoin = StrokeJoin.round
            ..color = const Color(0xFFB4561C).withValues(alpha: alpha),
        );
        canvas.drawCircle(
          c,
          r * 0.2 * pop,
          Paint()..color = Colors.white.withValues(alpha: alpha),
        );
    }
  }

  @override
  bool shouldRepaint(covariant _BadgePainter old) =>
      old.kind != kind || old.t != t;
}
