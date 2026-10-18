import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/doodle_studio/domain/art_doc.dart';
import 'package:utopia/features/doodle_studio/domain/coloring_pages.dart';
import 'package:utopia/features/doodle_studio/domain/line_art.dart';
import 'package:utopia/features/doodle_studio/domain/regions.dart';
import 'package:utopia/features/doodle_studio/presentation/art_render.dart';

/// A stand-in for the image model's answer: the rocket page drawn as black
/// lines on white, 900 x 1200, as a PNG.
Future<Uint8List> _portraitPng() async {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec)
    ..drawRect(
      const Rect.fromLTWH(0, 0, 900, 1200),
      Paint()..color = Colors.white,
    )
    ..scale(0.9);
  ColoringPage.paintLines(
    canvas,
    ColoringPage.byId('rocket')!.draw(),
    Colors.black,
  );
  final image = await rec.endRecording().toImage(900, 1200);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  test('ink keeps the dark lines and clears the paper', () {
    final ink = LineArt.inkOf(
      Uint8List.fromList([
        0,
        0,
        0,
        255,
        255,
        255,
        255,
        255,
        120,
        120,
        120,
        255,
      ]),
    );
    expect(ink[3], 255); // black line: solid ink
    expect(ink[7], 0); // white paper: clear
    expect(ink[11], inInclusiveRange(100, 200)); // gray: partly inked
  });

  test('sealing grows each line a pixel so fills cannot leak', () {
    // A one-pixel gap in a wall at x = 2 (rows 0-4, missing at row 2).
    const w = 5, h = 5;
    final px = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      if (y != 2) px[(y * w + 2) * 4 + 3] = 255;
    }
    expect(RegionMap.label(px, w, h).count, 1);
    expect(RegionMap.label(RegionMap.sealed(px, w, h), w, h).count, 2);
  });

  testWidgets('a line-art page traces into shapes that fill', (tester) async {
    await tester.runAsync(() async {
      final png = await _portraitPng();
      LineArt.source = (_) async => png;
      final page = ColoringPage.fromArt(
        id: 'p:test-portrait',
        name: 'Test portrait',
        artPath: 'me/test.png',
      );
      final art = await PageArt.load(page);
      final shapes = art.regions.shapes();
      expect(shapes.length, greaterThan(15));

      final doc = ArtDoc.blank(ArtKind.coloring, pageId: page.id)
        ..add(FillsOp({for (final s in shapes) s.id: 0xFFFF0000}));
      final render = ArtRender(doc, page: art);
      await render.update();
      expect(render.fills, isNotNull);
      render.dispose();
    });
  });
}
