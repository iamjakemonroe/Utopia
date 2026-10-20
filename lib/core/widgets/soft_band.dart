import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// A band between a [lower] and an [upper] edge (as many points each, left
/// to right), as triangles for a browser to draw.
///
/// A browser fills a wide wavy shape pixel by pixel on the CPU every frame
/// (Skia's software path renderer); triangles go straight to the GPU. Its
/// edges fade out over a pixel ([dpr] pixels a point), half in and half
/// out, just as a smoothed edge is drawn, so it looks the same as the
/// shape would. Draw it with [BlendMode.modulate] and the shape's paint.
ui.Vertices softBand(List<Offset> lower, List<Offset> upper, double dpr) {
  assert(lower.length == upper.length && lower.length >= 2);
  final n = lower.length;
  final half = 0.5 / dpr;
  final positions = Float32List(n * 8);
  final colors = Int32List(n * 4);
  const clear = 0x00FFFFFF;
  const solid = 0xFFFFFFFF;

  // Each edge's normal at a point, from its neighbours, pointing down.
  Offset down(List<Offset> edge, int i) {
    final a = edge[i == 0 ? 0 : i - 1];
    final b = edge[i == n - 1 ? n - 1 : i + 1];
    final d = b - a;
    final length = d.distance;
    if (length == 0) return const Offset(0, 1);
    return Offset(-d.dy, d.dx) / length;
  }

  for (var i = 0; i < n; i++) {
    final lo = down(lower, i) * half;
    final up = down(upper, i) * half;
    // Rows: below the lower edge, above it, below the upper edge, above it.
    final rows = [lower[i] + lo, lower[i] - lo, upper[i] + up, upper[i] - up];
    for (var r = 0; r < 4; r++) {
      positions[(i * 4 + r) * 2] = rows[r].dx;
      positions[(i * 4 + r) * 2 + 1] = rows[r].dy;
      colors[i * 4 + r] = r == 0 || r == 3 ? clear : solid;
    }
  }

  // Three strips: the lower fade, the body, the upper fade.
  final indices = Uint16List((n - 1) * 3 * 6);
  var k = 0;
  for (var i = 0; i < n - 1; i++) {
    for (var r = 0; r < 3; r++) {
      final a = i * 4 + r;
      final b = a + 1;
      final c = a + 4;
      final d = b + 4;
      indices.setAll(k, [a, b, c, b, d, c]);
      k += 6;
    }
  }
  return ui.Vertices.raw(
    ui.VertexMode.triangles,
    positions,
    colors: colors,
    indices: indices,
  );
}
