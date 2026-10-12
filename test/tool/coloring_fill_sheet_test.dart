// The coloring pipeline end to end: pages traced into shapes, a few
// shapes filled, brush strokes on top, outlines over everything.
// Renders test/tool/goldens/coloring_fill.png.
// Run: flutter test --run-skipped --update-goldens test/tool/coloring_fill_sheet_test.dart
@Tags(['sheet'])
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/doodle_studio/domain/art_doc.dart';
import 'package:utopia/features/doodle_studio/domain/coloring_pages.dart';
import 'package:utopia/features/doodle_studio/presentation/art_render.dart';

void main() {
  testWidgets('coloring fills', (tester) async {
    final images = <ui.Image>[];
    await tester.runAsync(() async {
      for (final (id, taps) in const [
        (
          'mandala',
          [
            (500.0, 650.0, 0xFFFFC94D),
            (500.0, 560.0, 0xFFFF5A8A),
            (500.0, 330.0, 0xFF5AB8FF),
            (500.0, 140.0, 0xFF3DDC84),
          ],
        ),
        (
          'chip',
          [
            (500.0, 700.0, 0xFFFFC94D),
            (500.0, 340.0, 0xFFFFA43A),
            (220.0, 640.0, 0xFF9B8CFF),
            (120.0, 500.0, 0xFFE9F4FF),
          ],
        ),
        (
          'rocket',
          [
            (560.0, 700.0, 0xFFFF5A5F),
            (240.0, 360.0, 0xFF9B8CFF),
            (560.0, 1050.0, 0xFFFFC94D),
            (120.0, 400.0, 0xFF241C3B),
          ],
        ),
      ]) {
        final page = ColoringPage.byId(id)!;
        final art = await PageArt.load(page);
        final doc = ArtDoc.blank(ArtKind.coloring, pageId: id);
        for (final (x, y, c) in taps) {
          final r = art.regions.regionAtPage(x, y);
          if (r != 0) doc.add(FillOp(region: r, color: c));
        }
        doc.add(
          const StrokeOp(
            tool: ArtTool.marker,
            color: 0xFF2DE0C2,
            size: 14,
            points: [
              300,
              1150,
              14,
              420,
              1120,
              14,
              560,
              1160,
              14,
              700,
              1120,
              14,
            ],
          ),
        );
        final render = ArtRender(doc, page: art);
        await render.update();
        images.add(await render.toImage(0.5));
        // ignore: avoid_print
        print('$id: ${art.regions.count} shapes');
      }
    });
    tester.view.physicalSize = const Size(1500, 650);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('sheet'),
        child: Row(
          textDirection: TextDirection.ltr,
          children: [
            for (final i in images) RawImage(image: i, width: 500, height: 650),
          ],
        ),
      ),
    );
    await expectLater(
      find.byKey(const ValueKey('sheet')),
      matchesGoldenFile('goldens/coloring_fill.png'),
    );
  });
}
