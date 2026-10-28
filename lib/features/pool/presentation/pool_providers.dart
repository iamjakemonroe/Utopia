import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/profiles/profile_providers.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../store/domain/store_catalog.dart';
import '../../store/presentation/store_controller.dart';
import '../data/pool_repository.dart';
import '../domain/pool_cues.dart';

/// The cue the player plays with: the one they've equipped if they may use
/// it (theirs, or lent), else the classic; its level; and whether it can
/// go up a level (only a cue that's theirs for good).
typedef MyCue = ({PoolCue cue, int level, bool upgradable});

final myPoolCueProvider = Provider<MyCue>((ref) {
  final me = ref.watch(currentUserProvider)?.id;
  final profile = me == null
      ? null
      : ref.watch(profileByIdProvider(me)).valueOrNull;
  final store = ref.watch(storeControllerProvider);
  var cue = poolCue(profile?['equipped_pool_cue'] as String?);
  if (!store.isOwned(StoreCatalog.cueItem(cue.id))) cue = poolCue(kStarterCue);
  final levels =
      ref.watch(poolCueLevelsProvider).valueOrNull ?? const <String, int>{};
  final level = (levels[cue.id] ?? 1).clamp(1, cue.maxLevel);
  return (
    cue: cue,
    level: level,
    upgradable:
        store.isOwnedForever(StoreCatalog.cueItem(cue.id)) &&
        level < cue.maxLevel,
  );
});
