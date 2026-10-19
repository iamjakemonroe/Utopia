import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/platform/device_key.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../domain/coloring_pages.dart';
import '../domain/line_art.dart';

/// A picture in the library Chip draws for players (coloring_pages).
class LibraryPicture {
  const LibraryPicture({
    required this.id,
    required this.status,
    required this.title,
    this.paths = const [],
    this.art,
  });

  final String id;

  /// 'drawing', 'ready', 'refused' or 'failed'.
  final String status;
  final String title;

  /// The outlines, SVG path data in page units.
  final List<String> paths;

  /// A real portrait's line art (where it's kept), instead of outlines.
  final String? art;

  bool get ready => status == 'ready' && (paths.isNotEmpty || art != null);

  /// Library pictures go by 'p:' and their id among the built-in pages.
  String get pageId => '$kLibraryPrefix$id';

  ColoringPage get page => art != null
      ? ColoringPage.fromArt(id: pageId, name: title, artPath: art!)
      : ColoringPage.fromSvg(id: pageId, name: title, paths: paths);

  static LibraryPicture? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! String) return null;
    final paths = json['paths'];
    return LibraryPicture(
      id: id,
      status: json['status'] as String? ?? 'ready',
      title: json['title'] as String? ?? '',
      paths: paths is List ? paths.whereType<String>().toList() : const [],
      art: json['art'] as String?,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'status': status,
    'title': title,
    'paths': paths,
    if (art != null) 'art': art,
  };
}

/// What happened when the player asked for a picture.
class PictureAsk {
  const PictureAsk(this.status, {this.id});

  /// 'ready', 'drawing', 'refused' (not for a coloring book), 'limited'
  /// (no more new drawings today), or 'error'.
  final String status;
  final String? id;
}

const kLibraryPrefix = 'p:';

/// The shared picture library: searching it, asking Chip for a picture,
/// and watching one being drawn. Pictures that open are kept on the phone
/// too, so art colored from them always opens again, even offline.
class PictureLibrary {
  PictureLibrary(this._client);

  final SupabaseClient _client;

  static const _columns = 'id, status, title, paths, art';

  /// Ready pictures matching every word of [query], most asked for first;
  /// the most asked for of all when [query] is empty.
  Future<List<LibraryPicture>> search(String query) async {
    final words = query
        .toLowerCase()
        .replaceAll(RegExp(r"[^\p{L}\p{N}\s'-]", unicode: true), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 1)
        .take(5);
    var q = _client
        .from('coloring_pages')
        .select(_columns)
        .eq('status', 'ready');
    for (final w in words) {
      q = q.ilike('search', '%$w%');
    }
    final rows = await q
        .order('asks', ascending: false)
        .order('created_at', ascending: false)
        .limit(24);
    return [for (final r in rows) ?LibraryPicture.fromJson(r)];
  }

  /// The pictures this player asked for, newest first (including any still
  /// being drawn).
  Future<List<LibraryPicture>> mine() async {
    final rows = await _client
        .from('coloring_asks')
        .select('asked_at, coloring_pages($_columns)')
        .order('asked_at', ascending: false)
        .limit(30);
    return [
      for (final r in rows)
        if (LibraryPicture.fromJson(r['coloring_pages']) case final p?)
          if (p.status == 'ready' || p.status == 'drawing') p,
    ];
  }

  /// Asks Chip to draw [subject] (or finds it, when someone already has).
  Future<PictureAsk> ask(String subject) async {
    try {
      final res = await _client.functions.invoke(
        'chip',
        body: {'action': 'draw', 'device': DeviceKey.value, 'subject': subject},
      );
      final data = res.data;
      if (data is Map && data['status'] is String) {
        return PictureAsk(data['status'] as String, id: data['id'] as String?);
      }
    } on FunctionException catch (e) {
      if (e.status == 503) return const PictureAsk('off');
    } catch (_) {}
    return const PictureAsk('error');
  }

  /// One picture as it is now (null when it can't be seen).
  Future<LibraryPicture?> fetch(String id) async {
    final row = await _client
        .from('coloring_pages')
        .select(_columns)
        .eq('id', id)
        .maybeSingle();
    return LibraryPicture.fromJson(row);
  }

  /// [id] while it's being drawn, until it's ready, refused or failed (or
  /// it has taken far too long).
  Stream<LibraryPicture?> watch(String id) async* {
    final until = DateTime.now().add(const Duration(minutes: 5));
    while (true) {
      LibraryPicture? p;
      try {
        p = await fetch(id);
      } catch (_) {
        p = null;
      }
      if (p != null && p.status != 'drawing') {
        if (p.ready) unawaited(_keep(p));
        yield p;
        return;
      }
      if (DateTime.now().isAfter(until)) {
        yield LibraryPicture(id: id, status: 'failed', title: p?.title ?? '');
        return;
      }
      yield p;
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }

  /// The coloring page for [pageId]: a built-in one, or a library picture
  /// from the phone or, failing that, from the library.
  Future<ColoringPage?> page(String? pageId) async {
    final built = ColoringPage.byId(pageId);
    if (built != null || pageId == null) return built;
    if (!pageId.startsWith(kLibraryPrefix)) return null;
    final id = pageId.substring(kLibraryPrefix.length);
    final kept = await _kept(id);
    if (kept != null) return kept.page;
    final p = await fetch(id);
    if (p == null || !p.ready) return null;
    unawaited(_keep(p));
    return p.page;
  }

  /// The name of [pageId] if it's on the phone (for titles).
  Future<String?> name(String? pageId) async =>
      ColoringPage.byId(pageId)?.name ??
      (pageId != null && pageId.startsWith(kLibraryPrefix)
          ? (await _kept(pageId.substring(kLibraryPrefix.length)))?.title
          : null);

  static Future<File> _file(String id) async {
    final docs = await getApplicationDocumentsDirectory();
    final safe = id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return File('${docs.path}/pictures/$safe.json');
  }

  Future<LibraryPicture?> _kept(String id) async {
    try {
      final f = await _file(id);
      if (!await f.exists()) return null;
      final p = LibraryPicture.fromJson(jsonDecode(await f.readAsString()));
      return p != null && p.ready ? p : null;
    } catch (_) {
      return null;
    }
  }

  /// Keeps [p] on the phone (written whole, then swapped in).
  Future<void> _keep(LibraryPicture p) async {
    try {
      final f = await _file(p.id);
      await f.parent.create(recursive: true);
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode(p.toJson()), flush: true);
      await tmp.rename(f.path);
    } catch (_) {}
  }

  /// Keeps [p] now, before art is made from it.
  Future<void> keep(LibraryPicture p) => _keep(p);

  /// A real portrait's line art: from the phone if it's here, otherwise
  /// fetched (it's private to the player) and kept for next time.
  Future<Uint8List> artBytes(String path) async {
    // A browser keeps nothing on disk: fetch it each time.
    if (kIsWeb) return _client.storage.from('coloring-art').download(path);
    final docs = await getApplicationDocumentsDirectory();
    final safe = path.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final file = File('${docs.path}/pictures/art_$safe');
    if (await file.exists()) return file.readAsBytes();
    final bytes = await _client.storage.from('coloring-art').download(path);
    try {
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {}
    return bytes;
  }
}

final pictureLibraryProvider = Provider<PictureLibrary>((ref) {
  final library = PictureLibrary(ref.watch(supabaseClientProvider));
  // Portraits' line art comes from here wherever a page is drawn.
  LineArt.source = library.artBytes;
  return library;
});

/// Library pictures matching a search ('' for the most asked for).
final pictureSearchProvider = FutureProvider.autoDispose
    .family<List<LibraryPicture>, String>(
      (ref, query) => ref.watch(pictureLibraryProvider).search(query),
    );

/// The pictures this player asked for.
final myPicturesProvider = FutureProvider.autoDispose<List<LibraryPicture>>(
  (ref) => ref.watch(pictureLibraryProvider).mine(),
);

/// A picture being drawn, until it's done.
final pictureWatchProvider = StreamProvider.autoDispose
    .family<LibraryPicture?, String>(
      (ref, id) => ref.watch(pictureLibraryProvider).watch(id),
    );
