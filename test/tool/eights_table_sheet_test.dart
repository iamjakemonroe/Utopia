// The Crazy Eights table, for a look: a 2-player and a 4-player game at
// phone size (my turn, the cards that go lifted and glowing, an eight on
// the pile naming its suit), and a 6-player table mid-deal. Run:
// flutter test --run-skipped --update-goldens test/tool/eights_table_sheet_test.dart
@Tags(['sheet'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia/core/theme/app_text_styles.dart';
import 'package:utopia/core/theme/app_theme.dart';
import 'package:utopia/core/theme/theme_controller.dart';
import 'package:utopia/core/widgets/app_background.dart';
import 'package:utopia/features/eights/domain/eights_engine.dart';
import 'package:utopia/features/eights/presentation/widgets/eights_table_view.dart';

PlayingCard c(String code) => PlayingCard.fromCode(code);

Widget _seat(int s) => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    CircleAvatar(radius: 24, child: Text('P$s')),
    const SizedBox(height: 4),
    Text(
      'Player $s',
      style: const TextStyle(color: Colors.white, fontSize: 12),
    ),
  ],
);

Widget _table({
  required EightsTable table,
  required List<PlayingCard> hand,
  bool myTurn = true,
  bool deal = false,
}) => SizedBox(
  width: 390,
  height: 640,
  child: EightsTableView(
    table: table,
    hand: hand,
    mySeat: 0,
    playable: myTurn
        ? {
            for (final h in hand)
              if (table.canPlay(h)) h,
          }
        : const {},
    myTurn: myTurn,
    canDraw: myTurn,
    canPass: false,
    onPlay: (_) {},
    onDraw: () {},
    onPass: () {},
    seatBuilder: _seat,
    deal: deal,
  ),
);

void main() {
  testWidgets('the crazy eights table', (tester) async {
    tester.view.physicalSize = const Size(1240, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'sound.sfx': false,
      'sound.music': false,
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.runAsync(() async {
      final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
      final icons = File(
        '${artifacts.path}/material_fonts/MaterialIcons-Regular.otf',
      ).readAsBytesSync();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(Future.value(ByteData.sublistView(icons)))).load();
      AppTextStyles.display();
      AppTextStyles.body();
      await GoogleFonts.pendingFonts();
    });
    final hand7 = [
      for (final x in ['KH', '5H', '9S', '8C', 'QD', '2S', '5D']) c(x),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: Scaffold(
            body: AppBackground(
              child: Row(
                children: [
                  _table(
                    table: EightsTable(
                      counts: const [7, 6],
                      turn: 0,
                      top: c('5S'),
                      suit: CardSuit.spades,
                      drawCount: 31,
                    ),
                    hand: hand7,
                  ),
                  const SizedBox(width: 20),
                  _table(
                    table: EightsTable(
                      counts: const [5, 4, 1, 6],
                      turn: 0,
                      top: c('8D'),
                      suit: CardSuit.hearts,
                      drawCount: 12,
                    ),
                    hand: hand7.take(5).toList(),
                  ),
                  const SizedBox(width: 20),
                  _table(
                    table: EightsTable(
                      counts: const [5, 5, 5, 5, 5, 5],
                      turn: 2,
                      top: c('QC'),
                      suit: CardSuit.clubs,
                      drawCount: 21,
                    ),
                    hand: hand7.take(5).toList(),
                    myTurn: false,
                    deal: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    // Let the hands settle (and the deal get going on the last one).
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 900)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/eights_table.png'),
    );
    while (tester.takeException() != null) {}
  });
}
