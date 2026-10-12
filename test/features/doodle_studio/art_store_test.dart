import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/doodle_studio/data/art_store.dart';
import 'package:utopia/features/doodle_studio/domain/art_doc.dart';

void main() {
  late Directory dir;
  late ArtStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('art_store_test');
    store = ArtStore(dir);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('saves, lists newest first, loads and deletes', () async {
    final older = ArtDoc.blank(ArtKind.sketch, now: DateTime(2026, 1, 1))
      ..add(
        const StrokeOp(
          tool: ArtTool.marker,
          color: 1,
          size: 6,
          points: [1, 2, 6],
        ),
      );
    final newer = ArtDoc.blank(
      ArtKind.coloring,
      pageId: 'rocket',
      now: DateTime(2026, 1, 2),
    )..add(const FillOp(region: 4, color: 0xFFFF0000));
    await store.save(older, thumbnail: Uint8List.fromList([1, 2, 3]));
    await store.save(newer);

    final list = await store.list();
    expect(list.map((s) => s.id), [newer.id, older.id]);
    expect(list.first.pageId, 'rocket');
    expect(await store.thumbnail(older.id).readAsBytes(), [1, 2, 3]);

    final loaded = (await store.load(newer.id))!;
    expect(loaded.kind, ArtKind.coloring);
    expect(loaded.fills, {4: 0xFFFF0000});

    await store.delete(older.id);
    expect((await store.list()).map((s) => s.id), [newer.id]);
    expect(store.thumbnail(older.id).existsSync(), isFalse);
  });

  test(
    'a damaged file is left out, not fatal; nothing half-written stays',
    () async {
      final doc = ArtDoc.blank(ArtKind.sketch)
        ..add(
          const StrokeOp(
            tool: ArtTool.pen,
            color: 1,
            size: 6,
            points: [1, 2, 6],
          ),
        );
      await store.save(doc);
      File('${dir.path}/broken.meta').writeAsStringSync('{not json');
      expect((await store.list()).map((s) => s.id), [doc.id]);
      expect(dir.listSync().where((f) => f.path.endsWith('.tmp')), isEmpty);
      expect(await store.load('missing'), isNull);
    },
  );
}
