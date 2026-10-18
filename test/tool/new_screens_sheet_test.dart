// Phone screenshots of the birthday page, the event card and the event
// sheet, into test/tool/goldens/. Run:
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
      isWorld: false,
      games: 10,
      days: 0,
      earned: false,
    ),
    EventReward(
      itemId: 'utopia_halloween',
      isWorld: true,
      games: 15,
      days: 5,
      earned: false,
    ),
  ],
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
}
