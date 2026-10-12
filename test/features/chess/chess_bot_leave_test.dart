import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:utopia/core/bots/bots.dart';
import 'package:utopia/core/theme/theme_controller.dart'
    show sharedPreferencesProvider;
import 'package:utopia/core/widgets/game_card_art.dart';
import 'package:utopia/features/auth/presentation/providers/auth_providers.dart';
import 'package:utopia/features/chess/domain/chess_bot.dart';
import 'package:utopia/features/chess/domain/chess_types.dart';
import 'package:utopia/features/chess/presentation/screens/chess_bot_screen.dart';
import 'package:utopia/features/home/data/offline_game.dart';

/// Must match ChessBotScreen's own route for this setup, or the saved game
/// isn't picked up.
final _route =
    '/chess/bot?opponent=${kChessChip.key}&level=easy&color=white&clock=0&inc=0';

/// Opens a bot game from a plain home screen, so there's somewhere to leave
/// to. With [inProgress], a saved game (1.e4 e5, white to move) is resumed,
/// so the game is under way from the first frame.
Future<SharedPreferences> _openBotGame(
  WidgetTester tester, {
  required bool inProgress,
}) async {
  SharedPreferences.setMockInitialValues({
    if (inProgress)
      'offline_game': jsonEncode(
        OfflineGame(
          kind: GameKind.chess,
          route: _route,
          opponent: kChessChip.name,
          data: const {
            'moves': ['e2e4', 'e7e5'],
          },
        ).toJson(),
      ),
  });
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currentUserProvider.overrideWithValue(null),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChessBotScreen(
                      opponent: kChessChip,
                      level: BotLevel.easy,
                      myColor: PieceColor.white,
                      resume: inProgress,
                    ),
                  ),
                ),
                child: const Text('home'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('home'));
  // The screen animates forever (Chip's face), so pump, don't settle.
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  return prefs;
}

Future<void> _pumpDialog(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Chip's speech bubble and the music fade leave short timers behind;
/// unmount and let them run out so the test ends clean.
Future<void> _tearDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  testWidgets('leaving a game in progress asks first; keep playing stays', (
    tester,
  ) async {
    final prefs = await _openBotGame(tester, inProgress: true);
    expect(find.byType(ChessBotScreen), findsOneWidget);

    // The close button asks.
    await tester.tap(find.byTooltip('Leave game'));
    await _pumpDialog(tester);
    expect(find.text('Leave this game?'), findsOneWidget);

    await tester.tap(find.text('Keep playing'));
    await _pumpDialog(tester);
    expect(find.text('Leave this game?'), findsNothing);
    expect(find.byType(ChessBotScreen), findsOneWidget);
    expect(prefs.getString('offline_game'), isNotNull, reason: 'still saved');

    // So does the system back gesture.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await _pumpDialog(tester);
    expect(find.text('Leave this game?'), findsOneWidget);

    await tester.tap(find.text('Leave'));
    await _pumpDialog(tester);
    expect(find.byType(ChessBotScreen), findsNothing);
    expect(find.text('home'), findsOneWidget);
    expect(prefs.getString('offline_game'), isNull, reason: 'game forgotten');
    await _tearDown(tester);
  });

  testWidgets('resigning asks first', (tester) async {
    await _openBotGame(tester, inProgress: true);

    await tester.tap(find.byTooltip('Resign'));
    await _pumpDialog(tester);
    expect(find.text('Resign this game?'), findsOneWidget);
    await tester.tap(find.text('Keep playing'));
    await _pumpDialog(tester);
    expect(find.text('You resigned'), findsNothing);

    await tester.tap(find.byTooltip('Resign'));
    await _pumpDialog(tester);
    await tester.tap(find.text('Resign').last);
    await _pumpDialog(tester);
    expect(find.text('You resigned'), findsWidgets);
    await _tearDown(tester);
  });

  testWidgets('a game with no moves yet just closes', (tester) async {
    await _openBotGame(tester, inProgress: false);

    await tester.tap(find.byTooltip('Close'));
    await _pumpDialog(tester);
    expect(find.text('Leave this game?'), findsNothing);
    expect(find.byType(ChessBotScreen), findsNothing);
    await _tearDown(tester);
  });
}
