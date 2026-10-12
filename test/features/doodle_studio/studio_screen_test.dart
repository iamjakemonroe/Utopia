import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/doodle_studio/data/art_store.dart';
import 'package:utopia/features/doodle_studio/presentation/studio_screen.dart';
import 'package:utopia/features/doodle_studio/presentation/studio_toolbar.dart';

StudioButton _button(WidgetTester tester, String tooltip) => tester.widget(
  find.byWidgetPredicate((w) => w is StudioButton && w.tooltip == tooltip),
);

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('studio_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> open(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [artStoreProvider.overrideWith((ref) => ArtStore(dir))],
        child: const MaterialApp(home: StudioScreen()),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('a finger draws a line; undo and redo follow it', (tester) async {
    await open(tester, const Size(430, 900));
    expect(_button(tester, 'Undo').enabled, isFalse);

    final canvas = tester.getCenter(
      find.byKey(const ValueKey('studio-canvas')),
    );
    await tester.dragFrom(canvas, const Offset(120, 60));
    await tester.pump(const Duration(milliseconds: 50));
    expect(_button(tester, 'Undo').enabled, isTrue);

    await tester.tap(find.byTooltip('Undo'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(_button(tester, 'Undo').enabled, isFalse);
    expect(_button(tester, 'Redo').enabled, isTrue);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('two fingers zoom the page and draw nothing', (tester) async {
    await open(tester, const Size(430, 900));
    final c = tester.getCenter(find.byKey(const ValueKey('studio-canvas')));
    final a = await tester.startGesture(c - const Offset(40, 0), pointer: 1);
    final b = await tester.startGesture(c + const Offset(40, 0), pointer: 2);
    for (var i = 1; i <= 10; i++) {
      await a.moveTo(c - Offset(40.0 + i * 12, 0));
      await b.moveTo(c + Offset(40.0 + i * 12, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.textContaining('%'), findsOneWidget);
    await a.up();
    await b.up();
    await tester.pump(const Duration(milliseconds: 500));
    expect(_button(tester, 'Undo').enabled, isFalse);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('tablets get the tools down the sides', (tester) async {
    await open(tester, const Size(1180, 820));
    expect(find.byType(ToolPicker), findsOneWidget);
    final tools = tester.getRect(find.byType(ToolPicker));
    expect(tools.left, lessThan(150));
    expect(tools.height, greaterThan(tools.width));
    await tester.pump(const Duration(seconds: 2));
  });
}
