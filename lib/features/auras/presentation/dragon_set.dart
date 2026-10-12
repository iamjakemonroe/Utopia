import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/profiles/profile_providers.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/utopia_themes.dart';
import '../../../core/widgets/dojo_dragon.dart';
import '../../../core/widgets/world_sets.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../domain/aura.dart';

/// Wearing the Dragon Coil aura in the Dojo world completes the set: the
/// world's dragon breaks free and flies the whole screen. Null while the
/// player's profile is still loading. Watched at the app's root.
final dragonSetProvider = Provider<bool?>((ref) {
  final me = ref.watch(currentUserProvider)?.id;
  final profile = me == null
      ? null
      : ref.watch(profileByIdProvider(me)).valueOrNull;
  final biome = ref.watch(themeControllerProvider).world.biome;
  if (me != null && profile == null) return null;
  final complete = activeAura(profile) == 'dragon' && biome == WorldBiome.dojo;
  DojoDragon.free.value = complete;
  WorldSets.dragon.on.value = complete;
  return complete;
});
