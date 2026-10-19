// Phone screenshots of the rank hologram in each tier, into
// test/tool/goldens/. Run:
// flutter test --run-skipped --update-goldens test/tool/hologram_sheet_test.dart
@Tags(['sheet'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia/core/theme/app_theme.dart';
import 'package:utopia/core/theme/theme_controller.dart';
import 'package:utopia/core/widgets/app_background.dart';
import 'package:utopia/features/rankings/data/rankings_repository.dart';
import 'package:utopia/features/rankings/domain/rank_insights.dart';
import 'package:utopia/features/rankings/presentation/hologram/rank_hologram.dart';

RankInsights _insights(int rating) => RankInsights.fromJson({
  'game': 'chess',
  'rating': rating,
  'best': rating + 24,
  'peak_at': '2026-10-17T19:20:00Z',
  'since': '2026-10-02T10:00:00Z',
  'games': 64,
  'wins': 37,
  'losses': 22,
  'draws': 5,
  'week': 46,
  'month': 131,
  'games_week': 11,
  'biggest_gain': 31,
  'biggest_drop': -24,
  'ranked': 412,
  'top_percent': rating > 1700 ? 1 : (1900 - rating) ~/ 30,
  'streak': 4,
  'streak_kind': 'W',
  'best_streak': 7,
  'white': {'games': 33, 'wins': 21},
  'black': {'games': 31, 'wins': 16},
  'avg_moves': 34,
  'fastest_win': 11,
  'avg_opponent': rating - 40,
  'clock': '10+0',
  'wins_by': {'checkmate': 19, 'resignation': 12, 'timeout': 6},
  'losses_by': {'checkmate': 9, 'timeout': 8, 'resignation': 5},
  'best_win': {
    'id': 'a',
    'display_name': 'Amara',
    'avatar_kind': 'human',
    'avatar_seed': 3,
    'rating': rating + 180,
  },
  'rival': {
    'id': 'k',
    'display_name': 'Kofi',
    'avatar_kind': 'animal',
    'avatar_seed': 7,
    'games': 9,
    'wins': 5,
    'losses': 4,
  },
  'nemesis': {
    'id': 'l',
    'display_name': 'Lena',
    'avatar_kind': 'plant',
    'avatar_seed': 2,
    'losses': 4,
  },
});

Future<void> _hologram(WidgetTester tester, int rating, String name) async {
  tester.view.physicalSize = const Size(1290, 2796);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'sound.sfx': false});
  final prefs = await SharedPreferences.getInstance();
  late BuildContext host;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        rankInsightsProvider.overrideWith(
          (ref, game) async => _insights(rating),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: Scaffold(
          body: AppBackground(
            child: Builder(
              builder: (context) {
                host = context;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.runAsync(() async {
    final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
    final icons = File(
      '${artifacts.path}/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytesSync();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.sublistView(icons)))).load();
    await GoogleFonts.pendingFonts();
  });
  showRankHologram(
    host,
    game: 'chess',
    rating: rating,
    place: 12,
    line: [for (var i = 0; i < 24; i++) rating - 140 + i * 6 + (i % 4) * 9],
  );
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/hologram_$name.png'),
  );
  // Gone, so its tickers stop.
  await tester.pumpWidget(const SizedBox());
}

void main() {
  for (final (rating, name) in [
    (1050, 'bronze'),
    (1200, 'silver'),
    (1400, 'gold'),
    (1600, 'diamond'),
    (1800, 'legend'),
  ]) {
    testWidgets('hologram, $name', (tester) => _hologram(tester, rating, name));
  }
}
