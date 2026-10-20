import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/profiles/profile_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/utopia_themes.dart';
import '../../../core/widgets/coin_buddy.dart';
import '../../../core/widgets/confetti_burst.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/utopia_toast.dart';
import '../../../core/widgets/utopia_world.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../store/presentation/store_controller.dart';
import '../data/welcome_repository.dart';
import '../../../l10n/strings.dart';

/// Once a session on home: starts a new player's welcome pass (everything
/// in the store, free for three days) and welcomes them to it, reminds
/// them on its last day, and says goodbye once (when it has ended). Never
/// throws.
Future<void> showWelcomeIfDue(BuildContext context, WidgetRef ref) async {
  final me = ref.read(currentUserProvider)?.id;
  if (me == null) return;
  WelcomeWeek? week;
  try {
    week = await ref.read(welcomeRepositoryProvider).start();
  } catch (_) {
    return;
  }
  if (week == null) return;
  ref.read(welcomeWeekProvider.notifier).state = week;
  if (!context.mounted) return;

  if (week.fresh) {
    // Everything lent, and the halo on, shown straight away.
    unawaited(ref.read(storeControllerProvider.notifier).refresh());
    ref.invalidate(profileByIdProvider(me));
    ref.read(gameAudioProvider).play(Sfx.drawer);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WelcomeWeekSheet(until: week!.until),
    );
    return;
  }

  final prefs = _prefs(ref);
  if (week.over) {
    final key = 'welcome_over_seen_$me';
    if (prefs == null || (prefs.getBool(key) ?? false)) return;
    await prefs.setBool(key, true);
    if (!context.mounted) return;
    ref.read(gameAudioProvider).play(Sfx.drawer);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const WelcomeOverSheet(),
    );
    return;
  }

  final left = week.until.difference(DateTime.now());
  final key = 'welcome_last_day_$me';
  if (left < const Duration(hours: 24) &&
      prefs != null &&
      !(prefs.getBool(key) ?? false)) {
    await prefs.setBool(key, true);
    if (!context.mounted) return;
    showUtopiaToast(
      context,
      strings.welcomeWeekLastDayOfYourWelcome,
      icon: Icons.timer_rounded,
    );
  }
}

SharedPreferences? _prefs(WidgetRef ref) {
  try {
    return ref.read(sharedPreferencesProvider);
  } catch (_) {
    return null;
  }
}

final _weekdays = [
  'Mon',
  strings.welcomeWeekTue,
  strings.welcomeWeekWed,
  strings.welcomeWeekThu,
  strings.welcomeWeekFri,
  strings.welcomeWeekSat,
  strings.welcomeWeekSun,
];
final _months = [
  'Jan',
  strings.welcomeWeekFeb,
  strings.welcomeWeekMar,
  strings.welcomeWeekApr,
  strings.welcomeWeekMay,
  strings.welcomeWeekJun,
  strings.welcomeWeekJul,
  strings.welcomeWeekAug,
  strings.welcomeWeekSep,
  strings.welcomeWeekOct,
  strings.welcomeWeekNov,
  strings.welcomeWeekDec,
];

/// "Tue 21 Oct".
String _day(DateTime d) =>
    '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';

/// The sheet's frame: the daily reward's look, a gold rim on top.
class _Sheet extends StatelessWidget {
  const _Sheet({required this.children, this.confetti = false});

  final List<Widget> children;
  final bool confetti;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.surfaceElevated, AppColors.background],
        ),
        border: Border(top: BorderSide(color: AppColors.goldBorder, width: 2)),
      ),
      child: Stack(
        children: [
          SafeArea(
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
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...children,
                ],
              ),
            ),
          ),
          if (confetti)
            const Positioned.fill(child: IgnorePointer(child: ConfettiBurst())),
        ],
      ),
    );
  }
}

/// A small living window onto a world, with its name.
class _WorldPeek extends StatelessWidget {
  const _WorldPeek({required this.theme, required this.index});

  final UtopiaTheme theme;
  final int index;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + index * 140),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Transform.translate(
        offset: Offset(0, 24 * (1 - v)),
        child: Opacity(opacity: v.clamp(0, 1), child: child),
      ),
      child: Column(
        children: [
          Container(
            height: 112,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.trim, width: 2),
              boxShadow: [
                BoxShadow(
                  color: theme.glowRing.withValues(alpha: 0.45),
                  blurRadius: 14,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: UtopiaWorld(style: theme.world),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            theme.name.replaceFirst('Utopia ', ''),
            style: AppTextStyles.body(
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// The welcome: every world and the Angel Halo, free for a week.
class WelcomeWeekSheet extends ConsumerWidget {
  const WelcomeWeekSheet({super.key, required this.until});

  final DateTime until;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider)?.id;
    final profile = me == null
        ? null
        : ref.watch(profileByIdProvider(me)).valueOrNull;
    final name = profile?['display_name'] as String? ?? 'U';
    // The pass's length, as the server set it.
    final days = (until.difference(DateTime.now()).inHours / 24).ceil().clamp(
      1,
      30,
    );
    final worlds = [
      UtopiaThemes.utopiaHeaven,
      UtopiaThemes.utopiaDojo,
      UtopiaThemes.utopiaHell,
    ];
    return _Sheet(
      confetti: true,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CoinBuddy(mood: BuddyMood.excited, size: 84),
            const SizedBox(width: AppSpacing.md),
            UserAvatar.fromProfile(
              profile,
              fallbackInitial: name,
              radius: 34,
              aura: 'halo',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          strings.welcomeWeekEverythingSYoursForDays(days),
          textAlign: TextAlign.center,
          style: AppTextStyles.display(fontSize: 24),
        ),
        const SizedBox(height: 6),
        Text(
          strings.welcomeWeekEveryWorldFrameChessSet(days),
          textAlign: TextAlign.center,
          style: AppTextStyles.body(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            for (final (i, t) in worlds.indexed) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _WorldPeek(theme: t, index: i),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: AppColors.success.withValues(alpha: 0.14),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.card_giftcard_rounded,
                size: 16,
                color: AppColors.success,
              ),
              const SizedBox(width: 6),
              Text(
                strings.welcomeWeekFreeUntil(_day(until)),
                style: AppTextStyles.body(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.readable(AppColors.success),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: strings.welcomeWeekExploreEverything,
          onPressed: () {
            HapticFeedback.mediumImpact();
            final router = ref.read(goRouterProvider);
            Navigator.of(context).pop();
            router.push('/store');
          },
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            strings.welcomeWeekMaybeLater,
            style: AppTextStyles.body(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Goodbye to the welcome pass, and how to keep a favourite.
class WelcomeOverSheet extends ConsumerWidget {
  const WelcomeOverSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Sheet(
      children: [
        const CoinBuddy(mood: BuddyMood.peaceful, size: 96),
        const SizedBox(height: AppSpacing.sm),
        Text(
          strings.welcomeWeekYourWelcomePassIsOver,
          textAlign: TextAlign.center,
          style: AppTextStyles.display(fontSize: 24),
        ),
        const SizedBox(height: 6),
        Text(
          strings.welcomeWeekHopeYouLovedItYour,
          textAlign: TextAlign.center,
          style: AppTextStyles.body(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: strings.welcomeWeekSeeTheStore,
          onPressed: () {
            final router = ref.read(goRouterProvider);
            Navigator.of(context).pop();
            router.push('/store');
          },
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            strings.welcomeWeekNotNow,
            style: AppTextStyles.body(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
