// A page for measuring how fast Utopia draws in a browser, with no account:
// the app as players have it (theme, screen size, the world), opened
// straight onto one scene.
//
//   flutter build web --profile -t tool/perf/perf_main.dart \
//     --dart-define-from-file=env/local.json -o build/perf
//   then open /?scene=world|cards|chess|checkers&world=<theme id>[&pieces=<set>]
//   (tool/perf/measure.mjs measures it in a throttled browser)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:utopia/app.dart';
import 'package:utopia/core/bots/bots.dart';
import 'package:utopia/core/config/env.dart';
import 'package:utopia/core/router/app_router.dart';
import 'package:utopia/core/theme/theme_controller.dart';
import 'package:utopia/core/widgets/app_background.dart';
import 'package:utopia/core/widgets/coin_buddy.dart';
import 'package:utopia/core/widgets/game_card_art.dart';
import 'package:utopia/features/checkers/presentation/screens/checkers_bot_screen.dart';
import 'package:utopia/features/checkers/domain/checkers_engine.dart';
import 'package:utopia/features/chess/domain/chess_bot.dart';
import 'package:utopia/features/chess/domain/chess_types.dart';
import 'package:utopia/features/chess/presentation/screens/chess_bot_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final query = Uri.base.queryParameters;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('utopia.theme', query['world'] ?? 'utopia');
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
    'checkers' => const CheckersBotScreen(
      opponent: kChessChip,
      level: BotLevel.normal,
      mySide: CheckersSide.dark,
    ),
    'cards' => const _Cards(),
    _ => const AppBackground(child: SizedBox.expand()),
  };
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        goRouterProvider.overrideWith(
          (ref) => GoRouter(
            routes: [GoRoute(path: '/', builder: (_, _) => scene)],
          ),
        ),
      ],
      child: const UtopiaApp(),
    ),
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
