import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/events/domain/game_event.dart';
import 'package:utopia/features/events/presentation/events_controller.dart';

GameEvent _event(String season, {required bool frame, required bool world}) =>
    GameEvent(
      id: '${season}_2026',
      season: season,
      title: season,
      endsAt: DateTime.now().add(const Duration(days: 9)),
      games: 20,
      days: 6,
      rewards: [
        EventReward(
          itemId: 'jack',
          kind: RewardKind.aura,
          games: 10,
          days: 0,
          earned: frame,
        ),
        EventReward(
          itemId: 'utopia_halloween',
          kind: RewardKind.world,
          games: 15,
          days: 5,
          earned: world,
        ),
      ],
    );

void main() {
  test('a seasonal card stays until both its frame and world are earned', () {
    for (final (frame, world, shown) in [
      (false, false, true),
      (true, false, true),
      (false, true, true),
      (true, true, false),
    ]) {
      final state = EventsState(
        events: [_event('halloween', frame: frame, world: world)],
      );
      expect(
        state.onHome.isNotEmpty,
        shown,
        reason: 'frame $frame, world $world',
      );
    }
  });

  test('the weekly quests card stays when all are done', () {
    final state = EventsState(
      events: [_event('weekly', frame: true, world: true)],
    );
    expect(state.onHome, hasLength(1));
  });
}
