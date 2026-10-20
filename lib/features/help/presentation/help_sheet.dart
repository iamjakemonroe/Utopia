import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pop_card.dart';
import '../../../core/widgets/utopia_icons.dart';
import '../../../l10n/strings.dart';

/// Help & feedback, from the side menu: how to play, report a bug, or
/// suggest a feature. [from] is the screen the player was on (a report
/// says which).
Future<void> showHelpSheet(BuildContext context, {required String from}) {
  final router = GoRouter.of(context);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      void go(String location) {
        Navigator.of(context).pop();
        router.push(location);
      }

      return Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.surfaceElevated, AppColors.background],
          ),
          border: Border(
            top: BorderSide(color: AppColors.goldBorder, width: 2),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              10,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  strings.helpHelpFeedback,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.display(fontSize: 24),
                ),
                const SizedBox(height: AppSpacing.md),
                _Row(
                  icon: Icons.menu_book_rounded,
                  color: const Color(0xFFFF8A3D),
                  title: strings.helpHowToPlay,
                  subtitle: strings.helpTheRulesOfEveryGame,
                  onTap: () => go('/how-to-play'),
                ),
                const SizedBox(height: AppSpacing.sm),
                _Row(
                  icon: Icons.bug_report_rounded,
                  color: AppColors.coral,
                  title: strings.helpReportABug,
                  subtitle: strings.helpSomethingNotWorkingWeLl,
                  onTap: () =>
                      go('/report-bug?from=${Uri.encodeQueryComponent(from)}'),
                ),
                const SizedBox(height: AppSpacing.sm),
                _Row(
                  icon: Icons.lightbulb_rounded,
                  color: AppColors.coinGold,
                  title: strings.helpSuggestAFeature,
                  subtitle: strings.helpIdeasForGamesWorldsAnything,
                  onTap: () => go(
                    '/report-bug?kind=idea&from=${Uri.encodeQueryComponent(from)}',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PopCard(
      borderRadius: 20,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                GlossyBadge(icon: icon, color: color, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.body(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        subtitle,
                        style: AppTextStyles.body(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
