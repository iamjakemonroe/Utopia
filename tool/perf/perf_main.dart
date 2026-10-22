// A page for measuring how fast Utopia draws in a browser, with no account:
// the app as players have it (theme, screen size, the world), opened
// straight onto one scene.
//
//   flutter build web --profile -t tool/perf/perf_main.dart \
//     --dart-define-from-file=env/local.json -o build/perf
//   then open /?scene=world|cards|chess|checkers|ludo|eights|notifications
//   &world=<theme id> [&pieces=<set>]. "notifications" is home's cards with
//   window.__push() opening the notifications (20 of every kind) over them.
//   "ludo" and "eights" are offline tables where bots play every seat.
//   "chipshow" is Chip going through his moods; "chipdraws" is Chip
//   drawing an airplane in "Chip draws, you guess" (both for filming).
//   (tool/perf/measure.mjs measures it in a throttled browser)
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:utopia/app.dart';
import 'package:utopia/core/bots/bots.dart';
import 'package:utopia/core/config/env.dart';
import 'package:utopia/core/router/app_router.dart';
import 'package:utopia/core/settings/web_scale.dart';
import 'package:utopia/core/theme/app_text_styles.dart';
import 'package:utopia/core/theme/theme_controller.dart';
import 'package:utopia/core/widgets/app_background.dart';
import 'package:utopia/core/widgets/coin_buddy.dart';
import 'package:utopia/core/widgets/game_card_art.dart';
import 'package:utopia/features/checkers/presentation/screens/checkers_bot_screen.dart';
import 'package:utopia/features/checkers/domain/checkers_engine.dart';
import 'package:utopia/features/chess/domain/chess_bot.dart';
import 'package:utopia/features/chess/domain/chess_types.dart';
import 'package:utopia/features/chess/presentation/screens/chess_bot_screen.dart';
import 'package:utopia/features/notifications/data/notification_repository.dart';
import 'package:utopia/features/guess_doodle/data/chip_doodle_repository.dart';
import 'package:utopia/features/guess_doodle/domain/chip_doodle.dart';
import 'package:utopia/features/guess_doodle/presentation/chip_doodle_screen.dart';
import 'package:utopia/features/notifications/presentation/notifications_screen.dart';
import 'package:utopia/features/settings/presentation/settings_screen.dart';
import 'package:utopia/features/welcome/presentation/welcome_week.dart';
import 'package:utopia/core/profiles/profile_providers.dart';
import 'package:utopia/features/auth/presentation/providers/auth_providers.dart';
import 'package:utopia/features/coins/presentation/providers/coin_balance_provider.dart';
import 'package:utopia/features/friends/data/presence.dart';
import 'package:utopia/features/home/data/active_game.dart';
import 'package:utopia/features/home/presentation/screens/home_screen.dart';
import 'package:utopia/features/eights/presentation/controllers/eights_match_controller.dart';
import 'package:utopia/features/eights/presentation/screens/eights_match_screen.dart';
import 'package:utopia/features/ludo/domain/ludo_engine.dart';
import 'package:utopia/features/ludo/presentation/controllers/ludo_match_controller.dart';
import 'package:utopia/features/ludo/presentation/screens/ludo_match_screen.dart';

import 'cinema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final query = Uri.base.queryParameters;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('utopia.theme', query['world'] ?? 'utopia');
  // The film has Chip in it already: no floating one over it.
  await prefs.setBool('play.floatingChip', query['scene'] != 'cinema');
  AppTextStyles.preloadFonts();
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
  );
  final scene = switch (query['scene']) {
    // &pieces=<set>: the bot plays with that set (Chip's has faces).
    'chess' => ChessBotScreen(
      opponent: query['pieces'] == null
          ? kChessChip
          : BotPersona(
              key: 'perf',
              name: 'Chip',
              avatarKind: 'chip',
              avatarSeed: 0,
              chessPieces: query['pieces']!,
            ),
      level: BotLevel.normal,
      myColor: PieceColor.white,
    ),
    'checkers' => CheckersBotScreen(
      opponent: kChessChip,
      level: BotLevel.normal,
      mySide: CheckersSide.dark,
    ),
    'cards' || 'notifications' => const _Cards(),
    'chipshow' => const _ChipShow(),
    // For filming: Chip in one mood (&mood=), big; one game's diorama
    // (&game=) filling the screen.
    'hero' => _Hero(
      mood:
          BuddyMood.values.where((m) => m.name == query['mood']).firstOrNull ??
          BuddyMood.happy,
    ),
    'diorama' => _Diorama(
      game:
          GameKind.values.where((g) => g.name == query['game']).firstOrNull ??
          GameKind.ludo,
    ),
    // A Ludo table halfway through: pieces all over the board, so pieces
    // are taken (and react) within moments.
    'ludomid' => LudoMatchScreen(matchId: _midGame()),
    'chipdraws' => const ChipDoodleScreen(),
    // The trailer, played as a film (tool/perf/cinema.dart); window.__start()
    // rolls it.
    'cinema' => const Cinema(),
    // Home itself, as a signed-in player sees it (their profile made up;
    // friends, invites and games come back empty).
    'home' => const HomeScreen(),
    // Bots in every seat (the first is "this phone", played by a bot too),
    // so the game goes on by itself.
    'ludo' => LudoMatchScreen(
      matchId: startLocalLudo(
        LocalLudoSetup(
          playerIds: [for (final b in kLudoBots.take(4)) b.id],
          colors: const [
            LudoColor.red,
            LudoColor.green,
            LudoColor.yellow,
            LudoColor.blue,
          ],
          humanId: kLudoBots.first.id,
        ),
      ),
    ),
    'eights' => EightsMatchScreen(
      matchId: startLocalEights(
        LocalEightsSetup(
          playerIds: [for (final b in kLudoBots.take(4)) b.id],
          humanId: kLudoBots.first.id,
        ),
      ),
    ),
    _ => const AppBackground(child: SizedBox.expand()),
  };
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        goRouterProvider.overrideWith((ref) {
          final router = GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, _) => scene),
              GoRoute(
                path: '/notifications',
                builder: (_, _) => const NotificationsScreen(),
              ),
              GoRoute(
                path: '/settings',
                builder: (_, _) => const SettingsScreen(),
              ),
            ],
          );
          // window.__settings() opens Settings over the scene;
          // window.__where() says where the router is.
          globalContext['__settings'] = (() {
            router.push('/settings');
          }).toJS;
          globalContext['__where'] =
              (() => router.routerDelegate.currentConfiguration.uri.path.toJS)
                  .toJS;
          globalContext['__start'] = (() {
            cinemaStart.value = true;
          }).toJS;
          // window.__welcome() opens the welcome week's sheet (three live
          // worlds in it) over the scene.
          globalContext['__welcome'] = (() {
            final context = router.routerDelegate.navigatorKey.currentContext;
            if (context == null) return;
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => WelcomeWeekSheet(
                until: DateTime.now().add(const Duration(days: 3)),
              ),
            );
          }).toJS;
          globalContext['__push'] = (() {
            router.push('/notifications');
          }).toJS;
          return router;
        }),
        notificationsProvider.overrideWith(
          (ref) => Stream.value(_fakeNotifications()),
        ),
        currentUserProvider.overrideWithValue(
          User(
            id: _perfUser,
            appMetadata: const {},
            userMetadata: const {},
            aud: 'authenticated',
            createdAt: DateTime(2026).toIso8601String(),
          ),
        ),
        isAnonymousProvider.overrideWithValue(false),
        profileByIdProvider.overrideWith(
          (ref, id) async =>
              botProfile(id) ??
              {
                'id': id,
                'display_name': 'Jake',
                'username': 'jake',
                'avatar_kind': 'human',
                'avatar_seed': 4,
                'balance': 2500,
              },
        ),
        coinBalanceProvider.overrideWith((ref) => Stream.value(2500)),
        activeGameProvider.overrideWith((ref) async => null),
        friendsOnlineProvider.overrideWith((ref) => Stream.value(const {})),
        chipDoodleRepositoryProvider.overrideWithValue(_Airplane()),
        // &scale=2.6667 on a 1080x1920 window: a phone's screen, drawn
        // at full size (for filming).
        if (double.tryParse(query['scale'] ?? '') case final scale?)
          webScaleProvider.overrideWith((ref) => _FilmScale(scale)),
      ],
      child: const UtopiaApp(),
    ),
  );
}

const _perfUser = '00000000-0000-4000-8000-000000000001';

String _midGame() {
  const id = 'local-midgame';
  const colors = [
    LudoColor.red,
    LudoColor.green,
    LudoColor.yellow,
    LudoColor.blue,
  ];
  final players = [for (final b in kLudoBots.take(4)) b.id];
  final game = LudoState.initial(colors).copyWith(
    tokens: {
      LudoColor.red: const [4, 17, 29, -1],
      LudoColor.green: const [9, 21, 38, -1],
      LudoColor.yellow: const [2, 26, 34, -1],
      LudoColor.blue: const [7, 14, 43, -1],
    },
  );
  restoreLocalLudo('/ludo/$id', {
    'players': players,
    'colors': [for (final c in colors) c.name],
    'human': players.first,
    'game': game.toJson(),
    'turn': 12,
  });
  return id;
}

/// The screen drawn [scale] times bigger, past the setting's limits.
class _FilmScale extends WebScaleController {
  _FilmScale(double scale) : super(null) {
    state = scale;
  }
}

/// Chip through his moods, a couple of seconds each, big in the world.
class _ChipShow extends StatefulWidget {
  const _ChipShow();

  @override
  State<_ChipShow> createState() => _ChipShowState();
}

class _ChipShowState extends State<_ChipShow> {
  static const _moods = [
    BuddyMood.happy,
    BuddyMood.excited,
    BuddyMood.thinking,
    BuddyMood.evil,
    BuddyMood.peaceful,
    BuddyMood.sad,
    BuddyMood.vibing,
    BuddyMood.hot,
  ];
  int _at = 0;
  late final Timer _timer = Timer.periodic(
    const Duration(milliseconds: 1800),
    (_) => setState(() => _at = (_at + 1) % _moods.length),
  );

  @override
  void initState() {
    super.initState();
    _timer;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AppBackground(
      child: Center(child: CoinBuddy(mood: _moods[_at], size: 240)),
    ),
  );
}

/// Chip in [mood], big, in the world (for filming).
class _Hero extends StatelessWidget {
  const _Hero({required this.mood});

  final BuddyMood mood;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AppBackground(
      child: Align(
        alignment: const Alignment(0, 0.15),
        child: CoinBuddy(mood: mood, size: 260),
      ),
    ),
  );
}

/// One game's diorama, filling the screen's width (for filming).
class _Diorama extends StatelessWidget {
  const _Diorama({required this.game});

  final GameKind game;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AppBackground(
      child: Center(
        child: LayoutBuilder(
          builder: (context, c) =>
              GameSceneArt(game: game, height: c.maxWidth * 1.2),
        ),
      ),
    ),
  );
}

/// Chip's real airplane doodle, from the deck.
class _Airplane implements ChipDoodleRepository {
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

/// What home shows most of: Chip over the four game cards, in the world.
class _Cards extends StatelessWidget {
  const _Cards();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const CoinBuddy(mood: BuddyMood.happy, size: 104),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.85,
                    children: [
                      for (final game in GameKind.values)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(23),
                          child: GameSceneArt(game: game, height: 170),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Twenty notifications of every kind, some unread, from twenty people.
List<AppNotification> _fakeNotifications() {
  const kinds = [
    'friend_request',
    'game_invite',
    'friend_accepted',
    'report_update',
    'coin_gift',
    'friend_birthday',
    'birthday_wish',
  ];
  final now = DateTime.now();
  return [
    for (var i = 0; i < 20; i++)
      AppNotification(
        id: 1000 - i,
        kind: kinds[i % kinds.length],
        actorId: '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
        refId: '10000000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
        data: {
          'game': 'chess',
          'stake': 50,
          'coins': 500,
          'status': 'fixed',
          'note': 'Fixed: thanks for telling us!',
        },
        readAt: i < 6 ? null : now,
        createdAt: now.subtract(Duration(hours: i * 3)),
      ),
  ];
}
