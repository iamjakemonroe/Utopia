import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/coins/data/coin_repository.dart';
import 'package:utopia/features/coins/presentation/daily_reward_sheet.dart';
import 'package:utopia/features/coins/presentation/providers/coin_balance_provider.dart';

class _FakeCoins implements CoinRepository {
  int claims = 0;

  @override
  Future<({int coins, int streak})> claimDailyReward() async {
    claims++;
    return (coins: 1000, streak: 3);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('claiming adds the coins and shows them', (tester) async {
    final coins = _FakeCoins();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [coinRepositoryProvider.overrideWithValue(coins)],
        child: const MaterialApp(
          home: Scaffold(body: DailyRewardSheet(streak: 3, coins: 1000)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Day 3 in a row. Keep it going!'), findsOneWidget);
    expect(find.text('Claim 1,000 coins'), findsOneWidget);

    await tester.tap(find.text('Claim 1,000 coins'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(coins.claims, 1);
    expect(find.text('+1,000'), findsOneWidget);
    // A second tap does nothing: one claim a day.
    await tester.pump(const Duration(seconds: 3));
    expect(coins.claims, 1);
  });
}
