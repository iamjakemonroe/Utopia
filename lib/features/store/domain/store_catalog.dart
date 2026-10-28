import '../../../core/theme/utopia_themes.dart';
import '../../../l10n/strings.dart';
import '../../pool/domain/pool_cues.dart';
import '../../pool/presentation/pool_names.dart';

enum ItemKind {
  theme('theme'),
  ludoPieces('ludo_pieces'),
  chessPieces('chess_pieces'),
  poolCue('pool_cue');

  const ItemKind(this.apiName);

  /// The kind name the backend's equip_item expects.
  final String apiName;
}

/// Something a player can own and equip: a theme, a piece set or a pool
/// cue.
class StoreItem {
  const StoreItem({
    required this.id,
    required this.kind,
    required this.name,
    required this.tagline,
    this.free = false,
  });

  final String id;
  final ItemKind kind;
  final String name;
  final String tagline;
  final bool free;
}

/// A store product: what the player actually pays for. One product can
/// unlock several items (a theme family pack, the all-themes bundle).
class StoreProduct {
  const StoreProduct({
    required this.id,
    required this.title,
    required this.itemIds,
  });

  /// The product id the server prices in coins (see store_coin_prices).
  final String id;
  final String title;
  final List<String> itemIds;
}

/// A pack of coins (a consumable purchase). The server decides how many
/// coins each product id grants (see the coin_packs table); [coins] here is
/// for display.
class CoinPack {
  const CoinPack({
    required this.id,
    required this.name,
    required this.coins,
    required this.bonusPercent,
    required this.fallbackPrice,
    required this.art,
    this.badge,
  });

  final String id;
  final String name;
  final int coins;
  final int bonusPercent;
  final String fallbackPrice;

  /// Which picture the pack shows (see CoinPackArtPainter), growing with
  /// its size.
  final int art;
  final String? badge;
}

/// Everything sold in Utopia. Worlds, color families and piece sets are
/// bought with coins (the server sets their prices, see store_coin_prices).
/// Coin packs are the only App Store / Play products: consumables whose ids
/// must match the products set up in App Store Connect and the Play Console.
class StoreCatalog {
  StoreCatalog._();

  // ── Coins ────────────────────────────────────────────────────────────────

  /// About 10,000 coins per dollar, the rate the store's coin prices are set
  /// at (a premium world is 30,000 coins, about $3), with a bonus that
  /// grows with the pack.
  static final coinPacks = [
    CoinPack(
      id: 'utopia.coins.pouch',
      name: strings.storeCatalogPouch,
      coins: 10000,
      bonusPercent: 0,
      fallbackPrice: r'$0.99',
      art: 0,
    ),
    CoinPack(
      id: 'utopia.coins.sack',
      name: strings.storeCatalogSack,
      coins: 55000,
      bonusPercent: 10,
      fallbackPrice: r'$4.99',
      art: 1,
    ),
    CoinPack(
      id: 'utopia.coins.chest',
      name: strings.storeCatalogChest,
      coins: 120000,
      bonusPercent: 20,
      fallbackPrice: r'$9.99',
      art: 2,
      badge: strings.storeCatalogPopular,
    ),
    CoinPack(
      id: 'utopia.coins.vault',
      name: strings.storeCatalogVault,
      coins: 260000,
      bonusPercent: 30,
      fallbackPrice: r'$19.99',
      art: 3,
    ),
    CoinPack(
      id: 'utopia.coins.mountain',
      name: strings.storeCatalogMountain,
      coins: 750000,
      bonusPercent: 50,
      fallbackPrice: r'$49.99',
      art: 4,
    ),
    // The biggest pack: nothing above $99.99.
    CoinPack(
      id: 'utopia.coins.hoard',
      name: strings.storeCatalogDragonSHoard,
      coins: 1600000,
      bonusPercent: 60,
      fallbackPrice: r'$99.99',
      art: 5,
      badge: strings.storeCatalogBestValue,
    ),
  ];

  /// Double coins for the smallest price, once per player (the server
  /// says whether it's still on, see coin_shop_offers).
  static final starterPack = CoinPack(
    id: 'utopia.coins.starter',
    name: strings.storeCatalogStarterPack,
    coins: 20000,
    bonusPercent: 100,
    fallbackPrice: r'$0.99',
    art: 1,
    badge: strings.storeCatalogOnceOnly,
  );

  /// Every coin product id, for asking the store for local prices.
  static Set<String> get coinProductIds => {
    starterPack.id,
    for (final p in coinPacks) p.id,
  };

  // ── Ludo piece sets ──────────────────────────────────────────────────────

  static final ludoPieceSets = [
    StoreItem(
      id: 'classic',
      kind: ItemKind.ludoPieces,
      name: strings.storeCatalogClassicGloss,
      tagline: strings.storeCatalogShinyEnamelPinsTheTimeless,
      free: true,
    ),
    StoreItem(
      id: 'bubble',
      kind: ItemKind.ludoPieces,
      name: strings.storeCatalogBubblePop,
      tagline: strings.storeCatalogWobblySoapBubblesThatShimmer,
      free: true,
    ),
    StoreItem(
      id: 'jelly',
      kind: ItemKind.ludoPieces,
      name: strings.storeCatalogJellyBuddies,
      tagline: strings.storeCatalogSquishyJellyCrittersThatBlink,
    ),
    StoreItem(
      id: 'crystal',
      kind: ItemKind.ludoPieces,
      name: strings.storeCatalogCrystalShards,
      tagline: strings.storeCatalogFacetedGemsThatCatchThe,
    ),
    StoreItem(
      id: 'candy',
      kind: ItemKind.ludoPieces,
      name: strings.storeCatalogCandySwirl,
      tagline: strings.storeCatalogSpinningLollipopsSweetAndGlossy,
    ),
    StoreItem(
      id: 'cosmic',
      kind: ItemKind.ludoPieces,
      name: strings.storeCatalogCosmicOrbs,
      tagline: strings.storeCatalogTinyRingedPlanetsWithOrbiting,
    ),
    StoreItem(
      id: 'royal',
      kind: ItemKind.ludoPieces,
      name: strings.storeCatalogRoyalCrowns,
      tagline: strings.storeCatalogGoldCrownedPiecesWithJewel,
    ),
  ];

  // ── Chess piece sets ─────────────────────────────────────────────────────

  static final chessPieceSets = [
    StoreItem(
      id: 'classic',
      kind: ItemKind.chessPieces,
      name: strings.storeCatalogClassic,
      tagline: strings.storeCatalogIvoryAndVioletCleanAnd,
      free: true,
    ),
    StoreItem(
      id: 'chess_buddies',
      kind: ItemKind.chessPieces,
      name: strings.storeCatalogChessBuddies,
      tagline: strings.storeCatalogPiecesWithFacesTheyBlink,
    ),
    StoreItem(
      id: 'chess_monsters',
      kind: ItemKind.chessPieces,
      name: strings.storeCatalogMonsterMash,
      tagline: strings.storeCatalogHornsFangsAndOneVery,
    ),
    StoreItem(
      id: 'chess_robots',
      kind: ItemKind.chessPieces,
      name: strings.storeCatalogRoboKnights,
      tagline: strings.storeCatalogChromePiecesWithLedFaces,
    ),
    StoreItem(
      id: 'chess_crystal',
      kind: ItemKind.chessPieces,
      name: strings.storeCatalogCrystal,
      tagline: strings.storeCatalogIceClearPiecesWithA,
    ),
    StoreItem(
      id: 'chess_royal',
      kind: ItemKind.chessPieces,
      name: strings.storeCatalogRoyalGold,
      tagline: strings.storeCatalogGoldAgainstObsidianFitFor,
    ),
    StoreItem(
      id: 'chess_neon',
      kind: ItemKind.chessPieces,
      name: strings.storeCatalogNeon,
      tagline: strings.storeCatalogPiecesThatGlowLikeAn,
    ),
    StoreItem(
      id: 'chess_candy',
      kind: ItemKind.chessPieces,
      name: strings.storeCatalogCandy,
      tagline: strings.storeCatalogBubblegumPinkAndMintSweet,
    ),
  ];

  // ── Pool cues ────────────────────────────────────────────────────────────

  /// Every cue (its stats and levels are in pool_cues.dart).
  static final poolCues = [
    for (final cue in kPoolCues)
      StoreItem(
        id: cue.id,
        kind: ItemKind.poolCue,
        name: cueName(cue),
        tagline: cueTagline(cue),
        free: cue.free,
      ),
  ];

  static StoreItem cueItem(String id) =>
      poolCues.where((c) => c.id == id).firstOrNull ?? poolCues.first;

  // ── Themes ───────────────────────────────────────────────────────────────

  /// Free for everyone: the three worlds new players start in, plus Noir
  /// and Azure Dusk. Utopia Twilight (utopia_dark) is premium; players
  /// who had it before it was keep it.
  static const freeThemeIds = {
    'utopia_calm',
    'utopia_warm',
    'utopia_adventure',
    'azure_dusk',
    'noir',
  };

  static final themes = [
    for (final t in UtopiaThemes.all)
      StoreItem(
        id: t.id,
        kind: ItemKind.theme,
        name: t.name,
        tagline: t.tagline,
        free: freeThemeIds.contains(t.id),
      ),
  ];

  // ── Products ─────────────────────────────────────────────────────────────

  static final products = [
    for (final id in const [
      'utopia_dark',
      'utopia_alien',
      'utopia_tech',
      'utopia_anime',
      'utopia_deep',
      'utopia_doodle',
      'utopia_dojo',
      'utopia_zombie',
      'utopia_heaven',
      'utopia_hell',
      'utopia_music',
    ])
      StoreProduct(
        id: 'utopia.theme.$id',
        title: UtopiaThemes.byId(id).name,
        itemIds: [id],
      ),
    for (final family in _colorFamilies)
      StoreProduct(
        id: 'utopia.themes.${family.$1}',
        title: strings.storeCatalogPack(family.$2),
        itemIds: [
          for (final t in UtopiaThemes.colors)
            if (t.id.startsWith('${family.$1}_')) t.id,
        ],
      ),
    StoreProduct(
      id: 'utopia.themes.all',
      title: strings.storeCatalogEveryWorld,
      itemIds: [
        for (final t in UtopiaThemes.all)
          if (UtopiaThemes.sold(t.id)) t.id,
      ],
    ),
    for (final set in ludoPieceSets)
      if (!set.free)
        StoreProduct(
          id: 'utopia.pieces.${set.id}',
          title: set.name,
          itemIds: [set.id],
        ),
    for (final set in chessPieceSets)
      if (!set.free)
        StoreProduct(
          id: 'utopia.chess.${set.id.replaceFirst('chess_', '')}',
          title: strings.storeCatalogChess(set.name),
          itemIds: [set.id],
        ),
    for (final cue in kPoolCues)
      if (!cue.free)
        StoreProduct(id: cue.productId, title: cueName(cue), itemIds: [cue.id]),
  ];

  static final _colorFamilies = [
    ('ruby', strings.storeCatalogRuby),
    ('ember', strings.storeCatalogEmber),
    ('sunbeam', strings.storeCatalogSunbeam),
    ('jade', strings.storeCatalogJade),
    ('lagoon', strings.storeCatalogLagoon),
    ('azure', strings.storeCatalogAzure),
    ('sapphire', strings.storeCatalogSapphire),
    ('amethyst', strings.storeCatalogAmethyst),
    ('blossom', strings.storeCatalogBlossom),
    ('rosegold', strings.storeCatalogRoseGold),
    ('onyx', strings.storeCatalogOnyx),
    ('pearl', strings.storeCatalogPearl),
  ];

  // ── Worlds for coins ─────────────────────────────────────────────────────

  static const premiumWorldIds = {
    'utopia_dark',
    'utopia_alien',
    'utopia_tech',
    'utopia_anime',
    'utopia_deep',
    'utopia_doodle',
    'utopia_dojo',
    'utopia_zombie',
    'utopia_heaven',
    'utopia_hell',
    'utopia_music',
    'utopia_halloween',
    'utopia_winter',
  };

  /// What renting a world for [days] costs in coins, or null if it can't
  /// be rented (free worlds). Shown only: the server charges its own price
  /// (_world_rent_price).
  static int? worldRentPrice(String worldId, int days) {
    if (freeThemeIds.contains(worldId)) return null;
    final premium = premiumWorldIds.contains(worldId);
    // A week at a time (the server agrees, see _world_rent_price).
    return days == 7 ? (premium ? 6000 : 3000) : null;
  }

  static StoreItem? ludoSet(String id) =>
      ludoPieceSets.where((s) => s.id == id).firstOrNull;

  static StoreItem? chessSet(String id) =>
      chessPieceSets.where((s) => s.id == id).firstOrNull;

  /// The cheapest single product that unlocks [itemId] (the bundle is
  /// offered separately).
  static StoreProduct? productFor(String itemId) {
    final matches = [
      for (final p in products)
        if (p.itemIds.contains(itemId) && p.id != 'utopia.themes.all') p,
    ];
    return matches.isEmpty ? null : matches.first;
  }
}
