/// Someone in a player's insights: their best win, their rival, their
/// nemesis (the profile fields a row needs, plus what's said of them).
class InsightPerson {
  const InsightPerson(this.profile);

  final Map<String, dynamic> profile;

  String get id => profile['id'] as String? ?? '';
  bool get house => profile['house'] == true;
  int _n(String key) => (profile[key] as num?)?.toInt() ?? 0;

  /// Their rating when they were beaten (best win).
  int get rating => _n('rating');
  int get games => _n('games');
  int get wins => _n('wins');
  int get losses => _n('losses');

  static InsightPerson? from(Object? json) =>
      json is Map ? InsightPerson(Map<String, dynamic>.from(json)) : null;
}

/// Everything worth knowing from a player's games in a ranked game (the
/// server's get_rank_insights), for the hologram.
class RankInsights {
  const RankInsights(this._json);

  factory RankInsights.fromJson(Map<String, dynamic> json) =>
      RankInsights(json);

  final Map<String, dynamic> _json;

  /// Someone else's, who keeps their stats to themselves: nothing else.
  bool get hidden => _json['hidden'] == true;

  int _n(String key) => (_json[key] as num?)?.toInt() ?? 0;
  int? _maybe(String key) => (_json[key] as num?)?.toInt();
  DateTime? _at(String key) =>
      DateTime.tryParse(_json[key] as String? ?? '')?.toLocal();
  Map<String, int> _counts(String key) => {
    for (final e in (_json[key] as Map? ?? const {}).entries)
      e.key as String: (e.value as num).toInt(),
  };

  String get game => _json['game'] as String? ?? 'chess';
  bool get boardGame => game != 'doodle';

  int get rating => _n('rating');
  int get best => _n('best');
  DateTime? get peakAt => _at('peak_at');
  DateTime? get since => _at('since');
  int get games => _n('games');
  int get wins => _n('wins');
  int get losses => _n('losses');
  int get draws => _n('draws');

  /// Won, of decided and drawn games: 0 to 1.
  double get winRate => games == 0 ? 0 : wins / games;

  int get week => _n('week');
  int get month => _n('month');
  int get gamesThisWeek => _n('games_week');
  int get biggestGain => _n('biggest_gain');
  int get biggestDrop => _n('biggest_drop');

  /// Where they sit among the real ranked players (null until ranked).
  int? get topPercent => _maybe('top_percent');
  int? get ranked => _maybe('ranked');

  /// Now: [streak] games in a row of [streakKind] ('W', 'L' or 'D').
  int get streak => _n('streak');
  String? get streakKind => _json['streak_kind'] as String?;
  int get bestStreak => _n('best_streak');

  // Chess and checkers only.

  ({int games, int wins}) side(String key) {
    final m = _json[key] as Map? ?? const {};
    return (
      games: (m['games'] as num?)?.toInt() ?? 0,
      wins: (m['wins'] as num?)?.toInt() ?? 0,
    );
  }

  /// As white (checkers: dark, which moves first).
  ({int games, int wins}) get asWhite => side('white');
  ({int games, int wins}) get asBlack => side('black');
  int? get averageMoves => _maybe('avg_moves');
  int? get fastestWin => _maybe('fastest_win');
  int? get averageOpponent => _maybe('avg_opponent');

  /// Their usual clock, as minutes+increment ("10+0").
  String? get clock => _json['clock'] as String?;

  /// How their games were won and lost, by result ('checkmate', ...).
  Map<String, int> get winsBy => _counts('wins_by');
  Map<String, int> get lossesBy => _counts('losses_by');

  InsightPerson? get bestWin => InsightPerson.from(_json['best_win']);
  InsightPerson? get rival => InsightPerson.from(_json['rival']);
  InsightPerson? get nemesis => InsightPerson.from(_json['nemesis']);
}
