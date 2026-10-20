import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/pop_card.dart';
import '../../../core/layout/responsive.dart';
import '../../../l10n/strings.dart';

/// Utopia's privacy policy, in the app (Settings > Privacy policy). The
/// same words are on the website at /privacy.html
/// (utopia-landingpage/public/privacy.html): change both together.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static final updated = strings.privacyOctober202026;

  static final _sections = <(String, List<String>)>[
    (
      strings.privacyWhatWeCollect,
      [
        'Your account. When you play as a guest we create an anonymous account for you. If you save your account, we keep the email address you sign in with.',
        strings.privacyYourProfileTheNameUsername,
        strings.privacyGamesTheGamesYouPlay,
        strings.privacyPurchasesIfYouBuyCoins,
        strings.privacyMessagesChatMessagesAndVoice,
        strings.privacyFriendsFriendRequestsAndYour,
        strings.privacyReportsWhenYouReportA,
        strings.privacyCrashReportsIfTheApp,
        strings.privacyHowYouUseUtopiaWhen,
        strings.privacyChipWhenYouChatWith,
        strings.privacyYourSketchbookDrawingsAreKept,
      ],
    ),
    (
      strings.privacyPermissionsOnYourPhone,
      [
        'Microphone: only while you record a voice note.',
        strings.privacyPhotosToPickAProfile,
        strings.privacyNotificationsGameRemindersAndAlerts,
        strings.privacyNotificationAccessAndroidOrApple,
      ],
    ),
    (
      strings.privacyHowWeUseIt,
      [
        "To run the games and match you with other players, show your profile to them, keep your coins and items, deliver chat and notifications, make Chip reply, fix bugs and improve Utopia, and keep play fair and safe. We don't sell your information, we don't show ads, and we don't use advertising or tracking tools.",
      ],
    ),
    (
      strings.privacyWhoWeShareItWith,
      [
        'Other players see your profile, your messages to them, and your coins unless you turn on "Hide my coins" in Settings.',
        strings.privacySupabaseHostsUtopiaSServers,
        strings.privacyResendDeliversTheSignIn,
        strings.privacySentryReceivesCrashReportsTo,
        strings.privacyAnthropicProcessesChipSChats,
        strings.privacyGoogleDrawsRealPortraitsIt,
        strings.privacyAppleAndGoogleRunThe,
        strings.privacyWeMayAlsoShareInformation,
      ],
    ),
    (
      strings.privacyKeepingAndDeletingIt,
      [
        'We keep your information while you have an account. You can delete your account at any time in Settings > Delete account. That removes your name, username, picture, friends, chat messages, Chip\'s notes about you, the pictures he drew from your photos, notifications and sign-in for good. A small anonymous record of coin movements, coin purchases and finished games is kept, without anything that identifies you, because other players\' game histories and our coin records rely on it.',
      ],
    ),
    (
      strings.privacyChildren,
      [
        "Utopia isn't meant for children under 13, and we don't knowingly collect information from them. If you believe a child under 13 is using Utopia, contact us and we'll delete the account.",
      ],
    ),
    (
      strings.privacyChangesAndContact,
      [
        "If this policy changes, we'll update the date at the top. Questions or requests: use Settings > Report a bug and we'll reply.",
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(strings.privacyPrivacyPolicy)),
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: context.readablePadding(
              top: AppSpacing.sm,
              bottom: AppSpacing.xxl,
            ),
            children: [
              Text(
                strings.privacyLastUpdated(updated),
                style: AppTextStyles.body(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                strings.privacyUtopiaIsAGameApp,
                style: AppTextStyles.body(),
              ),
              for (final (title, lines) in _sections) ...[
                const SizedBox(height: AppSpacing.md),
                PopCard(
                  borderRadius: 22,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.display(fontSize: 18)),
                      for (final line in lines) ...[
                        const SizedBox(height: 8),
                        Text(line, style: AppTextStyles.body(fontSize: 14)),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
