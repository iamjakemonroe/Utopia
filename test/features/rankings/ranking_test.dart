import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/rankings/domain/ranking.dart';

void main() {
  test('everyone starts in Bronze, and tiers climb with the rating', () {
    expect(RankTier.of(1000), RankTier.bronze);
    expect(RankTier.of(100), RankTier.bronze);
    expect(RankTier.of(1100), RankTier.silver);
    expect(RankTier.of(1299), RankTier.silver);
    expect(RankTier.of(1300), RankTier.gold);
    expect(RankTier.of(1500), RankTier.diamond);
    expect(RankTier.of(2400), RankTier.legend);
    expect(RankTier.bronze.next, RankTier.silver);
    expect(RankTier.legend.next, isNull);
  });

  test('a board reads the top players and where I stand', () {
    final board = Leaderboard.fromJson({
      'top': [
        {
          'place': 1,
          'id': 'a',
          'display_name': 'Ada',
          'rating': 1240,
          'games': 9,
        },
      ],
      'me': {'place': null, 'rating': 1012, 'games': 2},
    });
    expect(board.top.single.userId, 'a');
    expect(board.top.single.profile['display_name'], 'Ada');
    expect(board.top.single.rating, 1240);
    expect(board.myPlace, isNull);
    expect(board.myRating, 1012);
    expect(board.gamesToGo, kGamesToRank - 2);
  });

  test('a new player has the starting rating and every game to go', () {
    final board = Leaderboard.fromJson({'top': [], 'me': {}});
    expect(board.myRating, 1000);
    expect(board.gamesToGo, kGamesToRank);
  });

  test('rating changes read as +n, -n or ±0', () {
    expect(const RatingChange(1000, 1020).label, '+20');
    expect(const RatingChange(1000, 988).label, '-12');
    expect(const RatingChange(1000, 1000).label, '±0');
  });
}
