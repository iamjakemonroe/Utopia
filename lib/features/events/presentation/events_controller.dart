import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/profiles/profile_providers.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../store/presentation/store_controller.dart';
import '../data/events_repository.dart';
import '../domain/game_event.dart';

@immutable
class EventsState {
  const EventsState({this.events = const [], this.justEarned = const []});

  /// The events on now, with the player's progress.
  final List<GameEvent> events;

  /// Rewards just earned, for the celebration (cleared once shown).
  final List<EventReward> justEarned;

  EventsState copyWith({
    List<GameEvent>? events,
    List<EventReward>? justEarned,
  }) => EventsState(
    events: events ?? this.events,
    justEarned: justEarned ?? this.justEarned,
  );
}

/// The player's events: asked on arriving home, and told about every game
/// they finish. Whatever they earn is in their hands at once (the store and
/// their profile are refreshed) and celebrated.
class EventsController extends StateNotifier<EventsState> {
  EventsController(this._ref) : super(const EventsState());

  final Ref _ref;

  EventsRepository get _repo => _ref.read(eventsRepositoryProvider);

  /// The player came by: counts today and brings back last season's items.
  Future<void> visit() async {
    try {
      _take(await _repo.visit());
    } catch (_) {
      // Offline: the card just stays as it was.
    }
  }

  /// A game just finished: [game] is 'chess', 'checkers', 'ludo' or
  /// 'doodle'; [matchId] for an online one.
  Future<void> gameFinished(String game, {String? matchId}) async {
    try {
      _take(await _repo.countGame(game, matchId: matchId));
    } catch (_) {
      // Not counted (offline, or the match isn't over on the server yet).
    }
  }

  void clearEarned() => state = state.copyWith(justEarned: const []);

  void _take(EventStatus status) {
    if (!mounted) return;
    final earned = [
      for (final e in status.events)
        for (final r in e.rewards)
          if (status.earnedNow.contains(r.itemId)) r,
    ];
    state = state.copyWith(
      events: status.events,
      justEarned: earned.isEmpty ? null : earned,
    );
    if (earned.isNotEmpty) {
      _ref.read(storeControllerProvider.notifier).refresh();
      final me = _ref.read(currentUserProvider)?.id;
      if (me != null) _ref.invalidate(profileByIdProvider(me));
    }
  }
}

/// Rebuilt when the signed-in player changes.
final eventsProvider = StateNotifierProvider<EventsController, EventsState>((
  ref,
) {
  ref.watch(currentUserProvider.select((u) => u?.id));
  return EventsController(ref);
});
