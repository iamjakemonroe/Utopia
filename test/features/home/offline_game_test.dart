import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia/core/widgets/game_card_art.dart';
import 'package:utopia/features/home/data/offline_game.dart';
import 'package:utopia/features/ludo/domain/ludo_engine.dart';
import 'package:utopia/features/ludo/presentation/controllers/ludo_match_controller.dart';

void main() {
  test('a saved game comes back, and only its own end clears it', () async {
    SharedPreferences.setMockInitialValues({});
    final store = OfflineGameStore(await SharedPreferences.getInstance());
    const route =
        '/chess/bot?opponent=chip&level=normal&color=white&clock=5&inc=0';
    store.save(
      const OfflineGame(
        kind: GameKind.chess,
        route: route,
        opponent: 'Chip',
        data: {
          'moves': ['e2e4', 'e7e5'],
        },
      ),
    );
    final back = store.load()!;
    expect(back.kind, GameKind.chess);
    expect(back.data['moves'], ['e2e4', 'e7e5']);
    expect(back.resumeRoute, '$route&resume=1');

    // Ending some other game leaves this one alone.
    store.clear(route: '/checkers/bot?opponent=robo');
    expect(store.load(), isNotNull);
    store.clear(route: route);
    expect(store.load(), isNull);
  });

  test('an offline Ludo table is set back up from its save', () {
    final game = LudoState.initial(const [LudoColor.red, LudoColor.yellow]);
    restoreLocalLudo('/ludo/local-42', {
      'players': ['me', 'bot:pip'],
      'colors': ['red', 'yellow'],
      'human': 'me',
      'game': game.toJson(),
      'turn': 7,
    });
    final setup = localLudoSetup('local-42');
    expect(setup, isNotNull);
    expect(setup!.humanId, 'me');
    expect(setup.colors, [LudoColor.red, LudoColor.yellow]);
  });
}
