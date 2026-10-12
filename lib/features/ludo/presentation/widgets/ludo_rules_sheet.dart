import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/pop_card.dart';
import '../../../../core/widgets/utopia_icons.dart';

/// The rules of Utopia Ludo, short and friendly.
Future<void> showLudoRules(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (context, scroll) => Padding(
        padding: EdgeInsets.zero,
        child: PopCard(
          borderRadius: 28,
          sheet: true,
          padding: EdgeInsets.zero,
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                'How to play Ludo',
                style: AppTextStyles.display(fontSize: 24),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final (icon, color, title, body) in ludoRules)
                RuleRow(icon: icon, color: color, title: title, body: body),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Ludo's rules: (icon, color, title, explanation).
const ludoRules = [
  (
    Icons.casino_rounded,
    Color(0xFF4DA3FF),
    'Roll a 6 to start',
    'Each piece waits in your yard until you roll a 6. Then it hops out onto your start square.',
  ),
  (
    Icons.directions_run_rounded,
    Color(0xFF3DDC97),
    'Race around the board',
    'Pieces move by the number you roll. Tap a glowing piece to move it. If only one move is possible, it moves on its own.',
  ),
  (
    Icons.timer_rounded,
    Color(0xFFFF5C9C),
    'Timed turns',
    'The ring around your picture shows your time: 15 seconds a move in public games, 40 with friends. Run out and your turn passes. Miss three turns in a row and you leave the game.',
  ),
  (
    Icons.bolt_rounded,
    Color(0xFFFF8A3D),
    'Capture to send them home',
    'Land exactly on an opponent to send their piece back to its yard. Stars and start squares are safe.',
  ),
  (
    Icons.theater_comedy_rounded,
    Color(0xFFB27BFF),
    'War or peace',
    'After a capture, pick a reaction before the bubble runs out: an evil cackle or a peaceful hug. Everyone sees it.',
  ),
  (
    Icons.star_rounded,
    Color(0xFFFFC94D),
    'Bonus rolls',
    'Rolling a 6, capturing, or getting a piece home earns another roll. Three 6s in a row and you lose the turn.',
  ),
  (
    Icons.flag_rounded,
    Color(0xFF3DDC97),
    'Get all four home',
    'Go up your own colored path into the center. You need the exact number to finish. The first player with all four pieces home wins.',
  ),
  (
    Icons.logout_rounded,
    Color(0xFFFF7A7A),
    'Leaving ends your game',
    'If you leave, you lose this game and your entry stays in the prize. With more than two players, the game carries on.',
  ),
];

/// One rule: a glossy icon, a title and a short explanation.
class RuleRow extends StatelessWidget {
  const RuleRow({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlossyBadge(icon: icon, color: color, size: 42),
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
