import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/analytics.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/profiles/profile_providers.dart';
import '../../../core/widgets/utopia_toast.dart';
import '../../../l10n/strings.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../profile/presentation/widgets/avatar_picker.dart';

/// A new player's first step: choosing the picture friends see, one of the
/// drawn ones or a photo of their own. Sign-up already gave them a drawn
/// one at random, so skipping keeps that. Not asked of someone who already
/// has a photo. Never throws.
Future<void> showPictureStep(BuildContext context, WidgetRef ref) async {
  final me = ref.read(currentUserProvider)?.id;
  if (me == null) return;
  Map<String, dynamic>? profile;
  try {
    profile = await ref.read(profileByIdProvider(me).future);
  } catch (_) {}
  if (profile?['avatar_url'] != null || !context.mounted) return;

  ref.read(gameAudioProvider).play(Sfx.drawer);
  final choice = await showModalBottomSheet<AvatarChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AvatarPickerSheet(
      currentKind: profile?['avatar_kind'] as String?,
      currentSeed: (profile?['avatar_seed'] as num?)?.toInt(),
      title: strings.welcomePictureTitle,
      body: strings.welcomePictureBody,
      skipLabel: strings.welcomePictureSkip,
    ),
  );
  final analytics = ref.read(analyticsProvider);
  if (choice == null) {
    analytics.log('picture_step', {'chose': 'skip'});
    return;
  }
  try {
    final repository = ref.read(profileRepositoryProvider);
    if (choice.kind == null) {
      final photo = await pickAvatarPhoto();
      if (photo == null) {
        analytics.log('picture_step', {'chose': 'skip'});
        return;
      }
      await repository.replaceAvatarPhoto(
        userId: me,
        bytes: photo.$1,
        fileExtension: photo.$2,
      );
    } else {
      await repository.useGeneratedAvatar(
        userId: me,
        kind: choice.kind!,
        seed: choice.seed!,
      );
    }
    analytics.log('picture_step', {
      'chose': choice.kind == null ? 'photo' : 'drawn',
    });
    ref.invalidate(profileByIdProvider(me));
    ref.read(gameAudioProvider).play(Sfx.reaction);
  } catch (e) {
    if (context.mounted) {
      showUtopiaToast(
        context,
        friendlyError(e, fallback: strings.profileCouldnTChangeYourAvatar),
        kind: ToastKind.error,
      );
    }
  }
}
