import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/profiles/profile_providers.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/utopia_themes.dart';
import '../../../core/widgets/zombie_world.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../domain/aura.dart';

/// Wearing the Zombie Bite aura in the Zombie world completes the set:
/// Chip gets bitten and turns, and the world goes deader (a blood moon,
/// thicker fog, more of the dead rising). Null while the player's profile
/// is still loading. Watched at the app's root.
final zombieSetProvider = Provider<bool?>((ref) {
  final me = ref.watch(currentUserProvider)?.id;
  final profile = me == null
      ? null
      : ref.watch(profileByIdProvider(me)).valueOrNull;
  final biome = ref.watch(themeControllerProvider).world.biome;
  if (me != null && profile == null) return null;
  final complete =
      activeAura(profile) == 'zombie' && biome == WorldBiome.zombie;
  ZombieWorld.dead.value = complete;
  return complete;
});
