import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia/features/doodle_studio/data/art_cloud.dart';
import 'package:utopia/features/doodle_studio/data/art_store.dart';
import 'package:utopia/features/doodle_studio/domain/art_doc.dart';

/// The server's copy, in memory.
class _Cloud implements ArtCloud {
  final files = <String, Uint8List>{};
  final guests = <String>[];
  bool down = false;
  int puts = 0;

  void _check() {
    if (down) throw StateError('offline');
  }

  List<String> under(String folder) => [
    for (final k in files.keys)
      if (k.startsWith('$folder/')) k.substring(folder.length + 1),
  ];

  @override
  Future<List<String>> list(String folder) async {
    _check();
    return under(folder);
  }

  @override
  Future<void> put(String path, Uint8List bytes, String type) async {
    _check();
    puts++;
    files[path] = bytes;
  }

  @override
  Future<Uint8List> get(String path) async {
    _check();
    return files[path] ?? (throw StateError('no $path'));
  }

  @override
  Future<void> remove(List<String> paths) async {
    _check();
    paths.forEach(files.remove);
  }

  @override
  Future<void> copy(String from, String to) async {
    _check();
    files[to] = files[from] ?? (throw StateError('no $from'));
  }

  @override
  Future<List<String>> guestFolders() async {
    _check();
    return guests;
  }
}

/// A browser whose storage is full.
class _FullBrowser extends WebArtStore {
  _FullBrowser(super.prefs, super.prefix);

  @override
  Future<void> save(ArtDoc doc, {Uint8List? thumbnail}) async =>
      throw StateError('QuotaExceededError');
}

ArtDoc _doc(String id, {int strokes = 1, DateTime? at}) {
  final doc = ArtDoc(
    id: id,
    kind: ArtKind.sketch,
    created: DateTime(2026, 10, 21),
    updated: at ?? DateTime(2026, 10, 21, 12),
  );
  for (var i = 0; i < strokes; i++) {
    doc.ops.add(
      StrokeOp(
        tool: ArtTool.marker,
        color: 0xFF000000,
        size: 12,
        points: [i.toDouble(), 1, 12],
      ),
    );
  }
  return doc;
}

final _png = Uint8List.fromList([137, 80, 78, 71]);

void main() {
  late SharedPreferences prefs;
  late _Cloud cloud;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    cloud = _Cloud();
  });

  CloudArtStore store({
    bool keepLocal = true,
    WebArtStore? local,
    String player = 'me',
  }) => CloudArtStore(
    local ?? WebArtStore(prefs, 'art/$player/'),
    cloud,
    player,
    prefs,
    keepLocal: keepLocal,
    uploadAfter: Duration.zero,
    guestStores: (p) async => WebArtStore(prefs, 'art/$p/'),
  );

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  test('a save is on the device at once, and up a moment later', () async {
    final s = store();
    await s.save(_doc('art-1'), thumbnail: _png);
    expect(await WebArtStore(prefs, 'art/me/').load('art-1'), isNotNull);
    await settle();
    expect(cloud.under('me'), containsAll(['art-1.json', 'art-1.png']));
    expect(cloud.under('me').where((n) => n.endsWith('.meta')), hasLength(1));
  });

  test('in a browser, a piece leaves its storage once it is up, and still '
      'opens', () async {
    final s = store(keepLocal: false);
    await s.save(_doc('art-1', strokes: 3), thumbnail: _png);
    await settle();
    expect(prefs.getKeys().where((k) => k.startsWith('art/me/')), isEmpty);
    final listed = await s.list();
    expect([for (final a in listed) a.id], ['art-1']);
    expect((await s.load('art-1'))!.ops, hasLength(3));
    expect(await s.thumbnailBytes('art-1'), _png);
  });

  test(
    "a full browser doesn't lose the painting: it goes up at once",
    () async {
      final s = store(local: _FullBrowser(prefs, 'art/me/'), keepLocal: false);
      await s.save(_doc('art-1'), thumbnail: _png);
      expect(cloud.under('me'), contains('art-1.json'));
    },
  );

  test('full and offline: the save says it failed', () async {
    cloud.down = true;
    final s = store(local: _FullBrowser(prefs, 'art/me/'), keepLocal: false);
    await expectLater(s.save(_doc('art-1')), throwsStateError);
  });

  test('a painting from another device shows and opens here', () async {
    await store(player: 'me').save(_doc('art-9', strokes: 2));
    await settle();
    // A second device: nothing of it on this one.
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final there = store();
    expect([for (final a in await there.list()) a.id], ['art-9']);
    expect((await there.load('art-9'))!.ops, hasLength(2));
  });

  test('one deleted on another device goes here too', () async {
    final s = store();
    await s.save(_doc('art-1'));
    await settle();
    await s.list();
    cloud.files.removeWhere((k, _) => k.startsWith('me/art-1'));
    expect(await s.list(), isEmpty);
    expect(await WebArtStore(prefs, 'art/me/').load('art-1'), isNull);
  });

  test('one made offline goes up when it can', () async {
    cloud.down = true;
    final s = store();
    await s.save(_doc('art-2'));
    await settle();
    expect(cloud.files, isEmpty);
    cloud.down = false;
    expect([for (final a in await s.list()) a.id], ['art-2']);
    await settle();
    expect(cloud.under('me'), contains('art-2.json'));
  });

  test('edited on another device: the newer one opens', () async {
    final s = store();
    await s.save(_doc('art-1', strokes: 1));
    await settle();
    // The other device saves 5 strokes, later.
    final other = CloudArtStore(
      WebArtStore(prefs, 'art/other-device/'),
      cloud,
      'me',
      prefs,
      uploadAfter: Duration.zero,
    );
    await other.save(_doc('art-1', strokes: 5, at: DateTime(2026, 10, 21, 13)));
    await settle();
    await s.list();
    expect((await s.load('art-1'))!.ops, hasLength(5));
    expect(
      cloud.under('me').where((n) => n.endsWith('.meta')),
      hasLength(1),
      reason: 'the older save note cleared away',
    );
  });

  test('saved again while going up: the newest goes up after', () async {
    final s = store();
    final doc = _doc('art-1');
    await s.save(doc);
    doc.ops.add(doc.ops.first);
    doc.updated = DateTime(2026, 10, 21, 14);
    await s.save(doc);
    await settle();
    final json = String.fromCharCodes(cloud.files['me/art-1.json']!);
    expect(RegExp('"t":"s"').allMatches(json), hasLength(2));
  });

  test('deleted: gone here and up there', () async {
    final s = store();
    await s.save(_doc('art-1'), thumbnail: _png);
    await settle();
    await s.list();
    await s.delete('art-1');
    expect(cloud.under('me'), isEmpty);
    expect(await s.list(), isEmpty);
  });

  test("a guest's paintings come along when they sign in", () async {
    // As the guest: one up, one only on this device.
    final guest = store(player: 'guest-1');
    await guest.save(_doc('art-g1'), thumbnail: _png);
    await settle();
    cloud.down = true;
    await guest.save(_doc('art-g2'));
    await settle();
    cloud.down = false;
    // Signed in to their account, which the guest moved to.
    cloud.guests.add('guest-1');
    final me = store();
    final ids = {for (final a in await me.list()) a.id};
    await settle();
    expect(ids, {'art-g1', 'art-g2'});
    expect(cloud.under('guest-1'), isEmpty);
    expect(cloud.under('me'), containsAll(['art-g1.json', 'art-g2.json']));
    expect(await WebArtStore(prefs, 'art/guest-1/').list(), isEmpty);
  });
}
