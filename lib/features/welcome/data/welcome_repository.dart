import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';

/// A player's welcome pass (the welcome week before it): when it ends, and
/// whether it only just started.
class WelcomeWeek {
  const WelcomeWeek({required this.until, required this.fresh});

  final DateTime until;

  /// True on the call that started it (show the welcome).
  final bool fresh;

  bool get over => DateTime.now().isAfter(until);
}

/// Starts the welcome pass the first time it's asked (everything in the
/// store but Chip Maestro, free for three days) and after that says when it
/// ends.
class WelcomeRepository {
  WelcomeRepository(this._client);

  final SupabaseClient _client;

  Future<WelcomeWeek?> start() async {
    final data = await _client.rpc('start_welcome_week');
    if (data is! Map) return null;
    final until = DateTime.tryParse(data['until'] as String? ?? '');
    if (until == null) return null;
    return WelcomeWeek(until: until.toLocal(), fresh: data['fresh'] == true);
  }
}

final welcomeRepositoryProvider = Provider<WelcomeRepository>(
  (ref) => WelcomeRepository(ref.watch(supabaseClientProvider)),
);

/// The player's welcome week, once home has asked (for Chip to know).
final welcomeWeekProvider = StateProvider<WelcomeWeek?>((ref) => null);
