// Phone screenshots of the birthday page, the event card and sheet, and
// the rankings, into test/tool/goldens/. Run:
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
import 'package:utopia/features/rankings/data/rankings_repository.dart';
import 'package:utopia/features/rankings/domain/ranking.dart';
import 'package:utopia/features/rankings/presentation/rankings_screen.dart';

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
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/new_rankings.png'),
    );
  });
}
