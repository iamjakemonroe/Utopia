// Pictures Chip drew on the live server, side by side: pass the saved
// coloring_pages rows (JSON files) as --dart-define=PAGES=a.json,b.json.
// Renders test/tool/goldens/chip_drawings.png.
@Tags(['sheet'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/doodle_studio/domain/art_doc.dart';
import 'package:utopia/features/doodle_studio/domain/coloring_pages.dart';
import 'package:utopia/features/doodle_studio/presentation/art_render.dart';

void main() {
  testWidgets('chip drawings', (tester) async {
    final images = <ui.Image>[];
    await tester.runAsync(() async {
      for (final path in const String.fromEnvironment('PAGES').split(',')) {
        if (path.isEmpty) continue;
        final row = jsonDecode(File(path).readAsStringSync()) as Map;
        final page = ColoringPage.fromSvg(
          id: 'p:${row['id']}',
          name: row['title'] as String,
          paths: (row['paths'] as List).cast<String>(),
        );
        final art = await PageArt.load(page);
        final render = ArtRender(
          ArtDoc.blank(ArtKind.coloring, pageId: page.id),
          page: art,
        );
        await render.update();
        images.add(await render.toImage(0.5));
        render.dispose();
      }
    });
    tester.view.physicalSize = Size(500.0 * images.length, 650);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('sheet'),
        child: Row(
          textDirection: TextDirection.ltr,
          children: [
            for (final i in images)
              SizedBox(
                width: 500,
                height: 650,
                child: RawImage(image: i, fit: BoxFit.fill),
              ),
          ],
        ),
      ),
    );
    await expectLater(
      find.byKey(const ValueKey('sheet')),
      matchesGoldenFile('goldens/chip_drawings.png'),
    );
  });
}
