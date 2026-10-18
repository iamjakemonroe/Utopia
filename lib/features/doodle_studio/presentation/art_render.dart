import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../domain/art_doc.dart';
import '../domain/coloring_pages.dart';
import '../domain/line_art.dart';
import '../domain/regions.dart';

/// The paper every page is drawn on, and the ink of a coloring page's lines.
const kPaper = Color(0xFFFFFDF7);
const kLineInk = Color(0xFF1F1E1B);

/// Draws [page]'s lines in page units: its outlines, or its line art once
/// that's ready ([LineArt.ready] says when). [cache] keeps parsed outlines.
void paintPageLines(
  Canvas canvas,
  ColoringPage page,
  Map<String, List<Path>> cache,
) {
  if (page.artPath == null) {
    ColoringPage.paintLines(canvas, cache[page.id] ??= page.draw(), kLineInk);
    return;
  }
  final ink = LineArt.of(page);
  if (ink == null) return;
  canvas.drawImageRect(
    ink,
    Offset.zero & Size(ink.width.toDouble(), ink.height.toDouble()),
    LineArt.fit(ink),
    Paint()..filterQuality = FilterQuality.medium,
  );
}

/// How a brush stroke looks, for each tool. [s] is the stroke's size.
void paintStroke(Canvas canvas, StrokeOp s) {
  final color = Color(s.color);
  final pts = <Offset>[
    for (var i = 0; i + 1 < s.points.length; i += 3)
      Offset(s.points[i], s.points[i + 1]),
  ];
  if (pts.isEmpty) return;

  if (s.tool == ArtTool.pen) {
    // Ink: each bit of the line as wide as the pen was moving there.
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..color = color;
    if (pts.length == 1) {
      canvas.drawCircle(
        pts.first,
        s.points[2] / 2,
        paint..style = PaintingStyle.fill,
      );
      return;
    }
    paint.style = PaintingStyle.stroke;
    for (var i = 1; i < pts.length; i++) {
      paint.strokeWidth = (s.points[(i - 1) * 3 + 2] + s.points[i * 3 + 2]) / 2;
      canvas.drawLine(pts[i - 1], pts[i], paint);
    }
    return;
  }

  final width = switch (s.tool) {
    ArtTool.pencil => (s.size * 0.6).clamp(1.5, 60.0),
    ArtTool.marker => s.size * 1.4,
    ArtTool.soft => s.size * 1.8,
    ArtTool.highlighter => s.size * 2.0,
    ArtTool.eraser => s.size * 2.0,
    _ => s.size,
  };
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = s.tool == ArtTool.highlighter
        ? StrokeCap.square
        : StrokeCap.round;
  switch (s.tool) {
    case ArtTool.pencil:
      paint.color = color.withValues(alpha: color.a * 0.85);
    case ArtTool.soft:
      paint
        ..color = color.withValues(alpha: color.a * 0.8)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.size * 0.45);
    case ArtTool.highlighter:
      paint.color = color.withValues(alpha: color.a * 0.38);
    case ArtTool.eraser:
      paint
        ..color = Colors.black
        ..blendMode = BlendMode.clear;
    default:
      paint.color = color;
  }
  if (pts.length == 1) {
    final dot = Paint()
      ..color = paint.color
      ..blendMode = paint.blendMode
      ..maskFilter = paint.maskFilter;
    canvas.drawCircle(pts.first, width / 2, dot);
    return;
  }
  canvas.drawPath(smoothPath(pts), paint);
}

/// A smooth line through [pts]: curves through the midpoints, so fast
/// strokes don't come out as corners.
Path smoothPath(List<Offset> pts) {
  final path = Path()..moveTo(pts.first.dx, pts.first.dy);
  if (pts.length == 2) return path..lineTo(pts[1].dx, pts[1].dy);
  for (var i = 1; i < pts.length - 1; i++) {
    final mid = Offset.lerp(pts[i], pts[i + 1], 0.5)!;
    path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
  }
  return path..lineTo(pts.last.dx, pts.last.dy);
}

/// A coloring page's outlines as a picture, and its shapes, worked out
/// once per page per session.
class PageArt {
  PageArt(this.page, this.lines, this.regions);

  final ColoringPage page;
  final ui.Picture lines;
  final RegionMap regions;

  static final _cache = <String, Future<PageArt>>{};

  static Future<PageArt> load(ColoringPage page) =>
      _cache[page.id] ??= _build(page).catchError((Object e) {
        _cache.remove(page.id);
        throw e;
      });

  /// Shapes are traced at this many pixels per page unit: a quarter of
  /// the work of full size, and the lines drawn over the top hide the
  /// difference.
  static const _traceScale = 0.5;

  static Future<PageArt> _build(ColoringPage page) async {
    final rec = ui.PictureRecorder();
    if (page.artPath != null) {
      final ink = await LineArt.load(page);
      Canvas(rec).drawImageRect(
        ink,
        Offset.zero & Size(ink.width.toDouble(), ink.height.toDouble()),
        LineArt.fit(ink),
        Paint()..filterQuality = FilterQuality.high,
      );
    } else {
      ColoringPage.paintLines(Canvas(rec), page.draw(), kLineInk);
    }
    final lines = rec.endRecording();
    final small = ui.PictureRecorder();
    final canvas = Canvas(small)..scale(_traceScale);
    canvas.drawPicture(lines);
    final picture = small.endRecording();
    final w = (kPageSize.width * _traceScale).round();
    final h = (kPageSize.height * _traceScale).round();
    final image = await picture.toImage(w, h);
    picture.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    final regions = await RegionMap.trace(
      data!.buffer.asUint8List(),
      w,
      h,
      scale: _traceScale,
      seal: page.artPath != null,
    );
    return PageArt(page, lines, regions);
  }
}

/// Everything already on a piece of art, kept ready to draw: each finished
/// stroke as its own picture (so redrawing them all is cheap however many
/// there are), the strokes together, and a coloring page's fills as an
/// image. [paint] draws the whole thing in page units.
class ArtRender {
  ArtRender(this.doc, {this.page, this.size = kPageSize});

  final ArtDoc doc;
  final PageArt? page;

  /// The page's size in page units (Guess My Doodle draws on a square one).
  final Size size;

  Rect get _pageRect => Offset.zero & size;

  final _strokePictures = Expando<ui.Picture>();
  ui.Picture? _paint;
  ui.Image? _fills;
  Map<int, int>? _fillsFor;

  /// Bumped on every update, so a slow fill finishing after a newer one
  /// never puts older colors back.
  int _generation = 0;
  bool _disposed = false;

  /// The fills as they are now (coloring pages only).
  ui.Image? get fills => _fills;

  /// While Chip's colors sweep in: how far (0 to 1) a circle growing from
  /// [revealAt] has spread, the fills from before showing outside it. Null
  /// when nothing is sweeping.
  double? reveal;
  Offset revealAt = Offset.zero;
  ui.Image? _before;
  bool _keepBefore = false;

  /// The next [update] keeps the fills it replaces, to sweep from.
  void holdForReveal() => _keepBefore = true;

  /// The sweep is done: only the new fills from here on.
  void endReveal() {
    reveal = null;
    _before?.dispose();
    _before = null;
  }

  /// Brings the cached paint and fills up to date with [doc]. Call after
  /// anything is added, undone or redone.
  Future<void> update() async {
    if (_disposed) return;
    final generation = ++_generation;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    for (final op in doc.ops) {
      if (op is StrokeOp) {
        canvas.drawPicture(_strokePictures[op] ??= _record(op));
      }
    }
    _paint?.dispose();
    _paint = rec.endRecording();

    final p = page;
    if (p == null) return;
    final fills = doc.fills;
    if (_fillsFor != null && _mapEquals(_fillsFor!, fills)) {
      _keepBefore = false;
      return;
    }
    final image = await p.regions.fillImage(fills);
    if (_disposed || generation != _generation) {
      image.dispose();
      return;
    }
    _fillsFor = fills;
    if (_keepBefore) {
      _before?.dispose();
      _before = _fills;
      _keepBefore = false;
    } else {
      _fills?.dispose();
    }
    _fills = image;
  }

  ui.Picture _record(StrokeOp op) {
    final rec = ui.PictureRecorder();
    paintStroke(Canvas(rec), op);
    return rec.endRecording();
  }

  /// The art, in page units: paper, fills, the paint (with [live], the
  /// stroke being drawn right now, and any [more] still arriving), then a
  /// coloring page's outlines on top.
  void paint(
    Canvas canvas, {
    StrokeOp? live,
    Iterable<StrokeOp> more = const [],
  }) {
    canvas.drawRect(_pageRect, Paint()..color = kPaper);
    void drawFills(ui.Image image) => canvas.drawImageRect(
      image,
      Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
      _pageRect,
      Paint()..filterQuality = FilterQuality.medium,
    );
    final fills = _fills;
    final sweep = reveal;
    if (sweep != null) {
      if (_before case final before?) drawFills(before);
      if (fills != null) {
        canvas.save();
        canvas.clipPath(
          Path()..addOval(
            Rect.fromCircle(
              center: revealAt,
              radius: sweep * size.longestSide * 1.15,
            ),
          ),
        );
        drawFills(fills);
        canvas.restore();
      }
    } else if (fills != null) {
      drawFills(fills);
    }
    // The paint gets a layer of its own, so the eraser takes away paint
    // only, never the paper or the fills under it.
    canvas.saveLayer(_pageRect, Paint());
    final paint = _paint;
    if (paint != null) canvas.drawPicture(paint);
    for (final stroke in more) {
      paintStroke(canvas, stroke);
    }
    if (live != null) paintStroke(canvas, live);
    canvas.restore();
    final p = page;
    if (p != null) canvas.drawPicture(p.lines);
  }

  /// The art as a picture [scale] times the page's size.
  Future<ui.Image> toImage(double scale) {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec)..scale(scale);
    paint(canvas);
    final picture = rec.endRecording();
    return picture
        .toImage((size.width * scale).round(), (size.height * scale).round())
        .whenComplete(picture.dispose);
  }

  /// The art as a PNG [scale] times the page's size.
  Future<Uint8List> toPng(double scale) async {
    final image = await toImage(scale);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  void dispose() {
    _disposed = true;
    _paint?.dispose();
    _paint = null;
    _fills?.dispose();
    _fills = null;
    _before?.dispose();
    _before = null;
  }
}

bool _mapEquals(Map<int, int> a, Map<int, int> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (b[e.key] != e.value) return false;
  }
  return true;
}
