import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/config/env.dart';
import '../../../core/audio/game_audio.dart';
import '../../../core/profiles/profile_providers.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/utopia_themes.dart';
import '../../../core/widgets/utopia_icons.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../data/store_repository.dart';
import '../domain/store_catalog.dart';

final storeRepositoryProvider = Provider<StoreRepository>(
  (ref) => StoreRepository(ref.watch(supabaseClientProvider)),
);

@immutable
class StoreState {
  const StoreState({
    this.owned = const {},
    this.rentals = const {},
    this.products = const {},
    this.coinPrices = const {},
    this.storeAvailable = false,
    this.loaded = false,
    this.busyProduct,
    this.message,
    this.justUnlocked,
    this.unlockedFocus,
    this.coinsAdded,
  });

  /// Item ids this player owns (free items are owned implicitly).
  final Set<String> owned;

  /// Worlds rented with coins, and when each rental runs out.
  final Map<String, DateTime> rentals;

  /// When the rental of [itemId] runs out, if it's still going.
  DateTime? rentedUntil(String itemId) {
    final until = rentals[itemId];
    return until != null && until.isAfter(DateTime.now()) ? until : null;
  }

  /// Live store listings by product id, when the store answered.
  final Map<String, ProductDetails> products;

  /// What each product costs in coins (while the real-money store is off).
  final Map<String, int> coinPrices;
  final bool storeAvailable;
  final bool loaded;

  /// A purchase in progress.
  final String? busyProduct;
  final String? message;

  /// The product that was just unlocked, for the celebration.
  final StoreProduct? justUnlocked;

  /// The item the player was looking at when they bought [justUnlocked]
  /// (one world of a pack), so "Travel there" goes to that world.
  final String? unlockedFocus;

  /// Coins just added by a purchase, for the celebration.
  final int? coinsAdded;

  /// Free, bought, or rented and still within the rental.
  bool isOwned(StoreItem item) =>
      item.free || owned.contains(item.id) || rentedUntil(item.id) != null;

  /// Bought for good (not just rented).
  bool isOwnedForever(StoreItem item) => item.free || owned.contains(item.id);

  String priceOf(StoreProduct product) {
    if (!Env.realMoneyStore) {
      final coins = coinPrices[product.id];
      return coins == null ? '…' : '${formatCoins(coins)} coins';
    }
    return products[product.id]?.price ?? product.fallbackPrice;
  }

  StoreState copyWith({
    Set<String>? owned,
    Map<String, DateTime>? rentals,
    Map<String, int>? coinPrices,
    Map<String, ProductDetails>? products,
    bool? storeAvailable,
    bool? loaded,
    String? busyProduct,
    bool clearBusy = false,
    String? message,
    bool clearMessage = false,
    StoreProduct? justUnlocked,
    String? unlockedFocus,
    bool clearUnlocked = false,
    int? coinsAdded,
    bool clearCoinsAdded = false,
  }) {
    return StoreState(
      owned: owned ?? this.owned,
      coinPrices: coinPrices ?? this.coinPrices,
      rentals: rentals ?? this.rentals,
      products: products ?? this.products,
      storeAvailable: storeAvailable ?? this.storeAvailable,
      loaded: loaded ?? this.loaded,
      busyProduct: clearBusy ? null : (busyProduct ?? this.busyProduct),
      message: clearMessage ? null : (message ?? this.message),
      justUnlocked: clearUnlocked ? null : (justUnlocked ?? this.justUnlocked),
      unlockedFocus: clearUnlocked
          ? null
          : (unlockedFocus ?? this.unlockedFocus),
      coinsAdded: clearCoinsAdded ? null : (coinsAdded ?? this.coinsAdded),
    );
  }
}

/// Buying, restoring and equipping themes and piece sets.
///
/// Purchases go through the App Store / Play Store (non-consumable
/// products, ids in [StoreCatalog.products]); each completed purchase is
/// reported to the backend, which records ownership. Until the products
/// exist in App Store Connect / the Play Console the store answers with
/// nothing to sell; debug builds then offer a test unlock instead so every
/// item can still be tried.
class StoreController extends StateNotifier<StoreState> {
  StoreController(this._ref) : super(const StoreState()) {
    _purchases = InAppPurchase.instance.purchaseStream.listen(
      _onPurchases,
      onError: (Object _) {},
    );
    refresh();
  }

  final Ref _ref;
  StreamSubscription<List<PurchaseDetails>>? _purchases;

  /// What the player was looking at when they last tapped buy.
  String? _focus;

  StoreRepository get _repo => _ref.read(storeRepositoryProvider);

  Future<void> refresh() async {
    try {
      final owned = await _repo.fetchOwned();
      final rentals = await _repo.fetchRentals();
      if (mounted) {
        state = state.copyWith(owned: owned, rentals: rentals);
        _leaveExpiredWorld();
      }
    } catch (_) {
      // Offline: keep what we knew, and never kick anyone out of a world
      // because a check failed.
    }
    if (!Env.realMoneyStore) {
      try {
        final prices = await _repo.fetchCoinPrices();
        if (mounted) state = state.copyWith(coinPrices: prices, loaded: true);
      } catch (_) {
        if (mounted) state = state.copyWith(loaded: true);
      }
      return;
    }
    try {
      final available = await InAppPurchase.instance.isAvailable();
      Map<String, ProductDetails> products = const {};
      if (available) {
        final response = await InAppPurchase.instance.queryProductDetails({
          for (final p in StoreCatalog.products) p.id,
          for (final p in StoreCatalog.coinPacks) p.id,
        });
        products = {for (final d in response.productDetails) d.id: d};
      }
      if (mounted) {
        state = state.copyWith(
          storeAvailable: available && products.isNotEmpty,
          products: products,
          loaded: true,
        );
      }
    } catch (_) {
      if (mounted) state = state.copyWith(loaded: true, storeAvailable: false);
    }
  }

  /// Whether this build can unlock items without the real store (debug and
  /// tester builds, while the store products don't exist yet).
  bool get canTestUnlock =>
      Env.realMoneyStore &&
      (kDebugMode || Env.testStore) &&
      !state.storeAvailable;

  /// Buys [product]. [focus] is the item on screen when they tapped buy
  /// (one world of a pack), so the celebration can take them there.
  Future<void> buy(StoreProduct product, {String? focus}) async {
    if (state.busyProduct != null) return;
    _focus = focus;
    if (!Env.realMoneyStore) return _buyWithCoins(product);
    final details = state.products[product.id];
    if (details == null) {
      if (canTestUnlock) {
        await _grant(
          product,
          transactionId: 'debug-${DateTime.now().microsecondsSinceEpoch}',
          verification: 'debug-unlock',
        );
      } else {
        state = state.copyWith(
          message: "The store isn't available right now. Try again in a bit.",
        );
      }
      return;
    }
    state = state.copyWith(busyProduct: product.id, clearMessage: true);
    try {
      final started = await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: details),
      );
      if (!started) state = state.copyWith(clearBusy: true);
    } catch (_) {
      state = state.copyWith(
        clearBusy: true,
        message: "Couldn't start the purchase.",
      );
    }
  }

  String priceOfPack(CoinPack pack) =>
      state.products[pack.id]?.price ?? pack.fallbackPrice;

  /// Buys a coin pack. The server credits the coins once the store
  /// confirms the payment (see [_onPurchases]).
  Future<void> buyCoins(CoinPack pack) async {
    if (state.busyProduct != null) return;
    if (!Env.realMoneyStore) {
      state = state.copyWith(message: 'Coin top-ups are coming soon.');
      return;
    }
    final details = state.products[pack.id];
    if (details == null) {
      if (canTestUnlock) {
        await _creditCoins(
          pack,
          transactionId: 'debug-${DateTime.now().microsecondsSinceEpoch}',
          verification: 'debug-unlock',
        );
      } else {
        state = state.copyWith(
          message: "The store isn't available right now. Try again soon.",
        );
      }
      return;
    }
    state = state.copyWith(busyProduct: pack.id, clearMessage: true);
    try {
      final started = await InAppPurchase.instance.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: details),
      );
      if (!started) state = state.copyWith(clearBusy: true);
    } catch (_) {
      state = state.copyWith(
        clearBusy: true,
        message: "Couldn't start the purchase.",
      );
    }
  }

  /// Returns whether the coins were credited.
  Future<bool> _creditCoins(
    CoinPack pack, {
    required String transactionId,
    required String verification,
  }) async {
    try {
      await _ref
          .read(supabaseClientProvider)
          .rpc(
            'claim_coin_purchase',
            params: {
              'p_platform': Platform.isIOS ? 'ios' : 'android',
              'p_product_id': pack.id,
              'p_transaction_id': transactionId,
              'p_verification': verification,
            },
          );
      state = state.copyWith(clearBusy: true, coinsAdded: pack.coins);
      _ref.read(gameAudioProvider).play(Sfx.purchase);
      return true;
    } catch (_) {
      state = state.copyWith(
        clearBusy: true,
        message:
            "Payment received. Your coins will arrive the next time you open Utopia.",
      );
      return false;
    }
  }

  void clearCoinsAdded() => state = state.copyWith(clearCoinsAdded: true);

  Future<void> restore() async {
    state = state.copyWith(message: 'Restoring your purchases');
    try {
      await InAppPurchase.instance.restorePurchases();
      await refresh();
      if (mounted) state = state.copyWith(message: 'Purchases restored.');
    } catch (_) {
      if (mounted) {
        state = state.copyWith(message: "Couldn't restore purchases.");
      }
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      final pack = StoreCatalog.coinPacks
          .where((x) => x.id == p.productID)
          .firstOrNull;
      if (pack != null) {
        if (p.status == PurchaseStatus.purchased) {
          final credited = await _creditCoins(
            pack,
            transactionId:
                p.purchaseID ?? '${p.productID}-${p.transactionDate}',
            verification: p.verificationData.serverVerificationData,
          );
          // Left unfinished, the store hands the purchase back on the next
          // launch and we try again.
          if (!credited) continue;
        } else if (p.status == PurchaseStatus.error) {
          state = state.copyWith(
            clearBusy: true,
            message: "The purchase didn't go through.",
          );
        } else if (p.status == PurchaseStatus.canceled) {
          state = state.copyWith(clearBusy: true);
        }
        if (p.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(p);
        }
        continue;
      }
      final product = StoreCatalog.products
          .where((x) => x.id == p.productID)
          .firstOrNull;
      switch (p.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (product != null) {
            await _grant(
              product,
              transactionId:
                  p.purchaseID ?? '${p.productID}-${p.transactionDate}',
              verification: p.verificationData.serverVerificationData,
              celebrate: p.status == PurchaseStatus.purchased,
            );
          }
        case PurchaseStatus.error:
          state = state.copyWith(
            clearBusy: true,
            message: 'The purchase didn’t go through.',
          );
        case PurchaseStatus.canceled:
          state = state.copyWith(clearBusy: true);
      }
      if (p.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(p);
      }
    }
  }

  Future<void> _grant(
    StoreProduct product, {
    required String transactionId,
    required String verification,
    bool celebrate = true,
  }) async {
    try {
      await _repo.claimPurchase(
        platform: Platform.isIOS ? 'ios' : 'android',
        productId: product.id,
        transactionId: transactionId,
        verification: verification,
        itemIds: product.itemIds,
      );
      state = state.copyWith(
        owned: {...state.owned, ...product.itemIds},
        clearBusy: true,
        justUnlocked: celebrate ? product : null,
        unlockedFocus: celebrate && product.itemIds.contains(_focus)
            ? _focus
            : null,
      );
      if (celebrate) _ref.read(gameAudioProvider).play(Sfx.purchase);
    } catch (_) {
      state = state.copyWith(
        clearBusy: true,
        message:
            "Payment received, but it didn't unlock yet. Tap Restore purchases.",
      );
    }
  }

  /// Buys [product] with coins (the server checks the price and balance).
  Future<void> _buyWithCoins(StoreProduct product) async {
    state = state.copyWith(busyProduct: product.id, clearMessage: true);
    try {
      await _repo.buyWithCoins(product.id);
      state = state.copyWith(
        owned: {...state.owned, ...product.itemIds},
        clearBusy: true,
        justUnlocked: product,
        unlockedFocus: product.itemIds.contains(_focus) ? _focus : null,
      );
      _ref.read(gameAudioProvider).play(Sfx.purchase);
    } catch (e) {
      final price = state.coinPrices[product.id];
      state = state.copyWith(
        clearBusy: true,
        message: '$e'.contains('insufficient balance')
            ? (price == null
                  ? 'Not enough coins yet.'
                  : 'You need ${formatCoins(price)} coins for that.')
            : "Couldn't unlock that. Check your connection and try again.",
      );
    }
  }

  void clearCelebration() => state = state.copyWith(clearUnlocked: true);
  void clearMessage() => state = state.copyWith(clearMessage: true);

  /// Equips a piece set (themes go through the teleport, see
  /// theme_teleport.dart). Returns an error message, or null.
  Future<String?> equipPieces(StoreItem item) async {
    if (!state.isOwned(item)) return 'Unlock it first.';
    try {
      await _repo.equip(item.kind, item.id);
      final me = _ref.read(currentUserProvider)?.id;
      if (me != null) _ref.invalidate(profileByIdProvider(me));
      _ref.read(gameAudioProvider).play(Sfx.reaction);
      return null;
    } catch (_) {
      return "Couldn't equip that. Try again?";
    }
  }

  /// A rented world whose time ran out: back to the default world.
  void _leaveExpiredWorld() {
    final current = _ref.read(themeControllerProvider);
    final item = StoreCatalog.themes
        .where((i) => i.id == current.id)
        .firstOrNull;
    if (item == null || state.isOwned(item)) return;
    _ref.read(themeControllerProvider.notifier).apply(UtopiaThemes.utopiaDark);
    rememberTheme(UtopiaThemes.utopiaDark.id);
    state = state.copyWith(
      message: 'Your time in ${current.name} ran out. Rent it again any time.',
    );
  }

  /// Rents a world with coins for [days] and returns an error to show, or
  /// null once it's yours.
  Future<String?> rentWorld(String worldId, int days) async {
    try {
      final until = await _repo.rentWorld(worldId, days);
      state = state.copyWith(rentals: {...state.rentals, worldId: until});
      _ref.read(gameAudioProvider).play(Sfx.purchase);
      return null;
    } catch (e) {
      if (e.toString().contains('insufficient balance')) {
        return 'You need more coins for that.';
      }
      return "Couldn't rent that world. Try again.";
    }
  }

  /// Remembers the theme on the server too, so it follows the player.
  void rememberTheme(String themeId) {
    _repo.equip(ItemKind.theme, themeId).ignore();
  }

  @override
  void dispose() {
    _purchases?.cancel();
    super.dispose();
  }
}

/// Rebuilt when the signed-in user changes, so ownership is always theirs.
final storeControllerProvider =
    StateNotifierProvider<StoreController, StoreState>((ref) {
      ref.watch(currentUserProvider.select((u) => u?.id));
      return StoreController(ref);
    });
