// A capture on the Ludo board, for a look: the badge on the piece that took
// it (yours, and someone else's), the reaction cards open (war or peace for
// the piece that took it, sad or again for one sent home), and all four
// reactions playing on the pieces. Run:
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
import 'package:utopia/features/ludo/presentation/widgets/ludo_pieces.dart';

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
    tester.view.physicalSize = const Size(1600, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'sound.sfx': false,
      'sound.music': false,
    });
    final prefs = await SharedPreferences.getInstance();
    final deadline = DateTime.now().add(const Duration(seconds: 4));
    const window = Duration(seconds: 6);

    Widget board(
      String title, {
      Widget? badge,
      double width = 0,
      int token = 0,
      List<LudoTokenReaction> reactions = const [],
    }) => Expanded(
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
              reactions: reactions,
              anchors: [
                if (badge != null)
                  LudoTokenAnchor(
                    color: LudoColor.red,
                    token: token,
                    width: width,
                    onTokenTap: () {},
                    child: badge,
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    // Reactions halfway through, at full strength.
    LudoTokenReaction playing(LudoColor color, int token, TokenReaction kind) =>
        LudoTokenReaction(
          color: color,
          token: token,
          kind: kind,
          startedAt:
              LudoBoardView.clockNow() - LudoTokenReaction.duration * 0.45,
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
                child: Column(
                  children: [
                    Row(
                      children: [
                        board(
                          'You captured',
                          badge: LudoCaptureBadge(
                            deadline: deadline,
                            window: window,
                            onTap: () {},
                          ),
                          width: LudoCaptureBadge.size.width,
                        ),
                        board(
                          'Someone else is deciding',
                          badge: LudoCaptureBadge(
                            deadline: deadline,
                            window: window,
                          ),
                          width: LudoCaptureBadge.size.width,
                        ),
                        board(
                          'You tapped your piece',
                          badge: LudoReactionCard.capture(
                            deadline: deadline,
                            window: window,
                            onWar: () {},
                            onPeace: () {},
                          ),
                          width: LudoReactionCard.size.width,
                        ),
                        board(
                          'Your piece was sent home',
                          token: 1,
                          badge: LudoReactionCard.sentHome(
                            deadline: deadline,
                            window: window,
                            color: LudoColor.red,
                            setId: 'classic',
                            onSad: () {},
                            onAgain: () {},
                          ),
                          width: LudoReactionCard.size.width,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        board(
                          'War',
                          reactions: [
                            playing(LudoColor.red, 0, TokenReaction.war),
                          ],
                        ),
                        board(
                          'Peace',
                          reactions: [
                            playing(LudoColor.red, 0, TokenReaction.peace),
                          ],
                        ),
                        board(
                          'Sad (sent home)',
                          reactions: [
                            playing(LudoColor.yellow, 0, TokenReaction.sad),
                          ],
                        ),
                        board(
                          'Again! (sent home)',
                          reactions: [
                            playing(LudoColor.yellow, 0, TokenReaction.again),
                          ],
                        ),
                      ],
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
