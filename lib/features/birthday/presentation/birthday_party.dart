import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/profiles/profile_providers.dart';
import '../../../core/profiles/profile_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/utopia_themes.dart';
import '../../../core/widgets/coin_buddy.dart';
import '../../../core/widgets/confetti_burst.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auras/data/aura_repository.dart';
import '../../auras/domain/aura.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../store/presentation/store_controller.dart';
import '../../store/presentation/theme_teleport.dart';
import '../data/birthday_repository.dart';
import 'birthday_providers.dart';
import '../../../l10n/strings.dart';

String _returnAuraKey(String userId) => 'aura.returnTo.$userId';
String _celebratedKey(String userId) => 'birthday.celebrated.$userId';

/// On the player's birthday, the first time home opens: the Birthday world
/// and frame (until their midnight), a trip there through the portal, and,
/// once a year, Chip's happy birthday. Any other day, puts back the frame
/// they wore before their birthday if it's still theirs. Returns whether it
/// showed anything.
Future<bool> celebrateBirthdayIfToday(
  BuildContext context,
  WidgetRef ref,
) async {
  final me = ref.read(currentUserProvider)?.id;
  if (me == null) return false;
  final prefs = ref.read(sharedPreferencesProvider);
  final saved = await ref
      .read(myBirthdayProvider.future)
      .catchError((Object _) => null);
  final now = DateTime.now();

  if (saved == null || !saved.birthday.isOn(now)) {
    await _wearAgainAfterBirthday(ref, me);
    return false;
  }

  DateTime? until;
  try {
    until = await ref
        .read(birthdayRepositoryProvider)
        .start(DateTime(now.year, now.month, now.day + 1));
  } catch (_) {
    return false;
  }
  if (until == null || !context.mounted) return false;

  // Where they were, to go back to after.
  final current = ref.read(themeControllerProvider);
  if (current.id != UtopiaThemes.utopiaBirthday.id) {
    await prefs.setString(returnWorldKey(me), current.id);
  }
  final profile = await ref
      .read(profileByIdProvider(me).future)
      .catchError((Object _) => null);
  final wearing = activeAura(profile);
  if (wearing != null && wearing != Aura.birthdayFrame.id) {
    await prefs.setString(_returnAuraKey(me), wearing);
  }
  await ref.read(storeControllerProvider.notifier).refresh();
  ref.invalidate(profileByIdProvider(me));

  if (current.id != UtopiaThemes.utopiaBirthday.id) {
    ref
        .read(themeTeleportProvider.notifier)
        .travelTo(UtopiaThemes.utopiaBirthday);
  }

  if (prefs.getInt(_celebratedKey(me)) == now.year) return false;
  await prefs.setInt(_celebratedKey(me), now.year);
  // After the trip lands.
  await Future<void>.delayed(const Duration(milliseconds: 2600));
  if (!context.mounted) return false;
  final name = profileDisplayName(profile, me);
  ref.read(gameAudioProvider).play(Sfx.win);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BirthdaySheet(name: name),
  );
  return true;
}

/// The day after: back into the frame they wore before, if it's still
/// theirs (the world is handled by the store as the Birthday world closes).
Future<void> _wearAgainAfterBirthday(WidgetRef ref, String me) async {
  final prefs = ref.read(sharedPreferencesProvider);
  final previous = prefs.getString(_returnAuraKey(me));
  if (previous == null) return;
  final profile = await ref
      .read(profileByIdProvider(me).future)
      .catchError((Object _) => null);
  if (activeAura(profile) == Aura.birthdayFrame.id) return; // still the day
  await prefs.remove(_returnAuraKey(me));
  if (activeAura(profile) != null) return; // they've picked another since
  try {
    await ref.read(auraRepositoryProvider).equip(previous);
    ref.invalidate(profileByIdProvider(me));
  } catch (_) {
    // Their time in it ran out meanwhile: nothing to put back.
  }
}

class _BirthdaySheet extends StatelessWidget {
  const _BirthdaySheet({required this.name});

  final String name;

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
                  const CoinBuddy(
                    mood: BuddyMood.excited,
                    size: 120,
                    party: true,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    strings.birthdayPartyHappyBirthday(name),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.display(fontSize: 28),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    strings.birthdayPartyYourOwnBirthdayWorldIs,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: strings.birthdayPartyLetSParty,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(child: ConfettiBurst(pieces: 90)),
          ),
        ],
      ),
    );
  }
}
