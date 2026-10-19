import 'dart:ui';

/// Players are ranked once they've played this many rated games.
const kGamesToRank = 5;

/// The games with a rating: online chess and checkers, and public Guess My
/// Doodle games.
const rankedGames = ['chess', 'checkers', 'doodle'];

/// A ranked game's name.
String rankedGameName(String game) => switch (game) {
  'checkers' => 'Checkers',
  'doodle' => 'Doodle',
  _ => 'Chess',
};

/// Where a ranked game is played online.
String rankedGameRoute(String game) =>
    game == 'doodle' ? '/guess-my-doodle' : '/$game';

/// Where a rating sits, from Bronze (everyone starts at 1000) to Legend.
enum RankTier {
  bronze('Bronze', 0, Color(0xFFD9935A)),
  silver('Silver', 1100, Color(0xFFCAD5E6)),
  gold('Gold', 1300, Color(0xFFFFC94D)),
  diamond('Diamond', 1500, Color(0xFF6FE3FF)),
  legend('Legend', 1700, Color(0xFFFF1F3D));

  const RankTier(this.label, this.from, this.color);

  final String label;

  /// The lowest rating in this tier.
  final int from;
  final Color color;

  static RankTier of(int rating) =>
      values.lastWhere((t) => rating >= t.from, orElse: () => bronze);

  /// The tier above, or null at the top.
  RankTier? get next => index + 1 < values.length ? values[index + 1] : null;
}

/// One row on the board: a player, their place and rating.
class BoardEntry {
  const BoardEntry({
    required this.place,
    required this.userId,
    required this.profile,
    required this.rating,
    required this.games,
    this.house = false,
  });

  factory BoardEntry.fromJson(Map<String, dynamic> json) => BoardEntry(
    place: (json['place'] as num).toInt(),
    userId: json['id'] as String,
    profile: json,
    rating: (json['rating'] as num).toInt(),
    games: (json['games'] as num).toInt(),
    house: json['house'] == true,
  );

  final int place;
  final String userId;

  /// Their name and avatar, the way a profile row has them.
  final Map<String, dynamic> profile;
  final int rating;
  final int games;

  /// One of Utopia's house players (they fill a board while it's new, and
  /// never win prizes): tagged "House" wherever they're shown.
  final bool house;
}

/// A game's board: the top players, and where this player stands.
class Leaderboard {
  const Leaderboard({
    required this.top,
    required this.myPlace,
    required this.myRating,
    required this.myGames,
    this.hasMore = false,
  });

  factory Leaderboard.fromJson(Map<String, dynamic> json) {
    final me = Map<String, dynamic>.from(json['me'] as Map? ?? const {});
    return Leaderboard(
      top: [
        for (final row in json['top'] as List? ?? const [])
          BoardEntry.fromJson(Map<String, dynamic>.from(row as Map)),
      ],
      myPlace: (me['place'] as num?)?.toInt(),
      myRating: (me['rating'] as num?)?.toInt() ?? 1000,
      myGames: (me['games'] as num?)?.toInt() ?? 0,
      hasMore: json['more'] == true,
    );
  }

  /// One page of the board (the top 100, a page at a time).
  final List<BoardEntry> top;

  /// Whether there are more places after this page.
  final bool hasMore;

  /// Null until they've played [kGamesToRank] rated games.
  final int? myPlace;
  final int myRating;
  final int myGames;

  /// Rated games still to play before they're ranked.
  int get gamesToGo => (kGamesToRank - myGames).clamp(0, kGamesToRank);
}

/// The player's own record in a game.
class PlayerRecord {
  const PlayerRecord({
    required this.rating,
    required this.best,
    required this.games,
    required this.wins,
    required this.losses,
    required this.draws,
  });

  factory PlayerRecord.fromJson(Map<String, dynamic> json) {
    int n(String key) => (json[key] as num?)?.toInt() ?? 0;
    return PlayerRecord(
      rating: n('rating'),
      best: n('best'),
      games: n('games'),
      wins: n('wins'),
      losses: n('losses'),
      draws: n('draws'),
    );
  }

  final int rating;
  final int best;
  final int games;
  final int wins;
  final int losses;
  final int draws;
}

/// One rated game's change, and when.
class RatingStep {
  const RatingStep(this.change, this.at);

  final RatingChange change;
  final DateTime at;
}

/// The rating over [steps] (oldest first): where it started, then after
/// each game.
List<int> ratingLine(List<RatingStep> steps) => [
  if (steps.isNotEmpty) steps.first.change.before,
  for (final s in steps) s.change.after,
];

/// How far the rating moved in the week before [now].
int weekChange(List<RatingStep> steps, DateTime now) => steps
    .where((s) => now.difference(s.at) < const Duration(days: 7))
    .fold(0, (sum, s) => sum + s.change.delta);

/// Where [rating] sits along the tiers, 0 (bottom of Bronze's band) to 1
/// (Legend), each tier an equal share.
double ladderPosition(int rating) {
  final tiers = RankTier.values;
  final tier = RankTier.of(rating);
  final next = tier.next;
  final low = tier == RankTier.bronze ? 900 : tier.from;
  if (next == null) return 1;
  final within = ((rating - low) / (next.from - low)).clamp(0.0, 1.0);
  return (tier.index + within) / (tiers.length - 1);
}

/// How one match moved a player's rating.
class RatingChange {
  const RatingChange(this.before, this.after);

  final int before;
  final int after;

  int get delta => after - before;

  /// "+12", "-8", "±0".
  String get label => delta > 0
      ? '+$delta'
      : delta < 0
      ? '$delta'
      : '±0';
}
