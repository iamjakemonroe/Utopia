import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/store_catalog.dart';

/// What the player owns and has equipped, on the server (so other players
/// see your pieces, and purchases follow you to a new phone).
class StoreRepository {
  StoreRepository(this._client);

  final SupabaseClient _client;

  /// What each product costs in coins (the server's price list).
  Future<Map<String, int>> fetchCoinPrices() async {
    final rows = await _client
        .from('store_coin_prices')
        .select('product_id, coins');
    return {
      for (final r in rows)
        r['product_id'] as String: (r['coins'] as num).toInt(),
    };
  }

  /// Buys [productId] with coins; the server checks the price and the
  /// balance, takes the coins and unlocks what's in it.
  Future<void> buyWithCoins(String productId) =>
      _client.rpc('buy_with_coins', params: {'p_product_id': productId});

  Future<Set<String>> fetchOwned() async {
    if (_client.auth.currentUser == null) return {};
    final rows = await _client.from('user_entitlements').select('item_id');
    return {for (final r in rows) r['item_id'] as String};
  }

  /// Records a completed store purchase and grants its items.
  Future<void> claimPurchase({
    required String platform,
    required String productId,
    required String transactionId,
    required String verification,
    required List<String> itemIds,
  }) {
    return _client.rpc(
      'claim_purchase',
      params: {
        'p_platform': platform,
        'p_product_id': productId,
        'p_transaction_id': transactionId,
        'p_verification': verification,
        'p_item_ids': itemIds,
      },
    );
  }

  /// Worlds rented with coins, and when each rental runs out.
  Future<Map<String, DateTime>> fetchRentals() async {
    if (_client.auth.currentUser == null) return {};
    final rows = await _client
        .from('world_rentals')
        .select('world_id, expires_at');
    return {
      for (final r in rows)
        r['world_id'] as String: DateTime.parse(
          r['expires_at'] as String,
        ).toLocal(),
    };
  }

  /// Rents [worldId] for [days] (3, 7 or 30) with coins, adding to any
  /// time left. Returns when it now runs out.
  Future<DateTime> rentWorld(String worldId, int days) async {
    final result = await _client.rpc(
      'rent_world',
      params: {'p_world_id': worldId, 'p_days': days},
    );
    return DateTime.parse(result as String).toLocal();
  }

  Future<void> equip(ItemKind kind, String itemId) {
    return _client.rpc(
      'equip_item',
      params: {'p_kind': kind.apiName, 'p_item_id': itemId},
    );
  }
}
