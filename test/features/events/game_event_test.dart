import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/events/domain/game_event.dart';

void main() {
  Map<String, dynamic> status({bool jackEarned = false, int games = 6}) => {
    'counted': true,
    'earned_now': jackEarned ? ['jack'] : <String>[],
    'events': [
      {
        'id': 'halloween_2026',
        'season': 'halloween',
        'title': 'Halloween',
        'starts_at': '2026-10-15T00:00:00+00:00',
        'ends_at': DateTime.now()
            .add(const Duration(days: 6, hours: 2))
            .toUtc()
            .toIso8601String(),
        'games': games,
        'days': 2,
        'rewards': [
          {
            'item_id': 'jack',
            'kind': 'aura',
            'games': 10,
            'days': 0,
            'earned': jackEarned,
          },
          {
            'item_id': 'utopia_halloween',
            'kind': 'world',
            'games': 15,
            'days': 5,
            'earned': false,
          },
        ],
      },
    ],
  };

  test("reads the server's event status", () {
    final s = EventStatus.fromJson(status());
    final e = s.events.single;
    expect(e.title, 'Halloween');
    expect(e.games, 6);
    expect(e.timeLeft, '6 days left');
    expect(e.next?.itemId, 'jack');
    expect(e.next?.name, "Jack's Lantern");
    expect(e.rewards.last.isWorld, isTrue);
    expect(e.rewards.last.name, 'Utopia Halloween');
    expect(s.earnedNow, isEmpty);
  });

  test('once the frame is earned, the world is next', () {
    final s = EventStatus.fromJson(status(jackEarned: true, games: 10));
    expect(s.earnedNow, ['jack']);
    expect(s.events.single.next?.itemId, 'utopia_halloween');
    expect(s.events.single.allEarned, isFalse);
  });

  test('nothing on', () {
    final s = EventStatus.fromJson({'events': [], 'earned_now': []});
    expect(s.events, isEmpty);
  });
}
