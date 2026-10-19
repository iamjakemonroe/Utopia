import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia/core/theme/app_theme.dart';
import 'package:utopia/core/theme/theme_controller.dart';
import 'package:utopia/features/auth/presentation/providers/auth_providers.dart';
import 'package:utopia/features/rankings/data/rankings_repository.dart';
import 'package:utopia/features/rankings/domain/ranking.dart';
import 'package:utopia/features/rankings/presentation/rankings_screen.dart';

/// A board of [total] players, served a page at a time.
class _Board implements RankingsRepository {
  _Board(this.total);

  final int total;
  final asked = <int>[];

  @override
  Future<Leaderboard> leaderboard(
    String game, {
    bool friends = false,
    int offset = 0,
    int limit = kBoardPage,
  }) async {
    asked.add(offset);
    final end = (offset + limit).clamp(0, total);
    return Leaderboard(
      top: [
        for (var i = offset; i < end; i++)
          BoardEntry(
            place: i + 1,
            userId: 'p$i',
            profile: {'display_name': 'Player ${i + 1}', 'avatar_seed': i},
            rating: 1800 - i * 5,
            games: 20,
          ),
      ],
      myPlace: null,
      myRating: 1000,
      myGames: 0,
      hasMore: end < total,
    );
  }

  @override
  Future<PlayerRecord?> record(String game) async => null;

  @override
  Future<List<RatingStep>> history(String game, {int limit = 30}) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('the board opens on its first page and brings more on scroll', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'sound.sfx': false});
    final prefs = await SharedPreferences.getInstance();
    final board = _Board(60);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentUserProvider.overrideWithValue(null),
          rankingsRepositoryProvider.overrideWithValue(board),
        ],
        child: MaterialApp(theme: AppTheme.dark, home: const RankingsScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(board.asked, [0], reason: 'only the first page at first');

    for (var i = 0; i < 40 && !board.asked.contains(50); i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(board.asked, [0, 25, 50], reason: 'a page each time, in order');
    await tester.drag(find.byType(ListView), const Offset(0, -20000));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Player 60'), findsOneWidget, reason: 'down to the last');
    expect(board.asked, [0, 25, 50], reason: 'and no more once it says so');
  });
}
