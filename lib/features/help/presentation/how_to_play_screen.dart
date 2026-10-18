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

/// How to play every game in Utopia: a tab per game, each with its own
/// sections. New games get a tab here as they arrive.
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key, this.initialGame = 0});

  final int initialGame;

  static const _games = [
    (GameKind.chess, 'Chess', Icons.extension_rounded),
    (GameKind.ludo, 'Ludo', Icons.casino_rounded),
    (GameKind.checkers, 'Checkers', Icons.blur_circular_rounded),
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
            title: const Text('How to play'),
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
              children: [_ChessGuide(), _LudoGuide(), _CheckersGuide()],
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

  static const _pieces = [
    (
      PieceType.king,
      'King',
      'One square any way. Keep it safe: if it can be taken and has no escape, the game is lost.',
    ),
    (
      PieceType.queen,
      'Queen',
      'Any number of squares in a straight line or along a diagonal.',
    ),
    (
      PieceType.rook,
      'Rook',
      'Any number of squares straight up, down or across.',
    ),
    (PieceType.bishop, 'Bishop', 'Any number of squares along a diagonal.'),
    (
      PieceType.knight,
      'Knight',
      'Jumps in an L: two squares one way, then one to the side. It can hop over pieces.',
    ),
    (
      PieceType.pawn,
      'Pawn',
      'One square forward (two on its first move) and takes one square diagonally forward.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final style = ChessPieceStyle.byId('classic');
    return _Guide(
      game: GameKind.chess,
      intro:
          'Two players, one board. Out-think your opponent and trap their king.',
      sections: [
        const _Section(
          title: 'The goal',
          icon: Icons.emoji_events_rounded,
          color: Color(0xFFFFC94D),
          children: [
            RuleRow(
              icon: Icons.flag_rounded,
              color: Color(0xFFFFC94D),
              title: 'Checkmate wins',
              body:
                  "Attack the other king so it can't escape. That's checkmate, and the game is yours.",
            ),
            RuleRow(
              icon: Icons.warning_amber_rounded,
              color: Color(0xFFFF7A7A),
              title: 'Check',
              body:
                  'When your king is attacked you must get it out of danger on your very next move.',
            ),
          ],
        ),
        _Section(
          title: 'How the pieces move',
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
        const _Section(
          title: 'Special moves',
          icon: Icons.auto_awesome_rounded,
          color: Color(0xFFB27BFF),
          children: [
            RuleRow(
              icon: Icons.castle_rounded,
              color: Color(0xFFB27BFF),
              title: 'Castling',
              body:
                  "Once a game, your king can step two squares toward a rook and the rook jumps over it, as long as neither has moved, nothing's between them and the king isn't in check.",
            ),
            RuleRow(
              icon: Icons.upgrade_rounded,
              color: Color(0xFF3DDC97),
              title: 'Promotion',
              body:
                  'A pawn that reaches the far side becomes a queen, rook, bishop or knight. You choose.',
            ),
            RuleRow(
              icon: Icons.compare_arrows_rounded,
              color: Color(0xFF4DA3FF),
              title: 'En passant',
              body:
                  'If a pawn rushes two squares past one of yours, you can take it as if it had moved one, on your very next move only.',
            ),
          ],
        ),
        const _Section(
          title: 'Draws',
          icon: Icons.handshake_rounded,
          color: Color(0xFF4DA3FF),
          children: [
            RuleRow(
              icon: Icons.block_rounded,
              color: Color(0xFF4DA3FF),
              title: 'Stalemate',
              body:
                  "If it's your move, you're not in check and you have no legal move, the game is a draw.",
            ),
            RuleRow(
              icon: Icons.balance_rounded,
              color: Color(0xFF9B7BFF),
              title: 'Not enough to win',
              body:
                  "When neither side has enough pieces left to checkmate, it's a draw. Entries go back to both players.",
            ),
          ],
        ),
        const _Section(
          title: 'Playing in Utopia',
          icon: Icons.public_rounded,
          color: Color(0xFF2DE0C2),
          children: [
            RuleRow(
              icon: Icons.timer_rounded,
              color: Color(0xFFFF5C9C),
              title: 'Clocks',
              body:
                  "Each side has its own time. Run out and you lose. Make your first move within 30 seconds or the game is called off and entries are returned.",
            ),
            RuleRow(
              icon: Icons.toll_rounded,
              color: Color(0xFFFFC94D),
              title: 'Entries and prizes',
              body:
                  'Pick a free game or an entry. The winner takes the prize; a draw gives everyone their entry back.',
            ),
            RuleRow(
              icon: Icons.history_rounded,
              color: Color(0xFF5AB8FF),
              title: 'Look back',
              body:
                  'Use the arrows under the board to step through every move, during the game or after it. Tap a move to jump to it.',
            ),
            RuleRow(
              icon: Icons.chat_bubble_rounded,
              color: Color(0xFFB27BFF),
              title: 'Chat',
              body:
                  'Send messages, stickers and voice notes from the chat button. Games with strangers keep it friendly.',
            ),
            RuleRow(
              icon: Icons.logout_rounded,
              color: Color(0xFFFF7A7A),
              title: 'Leaving resigns',
              body:
                  "Leaving a game in progress resigns it. Closed the app by accident? Open it again and you're taken straight back to your game.",
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
      intro:
          'Two to six players race their pieces around the board and home. Roll, capture, and get all four in first.',
      sections: [
        _Section(
          title: 'The basics',
          icon: Icons.casino_rounded,
          color: AppColors.mint,
          children: [
            for (final (icon, color, title, body) in basics)
              RuleRow(icon: icon, color: color, title: title, body: body),
          ],
        ),
        _Section(
          title: 'Winning',
          icon: Icons.emoji_events_rounded,
          color: const Color(0xFFFFC94D),
          children: [
            for (final (icon, color, title, body) in more)
              RuleRow(icon: icon, color: color, title: title, body: body),
          ],
        ),
        const _Section(
          title: 'Playing with friends',
          icon: Icons.groups_rounded,
          color: Color(0xFFFF8FB8),
          children: [
            RuleRow(
              icon: Icons.vpn_key_rounded,
              color: Color(0xFFFF8FB8),
              title: 'Rooms',
              body:
                  'Make a room and share its code. Friends join with the code and the host starts the game.',
            ),
            RuleRow(
              icon: Icons.event_seat_rounded,
              color: Color(0xFF4DA3FF),
              title: 'Pick your seat',
              body:
                  'In a room, tap an empty seat to sit there and play that color, or share an invite to it.',
            ),
            RuleRow(
              icon: Icons.mic_rounded,
              color: Color(0xFFB27BFF),
              title: 'Voice notes',
              body:
                  'Hold a conversation without typing: record up to 30 seconds and it plays for everyone at the table.',
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
      intro:
          'Two players, twelve pieces each, on the dark squares of an 8x8 board. Dark moves first.',
      sections: [
        _Section(
          title: 'How pieces move',
          icon: Icons.open_with_rounded,
          color: AppColors.sky,
          children: [
            _DiscRule(
              king: false,
              title: 'Men',
              body:
                  'Every piece starts as a man. A man moves one square diagonally forward, onto an empty dark square.',
            ),
            _DiscRule(
              king: true,
              title: 'Kings',
              body:
                  'A man that reaches the far row is crowned king. Kings move one square diagonally forward or backward.',
            ),
          ],
        ),
        const _Section(
          title: 'Taking pieces',
          icon: Icons.bolt_rounded,
          color: Color(0xFFFF7A45),
          children: [
            RuleRow(
              icon: Icons.call_made_rounded,
              color: Color(0xFFFF7A45),
              title: 'Jump to take',
              body:
                  "Jump diagonally over an opponent's piece to an empty square right behind it, and that piece is taken. Men jump forward only; kings jump either way.",
            ),
            RuleRow(
              icon: Icons.priority_high_rounded,
              color: Color(0xFFFF5C6C),
              title: 'Taking is a must',
              body:
                  "If you can take a piece, you have to. The pieces that can take glow orange, and you choose which jump to make if there's more than one.",
            ),
            RuleRow(
              icon: Icons.all_inclusive_rounded,
              color: Color(0xFFFFC94D),
              title: 'Multi-jumps',
              body:
                  "After a jump, if the same piece can jump again, it keeps going in the same move. A man that's crowned mid-jump stops there.",
            ),
          ],
        ),
        const _Section(
          title: 'Winning',
          icon: Icons.emoji_events_rounded,
          color: Color(0xFFFFC94D),
          children: [
            RuleRow(
              icon: Icons.flag_rounded,
              color: Color(0xFFFFC94D),
              title: 'No moves, no game',
              body:
                  "Take all of your opponent's pieces, or leave them with no move to make, and you win.",
            ),
            RuleRow(
              icon: Icons.handshake_rounded,
              color: Color(0xFF4DA3FF),
              title: 'Draws',
              body:
                  "If only kings move for forty moves each, with nothing taken, it's a draw. Entries go back to both players.",
            ),
          ],
        ),
        const _Section(
          title: 'Playing in Utopia',
          icon: Icons.public_rounded,
          color: Color(0xFF2DE0C2),
          children: [
            RuleRow(
              icon: Icons.timer_rounded,
              color: Color(0xFFFF5C9C),
              title: 'Clocks, entries and chat',
              body:
                  'The same as chess: your own clock, free games or an entry, every move to look back on, and chat with stickers and voice notes. Make your first move within 30 seconds.',
            ),
            RuleRow(
              icon: Icons.wifi_off_rounded,
              color: Color(0xFF8FD8FF),
              title: 'Offline',
              body:
                  'Play Chip or Robo at three levels, or pass one phone between two players. No internet needed.',
            ),
            RuleRow(
              icon: Icons.palette_rounded,
              color: Color(0xFFB27BFF),
              title: 'Your pieces',
              body:
                  'Your pieces wear your chess set. Buddies, Monsters and Robots get faces that watch the game.',
            ),
          ],
        ),
      ],
    );
  }
}

/// A rule with a checkers piece beside it.
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
