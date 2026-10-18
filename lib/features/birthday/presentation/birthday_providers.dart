import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/world_sets.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../data/birthday_repository.dart';
import '../domain/birthday.dart';

/// The signed-in player's saved birthday (null if they haven't given one).
final myBirthdayProvider = FutureProvider<SavedBirthday?>((ref) async {
  final me = ref.watch(currentUserProvider)?.id;
  if (me == null) return null;
  return ref.watch(birthdayRepositoryProvider).fetch(me);
});

/// Whether it's the player's birthday today (on their phone's calendar).
/// Puts Chip's party hat on all day. Watched at the app's root.
final birthdayTodayProvider = Provider<bool>((ref) {
  final saved = ref.watch(myBirthdayProvider).valueOrNull;
  final today = saved != null && saved.birthday.isOn(DateTime.now());
  WorldSets.birthday.on.value = today;
  return today;
});
