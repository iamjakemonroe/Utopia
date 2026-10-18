// Phone screenshots of the birthday page, the event card and sheet, and
// the rankings, Chip drawing and the profile, into test/tool/goldens/. Run:
// flutter test --run-skipped --update-goldens test/tool/new_screens_sheet_test.dart
@Tags(['sheet'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia/core/theme/theme_controller.dart';
import 'package:utopia/core/theme/utopia_themes.dart';
import 'package:utopia/core/widgets/app_background.dart';
import 'package:utopia/features/auth/presentation/providers/auth_providers.dart';
import 'package:utopia/features/birthday/presentation/birthday_providers.dart';
import 'package:utopia/features/birthday/presentation/birthday_screen.dart';
import 'package:utopia/features/events/domain/game_event.dart';
import 'package:utopia/features/events/presentation/event_widgets.dart';
import 'package:utopia/features/events/presentation/events_controller.dart';
import 'package:utopia/features/guess_doodle/data/chip_doodle_repository.dart';
import 'package:utopia/features/guess_doodle/domain/chip_doodle.dart';
import 'package:utopia/features/guess_doodle/presentation/chip_doodle_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:utopia/core/profiles/profile_providers.dart';
import 'package:utopia/features/coins/presentation/providers/coin_balance_provider.dart';
import 'package:utopia/features/ludo/data/ludo_repository.dart';
import 'package:utopia/features/ludo/presentation/controllers/ludo_match_controller.dart';
import 'package:utopia/features/profile/presentation/screens/profile_screen.dart';
import 'package:utopia/features/rankings/data/rankings_repository.dart';
import 'package:utopia/features/rankings/domain/ranking.dart';
import 'package:utopia/features/rankings/presentation/rankings_screen.dart';
import 'package:utopia/features/rankings/presentation/rankings_widgets.dart';

class _Events extends EventsController {
  _Events(super.ref, List<GameEvent> events) {
    state = EventsState(events: events);
  }
}

final _halloween = GameEvent(
  id: 'halloween_2026',
  season: 'halloween',
  title: 'Halloween',
  endsAt: DateTime.now().add(const Duration(days: 14, hours: 3)),
  games: 6,
  days: 2,
  rewards: const [
    EventReward(
      itemId: 'jack',
      kind: RewardKind.aura,
      games: 10,
      days: 0,
      earned: false,
    ),
    EventReward(
      itemId: 'utopia_halloween',
      kind: RewardKind.world,
      games: 15,
      days: 5,
      earned: false,
    ),
  ],
);

/// Chip's real airplane doodle, from the deck.
class _FakeChipDoodles implements ChipDoodleRepository {
  @override
  Future<ChipDoodleRound> round() async => const ChipDoodleRound(
    word: 'airplane',
    strokes: [
      'M150 520 Q150 470 220 465 L780 455 Q860 455 880 500 Q860 545 780 545 L220 540 Q150 540 150 520',
      'M450 460 L330 200 L400 200 L560 458',
      'M450 540 L330 820 L400 820 L560 542',
      'M220 465 L170 320 L230 320 L300 463',
      'M200 538 L160 620 L210 620 L280 540',
      'M820 470 Q850 480 860 500 L800 500 Q800 480 820 470',
      'M330 490 Q330 480 340 480 Q350 480 350 490 Q350 500 340 500 Q330 500 330 490',
      'M400 490 Q400 480 410 480 Q420 480 420 490 Q420 500 410 500 Q400 500 400 490',
      'M470 490 Q470 480 480 480 Q490 480 490 490 Q490 500 480 500 Q470 500 470 490',
      'M600 180 Q620 140 660 160 Q690 120 730 155 Q770 150 760 190 Q700 200 600 180',
    ],
  );
}

final _history = [
  for (final (i, (before, after)) in const [
    (1000, 1020),
    (1020, 1041),
    (1041, 1022),
    (1022, 1060),
    (1060, 1083),
    (1083, 1070),
    (1070, 1101),
    (1101, 1124),
    (1124, 1150),
    (1150, 1139),
    (1139, 1165),
    (1165, 1188),
  ].indexed)
    RatingStep(
      RatingChange(before, after),
      DateTime.now().subtract(Duration(days: 11 - i)),
    ),
];

class _FakeLudo implements LudoRepository {
  @override
  Future<Map<String, dynamic>> playerStats(String userId) async => {
    'ludo_played': 14,
    'ludo_won': 6,
    'chess_played': 22,
    'chess_won': 13,
    'checkers_played': 9,
    'checkers_won': 4,
    'chess_rating': 1342,
    'checkers_rating': 1118,
    'doodle_rating': null,
    'member_since': '2026-09-02T10:00:00Z',
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _board = Leaderboard(
  top: [
    for (final (i, (name, rating, games)) in const [
      ('Ada', 1734, 61),
      ('Kofi', 1588, 40),
      ('Mei', 1412, 33),
      ('Sam', 1296, 18),
      ('Lena', 1188, 12),
      ('Theo', 1104, 9),
      ('Ivy', 1031, 6),
    ].indexed)
      BoardEntry(
        place: i + 1,
        userId: 'u$i',
        profile: {'display_name': name, 'avatar_seed': i * 7 + 3},
        rating: rating,
        games: games,
      ),
  ],
  myPlace: 5,
  myRating: 1188,
  myGames: 12,
);

Future<void> _phone(
  WidgetTester tester,
  Widget child, {
  UtopiaTheme world = UtopiaThemes.utopiaTwilight,
}) async {
  UtopiaThemes.active = world;
  addTearDown(() => UtopiaThemes.active = UtopiaThemes.utopiaTwilight);
  tester.view.physicalSize = const Size(1290, 2796);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    'sound.sfx': false,
    'sound.music': false,
    'utopia.theme': world.id,
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currentUserProvider.overrideWithValue(null),
        myBirthdayProvider.overrideWith((ref) async => null),
        eventsProvider.overrideWith((ref) => _Events(ref, [_halloween])),
        leaderboardProvider.overrideWith((ref, key) async => _board),
        myRecordProvider.overrideWith(
          (ref, game) async => const PlayerRecord(
            rating: 1188,
            best: 1215,
            games: 12,
            wins: 8,
            losses: 3,
            draws: 1,
          ),
        ),
        ratingHistoryProvider.overrideWith((ref, game) async => _history),
        chipDoodleRepositoryProvider.overrideWithValue(_FakeChipDoodles()),
      ],
      child: MaterialApp(debugShowCheckedModeBanner: false, home: child),
    ),
  );
  // The app's fonts (bundled) and the icon font, so text and icons draw.
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
  await tester.pump(const Duration(milliseconds: 1500));
}

void main() {
  testWidgets('birthday page', (tester) async {
    await _phone(tester, const BirthdayScreen(onboarding: true));
    await tester.tap(find.text('Oct'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('18'));
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/new_birthday_page.png'),
    );
  });

  testWidgets('event card and sheet', (tester) async {
    late BuildContext host;
    await _phone(
      tester,
      Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Builder(
              builder: (context) {
                host = context;
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(children: [EventCard()]),
                );
              },
            ),
          ),
        ),
      ),
      world: UtopiaThemes.utopiaHalloween,
    );
    showEventSheet(host, 'halloween_2026');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/new_event_sheet.png'),
    );
  });

  testWidgets('rankings', (tester) async {
    await _phone(tester, const RankingsScreen());
    // The board loads after the first frame; its fonts too.
    await tester.runAsync(GoogleFonts.pendingFonts);
    await tester.pump(const Duration(milliseconds: 1600));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/new_rankings.png'),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.runAsync(GoogleFonts.pendingFonts);
    await tester.pump(const Duration(milliseconds: 100));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/new_rankings_board.png'),
    );
  });

  testWidgets('chip draws', (tester) async {
    await _phone(tester, const ChipDoodleScreen());
    // Chip draws for a few seconds; the player tries twice.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    for (final guess in ['bird', 'airplan']) {
      await tester.enterText(find.byType(TextField), guess);
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump(const Duration(milliseconds: 300));
    }
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.runAsync(GoogleFonts.pendingFonts);
    await tester.pump(const Duration(milliseconds: 100));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/new_chip_draws.png'),
    );
  });

  testWidgets('legend badge', (tester) async {
    await _phone(
      tester,
      Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TierEmblem(tier: RankTier.legend, size: 120),
                      TierEmblem(tier: RankTier.legend, size: 60),
                      TierEmblem(tier: RankTier.diamond, size: 60),
                    ],
                  ),
                  const SizedBox(height: 30),
                  const TierLadder(rating: 1760),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1230));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/new_legend_badge.png'),
    );
  });

  testWidgets('profile', (tester) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'sound.sfx': false,
      'sound.music': false,
    });
    final prefs = await SharedPreferences.getInstance();
    // No Supabase here: recent games shows its empty state.
    const me = User(
      id: 'me',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-09-02T10:00:00Z',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentUserProvider.overrideWithValue(me),
          profileByIdProvider.overrideWith(
            (ref, id) async => {
              'id': id,
              'display_name': 'Jake',
              'username': 'jakem',
              'avatar_seed': 7,
            },
          ),
          ludoRepositoryProvider.overrideWithValue(_FakeLudo()),
          coinBalanceProvider.overrideWith((ref) => Stream.value(48200)),
        ],
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: ProfileScreen(),
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
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.runAsync(GoogleFonts.pendingFonts);
    await tester.pump(const Duration(milliseconds: 100));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/new_profile.png'),
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -1100));
    await tester.pump(const Duration(milliseconds: 800));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/new_profile_ranks.png'),
    );
  });
}
