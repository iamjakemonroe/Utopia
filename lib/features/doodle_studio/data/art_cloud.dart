import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/art_doc.dart';
import 'art_store.dart';

/// The sketchbook's copy on the server: a private folder per player in the
/// `sketchbook` bucket (see 20261021380000_sketchbook_cloud.sql).
abstract class ArtCloud {
  /// The files in [folder]: each one's name, and when it was saved.
  Future<List<String>> list(String folder);
  Future<void> put(String path, Uint8List bytes, String type);
  Future<Uint8List> get(String path);
  Future<void> remove(List<String> paths);
  Future<void> copy(String from, String to);

  /// Guests whose things moved to this player when they signed in.
  Future<List<String>> guestFolders();
}

class SupabaseArtCloud implements ArtCloud {
  SupabaseArtCloud(this._client);

  final SupabaseClient _client;

  StorageFileApi get _bucket => _client.storage.from('sketchbook');

  @override
  Future<List<String>> list(String folder) async => [
    for (final f in await _bucket.list(
      path: folder,
      searchOptions: const SearchOptions(limit: 10000),
    ))
      f.name,
  ];

  @override
  Future<void> put(String path, Uint8List bytes, String type) =>
      _bucket.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(upsert: true, contentType: type),
      );

  @override
  Future<Uint8List> get(String path) => _bucket.download(path);

  @override
  Future<void> remove(List<String> paths) => _bucket.remove(paths);

  @override
  Future<void> copy(String from, String to) => _bucket.copy(from, to);

  @override
  Future<List<String>> guestFolders() async {
    final rows = await _client.rpc('my_guest_folders') as List;
    return [for (final r in rows) '$r'];
  }
}

/// A player's art on their device, kept with their account too, so it's
/// never lost (a phone replaced, a browser's storage full or emptied) and
/// shows on every device they sign in on.
///
/// Every save goes to the device first, then up a few seconds after the
/// last one (at once if the device couldn't take it). On the web, where a
/// whole site gets about 5 MB, a piece is let go from the browser once
/// it's up ([keepLocal] false): the browser only holds what's on its way.
///
/// Each piece is up as `<player>/<id>.json` (what's drawn), `<id>.png` (its
/// small picture) and an empty `<id>~<kind>~<page>~<saved>.meta` whose name
/// is all the list needs.
class CloudArtStore implements ArtStore {
  CloudArtStore(
    this._local,
    this._cloud,
    this._player,
    this._prefs, {
    this.keepLocal = true,
    this.uploadAfter = const Duration(seconds: 3),
    this.guestStores,
  });

  final ArtStore _local;
  final ArtCloud _cloud;
  final String _player;
  final SharedPreferences _prefs;

  /// Keeps a copy on the device once it's up (not in a browser).
  final bool keepLocal;

  /// How long after the last save a piece goes up.
  final Duration uploadAfter;

  /// The device's stores for other players (guests whose things moved
  /// here), to bring their art along.
  final Future<ArtStore> Function(String player)? guestStores;

  /// What's up, by piece: its meta file's name, as last listed.
  final Map<String, String> _metas = {};

  /// Pieces waiting to go up: the latest save of each, and its number.
  final Map<String, (ArtDoc, Uint8List?, int)> _due = {};
  int _saves = 0;

  /// Deleted this visit (one on its way up as it went is taken down again).
  final Set<String> _deleted = {};

  /// What's on the device, as last listed.
  final Map<String, ArtSummary> _here = {};
  Timer? _timer;
  Future<void>? _sending;

  /// Downloaded this visit (pictures and pieces not on the device).
  final Map<String, Uint8List> _pictures = {};

  Future<void>? _adopting;

  String get _syncedKey => 'art_synced/$_player';

  static int _ms(ArtSummary s) => s.updated.millisecondsSinceEpoch;

  /// What's up is newer than what's on the device (saved on another one).
  bool _newerUp(String id) {
    final name = _metas[id];
    final up = name == null ? null : _fromMeta(name);
    if (up == null || _due.containsKey(id)) return false;
    final here = _here[id];
    return here == null || _ms(up) > _ms(here);
  }

  /// Pieces this device has seen up (so one missing there now was deleted
  /// on another device, not never sent).
  Set<String> get _synced => {...?_prefs.getStringList(_syncedKey)};

  void _setSynced(String id, bool up) {
    final all = _synced;
    if (up ? all.add(id) : all.remove(id)) {
      _prefs.setStringList(_syncedKey, all.toList());
    }
  }

  String _path(String name) => '$_player/$name';

  static String _metaName(ArtSummary s) {
    final page = s.pageId == null
        ? '_'
        : base64Url.encode(utf8.encode(s.pageId!)).replaceAll('=', '');
    return '${s.id}~${s.kind.name}~$page~${s.updated.millisecondsSinceEpoch}.meta';
  }

  static ArtSummary? _fromMeta(String name) {
    if (!name.endsWith('.meta')) return null;
    final parts = name.substring(0, name.length - 5).split('~');
    if (parts.length != 4) return null;
    final kind = ArtKind.values.where((k) => k.name == parts[1]).firstOrNull;
    final ms = int.tryParse(parts[3]);
    if (kind == null || ms == null) return null;
    String? page;
    if (parts[2] != '_') {
      try {
        page = utf8.decode(base64Url.decode(base64Url.normalize(parts[2])));
      } catch (_) {
        return null;
      }
    }
    return ArtSummary(
      id: parts[0],
      kind: kind,
      pageId: page,
      updated: DateTime.fromMillisecondsSinceEpoch(ms),
    );
  }

  /// What's up, newest save of each piece (older metas left over from an
  /// interrupted save are cleared away).
  Future<Map<String, ArtSummary>> _cloudList() async {
    final names = await _cloud.list(_player);
    final out = <String, ArtSummary>{};
    final stale = <String>[];
    _metas.clear();
    for (final name in names) {
      final s = _fromMeta(name);
      if (s == null) continue;
      final had = out[s.id];
      if (had != null && !s.updated.isAfter(had.updated)) {
        stale.add(_path(name));
        continue;
      }
      if (had != null) stale.add(_path(_metas[s.id]!));
      out[s.id] = s;
      _metas[s.id] = name;
    }
    if (stale.isNotEmpty) unawaited(_cloud.remove(stale).catchError((_) {}));
    return out;
  }

  @override
  Future<List<ArtSummary>> list() async {
    await (_adopting ??= _adopt()).catchError((_) {});
    List<ArtSummary> local;
    try {
      local = await _local.list();
    } catch (_) {
      local = const [];
    }
    final Map<String, ArtSummary> up;
    try {
      up = await _cloudList();
    } catch (_) {
      // Offline: what's on the device.
      return local;
    }
    final out = Map<String, ArtSummary>.of(up);
    final synced = _synced;
    _here
      ..clear()
      ..addEntries([for (final s in local) MapEntry(s.id, s)]);
    for (final here in local) {
      final there = up[here.id];
      if (there == null) {
        if (synced.contains(here.id) && !_due.containsKey(here.id)) {
          // Deleted on another device.
          await _local.delete(here.id).catchError((_) {});
          _setSynced(here.id, false);
          continue;
        }
        out[here.id] = here;
        unawaited(_sendFromDevice(here.id));
      } else if (_ms(here) > _ms(there)) {
        out[here.id] = here;
        unawaited(_sendFromDevice(here.id));
      } else {
        _setSynced(here.id, true);
      }
    }
    for (final id in up.keys) {
      _setSynced(id, true);
    }
    return out.values.toList()..sort((a, b) => b.updated.compareTo(a.updated));
  }

  /// Sends up a piece saved on the device but not up yet (made offline,
  /// or before art was kept with accounts).
  Future<void> _sendFromDevice(String id) async {
    // Already waiting (it couldn't go before): try again now.
    if (_due.containsKey(id)) return _send();
    final doc = await _local.load(id);
    if (doc == null) return;
    Uint8List? picture;
    try {
      picture = await _local.thumbnailBytes(id);
    } catch (_) {}
    _due[id] = (doc, picture, ++_saves);
    await _send();
  }

  @override
  Future<ArtDoc?> load(String id) async {
    final here = await _local.load(id).catchError((_) => null);
    if (here != null && !_newerUp(id)) return here;
    try {
      final bytes = await _cloud.get(_path('$id.json'));
      return ArtDoc.fromJson(
        (jsonDecode(utf8.decode(bytes)) as Map).cast<String, Object?>(),
      );
    } catch (_) {
      return here;
    }
  }

  @override
  Future<Uint8List> thumbnailBytes(String id) async {
    final name = _metas[id];
    if (name == null || !(_newerUp(id) || !_here.containsKey(id))) {
      return _local.thumbnailBytes(id);
    }
    final seen = _pictures[name];
    if (seen != null) return seen;
    try {
      return _pictures[name] = await _cloud.get(_path('$id.png'));
    } catch (_) {
      return _local.thumbnailBytes(id);
    }
  }

  @override
  Future<void> save(ArtDoc doc, {Uint8List? thumbnail}) async {
    var onDevice = true;
    try {
      await _local.save(doc, thumbnail: thumbnail);
    } catch (_) {
      // A full browser: it goes up at once instead.
      onDevice = false;
    }
    final had = _due[doc.id];
    _due[doc.id] = (doc, thumbnail ?? had?.$2, ++_saves);
    _timer?.cancel();
    if (!onDevice) {
      // Nowhere else to keep it: the save is only done once it's up.
      await _send();
      if (_due.containsKey(doc.id)) throw StateError('not saved');
      return;
    }
    _timer = Timer(uploadAfter, () => unawaited(_send()));
  }

  /// Sends up everything due, one piece at a time; a piece saved again
  /// meanwhile goes up again after.
  Future<void> _send() {
    final running = _sending;
    if (running != null) return running.then((_) => _send());
    final done = _sendAll();
    _sending = done;
    return done.whenComplete(() => _sending = null);
  }

  Future<void> _sendAll() async {
    while (_due.isNotEmpty) {
      final id = _due.keys.first;
      final (doc, picture, save) = _due[id]!;
      try {
        await _upload(doc, picture);
      } catch (_) {
        // Offline or the like: kept for the next save or list.
        return;
      }
      if (_deleted.contains(id)) {
        await _cloud.remove(_files(id)).catchError((_) {});
        continue;
      }
      // Saved again while it went up: that one goes next.
      if (_due[id]?.$3 != save) continue;
      _due.remove(id);
      _setSynced(id, true);
      if (!keepLocal) {
        // Safely up: the browser's room goes back to the game.
        await _local.delete(id).catchError((_) {});
      }
    }
  }

  Future<void> _upload(ArtDoc doc, Uint8List? picture) async {
    final summary = ArtSummary(
      id: doc.id,
      kind: doc.kind,
      updated: doc.updated,
      pageId: doc.pageId,
    );
    await _cloud.put(
      _path('${doc.id}.json'),
      Uint8List.fromList(utf8.encode(jsonEncode(doc.toJson()))),
      'application/json',
    );
    if (picture != null) {
      await _cloud.put(_path('${doc.id}.png'), picture, 'image/png');
    }
    final meta = _metaName(summary);
    await _cloud.put(_path(meta), Uint8List(0), 'application/json');
    final old = _metas[doc.id];
    _metas[doc.id] = meta;
    if (old != null && old != meta) {
      await _cloud.remove([_path(old)]).catchError((_) {});
    }
  }

  /// A piece's files up there.
  List<String> _files(String id) => [
    _path('$id.json'),
    _path('$id.png'),
    if (_metas[id] case final meta?) _path(meta),
  ];

  @override
  Future<void> delete(String id) async {
    _due.remove(id);
    _deleted.add(id);
    await _local.delete(id).catchError((_) {});
    final files = _files(id);
    _metas.remove(id);
    _here.remove(id);
    _setSynced(id, false);
    await _cloud.remove(files);
  }

  @override
  Future<void> deleteAll() async {
    _due.clear();
    _timer?.cancel();
    await _local.deleteAll().catchError((_) {});
    _prefs.remove(_syncedKey);
    try {
      final names = await _cloud.list(_player);
      if (names.isNotEmpty) {
        await _cloud.remove([for (final n in names) _path(n)]);
      }
    } catch (_) {}
  }

  /// Brings along the art of guests who became this player: theirs up
  /// (copied into this player's folder, then cleared), and theirs on this
  /// device (saved as this player's, then cleared), with anything drawn
  /// here signed out.
  Future<void> _adopt() async {
    final guests = await _cloud.guestFolders();
    for (final guest in [...guests, 'guest']) {
      if (guest == _player) continue;
      final names = guest == 'guest'
          ? const <String>[]
          : await _cloud.list(guest);
      for (final name in names) {
        try {
          await _cloud.copy('$guest/$name', _path(name));
        } catch (_) {
          // Already copied (an earlier visit stopped part way).
        }
      }
      if (names.isNotEmpty) {
        await _cloud.remove([for (final n in names) '$guest/$n']);
      }
      final open = guestStores;
      if (open == null) continue;
      final theirs = await open(guest);
      for (final s in await theirs.list()) {
        final doc = await theirs.load(s.id);
        if (doc == null) continue;
        Uint8List? picture;
        try {
          picture = await theirs.thumbnailBytes(s.id);
        } catch (_) {}
        await save(doc, thumbnail: picture);
      }
      await theirs.deleteAll();
    }
  }
}
