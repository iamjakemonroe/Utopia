import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/doodle_game.dart';
import '../doodle_ink.dart';

/// The paper everyone watches. For the drawer it takes one finger at a
/// time (a second touch, like a resting palm, is ignored); for everyone
/// else it plays the drawer's strokes back smoothly as they arrive.
class DoodleCanvasView extends StatefulWidget {
  const DoodleCanvasView({
    super.key,
    required this.ink,
    required this.canDraw,
    required this.onStart,
    required this.onMove,
    required this.onEnd,
    this.overlay,
  });

  final DoodleInk ink;
  final bool canDraw;

  /// In page units (see [kDoodleGameSize]).
  final ValueChanged<Offset> onStart;
  final ValueChanged<Offset> onMove;
  final VoidCallback onEnd;

  /// Shown over the paper: word choice, the reveal, the scores.
  final Widget? overlay;

  @override
  State<DoodleCanvasView> createState() => _DoodleCanvasViewState();
}

class _DoodleCanvasViewState extends State<DoodleCanvasView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  int? _pointer;

  @override
  void initState() {
    super.initState();
    // Made here, not on first use: first use might be in dispose, when it
    // can no longer look up the widget tree.
    _ticker = createTicker(_onFrame);
    widget.ink.addListener(_wake);
  }

  @override
  void didUpdateWidget(covariant DoodleCanvasView old) {
    super.didUpdateWidget(old);
    if (old.ink != widget.ink) {
      old.ink.removeListener(_wake);
      widget.ink.addListener(_wake);
    }
    // Lost the pen mid-stroke (time's up): finish the line.
    if (old.canDraw && !widget.canDraw && _pointer != null) {
      _pointer = null;
      final end = widget.onEnd;
      WidgetsBinding.instance.addPostFrameCallback((_) => end());
    }
  }

  /// Runs the playback clock only while strokes are coming in.
  void _wake() {
    if (widget.ink.animating && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _onFrame(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 1 / 60
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    widget.ink.advance(dt.clamp(0.0, 0.1));
    if (!widget.ink.animating) _ticker.stop();
  }

  @override
  void dispose() {
    widget.ink.removeListener(_wake);
    _ticker.dispose();
    super.dispose();
  }

  Offset _page(Offset local, double side) =>
      local * (kDoodleGameSize.width / side);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final side = c.biggest.shortestSide;
        return Center(
          child: SizedBox.square(
            dimension: side,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: widget.canDraw
                      ? AppColors.goldBorderBright
                      : Colors.white.withValues(alpha: 0.7),
                  width: widget.canDraw ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                  if (widget.canDraw)
                    BoxShadow(
                      color: AppColors.coinGold.withValues(alpha: 0.35),
                      blurRadius: 16,
                    ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (e) {
                        if (!widget.canDraw || _pointer != null) return;
                        _pointer = e.pointer;
                        widget.onStart(_page(e.localPosition, side));
                      },
                      onPointerMove: (e) {
                        if (e.pointer != _pointer) return;
                        widget.onMove(_page(e.localPosition, side));
                      },
                      onPointerUp: (e) {
                        if (e.pointer != _pointer) return;
                        _pointer = null;
                        widget.onEnd();
                      },
                      onPointerCancel: (e) {
                        if (e.pointer != _pointer) return;
                        _pointer = null;
                        widget.onEnd();
                      },
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _InkPainter(widget.ink),
                          isComplex: true,
                        ),
                      ),
                    ),
                    ?widget.overlay,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InkPainter extends CustomPainter {
  _InkPainter(this.ink) : super(repaint: ink);

  final DoodleInk ink;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / kDoodleGameSize.width);
    ink.render.paint(canvas, more: ink.liveStrokes);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _InkPainter old) => old.ink != ink;
}
