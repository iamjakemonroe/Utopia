import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/back_to_home.dart';
import '../../../core/widgets/game_card_art.dart';
import '../../../core/widgets/pop_card.dart';
import '../../checkers/domain/checkers_engine.dart';
import '../../checkers/presentation/widgets/checkers_disc.dart';
import '../../chess/domain/chess_types.dart';
import '../../chess/presentation/widgets/chess_piece_art.dart';
import '../../chess/presentation/widgets/chess_piece_styles.dart';
import '../../ludo/presentation/widgets/ludo_rules_sheet.dart';
import '../../../core/layout/responsive.dart';
import '../../../l10n/strings.dart';

/// How to play every game in Utopia: a tab per game, each with its own
/// sections. New games get a tab here as they arrive.
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key, this.initialGame = 0});

  final int initialGame;

  static final _games = [
    (GameKind.chess, strings.howToPlayChess, Icons.extension_rounded),
    (GameKind.ludo, strings.howToPlayLudo, Icons.casino_rounded),
    (GameKind.checkers, strings.howToPlayCheckers, Icons.blur_circular_rounded),
    (GameKind.pool, strings.poolPool, Icons.sports_baseball_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _games.length,
      initialIndex: initialGame.clamp(0, _games.length - 1),
      child: BackToHomeScope(
        child: Scaffold(
          appBar: AppBar(
            leading: const BackOrHomeButton(),
            title: Text(strings.howToPlayHowToPlay),
            bottom: TabBar(
              labelColor: AppColors.textPrimary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.goldBorder,
              indicatorWeight: 3,
              labelStyle: AppTextStyles.body(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
              tabs: [
                for (final (_, name, icon) in _games)
                  Tab(icon: Icon(icon), text: name),
              ],
            ),
          ),
          body: const AppBackground(
            child: TabBarView(
              children: [
                _ChessGuide(),
                _LudoGuide(),
                _CheckersGuide(),
                _PoolGuide(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A game's guide: its living diorama, then each section in a card.
class _Guide extends StatelessWidget {
  const _Guide({
    required this.game,
    required this.intro,
    required this.sections,
  });

  final GameKind game;
  final String intro;
  final List<_Section> sections;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: context.readablePadding(
        top: AppSpacing.md,
        bottom: AppSpacing.xxl,
      ),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: GameSceneArt(game: game, height: 140),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(intro, style: AppTextStyles.body(color: AppColors.textSecondary)),
        for (final section in sections) ...[
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Icon(section.icon, size: 20, color: section.color),
              const SizedBox(width: 8),
              Text(section.title, style: AppTextStyles.display(fontSize: 19)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          PopCard(
            borderRadius: 22,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            child: Column(children: section.children),
          ),
        ],
      ],
    );
  }
}

class _Section {
  const _Section({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;
}

class _ChessGuide extends StatelessWidget {
  const _ChessGuide();

  static final _pieces = [
    (
      PieceType.king,
      strings.howToPlayKing,
      strings.howToPlayOneSquareAnyWayKeep,
    ),
    (
      PieceType.queen,
      strings.howToPlayQueen,
      strings.howToPlayAnyNumberOfSquaresIn,
    ),
    (
      PieceType.rook,
      strings.howToPlayRook,
      strings.howToPlayAnyNumberOfSquaresStraight,
    ),
    (
      PieceType.bishop,
      strings.howToPlayBishop,
      strings.howToPlayAnyNumberOfSquaresAlong,
    ),
    (PieceType.knight, strings.howToPlayKnight, strings.howToPlayJumpsInAnLTwo),
    (
      PieceType.pawn,
      strings.howToPlayPawn,
      strings.howToPlayOneSquareForwardTwoOn,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final style = ChessPieceStyle.byId('classic');
    return _Guide(
      game: GameKind.chess,
      intro: strings.howToPlayTwoPlayersOneBoardOut,
      sections: [
        _Section(
          title: strings.howToPlayTheGoal,
          icon: Icons.emoji_events_rounded,
          color: Color(0xFFFFC94D),
          children: [
            RuleRow(
              icon: Icons.flag_rounded,
              color: Color(0xFFFFC94D),
              title: strings.howToPlayCheckmateWins,
              body: strings.howToPlayAttackTheOtherKingSo,
            ),
            RuleRow(
              icon: Icons.warning_amber_rounded,
              color: Color(0xFFFF7A7A),
              title: strings.howToPlayCheck,
              body: strings.howToPlayWhenYourKingIsAttacked,
            ),
          ],
        ),
        _Section(
          title: strings.howToPlayHowThePiecesMove,
          icon: Icons.open_with_rounded,
          color: AppColors.sky,
          children: [
            for (final (type, name, body) in _pieces)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.25),
                      ),
                      alignment: Alignment.center,
                      child: ChessPieceArt(
                        type: type,
                        finish: style.of(PieceColor.white),
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: AppTextStyles.body(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            body,
                            style: AppTextStyles.body(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        _Section(
          title: strings.howToPlaySpecialMoves,
          icon: Icons.auto_awesome_rounded,
          color: Color(0xFFB27BFF),
          children: [
            RuleRow(
              icon: Icons.castle_rounded,
              color: Color(0xFFB27BFF),
              title: strings.howToPlayCastling,
              body: strings.howToPlayOnceAGameYourKing,
            ),
            RuleRow(
              icon: Icons.upgrade_rounded,
              color: Color(0xFF3DDC97),
              title: strings.howToPlayPromotion,
              body: strings.howToPlayAPawnThatReachesThe,
            ),
            RuleRow(
              icon: Icons.compare_arrows_rounded,
              color: Color(0xFF4DA3FF),
              title: strings.howToPlayEnPassant,
              body: strings.howToPlayIfAPawnRushesTwo,
            ),
          ],
        ),
        _Section(
          title: strings.howToPlayDraws,
          icon: Icons.handshake_rounded,
          color: Color(0xFF4DA3FF),
          children: [
            RuleRow(
              icon: Icons.block_rounded,
              color: Color(0xFF4DA3FF),
              title: strings.howToPlayStalemate,
              body: strings.howToPlayIfItSYourMove,
            ),
            RuleRow(
              icon: Icons.balance_rounded,
              color: Color(0xFF9B7BFF),
              title: strings.howToPlayNotEnoughToWin,
              body: strings.howToPlayWhenNeitherSideHasEnough,
            ),
          ],
        ),
        _Section(
          title: strings.howToPlayPlayingInUtopia,
          icon: Icons.public_rounded,
          color: Color(0xFF2DE0C2),
          children: [
            RuleRow(
              icon: Icons.timer_rounded,
              color: Color(0xFFFF5C9C),
              title: strings.howToPlayClocks,
              body: strings.howToPlayEachSideHasItsOwn,
            ),
            RuleRow(
              icon: Icons.toll_rounded,
              color: Color(0xFFFFC94D),
              title: strings.howToPlayEntriesAndPrizes,
              body: strings.howToPlayPickAFreeGameOr,
            ),
            RuleRow(
              icon: Icons.history_rounded,
              color: Color(0xFF5AB8FF),
              title: strings.howToPlayLookBack,
              body: strings.howToPlayUseTheArrowsUnderThe,
            ),
            RuleRow(
              icon: Icons.chat_bubble_rounded,
              color: Color(0xFFB27BFF),
              title: strings.howToPlayChat,
              body: strings.howToPlaySendMessagesStickersAndVoice,
            ),
            RuleRow(
              icon: Icons.logout_rounded,
              color: Color(0xFFFF7A7A),
              title: strings.howToPlayLeavingResigns,
              body: strings.howToPlayLeavingAGameInProgress,
            ),
          ],
        ),
      ],
    );
  }
}

class _LudoGuide extends StatelessWidget {
  const _LudoGuide();

  @override
  Widget build(BuildContext context) {
    final basics = ludoRules.take(4).toList();
    final more = ludoRules.skip(4).toList();
    return _Guide(
      game: GameKind.ludo,
      intro: strings.howToPlayTwoToSixPlayersRace,
      sections: [
        _Section(
          title: strings.howToPlayTheBasics,
          icon: Icons.casino_rounded,
          color: AppColors.mint,
          children: [
            for (final (icon, color, title, body) in basics)
              RuleRow(icon: icon, color: color, title: title, body: body),
          ],
        ),
        _Section(
          title: strings.howToPlayWinning,
          icon: Icons.emoji_events_rounded,
          color: const Color(0xFFFFC94D),
          children: [
            for (final (icon, color, title, body) in more)
              RuleRow(icon: icon, color: color, title: title, body: body),
          ],
        ),
        _Section(
          title: strings.howToPlayPlayingWithFriends,
          icon: Icons.groups_rounded,
          color: Color(0xFFFF8FB8),
          children: [
            RuleRow(
              icon: Icons.vpn_key_rounded,
              color: Color(0xFFFF8FB8),
              title: strings.howToPlayRooms,
              body: strings.howToPlayMakeARoomAndShare,
            ),
            RuleRow(
              icon: Icons.event_seat_rounded,
              color: Color(0xFF4DA3FF),
              title: strings.howToPlayPickYourSeat,
              body: strings.howToPlayInARoomTapAn,
            ),
            RuleRow(
              icon: Icons.mic_rounded,
              color: Color(0xFFB27BFF),
              title: strings.howToPlayVoiceNotes,
              body: strings.howToPlayHoldAConversationWithoutTyping,
            ),
          ],
        ),
      ],
    );
  }
}

class _CheckersGuide extends StatelessWidget {
  const _CheckersGuide();

  @override
  Widget build(BuildContext context) {
    return _Guide(
      game: GameKind.checkers,
      intro: strings.howToPlayTwoPlayersTwelvePiecesEach,
      sections: [
        _Section(
          title: strings.howToPlayHowPiecesMove,
          icon: Icons.open_with_rounded,
          color: AppColors.sky,
          children: [
            _DiscRule(
              king: false,
              title: strings.howToPlayMen,
              body: strings.howToPlayEveryPieceStartsAsA,
            ),
            _DiscRule(
              king: true,
              title: strings.howToPlayKings,
              body: strings.howToPlayAManThatReachesThe,
            ),
          ],
        ),
        _Section(
          title: strings.howToPlayTakingPieces,
          icon: Icons.bolt_rounded,
          color: Color(0xFFFF7A45),
          children: [
            RuleRow(
              icon: Icons.call_made_rounded,
              color: Color(0xFFFF7A45),
              title: strings.howToPlayJumpToTake,
              body: strings.howToPlayJumpDiagonallyOverAnOpponent,
            ),
            RuleRow(
              icon: Icons.priority_high_rounded,
              color: Color(0xFFFF5C6C),
              title: strings.howToPlayTakingIsAMust,
              body: strings.howToPlayIfYouCanTakeA,
            ),
            RuleRow(
              icon: Icons.all_inclusive_rounded,
              color: Color(0xFFFFC94D),
              title: strings.howToPlayMultiJumps,
              body: strings.howToPlayAfterAJumpIfThe,
            ),
          ],
        ),
        _Section(
          title: strings.howToPlayWinning,
          icon: Icons.emoji_events_rounded,
          color: Color(0xFFFFC94D),
          children: [
            RuleRow(
              icon: Icons.flag_rounded,
              color: Color(0xFFFFC94D),
              title: strings.howToPlayNoMovesNoGame,
              body: strings.howToPlayTakeAllOfYourOpponent,
            ),
            RuleRow(
              icon: Icons.handshake_rounded,
              color: Color(0xFF4DA3FF),
              title: strings.howToPlayDraws,
              body: strings.howToPlayIfOnlyKingsMoveFor,
            ),
          ],
        ),
        _Section(
          title: strings.howToPlayPlayingInUtopia,
          icon: Icons.public_rounded,
          color: Color(0xFF2DE0C2),
          children: [
            RuleRow(
              icon: Icons.timer_rounded,
              color: Color(0xFFFF5C9C),
              title: strings.howToPlayClocksEntriesAndChat,
              body: strings.howToPlayTheSameAsChessYour,
            ),
            RuleRow(
              icon: Icons.wifi_off_rounded,
              color: Color(0xFF8FD8FF),
              title: strings.howToPlayOffline,
              body: strings.howToPlayPlayChipOrRoboAt,
            ),
            RuleRow(
              icon: Icons.palette_rounded,
              color: Color(0xFFB27BFF),
              title: strings.howToPlayYourPieces,
              body: strings.howToPlayYourPiecesWearYourChess,
            ),
          ],
        ),
      ],
    );
  }
}

/// A rule with a checkers piece beside it.
class _PoolGuide extends StatelessWidget {
  const _PoolGuide();

  @override
  Widget build(BuildContext context) {
    return _Guide(
      game: GameKind.pool,
      intro: strings.poolGuideIntro,
      sections: [
        _Section(
          title: strings.poolGuideShooting,
          icon: Icons.sports_baseball_rounded,
          color: AppColors.sky,
          children: [
            RuleRow(
              icon: Icons.touch_app_rounded,
              color: AppColors.sky,
              title: strings.poolGuideAimTitle,
              body: strings.poolGuideAimBody,
            ),
            RuleRow(
              icon: Icons.south_rounded,
              color: Color(0xFF2FD98E),
              title: strings.poolGuidePowerTitle,
              body: strings.poolGuidePowerBody,
            ),
            RuleRow(
              icon: Icons.adjust_rounded,
              color: Color(0xFFFF5C6C),
              title: strings.poolGuideSpinTitle,
              body: strings.poolGuideSpinBody,
            ),
          ],
        ),
        _Section(
          title: strings.poolGuideRules,
          icon: Icons.rule_rounded,
          color: Color(0xFFFFC94D),
          children: [
            RuleRow(
              icon: Icons.blur_on_rounded,
              color: Color(0xFFFFC94D),
              title: strings.poolGuideGroupsTitle,
              body: strings.poolGuideGroupsBody,
            ),
            RuleRow(
              icon: Icons.warning_amber_rounded,
              color: Color(0xFFFF7A45),
              title: strings.poolGuideFoulsTitle,
              body: strings.poolGuideFoulsBody,
            ),
            RuleRow(
              icon: Icons.emoji_events_rounded,
              color: Color(0xFFB45CFF),
              title: strings.poolGuideEightTitle,
              body: strings.poolGuideEightBody,
            ),
          ],
        ),
        _Section(
          title: strings.howToPlayPlayingInUtopia,
          icon: Icons.public_rounded,
          color: Color(0xFF2DE0C2),
          children: [
            RuleRow(
              icon: Icons.monetization_on_rounded,
              color: Color(0xFFFFC94D),
              title: strings.poolGuideTablesTitle,
              body: strings.poolGuideTablesBody,
            ),
            RuleRow(
              icon: Icons.auto_awesome_rounded,
              color: Color(0xFFFF4F7B),
              title: strings.poolGuideCuesTitle,
              body: strings.poolGuideCuesBody,
            ),
          ],
        ),
      ],
    );
  }
}

class _DiscRule extends StatelessWidget {
  const _DiscRule({
    required this.king,
    required this.title,
    required this.body,
  });

  final bool king;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.25),
            ),
            child: CustomPaint(painter: _DiscPainter(king: king)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: AppTextStyles.body(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscPainter extends CustomPainter {
  _DiscPainter({required this.king});

  final bool king;

  @override
  void paint(Canvas canvas, Size size) {
    paintCheckersDisc(
      canvas,
      size.center(Offset.zero).translate(0, king ? 2 : -1),
      size.width * 0.34,
      finish: checkersFinish('classic', CheckersSide.light),
      king: king,
    );
  }

  @override
  bool shouldRepaint(covariant _DiscPainter old) => old.king != king;
}
