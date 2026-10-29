import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/world_sets.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../data/maestro_repository.dart';

/// The signed-in player's Chip Maestro plan. Refresh it (invalidate) after
/// a purchase or a real portrait.
final maestroProvider = FutureProvider<MaestroStatus>((ref) async {
  ref.watch(currentUserProvider.select((u) => u?.id));
  try {
    return await ref.watch(maestroRepositoryProvider).fetch();
  } catch (_) {
    return const MaestroStatus();
  }
});

/// Members' Chip wears his artist's beret, everywhere. Watched at the
/// app's root.
final maestroLookProvider = Provider<bool>((ref) {
  final member = ref.watch(maestroProvider).valueOrNull?.active ?? false;
  WorldSets.maestro.on.value = member;
  return member;
});
