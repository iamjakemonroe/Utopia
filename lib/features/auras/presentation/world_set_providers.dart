import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/profiles/profile_providers.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/utopia_themes.dart';
import '../../../core/widgets/world_sets.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../domain/aura.dart';

/// Whether the player wears [aura] in [biome]: null while their profile is
/// still loading.
bool? _wearing(Ref ref, String aura, WorldBiome biome) {
  final me = ref.watch(currentUserProvider)?.id;
  final profile = me == null
      ? null
      : ref.watch(profileByIdProvider(me)).valueOrNull;
  final here = ref.watch(themeControllerProvider).world.biome;
  if (me != null && profile == null) return null;
  return activeAura(profile) == aura && here == biome;
}

/// Angel Halo worn in Heaven completes the set: the gates open, a rainbow
/// forms, and Chip gets a halo and wings. Watched at the app's root.
final heavenSetProvider = Provider<bool?>((ref) {
  final complete = _wearing(ref, 'halo', WorldBiome.heaven);
  if (complete != null) WorldSets.heaven.on.value = complete;
  return complete;
});

/// Inferno worn in Hell completes the set: the volcano erupts, fire rains,
/// something horned looms in the smoke, and Chip grows baby horns, red
/// eyes and a tail. Watched at the app's root.
final hellSetProvider = Provider<bool?>((ref) {
  final complete = _wearing(ref, 'demon', WorldBiome.hell);
  if (complete != null) WorldSets.hell.on.value = complete;
  return complete;
});
