import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/theme/utopia_themes.dart';
import 'package:utopia/core/widgets/utopia_world.dart';

const _size = Size(390, 844);
const _dpr = 3.0;

/// A world on a phone's screen, as pixels: its sky drawn straight, or as a
/// browser keeps it ([debugShareSkies]).
Future<Uint8List> _world(
  WidgetTester tester,
  WorldStyle style, {
  required bool shared,
}) async {
  debugShareSkies = shared;
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: key,
          child: SizedBox.fromSize(
            size: _size,
            child: UtopiaWorld(key: ValueKey(shared), style: style),
          ),
        ),
      ),
    ),
  );
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _dpr);
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return rgba!.buffer.asUint8List();
  }))!;
}

void main() {
  setUp(() {
    debugWorldSeconds = 3.2;
  });
  tearDown(() {
    debugWorldSeconds = null;
    debugShareSkies = null;
  });

  testWidgets('a shared sky draws the same pixels as the sky itself', (
    tester,
  ) async {
    tester.view.devicePixelRatio = _dpr;
    tester.view.physicalSize = _size * _dpr * 1.2;
    addTearDown(tester.view.reset);
    for (final theme in [
      UtopiaThemes.utopiaTwilight,
      UtopiaThemes.utopiaDoodle,
    ]) {
      final straight = await _world(tester, theme.world, shared: false);
      final shared = await _world(tester, theme.world, shared: true);
      expect(shared.length, straight.length);
      var off = 0;
      for (var i = 0; i < straight.length; i++) {
        if ((shared[i] - straight[i]).abs() > 1) off++;
      }
      expect(off, 0, reason: '${theme.id}: channels off by more than 1');
    }
  });

  testWidgets('every copy of a world at one size shares one sky', (
    tester,
  ) async {
    debugShareSkies = true;
    tester.view.devicePixelRatio = _dpr;
    tester.view.physicalSize = _size * _dpr;
    addTearDown(tester.view.reset);
    final world = UtopiaThemes.utopiaTwilight.world;
    Widget screens({required bool header}) => Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          Positioned.fill(child: UtopiaWorld(style: world)),
          // A screen opened over it, in the same world at the same size.
          Positioned.fill(child: UtopiaWorld(style: world)),
          // The side menu's header: smaller, so a sky of its own.
          if (header)
            Positioned(
              left: 0,
              top: 0,
              width: 320,
              height: 210,
              child: UtopiaWorld(style: world),
            ),
        ],
      ),
    );
    final before = debugSharedSkies;
    await tester.pumpWidget(screens(header: false));
    final screensMade = debugSharedSkies - before;
    expect(screensMade, lessThanOrEqualTo(1), reason: 'one sky for both');
    await tester.pumpWidget(screens(header: true));
    expect(debugSharedSkies - before, screensMade + 1);
  });
}
