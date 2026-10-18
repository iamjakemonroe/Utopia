import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Lays [children] out [columns] to a row, each a column wide, rows as tall
/// as their tallest. A child with nothing to show right now (no height)
/// takes no place, so a card that's hidden leaves no gap. Children bring
/// their own space below them; [spacing] is between the columns.
class TileGrid extends MultiChildRenderObjectWidget {
  const TileGrid({
    super.key,
    required this.columns,
    this.spacing = 16,
    required super.children,
  });

  final int columns;
  final double spacing;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTileGrid(columns, spacing);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderTileGrid)
      ..columns = columns
      ..spacing = spacing;
  }
}

class _TileParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderTileGrid extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _TileParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _TileParentData> {
  _RenderTileGrid(this._columns, this._spacing);

  int _columns;
  set columns(int value) {
    if (value == _columns) return;
    _columns = value;
    markNeedsLayout();
  }

  double _spacing;
  set spacing(double value) {
    if (value == _spacing) return;
    _spacing = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _TileParentData) {
      child.parentData = _TileParentData();
    }
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final columns = math.max(1, _columns);
    final column = (width - _spacing * (columns - 1)) / columns;
    var top = 0.0;
    var row = 0.0;
    var placed = 0;
    var child = firstChild;
    while (child != null) {
      child.layout(
        BoxConstraints.tightFor(width: column),
        parentUsesSize: true,
      );
      final data = child.parentData! as _TileParentData;
      if (child.size.height <= 0) {
        data.offset = Offset(0, top);
      } else {
        final at = placed % columns;
        if (at == 0 && placed > 0) {
          top += row;
          row = 0;
        }
        data.offset = Offset(at * (column + _spacing), top);
        row = math.max(row, child.size.height);
        placed++;
      }
      child = data.nextSibling;
    }
    size = constraints.constrain(Size(width, top + row));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
