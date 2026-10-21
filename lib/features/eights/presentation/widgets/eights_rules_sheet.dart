import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/pop_card.dart';
import '../../../../l10n/strings.dart';
import '../../../ludo/presentation/widgets/ludo_rules_sheet.dart';
import '../../domain/eights_engine.dart';
import 'card_art.dart';

/// How Crazy Eights is played, short and friendly, with a few cards to
/// show what matches.
Future<void> showEightsRules(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.72,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (context, scroll) => PopCard(
        borderRadius: 28,
        sheet: true,
        padding: EdgeInsets.zero,
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              strings.eightsRulesTitle,
              style: AppTextStyles.display(fontSize: 24),
            ),
            const SizedBox(height: AppSpacing.md),
            // On a 7 of hearts: any heart, any 7, or an eight.
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PlayingCardView(
                  card: PlayingCard(7, CardSuit.hearts),
                  width: 58,
                ),
                SizedBox(width: 10),
                Icon(Icons.arrow_forward_rounded),
                SizedBox(width: 10),
                PlayingCardView(
                  card: PlayingCard(12, CardSuit.hearts),
                  width: 50,
                ),
                SizedBox(width: 6),
                PlayingCardView(
                  card: PlayingCard(7, CardSuit.clubs),
                  width: 50,
                ),
                SizedBox(width: 6),
                PlayingCardView(
                  card: PlayingCard(8, CardSuit.spades),
                  width: 50,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final (icon, color, title, body) in eightsRules)
              RuleRow(icon: icon, color: color, title: title, body: body),
          ],
        ),
      ),
    ),
  );
}

/// The rules: (icon, color, title, explanation).
final eightsRules = [
  (
    Icons.style_rounded,
    const Color(0xFF4DA3FF),
    strings.eightsRulesMatchTitle,
    strings.eightsRulesMatchBody,
  ),
  (
    Icons.auto_awesome_rounded,
    const Color(0xFFB27BFF),
    strings.eightsRulesWildTitle,
    strings.eightsRulesWildBody,
  ),
  (
    Icons.layers_rounded,
    const Color(0xFF3DDC97),
    strings.eightsRulesDrawTitle,
    strings.eightsRulesDrawBody,
  ),
  (
    Icons.timer_rounded,
    const Color(0xFFFF5C9C),
    strings.ludoRulesTimedTurns,
    strings.eightsRulesTimeBody,
  ),
  (
    Icons.emoji_events_rounded,
    const Color(0xFFFFC94D),
    strings.eightsRulesWinTitle,
    strings.eightsRulesWinBody,
  ),
  (
    Icons.logout_rounded,
    const Color(0xFFFF7A7A),
    strings.ludoRulesLeavingEndsYourGame,
    strings.eightsRulesLeaveBody,
  ),
];
