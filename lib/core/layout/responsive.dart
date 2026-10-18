import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// How much room the app has: a phone ([compact]), a small tablet or a
/// phone on its side ([medium]), or a tablet ([expanded]). The breakpoints
/// are Material's window size classes.
enum WindowSize {
  compact,
  medium,
  expanded;

  static WindowSize of(double width) => width < 600
      ? compact
      : width < 840
      ? medium
      : expanded;
}

/// The widest a column of reading content (lists, forms, cards) gets:
/// wider than this, lines get too long and cards too stretched to scan.
const kReadableWidth = 680.0;

extension Responsive on BuildContext {
  Size get screenSize => MediaQuery.sizeOf(this);

  WindowSize get windowSize => WindowSize.of(screenSize.width);

  /// A tablet (its short side is a tablet's), whichever way it's held.
  bool get isTablet => screenSize.shortestSide >= 600;

  /// Wider than it's tall.
  bool get isLandscape => screenSize.width > screenSize.height;

  /// Side padding that keeps content at most [maxWidth] wide, centered
  /// (and at least [min] from the edges), for a list or scroll view that
  /// should still scroll edge to edge.
  EdgeInsets readablePadding({
    double maxWidth = kReadableWidth,
    double min = 16,
    double top = 0,
    double bottom = 0,
  }) {
    final side = math.max(min, (screenSize.width - maxWidth) / 2);
    return EdgeInsets.fromLTRB(side, top, side, bottom);
  }

  /// How many columns a grid of [itemWidth]-wide things fits, between
  /// [min] and [max].
  int columnsFor(double itemWidth, {int min = 1, int max = 6}) =>
      (screenSize.width / itemWidth).floor().clamp(min, max);

  /// Columns for a grid of cards: two on a phone, more as the screen
  /// widens (about one per [cardWidth]).
  int gridColumns({double cardWidth = 210, int max = 6}) =>
      columnsFor(cardWidth, min: 2, max: max);
}

/// Keeps [child] at most [maxWidth] wide, centered: for a column of
/// content on a big screen. Backgrounds go outside it, so they still fill
/// the screen.
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({
    super.key,
    required this.child,
    this.maxWidth = kReadableWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
