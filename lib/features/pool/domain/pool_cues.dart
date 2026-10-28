/// The pool cues: what each one looks like, how rare it is, its stats at
/// every level, and what its next level costs.
///
/// Plain Dart: the apps show it, and the server's referee
/// (pool_referee.dart, compiled for the pool-table function) plays every
/// coin-table shot with the stats it gives, so a cue does at the table
/// exactly what its card says. The prices and levels the server charges
/// are in supabase/migrations/20261028120000_pool.sql, which a test
/// checks against this file.
library;

/// How rare a cue is. Regular cues are still pictures and go up to level
/// 5; animated ones (rare and up) move, go up to level 10 and reach
/// higher stats, each tier higher than the last.
enum CueTier {
  regular,
  rare,
  epic,
  legendary,
  mythic;

  bool get animated => this != regular;

  int get maxLevel => animated ? 10 : 5;
}

/// A cue's look, for the cue painter (shaders/pool_cue.frag's style).
enum CueLook {
  classic,
  oak,
  carbon,
  ivory,
  neon,
  frost,
  inferno,
  thunder,
  galaxy,
  phoenix,
  prism,
  dragon,
}

/// A cue's three stats, each 0 to 100: [power] (how hard it can hit),
/// [aim] (how far the aiming guide reaches) and [spin] (how far off
/// centre the tip may strike, so how much the cue ball curves and
/// screws).
class CueStats {
  const CueStats(this.power, this.aim, this.spin);

  final int power, aim, spin;

  /// The fastest the cue ball leaves this cue's tip (table units a
  /// second): 5.6 at no power, 7.6 at full.
  double get maxSpeed => 5.6 + 2.0 * power / 100;

  /// How far off centre the tip may strike, as a fraction of the ball's
  /// radius: 0.3 at no spin, 0.65 at full.
  double get tipOffset => 0.3 + 0.35 * spin / 100;

  /// How far the object ball's line reaches on a full hit (table units).
  double get guideReach => 0.08 + 0.55 * aim / 100;

  /// Whether the guide also shows where the cue ball goes off a cushion.
  bool get guideBounce => aim >= 70;

  @override
  bool operator ==(Object other) =>
      other is CueStats &&
      other.power == power &&
      other.aim == aim &&
      other.spin == spin;

  @override
  int get hashCode => Object.hash(power, aim, spin);

  @override
  String toString() => 'CueStats($power, $aim, $spin)';
}

/// A cue: its [id] (the store item), [tier], [look], its stats at level 1
/// ([first]) and at its top level ([best]), and its coin price (0 for a
/// free one; shown only, the server charges its own).
class PoolCue {
  const PoolCue({
    required this.id,
    required this.tier,
    required this.look,
    required this.first,
    required this.best,
    this.price = 0,
  });

  final String id;
  final CueTier tier;
  final CueLook look;
  final CueStats first, best;
  final int price;

  bool get free => price == 0;
  bool get animated => tier.animated;
  int get maxLevel => tier.maxLevel;

  /// The store product that sells it.
  String get productId => 'utopia.cue.${id.replaceFirst('cue_', '')}';

  /// Its stats at [level] (1 to [maxLevel]): evenly from [first] to
  /// [best].
  CueStats at(int level) {
    final l = level.clamp(1, maxLevel);
    int step(int a, int b) => a + ((b - a) * (l - 1) / (maxLevel - 1)).round();
    return CueStats(
      step(first.power, best.power),
      step(first.aim, best.aim),
      step(first.spin, best.spin),
    );
  }

  /// What going from [level] to the next costs, or null at the top.
  int? upgradeCost(int level) => cueUpgradeCost(tier, level);
}

/// Every cue, cheapest first.
const kPoolCues = [
  // Regular: still pictures, up to level 5.
  PoolCue(
    id: 'cue_classic',
    tier: CueTier.regular,
    look: CueLook.classic,
    first: CueStats(40, 40, 30),
    best: CueStats(52, 52, 42),
  ),
  PoolCue(
    id: 'cue_oak',
    tier: CueTier.regular,
    look: CueLook.oak,
    first: CueStats(44, 42, 34),
    best: CueStats(58, 56, 46),
    price: 20000,
  ),
  PoolCue(
    id: 'cue_carbon',
    tier: CueTier.regular,
    look: CueLook.carbon,
    first: CueStats(48, 42, 36),
    best: CueStats(62, 56, 50),
    price: 30000,
  ),
  PoolCue(
    id: 'cue_ivory',
    tier: CueTier.regular,
    look: CueLook.ivory,
    first: CueStats(44, 50, 38),
    best: CueStats(58, 64, 52),
    price: 40000,
  ),
  // Rare.
  PoolCue(
    id: 'cue_neon',
    tier: CueTier.rare,
    look: CueLook.neon,
    first: CueStats(52, 50, 46),
    best: CueStats(74, 72, 68),
    price: 50000,
  ),
  PoolCue(
    id: 'cue_frost',
    tier: CueTier.rare,
    look: CueLook.frost,
    first: CueStats(50, 54, 46),
    best: CueStats(72, 76, 68),
    price: 50000,
  ),
  // Epic.
  PoolCue(
    id: 'cue_inferno',
    tier: CueTier.epic,
    look: CueLook.inferno,
    first: CueStats(58, 54, 50),
    best: CueStats(84, 78, 74),
    price: 80000,
  ),
  PoolCue(
    id: 'cue_thunder',
    tier: CueTier.epic,
    look: CueLook.thunder,
    first: CueStats(56, 56, 54),
    best: CueStats(80, 80, 78),
    price: 80000,
  ),
  // Legendary.
  PoolCue(
    id: 'cue_galaxy',
    tier: CueTier.legendary,
    look: CueLook.galaxy,
    first: CueStats(62, 64, 60),
    best: CueStats(90, 92, 88),
    price: 120000,
  ),
  PoolCue(
    id: 'cue_phoenix',
    tier: CueTier.legendary,
    look: CueLook.phoenix,
    first: CueStats(64, 60, 62),
    best: CueStats(92, 88, 90),
    price: 120000,
  ),
  // Mythic.
  PoolCue(
    id: 'cue_prism',
    tier: CueTier.mythic,
    look: CueLook.prism,
    first: CueStats(66, 68, 66),
    best: CueStats(100, 100, 98),
    price: 200000,
  ),
  PoolCue(
    id: 'cue_dragon',
    tier: CueTier.mythic,
    look: CueLook.dragon,
    first: CueStats(70, 64, 66),
    best: CueStats(100, 96, 100),
    price: 200000,
  ),
];

/// The cue everyone has.
const kStarterCue = 'cue_classic';

/// The cue [id], or the starter cue if there's none by that id.
PoolCue poolCue(String? id) =>
    kPoolCues.where((c) => c.id == id).firstOrNull ?? kPoolCues.first;

/// What a cue of [tier] costs to take from [level] to the next, or null
/// at its top level. Regular cues climb cheaply to level 5; animated ones
/// climb to 10, the rarer the dearer.
int? cueUpgradeCost(CueTier tier, int level) {
  if (level < 1 || level >= tier.maxLevel) return null;
  if (!tier.animated) return const [2000, 4000, 7000, 12000][level - 1];
  const steps = [3000, 5000, 8000, 12000, 17000, 23000, 30000, 40000, 50000];
  final times = switch (tier) {
    CueTier.rare => 4,
    CueTier.epic => 5,
    CueTier.legendary => 6,
    _ => 8,
  };
  return steps[level - 1] * times ~/ 4;
}
