import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/store_catalog.dart';
import '../../../l10n/strings.dart';

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

  /// Has the server check a coin purchase with the App Store or Play Store
  /// and add its coins (the verify-purchase function). [purchaseId] is
  /// Apple's transaction id or Google's purchase token.
  Future<CoinPurchaseResult> verifyCoinPurchase({
    required String platform,
    required String productId,
    required String purchaseId,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'verify-purchase',
        body: {
          'platform': platform,
          'product_id': productId,
          'purchase_id': purchaseId,
        },
      );
      final data = res.data;
      if (data is Map && data['status'] == 'credited') {
        return CoinPurchaseCredited(
          coins: (data['coins'] as num?)?.toInt() ?? 0,
          mine: data['mine'] != false,
        );
      }
      if (data is Map && data['status'] == 'pending') {
        return const CoinPurchasePending();
      }
      return const CoinPurchaseRetry();
    } on FunctionException catch (e) {
      return e.status == 410
          ? const CoinPurchaseVoid()
          : const CoinPurchaseRetry();
    } catch (_) {
      return const CoinPurchaseRetry();
    }
  }

  /// Has the server check a Chip Maestro subscription with the store and
  /// start (or refresh) the plan: 'active', 'expired', 'other' (another
  /// account's), 'pending', or 'retry' when it couldn't be checked now.
  Future<String> verifyMaestro({
    required String platform,
    required String productId,
    required String purchaseId,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'verify-purchase',
        body: {
          'platform': platform,
          'product_id': productId,
          'purchase_id': purchaseId,
        },
      );
      final status = res.data is Map ? res.data['status'] : null;
      return switch (status) {
        'active' || 'expired' || 'other' || 'pending' => status as String,
        _ => 'retry',
      };
    } catch (_) {
      return 'retry';
    }
  }

  /// Whether this player can still buy the starter pack.
  /// Whether coins can be bought on the web yet (Flutterwave set up).
  Future<bool> webPaymentsOn() async {
    try {
      final res = await _client.functions.invoke(
        'web-pay',
        body: {'action': 'status'},
      );
      final data = res.data;
      return data is Map && data['on'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Each coin pack's web price, in [currency] where it has one (US
  /// dollars otherwise), ready to show ('₦7,500', '\$4.99').
  Future<Map<String, String>> webCoinShop(String currency) async {
    final rows = await _client.rpc(
      'web_coin_shop',
      params: {'p_currency': currency},
    );
    return {
      for (final r in (rows as List).cast<Map>())
        r['product_id'] as String: formatMoney(
          (r['amount'] as num).toDouble(),
          r['currency'] as String,
        ),
    };
  }

  /// Starts paying for [productId] on the web: the checkout page's link.
  /// Throws [WebPayException] with what to tell the player.
  Future<String> webCheckout(String productId, String currency) async {
    try {
      final res = await _client.functions.invoke(
        'web-pay',
        body: {
          'action': 'checkout',
          'product': productId,
          'currency': currency,
        },
      );
      final link = (res.data as Map?)?['link'];
      if (link is String && link.startsWith('https://')) return link;
    } on FunctionException catch (e) {
      final why = e.details is Map ? (e.details as Map)['error'] : null;
      throw WebPayException(switch (why) {
        'account' => strings.storeSaveYourAccountToBuy,
        'starter' => strings.storeYouAlreadyHaveTheStarter,
        'off' => strings.storeCoinTopUpsOnThe,
        _ => strings.storeCouldnTStartThePayment,
      });
    } catch (_) {}
    throw WebPayException(strings.storeCouldnTStartThePayment);
  }

  /// Back from checkout: whether payment [ref] went through ('paid',
  /// with its coins), as the payment service has it.
  Future<({String status, int coins})> webConfirm(
    String ref,
    String transactionId,
  ) async {
    try {
      final res = await _client.functions.invoke(
        'web-pay',
        body: {
          'action': 'confirm',
          'ref': ref,
          'transaction_id': transactionId,
        },
      );
      final data = res.data as Map? ?? const {};
      return (
        status: data['status'] as String? ?? 'unknown',
        coins: (data['coins'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return (status: 'error', coins: 0);
    }
  }

  Future<bool> starterOffer() async {
    final offers = await _client.rpc('coin_shop_offers');
    return offers is Map && offers['starter'] == true;
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

/// What the server said about a coin purchase.
sealed class CoinPurchaseResult {
  const CoinPurchaseResult();
}

/// Paid out (now, or already before). [mine] is false when it was bought
/// for another account signed in on this phone earlier, which got the
/// coins instead.
class CoinPurchaseCredited extends CoinPurchaseResult {
  const CoinPurchaseCredited({required this.coins, required this.mine});

  final int coins;
  final bool mine;
}

/// The store is still waiting for the money (a cash or bank payment).
class CoinPurchasePending extends CoinPurchaseResult {
  const CoinPurchasePending();
}

/// Cancelled or refunded: no coins, and nothing more to do.
class CoinPurchaseVoid extends CoinPurchaseResult {
  const CoinPurchaseVoid();
}

/// Couldn't be checked right now: keep it and try again later.
class CoinPurchaseRetry extends CoinPurchaseResult {
  const CoinPurchaseRetry();
}

/// Why a web payment couldn't start, in the player's words.
class WebPayException implements Exception {
  const WebPayException(this.message);

  final String message;
}

/// [amount] in [currency] the way people write it: '₦7,500', '\$4.99',
/// 'GH₵15'.
String formatMoney(double amount, String currency) {
  final symbols = {
    'USD': r'$',
    'NGN': '₦',
    'GBP': '£',
    'EUR': '€',
    'GHS': strings.storeGh,
    'KES': strings.storeKsh,
    'ZAR': 'R',
  };
  final whole = amount == amount.roundToDouble();
  final fixed = whole ? amount.round().toString() : amount.toStringAsFixed(2);
  final parts = fixed.split('.');
  final grouped = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  final number = parts.length > 1 ? '$grouped.${parts[1]}' : grouped;
  final symbol = symbols[currency];
  return symbol == null ? '$currency $number' : '$symbol$number';
}
