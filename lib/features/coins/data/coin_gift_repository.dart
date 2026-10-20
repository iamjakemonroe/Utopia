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
    required this.balance,
    required this.giftable,
    required this.held,
    required this.holdDays,
    required this.min,
    required this.pinSet,
    this.pinLockedUntil,
  });

  factory GiftAllowance.fromJson(Map<String, dynamic> json) {
    int n(String key) => (json[key] as num?)?.toInt() ?? 0;
    return GiftAllowance(
      ok: json['ok'] == true,
      why: json['why'] as String?,
      balance: n('balance'),
      giftable: n('giftable'),
      held: n('held'),
      holdDays: n('hold_days'),
      min: n('min'),
      pinSet: json['pin_set'] == true,
      pinLockedUntil: DateTime.tryParse(
        json['pin_locked_until'] as String? ?? '',
      )?.toLocal(),
    );
  }

  /// Whether they can send at all; if not, [why]: 'guest' or 'off'.
  final bool ok;
  final String? why;

  final int balance;

  /// What they can give: their coins less any bought in the last
  /// [holdDays] days ([held]).
  final int giftable;
  final int held;
  final int holdDays;

  /// The least one gift can be.
  final int min;

  /// Whether they've a gift PIN yet (every gift asks for it), and when
  /// it unlocks after too many wrong tries.
  final bool pinSet;
  final DateTime? pinLockedUntil;

  /// The most one gift can be right now.
  int get most => giftable;
}

/// How a gift (or a PIN change) went: [ok], or what said no ([why]).
class GiftResult {
  const GiftResult({
    required this.ok,
    this.why,
    this.coins = 0,
    this.triesLeft,
    this.lockedUntil,
  });

  factory GiftResult.fromJson(Map<String, dynamic> json) => GiftResult(
    ok: json['ok'] == true,
    why: json['why'] as String?,
    coins: (json['coins'] as num?)?.toInt() ?? 0,
    triesLeft: (json['tries_left'] as num?)?.toInt(),
    lockedUntil: DateTime.tryParse(
      json['locked_until'] as String? ?? '',
    )?.toLocal(),
  );

  final bool ok;
  final String? why;
  final int coins;

  /// After a wrong PIN, how many tries before gifts lock.
  final int? triesLeft;

  /// Locked after too many wrong PINs, until then.
  final DateTime? lockedUntil;
}

/// Whether the player has a gift PIN, and whether it's locked.
class GiftPinStatus {
  const GiftPinStatus({required this.set, this.lockedUntil});

  factory GiftPinStatus.fromJson(Map<String, dynamic> json) => GiftPinStatus(
    set: json['set'] == true,
    lockedUntil: DateTime.tryParse(
      json['locked_until'] as String? ?? '',
    )?.toLocal(),
  );

  final bool set;
  final DateTime? lockedUntil;
}

class CoinGiftRepository {
  CoinGiftRepository(this._client);

  final SupabaseClient _client;

  Map<String, dynamic> _map(Object? json) =>
      Map<String, dynamic>.from(json! as Map);

  /// What they can send now.
  Future<GiftAllowance> allowance() async =>
      GiftAllowance.fromJson(_map(await _client.rpc('coin_gift_allowance')));

  /// Sends [coins] to friend [to], with the gift [pin]. [key] is made once
  /// per gift ([newGiftKey]): sending again with it (after a dropped
  /// connection) never sends twice.
  Future<GiftResult> send({
    required String to,
    required int coins,
    required String key,
    required String pin,
  }) async => GiftResult.fromJson(
    _map(
      await _client.rpc(
        'send_coin_gift',
        params: {'p_to': to, 'p_coins': coins, 'p_key': key, 'p_pin': pin},
      ),
    ),
  );

  Future<GiftPinStatus> pinStatus() async =>
      GiftPinStatus.fromJson(_map(await _client.rpc('gift_pin_status')));

  /// Sets the gift PIN, or changes it ([current], the one they have).
  Future<GiftResult> setPin(String pin, {String? current}) async =>
      GiftResult.fromJson(
        _map(
          await _client.rpc(
            'set_gift_pin',
            params: {'p_pin': pin, 'p_current': current},
          ),
        ),
      );

  /// Emails a code to [email] (the account's), to prove it's theirs
  /// before a new PIN: the "Your gift PIN code" email (Utopia has no
  /// passwords, so the password-reset email is the PIN's;
  /// supabase/templates/recovery.html).
  Future<void> sendPinResetCode(String email) =>
      _client.auth.resetPasswordForEmail(email);

  /// Checks the code from that email: the session's then proved by it,
  /// which [resetPin] needs (within a few minutes).
  Future<void> verifyPinResetCode(String email, String code) async {
    await _client.auth.verifyOTP(
      email: email,
      token: code,
      type: OtpType.recovery,
    );
  }

  /// A new gift PIN for one who's forgotten theirs, once their email's
  /// proved ([verifyPinResetCode]).
  Future<GiftResult> resetPin(String pin) async => GiftResult.fromJson(
    _map(await _client.rpc('reset_gift_pin', params: {'p_pin': pin})),
  );
}

final coinGiftRepositoryProvider = Provider<CoinGiftRepository>(
  (ref) => CoinGiftRepository(ref.watch(supabaseClientProvider)),
);

/// What the player can send now, asked each time the send sheet opens.
final giftAllowanceProvider = FutureProvider.autoDispose<GiftAllowance>(
  (ref) => ref.watch(coinGiftRepositoryProvider).allowance(),
);

/// Whether the player has a gift PIN (for Settings).
final giftPinStatusProvider = FutureProvider.autoDispose<GiftPinStatus>(
  (ref) => ref.watch(coinGiftRepositoryProvider).pinStatus(),
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
