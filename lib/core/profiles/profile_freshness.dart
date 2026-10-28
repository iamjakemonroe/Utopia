import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bots/bots.dart';
import '../supabase/supabase_providers.dart';
import 'profile_providers.dart';

/// Keeps other players' profiles (names, avatars, piece sets, auras) from
/// going stale. Profiles are cached for the session, so without this a
/// player who equips a new piece set keeps showing their old one.
///
/// Three triggers, cheapest first:
///   * A game opening refreshes everyone in it ([liveProfilesProvider]).
///   * While a game is open, the players' profile rows are watched live,
///     and one is refetched only when something people can see changed
///     (a coin balance moving after a game doesn't count).
///   * Coming back to the app after a while refreshes every cached
///     profile ([profileFreshnessProvider]).

/// The columns other players can see. A change to any of these refreshes
/// the cached profile.
const _visibleColumns = [
  'display_name',
  'username',
  'avatar_url',
  'avatar_kind',
  'avatar_seed',
  'equipped_theme',
  'equipped_ludo_pieces',
  'equipped_chess_pieces',
  'equipped_pool_cue',
  'equipped_aura',
  'aura_expires_at',
];

/// A stable key for a set of player ids, for [liveProfilesProvider].
String liveProfilesKey(Iterable<String?> ids) =>
    (ids
            .whereType<String>()
            .where((id) => !isOfflinePlayerId(id))
            .toSet()
            .toList()
          ..sort())
        .join(',');

/// Watch with [liveProfilesKey] of the players on screen (a game, a room).
final liveProfilesProvider = Provider.autoDispose.family<void, String>((
  ref,
  key,
) {
  final ids = [
    for (final id in key.split(','))
      if (id.isNotEmpty) id,
  ];
  if (ids.isEmpty) return;

  var alive = true;
  ref.onDispose(() => alive = false);

  // Fresh at the start: anything cached earlier this session may be old.
  // (After this build, so nothing changes while widgets are building.)
  scheduleMicrotask(() {
    if (!alive) return;
    for (final id in ids) {
      ref.invalidate(profileByIdProvider(id));
    }
  });

  final client = ref.watch(supabaseClientProvider);
  final channel = client
      .channel('profiles-live-${key.hashCode}')
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'profiles',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.inFilter,
          column: 'id',
          value: ids,
        ),
        callback: (payload) {
          final row = payload.newRecord;
          final id = row['id'] as String?;
          if (id == null || !alive) return;
          final cached = ref.read(profileByIdProvider(id)).valueOrNull;
          final changed =
              cached == null ||
              _visibleColumns.any((c) => '${row[c]}' != '${cached[c]}');
          if (changed) ref.invalidate(profileByIdProvider(id));
        },
      )
      .subscribe();
  ref.onDispose(() => client.removeChannel(channel));
});

/// Watched once at the app's root: coming back to the app after a minute
/// or more away refreshes every cached profile (only the ones on screen
/// actually refetch).
final profileFreshnessProvider = Provider<void>((ref) {
  DateTime? leftAt;
  final listener = AppLifecycleListener(
    onHide: () => leftAt = DateTime.now(),
    onShow: () {
      final away = leftAt == null
          ? Duration.zero
          : DateTime.now().difference(leftAt!);
      leftAt = null;
      if (away >= const Duration(minutes: 1)) {
        ref.invalidate(profileByIdProvider);
      }
    },
  );
  ref.onDispose(listener.dispose);
});
