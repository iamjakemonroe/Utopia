import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:utopia/core/theme/theme_controller.dart';
import 'package:utopia/features/doodle_studio/data/art_store.dart';
import 'package:utopia/features/doodle_studio/data/picture_library.dart';
import 'package:utopia/features/doodle_studio/presentation/sketchbook_screen.dart';

/// A library with nothing in it that records what Chip was asked to draw.
class _FakeLibrary extends PictureLibrary {
  _FakeLibrary()
    : super(
        SupabaseClient(
          'http://localhost',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final asked = <String>[];

  @override
  Future<PictureAsk> ask(String subject) async {
    asked.add(subject);
    return const PictureAsk('drawing', id: 'new');
  }
}

const _square = LibraryPicture(
  id: 'sq',
  status: 'ready',
  title: 'Big square',
  paths: ['M 100 100 L 900 100 L 900 1200 L 100 1200 Z'],
);

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('picker_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<_FakeLibrary> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final library = _FakeLibrary();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          artStoreProvider.overrideWith((ref) => ArtStore(dir)),
          pictureLibraryProvider.overrideWithValue(library),
          myPicturesProvider.overrideWith(
            (ref) async => const [
              _square,
              LibraryPicture(id: 'w', status: 'drawing', title: ''),
            ],
          ),
          pictureSearchProvider.overrideWith(
            (ref, query) async => query.isEmpty || query == 'zebra'
                ? const <LibraryPicture>[]
                : const [_square],
          ),
          pictureWatchProvider.overrideWith(
            (ref, id) => Stream.value(
              const LibraryPicture(id: 'w', status: 'drawing', title: ''),
            ),
          ),
        ],
        child: const MaterialApp(home: SketchbookScreen(pick: true)),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return library;
  }

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump(const Duration(milliseconds: 400));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('shows your pictures, one still being drawn, and ours', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Yours'), findsOneWidget);
    expect(find.text('Big square'), findsOneWidget);
    expect(find.text('Chip is drawing...'), findsOneWidget);
    expect(find.text("Utopia's pictures"), findsOneWidget);
    expect(find.text('Mandala'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a search nobody has asked for offers to have Chip draw it', (
    tester,
  ) async {
    final library = await open(tester);
    await search(tester, 'zebra');
    expect(find.text('Nobody has asked for that yet.'), findsOneWidget);
    expect(find.text('Ask Chip to draw "zebra"'), findsOneWidget);
    expect(find.text('Mandala'), findsNothing);

    await tester.tap(find.text('Ask Chip to draw "zebra"'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(library.asked, ['zebra']);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('a search that finds pictures still lets you ask Chip', (
    tester,
  ) async {
    await open(tester);
    await search(tester, 'square');
    expect(find.text('From the library'), findsOneWidget);
    expect(find.text('Not quite? Ask Chip to draw "square"'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });
}
