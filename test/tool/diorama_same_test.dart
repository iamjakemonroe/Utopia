// The game cards' dioramas, every game at a few moments, as pixels: made
// before a change to how they're drawn, then compared after it, so a
// speed-up provably changes nothing on screen. Run:
// flutter test --run-skipped [--update-goldens] test/tool/diorama_same_test.dart
@Tags(['sheet'])
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/widgets/game_card_art.dart';

Widget _sheet() => MaterialApp(
  debugShowCheckedModeBanner: false,
  home: Wrap(
    children: [
      for (final game in GameKind.values)
        SizedBox(
          width: 300,
          height: 190,
          child: GameSceneArt(game: game, height: 190),
        ),
    ],
  ),
);

/// The sheet at [ms] (after a few frames, so the still parts are made into
/// pixels on the way), as a phone with three pixels a point sees it.
Future<(ui.Image, Uint8List)> _shot(WidgetTester tester, int ms) async {
  tester.view.physicalSize = const Size(2700, 2280);
  tester.view.devicePixelRatio = 3;
  await tester.pumpWidget(_sheet());
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pump(Duration(milliseconds: ms));
  final image = (await tester.runAsync(
    () => captureImage(find.byType(Wrap).evaluate().single),
  ))!;
  final bytes = (await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  ))!;
  return (image, bytes.buffer.asUint8List());
}

Future<void> _save(WidgetTester tester, ui.Image image, String name) async {
  final png = (await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.png),
  ))!;
  final file = File('test/tool/failures/$name.png');
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(png.buffer.asUint8List());
}

void main() {
  for (final ms in const [0, 700, 2300, 4100]) {
    testWidgets('dioramas at $ms ms', (tester) async {
      tester.view.physicalSize = const Size(900, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_sheet());
      await tester.pump(Duration(milliseconds: ms));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/dioramas_$ms.png'),
      );
    });
  }

  // A browser's way (the still parts from pixels, placed on whole pixels)
  // against drawing it all directly: the same picture, but for edges a
  // fraction of a pixel apart.
  for (final ms in const [0, 700, 2300, 4100]) {
    testWidgets('kept as pixels, dioramas at $ms ms look the same', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      addTearDown(() => debugDioramaSprites = false);
      debugClearDioramaSprites();

      // Once to load the cards' font, then for real.
      await _shot(tester, ms);
      await tester.pumpWidget(const SizedBox());
      final (direct, a) = await _shot(tester, ms);
      await tester.pumpWidget(const SizedBox());
      debugDioramaSprites = true;
      final (kept, b) = await _shot(tester, ms);
      // The sun and the rock (the same in every game), each game's
      // grass and board, and the checkers sitting still.
      expect(
        debugDioramaSpriteCount,
        greaterThanOrEqualTo(2 + GameKind.values.length),
      );

      var off = 0, far = 0, worst = 0;
      for (var i = 0; i < a.length; i += 4) {
        var d = 0;
        for (var c = 0; c < 4; c++) {
          final e = (a[i + c] - b[i + c]).abs();
          if (e > d) d = e;
        }
        if (d > 8) off++;
        if (d > 96) far++;
        if (d > worst) worst = d;
      }
      final pixels = a.length ~/ 4;
      // ignore: avoid_print
      print(
        '$ms ms: ${(off / pixels * 100).toStringAsFixed(2)}% of pixels off '
        'by more than 8, ${(far / pixels * 100).toStringAsFixed(3)}% by '
        'more than 96, worst $worst',
      );
      await _save(tester, direct, 'sprites_${ms}_direct');
      await _save(tester, kept, 'sprites_${ms}_kept');
      expect(far / pixels, lessThan(0.0002));
    });
  }
}
