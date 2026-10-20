import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/pop_card.dart';
import '../../../../core/widgets/utopia_icons.dart';
import '../../../../l10n/strings.dart';

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
                strings.ludoRulesHowToPlayLudo,
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
final ludoRules = [
  (
    Icons.casino_rounded,
    Color(0xFF4DA3FF),
    strings.ludoRulesRollA6ToStart,
    strings.ludoRulesEachPieceWaitsInYour,
  ),
  (
    Icons.directions_run_rounded,
    Color(0xFF3DDC97),
    strings.ludoRulesRaceAroundTheBoard,
    strings.ludoRulesPiecesMoveByTheNumber,
  ),
  (
    Icons.timer_rounded,
    Color(0xFFFF5C9C),
    strings.ludoRulesTimedTurns,
    strings.ludoRulesTheRingAroundYourPicture,
  ),
  (
    Icons.bolt_rounded,
    Color(0xFFFF8A3D),
    strings.ludoRulesCaptureToSendThemHome,
    strings.ludoRulesLandExactlyOnAnOpponent,
  ),
  (
    Icons.theater_comedy_rounded,
    Color(0xFFB27BFF),
    strings.ludoRulesWarOrPeace,
    strings.ludoRulesAfterACapturePickA,
  ),
  (
    Icons.star_rounded,
    Color(0xFFFFC94D),
    strings.ludoRulesBonusRolls,
    strings.ludoRulesRollingA6CapturingOr,
  ),
  (
    Icons.flag_rounded,
    Color(0xFF3DDC97),
    strings.ludoRulesGetAllFourHome,
    strings.ludoRulesGoUpYourOwnColored,
  ),
  (
    Icons.logout_rounded,
    Color(0xFFFF7A7A),
    strings.ludoRulesLeavingEndsYourGame,
    strings.ludoRulesIfYouLeaveYouLose,
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
