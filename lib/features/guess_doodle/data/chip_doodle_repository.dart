import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/platform/device_key.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../domain/chip_doodle.dart';
import '../../../l10n/strings.dart';

/// Chip couldn't deal a round: [message] says why, for the player.
class ChipDoodleUnavailable implements Exception {
  const ChipDoodleUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Rounds of "Chip draws, you guess", from Chip's brain (the chip function
/// deals doodles from a deck every player shares).
class ChipDoodleRepository {
  ChipDoodleRepository(this._client);

  final SupabaseClient _client;

  /// A doodle the player hasn't had. Throws [ChipDoodleUnavailable].
  Future<ChipDoodleRound> round() async {
    try {
      final res = await _client.functions.invoke(
        'chip',
        body: {'action': 'doodle', 'device': DeviceKey.value},
      );
      final round = ChipDoodleRound.fromJson(res.data);
      if (round != null && round.strokes.isNotEmpty) return round;
    } on FunctionException catch (e) {
      final details = e.details;
      if (e.status == 503 && details is Map && details['error'] is String) {
        throw ChipDoodleUnavailable(details['error'] as String);
      }
    } catch (_) {}
    throw ChipDoodleUnavailable(strings.chipDoodleChipCouldnTDrawJust2);
  }
}

final chipDoodleRepositoryProvider = Provider<ChipDoodleRepository>(
  (ref) => ChipDoodleRepository(ref.watch(supabaseClientProvider)),
);
