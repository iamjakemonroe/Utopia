import '../../../core/theme/utopia_themes.dart';

enum ItemKind {
  theme('theme'),
  ludoPieces('ludo_pieces'),
  chessPieces('chess_pieces');

  const ItemKind(this.apiName);

  /// The kind name the backend's equip_item expects.
  final String apiName;
}

/// Something a player can own and equip: a theme or a piece set.
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
    required this.fallbackPrice,
  });

  /// The App Store / Play product identifier.
  final String id;
  final String title;
  final List<String> itemIds;

  /// Shown when the store can't be reached for the localized price.
  final String fallbackPrice;
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
    this.badge,
  });

  final String id;
  final String name;
  final int coins;
  final int bonusPercent;
  final String fallbackPrice;
  final String? badge;
}

/// Everything sold in Utopia. Product ids must match the in-app purchase
/// products set up in App Store Connect and the Play Console: worlds and
/// piece sets are non-consumable, coin packs are consumable.
class StoreCatalog {
  StoreCatalog._();

  // ── Coins ────────────────────────────────────────────────────────────────

  /// A standard ladder: about 1,000 coins per dollar, with a growing bonus
  /// on bigger packs. Entries run 25-1,000, so the smallest pack is several
  /// games and nobody is ever a few coins short of a pack.
  static const coinPacks = [
    CoinPack(
      id: 'utopia.coins.pouch',
      name: 'Pouch',
      coins: 1000,
      bonusPercent: 0,
      fallbackPrice: r'$0.99',
    ),
    CoinPack(
      id: 'utopia.coins.sack',
      name: 'Sack',
      coins: 3300,
      bonusPercent: 10,
      fallbackPrice: r'$2.99',
    ),
    CoinPack(
      id: 'utopia.coins.chest',
      name: 'Chest',
      coins: 6000,
      bonusPercent: 20,
      fallbackPrice: r'$4.99',
      badge: 'Popular',
    ),
    CoinPack(
      id: 'utopia.coins.vault',
      name: 'Vault',
      coins: 13000,
      bonusPercent: 30,
      fallbackPrice: r'$9.99',
    ),
    CoinPack(
      id: 'utopia.coins.mountain',
      name: 'Mountain',
      coins: 30000,
      bonusPercent: 50,
      fallbackPrice: r'$19.99',
    ),
    CoinPack(
      id: 'utopia.coins.hoard',
      name: "Dragon's Hoard",
      coins: 80000,
      bonusPercent: 60,
      fallbackPrice: r'$49.99',
    ),
    CoinPack(
      id: 'utopia.coins.treasury',
      name: 'Sky Treasury',
      coins: 175000,
      bonusPercent: 75,
      fallbackPrice: r'$99.99',
      badge: 'Best value',
    ),
  ];

  // ── Ludo piece sets ──────────────────────────────────────────────────────

  static const ludoPieceSets = [
    StoreItem(
      id: 'classic',
      kind: ItemKind.ludoPieces,
      name: 'Classic Gloss',
      tagline: 'Shiny enamel pins, the timeless look.',
      free: true,
    ),
    StoreItem(
      id: 'bubble',
      kind: ItemKind.ludoPieces,
      name: 'Bubble Pop',
      tagline: 'Wobbly soap bubbles that shimmer as they hop.',
      free: true,
    ),
    StoreItem(
      id: 'jelly',
      kind: ItemKind.ludoPieces,
      name: 'Jelly Buddies',
      tagline: 'Squishy jelly critters that blink and jiggle.',
    ),
    StoreItem(
      id: 'crystal',
      kind: ItemKind.ludoPieces,
      name: 'Crystal Shards',
      tagline: 'Faceted gems that catch the light.',
    ),
    StoreItem(
      id: 'candy',
      kind: ItemKind.ludoPieces,
      name: 'Candy Swirl',
      tagline: 'Spinning lollipops, sweet and glossy.',
    ),
    StoreItem(
      id: 'cosmic',
      kind: ItemKind.ludoPieces,
      name: 'Cosmic Orbs',
      tagline: 'Tiny ringed planets with orbiting moons.',
    ),
    StoreItem(
      id: 'royal',
      kind: ItemKind.ludoPieces,
      name: 'Royal Crowns',
      tagline: 'Gold-crowned pieces with jewel hearts.',
    ),
  ];

  // ── Chess piece sets ─────────────────────────────────────────────────────

  static const chessPieceSets = [
    StoreItem(
      id: 'classic',
      kind: ItemKind.chessPieces,
      name: 'Classic',
      tagline: 'Ivory and violet, clean and readable.',
      free: true,
    ),
    StoreItem(
      id: 'chess_buddies',
      kind: ItemKind.chessPieces,
      name: 'Chess Buddies',
      tagline: 'Pieces with faces: they blink, cheer, panic and faint.',
    ),
    StoreItem(
      id: 'chess_monsters',
      kind: ItemKind.chessPieces,
      name: 'Monster Mash',
      tagline: 'Horns, fangs and one very big eye. They mean business.',
    ),
    StoreItem(
      id: 'chess_robots',
      kind: ItemKind.chessPieces,
      name: 'Robo Knights',
      tagline: 'Chrome pieces with LED faces that scan the board.',
    ),
    StoreItem(
      id: 'chess_crystal',
      kind: ItemKind.chessPieces,
      name: 'Crystal',
      tagline: 'Ice-clear pieces with a frosted glow.',
    ),
    StoreItem(
      id: 'chess_royal',
      kind: ItemKind.chessPieces,
      name: 'Royal Gold',
      tagline: 'Gold against obsidian, fit for a throne.',
    ),
    StoreItem(
      id: 'chess_neon',
      kind: ItemKind.chessPieces,
      name: 'Neon',
      tagline: 'Pieces that glow like an arcade at night.',
    ),
    StoreItem(
      id: 'chess_candy',
      kind: ItemKind.chessPieces,
      name: 'Candy',
      tagline: 'Bubblegum pink and mint, sweet as it gets.',
    ),
  ];

  // ── Themes ───────────────────────────────────────────────────────────────

  static const freeThemeIds = {'utopia_dark', 'azure_dusk', 'noir'};

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
      'utopia_calm',
      'utopia_adventure',
      'utopia_warm',
      'utopia_alien',
      'utopia_tech',
      'utopia_anime',
      'utopia_deep',
      'utopia_doodle',
      'utopia_dojo',
      'utopia_zombie',
      'utopia_heaven',
      'utopia_hell',
    ])
      StoreProduct(
        id: 'utopia.theme.$id',
        title: UtopiaThemes.byId(id).name,
        itemIds: [id],
        fallbackPrice: r'$2.99',
      ),
    for (final family in _colorFamilies)
      StoreProduct(
        id: 'utopia.themes.${family.$1}',
        title: '${family.$2} Pack',
        itemIds: [
          for (final t in UtopiaThemes.colors)
            if (t.id.startsWith('${family.$1}_')) t.id,
        ],
        fallbackPrice: r'$1.99',
      ),
    StoreProduct(
      id: 'utopia.themes.all',
      title: 'Every World',
      itemIds: [for (final t in UtopiaThemes.all) t.id],
      fallbackPrice: r'$9.99',
    ),
    for (final set in ludoPieceSets)
      if (!set.free)
        StoreProduct(
          id: 'utopia.pieces.${set.id}',
          title: set.name,
          itemIds: [set.id],
          fallbackPrice: set.id == 'cosmic' || set.id == 'royal'
              ? r'$4.99'
              : r'$3.99',
        ),
    for (final set in chessPieceSets)
      if (!set.free)
        StoreProduct(
          id: 'utopia.chess.${set.id.replaceFirst('chess_', '')}',
          title: '${set.name} Chess',
          itemIds: [set.id],
          fallbackPrice:
              const {
                'chess_royal',
                'chess_monsters',
                'chess_robots',
              }.contains(set.id)
              ? r'$4.99'
              : r'$3.99',
        ),
  ];

  static const _colorFamilies = [
    ('ruby', 'Ruby'),
    ('ember', 'Ember'),
    ('sunbeam', 'Sunbeam'),
    ('jade', 'Jade'),
    ('lagoon', 'Lagoon'),
    ('azure', 'Azure'),
    ('sapphire', 'Sapphire'),
    ('amethyst', 'Amethyst'),
    ('blossom', 'Blossom'),
    ('rosegold', 'Rose Gold'),
    ('onyx', 'Onyx'),
    ('pearl', 'Pearl'),
  ];

  // ── Worlds for coins ─────────────────────────────────────────────────────

  static const premiumWorldIds = {
    'utopia_calm',
    'utopia_adventure',
    'utopia_warm',
    'utopia_alien',
    'utopia_tech',
    'utopia_anime',
    'utopia_deep',
    'utopia_doodle',
    'utopia_dojo',
    'utopia_zombie',
    'utopia_heaven',
    'utopia_hell',
  };

  /// What renting a world for [days] costs in coins, or null if it can't
  /// be rented (free worlds). Shown only: the server charges its own price
  /// (_world_rent_price).
  static int? worldRentPrice(String worldId, int days) {
    if (freeThemeIds.contains(worldId)) return null;
    final premium = premiumWorldIds.contains(worldId);
    return switch (days) {
      3 => premium ? 2500 : 1200,
      7 => premium ? 6000 : 3000,
      30 => premium ? 20000 : 10000,
      _ => null,
    };
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
