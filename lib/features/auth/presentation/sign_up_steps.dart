import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/profiles/profile_providers.dart';
import '../../../core/theme/theme_controller.dart';
import '../../birthday/data/birthday_repository.dart';
import '../../store/presentation/theme_teleport.dart';
import 'providers/auth_providers.dart';

/// What a player still has to do as they sign up, in order: their names
/// (no username yet), then their birthday (not given yet), then home.
abstract final class SignUpSteps {
  /// Where to go after signing in: the next step, or home (null).
  static Future<String?> afterSignIn(WidgetRef ref) async {
    if (await _needsNames(ref)) return '/names?onboarding=1';
    return afterNames(ref);
  }

  /// Where to go after the names step: the birthday, or home (null).
  static Future<String?> afterNames(WidgetRef ref) async =>
      await _knowsBirthday(ref) ? null : '/birthday?onboarding=1';

  /// The last step: Chip carries them home through the portal, the same
  /// trip as changing worlds, and home appears under the flash.
  static void home(WidgetRef ref, GoRouter router, {void Function()? before}) {
    void go() {
      before?.call();
      router.go('/home');
    }

    final teleporting = ref
        .read(themeTeleportProvider.notifier)
        .welcome(ref.read(themeControllerProvider), atFlash: go);
    if (!teleporting) go();
  }

  /// Straight from the auth client: it has the new session the moment the
  /// code is verified, before the app's own user state catches up.
  static String? _me(WidgetRef ref) =>
      ref.read(authRepositoryProvider).currentUser?.id;

  /// No username yet (a new account). If it can't be checked, it isn't
  /// asked: names can be set any time from the profile.
  static Future<bool> _needsNames(WidgetRef ref) async {
    final me = _me(ref);
    if (me == null) return false;
    try {
      final profile = await ref
          .read(profileRepositoryProvider)
          .fetchById(me)
          .timeout(const Duration(seconds: 4));
      return (profile?['username'] as String?)?.isNotEmpty != true;
    } catch (_) {
      return false;
    }
  }

  /// A new account hasn't given it, so it's always asked; if it can't be
  /// checked, it's asked too (the page has "Skip for now").
  static Future<bool> _knowsBirthday(WidgetRef ref) async {
    final me = _me(ref);
    if (me == null) return false;
    try {
      final saved = await ref
          .read(birthdayRepositoryProvider)
          .fetch(me)
          .timeout(const Duration(seconds: 4));
      return saved != null;
    } catch (_) {
      return false;
    }
  }
}
