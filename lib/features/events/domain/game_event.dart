import '../../../core/theme/utopia_themes.dart';
import '../../../core/widgets/utopia_icons.dart' show formatCoins;
import '../../auras/domain/aura.dart';
import '../../../l10n/strings.dart';

/// What an event gives: a world or a frame (kept for good, usable whenever
/// its season comes round), or coins (a week's quests).
enum RewardKind { world, aura, coins }

/// Something an event gives away free, earned by finishing [games] games
/// and coming by on [days] different days while the event is on.
class EventReward {
  const EventReward({
    required this.itemId,
    required this.kind,
    required this.games,
    required this.days,
    required this.earned,
    this.coins = 0,
  });

  final String itemId;
  final RewardKind kind;
  final int games;
  final int days;
  final bool earned;

  /// For [RewardKind.coins]: how many.
  final int coins;

  bool get isWorld => kind == RewardKind.world;
  bool get isCoins => kind == RewardKind.coins;

  String get name => switch (kind) {
    RewardKind.world => UtopiaThemes.byId(itemId).name,
    RewardKind.aura => Aura.byId(itemId)?.name ?? itemId,
    RewardKind.coins => '${formatCoins(coins)} coins',
  };

  static EventReward fromJson(Map<String, dynamic> json) => EventReward(
    itemId: json['item_id'] as String,
    kind: switch (json['kind']) {
      'world' => RewardKind.world,
      'coins' => RewardKind.coins,
      _ => RewardKind.aura,
    },
    games: (json['games'] as num?)?.toInt() ?? 0,
    days: (json['days'] as num?)?.toInt() ?? 0,
    coins: (json['coins'] as num?)?.toInt() ?? 0,
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

  /// The week's quests (coins), rather than a seasonal event.
  bool get isWeekly => season == 'weekly';

  bool get allEarned => rewards.every((r) => r.earned);

  /// "6 days left", "Last day".
  String get timeLeft {
    final left = endsAt.difference(DateTime.now());
    if (left.inHours < 24) return strings.gameEventLastDay;
    final days = left.inDays;
    return strings.gameEventDayLeft(days, days == 1 ? '' : 's');
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

/// An event item the player earned: theirs for good, usable while an event
/// of its [season] is on.
class SeasonItem {
  const SeasonItem({
    required this.itemId,
    required this.isWorld,
    required this.season,
  });

  final String itemId;
  final bool isWorld;
  final String season;

  /// "Halloween".
  String get seasonName =>
      season.isEmpty ? season : season[0].toUpperCase() + season.substring(1);
}
