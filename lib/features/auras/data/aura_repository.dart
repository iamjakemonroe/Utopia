import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../domain/aura.dart';

/// Auras live on the server: prices in aura_catalog, what you own (and
/// until when) in user_auras, and coins only move inside buy_aura.
class AuraRepository {
  AuraRepository(this._client);

  final SupabaseClient _client;

  Future<Map<String, Map<AuraLength, int>>> fetchPrices() async {
    final rows = await _client
        .from('aura_catalog')
        .select('id, price_3d, price_7d, price_30d');
    return {
      for (final r in rows)
        r['id'] as String: {
          AuraLength.days3: (r['price_3d'] as num).toInt(),
          AuraLength.week: (r['price_7d'] as num).toInt(),
          AuraLength.month: (r['price_30d'] as num).toInt(),
        },
    };
  }

  /// Auras the player has bought, with when each runs out.
  Future<Map<String, DateTime>> fetchMine() async {
    if (_client.auth.currentUser == null) return {};
    final rows = await _client.from('user_auras').select('aura_id, expires_at');
    return {
      for (final r in rows)
        r['aura_id'] as String: DateTime.parse(
          r['expires_at'] as String,
        ).toLocal(),
    };
  }

  /// Buys (or extends) an aura and wears it. Returns when it now runs out.
  Future<DateTime> buy(String auraId, AuraLength length) async {
    final until = await _client.rpc(
      'buy_aura',
      params: {'p_aura_id': auraId, 'p_days': length.days},
    );
    return DateTime.parse(until as String).toLocal();
  }

  /// Wears an owned aura, or takes it off with null.
  Future<void> equip(String? auraId) {
    return _client.rpc('equip_aura', params: {'p_aura_id': auraId});
  }
}

final auraRepositoryProvider = Provider<AuraRepository>(
  (ref) => AuraRepository(ref.watch(supabaseClientProvider)),
);

/// Server prices, falling back to the built-in list if they can't load.
final auraPricesProvider = FutureProvider<Map<String, Map<AuraLength, int>>>((
  ref,
) async {
  try {
    return await ref.watch(auraRepositoryProvider).fetchPrices();
  } catch (_) {
    return {for (final a in Aura.all) a.id: a.prices};
  }
});

final myAurasProvider = FutureProvider.autoDispose<Map<String, DateTime>>((
  ref,
) {
  ref.watch(currentUserProvider.select((u) => u?.id));
  return ref.watch(auraRepositoryProvider).fetchMine();
});

/// What an aura costs right now.
int auraPrice(
  Map<String, Map<AuraLength, int>>? prices,
  Aura aura,
  AuraLength length,
) => prices?[aura.id]?[length] ?? aura.priceFor(length);
