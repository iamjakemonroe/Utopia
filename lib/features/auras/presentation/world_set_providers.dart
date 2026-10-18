import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/now_playing/now_playing.dart';
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

/// Encore worn in the Music world completes the set: the show peaks with
/// fireworks, confetti and the crowd jumping, and Chip takes the decks in
/// headphones and shades. Watched at the app's root.
final musicSetProvider = Provider<bool?>((ref) {
  final complete = _wearing(ref, 'music', WorldBiome.music);
  if (complete != null) WorldSets.music.on.value = complete;
  return complete;
});

/// The player's own music playing while they're in the Music world: the
/// lasers, equalizer and crowd all dance harder. Watched at the app's root.
final musicLiveProvider = Provider<bool>((ref) {
  final here = ref.watch(themeControllerProvider).world.biome;
  final playing = ref.watch(nowPlayingProvider);
  final kind = playing.track?.kind ?? MediaKind.unknown;
  final live =
      here == WorldBiome.music &&
      playing.listening &&
      (kind == MediaKind.music ||
          kind == MediaKind.radio ||
          kind == MediaKind.unknown);
  WorldSets.musicLive.on.value = live;
  return live;
});

/// Jack's Lantern worn in the Halloween world completes the set: Chip is
/// carved into a jack-o'-lantern in a witch's hat, and the night turns (a
/// blood moon, the scarecrow's eyes light, more ghosts, the witch circling,
/// the tall thing in the trees closer). Watched at the app's root.
final halloweenSetProvider = Provider<bool?>((ref) {
  final complete = _wearing(ref, 'jack', WorldBiome.halloween);
  if (complete != null) WorldSets.halloween.on.value = complete;
  return complete;
});
