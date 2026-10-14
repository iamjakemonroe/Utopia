import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/utopia_themes.dart';
import '../../../core/widgets/utopia_toast.dart';
import '../../store/domain/store_catalog.dart';
import '../../store/presentation/store_controller.dart';
import '../../store/presentation/store_screen.dart';
import '../../store/presentation/theme_teleport.dart';

/// The Sketchbook is the Doodle world's: opens [location] (a Sketchbook
/// route) there. In the Doodle world it just opens; if the player owns or
/// rents it, Chip carries them there through the portal and it opens under
/// the flash; otherwise they're shown the Doodle world to rent or unlock.
///
/// Takes the [container] rather than a widget's ref, so it can be called
/// as the sheet that asked closes.
Future<void> openInDoodleWorld(
  ProviderContainer container,
  String location,
) async {
  final router = container.read(goRouterProvider);
  const doodle = UtopiaThemes.utopiaDoodle;
  if (UtopiaThemes.active.world.biome == WorldBiome.doodle) {
    router.push(location);
    return;
  }
  final item = StoreCatalog.themes.where((i) => i.id == doodle.id).firstOrNull;
  final owned =
      item != null && container.read(storeControllerProvider).isOwned(item);
  if (owned) {
    final travelling = container
        .read(themeTeleportProvider.notifier)
        .welcome(doodle, atFlash: () => router.push(location));
    if (!travelling) router.push(location);
    return;
  }
  final context = router.routerDelegate.navigatorKey.currentContext;
  if (context == null || !context.mounted) return;
  showUtopiaToast(
    context,
    'Coloring happens in the Doodle world.',
    icon: Icons.brush_rounded,
  );
  await showWorldPreview(context, doodle);
}
