import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

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

/// A player's art on this phone, kept in the app's own files (so it stays
/// through changing worlds, closing the app and restarting the phone):
/// for each piece, everything drawn (`<id>.json`), a note for the list
/// (`<id>.meta`) and a small picture of it (`<id>.png`). Every write goes to
/// a temporary file first and then replaces the old one, so a save cut
/// short never leaves a broken file behind.
class ArtStore {
  ArtStore(this.dir);

  final Directory dir;

  /// Writes one at a time, in order.
  Future<void> _queue = Future.value();

  static Future<ArtStore> open(String player) async {
    final docs = await getApplicationDocumentsDirectory();
    final safe = player.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final dir = Directory('${docs.path}/art/$safe');
    await dir.create(recursive: true);
    return ArtStore(dir);
  }

  File _file(String id, String ext) => File('${dir.path}/$id.$ext');

  /// The small picture for the list (it may not exist yet).
  File thumbnail(String id) => _file(id, 'png');

  /// Everything saved, newest first.
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

  /// Saves [doc] (and its small picture, when given).
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
