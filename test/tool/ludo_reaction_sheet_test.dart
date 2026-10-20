// A capture on the Ludo board, for a look: the badge on the piece that took
// it (yours, and someone else's), and the reaction card open. Run:
// flutter test --run-skipped --update-goldens test/tool/ludo_reaction_sheet_test.dart
@Tags(['sheet'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:utopia/core/theme/app_colors.dart';
import 'package:utopia/core/theme/app_theme.dart';
import 'package:utopia/core/theme/theme_controller.dart';
import 'package:utopia/core/widgets/app_background.dart';
import 'package:utopia/features/ludo/domain/ludo_engine.dart';
import 'package:utopia/features/ludo/presentation/widgets/ludo_board.dart';
import 'package:utopia/features/ludo/presentation/widgets/ludo_capture_bubble.dart';

LudoState _game() {
  final g = LudoState.initial(const [
    LudoColor.red,
    LudoColor.green,
    LudoColor.yellow,
    LudoColor.blue,
  ]);
  return g.copyWith(
    tokens: {
      ...g.tokens,
      LudoColor.red: [12, kLudoBase, kLudoBase, 3],
      LudoColor.yellow: [kLudoBase, 30, kLudoBase, kLudoBase],
    },
  );
}

void main() {
  testWidgets('a capture on the ludo board', (tester) async {
    tester.view.physicalSize = const Size(1200, 460);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'sound.sfx': false,
      'sound.music': false,
    });
    final prefs = await SharedPreferences.getInstance();
    final deadline = DateTime.now().add(const Duration(seconds: 4));
    const window = Duration(seconds: 6);

    Widget board(String title, Widget badge, double width) => Expanded(
      child: Column(
        children: [
          Text(title, style: TextStyle(color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          SizedBox(
            width: 380,
            height: 380,
            child: LudoBoardView(
              game: _game(),
              myColor: LudoColor.red,
              movableTokens: const [],
              onTokenTap: (_) {},
              pieceSets: const {},
              anchor: LudoTokenAnchor(
                color: LudoColor.red,
                token: 0,
                width: width,
                child: badge,
              ),
              onAnchorTap: () {},
            ),
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          home: Scaffold(
            body: AppBackground(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    board(
                      'You captured',
                      LudoCaptureBadge(
                        deadline: deadline,
                        window: window,
                        onTap: () {},
                      ),
                      LudoCaptureBadge.size.width,
                    ),
                    board(
                      'Someone else captured',
                      LudoCaptureBadge(deadline: deadline, window: window),
                      LudoCaptureBadge.size.width,
                    ),
                    board(
                      'You tapped your piece',
                      LudoReactionCard(
                        deadline: deadline,
                        window: window,
                        onWar: () {},
                        onPeace: () {},
                      ),
                      LudoReactionCard.size.width,
                    ),
                  ],
                ),
              ),
            ),
          ),
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
    });
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/ludo_reaction.png'),
    );
    while (tester.takeException() != null) {}
  });
}
