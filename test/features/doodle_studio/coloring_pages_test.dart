import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/doodle_studio/domain/art_doc.dart';
import 'package:utopia/features/doodle_studio/domain/coloring_pages.dart';
import 'package:utopia/features/doodle_studio/domain/regions.dart';

/// [page]'s shapes, traced as the studio traces them (half size).
Future<RegionMap> _trace(ColoringPage page) async {
  const scale = 0.5;
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec)..scale(scale);
  ColoringPage.paintLines(canvas, page.draw(), Colors.black);
  final w = (kPageSize.width * scale).round();
  final h = (kPageSize.height * scale).round();
  final image = await rec.endRecording().toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return RegionMap.label(data!.buffer.asUint8List(), w, h, scale: scale);
}

void main() {
  test('every page has its own id and a name', () {
    final ids = {for (final p in kColoringPages) p.id};
    expect(ids, hasLength(kColoringPages.length));
    expect(kColoringPages.every((p) => p.name.isNotEmpty), isTrue);
    expect(kColoringPages.where((p) => p.detailed), hasLength(8));
  });

  testWidgets('detailed pages: plenty to fill, all of it closed', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final page in kColoringPages.where((p) => p.detailed)) {
        final regions = await _trace(page);
        final shapes = regions.shapes(minArea: 120, limit: 100000);
        final page_ = kPageSize.width * kPageSize.height;
        final biggest = shapes.first.area;
        // Lots of shapes a fingertip can pick out...
        expect(shapes.length, greaterThan(60), reason: page.id);
        // ...and no gap letting one fill spread over most of the page.
        expect(biggest / page_, lessThan(0.4), reason: '${page.id}: $biggest');
      }
    });
  });
}
