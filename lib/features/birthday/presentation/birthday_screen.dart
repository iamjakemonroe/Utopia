import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/coin_buddy.dart';
import '../../../core/widgets/confetti_burst.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/utopia_toast.dart';
import '../../auth/presentation/widgets/auth_world.dart';
import '../../store/presentation/theme_teleport.dart';
import '../data/birthday_repository.dart';
import '../domain/birthday.dart';
import 'birthday_providers.dart';

/// "When's your birthday?": the day and month (never the year), so Chip
/// can throw the player a party every year in a world that only opens on
/// their birthday.
///
/// Right after signing up ([onboarding]), it's the last step before the
/// portal home, and can be skipped. From Settings, it saves and goes back.
class BirthdayScreen extends ConsumerStatefulWidget {
  const BirthdayScreen({super.key, this.onboarding = false});

  final bool onboarding;

  @override
  ConsumerState<BirthdayScreen> createState() => _BirthdayScreenState();
}

class _BirthdayScreenState extends ConsumerState<BirthdayScreen> {
  int? _month;
  int? _day;
  bool _saving = false;
  bool _saved = false;
  bool _seeded = false;

  Birthday? get _choice {
    final month = _month;
    final day = _day;
    if (month == null || day == null || day > Birthday.daysIn(month)) {
      return null;
    }
    return Birthday(month, day);
  }

  void _pickMonth(int month) {
    HapticFeedback.selectionClick();
    ref.read(gameAudioProvider).play(Sfx.tap);
    setState(() {
      _month = month;
      if (_day != null && _day! > Birthday.daysIn(month)) _day = null;
    });
  }

  void _pickDay(int day) {
    HapticFeedback.selectionClick();
    ref.read(gameAudioProvider).play(Sfx.tap);
    setState(() => _day = day);
  }

  Future<void> _save() async {
    final choice = _choice;
    if (choice == null || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(birthdayRepositoryProvider).save(choice);
      ref.invalidate(myBirthdayProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showUtopiaToast(
        context,
        e.toString().contains('birthday locked')
            ? "Your birthday's locked now. Report a bug if it's wrong and we'll fix it."
            : "Couldn't save that. Try again?",
        kind: ToastKind.error,
      );
      return;
    }
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    ref.read(gameAudioProvider).play(Sfx.purchase);
    setState(() {
      _saving = false;
      _saved = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    if (widget.onboarding) {
      _home();
    } else {
      showUtopiaToast(
        context,
        'Saved. Chip will see you on ${choice.label}.',
        kind: ToastKind.success,
        icon: Icons.cake_rounded,
      );
      context.pop();
    }
  }

  /// The last step of signing up: Chip carries them home through the
  /// portal, the same trip as before.
  void _home() {
    final router = GoRouter.of(context);
    final teleporting = ref
        .read(themeTeleportProvider.notifier)
        .welcome(
          ref.read(themeControllerProvider),
          atFlash: () => router.go('/home'),
        );
    if (!teleporting) router.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    // From Settings, start on the birthday they saved.
    final saved = ref.watch(myBirthdayProvider).valueOrNull;
    if (!_seeded && saved != null) {
      _seeded = true;
      _month = saved.birthday.month;
      _day = saved.birthday.day;
    }
    final locked = saved != null && !saved.canChange && !widget.onboarding;
    final choice = _choice;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: !widget.onboarding,
      ),
      body: AppBackground(
        child: Stack(
          children: [
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RiseIn(
                      child: Center(
                        child: CoinBuddy(
                          mood: _saved
                              ? BuddyMood.happy
                              : choice != null
                              ? BuddyMood.excited
                              : BuddyMood.idle,
                          size: 110,
                          party: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _saved ? "It's a date!" : "When's your birthday?",
                      textAlign: TextAlign.center,
                      style: AppTextStyles.display(fontSize: 28),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _saved
                          ? 'Chip will throw you a party on ${choice?.label}.'
                          : 'Chip throws you a party every year, in a world '
                                'that only opens on your birthday.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    RiseIn(
                      delay: 0.15,
                      child: GlassPanel(
                        child: IgnorePointer(
                          ignoring: locked || _saving || _saved,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _Label(
                                icon: Icons.calendar_month_rounded,
                                text: 'Month',
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              _Grid(
                                columns: 4,
                                count: 12,
                                label: (i) =>
                                    Birthday.monthNames[i].substring(0, 3),
                                selected: (i) => _month == i + 1,
                                enabled: (i) => true,
                                onTap: (i) => _pickMonth(i + 1),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              const _Label(
                                icon: Icons.today_rounded,
                                text: 'Day',
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              _Grid(
                                columns: 7,
                                count: 31,
                                label: (i) => '${i + 1}',
                                selected: (i) => _day == i + 1,
                                enabled: (i) =>
                                    _month == null ||
                                    i + 1 <= Birthday.daysIn(_month!),
                                onTap: (i) => _pickDay(i + 1),
                                compact: true,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _Summary(choice: choice),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (locked)
                      Text(
                        "Your birthday's locked. If it's wrong, report a bug "
                        "and we'll fix it.",
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      )
                    else ...[
                      PrimaryButton(
                        label: _saved ? 'Saved!' : 'Save my birthday',
                        isLoading: _saving,
                        onPressed: choice == null || _saved ? null : _save,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_rounded,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Just the day and month, never the year. '
                              'Only you can see it.',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.body(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (widget.onboarding && !_saved) ...[
                        const SizedBox(height: AppSpacing.sm),
                        TextButton(
                          onPressed: _saving ? null : _home,
                          child: const Text('Skip for now'),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            if (_saved)
              const Positioned.fill(
                child: IgnorePointer(child: ConfettiBurst(pieces: 80)),
              ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.accentSecondary),
        const SizedBox(width: 6),
        Text(text, style: AppTextStyles.display(fontSize: 17)),
      ],
    );
  }
}

/// A grid of choices that spring when picked.
class _Grid extends StatelessWidget {
  const _Grid({
    required this.columns,
    required this.count,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.compact = false,
  });

  final int columns;
  final int count;
  final String Function(int) label;
  final bool Function(int) selected;
  final bool Function(int) enabled;
  final void Function(int) onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final rows = (count / columns).ceil();
    return Column(
      children: [
        for (var row = 0; row < rows; row++)
          Padding(
            padding: EdgeInsets.only(bottom: row == rows - 1 ? 0 : 6),
            child: Row(
              children: [
                for (var col = 0; col < columns; col++) ...[
                  if (col > 0) const SizedBox(width: 6),
                  Expanded(
                    child: row * columns + col < count
                        ? _Choice(
                            label: label(row * columns + col),
                            selected: selected(row * columns + col),
                            enabled: enabled(row * columns + col),
                            compact: compact,
                            onTap: () => onTap(row * columns + col),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedScale(
        scale: selected ? 1.08 : 1,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: compact ? 38 : 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 12 : 16),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: selected
                  ? [
                      Color.lerp(AppColors.accent, Colors.white, 0.25)!,
                      AppColors.accent,
                    ]
                  : [
                      AppColors.surfaceElevated.withValues(alpha: 0.9),
                      AppColors.surface.withValues(alpha: 0.9),
                    ],
            ),
            border: Border.all(
              color: selected
                  ? AppColors.goldBorderBright
                  : AppColors.glowRing.withValues(alpha: 0.3),
              width: selected ? 2 : 1.1,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.body(
              fontSize: compact ? 14 : 15,
              fontWeight: FontWeight.w800,
              color: !enabled
                  ? AppColors.textSecondary.withValues(alpha: 0.35)
                  : selected
                  ? AppColors.onAccent
                  : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// What they've picked, as the date of their party.
class _Summary extends StatelessWidget {
  const _Summary({required this.choice});

  final Birthday? choice;

  @override
  Widget build(BuildContext context) {
    final picked = choice;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: (picked == null ? AppColors.surface : AppColors.accent)
            .withValues(alpha: picked == null ? 0.5 : 0.18),
        border: Border.all(
          color: picked == null
              ? AppColors.glowRing.withValues(alpha: 0.25)
              : AppColors.goldBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(
            picked == null ? Icons.redeem_rounded : Icons.celebration_rounded,
            color: picked == null ? AppColors.textSecondary : AppColors.coinGold,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              picked == null
                  ? 'Pick a month and a day'
                  : 'Your party: ${picked.label}',
              style: AppTextStyles.body(
                fontWeight: FontWeight.w800,
                color: picked == null
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
