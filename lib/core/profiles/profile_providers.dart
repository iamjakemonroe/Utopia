import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bots/bots.dart';
import '../supabase/supabase_providers.dart';
import 'profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});

/// Cached single-profile lookup by id, e.g. to render an opponent's name
/// on a match screen. Riverpod's provider cache means the same id is only
/// fetched once per session unless invalidated.
final profileByIdProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, id) {
      // Computer players have their profiles built in: no server needed.
      if (isBotId(id)) return Future.value(botProfile(id));
      if (isFriendSeatId(id)) return Future.value(friendSeatProfile(id));
      return ref.watch(profileRepositoryProvider).fetchById(id);
    });
