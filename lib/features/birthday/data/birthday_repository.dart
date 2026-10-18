import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/birthday.dart';

/// The player's birthday on the server (a table only they can read), and
/// their birthday party: the Birthday world and frame, given on the day.
class BirthdayRepository {
  BirthdayRepository(this._client);

  final SupabaseClient _client;

  Future<SavedBirthday?> fetch(String userId) async {
    final row = await _client
        .from('user_birthdays')
        .select('month, day, set_at, tell_friends')
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return SavedBirthday(
      Birthday((row['month'] as num).toInt(), (row['day'] as num).toInt()),
      DateTime.tryParse(row['set_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      tellFriends: row['tell_friends'] as bool? ?? true,
    );
  }

  /// Saves it (or corrects it, within a day of first saving it).
  Future<void> save(Birthday birthday) => _client.rpc(
    'set_birthday',
    params: {'p_month': birthday.month, 'p_day': birthday.day},
  );

  /// Whether their friends hear about their birthday on the day (any
  /// time, even once the date's locked).
  Future<void> setSharing(bool on) =>
      _client.rpc('set_birthday_sharing', params: {'p_on': on});

  /// On the player's birthday: the Birthday world and frame until [until]
  /// (their midnight). Returns when the party ends, or null if it isn't
  /// their birthday.
  Future<DateTime?> start(DateTime until) async {
    final data = await _client.rpc(
      'start_birthday',
      params: {'p_until': until.toUtc().toIso8601String()},
    );
    if (data is! Map || data['birthday'] != true) return null;
    return DateTime.tryParse(data['until'] as String? ?? '')?.toLocal();
  }
}

final birthdayRepositoryProvider = Provider<BirthdayRepository>(
  (ref) => BirthdayRepository(ref.watch(supabaseClientProvider)),
);
