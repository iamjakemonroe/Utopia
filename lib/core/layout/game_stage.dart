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
  });

  final Widget board;
  final List<Widget> above;
  final List<Widget> below;
  final double panelWidth;

  static const _gap = 16.0;

  /// Whether [size] (the room the stage has) lays out side by side: a
  /// tablet's, or anything wide enough for both.
  static bool sideBySide(Size size, {double panelWidth = 360}) {
    final tablet = size.shortestSide >= 600 && size.width >= 700;
    final wide =
        size.width > size.height * 1.15 &&
        size.width - size.height >= panelWidth * 0.75;
    return tablet || wide;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!sideBySide(constraints.biggest, panelWidth: panelWidth)) {
          return Column(
            children: [
              ...above,
              Expanded(child: board),
              ...below,
            ],
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
                SizedBox(width: side, child: board),
                const SizedBox(width: _gap),
                SizedBox(
                  width: panelWidth,
                  child: Column(children: [...above, const Spacer(), ...below]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
