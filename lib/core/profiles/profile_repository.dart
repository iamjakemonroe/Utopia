import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// The name everyone sees: the player's nickname (`display_name`, set with
/// set_nickname; it can have spaces and needn't be unique), else their
/// username, else a short id-based tag (e.g. "Player 4a2f") so two players
/// without names never look like the same person. Always route name
/// lookups through this function instead of inlining a fallback literal.
String profileDisplayName(Map<String, dynamic>? profile, String userId) {
  final displayName = profile?['display_name'] as String?;
  if (displayName != null && displayName.isNotEmpty) return displayName;
  final username = profile?['username'] as String?;
  // Usernames are stored lowercase; shown as a name, they start with a
  // capital ("maya42" reads as "Maya42"). @handles keep the raw form.
  if (username != null && username.isNotEmpty) {
    return username[0].toUpperCase() + username.substring(1);
  }
  final tag = userId.length >= 4 ? userId.substring(0, 4) : userId;
  return 'Player $tag';
}

/// Read access to other users' public profile fields (id, display_name,
/// username) — the columns `select any profile for search/matches` (see
/// the chess/social migration) exposes. Nothing here can write a balance;
/// mutation stays entirely in `set_username` and the coins/matches RPCs.
class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  static const _publicColumns =
      'id, display_name, username, avatar_url, avatar_kind, avatar_seed, '
      'equipped_theme, equipped_ludo_pieces, equipped_chess_pieces, '
      'equipped_aura, aura_expires_at, show_coins, show_stats';

  Future<Map<String, dynamic>?> fetchById(String id) {
    return _client
        .from('profiles')
        .select(_publicColumns)
        .eq('id', id)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> fetchByIds(List<String> ids) {
    if (ids.isEmpty) return Future.value(const []);
    return _client.from('profiles').select(_publicColumns).inFilter('id', ids);
  }

  /// Case-insensitive search by username or nickname, excluding
  /// [excludeId] (the caller, so you never see yourself). Exact and
  /// starts-with username matches come first.
  Future<List<Map<String, dynamic>>> searchByUsername(
    String query, {
    String? excludeId,
  }) async {
    // Only characters names can contain: anything else would break the
    // filter syntax.
    final q = query
        .trim()
        .replaceFirst(RegExp(r'^@'), '')
        .replaceAll(RegExp(r"[^\p{L}\p{N} _.'-]", unicode: true), '');
    if (q.isEmpty) return const [];
    final rows = await _client
        .from('profiles')
        .select(_publicColumns)
        // Quoted, so spaces and dots in a nickname stay part of the value.
        .or('username.ilike."%$q%",display_name.ilike."%$q%"')
        .limit(30);
    final results = List<Map<String, dynamic>>.from(rows);
    if (excludeId != null) {
      results.removeWhere((row) => row['id'] == excludeId);
    }
    final lower = q.toLowerCase();
    int rank(Map<String, dynamic> row) {
      final u = (row['username'] as String? ?? '').toLowerCase();
      if (u == lower) return 0;
      if (u.startsWith(lower)) return 1;
      final n = (row['display_name'] as String? ?? '').toLowerCase();
      if (n.startsWith(lower)) return 2;
      return 3;
    }

    results.sort((a, b) => rank(a).compareTo(rank(b)));
    return results;
  }

  /// Whether someone other than [myId] already uses [username].
  Future<bool> isUsernameTaken(String username, String myId) async {
    final row = await _client
        .from('profiles')
        .select('id')
        .eq('username', username)
        .maybeSingle();
    return row != null && row['id'] != myId;
  }

  Future<void> setUsername(String username) {
    return _client.rpc('set_username', params: {'p_username': username});
  }

  /// Sets (or, when empty, clears) the nickname everyone sees.
  Future<void> setNickname(String nickname) {
    return _client.rpc('set_nickname', params: {'p_name': nickname});
  }

  /// Deletes every file in [userId]'s avatar folder except [keep]. Storage
  /// RLS only lets a user list/delete under their own uid, so this can
  /// never touch anyone else's photo.
  Future<void> _clearAvatarFolder(String userId, {String? keep}) async {
    final existing = await _client.storage.from('avatars').list(path: userId);
    final stale = existing.where((f) => f.name != keep).toList();
    if (stale.isEmpty) return;
    await _client.storage
        .from('avatars')
        .remove(stale.map((f) => '$userId/${f.name}').toList());
  }

  /// Replaces [userId]'s photo: uploads [bytes], points their profile at
  /// the new file, then deletes any older avatar files. `upsert` alone only
  /// overwrites an object at the *same* path, so a `.png` followed by a
  /// `.jpg` would otherwise leave the old one behind forever.
  ///
  /// Old files are removed last on purpose: if the upload fails, the
  /// user's current photo is still intact, and the profile never points at
  /// a file that has already been deleted.
  Future<void> replaceAvatarPhoto({
    required String userId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final ext = fileExtension.toLowerCase() == 'jpeg'
        ? 'jpg'
        : fileExtension.toLowerCase();
    final contentType = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      _ => 'image/jpeg',
    };

    final fileName = 'avatar.$ext';
    final path = '$userId/$fileName';
    await _client.storage
        .from('avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );
    final url = _client.storage.from('avatars').getPublicUrl(path);
    // Cache-busting param: re-uploading the same extension reuses the same
    // path, which image caches would otherwise keep serving stale.
    await _client.rpc(
      'set_avatar_url',
      params: {
        'p_avatar_url': '$url?t=${DateTime.now().millisecondsSinceEpoch}',
      },
    );

    await _clearAvatarFolder(userId, keep: fileName);
  }

  /// Switches to (or between) a generated character avatar — see
  /// GeneratedAvatar for what each kind/seed renders as. Also deletes any
  /// uploaded photo from storage, since the profile will no longer point at
  /// it and it would otherwise sit there orphaned.
  Future<void> useGeneratedAvatar({
    required String userId,
    required String kind,
    required int seed,
  }) async {
    await _client.rpc(
      'set_generated_avatar',
      params: {'p_kind': kind, 'p_seed': seed},
    );
    await _clearAvatarFolder(userId);
  }
}
