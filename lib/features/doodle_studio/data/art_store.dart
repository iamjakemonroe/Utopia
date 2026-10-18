import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/presentation/providers/auth_providers.dart';
import '../domain/art_doc.dart';

/// A piece of art in the list: enough to show it without loading it.
class ArtSummary {
  const ArtSummary({
    required this.id,
    required this.kind,
    required this.updated,
    this.pageId,
  });

  final String id;
  final ArtKind kind;
  final String? pageId;
  final DateTime updated;

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'page': pageId,
    'updated': updated.toIso8601String(),
  };

  static ArtSummary? fromJson(Map<String, Object?> json) {
    final id = json['id'] as String?;
    final kind = ArtKind.values
        .where((k) => k.name == json['kind'])
        .firstOrNull;
    final updated = DateTime.tryParse(json['updated'] as String? ?? '');
    if (id == null || kind == null || updated == null) return null;
    return ArtSummary(
      id: id,
      kind: kind,
      updated: updated,
      pageId: json['page'] as String?,
    );
  }
}

/// A player's art, kept on their device: in the app's own files on a phone
/// ([FileArtStore]), in the browser's storage on the web ([WebArtStore]).
abstract class ArtStore {
  static Future<ArtStore> open(String player) {
    final safe = player.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return kIsWeb ? WebArtStore.open(safe) : FileArtStore.open(safe);
  }

  /// Everything saved, newest first.
  Future<List<ArtSummary>> list();

  Future<ArtDoc?> load(String id);

  /// Saves [doc] (and its small picture, when given).
  Future<void> save(ArtDoc doc, {Uint8List? thumbnail});

  Future<void> delete(String id);

  /// The small picture for the list. Throws when there isn't one yet.
  Future<Uint8List> thumbnailBytes(String id);

  /// Forgets every piece (the account is going).
  Future<void> deleteAll();
}

/// Art on a phone, kept in the app's own files (so it stays through
/// changing worlds, closing the app and restarting the phone): for each
/// piece, everything drawn (`<id>.json`), a note for the list
/// (`<id>.meta`) and a small picture of it (`<id>.png`). Every write goes to
/// a temporary file first and then replaces the old one, so a save cut
/// short never leaves a broken file behind.
class FileArtStore implements ArtStore {
  FileArtStore(this.dir);

  final Directory dir;

  /// Writes one at a time, in order.
  Future<void> _queue = Future.value();

  static Future<ArtStore> open(String player) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/art/$player');
    await dir.create(recursive: true);
    return FileArtStore(dir);
  }

  File _file(String id, String ext) => File('${dir.path}/$id.$ext');

  @override
  Future<Uint8List> thumbnailBytes(String id) => _file(id, 'png').readAsBytes();

  @override
  Future<void> deleteAll() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  @override
  Future<List<ArtSummary>> list() async {
    if (!await dir.exists()) return const [];
    final out = <ArtSummary>[];
    await for (final f in dir.list()) {
      if (f is! File || !f.path.endsWith('.meta')) continue;
      try {
        final summary = ArtSummary.fromJson(
          (jsonDecode(await f.readAsString()) as Map).cast<String, Object?>(),
        );
        if (summary != null && await _file(summary.id, 'json').exists()) {
          out.add(summary);
        }
      } catch (_) {
        // A damaged note: leave that piece out rather than fail the list.
      }
    }
    out.sort((a, b) => b.updated.compareTo(a.updated));
    return out;
  }

  @override
  Future<ArtDoc?> load(String id) async {
    final f = _file(id, 'json');
    if (!await f.exists()) return null;
    try {
      return ArtDoc.fromJson(
        (jsonDecode(await f.readAsString()) as Map).cast<String, Object?>(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(ArtDoc doc, {Uint8List? thumbnail}) {
    final json = jsonEncode(doc.toJson());
    final meta = jsonEncode(
      ArtSummary(
        id: doc.id,
        kind: doc.kind,
        updated: doc.updated,
        pageId: doc.pageId,
      ).toJson(),
    );
    return _enqueue(() async {
      await _write(_file(doc.id, 'json'), utf8.encode(json));
      if (thumbnail != null) await _write(_file(doc.id, 'png'), thumbnail);
      await _write(_file(doc.id, 'meta'), utf8.encode(meta));
    });
  }

  @override
  Future<void> delete(String id) => _enqueue(() async {
    for (final ext in const ['meta', 'json', 'png']) {
      final f = _file(id, ext);
      if (await f.exists()) await f.delete();
    }
  });

  Future<void> _write(File f, List<int> bytes) async {
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(f.path);
  }

  Future<void> _enqueue(Future<void> Function() job) {
    final next = _queue.then((_) => job());
    // A failed write mustn't block the ones after it.
    _queue = next.catchError((_) {});
    return next;
  }
}

/// Art in a browser, kept in its local storage: the same three things per
/// piece as on a phone, under keys named for the player and the piece.
class WebArtStore implements ArtStore {
  WebArtStore(this._prefs, this._prefix);

  final SharedPreferences _prefs;
  final String _prefix;

  static Future<ArtStore> open(String player) async =>
      WebArtStore(await SharedPreferences.getInstance(), 'art/$player/');

  String _key(String id, String ext) => '$_prefix$id.$ext';

  @override
  Future<List<ArtSummary>> list() async {
    final out = <ArtSummary>[];
    for (final key in _prefs.getKeys()) {
      if (!key.startsWith(_prefix) || !key.endsWith('.meta')) continue;
      try {
        final summary = ArtSummary.fromJson(
          (jsonDecode(_prefs.getString(key)!) as Map).cast<String, Object?>(),
        );
        if (summary != null && _prefs.containsKey(_key(summary.id, 'json'))) {
          out.add(summary);
        }
      } catch (_) {}
    }
    out.sort((a, b) => b.updated.compareTo(a.updated));
    return out;
  }

  @override
  Future<ArtDoc?> load(String id) async {
    final json = _prefs.getString(_key(id, 'json'));
    if (json == null) return null;
    try {
      return ArtDoc.fromJson((jsonDecode(json) as Map).cast<String, Object?>());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(ArtDoc doc, {Uint8List? thumbnail}) async {
    await _prefs.setString(_key(doc.id, 'json'), jsonEncode(doc.toJson()));
    if (thumbnail != null) {
      await _prefs.setString(_key(doc.id, 'png'), base64Encode(thumbnail));
    }
    await _prefs.setString(
      _key(doc.id, 'meta'),
      jsonEncode(
        ArtSummary(
          id: doc.id,
          kind: doc.kind,
          updated: doc.updated,
          pageId: doc.pageId,
        ).toJson(),
      ),
    );
  }

  @override
  Future<void> delete(String id) async {
    for (final ext in const ['meta', 'json', 'png']) {
      await _prefs.remove(_key(id, ext));
    }
  }

  @override
  Future<Uint8List> thumbnailBytes(String id) async {
    final png = _prefs.getString(_key(id, 'png'));
    if (png == null) throw StateError('no picture yet');
    return base64Decode(png);
  }

  @override
  Future<void> deleteAll() async {
    for (final key in _prefs.getKeys().toList()) {
      if (key.startsWith(_prefix)) await _prefs.remove(key);
    }
  }
}

/// This player's art store (art is kept per player, so two people sharing a
/// phone each see their own).
final artStoreProvider = FutureProvider<ArtStore>((ref) {
  final player = ref.watch(currentUserProvider.select((u) => u?.id)) ?? 'guest';
  return ArtStore.open(player);
});

/// Everything this player has made, newest first.
final myArtProvider = FutureProvider.autoDispose<List<ArtSummary>>((ref) async {
  final store = await ref.watch(artStoreProvider.future);
  return store.list();
});
