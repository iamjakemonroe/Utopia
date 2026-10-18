import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/layout/tile_grid.dart';

void main() {
  testWidgets('cards fill rows in order; a hidden one leaves no gap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Widget card(String key, double height) =>
        SizedBox(key: Key(key), height: height);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: TileGrid(
            columns: 2,
            spacing: 20,
            children: [
              card('a', 100),
              card('hidden', 0),
              card('b', 140),
              card('c', 80),
            ],
          ),
        ),
      ),
    );
    final a = tester.getRect(find.byKey(const Key('a')));
    final b = tester.getRect(find.byKey(const Key('b')));
    final c = tester.getRect(find.byKey(const Key('c')));
    expect(a.width, 490);
    // b is beside a (the hidden card took no place), c starts the next row
    // under the taller of the two.
    expect(b.left, 510);
    expect(b.top, 0);
    expect(c.left, 0);
    expect(c.top, 140);
    expect(tester.getSize(find.byType(TileGrid)).height, 220);
  });
}
