import 'dart:ui';

import 'package:flutter/material.dart';

import '../audio/game_audio.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import 'pop_card.dart';
import 'primary_button.dart';

/// Shows [builder]'s content in a dialog that springs in like a bubble
/// (and shrinks away), over a softly blurred backdrop.
Future<T?> showBouncyDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool dismissible = true,
  GameAudio? audio,
}) {
  audio?.play(Sfx.drawer);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 520),
    pageBuilder: (context, _, _) =>
        SafeArea(child: Center(child: builder(context))),
    transitionBuilder: (context, animation, _, child) {
      final pop = animation.status == AnimationStatus.reverse
          ? Curves.easeInBack.transform(animation.value)
          : Curves.elasticOut.transform(animation.value);
      return BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 6 * animation.value,
          sigmaY: 6 * animation.value,
        ),
        child: Opacity(
          opacity: Curves.easeOut.transform(animation.value.clamp(0, 1)),
          child: Transform.scale(scale: 0.6 + 0.4 * pop, child: child),
        ),
      );
    },
  );
}

/// A yes/no question in a bouncy dialog. Returns true when confirmed.
Future<bool> confirmBouncy({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
  Widget? hero,
  GameAudio? audio,
}) async {
  final result = await showBouncyDialog<bool>(
    context: context,
    audio: audio,
    builder: (context) => ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Material(
          type: MaterialType.transparency,
          child: PopCard(
            borderRadius: 28,
            glow: destructive ? AppColors.error : null,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hero != null) ...[
                  hero,
                  const SizedBox(height: AppSpacing.sm),
                ],
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.display(fontSize: 22),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: confirmLabel,
                  color: destructive ? AppColors.error : null,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(cancelLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  return result ?? false;
}
