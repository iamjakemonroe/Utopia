// Chip's colors from the live paint function (saved by a test script as
// test/tool/goldens/chip_paint_fills_<style>.json), on the page.
// Renders test/tool/goldens/chip_paint_result.png.
// Run: flutter test --run-skipped --update-goldens test/tool/chip_paint_result_sheet_test.dart
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
  testWidgets('chip paint result', (tester) async {
    final images = <ui.Image>[];
    await tester.runAsync(() async {
      final page = await PageArt.load(
        ColoringPage.byId(
          const String.fromEnvironment('PAGE', defaultValue: 'rocket'),
        )!,
      );
      for (final style in const ['your', 'black']) {
        final file = File('test/tool/goldens/chip_paint_fills_$style.json');
        if (!file.existsSync()) continue;
        final fills = <int, int>{
          for (final f in jsonDecode(file.readAsStringSync()) as List)
            (f['r'] as num).toInt():
                0xFF000000 |
                int.parse((f['c'] as String).substring(1), radix: 16),
        };
        final doc = ArtDoc.blank(ArtKind.coloring, pageId: page.page.id)
          ..add(FillsOp(fills));
        final render = ArtRender(doc, page: page);
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
      matchesGoldenFile('goldens/chip_paint_result.png'),
    );
  });
}
