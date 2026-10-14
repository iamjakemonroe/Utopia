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
    this.starterOffer = false,
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

  /// The coin packs' live store listings by product id (with the local
  /// price), when the store answered.
  final Map<String, ProductDetails> products;

  /// What each product costs in coins (set on the server).
  final Map<String, int> coinPrices;
  final bool storeAvailable;

  /// Whether this player can still buy the starter pack.
  final bool starterOffer;
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
    final coins = coinPrices[product.id];
    return coins == null ? '…' : '${formatCoins(coins)} coins';
  }

  StoreState copyWith({
    Set<String>? owned,
    Map<String, DateTime>? rentals,
    Map<String, int>? coinPrices,
    Map<String, ProductDetails>? products,
    bool? storeAvailable,
    bool? starterOffer,
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
      starterOffer: starterOffer ?? this.starterOffer,
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

/// Buying and equipping worlds and piece sets, and buying coins.
///
/// Worlds, color families and piece sets are bought with coins (the server
/// checks the price and balance). Coins are bought through the App Store /
/// Play Store (consumable products, ids in [StoreCatalog.coinPacks]), with
/// real-money top-ups on ([Env.realMoneyStore]). Each payment goes to the
/// verify-purchase function, which checks it with the store and adds the
/// coins; only then is the purchase finished, so one that couldn't be
/// checked comes back on the next launch and is tried again.
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

  /// Purchases being checked right now, so one the store reports twice is
  /// only sent once.
  final Set<String> _checking = {};

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
    try {
      final prices = await _repo.fetchCoinPrices();
      if (mounted) state = state.copyWith(coinPrices: prices);
    } catch (_) {}
    if (!Env.realMoneyStore) {
      if (mounted) state = state.copyWith(loaded: true);
      return;
    }
    try {
      final starter = await _repo.starterOffer();
      if (mounted) state = state.copyWith(starterOffer: starter);
    } catch (_) {}
    try {
      final available = await InAppPurchase.instance.isAvailable();
      Map<String, ProductDetails> products = const {};
      if (available) {
        final response = await InAppPurchase.instance.queryProductDetails(
          StoreCatalog.coinProductIds,
        );
        products = {for (final d in response.productDetails) d.id: d};
      }
      if (mounted) {
        state = state.copyWith(
          storeAvailable: available && products.isNotEmpty,
          products: products,
          loaded: true,
        );
      }
      // Google hands back coin purchases that were paid for but never
      // finished (the app closed first) only when asked. Apple sends its
      // own unfinished ones by itself at launch.
      if (available && Platform.isAndroid) {
        await InAppPurchase.instance.restorePurchases();
      }
    } catch (_) {
      if (mounted) state = state.copyWith(loaded: true, storeAvailable: false);
    }
  }

  /// Whether this build can add coins without the real store (debug and
  /// tester builds, while the store products don't exist yet).
  bool get canTestUnlock =>
      Env.realMoneyStore &&
      (kDebugMode || Env.testStore) &&
      !state.storeAvailable;

  /// Buys [product] with coins. [focus] is the item on screen when they
  /// tapped buy (one world of a pack), so the celebration can take them
  /// there.
  Future<void> buy(StoreProduct product, {String? focus}) async {
    if (state.busyProduct != null) return;
    _focus = focus;
    return _buyWithCoins(product);
  }

  /// The coin packs to show: the starter pack first while it's on.
  List<CoinPack> get packsOnSale => [
    if (state.starterOffer &&
        (state.products.containsKey(StoreCatalog.starterPack.id) ||
            canTestUnlock))
      StoreCatalog.starterPack,
    ...StoreCatalog.coinPacks,
  ];

  String priceOfPack(CoinPack pack) =>
      state.products[pack.id]?.price ?? pack.fallbackPrice;

  /// Buys a coin pack. The coins are added once the server has checked the
  /// payment with the store (see [_onPurchases]).
  Future<void> buyCoins(CoinPack pack) async {
    if (state.busyProduct != null) return;
    if (!Env.realMoneyStore) {
      state = state.copyWith(message: 'Coin top-ups are coming soon.');
      return;
    }
    final me = _ref.read(currentUserProvider)?.id;
    if (me == null) {
      state = state.copyWith(message: 'Sign in to buy coins.');
      return;
    }
    final details = state.products[pack.id];
    if (details == null) {
      if (canTestUnlock) {
        await _demoCoins(pack);
      } else {
        state = state.copyWith(
          message: "The store isn't available right now. Try again soon.",
        );
      }
      return;
    }
    state = state.copyWith(busyProduct: pack.id, clearMessage: true);
    try {
      // The account goes with the purchase (Apple's appAccountToken,
      // Google's account id), so its coins always reach this player.
      final started = await InAppPurchase.instance.buyConsumable(
        purchaseParam: PurchaseParam(
          productDetails: details,
          applicationUserName: me,
        ),
        // The server uses it up once the coins are added.
        autoConsume: !Platform.isAndroid,
      );
      if (!started) state = state.copyWith(clearBusy: true);
    } catch (_) {
      state = state.copyWith(
        clearBusy: true,
        message: "Couldn't start the purchase.",
      );
    }
  }

  /// Test builds only: the old free top-up, while the store has no products.
  Future<void> _demoCoins(CoinPack pack) async {
    try {
      await _ref
          .read(supabaseClientProvider)
          .rpc(
            'claim_coin_purchase',
            params: {
              'p_platform': Platform.isIOS ? 'ios' : 'android',
              'p_product_id': pack.id,
              'p_transaction_id':
                  'debug-${DateTime.now().microsecondsSinceEpoch}',
              'p_verification': 'debug-unlock',
            },
          );
      state = state.copyWith(clearBusy: true, coinsAdded: pack.coins);
      _ref.read(gameAudioProvider).play(Sfx.purchase);
    } catch (_) {
      state = state.copyWith(
        clearBusy: true,
        message: "Test top-ups aren't available on this server.",
      );
    }
  }

  void clearCoinsAdded() => state = state.copyWith(clearCoinsAdded: true);

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      final pack = [
        StoreCatalog.starterPack,
        ...StoreCatalog.coinPacks,
      ].where((x) => x.id == p.productID).firstOrNull;
      switch (p.status) {
        case PurchaseStatus.purchased || PurchaseStatus.restored:
          // Anything else (an old world bought with money) has nothing to
          // check here; finishing it stops the store sending it again.
          if (pack != null && !await _check(p, pack)) continue;
        case PurchaseStatus.pending:
          state = state.copyWith(
            clearBusy: true,
            message:
                'Your payment is still going through. Your coins arrive as soon as it does.',
          );
          continue;
        case PurchaseStatus.error:
          state = state.copyWith(
            clearBusy: true,
            message: "The purchase didn't go through.",
          );
        case PurchaseStatus.canceled:
          state = state.copyWith(clearBusy: true);
      }
      if (p.pendingCompletePurchase) {
        try {
          await InAppPurchase.instance.completePurchase(p);
        } catch (_) {
          // Unfinished, the store hands it back later and it's settled then.
        }
      }
    }
  }

  /// Has the server check [p] with the store and add its coins. Returns
  /// whether the purchase is settled (paid out, or void) and can be
  /// finished.
  Future<bool> _check(PurchaseDetails p, CoinPack pack) async {
    final id = Platform.isIOS
        ? p.purchaseID
        : p.verificationData.serverVerificationData;
    if (id == null || id.isEmpty || !_checking.add(id)) return false;
    try {
      final result = await _repo.verifyCoinPurchase(
        platform: Platform.isIOS ? 'ios' : 'android',
        productId: pack.id,
        purchaseId: id,
      );
      if (!mounted) return false;
      switch (result) {
        case CoinPurchaseCredited(:final coins, :final mine):
          if (mine) {
            state = state.copyWith(
              clearBusy: true,
              coinsAdded: coins > 0 ? coins : null,
              starterOffer: pack.id == StoreCatalog.starterPack.id
                  ? false
                  : null,
            );
            // The balance on screen follows by itself (it's live).
            if (coins > 0) _ref.read(gameAudioProvider).play(Sfx.purchase);
          } else {
            state = state.copyWith(
              clearBusy: true,
              message: 'Those coins went to the account that bought them.',
            );
          }
          return true;
        case CoinPurchasePending():
          state = state.copyWith(
            clearBusy: true,
            message:
                'Your payment is still going through. Your coins arrive as soon as it does.',
          );
          return false;
        case CoinPurchaseVoid():
          state = state.copyWith(
            clearBusy: true,
            message: 'That payment was cancelled, so no coins were added.',
          );
          return true;
        case CoinPurchaseRetry():
          state = state.copyWith(
            clearBusy: true,
            message:
                'Payment received. Your coins will arrive the next time you open Utopia.',
          );
          return false;
      }
    } finally {
      _checking.remove(id);
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
