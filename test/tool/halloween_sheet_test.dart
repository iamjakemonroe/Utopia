// Renders the Halloween world plain and with the Jack's Lantern set on
// (once mid-lightning), into test/tool/goldens/. Run:
// flutter test --run-skipped --update-goldens test/tool/halloween_sheet_test.dart
@Tags(['sheet'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/theme/utopia_themes.dart';
import 'package:utopia/core/widgets/coin_buddy.dart';
import 'package:utopia/core/widgets/halloween_world.dart';
import 'package:utopia/core/widgets/utopia_world.dart';
import 'package:utopia/core/widgets/world_sets.dart';

void main() {
  for (final (name, on) in [('plain', false), ('set', true)]) {
    testWidgets('halloween $name', (tester) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      WorldSets.halloween.on.value = on;
      WorldSets.halloween.settle();
      addTearDown(() {
        WorldSets.halloween.on.value = false;
        WorldSets.halloween.settle();
      });
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: const ValueKey('world'),
            child: FittedBox(
              child: SizedBox(
                width: 430,
                height: 932,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: UtopiaWorld(
                        style: UtopiaThemes.utopiaHalloween.world,
                      ),
                    ),
                    const Positioned(
                      left: 150,
                      top: 380,
                      child: CoinBuddy(size: 130),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      // The set's lightning comes every 5.5 s: land on a flash for it.
      await tester.pump(Duration(milliseconds: on ? 5520 : 3000));
      await expectLater(
        find.byKey(const ValueKey('world')),
        matchesGoldenFile('goldens/halloween_$name.png'),
      );
    });
  }

  // The world's clock is real time, so freeze the scene on a lightning
  // flash directly to see what it shows.
  testWidgets('halloween flash', (tester) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    WorldSets.halloween.on.value = true;
    WorldSets.halloween.settle();
    addTearDown(() {
      WorldSets.halloween.on.value = false;
      WorldSets.halloween.settle();
    });
    final style = UtopiaThemes.utopiaHalloween.world;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: const ValueKey('world'),
          child: FittedBox(
            child: Container(
              width: 430,
              height: 932,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: style.sky,
                ),
              ),
              child: CustomPaint(painter: _Frozen(style, 11.03)),
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byKey(const ValueKey('world')),
      matchesGoldenFile('goldens/halloween_flash.png'),
    );
  });
}

class _Frozen extends CustomPainter {
  _Frozen(this.style, this.t);

  final WorldStyle style;
  final double t;

  @override
  void paint(Canvas canvas, Size size) => paintHalloweenScene(
    canvas,
    size,
    t,
    style,
    moon: Offset(size.width * 0.32, size.height * 0.2),
  );

  @override
  bool shouldRepaint(covariant _Frozen oldDelegate) => false;
}
