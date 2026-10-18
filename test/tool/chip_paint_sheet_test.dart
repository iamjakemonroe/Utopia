// What Chip is shown when he colors a page: the outlines with every
// shape's number at its label point. Renders test/tool/goldens/chip_paint.png
// and saves the PNG Chip gets as test/tool/goldens/chip_paint_input.png.
// Run: flutter test --run-skipped --update-goldens test/tool/chip_paint_sheet_test.dart
@Tags(['sheet'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/doodle_studio/domain/coloring_pages.dart';
import 'package:utopia/features/doodle_studio/presentation/art_render.dart';
import 'package:utopia/features/doodle_studio/presentation/chip_paint.dart';

void main() {
  testWidgets('chip paint input', (tester) async {
    ui.Image? image;
    await tester.runAsync(() async {
      // Real digits, as on a phone (tests draw text as boxes otherwise).
      final font = FontLoader('Label')
        ..addFont(
          File(
            '/System/Library/Fonts/Supplemental/Arial Bold.ttf',
          ).readAsBytes().then((b) => ByteData.sublistView(b)),
        );
      await font.load();
      final page = await PageArt.load(
        ColoringPage.byId(
          const String.fromEnvironment('PAGE', defaultValue: 'rocket'),
        )!,
      );
      final shapes = await page.regions.shapesInBackground();
      final png = await numberedPage(page, shapes, fontFamily: 'Label');
      File('test/tool/goldens/chip_paint_input.png').writeAsBytesSync(png);
      File('test/tool/goldens/chip_paint_regions.json').writeAsStringSync(
        jsonEncode([
          for (final s in shapes)
            {
              'i': s.id,
              'x': s.labelX.round(),
              'y': s.labelY.round(),
              'w': s.width.round(),
              'h': s.height.round(),
              'a': s.area.round(),
            },
        ]),
      );
      final codec = await ui.instantiateImageCodec(png);
      image = (await codec.getNextFrame()).image;
      // ignore: avoid_print
      print('shapes: ${shapes.length}, png: ${png.length} bytes');
    });
    tester.view.physicalSize = const Size(750, 975);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('sheet'),
        child: RawImage(image: image, fit: BoxFit.fill),
      ),
    );
    await expectLater(
      find.byKey(const ValueKey('sheet')),
      matchesGoldenFile('goldens/chip_paint.png'),
    );
  });
}
