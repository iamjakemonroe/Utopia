import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SignOutScope;

import '../../doodle_studio/data/art_store.dart';
import '../../../core/widgets/utopia_loader.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/audio/room_sound.dart';
import '../../../core/settings/gameplay_settings.dart';
import '../../../core/platform/web_install.dart';
import '../../../core/settings/web_scale.dart';
import '../../install/presentation/install_sheet.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/utopia_themes.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/bouncy_dialog.dart';
import '../../../core/widgets/bubble_toggle.dart';
import '../../../core/widgets/coin_buddy.dart';
import '../../../core/widgets/utopia_icons.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../coins/presentation/providers/coin_balance_provider.dart';
import '../../../core/profiles/profile_providers.dart';
import '../../../core/notifications/local_notifications.dart';
import '../../../core/now_playing/now_playing.dart';
import '../../../core/widgets/utopia_toast.dart';
import '../../store/presentation/coin_shop.dart';
import '../../../core/config/env.dart';
import '../../birthday/presentation/birthday_providers.dart';
import '../../maestro/presentation/maestro_providers.dart';
import '../../maestro/presentation/maestro_sheet.dart';
import '../../store/presentation/store_controller.dart';
import '../../../core/layout/responsive.dart';
import '../../coins/data/coin_gift_repository.dart';
import '../../coins/presentation/gift_pin.dart';
import '../../rankings/data/rankings_repository.dart';
import '../../../l10n/strings.dart';

/// "Show my coins" while the change is on its way to the server, so the
/// switch moves at once.
final _showCoinsPending = StateProvider<bool?>((ref) => null);
final _showStatsPending = StateProvider<bool?>((ref) => null);

final _appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sound = ref.watch(soundSettingsProvider);
    final soundCtl = ref.read(soundSettingsProvider.notifier);
    final play = ref.watch(gameplaySettingsProvider);
    final playCtl = ref.read(gameplaySettingsProvider.notifier);
    final musicAccess = ref.watch(nowPlayingProvider.select((m) => m.access));
    final audio = ref.read(gameAudioProvider);
    final isGuest = ref.watch(isAnonymousProvider);
    ref.watch(themeControllerProvider);
    final world = UtopiaThemes.active;
    final version = ref.watch(_appVersionProvider).valueOrNull;
    final myId = ref.watch(currentUserProvider)?.id;
    final myProfile = myId == null
        ? null
        : ref.watch(profileByIdProvider(myId)).valueOrNull;
    final showCoins =
        ref.watch(_showCoinsPending) ??
        (myProfile?['show_coins'] as bool? ?? true);
    final showStats =
        ref.watch(_showStatsPending) ??
        (myProfile?['show_stats'] as bool? ?? true);

    void toggled(bool on) => audio.play(on ? Sfx.toggleOn : Sfx.toggleOff);

    return Scaffold(
      appBar: AppBar(title: Text(strings.settingsSettings)),
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: context.readablePadding(
              top: AppSpacing.xs,
              bottom: AppSpacing.xxl,
            ),
            children: [
              _Section(
                title: strings.settingsSound,
                children: [
                  _ToggleRow(
                    icon: Icons.music_note_rounded,
                    color: const Color(0xFFB27BFF),
                    title: strings.settingsMusic,
                    value: sound.musicOn,
                    onChanged: (v) {
                      soundCtl.setMusicOn(v);
                      toggled(v);
                    },
                  ),
                  _VolumeSlider(
                    enabled: sound.musicOn,
                    value: sound.musicVolume,
                    onChanged: soundCtl.setMusicVolume,
                  ),
                  _ToggleRow(
                    icon: Icons.graphic_eq_rounded,
                    color: const Color(0xFF4DA3FF),
                    title: strings.settingsSoundEffects,
                    value: sound.sfxOn,
                    onChanged: (v) {
                      soundCtl.setSfxOn(v);
                      if (v) audio.play(Sfx.toggleOn);
                    },
                  ),
                  _VolumeSlider(
                    enabled: sound.sfxOn,
                    value: sound.sfxVolume,
                    onChanged: soundCtl.setSfxVolume,
                    onChangeEnd: (_) => audio.play(Sfx.tap),
                  ),
                  _ToggleRow(
                    icon: Icons.mic_rounded,
                    color: const Color(0xFFFF4FD8),
                    title: strings.settingsMusicWorldHearsTheRoom,
                    subtitle: strings.settingsTheShowDancesToThe,
                    value: ref.watch(musicWorldListensProvider),
                    onChanged: (v) {
                      ref.read(musicWorldListensProvider.notifier).set(v);
                      if (v) audio.play(Sfx.toggleOn);
                    },
                  ),
                ],
              ),
              if (kIsWeb)
                _Section(
                  title: strings.settingsScreen,
                  children: [
                    const _ScreenSize(),
                    if (!WebInstall.installed)
                      _LinkRow(
                        icon: Icons.install_mobile_rounded,
                        color: const Color(0xFFFFC94D),
                        title: strings.settingsInstallUtopia,
                        subtitle: strings.settingsPlayFullScreenFromYour,
                        onTap: () => showInstallSheet(context, ref),
                      ),
                  ],
                ),
              _Section(
                title: strings.settingsPlay,
                children: [
                  _ToggleRow(
                    icon: Icons.vibration_rounded,
                    color: const Color(0xFFFF8A3D),
                    title: strings.settingsVibration,
                    subtitle: strings.settingsDiceCapturesYourTurn,
                    value: play.haptics,
                    onChanged: (v) {
                      playCtl.setHaptics(v);
                      toggled(v);
                    },
                  ),
                  _ToggleRow(
                    icon: Icons.timer_rounded,
                    color: const Color(0xFFFF5C9C),
                    title: strings.settingsTimerTicks,
                    subtitle: strings.settingsASoftTickWhenYour,
                    value: play.timerTicks,
                    onChanged: (v) {
                      playCtl.setTimerTicks(v);
                      toggled(v);
                    },
                  ),
                  _ToggleRow(
                    icon: Icons.record_voice_over_rounded,
                    color: AppColors.mint,
                    title: strings.settingsPlayVoiceNotes,
                    subtitle: strings.settingsHearOtherPlayersVoiceNotes,
                    value: play.autoPlayVoice,
                    onChanged: (v) {
                      playCtl.setAutoPlayVoice(v);
                      toggled(v);
                    },
                  ),
                  _ToggleRow(
                    icon: Icons.notifications_active_rounded,
                    color: AppColors.sky,
                    title: strings.settingsGameReminders,
                    subtitle: strings.settingsANudgeToComePlay,
                    value: play.reminders,
                    onChanged: (v) {
                      playCtl.setReminders(v);
                      if (v) LocalNotifications.instance.requestPermission();
                      toggled(v);
                    },
                  ),
                  _ToggleRow(
                    icon: Icons.headphones_rounded,
                    color: AppColors.coinGold,
                    title: strings.settingsShowTheMusicIM,
                    subtitle: strings.settingsChipVibesAlongWithWhat,
                    value: play.showNowPlaying,
                    onChanged: (v) {
                      playCtl.setShowNowPlaying(v);
                      toggled(v);
                    },
                  ),
                  _ToggleRow(
                    icon: Icons.bubble_chart_rounded,
                    color: const Color(0xFF9B8CFF),
                    title: strings.settingsFloatingChip,
                    subtitle: strings.settingsChipFloatsOverEveryScreen,
                    value: play.floatingChip,
                    onChanged: (v) {
                      playCtl.setFloatingChip(v);
                      toggled(v);
                    },
                  ),
                  // The phone has to agree before Chip can see the song.
                  if (play.showNowPlaying && musicAccess == MusicAccess.unknown)
                    _LinkRow(
                      icon: Icons.music_note_rounded,
                      color: AppColors.coinGold,
                      title: strings.settingsLetChipSeeYourMusic,
                      subtitle: !kIsWeb && Platform.isAndroid
                          ? strings.settingsTurnOnNotificationAccessFor
                          : strings.settingsAllowAppleMusicSoChip,
                      onTap: () =>
                          ref.read(nowPlayingProvider.notifier).requestAccess(),
                    ),
                  _ToggleRow(
                    icon: Icons.blur_on_rounded,
                    color: const Color(0xFF3DDC97),
                    title: strings.settingsChessMoveHints,
                    subtitle: strings.settingsShowWhereAPieceCan,
                    value: play.moveHints,
                    onChanged: (v) {
                      playCtl.setMoveHints(v);
                      toggled(v);
                    },
                  ),
                ],
              ),
              _Section(
                title: strings.settingsUtopia,
                children: [
                  _LinkRow(
                    icon: Icons.public_rounded,
                    color: AppColors.mint,
                    title: strings.settingsWorld,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: world.accent,
                            border: Border.all(color: Colors.white70),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          world.name,
                          style: AppTextStyles.body(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    onTap: () => context.push('/collection'),
                  ),
                  _LinkRow(
                    icon: Icons.add_circle_rounded,
                    color: AppColors.coinGold,
                    title: strings.settingsGetCoins,
                    trailing: const CoinIcon(size: 20),
                    onTap: () => showCoinShop(context),
                  ),
                  _LinkRow(
                    icon: Icons.brush_rounded,
                    color: const Color(0xFFFF5C9C),
                    title: strings.settingsChipMaestro,
                    subtitle:
                        (ref.watch(maestroProvider).valueOrNull?.active ??
                            false)
                        ? strings.settingsYouReAMember
                        : strings.settingsRealPortraitsAndMoreFrom,
                    onTap: () => showMaestroSheet(context),
                  ),
                  // App stores require a way to get a subscription back on
                  // a new phone or after a reinstall.
                  if (Env.realMoneyStore)
                    _LinkRow(
                      icon: Icons.restore_rounded,
                      color: AppColors.sky,
                      title: strings.settingsRestorePurchases,
                      subtitle: strings.settingsGotChipMaestroOnAnother,
                      onTap: () =>
                          ref.read(storeControllerProvider.notifier).restore(),
                    ),
                ],
              ),
              _Section(
                title: strings.settingsAccount,
                children: [
                  _LinkRow(
                    icon: Icons.person_rounded,
                    color: AppColors.sky,
                    title: strings.settingsProfile,
                    onTap: () => context.push('/profile'),
                  ),
                  Builder(
                    builder: (context) {
                      final saved = ref.watch(myBirthdayProvider).valueOrNull;
                      return _LinkRow(
                        icon: Icons.cake_rounded,
                        color: const Color(0xFFFF6FAE),
                        title: strings.settingsYourBirthday,
                        subtitle: saved == null
                            ? strings.settingsAddItAndChipThrows
                            : saved.canChange
                            ? strings.settingsYouCanChangeItToday(
                                saved.birthday.label,
                              )
                            : saved.birthday.label,
                        onTap: () => context.push('/birthday'),
                      );
                    },
                  ),
                  _ToggleRow(
                    icon: Icons.monetization_on_rounded,
                    color: AppColors.coinGold,
                    title: strings.settingsShowMyCoins,
                    subtitle: strings.settingsOtherPlayersSeeThemOn,
                    value: showCoins,
                    onChanged: myId == null
                        ? (_) {}
                        : (v) async {
                            toggled(v);
                            ref.read(_showCoinsPending.notifier).state = v;
                            try {
                              await ref
                                  .read(coinRepositoryProvider)
                                  .setShowCoins(v);
                              ref.invalidate(profileByIdProvider(myId));
                              await ref.read(profileByIdProvider(myId).future);
                            } catch (_) {
                              if (context.mounted) {
                                showUtopiaToast(
                                  context,
                                  strings.settingsCouldnTChangeThatTry,
                                  kind: ToastKind.error,
                                );
                              }
                            } finally {
                              ref.read(_showCoinsPending.notifier).state = null;
                            }
                          },
                  ),
                  _ToggleRow(
                    icon: Icons.query_stats_rounded,
                    color: AppColors.sky,
                    title: strings.settingsShowMyStats,
                    subtitle: strings.settingsOthersCanOpenYourRank,
                    value: showStats,
                    onChanged: myId == null
                        ? (_) {}
                        : (v) async {
                            toggled(v);
                            ref.read(_showStatsPending.notifier).state = v;
                            try {
                              await ref
                                  .read(rankingsRepositoryProvider)
                                  .setShowStats(v);
                              ref.invalidate(profileByIdProvider(myId));
                              await ref.read(profileByIdProvider(myId).future);
                            } catch (_) {
                              if (context.mounted) {
                                showUtopiaToast(
                                  context,
                                  strings.settingsCouldnTChangeThatTry,
                                  kind: ToastKind.error,
                                );
                              }
                            } finally {
                              ref.read(_showStatsPending.notifier).state = null;
                            }
                          },
                  ),
                  if (!isGuest)
                    Builder(
                      builder: (context) {
                        final pin = ref
                            .watch(giftPinStatusProvider)
                            .valueOrNull;
                        return _LinkRow(
                          icon: Icons.lock_rounded,
                          color: AppColors.coinGold,
                          title: strings.settingsGiftPin,
                          subtitle: pin == null
                              ? strings.settingsEveryCoinGiftAsksFor
                              : pin.set
                              ? strings.settingsSetEveryCoinGiftAsks
                              : strings.settingsNotSetYetChooseOne,
                          onTap: () => showGiftPinSheet(context),
                        );
                      },
                    ),
                  if (isGuest)
                    _LinkRow(
                      icon: Icons.shield_rounded,
                      color: AppColors.success,
                      title: strings.settingsSaveYourAccount,
                      subtitle: strings.settingsKeepYourCoinsAndWorlds,
                      onTap: () => context.push('/auth/link'),
                    )
                  else
                    _LinkRow(
                      icon: Icons.logout_rounded,
                      color: AppColors.coral,
                      title: strings.settingsSignOut,
                      onTap: () => _signOut(context, ref),
                    ),
                  _LinkRow(
                    icon: Icons.delete_forever_rounded,
                    color: AppColors.error,
                    title: strings.settingsDeleteAccount,
                    subtitle: strings.settingsRemoveYourAccountAndEverything,
                    onTap: () => _deleteAccount(context, ref),
                  ),
                ],
              ),
              _Section(
                title: strings.settingsHelp,
                children: [
                  _LinkRow(
                    icon: Icons.menu_book_rounded,
                    color: const Color(0xFFFF8A3D),
                    title: strings.settingsHowToPlay,
                    onTap: () => context.push('/how-to-play'),
                  ),
                  _LinkRow(
                    icon: Icons.bug_report_rounded,
                    color: AppColors.coral,
                    title: strings.settingsReportABug,
                    onTap: () => context.push('/report-bug'),
                  ),
                  _LinkRow(
                    icon: Icons.lightbulb_rounded,
                    color: AppColors.coinGold,
                    title: strings.settingsSuggestAFeature,
                    onTap: () => context.push('/report-bug?kind=idea'),
                  ),
                  _LinkRow(
                    icon: Icons.privacy_tip_rounded,
                    color: AppColors.sky,
                    title: strings.settingsPrivacyPolicy,
                    onTap: () => context.push('/privacy'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: Column(
                  children: [
                    Image.asset(
                      'assets/branding/logo_mark.png',
                      width: 56,
                      height: 56,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      strings.settingsUtopia,
                      style: AppTextStyles.display(fontSize: 16),
                    ),
                    if (version != null)
                      Text(
                        strings.settingsVersion(version),
                        style: AppTextStyles.body(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Deletes the account for good (the delete-account Edge Function), then
  /// signs out on this phone, taking the sketchbook kept here with it.
  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final ok = await confirmBouncy(
      context: context,
      audio: ref.read(gameAudioProvider),
      title: strings.settingsDeleteYourAccount,
      message: strings.settingsYourProfileFriendsChatsCoins,
      confirmLabel: strings.settingsDelete,
      cancelLabel: strings.settingsKeepIt,
      hero: const CoinBuddy(mood: BuddyMood.sad, size: 72),
    );
    if (!ok || !context.mounted) return;
    final client = ref.read(supabaseClientProvider);
    try {
      await runWithUtopiaLoader(context, () async {
        final res = await client.functions.invoke('delete-account');
        if (res.status != 200) throw Exception('delete-account ${res.status}');
      });
    } catch (_) {
      if (context.mounted) {
        showUtopiaToast(
          context,
          strings.settingsCouldnTDeleteYourAccount,
          kind: ToastKind.error,
        );
      }
      return;
    }
    try {
      final store = await ref.read(artStoreProvider.future);
      await store.deleteAll();
    } catch (_) {}
    // The sign-in is already gone on the server: just forget it here.
    try {
      await client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {}
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ok = await confirmBouncy(
      context: context,
      audio: ref.read(gameAudioProvider),
      title: strings.settingsSignOut2,
      message: strings.settingsYouCanSignBackIn,
      confirmLabel: strings.settingsSignOut,
      cancelLabel: strings.settingsStay,
      hero: const CoinBuddy(mood: BuddyMood.sad, size: 72),
    );
    if (ok) await ref.read(authRepositoryProvider).signOut();
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 6),
            child: Text(
              title.toUpperCase(),
              style: AppTextStyles.body(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: AppColors.textSecondary,
              ).copyWith(letterSpacing: 1.4),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.surfaceElevated.withValues(alpha: 0.92),
                  AppColors.surface.withValues(alpha: 0.92),
                ],
              ),
              border: Border.all(
                color: AppColors.glowRing.withValues(alpha: 0.35),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _RowShell extends StatelessWidget {
  const _RowShell({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            GlossyBadge(icon: icon, color: color, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.body(fontWeight: FontWeight.w800),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: AppTextStyles.body(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

/// Asks the app store for everything bought on this account before, and
/// says how it went.
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      icon: icon,
      color: color,
      title: title,
      subtitle: subtitle,
      onTap: () => onChanged(!value),
      trailing: BubbleToggle(
        value: value,
        onChanged: onChanged,
        onIcon: icon,
        offIcon: Icons.close_rounded,
        semanticLabel: title,
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      icon: icon,
      color: color,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ?trailing,
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

class _VolumeSlider extends StatelessWidget {
  const _VolumeSlider({
    required this.enabled,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
  });

  final bool enabled;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.35,
      duration: const Duration(milliseconds: 200),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(52, 0, 8, 4),
        child: Row(
          children: [
            Icon(
              Icons.volume_down_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.accent,
                  inactiveTrackColor: Colors.black.withValues(alpha: 0.3),
                  thumbColor: AppColors.goldBorderBright,
                  overlayColor: AppColors.accent.withValues(alpha: 0.2),
                  trackHeight: 5,
                ),
                child: Slider(
                  value: value,
                  onChanged: enabled ? onChanged : null,
                  onChangeEnd: onChangeEnd,
                ),
              ),
            ),
            Icon(
              Icons.volume_up_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// How big Utopia is drawn in a browser: smaller fits more on screen,
/// bigger is easier to read. Only on the web.
class _ScreenSize extends ConsumerWidget {
  const _ScreenSize();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(webScaleProvider);
    final control = ref.read(webScaleProvider.notifier);
    final isDefault = scale == WebScaleController.defaultScale;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.zoom_out_map_rounded,
                color: Color(0xFF4DD0B0),
                size: 24,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  strings.settingsScreenSize,
                  style: AppTextStyles.body(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${(scale * 100).round()}%',
                style: AppTextStyles.body(color: AppColors.accent),
              ),
              if (!isDefault)
                TextButton(
                  onPressed: control.reset,
                  child: Text(strings.settingsReset),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 38),
            child: Row(
              children: [
                Icon(
                  Icons.text_decrease_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.accent,
                      inactiveTrackColor: Colors.black.withValues(alpha: 0.3),
                      thumbColor: AppColors.goldBorderBright,
                      overlayColor: AppColors.accent.withValues(alpha: 0.2),
                      trackHeight: 5,
                    ),
                    child: Slider(
                      value: scale,
                      min: WebScaleController.min,
                      max: WebScaleController.max,
                      // In steps of 5%.
                      divisions:
                          ((WebScaleController.max - WebScaleController.min) *
                                  20)
                              .round(),
                      label: '${(scale * 100).round()}%',
                      onChanged: control.set,
                    ),
                  ),
                ),
                Icon(
                  Icons.text_increase_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
