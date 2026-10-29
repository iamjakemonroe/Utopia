import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';

/// The store product for Chip Maestro, the monthly art plan.
const kMaestroProductId = 'utopia.maestro.monthly';

/// What Chip Maestro includes (the server holds the real limits).
const kMaestroPortraitsPerMonth = 30;

/// What a day with Chip allows, free and with Chip Maestro: the same as
/// the server's chip_allow, shown when comparing the two.
const kChipChatsFree = 20, kChipChatsMaestro = 60;
const kChipDrawsFree = 4, kChipDrawsMaestro = 6;
const kChipPaintsFree = 20, kChipPaintsMaestro = 40;

/// The player's Chip Maestro plan, as the server knows it.
@immutable
class MaestroStatus {
  const MaestroStatus({
    this.active = false,
    this.until,
    this.autoRenew = false,
    this.left = 0,
    this.freePortrait = false,
  });

  final bool active;

  /// When this month of the plan ends (it renews then, unless cancelled).
  final DateTime? until;
  final bool autoRenew;

  /// Real portraits left this month.
  final int left;

  /// Their one free real portrait is still there to try.
  final bool freePortrait;

  static MaestroStatus fromJson(Object? json) {
    if (json is! Map) return const MaestroStatus();
    return MaestroStatus(
      active: json['active'] == true,
      until: DateTime.tryParse(json['until'] as String? ?? ''),
      autoRenew: json['auto_renew'] == true,
      left: (json['left'] as num?)?.toInt() ?? 0,
      freePortrait: json['free'] == true,
    );
  }
}

class MaestroRepository {
  MaestroRepository(this._client);

  final SupabaseClient _client;

  Future<MaestroStatus> fetch() async {
    if (_client.auth.currentUser == null) return const MaestroStatus();
    return MaestroStatus.fromJson(await _client.rpc('my_maestro'));
  }
}

final maestroRepositoryProvider = Provider<MaestroRepository>(
  (ref) => MaestroRepository(ref.watch(supabaseClientProvider)),
);
