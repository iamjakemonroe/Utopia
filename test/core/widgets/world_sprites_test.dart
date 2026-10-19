import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/theme/utopia_themes.dart';
import 'package:utopia/core/widgets/doodle_world.dart';
import 'package:utopia/core/widgets/halloween_world.dart';

const _size = Size(390, 844);
const _dpr = 3.0;

/// [paint]'s drawing at [_dpr], as pixels.
Future<Uint8List> _pixels(
  void Function(Canvas canvas) paint, {
  String? save,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(_dpr);
  canvas.drawRect(
    Offset.zero & _size,
    Paint()..color = const Color(0xFF808080),
  );
  paint(canvas);
  final image = await recorder.endRecording().toImage(
    (_size.width * _dpr).round(),
    (_size.height * _dpr).round(),
  );
  if (save != null && Platform.environment['SAVE_WORLDS'] != null) {
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('build/$save.png').writeAsBytesSync(png!.buffer.asUint8List());
  }
  final rgba = await image.toByteData();
  return rgba!.buffer.asUint8List();
}

/// The share of pixels that differ by more than a faint edge would, from
/// any pixel next to them in the other: the kept pixels are placed on
/// whole pixels, at most a pixel from where they'd be drawn.
double _changed(Uint8List a, Uint8List b) {
  final width = (_size.width * _dpr).round();
  final height = (_size.height * _dpr).round();
  int far(int i, int j) {
    var most = 0;
    for (var k = 0; k < 3; k++) {
      final d = (a[i + k] - b[j + k]).abs();
      if (d > most) most = d;
    }
    return most;
  }

  var changed = 0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      if (far(i, i) <= 48) continue;
      var near = false;
      for (var dy = -1; dy <= 1 && !near; dy++) {
        for (var dx = -1; dx <= 1 && !near; dx++) {
          final nx = x + dx;
          final ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
          near = far(i, (ny * width + nx) * 4) <= 48;
        }
      }
      if (!near) changed++;
    }
  }
  return changed / (width * height);
}

void main() {
  // In a browser the busiest worlds keep their slow parts as pixels: they
  // must look the same as the apps' drawing.
  testWidgets('the Doodle world looks the same kept as pixels', (tester) async {
    await tester.runAsync(() async {
      // Early in the boil, when the browser's loop and the apps' agree.
      for (final t in [0.1, 0.4]) {
        final clock = ValueNotifier(t);
        final app = await _pixels(
          (c) => DoodleScenePainter(clock).paint(c, _size),
          save: 'doodle_app_$t',
        );
        final web = await _pixels(
          (c) => DoodleScenePainter(clock, dpr: _dpr).paint(c, _size),
          save: 'doodle_web_$t',
        );
        // Again, from what it kept.
        final again = await _pixels(
          (c) => DoodleScenePainter(clock, dpr: _dpr).paint(c, _size),
        );
        expect(_changed(app, web), lessThan(0.001), reason: 't $t');
        expect(_changed(web, again), 0, reason: 't $t, kept');
      }
    });
  });

  testWidgets('the Halloween world looks the same kept as pixels', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final t in [1.0, 7.0]) {
        void paint(Canvas c, double? dpr) => paintHalloweenScene(
          c,
          _size,
          t,
          UtopiaThemes.utopiaHalloween.world,
          moon: const Offset(125, 170),
          dpr: dpr,
        );
        final app = await _pixels((c) => paint(c, null), save: 'hw_app_$t');
        final web = await _pixels((c) => paint(c, _dpr), save: 'hw_web_$t');
        // (Its trees sway as a whole, a hair from where their branches
        // would bend to.)
        expect(_changed(app, web), lessThan(0.004), reason: 't $t');
      }
    });
  });
}
