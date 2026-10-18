import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/game_event.dart';

/// Events on the server: a visit counts the day (and brings back what the
/// player earned in this season before), a finished game counts toward the
/// rewards. Both say what's on and what was just earned.
class EventsRepository {
  EventsRepository(this._client);

  final SupabaseClient _client;

  Future<EventStatus> visit() async =>
      _status(await _client.rpc('event_visit'));

  /// [game]: 'chess', 'checkers', 'ludo' or 'doodle'. [matchId] for an
  /// online game (checked and counted once); none for one on this phone.
  Future<EventStatus> countGame(String game, {String? matchId}) async =>
      _status(
        await _client.rpc(
          'event_count_game',
          params: {'p_game': game, 'p_match': ?matchId},
        ),
      );

  /// Every event item the player has earned (any season, in or out).
  Future<List<SeasonItem>> seasonItems() async {
    final rows = await _client
        .from('season_items')
        .select('item_id, kind, season');
    return [
      for (final r in rows)
        SeasonItem(
          itemId: r['item_id'] as String,
          isWorld: r['kind'] == 'world',
          season: r['season'] as String,
        ),
    ];
  }

  static EventStatus _status(Object? data) => data is Map
      ? EventStatus.fromJson(Map<String, dynamic>.from(data))
      : const EventStatus(events: [], earnedNow: []);
}

final eventsRepositoryProvider = Provider<EventsRepository>(
  (ref) => EventsRepository(ref.watch(supabaseClientProvider)),
);

/// The player's earned event items, for their collection.
final seasonItemsProvider = FutureProvider.autoDispose<List<SeasonItem>>((
  ref,
) async {
  try {
    return await ref.watch(eventsRepositoryProvider).seasonItems();
  } catch (_) {
    return const [];
  }
});
