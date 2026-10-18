import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/pop_card.dart';

/// Utopia's privacy policy, in the app (Settings > Privacy policy). The
/// same words are on the website at /privacy.html
/// (utopia-landingpage/public/privacy.html): change both together.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const updated = 'October 20, 2026';

  static const _sections = <(String, List<String>)>[
    (
      'What we collect',
      [
        'Your account. When you play as a guest we create an anonymous account for you. If you save your account, we keep the email address you sign in with.',
        'Your profile. The name, username and picture you choose (a picture you upload is stored so other players can see it), the world, piece sets and aura you wear, and your coin balance.',
        "Games. The games you play and their moves and results, your coin history (coins are virtual, have no cash value and can't be cashed out), and the items you own or rent. In Guess My Doodle, what you draw is shown live to the players in that game and kept only until the turn is over; a game's chat and guesses are deleted a day after it ends.",
        "Purchases. If you buy coins, Apple or Google take the payment, and we never see your card or bank details. We get the purchase's ID, the pack, when it was bought and whether it was refunded, so we can add your coins once and take them back if the payment is refunded. If you join Chip Maestro, Apple or Google handle the subscription; we keep its ID, plan and renewal dates so we know you're a member.",
        'Messages. Chat messages and voice notes you send in games and to friends. Voice notes are only available to the players in that game.',
        'Friends. Friend requests and your friends list.',
        'Reports. When you report a bug or suggest a feature: what you write, an optional screenshot, an optional email for follow-up, and the app version, phone system, screen and world you were in.',
        "Crash reports. If the app crashes, a report of what went wrong (the error, your phone's model and system version, and the app version) goes to Sentry, which helps us fix it. It doesn't include your name, messages or anything you've made.",
        "How you use Utopia. When the app opens, the screens you go to, and when you finish a game, buy something, earn a reward, share an invite or chat with Chip (not what you say), so we can see what works and fix what doesn't. It stays in our own database: it's never sold or given to advertisers, and it's deleted with your account.",
        "Chip. When you chat with Chip, your messages and some context from the app (your first name, the time, the screen and world you're on, and your coins, worlds and aura) are used to write his replies. Your conversation is kept on your phone until you start a new chat. Chip can also keep a few short notes about things you tell him, like a plan or a favourite world, so he can follow up next time; ask him to forget and he deletes them. If you send Chip a photo, it's used to draw your picture and isn't kept on our servers; it stays on your phone until you start a new chat, and a picture drawn from it is visible only to you. When Chip colors a picture for you, the picture is sent to him to choose the colors. A real portrait is drawn from your photo or the name you give. One from your photo is kept privately for you; one of a famous person is shared with other Chip Maestro members who ask for them. If you let Chip see what you're playing in other apps, the title and artist of the song, video or podcast are used for his reaction to it.",
        'Your Sketchbook drawings are kept only on your phone, unless you choose to save one to your photos.',
      ],
    ),
    (
      'Permissions on your phone',
      [
        'Microphone: only while you record a voice note.',
        'Photos: to pick a profile picture or a screenshot for a report, and to save your drawings to your photos when you ask.',
        'Notifications: game reminders and alerts, which you can turn off in Settings.',
        "Notification access (Android) or Apple Music (iPhone): optional, so Chip can see what's playing. You can turn it off any time in your phone's settings.",
      ],
    ),
    (
      'How we use it',
      [
        "To run the games and match you with other players, show your profile to them, keep your coins and items, deliver chat and notifications, make Chip reply, fix bugs and improve Utopia, and keep play fair and safe. We don't sell your information, we don't show ads, and we don't use advertising or tracking tools.",
      ],
    ),
    (
      'Who we share it with',
      [
        'Other players see your profile, your messages to them, and your coins unless you turn on "Hide my coins" in Settings.',
        "Supabase hosts Utopia's servers and stores the information above (in the European Union, Ireland).",
        'Resend delivers the sign-in codes we email you.',
        'Sentry receives crash reports, to help us fix what went wrong.',
        "Anthropic processes Chip's chats, the photos you send him and what's-playing details to write his replies and draw and color your pictures. It doesn't use them to train its models.",
        'Google draws real portraits: it gets the photo or name for that portrait, under its paid API terms.',
        'Apple and Google run the app stores Utopia comes from, and take the payment when you buy coins.',
        'We may also share information if the law requires it, or to protect players and Utopia.',
      ],
    ),
    (
      'Keeping and deleting it',
      [
        'We keep your information while you have an account. You can delete your account at any time in Settings > Delete account. That removes your name, username, picture, friends, chat messages, Chip\'s notes about you, the pictures he drew from your photos, notifications and sign-in for good. A small anonymous record of coin movements, coin purchases and finished games is kept, without anything that identifies you, because other players\' game histories and our coin records rely on it.',
      ],
    ),
    (
      'Children',
      [
        "Utopia isn't meant for children under 13, and we don't knowingly collect information from them. If you believe a child under 13 is using Utopia, contact us and we'll delete the account.",
      ],
    ),
    (
      'Changes and contact',
      [
        "If this policy changes, we'll update the date at the top. Questions or requests: use Settings > Report a bug and we'll reply.",
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy policy')),
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xxl,
            ),
            children: [
              Text(
                'Last updated $updated',
                style: AppTextStyles.body(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Utopia is a game app for chess, checkers, Ludo and Guess My Doodle, with animated worlds and a mascot called Chip. This policy explains what information Utopia collects, why, who it\'s shared with, and the choices you have.',
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
