import 'package:flutter/material.dart';

import '../../../../core/widgets/pop_card.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/entry_selector.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../chess/domain/time_control.dart';
import '../../../chess/presentation/widgets/time_control_style.dart';

/// What a challenge is for: the game ('chess' or 'checkers'), the clock
/// and each player's entry.
typedef ChessChallenge = ({String game, TimeControl time, int entry});

/// The board game a new challenge starts on: the last lobby the player
/// opened, so "Play a friend" from Checkers sends a checkers challenge.
final inviteGameHint = ValueNotifier<String>('chess');

/// Sheet for setting up a challenge before it's sent. Returns the choice,
/// or null if the player backed out.
Future<ChessChallenge?> showInviteStakeSheet(
  BuildContext context, {
  required String opponentName,
}) {
  return showModalBottomSheet<ChessChallenge>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.surfaceElevated, AppColors.background],
        ),
        border: sheetBorder(AppColors.goldBorder),
      ),
      child: _ChallengeSheet(opponentName: opponentName),
    ),
  );
}

class _ChallengeSheet extends StatefulWidget {
  const _ChallengeSheet({required this.opponentName});

  final String opponentName;

  @override
  State<_ChallengeSheet> createState() => _ChallengeSheetState();
}

class _ChallengeSheetState extends State<_ChallengeSheet> {
  TimeControl _time = TimeControl.standard;
  int _entry = 0;
  String _game = inviteGameHint.value;

  Widget _gameChoice(String game, String label, IconData icon) {
    final on = _game == game;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _game = game),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: on
                  ? [
                      Color.lerp(AppColors.accent, Colors.white, 0.25)!,
                      AppColors.accent,
                    ]
                  : [AppColors.surfaceElevated, AppColors.surface],
            ),
            border: Border.all(
              color: on
                  ? AppColors.goldBorderBright
                  : AppColors.glowRing.withValues(alpha: 0.35),
              width: on ? 2 : 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: on ? AppColors.onAccent : AppColors.textPrimary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.body(
                  fontWeight: FontWeight.w800,
                  color: on ? AppColors.onAccent : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sports_esports_rounded,
                  color: AppColors.accentSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.opponentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.display(fontSize: 22),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                _gameChoice('chess', 'Chess', Icons.extension_rounded),
                const SizedBox(width: 8),
                _gameChoice(
                  'checkers',
                  'Checkers',
                  Icons.blur_circular_rounded,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TimeControlPicker(
              value: _time,
              onChanged: (t) => setState(() => _time = t),
            ),
            const SizedBox(height: AppSpacing.lg),
            EntrySelector(
              options: kChessEntries,
              value: _entry,
              players: 2,
              onChanged: (v) => setState(() => _entry = v),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Send challenge',
              onPressed: () => Navigator.of(
                context,
              ).pop((game: _game, time: _time, entry: _entry)),
            ),
          ],
        ),
      ),
    );
  }
}
