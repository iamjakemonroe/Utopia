import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/widgets/countdown_border.dart';

void main() {
  int? left;
  final warned = <int>[];

  Widget timer() => Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: CountdownBorder(
        msLeft: () => left,
        totalMs: 15000,
        color: const Color(0xFF4DA3FF),
        onWarnSecond: warned.add,
        child: const SizedBox.square(key: Key('face'), dimension: 56),
      ),
    ),
  );

  // How much the heartbeat scales what's under it.
  double scale(WidgetTester tester) => tester
      .renderObject<RenderBox>(
        find
            .descendant(
              of: find.byType(CountdownBorder),
              matching: find.byType(CustomPaint),
            )
            .first,
      )
      .getTransformTo(null)
      .getMaxScaleOnAxis();

  setUp(() {
    left = null;
    warned.clear();
  });

  testWidgets('off the clock, it is just what it wraps', (tester) async {
    await tester.pumpWidget(timer());
    await tester.pump();
    expect(
      find.ancestor(
        of: find.byKey(const Key('face')),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
  });

  testWidgets('counting down, it is drawn again but never built again', (
    tester,
  ) async {
    var builds = 0;
    debugOnRebuildDirtyWidget = (element, _) {
      if (element.widget is CountdownBorder) builds++;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);

    left = 12000;
    await tester.pumpWidget(timer());
    await tester.pump(); // comes onto the clock: built once
    builds = 0;
    for (var i = 0; i < 30; i++) {
      left = left! - 16;
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(builds, 0);
    expect(
      find.ancestor(
        of: find.byKey(const Key('face')),
        matching: find.byType(CustomPaint),
      ),
      findsWidgets,
    );
    // Not yet in the warning: no heartbeat.
    expect(scale(tester), closeTo(1, 1e-9));
  });

  testWidgets('in the last seconds it beats, and warns once a second', (
    tester,
  ) async {
    left = 4990;
    await tester.pumpWidget(timer());
    await tester.pump();
    left = 4000; // a whole second: the beat's peak
    await tester.pump(const Duration(milliseconds: 16));
    expect(scale(tester), closeTo(1.05, 1e-6));
    left = 3500; // half way to the next: nearly still
    await tester.pump(const Duration(milliseconds: 16));
    expect(scale(tester), closeTo(1 + 0.05 * 0.125, 1e-6));
    left = 2990;
    await tester.pump(const Duration(milliseconds: 16));
    expect(warned, [5, 4, 3]);
  });
}
