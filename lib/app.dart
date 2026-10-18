import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/profiles/profile_freshness.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/widgets/utopia_toast.dart';
import 'features/auras/presentation/dragon_set.dart';
import 'features/auras/presentation/world_set_providers.dart';
import 'features/auras/presentation/zombie_set.dart';
import 'features/chip/presentation/floating_chip.dart';
import 'features/birthday/presentation/birthday_providers.dart';
import 'features/maestro/presentation/maestro_providers.dart';
import 'features/notifications/presentation/notification_actions.dart';
import 'features/notifications/presentation/notification_center.dart';
import 'features/store/presentation/theme_teleport.dart';

class UtopiaApp extends ConsumerWidget {
  const UtopiaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    // Rebuilt with the theme so ThemeData picks up the new colors.
    ref.watch(themeControllerProvider);
    // Refreshes cached player profiles after time away from the app.
    ref.watch(profileFreshnessProvider);
    // Dragon Coil worn in the Dojo world sets its dragon free.
    // A Chip Maestro member's Chip wears his beret.
    ref.watch(maestroLookProvider);
    // On the player's birthday, his party hat.
    ref.watch(birthdayTodayProvider);
    ref.watch(dragonSetProvider);
    ref.listen(dragonSetProvider, (previous, next) {
      if (previous != false || next != true) return;
      final ctx = appNavigatorContext(ref);
      if (ctx == null || !ctx.mounted) return;
      showUtopiaToast(
        ctx,
        'Dragon set complete. The dragon flies free.',
        kind: ToastKind.success,
        icon: Icons.local_fire_department_rounded,
      );
    });
    // Angel Halo in Heaven, Inferno in Hell.
    ref.watch(heavenSetProvider);
    ref.listen(heavenSetProvider, (previous, next) {
      if (previous != false || next != true) return;
      final ctx = appNavigatorContext(ref);
      if (ctx == null || !ctx.mounted) return;
      showUtopiaToast(
        ctx,
        'Heaven set complete. The gates are open.',
        kind: ToastKind.success,
        icon: Icons.auto_awesome_rounded,
      );
    });
    ref.watch(hellSetProvider);
    ref.listen(hellSetProvider, (previous, next) {
      if (previous != false || next != true) return;
      final ctx = appNavigatorContext(ref);
      if (ctx == null || !ctx.mounted) return;
      showUtopiaToast(
        ctx,
        'Hell set complete. Chip grew horns.',
        kind: ToastKind.success,
        icon: Icons.local_fire_department_rounded,
      );
    });
    // Encore in the Music world puts Chip on the decks; the player's own
    // music makes the show dance harder.
    ref.watch(musicLiveProvider);
    ref.watch(musicSetProvider);
    ref.listen(musicSetProvider, (previous, next) {
      if (previous != false || next != true) return;
      final ctx = appNavigatorContext(ref);
      if (ctx == null || !ctx.mounted) return;
      showUtopiaToast(
        ctx,
        'Music set complete. Chip is on the decks.',
        kind: ToastKind.success,
        icon: Icons.headphones_rounded,
      );
    });
    // Jack's Lantern in the Halloween world gets Chip carved.
    ref.watch(halloweenSetProvider);
    ref.listen(halloweenSetProvider, (previous, next) {
      if (previous != false || next != true) return;
      final ctx = appNavigatorContext(ref);
      if (ctx == null || !ctx.mounted) return;
      showUtopiaToast(
        ctx,
        'Halloween set complete. Chip got carved.',
        kind: ToastKind.success,
        icon: Icons.nightlight_round,
      );
    });
    // Zombie Bite worn in the Zombie world gets Chip bitten.
    ref.watch(zombieSetProvider);
    ref.listen(zombieSetProvider, (previous, next) {
      if (previous != false || next != true) return;
      final ctx = appNavigatorContext(ref);
      if (ctx == null || !ctx.mounted) return;
      showUtopiaToast(
        ctx,
        'Zombie set complete. Chip got bitten.',
        kind: ToastKind.success,
        icon: Icons.pan_tool_rounded,
      );
    });

    return MaterialApp.router(
      title: 'Utopia',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      // The teleport plays above the router, so the rebuild a theme switch
      // triggers underneath never interrupts it.
      builder: (context, child) => Stack(
        children: [
          child!,
          // Chip, floating over the screens, ready to chat.
          const Positioned.fill(child: FloatingChip()),
          // Friend requests and challenges pop up over any screen.
          const Positioned.fill(child: NotificationCenter()),
          const Positioned.fill(child: ThemeTeleportLayer()),
        ],
      ),
    );
  }
}
