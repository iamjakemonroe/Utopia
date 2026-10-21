import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'art_doc.dart';

/// Paint poured into a shape of a freehand drawing (Guess My Doodle's
/// bucket). The drawing's lines are traced onto a grid of [cell]-sized
/// squares, and the paint floods every square joined to the one tapped
/// that shows the same color, stopping at lines. It's worked out from the
/// strokes alone (no pixels read back from the screen), so every phone in
/// the game fills exactly the same squares.
class SpillGrid {
  SpillGrid(Size page, {this.cell = 4})
    : cols = (page.width / cell).ceil(),
      rows = (page.height / cell).ceil() {
    ink = Uint32List(cols * rows);
    fill = Uint32List(cols * rows);
  }

  final double cell;
  final int cols;
  final int rows;

  /// Each square's line color (ARGB), or 0 for none.
  late final Uint32List ink;

  /// Each square's poured color (ARGB), or 0 for none.
  late final Uint32List fill;

  /// The ops it has taken in, in order (to pick up where it left off).
  final List<ArtOp> applied = [];

  /// Takes in [op], after everything before it.
  void apply(ArtOp op) {
    applied.add(op);
    switch (op) {
      case StrokeOp():
        _stroke(op);
      case SpillOp():
        _spill(op);
      default:
    }
  }

  /// How wide [s] is drawn (see paintStroke), in page units.
  static double widthOf(StrokeOp s, int point) => switch (s.tool) {
    ArtTool.pen => s.points[point * 3 + 2],
    ArtTool.pencil => (s.size * 0.6).clamp(1.5, 60.0),
    ArtTool.marker => s.size * 1.4,
    ArtTool.soft => s.size * 1.8,
    ArtTool.highlighter || ArtTool.eraser => s.size * 2.0,
    _ => s.size,
  };

  void _stroke(StrokeOp s) {
    final erase = s.tool == ArtTool.eraser;
    final color = s.color == 0 ? 1 : s.color;
    final n = s.length;
    if (n == 0) return;
    for (var i = 0; i < math.max(1, n - 1); i++) {
      final j = math.min(i + 1, n - 1);
      final r = math.max(widthOf(s, i), widthOf(s, j)) / 2;
      _segment(
        s.points[i * 3],
        s.points[i * 3 + 1],
        s.points[j * 3],
        s.points[j * 3 + 1],
        r,
        erase,
        color,
      );
    }
  }

  /// Marks every square whose middle is within [r] of the line a-b.
  void _segment(
    double ax,
    double ay,
    double bx,
    double by,
    double r,
    bool erase,
    int color,
  ) {
    final c0 = math.max(0, ((math.min(ax, bx) - r) / cell).floor());
    final c1 = math.min(cols - 1, ((math.max(ax, bx) + r) / cell).floor());
    final r0 = math.max(0, ((math.min(ay, by) - r) / cell).floor());
    final r1 = math.min(rows - 1, ((math.max(ay, by) + r) / cell).floor());
    final dx = bx - ax;
    final dy = by - ay;
    final len2 = dx * dx + dy * dy;
    final rr = r * r;
    for (var row = r0; row <= r1; row++) {
      final py = (row + 0.5) * cell;
      for (var col = c0; col <= c1; col++) {
        final px = (col + 0.5) * cell;
        var t = len2 == 0 ? 0.0 : ((px - ax) * dx + (py - ay) * dy) / len2;
        t = t.clamp(0.0, 1.0);
        final ex = ax + dx * t - px;
        final ey = ay + dy * t - py;
        if (ex * ex + ey * ey > rr) continue;
        final at = row * cols + col;
        if (erase) {
          ink[at] = 0;
          fill[at] = 0;
        } else {
          ink[at] = color;
        }
      }
    }
  }

  void _spill(SpillOp op) {
    final col = (op.x / cell).floor().clamp(0, cols - 1);
    final row = (op.y / cell).floor().clamp(0, rows - 1);
    final seed = row * cols + col;
    // Poured on a line: lines keep their color.
    if (ink[seed] != 0) return;
    final from = fill[seed];
    final to = op.color;
    if (from == to) return;
    final queue = Int32List(cols * rows);
    var head = 0;
    var tail = 0;
    fill[seed] = to;
    queue[tail++] = seed;
    while (head < tail) {
      final at = queue[head++];
      final x = at % cols;
      final y = at ~/ cols;
      void visit(int next) {
        if (ink[next] == 0 && fill[next] == from) {
          fill[next] = to;
          queue[tail++] = next;
        }
      }

      if (x > 0) visit(at - 1);
      if (x < cols - 1) visit(at + 1);
      if (y > 0) visit(at - cols);
      if (y < rows - 1) visit(at + cols);
    }
  }

  /// Whether anything's been poured.
  bool get poured => fill.any((c) => c != 0);

  /// The poured paint as RGBA pixels, one a square. Each poured shape
  /// reaches a square under the lines around it, so no paper shows
  /// between the paint and the line drawn over it.
  Uint8List rgba() {
    final out = Uint8List(cols * rows * 4);
    for (var at = 0; at < cols * rows; at++) {
      var c = fill[at];
      if (c == 0 && ink[at] != 0) c = _nextTo(at);
      if (c == 0) continue;
      final o = at * 4;
      out[o] = (c >> 16) & 0xFF;
      out[o + 1] = (c >> 8) & 0xFF;
      out[o + 2] = c & 0xFF;
      out[o + 3] = (c >> 24) & 0xFF;
    }
    return out;
  }

  /// The paint in a square beside [at] that isn't under a line, if any.
  int _nextTo(int at) {
    final x = at % cols;
    final y = at ~/ cols;
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final nx = x + dx;
        final ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= cols || ny >= rows) continue;
        final n = ny * cols + nx;
        if (ink[n] == 0 && fill[n] != 0) return fill[n];
      }
    }
    return 0;
  }
}
