// Every frame, world and Chip, held at fixed moments, so a change that
// should draw nothing differently (splitting a big file into parts) can be
// checked to the pixel. Before the change:
//   flutter test --run-skipped --update-goldens test/tool/split_check_test.dart
// After it, without --update-goldens: every image must match exactly.
@Tags(['sheet'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/core/theme/utopia_themes.dart';
import 'package:utopia/core/widgets/coin_buddy.dart';
import 'package:utopia/core/widgets/utopia_world.dart';
import 'package:utopia/core/widgets/world_sets.dart';
import 'package:utopia/features/auras/domain/aura.dart';
import 'package:utopia/features/auras/presentation/aura_frame.dart';

const _times = [0.4, 2.3, 5.1, 9.7];

final _sets = <String, SetBonus>{
  'zombie': WorldSets.zombie,
  'heaven': WorldSets.heaven,
  'hell': WorldSets.hell,
  'dragon': WorldSets.dragon,
  'music': WorldSets.music,
  'halloween': WorldSets.halloween,
  'winter': WorldSets.winter,
  'birthday': WorldSets.birthday,
  'maestro': WorldSets.maestro,
  'musicLive': WorldSets.musicLive,
};

/// Only [on] (if any) worn, the rest off, all settled.
void _wear(SetBonus? on) {
  for (final set in _sets.values) {
    set.on.value = set == on;
    set.settle();
  }
}

Future<void> _shoot(WidgetTester tester, String name) => expectLater(
  find.byKey(const ValueKey('shot')),
  matchesGoldenFile('goldens/split/$name.png'),
);

Widget _frame(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: RepaintBoundary(key: const ValueKey('shot'), child: child),
);

void main() {
  setUp(() {
    _wear(null);
    // The beat (Encore, DJ Chip) follows the worlds' clock: held too.
    debugWorldSeconds = 12.5;
  });
  tearDown(() {
    _wear(null);
    debugWorldSeconds = null;
    CoinBuddy.debugSeed = null;
  });

  // Every frame, big (blurs and all) and small (the lite version), behind
  // and in front, at four moments.
  final auras = {
    for (final a in Aura.all) a.id,
    'storm',
    'storm_white',
    'storm_blue',
    'storm_green',
    'storm_gold',
    'storm_pink',
  };
  for (final id in auras) {
    testWidgets('aura $id', (tester) async {
      tester.view.physicalSize = const Size(4 * 260, 260 + 70);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _frame(
          ColoredBox(
            color: const Color(0xFF1E1638),
            child: Row(
              children: [
                for (final t in _times)
                  SizedBox(
                    width: 260,
                    child: Column(
                      children: [
                        for (final r in const [60.0, 16.0])
                          SizedBox(
                            height: r == 60 ? 260 : 70,
                            child: Center(
                              child: CustomPaint(
                                painter: AuraPainter(
                                  id,
                                  ValueNotifier(t),
                                  front: false,
                                ),
                                foregroundPainter: AuraPainter(
                                  id,
                                  ValueNotifier(t),
                                  front: true,
                                ),
                                child: SizedBox.square(
                                  dimension: r * 2,
                                  child: const DecoratedBox(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF6FA8DC),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      await _shoot(tester, 'aura_$id');
    });
  }

  // Every world, plain and (where it has one) with its set on, at two
  // moments, and the color worlds' four lands.
  final worlds = [
    ...UtopiaThemes.utopia,
    ...UtopiaThemes.secret,
    for (final family in const ['ruby', 'jade', 'azure', 'onyx'])
      for (final shade in const ['dawn', 'dusk', 'midnight'])
        ?UtopiaThemes.find('${family}_$shade'),
  ];
  final setOf = <WorldBiome, SetBonus>{
    WorldBiome.zombie: WorldSets.zombie,
    WorldBiome.heaven: WorldSets.heaven,
    WorldBiome.hell: WorldSets.hell,
    WorldBiome.dojo: WorldSets.dragon,
    WorldBiome.music: WorldSets.music,
    WorldBiome.halloween: WorldSets.halloween,
    WorldBiome.winter: WorldSets.winter,
    WorldBiome.birthday: WorldSets.birthday,
  };
  for (final theme in worlds) {
    final set = setOf[theme.world.biome];
    for (final on in [false, if (set != null) true]) {
      testWidgets('world ${theme.id}${on ? ' set' : ''}', (tester) async {
        tester.view.physicalSize = const Size(2 * 430, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        _wear(on ? set : null);
        for (final (k, t) in const [(0, 3.3), (1, 41.7)]) {
          debugWorldSeconds = t;
          await tester.pumpWidget(
            _frame(
              SizedBox(
                width: 430,
                height: 932,
                child: UtopiaWorld(
                  key: ValueKey('${theme.id} $on $k'),
                  style: theme.world,
                ),
              ),
            ),
          );
          await tester.pump();
          await _shoot(
            tester,
            'world_${theme.id}${on ? '_set' : ''}_$k',
          );
        }
      });
    }
  }

  // Chip in every mood, then in each costume.
  for (final (name, set) in [
    ('plain', null),
    for (final e in _sets.entries) (e.key, e.value),
  ]) {
    testWidgets('chip $name', (tester) async {
      tester.view.physicalSize = const Size(1500, 3 * 180.0);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      CoinBuddy.debugSeed = 3.7;
      _wear(set);
      final moods = set == null
          ? BuddyMood.values
          : const [BuddyMood.idle, BuddyMood.happy, BuddyMood.thinking];
      await tester.pumpWidget(
        _frame(
          ColoredBox(
            color: const Color(0xFF1A1430),
            child: Wrap(
              children: [
                for (final m in moods)
                  SizedBox.square(
                    dimension: 150,
                    child: Center(child: CoinBuddy(mood: m, size: 120)),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1730));
      await _shoot(tester, 'chip_$name');
    });
  }
}
