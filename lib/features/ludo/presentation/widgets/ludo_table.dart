import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../domain/ludo_engine.dart';

/// A seat at the table: its color and the direction its yard is drawn in
/// on screen ([x] right, [y] down, each -1 to 1).
typedef LudoSeat = ({LudoColor color, double x, double y});

/// The board with each player's panel by the part of it their yard is
/// drawn in, laid out for the room there is.
///
/// Upright (a phone, a tablet held upright): a row of seats above the
/// board and a row below, each row as wide as the board, so every panel
/// sits by its own corner. Wide (a tablet or phone on its side, a
/// computer): a column of seats either side of the board, each level with
/// its yard, the board as tall as the room. Whichever leaves the board
/// bigger. If the room's smaller than the table even so (big text, a
/// short window), the whole table shrinks to fit: nothing's ever cut off.
class LudoTable extends StatelessWidget {
  const LudoTable({
    super.key,
    required this.board,
    required this.boardAspect,
    required this.seats,
    required this.panel,
  });

  final Widget board;

  /// The board's width over its height.
  final double boardAspect;
  final List<LudoSeat> seats;
  final Widget Function(LudoColor color, {required bool mirrored}) panel;

  /// A seat panel's size at the usual text size.
  static const panelSize = Size(120, 104);
  static const _gap = 6.0;

  /// Whether [size] lays the seats out beside the board.
  static bool wide(Size size, List<LudoSeat> seats, double boardAspect) =>
      _wideSide(size, seats, boardAspect) >
      _uprightSide(size, seats, boardAspect) * 1.1;

  static bool _isMiddle(LudoSeat s) => s.x.abs() <= 0.3;

  /// The board's height upright: what the rows above and below leave.
  static double _uprightSide(Size size, List<LudoSeat> seats, double aspect) {
    var rows = 0.0;
    if (seats.any((s) => s.y < 0)) rows += panelSize.height + _gap;
    if (seats.any((s) => s.y >= 0)) rows += panelSize.height + _gap;
    return math.max(0, math.min(size.height - rows, size.width / aspect));
  }

  /// The board's height wide: what the columns either side leave.
  static double _wideSide(Size size, List<LudoSeat> seats, double aspect) {
    final columns = 2 * (panelSize.width + _gap);
    return math.max(0, math.min(size.height, (size.width - columns) / aspect));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: wide(size, seats, boardAspect)
                ? _wideTable(size)
                : _uprightTable(size),
          ),
        );
      },
    );
  }

  Widget _uprightTable(Size size) {
    final height = _uprightSide(size, seats, boardAspect);
    final width = height * boardAspect;
    final top = [
      for (final s in seats)
        if (s.y < 0) s,
    ];
    final bottom = [
      for (final s in seats)
        if (s.y >= 0) s,
    ];
    // Never narrower than its panels side by side.
    final across = math.max(
      width,
      panelSize.width * (seats.any(_isMiddle) ? 3 : 2) + 2 * _gap,
    );

    Widget row(List<LudoSeat> row) {
      LudoColor? at(bool Function(double) where) =>
          row.where((s) => where(s.x)).map((s) => s.color).firstOrNull;
      final left = at((x) => x < -0.3);
      final middle = at((x) => x >= -0.3 && x <= 0.3);
      final right = at((x) => x > 0.3);
      return SizedBox(
        width: across,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            left == null
                ? SizedBox(width: panelSize.width)
                : panel(left, mirrored: false),
            if (middle != null) panel(middle, mirrored: false),
            right == null
                ? SizedBox(width: panelSize.width)
                : panel(right, mirrored: true),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (top.isNotEmpty) ...[row(top), const SizedBox(height: _gap)],
        SizedBox(width: width, height: height, child: board),
        if (bottom.isNotEmpty) ...[const SizedBox(height: _gap), row(bottom)],
      ],
    );
  }

  Widget _wideTable(Size size) {
    final height = _wideSide(size, seats, boardAspect);
    final width = height * boardAspect;
    final ph = panelSize.height;

    // Each side's seats, top to bottom. The six-seat board's top seat
    // goes to the left and its bottom one to the right, so the order
    // round the table stays the board's.
    List<LudoSeat> side(bool right) => [
      for (final s in seats)
        if (_isMiddle(s) ? (s.y >= 0) == right : (s.x > 0) == right) s,
    ]..sort((a, b) => a.y.compareTo(b.y));
    final left = side(false);
    final right = side(true);
    final most = math.max(left.length, right.length);
    // Tall enough for a side's panels one above another.
    final tall = math.max(height, most * ph + (most - 1) * _gap);
    final boardTop = (tall - height) / 2;

    // Each panel level with its yard, as near as there's room for.
    List<double> tops(List<LudoSeat> column) {
      final ys = [
        for (final s in column)
          (boardTop + height / 2 * (1 + s.y) - ph / 2).clamp(0.0, tall - ph),
      ];
      for (var i = 1; i < ys.length; i++) {
        ys[i] = math.max(ys[i], ys[i - 1] + ph + _gap);
      }
      for (var i = ys.length - 1; i >= 0; i--) {
        final limit = i == ys.length - 1 ? tall - ph : ys[i + 1] - ph - _gap;
        ys[i] = math.min(ys[i], limit);
      }
      return ys;
    }

    final leftTops = tops(left);
    final rightTops = tops(right);
    // The board first, so the panels (and their speech bubbles, which
    // reach over its edge) are drawn on top.
    return SizedBox(
      width: width + 2 * (panelSize.width + _gap),
      height: tall,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: panelSize.width + _gap,
            top: boardTop,
            width: width,
            height: height,
            child: board,
          ),
          for (var i = 0; i < left.length; i++)
            Positioned(
              left: 0,
              top: leftTops[i],
              child: panel(left[i].color, mirrored: false),
            ),
          for (var i = 0; i < right.length; i++)
            Positioned(
              right: 0,
              top: rightTops[i],
              child: panel(right[i].color, mirrored: true),
            ),
        ],
      ),
    );
  }
}
