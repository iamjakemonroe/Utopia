import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia/core/theme/theme_controller.dart';
import 'package:utopia/core/widgets/game_card_art.dart';
import 'package:utopia/features/auth/presentation/providers/auth_providers.dart';
import 'package:utopia/features/guess_doodle/data/chip_doodle_repository.dart';
import 'package:utopia/features/guess_doodle/domain/chip_doodle.dart';
import 'package:utopia/features/guess_doodle/presentation/chip_doodle_screen.dart';
import 'package:utopia/features/home/data/offline_game.dart';

/// Chip draws a cat, every round.
class _Doodles implements ChipDoodleRepository {
  @override
  Future<ChipDoodleRound> round() async => const ChipDoodleRound(
    word: 'cat',
    strokes: ['M100 100 L300 300', 'M300 100 L100 300'],
  );
}

void main() {
  testWidgets('a game the app closed on carries on, points and all', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'sound.sfx': false,
      'sound.music': false,
    });
    final prefs = await SharedPreferences.getInstance();
    final store = OfflineGameStore(prefs);
    // The app closed in round 3, with 250 points from two right guesses.
    store.save(
      const OfflineGame(
        kind: GameKind.doodle,
        route: '/guess-my-doodle/chip',
        opponent: 'Chip',
        data: {'round': 3, 'score': 250, 'guessed': 2},
      ),
    );
    expect(store.load()!.resumeRoute, '/guess-my-doodle/chip?resume=1');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentUserProvider.overrideWithValue(null),
          chipDoodleRepositoryProvider.overrideWithValue(_Doodles()),
        ],
        child: const MaterialApp(home: ChipDoodleScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(store.load()!.data, {'round': 3, 'score': 250, 'guessed': 2});

    // Guessed: kept as round 4 next, with the new points on top.
    await tester.enterText(find.byType(TextField), 'cat');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump(const Duration(milliseconds: 100));
    final after = store.load()!.data;
    expect(after['round'], 4);
    expect(after['score'] as int, greaterThan(250));
    expect(after['guessed'], 3);

    // Leaving on purpose ends it.
    await tester.pumpWidget(const SizedBox());
    expect(store.load(), isNull);
  });
}
