import 'dart:async';
import 'dart:typed_data';
import '../../../core/platform/off_main.dart';
import 'dart:ui' as ui;

/// The shapes of a coloring page: every pixel of the page (at [width] by
/// [height]) labelled with the shape it's in, 0 where the outlines are.
/// Built once per page by tracing the drawn outlines; a fill then colors
/// every pixel with that label.
class RegionMap {
  RegionMap(this.width, this.height, this.labels, this.count, {this.scale = 1});

  final int width;
  final int height;

  /// Pixels per page unit (shapes are traced smaller than the page, which
  /// is quicker; the outlines drawn over the top hide the edges).
  final double scale;

  /// The shape at page point ([x], [y]) (see [regionAt]).
  int regionAtPage(double x, double y) =>
      regionAt((x * scale).floor(), (y * scale).floor());

  /// One label per pixel, row by row: 0 is outline, 1.. are shapes.
  final Uint16List labels;

  /// How many shapes there are.
  final int count;

  /// The shape at pixel ([x], [y]); on an outline, the nearest shape
  /// within a few pixels (so a tap on a line still fills something), or 0.
  int regionAt(int x, int y, {int reach = 4}) {
    if (x < 0 || y < 0 || x >= width || y >= height) return 0;
    final here = labels[y * width + x];
    if (here != 0) return here;
    for (var r = 1; r <= reach; r++) {
      for (var dy = -r; dy <= r; dy++) {
        for (var dx = -r; dx <= r; dx++) {
          if (dx.abs() != r && dy.abs() != r) continue;
          final px = x + dx, py = y + dy;
          if (px < 0 || py < 0 || px >= width || py >= height) continue;
          final l = labels[py * width + px];
          if (l != 0) return l;
        }
      }
    }
    return 0;
  }

  /// The fills as pixels (RGBA, straight alpha): each shape in its color,
  /// unfilled shapes and outlines clear.
  Uint8List fillPixels(Map<int, int> fills) {
    final out = Uint8List(width * height * 4);
    if (fills.isEmpty) return out;
    // A table from label to color, so the pass over pixels is one lookup.
    final table = Uint32List(count + 1);
    final opaque = Uint8List(count + 1);
    fills.forEach((region, argb) {
      if (region <= 0 || region > count) return;
      table[region] = argb;
      opaque[region] = (argb >> 24) & 0xFF;
    });
    void put(int o, int l) {
      final argb = table[l];
      out[o] = (argb >> 16) & 0xFF;
      out[o + 1] = (argb >> 8) & 0xFF;
      out[o + 2] = argb & 0xFF;
      out[o + 3] = opaque[l];
    }

    for (var i = 0, o = 0; i < labels.length; i++, o += 4) {
      final l = labels[i];
      if (l != 0 && opaque[l] != 0) put(o, l);
    }
    // Each fill reaches a couple of pixels in under the outline, so no
    // hairline of paper shows between the color and the line, even zoomed
    // right in (the line is drawn over the top).
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final i = y * width + x;
        if (labels[i] != 0) continue;
        for (var k = 0; k < _reachX.length; k++) {
          final px = x + _reachX[k], py = y + _reachY[k];
          if (px < 0 || py < 0 || px >= width || py >= height) continue;
          final l = labels[py * width + px];
          if (l != 0 && opaque[l] != 0) {
            put(i * 4, l);
            break;
          }
        }
      }
    }
    return out;
  }

  /// [fillPixels] as an image to draw.
  Future<ui.Image> fillImage(Map<int, int> fills) async {
    // Worked out off the UI thread, so a tap of the bucket never stutters.
    final pixels = await offMainThread(() => fillPixels(fills));
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      width,
      height,
      ui.PixelFormat.rgba8888,
      done.complete,
    );
    return done.future;
  }

  /// Traces the shapes from the outlines drawn as RGBA [pixels] (anything
  /// at least half opaque is outline). Off the UI thread: big pages take a
  /// moment.
  ///
  /// [seal] is for line art (a real portrait): faint lines count as lines
  /// too, and every line is grown a pixel, so a hairline gap in the artist's
  /// line can't let a fill spill into the next shape.
  static Future<RegionMap> trace(
    Uint8List pixels,
    int width,
    int height, {
    double scale = 1,
    bool seal = false,
  }) {
    return offMainThread(
      () => label(
        seal ? sealed(pixels, width, height) : pixels,
        width,
        height,
        scale: scale,
      ),
    );
  }

  /// [pixels] with every pixel that's at least a little inked, and the ones
  /// next to it, made solid.
  static Uint8List sealed(
    Uint8List pixels,
    int width,
    int height, {
    int minAlpha = 48,
  }) {
    final out = Uint8List(pixels.length);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (pixels[(y * width + x) * 4 + 3] < minAlpha) continue;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            final px = x + dx, py = y + dy;
            if (px < 0 || py < 0 || px >= width || py >= height) continue;
            out[(py * width + px) * 4 + 3] = 255;
          }
        }
      }
    }
    return out;
  }

  /// Every shape of at least [minArea] (square page units), biggest first
  /// and at most [limit] of them: where each one is, for Chip to color.
  List<RegionInfo> shapes({double minArea = 120, int limit = 300}) {
    final n = count + 1;
    final pixels = Int32List(n);
    final sumX = Float64List(n);
    final sumY = Float64List(n);
    final x0 = Int32List(n)..fillRange(0, n, width);
    final y0 = Int32List(n)..fillRange(0, n, height);
    final x1 = Int32List(n)..fillRange(0, n, -1);
    final y1 = Int32List(n)..fillRange(0, n, -1);
    for (var y = 0, i = 0; y < height; y++) {
      for (var x = 0; x < width; x++, i++) {
        final l = labels[i];
        if (l == 0) continue;
        pixels[l]++;
        sumX[l] += x;
        sumY[l] += y;
        if (x < x0[l]) x0[l] = x;
        if (x > x1[l]) x1[l] = x;
        if (y < y0[l]) y0[l] = y;
        if (y > y1[l]) y1[l] = y;
      }
    }
    final unit = 1 / scale;
    final big = [
      for (var l = 1; l <= count; l++)
        if (pixels[l] * unit * unit >= minArea) l,
    ]..sort((a, b) => pixels[b] - pixels[a]);
    final kept = big.take(limit).toList();
    final keep = Uint8List(n);
    for (final l in kept) {
      keep[l] = 1;
    }

    // The label goes on the shape's own pixel nearest its middle, so it
    // sits inside even a ring or a crescent.
    final best = Float64List(n)..fillRange(0, n, double.infinity);
    final bestX = Int32List(n);
    final bestY = Int32List(n);
    for (var y = 0, i = 0; y < height; y++) {
      for (var x = 0; x < width; x++, i++) {
        final l = labels[i];
        if (l == 0 || keep[l] == 0) continue;
        final dx = x - sumX[l] / pixels[l];
        final dy = y - sumY[l] / pixels[l];
        final d = dx * dx + dy * dy;
        if (d < best[l]) {
          best[l] = d;
          bestX[l] = x;
          bestY[l] = y;
        }
      }
    }
    return [
      for (final l in kept)
        RegionInfo(
          id: l,
          labelX: (bestX[l] + 0.5) * unit,
          labelY: (bestY[l] + 0.5) * unit,
          left: x0[l] * unit,
          top: y0[l] * unit,
          width: (x1[l] - x0[l] + 1) * unit,
          height: (y1[l] - y0[l] + 1) * unit,
          area: pixels[l] * unit * unit,
        ),
    ];
  }

  /// [shapes], off the UI thread.
  Future<List<RegionInfo>> shapesInBackground() => offMainThread(shapes);

  /// [trace], on this thread (for tests).
  static RegionMap label(
    Uint8List pixels,
    int width,
    int height, {
    double scale = 1,
  }) {
    final n = width * height;
    final wall = Uint8List(n);
    for (var i = 0; i < n; i++) {
      if (pixels[i * 4 + 3] >= 128) wall[i] = 1;
    }
    final labels = Uint16List(n);
    var next = 0;
    final stack = <int>[];
    for (var start = 0; start < n; start++) {
      if (wall[start] == 1 || labels[start] != 0) continue;
      if (next == 0xFFFF) break; // more shapes than labels: the rest stay 0
      next++;
      // Scanline fill: run left and right along the row, then queue the
      // rows above and below.
      stack
        ..clear()
        ..add(start);
      labels[start] = next;
      while (stack.isNotEmpty) {
        final p = stack.removeLast();
        final y = p ~/ width;
        var x0 = p % width;
        var x1 = x0;
        final row = y * width;
        while (x0 > 0 &&
            wall[row + x0 - 1] == 0 &&
            (labels[row + x0 - 1] == 0 || labels[row + x0 - 1] == next)) {
          x0--;
        }
        while (x1 < width - 1 &&
            wall[row + x1 + 1] == 0 &&
            (labels[row + x1 + 1] == 0 || labels[row + x1 + 1] == next)) {
          x1++;
        }
        for (var x = x0; x <= x1; x++) {
          labels[row + x] = next;
          if (y > 0) {
            final q = row - width + x;
            if (wall[q] == 0 && labels[q] == 0) {
              labels[q] = next;
              stack.add(q);
            }
          }
          if (y < height - 1) {
            final q = row + width + x;
            if (wall[q] == 0 && labels[q] == 0) {
              labels[q] = next;
              stack.add(q);
            }
          }
        }
      }
    }
    return RegionMap(width, height, labels, next, scale: scale);
  }
}

/// Where an outline pixel looks for a fill to borrow, nearest first.
const _reachX = [1, -1, 0, 0, 2, -2, 0, 0];
const _reachY = [0, 0, 1, -1, 0, 0, 2, -2];

/// One shape of a coloring page, in page units: a point inside it to label
/// it by, its bounding box and its area.
class RegionInfo {
  const RegionInfo({
    required this.id,
    required this.labelX,
    required this.labelY,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.area,
  });

  /// Its label in the RegionMap.
  final int id;
  final double labelX;
  final double labelY;
  final double left;
  final double top;
  final double width;
  final double height;
  final double area;
}
