import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/store/domain/store_catalog.dart';

double _dollars(String price) => double.parse(price.replaceFirst(r'$', ''));

void main() {
  final all = [StoreCatalog.starterPack, ...StoreCatalog.coinPacks];

  test('the app shows the coins the server pays for each pack', () {
    final sql = File(
      'supabase/migrations/20261014110000_real_coin_top_ups.sql',
    ).readAsStringSync();
    final server = {
      for (final m in RegExp(
        r"\('(utopia\.coins\.\w+)', (\d+), \d+\)",
      ).allMatches(sql))
        m.group(1)!: int.parse(m.group(2)!),
    };
    expect(server, {for (final p in all) p.id: p.coins});
  });

  test('each bonus is what the pack gives over 10,000 coins a dollar', () {
    for (final p in all) {
      final base = _dollars(p.fallbackPrice) * 10000;
      final bonus = (p.coins / base - 1) * 100;
      expect(
        (bonus - p.bonusPercent).abs(),
        lessThan(2.1),
        reason: '${p.name}: +${bonus.toStringAsFixed(1)}%',
      );
    }
  });

  test('every pack has its own id and picture, growing with its size', () {
    expect(StoreCatalog.coinProductIds.length, all.length);
    final arts = [for (final p in StoreCatalog.coinPacks) p.art];
    expect(arts, List.generate(arts.length, (i) => i));
    for (var i = 1; i < StoreCatalog.coinPacks.length; i++) {
      expect(
        StoreCatalog.coinPacks[i].coins,
        greaterThan(StoreCatalog.coinPacks[i - 1].coins),
      );
    }
  });
}
