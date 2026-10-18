import 'dart:ui';

/// Players are ranked once they've played this many rated games.
const kGamesToRank = 5;

/// The games with a rating: online chess and checkers.
const rankedGames = ['chess', 'checkers'];

/// Where a rating sits, from Bronze (everyone starts at 1000) to Legend.
enum RankTier {
  bronze('Bronze', 0, Color(0xFFD9935A)),
  silver('Silver', 1100, Color(0xFFCAD5E6)),
  gold('Gold', 1300, Color(0xFFFFC94D)),
  diamond('Diamond', 1500, Color(0xFF6FE3FF)),
  legend('Legend', 1700, Color(0xFFC490FF));

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
  });

  factory BoardEntry.fromJson(Map<String, dynamic> json) => BoardEntry(
    place: (json['place'] as num).toInt(),
    userId: json['id'] as String,
    profile: json,
    rating: (json['rating'] as num).toInt(),
    games: (json['games'] as num).toInt(),
  );

  final int place;
  final String userId;

  /// Their name and avatar, the way a profile row has them.
  final Map<String, dynamic> profile;
  final int rating;
  final int games;
}

/// A game's board: the top players, and where this player stands.
class Leaderboard {
  const Leaderboard({
    required this.top,
    required this.myPlace,
    required this.myRating,
    required this.myGames,
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
    );
  }

  final List<BoardEntry> top;

  /// Null until they've played [kGamesToRank] rated games.
  final int? myPlace;
  final int myRating;
  final int myGames;

  /// Rated games still to play before they're ranked.
  int get gamesToGo => (kGamesToRank - myGames).clamp(0, kGamesToRank);
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
