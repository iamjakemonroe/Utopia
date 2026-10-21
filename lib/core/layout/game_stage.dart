import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// A game's screen: its [board] and what goes around it (the players'
/// bars, the moves, the controls).
///
/// On a phone held upright: a column, [above] the board and [below] it,
/// the board as big as the rest leaves room for. On a tablet (either way
/// up) or a phone on its side: two columns, the board on the left as big
/// as it can be and the rest in a panel beside it as tall as the board,
/// [above] level with its top and [below] with its bottom.
class GameStage extends StatelessWidget {
  const GameStage({
    super.key,
    required this.board,
    this.above = const [],
    this.below = const [],
    this.panelWidth = 360,
    this.panelFill,
    this.tabletsUpright = true,
  });

  final Widget board;
  final List<Widget> above;
  final List<Widget> below;
  final double panelWidth;

  /// Fills the panel's room between [above] and [below] when side by side
  /// (a game's chat, say, which sits under the board in a column).
  final Widget? panelFill;

  /// Side by side on a tablet held upright too. Off, an upright tablet gets
  /// the column a phone does (its board as wide as the screen).
  final bool tabletsUpright;

  /// Whether the stage around [context] is side by side.
  static bool sideBySideOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_StageMode>()?.sideBySide ??
      false;

  static const _gap = 16.0;

  /// Whether [size] (the room the stage has) lays out side by side: a
  /// tablet's, or anything wide enough for both.
  static bool sideBySide(
    Size size, {
    double panelWidth = 360,
    bool tabletsUpright = true,
  }) {
    final tablet =
        size.shortestSide >= 600 &&
        size.width >= 700 &&
        (tabletsUpright || size.width > size.height);
    final wide =
        size.width > size.height * 1.15 &&
        size.width - size.height >= panelWidth * 0.75;
    return tablet || wide;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!sideBySide(
          constraints.biggest,
          panelWidth: panelWidth,
          tabletsUpright: tabletsUpright,
        )) {
          return _StageMode(
            sideBySide: false,
            child: Column(
              children: [
                ...above,
                Expanded(child: board),
                ...below,
              ],
            ),
          );
        }
        // The panel as tall as the board, so what's above lines up with
        // its top and what's below with its bottom, the pair centered.
        final side = math.min(
          constraints.maxWidth - panelWidth - _gap,
          constraints.maxHeight,
        );
        return Center(
          child: SizedBox(
            height: side,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: side,
                  child: _StageMode(sideBySide: true, child: board),
                ),
                const SizedBox(width: _gap),
                SizedBox(
                  width: panelWidth,
                  child: Column(
                    children: [
                      ...above,
                      if (panelFill case final fill?)
                        Expanded(child: fill)
                      else
                        const Spacer(),
                      ...below,
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StageMode extends InheritedWidget {
  const _StageMode({required this.sideBySide, required super.child});

  final bool sideBySide;

  @override
  bool updateShouldNotify(_StageMode old) => old.sideBySide != sideBySide;
}
