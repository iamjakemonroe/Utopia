import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';

/// What the player can send as gifts right now (the server's
/// coin_gift_allowance; it checks everything again on sending).
class GiftAllowance {
  const GiftAllowance({
    required this.ok,
    required this.why,
    required this.readyAt,
    required this.balance,
    required this.giftable,
    required this.held,
    required this.holdDays,
    required this.min,
    required this.max,
    required this.leftToday,
    required this.giftsLeft,
  });

  factory GiftAllowance.fromJson(Map<String, dynamic> json) {
    int n(String key) => (json[key] as num?)?.toInt() ?? 0;
    return GiftAllowance(
      ok: json['ok'] == true,
      why: json['why'] as String?,
      readyAt: DateTime.tryParse(json['ready_at'] as String? ?? '')?.toLocal(),
      balance: n('balance'),
      giftable: n('giftable'),
      held: n('held'),
      holdDays: n('hold_days'),
      min: n('min'),
      max: n('max'),
      leftToday: n('left_today'),
      giftsLeft: n('gifts_left'),
    );
  }

  /// Whether they can send at all; if not, [why]: 'guest', 'new' (until
  /// [readAt]) or 'off'.
  final bool ok;
  final String? why;
  final DateTime? readyAt;

  final int balance;

  /// What they can give: their coins less any bought in the last
  /// [holdDays] days ([held]).
  final int giftable;
  final int held;
  final int holdDays;

  /// The least and most one gift can be.
  final int min;
  final int max;

  /// What's left of today's limits.
  final int leftToday;
  final int giftsLeft;

  /// The most one gift can be right now.
  int get most =>
      giftsLeft <= 0 ? 0 : [max, giftable, leftToday].reduce(math.min);
}

/// How a gift went: [ok], or the rule that said no ([why]).
class GiftResult {
  const GiftResult({required this.ok, this.why, this.coins = 0});

  factory GiftResult.fromJson(Map<String, dynamic> json) => GiftResult(
    ok: json['ok'] == true,
    why: json['why'] as String?,
    coins: (json['coins'] as num?)?.toInt() ?? 0,
  );

  final bool ok;
  final String? why;
  final int coins;
}

class CoinGiftRepository {
  CoinGiftRepository(this._client);

  final SupabaseClient _client;

  Future<GiftAllowance> allowance() async => GiftAllowance.fromJson(
    Map<String, dynamic>.from(await _client.rpc('coin_gift_allowance') as Map),
  );

  /// Sends [coins] to friend [to]. [key] is made once per gift
  /// ([newGiftKey]): sending again with it (after a dropped connection)
  /// never sends twice.
  Future<GiftResult> send({
    required String to,
    required int coins,
    required String key,
  }) async => GiftResult.fromJson(
    Map<String, dynamic>.from(
      await _client.rpc(
            'send_coin_gift',
            params: {'p_to': to, 'p_coins': coins, 'p_key': key},
          )
          as Map,
    ),
  );
}

final coinGiftRepositoryProvider = Provider<CoinGiftRepository>(
  (ref) => CoinGiftRepository(ref.watch(supabaseClientProvider)),
);

/// What the player can send now, asked each time the send sheet opens.
final giftAllowanceProvider = FutureProvider.autoDispose<GiftAllowance>(
  (ref) => ref.watch(coinGiftRepositoryProvider).allowance(),
);

/// A fresh random id for one gift (a version 4 UUID).
String newGiftKey() {
  final random = math.Random.secure();
  final bytes = [for (var i = 0; i < 16; i++) random.nextInt(256)];
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
