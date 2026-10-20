// Renders the Winter world plain and with the Snow Globe set on (Santa's
// sleigh crossing the moon in both), on a phone and an iPad, and New
// Year's Eve's fireworks, into test/tool/goldens/. Run:
// flutter test --run-skipped --update-goldens test/tool/winter_sheet_test.dart
@Tags(['sheet'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/theme/utopia_themes.dart';
import 'package:utopia/core/widgets/coin_buddy.dart';
import 'package:utopia/core/widgets/utopia_world.dart';
import 'package:utopia/core/widgets/winter_world.dart';
import 'package:utopia/core/widgets/world_sets.dart';

void main() {
  // Five seconds in, the sleigh is crossing the moon.
  const sleighAtMoon = Duration(milliseconds: 5000);

  for (final (name, on, width, height) in [
    ('plain', false, 430.0, 932.0),
    ('set', true, 430.0, 932.0),
    ('ipad', true, 1366.0, 1024.0),
  ]) {
    testWidgets('winter $name', (tester) async {
      tester.view.physicalSize = Size(width * 3, height * 3);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      WorldSets.winter.on.value = on;
      WorldSets.winter.settle();
      addTearDown(() {
        WorldSets.winter.on.value = false;
        WorldSets.winter.settle();
      });
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: const ValueKey('world'),
            child: FittedBox(
              child: SizedBox(
                width: width,
                height: height,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: UtopiaWorld(
                        style: UtopiaThemes.utopiaWinter.world,
                      ),
                    ),
                    Positioned(
                      left: width / 2 - 65,
                      top: height * 0.4,
                      child: const CoinBuddy(size: 130),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(sleighAtMoon);
      await expectLater(
        find.byKey(const ValueKey('world')),
        matchesGoldenFile('goldens/winter_$name.png'),
      );
    });
  }

  // The sleigh across the sky, and the fireworks of New Year's Eve, at
  // four moments each.
  testWidgets('winter moments', (tester) async {
    tester.view.physicalSize = const Size(1720, 1864);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final style = UtopiaThemes.utopiaWinter.world;
    Widget frame(double t, {bool newYear = false}) => Container(
      clipBehavior: Clip.hardEdge,
      width: 430,
      height: 932,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: style.sky,
        ),
      ),
      child: CustomPaint(painter: _Frozen(style, t, newYear: newYear)),
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: const ValueKey('world'),
          child: Column(
            children: [
              Row(
                children: [
                  for (final s in const [1.5, 3.5, 5.0, 6.5]) frame(s),
                ],
              ),
              Row(
                children: [
                  for (final s in const [10.6, 11.4, 12.2, 13.0])
                    frame(s, newYear: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await expectLater(
      find.byKey(const ValueKey('world')),
      matchesGoldenFile('goldens/winter_moments.png'),
    );
  });
}

class _Frozen extends CustomPainter {
  _Frozen(this.style, this.t, {this.newYear = false});

  final WorldStyle style;
  final double t;
  final bool newYear;

  @override
  void paint(Canvas canvas, Size size) {
    final moon = Offset(
      size.width * WinterTimeline.moonAcross,
      size.height * 0.15,
    );
    canvas.drawCircle(
      moon,
      size.width * 0.1,
      Paint()..color = const Color(0xFFE8F0FF),
    );
    paintWinterScene(
      canvas,
      size,
      t,
      style,
      moon: moon,
      newYear: newYear,
    );
  }

  @override
  bool shouldRepaint(covariant _Frozen oldDelegate) => true;
}
