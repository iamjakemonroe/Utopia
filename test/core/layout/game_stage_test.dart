import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/layout/game_stage.dart';

Future<void> _stage(WidgetTester tester, Size screen) async {
  tester.view.physicalSize = screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    const Directionality(
      textDirection: TextDirection.ltr,
      child: GameStage(
        above: [SizedBox(key: Key('top'), height: 60)],
        board: Center(
          child: AspectRatio(
            aspectRatio: 1,
            child: ColoredBox(key: Key('board'), color: Colors.green),
          ),
        ),
        below: [SizedBox(key: Key('bottom'), height: 60)],
      ),
    ),
  );
}

void main() {
  testWidgets('a phone held upright: one column', (tester) async {
    await _stage(tester, const Size(390, 760));
    final top = tester.getRect(find.byKey(const Key('top')));
    final board = tester.getRect(find.byKey(const Key('board')));
    final bottom = tester.getRect(find.byKey(const Key('bottom')));
    expect(top.bottom, lessThanOrEqualTo(board.top));
    expect(board.bottom, lessThanOrEqualTo(bottom.top));
  });

  for (final (name, screen) in [
    ('an iPad upright', const Size(992, 1250)),
    ('an iPad on its side', const Size(1334, 910)),
    ('a phone on its side', const Size(800, 340)),
  ]) {
    testWidgets('$name: the board beside a panel as tall as it', (
      tester,
    ) async {
      await _stage(tester, screen);
      final top = tester.getRect(find.byKey(const Key('top')));
      final board = tester.getRect(find.byKey(const Key('board')));
      final bottom = tester.getRect(find.byKey(const Key('bottom')));
      expect(top.left, greaterThan(board.right));
      expect(top.top, closeTo(board.top, 1));
      expect(bottom.bottom, closeTo(board.bottom, 1));
      expect(board.width, closeTo(board.height, 1));
    });
  }
}
