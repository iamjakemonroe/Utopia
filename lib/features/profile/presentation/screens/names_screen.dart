import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/analytics/analytics.dart';
import '../../../../core/audio/game_audio.dart';
import '../../../../core/layout/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/utopia_toast.dart';
import '../../../auth/presentation/sign_up_steps.dart';
import '../../../auth/presentation/widgets/auth_world.dart';
import '../username_dialog.dart';
import '../../../../l10n/strings.dart';

/// A step of signing up, after the email and before the birthday: the
/// nickname everyone sees (written any way they like) and the username
/// friends find them by, with free usernames offered from the nickname.
class NamesScreen extends ConsumerStatefulWidget {
  const NamesScreen({super.key, this.onboarding = false});

  /// Signing up: on to their birthday (or home) after, and no way back.
  final bool onboarding;

  @override
  ConsumerState<NamesScreen> createState() => _NamesScreenState();
}

class _NamesScreenState extends ConsumerState<NamesScreen> {
  bool _saving = false;

  Future<void> _save(ProfileNames names) async {
    setState(() => _saving = true);
    try {
      await saveProfileNames(ref, names);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showUtopiaToast(
        context,
        friendlyError(e, fallback: strings.namesThatNameDidnTWork),
        kind: ToastKind.error,
      );
      return;
    }
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    ref.read(gameAudioProvider).play(Sfx.reaction);
    ref.read(analyticsProvider).log('names_saved', {
      'onboarding': widget.onboarding,
    });
    final router = GoRouter.of(context);
    if (!widget.onboarding) {
      router.pop();
      return;
    }
    final next = await SignUpSteps.afterNames(ref);
    if (!mounted) return;
    if (next != null) {
      router.go(next);
    } else {
      SignUpSteps.home(ref, router);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: !widget.onboarding,
      ),
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: context.readablePadding(
              maxWidth: 520,
              min: AppSpacing.lg,
              top: AppSpacing.sm,
              bottom: AppSpacing.xl,
            ),
            child: RiseIn(
              child: NamesForm(
                title: strings.namesWhatShouldWeCallYou,
                subtitle: strings.namesYourNicknameIsWhatEveryone,
                submitLabel: strings.namesContinue,
                suggest: true,
                busy: _saving,
                chipSize: 96,
                onSubmit: _save,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
