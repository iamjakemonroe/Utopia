import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/utopia_themes.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/audio/game_audio.dart';
import '../../../../core/now_playing/now_playing.dart';
import '../../../../core/settings/gameplay_settings.dart';
import '../../../../core/profiles/profile_providers.dart';
import '../../../../core/profiles/profile_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/bouncy_dialog.dart';
import '../../../../core/widgets/coin_balance_pill.dart';
import '../../../../core/widgets/coin_buddy.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/widgets/utopia_world.dart';
import '../../../auras/domain/aura.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../friends/presentation/widgets/friends_popup.dart';
import '../../../help/presentation/help_sheet.dart';
import '../../../notifications/data/notification_repository.dart';
import '../../../../core/widgets/frosted.dart';
import '../../../../l10n/strings.dart';

/// Slides the side menu in from the left with a springy overshoot, items
/// popping in one after another, over a blurred backdrop.
Future<void> showSideMenu(BuildContext context, WidgetRef ref) {
  ref.read(gameAudioProvider).play(Sfx.drawer);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: strings.sideMenuCloseMenu,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 620),
    pageBuilder: (context, animation, _) => _SideMenu(animation: animation),
    transitionBuilder: (context, animation, _, child) {
      final slide = animation.status == AnimationStatus.reverse
          ? Curves.easeInBack.transform(animation.value)
          : Curves.elasticOut.transform(animation.value).clamp(0.0, 1.06);
      return Frosted(
        sigma: 5 * animation.value,
        child: FractionalTranslation(
          translation: Offset(slide - 1, 0),
          child: child,
        ),
      );
    },
  );
}

class _SideMenu extends ConsumerWidget {
  const _SideMenu({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isGuest = ref.watch(isAnonymousProvider);
    final profile = user == null
        ? null
        : ref.watch(profileByIdProvider(user.id)).valueOrNull;
    final name = user == null
        ? strings.sideMenuPlayer
        : profileDisplayName(profile, user.id);
    final username = profile?['username'] as String?;
    // Most of a phone's width; on a tablet, still about a phone's.
    final width = math.min(MediaQuery.sizeOf(context).width * 0.84, 380.0);
    final unread = ref.watch(unreadNotificationsProvider);
    // Chip up here vibes along too when there's music on.
    final music = ref.watch(nowPlayingProvider);
    final vibing =
        music.listening && ref.watch(gameplaySettingsProvider).showNowPlaying;
    final dragon = activeAura(profile) == 'dragon';
    ref.watch(themeControllerProvider);
    final doodle = UtopiaThemes.active.world.biome == WorldBiome.doodle;

    void go(String location) {
      Navigator.of(context).pop();
      context.push(location);
    }

    final items = <_MenuItem>[
      _MenuItem(
        Icons.person_rounded,
        strings.sideMenuProfile,
        AppColors.sky,
        () => go('/profile'),
      ),
      if (doodle)
        _MenuItem(
          Icons.draw_rounded,
          strings.sideMenuSketchbook,
          AppColors.accent,
          () => go('/sketchbook'),
        ),
      _MenuItem(
        Icons.storefront_rounded,
        strings.sideMenuStore,
        AppColors.coinGold,
        () => go('/store'),
      ),
      _MenuItem(
        Icons.collections_bookmark_rounded,
        strings.sideMenuCollection,
        AppColors.mint,
        () => go('/collection'),
      ),
      _MenuItem(
        Icons.leaderboard_rounded,
        strings.sideMenuRankings,
        AppColors.coral,
        () => go('/rankings'),
      ),
      _MenuItem(
        Icons.notifications_rounded,
        strings.sideMenuNotifications,
        AppColors.sky,
        () => go('/notifications'),
        badge: unread > 0 ? '$unread' : null,
      ),
      if (!isGuest)
        _MenuItem(
          Icons.people_rounded,
          strings.sideMenuFriends,
          const Color(0xFFFF8FB8),
          () {
            Navigator.of(context).pop();
            showFriendsPopup(context);
          },
        ),
      _MenuItem(
        Icons.settings_rounded,
        strings.sideMenuSettings,
        const Color(0xFFB27BFF),
        () => go('/settings'),
      ),
      _MenuItem(
        Icons.support_rounded,
        strings.sideMenuHelpFeedback,
        const Color(0xFFFF8A3D),
        () {
          Navigator.of(context).pop();
          showHelpSheet(context, from: currentPath(ref.read(goRouterProvider)));
        },
      ),
      if (isGuest)
        _MenuItem(
          Icons.shield_rounded,
          strings.sideMenuSaveYourAccount,
          AppColors.success,
          () => go('/auth/link'),
        )
      else
        _MenuItem(
          Icons.logout_rounded,
          strings.sideMenuSignOut,
          AppColors.textSecondary,
          () async {
            // The same question as in Settings, before signing out.
            final ok = await confirmBouncy(
              context: context,
              audio: ref.read(gameAudioProvider),
              title: strings.sideMenuSignOut2,
              message: strings.sideMenuYouCanSignBackIn,
              confirmLabel: strings.sideMenuSignOut,
              cancelLabel: strings.sideMenuStay,
              hero: const CoinBuddy(mood: BuddyMood.sad, size: 72),
            );
            if (!ok || !context.mounted) return;
            Navigator.of(context).pop();
            await ref.read(authRepositoryProvider).signOut();
          },
        ),
    ];

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: width,
          height: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(34),
            ),
            border: Border(
              right: BorderSide(color: AppColors.goldBorder, width: 2.5),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.glowRing.withValues(alpha: 0.45),
                blurRadius: 24,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(32),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header: a slice of the living world with you in it.
                SizedBox(
                  height: 210,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const UtopiaWorld(),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, AppColors.surface],
                            stops: const [0.45, 1.0],
                          ),
                        ),
                      ),
                      Positioned(
                        right: 10,
                        top: 40,
                        // Wearing Dragon Coil: Chip's too hot, and can't
                        // take his eyes off the dragon round your picture.
                        child: dragon
                            ? const CoinBuddy(
                                mood: BuddyMood.hot,
                                lookAt: Offset(-0.9, 0.75),
                                size: 74,
                              )
                            : CoinBuddy(
                                mood: vibing
                                    ? music.chipLine.mood
                                    : BuddyMood.happy,
                                flavor: vibing
                                    ? music.chipLine.flavor
                                    : ChipFlavor.none,
                                size: 74,
                              ),
                      ),
                      Positioned(
                        left: AppSpacing.lg,
                        right: AppSpacing.lg,
                        bottom: AppSpacing.md,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.goldBorder,
                                  width: 2.5,
                                ),
                              ),
                              child: UserAvatar.fromProfile(
                                profile,
                                fallbackInitial: name,
                                radius: 30,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.display(fontSize: 20),
                                  ),
                                  Text(
                                    isGuest
                                        ? strings.sideMenuGuest
                                        : (username == null
                                              ? strings.sideMenuNoUsernameYet
                                              : '@$username'),
                                    style: AppTextStyles.body(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const CoinBalancePill(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, i) => _StaggeredItem(
                      animation: animation,
                      index: i,
                      count: items.length,
                      item: items[i],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    strings.sideMenuUtopia10,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem(this.icon, this.label, this.color, this.onTap, {this.badge});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final String? badge;
}

/// One menu row, popping in a beat after the one above it.
class _StaggeredItem extends StatelessWidget {
  const _StaggeredItem({
    required this.animation,
    required this.index,
    required this.count,
    required this.item,
  });

  final Animation<double> animation;
  final int index;
  final int count;
  final _MenuItem item;

  @override
  Widget build(BuildContext context) {
    final start = 0.15 + index * (0.5 / count);
    final curve = CurvedAnimation(
      parent: animation,
      curve: Interval(
        start.clamp(0.0, 0.9),
        (start + 0.4).clamp(0.0, 1.0),
        curve: Curves.elasticOut,
      ),
      reverseCurve: Curves.easeIn,
    );
    return AnimatedBuilder(
      animation: curve,
      builder: (context, child) => Opacity(
        opacity: curve.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(-40 * (1 - curve.value), 0),
          child: Transform.scale(
            scale: 0.85 + 0.15 * curve.value,
            alignment: Alignment.centerLeft,
            child: child,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 3,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: item.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.35, -0.4),
                        colors: [
                          Color.lerp(item.color, Colors.white, 0.45)!,
                          item.color,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: item.color.withValues(alpha: 0.45),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(item.icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      item.label,
                      style: AppTextStyles.body(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (item.badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.coral,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        item.badge!,
                        style: AppTextStyles.body(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
