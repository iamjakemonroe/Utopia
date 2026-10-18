import '../../../core/theme/utopia_themes.dart';
import '../../auras/domain/aura.dart';

/// Something an event gives away free: a world or a frame, earned by
/// finishing [games] games and coming by on [days] different days while the
/// event is on. Kept for good, and usable whenever its season comes round.
class EventReward {
  const EventReward({
    required this.itemId,
    required this.isWorld,
    required this.games,
    required this.days,
    required this.earned,
  });

  final String itemId;
  final bool isWorld;
  final int games;
  final int days;
  final bool earned;

  String get name => isWorld
      ? UtopiaThemes.byId(itemId).name
      : Aura.byId(itemId)?.name ?? itemId;

  static EventReward fromJson(Map<String, dynamic> json) => EventReward(
    itemId: json['item_id'] as String,
    isWorld: json['kind'] == 'world',
    games: (json['games'] as num?)?.toInt() ?? 0,
    days: (json['days'] as num?)?.toInt() ?? 0,
    earned: json['earned'] == true,
  );
}

/// An event that's on now (Halloween), with the player's progress in it.
class GameEvent {
  const GameEvent({
    required this.id,
    required this.season,
    required this.title,
    required this.endsAt,
    required this.games,
    required this.days,
    required this.rewards,
  });

  final String id;
  final String season;
  final String title;
  final DateTime endsAt;

  /// Games finished, and different days come by, during the event.
  final int games;
  final int days;
  final List<EventReward> rewards;

  /// The next thing to earn, if any are left.
  EventReward? get next => rewards.where((r) => !r.earned).firstOrNull;

  bool get allEarned => rewards.every((r) => r.earned);

  /// "6 days left", "Last day".
  String get timeLeft {
    final left = endsAt.difference(DateTime.now());
    if (left.inHours < 24) return 'Last day';
    final days = left.inDays;
    return '$days day${days == 1 ? '' : 's'} left';
  }

  static GameEvent fromJson(Map<String, dynamic> json) => GameEvent(
    id: json['id'] as String,
    season: json['season'] as String,
    title: json['title'] as String,
    endsAt: DateTime.parse(json['ends_at'] as String).toLocal(),
    games: (json['games'] as num?)?.toInt() ?? 0,
    days: (json['days'] as num?)?.toInt() ?? 0,
    rewards: [
      for (final r in (json['rewards'] as List? ?? const []))
        EventReward.fromJson(Map<String, dynamic>.from(r as Map)),
    ],
  );
}

/// What the server says after a visit or a game: the events on now, and
/// anything that was just earned.
class EventStatus {
  const EventStatus({required this.events, required this.earnedNow});

  final List<GameEvent> events;
  final List<String> earnedNow;

  static EventStatus fromJson(Map<String, dynamic> json) => EventStatus(
    events: [
      for (final e in (json['events'] as List? ?? const []))
        GameEvent.fromJson(Map<String, dynamic>.from(e as Map)),
    ],
    earnedNow: [
      for (final id in (json['earned_now'] as List? ?? const [])) id as String,
    ],
  );
}
