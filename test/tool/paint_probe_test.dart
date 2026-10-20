// What a game screen draws again and lays out each frame, and why: which
// layers repaint (and what's in them), and the stacks that marked them.
//   flutter test --run-skipped test/tool/paint_probe_test.dart
//   (--dart-define=SCENE=checkers, LAYOUT=true for layout stacks,
//   REBUILDS=true for what's built again, BUILT=<lines>)
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:utopia/core/bots/bots.dart';
import 'package:utopia/core/theme/theme_controller.dart'
    show sharedPreferencesProvider;
import 'package:utopia/features/auth/presentation/providers/auth_providers.dart';
import 'package:utopia/features/checkers/domain/checkers_engine.dart';
import 'package:utopia/features/checkers/presentation/screens/checkers_bot_screen.dart';
import 'package:utopia/features/chess/domain/chess_bot.dart';
import 'package:utopia/features/chess/domain/chess_types.dart';
import 'package:utopia/features/chess/presentation/screens/chess_bot_screen.dart';

void main() {
  testWidgets('what repaints each frame in a chess game', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    SharedPreferences.setMockInitialValues({'utopia.theme': 'utopia_doodle'});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentUserProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
          home: const String.fromEnvironment('SCENE') == 'checkers'
              ? CheckersBotScreen(
                  opponent: kChessChip,
                  level: BotLevel.easy,
                  mySide: CheckersSide.dark,
                )
              : ChessBotScreen(
                  opponent: kChessChip,
                  level: BotLevel.easy,
                  myColor: PieceColor.white,
                ),
        ),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final painted = <String, int>{};
    debugProfilePaintsEnabled = true;
    debugOnProfilePaint = (RenderObject o) {
      RenderObject? b = o;
      while (b != null && !b.isRepaintBoundary) {
        b = b.parent;
      }
      final where = b?.debugCreator.toString().split('\n').first ?? '?';
      final what = o is RenderCustomPaint
          ? '${o.painter?.runtimeType}'
          : '${o.runtimeType}';
      final key =
          '${where.length > 90 ? where.substring(0, 90) : where}  >  $what';
      painted[key] = (painted[key] ?? 0) + 1;
    };
    debugPrintMarkNeedsPaintStacks = !const bool.fromEnvironment('LAYOUT');
    debugPrintMarkNeedsLayoutStacks = const bool.fromEnvironment('LAYOUT');
    debugPrintRebuildDirtyWidgets = const bool.fromEnvironment('REBUILDS');
    final log = <String>[];
    final old = debugPrint;
    debugPrint = (String? m, {int? wrapWidth}) => log.add(m ?? '');
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    debugPrint = old;
    debugPrintMarkNeedsPaintStacks = false;
    debugPrintMarkNeedsLayoutStacks = false;
    debugPrintRebuildDirtyWidgets = false;
    debugOnProfilePaint = null;
    debugProfilePaintsEnabled = false;

    final rows = painted.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    // ignore: avoid_print
    print('PAINTED over 2 frames (layer > painter: count)');
    for (final r in rows.take(40)) {
      // ignore: avoid_print
      print('  ${r.value.toString().padLeft(4)}  ${r.key}');
    }
    // ignore: avoid_print
    print('MARK NEEDS PAINT:');
    for (final l
        in log
            .where(
              (l) => const bool.fromEnvironment('REBUILDS')
                  ? l.startsWith('Building ')
                  : (l.contains('called for') ||
                        l.contains('utopia/') ||
                        l.contains('animation') ||
                        l.contains('transitions') ||
                        l.contains('Transition')),
            )
            .take(
              int.parse(
                const String.fromEnvironment('BUILT', defaultValue: '60'),
              ),
            )) {
      // ignore: avoid_print
      print('  $l');
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }, tags: ['probe']);
}
