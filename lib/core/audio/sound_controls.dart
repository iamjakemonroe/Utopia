import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import '../widgets/bubble_toggle.dart';
import '../widgets/pop_card.dart';
import 'game_audio.dart';

/// The full sound settings: music and effects switches with volumes.
Future<void> showSoundSettings(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => const _SoundSettingsCard(),
  );
}

class _SoundSettingsCard extends ConsumerWidget {
  const _SoundSettingsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(soundSettingsProvider);
    final controller = ref.read(soundSettingsProvider.notifier);
    final audio = ref.read(gameAudioProvider);

    return PopCard(
      borderRadius: 28,
      sheet: true,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sound', style: AppTextStyles.display(fontSize: 24)),
          const SizedBox(height: AppSpacing.md),
          _SoundRow(
            icon: Icons.music_note_rounded,
            title: 'Music',
            subtitle: 'Dreamy loops in menus, upbeat in games',
            on: settings.musicOn,
            volume: settings.musicVolume,
            onToggle: (v) {
              controller.setMusicOn(v);
              audio.play(v ? Sfx.toggleOn : Sfx.toggleOff);
            },
            onVolume: controller.setMusicVolume,
          ),
          const SizedBox(height: AppSpacing.md),
          _SoundRow(
            icon: Icons.graphic_eq_rounded,
            title: 'Sound effects',
            subtitle: 'Dice, hops, captures and reactions',
            on: settings.sfxOn,
            volume: settings.sfxVolume,
            onToggle: (v) {
              controller.setSfxOn(v);
              // Played after switching on, so turning effects on is audible
              // and turning them off is (correctly) silent.
              if (v) audio.play(Sfx.toggleOn);
            },
            onVolume: controller.setSfxVolume,
            onVolumeEnd: (_) => audio.play(Sfx.tap),
          ),
        ],
      ),
    );
  }
}

class _SoundRow extends StatelessWidget {
  const _SoundRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.on,
    required this.volume,
    required this.onToggle,
    required this.onVolume,
    this.onVolumeEnd,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool on;
  final double volume;
  final ValueChanged<bool> onToggle;
  final ValueChanged<double> onVolume;
  final ValueChanged<double>? onVolumeEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.25),
                border: Border.all(color: AppColors.glowRing, width: 1.2),
              ),
              child: Icon(icon, color: AppColors.textPrimary, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.body(fontWeight: FontWeight.w700),
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
            BubbleToggle(
              value: on,
              onChanged: onToggle,
              onIcon: icon,
              offIcon: Icons.volume_off_rounded,
              semanticLabel: title,
            ),
          ],
        ),
        AnimatedOpacity(
          opacity: on ? 1 : 0.35,
          duration: const Duration(milliseconds: 200),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.accent,
              inactiveTrackColor: AppColors.surfaceElevated,
              thumbColor: AppColors.goldBorderBright,
              overlayColor: AppColors.accent.withValues(alpha: 0.2),
              trackHeight: 5,
            ),
            child: Slider(
              value: volume,
              onChanged: on ? onVolume : null,
              onChangeEnd: onVolumeEnd,
            ),
          ),
        ),
      ],
    );
  }
}

/// The in-game sound switch: a speaker bubble that springs open sideways
/// into music and effects toggles, and folds back when tapped again.
class SoundQuickToggle extends ConsumerStatefulWidget {
  const SoundQuickToggle({super.key});

  @override
  ConsumerState<SoundQuickToggle> createState() => _SoundQuickToggleState();
}

class _SoundQuickToggleState extends ConsumerState<SoundQuickToggle> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(soundSettingsProvider);
    final controller = ref.read(soundSettingsProvider.notifier);
    final audio = ref.read(gameAudioProvider);
    final anyOn = settings.musicOn || settings.sfxOn;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 520),
      curve: Curves.elasticOut,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: AppColors.surface.withValues(alpha: 0.92),
        border: Border.all(color: AppColors.goldBorder, width: 1.6),
        boxShadow: [
          BoxShadow(
            color: AppColors.glowRing.withValues(alpha: 0.35),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              audio.play(Sfx.tap);
              setState(() => _open = !_open);
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.3, -0.4),
                  colors: [
                    Color.lerp(AppColors.accent, Colors.white, 0.35)!,
                    AppColors.accent,
                  ],
                ),
              ),
              child: Icon(
                anyOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                color: Colors.white,
                size: 20,
                semanticLabel: 'Sound settings',
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 520),
            curve: Curves.elasticOut,
            child: _open
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 10),
                      BubbleToggle(
                        width: 54,
                        value: settings.musicOn,
                        onIcon: Icons.music_note_rounded,
                        offIcon: Icons.music_off_rounded,
                        semanticLabel: 'Music',
                        onChanged: (v) {
                          controller.setMusicOn(v);
                          audio.play(v ? Sfx.toggleOn : Sfx.toggleOff);
                        },
                      ),
                      const SizedBox(width: 8),
                      BubbleToggle(
                        width: 54,
                        value: settings.sfxOn,
                        onIcon: Icons.graphic_eq_rounded,
                        offIcon: Icons.volume_off_rounded,
                        semanticLabel: 'Sound effects',
                        onChanged: (v) {
                          controller.setSfxOn(v);
                          if (v) audio.play(Sfx.toggleOn);
                        },
                      ),
                      const SizedBox(width: 6),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
