import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/pool/domain/pool_cues.dart';

int _sum(CueStats s) => s.power + s.aim + s.spin;

void main() {
  test('every cue gets better with every level, and stays within 0 to 100', () {
    for (final cue in kPoolCues) {
      var last = cue.at(1);
      expect(last, cue.first, reason: cue.id);
      for (var level = 2; level <= cue.maxLevel; level++) {
        final now = cue.at(level);
        expect(
          now.power >= last.power &&
              now.aim >= last.aim &&
              now.spin >= last.spin,
          isTrue,
          reason: '${cue.id} at $level',
        );
        expect(
          _sum(now),
          greaterThan(_sum(last)),
          reason: '${cue.id} at $level',
        );
        last = now;
      }
      expect(last, cue.best, reason: cue.id);
      for (final v in [cue.best.power, cue.best.aim, cue.best.spin]) {
        expect(v, inInclusiveRange(0, 100), reason: cue.id);
      }
    }
  });

  test(
    'regular cues stop at 5, animated ones at 10, and each tier tops the last',
    () {
      for (final cue in kPoolCues) {
        expect(cue.maxLevel, cue.animated ? 10 : 5, reason: cue.id);
      }
      int best(CueTier tier) => kPoolCues
          .where((c) => c.tier == tier)
          .map((c) => _sum(c.best))
          .reduce((a, b) => a > b ? a : b);
      int worst(CueTier tier) => kPoolCues
          .where((c) => c.tier == tier)
          .map((c) => _sum(c.best))
          .reduce((a, b) => a < b ? a : b);
      for (var i = 1; i < CueTier.values.length; i++) {
        expect(
          worst(CueTier.values[i]),
          greaterThan(best(CueTier.values[i - 1])),
          reason: CueTier.values[i].name,
        );
      }
    },
  );

  test(
    'rarer cues cost more, and a regular one is priced like a chess set',
    () {
      int cheapest(CueTier t) => kPoolCues
          .where((c) => c.tier == t)
          .map((c) => c.price)
          .reduce((a, b) => a < b ? a : b);
      int dearest(CueTier t) => kPoolCues
          .where((c) => c.tier == t)
          .map((c) => c.price)
          .reduce((a, b) => a > b ? a : b);
      for (var i = 1; i < CueTier.values.length; i++) {
        expect(
          cheapest(CueTier.values[i]),
          greaterThan(dearest(CueTier.values[i - 1])),
        );
      }
      expect(kPoolCues.where((c) => c.free).map((c) => c.id), [kStarterCue]);
      // The chess and Ludo sets go for 40,000 to 50,000.
      expect(dearest(CueTier.regular), 40000);
      expect(cheapest(CueTier.rare), 50000);
    },
  );

  test('upgrades climb, and cost more the rarer the cue', () {
    for (final tier in CueTier.values) {
      final costs = [
        for (var l = 1; l < tier.maxLevel; l++) cueUpgradeCost(tier, l)!,
      ];
      for (var i = 1; i < costs.length; i++) {
        expect(costs[i], greaterThan(costs[i - 1]));
      }
      expect(cueUpgradeCost(tier, tier.maxLevel), isNull);
      expect(cueUpgradeCost(tier, 0), isNull);
    }
    for (var l = 1; l < 10; l++) {
      expect(
        cueUpgradeCost(CueTier.epic, l)!,
        greaterThan(cueUpgradeCost(CueTier.rare, l)!),
      );
      expect(
        cueUpgradeCost(CueTier.mythic, l)!,
        greaterThan(cueUpgradeCost(CueTier.legendary, l)!),
      );
    }
  });

  test('stats turn into play within the table\'s limits', () {
    const none = CueStats(0, 0, 0), full = CueStats(100, 100, 100);
    expect(none.maxSpeed, closeTo(5.6, 1e-9));
    expect(full.maxSpeed, closeTo(7.6, 1e-9));
    expect(none.tipOffset, closeTo(0.3, 1e-9));
    expect(full.tipOffset, closeTo(0.65, 1e-9));
    expect(full.guideReach, greaterThan(none.guideReach));
    expect(const CueStats(69, 69, 0).guideBounce, isFalse);
    expect(const CueStats(0, 70, 0).guideBounce, isTrue);
  });

  test(
    'the database sells, levels and charges for the cues as this file says',
    () {
      final sql = File(
        'supabase/migrations/20261028120000_pool.sql',
      ).readAsStringSync();
      final tiers = {
        for (final m in RegExp(
          r"\('(cue_[a-z]+)', '([a-z]+)', \d+\)",
        ).allMatches(sql))
          m[1]!: m[2]!,
      };
      final prices = {
        for (final m in RegExp(
          r"\('utopia\.cue\.[a-z]+', array\['(cue_[a-z]+)'\], (\d+), \d+\)",
        ).allMatches(sql))
          m[1]!: int.parse(m[2]!),
      };
      expect(tiers.length, kPoolCues.length);
      for (final cue in kPoolCues) {
        expect(tiers[cue.id], cue.tier.name, reason: cue.id);
        expect(prices[cue.id], cue.free ? null : cue.price, reason: cue.id);
        expect(cue.productId, 'utopia.cue.${cue.id.substring(4)}');
      }
      // The upgrade costs: the same steps and the same rarer-is-dearer.
      expect(sql, contains('(array[2000, 4000, 7000, 12000])[p_level]'));
      expect(
        sql,
        contains(
          '(array[3000, 5000, 8000, 12000, 17000, 23000, 30000, 40000, 50000])[p_level]',
        ),
      );
      expect(
        sql,
        contains(
          "when 'rare' then 4 when 'epic' then 5 when 'legendary' then 6 else 8",
        ),
      );
    },
  );
}
