import 'package:flutter/material.dart';
import '../../l10n/strings.dart';

/// Which world a theme's background is built from (see utopia_world.dart).
enum WorldBiome {
  /// Floating islands with waterfalls over a sea of clouds.
  islands,

  /// A calm ocean horizon: rolling waves, a glittering reflection, birds.
  ocean,

  /// Layered mountain ranges, floating rocks and a drifting hot-air balloon.
  peaks,

  /// Rolling dunes under a huge low sun, with sky lanterns rising.
  dunes,

  /// Alien hills: glowing mushrooms, crystal spires, floating jellyfish
  /// creatures and a passing UFO.
  alien,

  /// A neon skyline over a synthwave grid, with flying cars.
  city,

  /// A snow-capped peak, a torii gate and cherry trees shedding petals.
  sakura,

  /// Under the sea: light shafts, coral, seaweed, fish and bubbles.
  reef,

  /// Ink on paper: the whole world hand-drawn, lines gently boiling.
  doodle,

  /// A samurai castle against a setting sun: shadow fighters sparring on a
  /// dojo floor, bamboo, lanterns, falling maple leaves and a dragon.
  dojo,

  /// A graveyard under a sick green moon: dead trees, leaning gravestones,
  /// crows, creeping fog, and the dead clawing their way up.
  zombie,

  /// Above the clouds: light pouring down, pearly gates, cloud temples,
  /// doves, and feathers drifting.
  heaven,

  /// Below everything: lava rivers, a smoking volcano, a black citadel,
  /// fire pits and embers under a blood-red moon.
  hell,

  /// A festival at night: a vinyl record for a moon, lasers, an equalizer
  /// skyline, a stage with pumping speakers and a crowd with their hands up.
  music,

  /// All Hallows' Eve: a harvest moon with a witch crossing it, a haunted
  /// manor, a twisted forest full of eyes, ghosts, a scarecrow, fog and a
  /// patch of jack-o'-lanterns.
  halloween,

  /// A snowy night by a frozen lake: the northern lights over the
  /// mountains, a log cabin with smoke curling from its chimney, a
  /// Christmas tree, a snowman, a skater on the ice, and Santa's sleigh
  /// crossing the moon.
  winter,

  /// A birthday party at dusk: bunting spelling HAPPY BIRTHDAY, fireworks,
  /// balloons drifting up, and a floating island with a cake and presents.
  /// Only ever seen on the player's own birthday.
  birthday,
}

enum CelestialKind { ringedPlanet, sun, moon }

/// Everything the animated world needs to paint one theme's version of it.
@immutable
class WorldStyle {
  const WorldStyle({
    required this.biome,
    required this.sky,
    required this.horizonGlow,
    required this.aurora,
    required this.celestial,
    required this.celestialColors,
    required this.ringColors,
    required this.cloudLight,
    required this.cloudShade,
    required this.layers,
    required this.land,
    required this.rock,
    required this.foliage,
    required this.glow,
    required this.sparkles,
    required this.haze,
    this.starDensity = 1,
  });

  final WorldBiome biome;

  /// Six sky colors, top to bottom. The first is the theme's background
  /// exactly, so screens whose body starts under the app bar have no seam.
  final List<Color> sky;
  final Color horizonGlow;

  /// Two aurora ribbon colors.
  final List<Color> aurora;
  final CelestialKind celestial;

  /// Four colors, lit side to shadow side.
  final List<Color> celestialColors;

  /// Two colors for a ringed planet's rings.
  final List<Color> ringColors;
  final Color cloudLight;
  final Color cloudShade;

  /// Three (top, bottom) color pairs for the ground layers, back to front:
  /// the cloud sea, ocean swells, dunes or mountain ranges.
  final List<(Color, Color)> layers;

  /// Light, mid, dark: island grass, dune crests, snowcaps.
  final List<Color> land;

  /// Light, mid, dark: rock undersides and cliffs.
  final List<Color> rock;

  /// Light, mid, dark: tree canopies.
  final List<Color> foliage;

  /// Crystals, lanterns and the balloon flame.
  final Color glow;

  /// Three colors for the fireflies / sparkles drifting up.
  final List<Color> sparkles;

  /// What distant things fade toward.
  final Color haze;

  /// 0-1, how many stars are out.
  final double starDensity;
}

/// One look for the whole app: UI colors plus the world behind it.
@immutable
class UtopiaTheme {
  const UtopiaTheme({
    required this.id,
    required this.name,
    required this.family,
    required this.tagline,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.accent,
    required this.trim,
    required this.trimBright,
    required this.glowRing,
    required this.textSecondary,
    required this.cardOutline,
    required this.world,
    this.textPrimary = const Color(0xFFF8F5FF),
    this.light = false,
  });

  final String id;
  final String name;

  /// Store grouping: 'Utopia' or a color family like 'Ruby'.
  final String family;
  final String tagline;

  final Color background;
  final Color surface;
  final Color surfaceElevated;

  /// The theme's primary color: buttons, highlights.
  final Color accent;

  /// Card and button rims (gold in the default theme).
  final Color trim;
  final Color trimBright;
  final Color glowRing;
  final Color textSecondary;
  final Color cardOutline;
  final WorldStyle world;

  /// Main text and icon color on the theme's background and surfaces.
  final Color textPrimary;

  /// A light world (paper, daylight): dark text, light surfaces, dark
  /// status bar icons.
  final bool light;
}

/// The theme catalog and the one that's active right now. Most of the app
/// reads colors through [AppColors] (app_colors.dart), which forwards here,
/// so switching [active] and rebuilding the tree recolors everything.
class UtopiaThemes {
  UtopiaThemes._();

  /// The look before the player's own world is known (signed out). Every
  /// account starts in one of [starters] instead.
  static const defaultId = 'utopia_dark';

  static UtopiaTheme active = utopiaTwilight;

  /// The free worlds a new account starts in, one picked at random by the
  /// server (profiles.equipped_theme's default).
  static final starters = [utopiaCalm, utopiaWarm, utopiaAdventure];

  /// The free world [userId] goes back to when a rented world runs out:
  /// always the same one for the same player.
  static UtopiaTheme starterFor(String? userId) {
    var hash = 0;
    for (final unit in (userId ?? '').codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return starters[hash % starters.length];
  }

  static UtopiaTheme byId(String? id) => find(id) ?? utopiaTwilight;

  /// The theme with [id], hidden ones included, or null.
  static UtopiaTheme? find(String? id) =>
      [...all, ...secret].where((t) => t.id == id).firstOrNull;

  /// Worlds that are never listed, sold or rented: the Birthday world, only
  /// ever given (by the server) on the player's own birthday.
  static final List<UtopiaTheme> secret = [utopiaBirthday];

  /// Event worlds and their season: earned by playing in their event, and
  /// only usable while it's on (never sold or rented).
  static const seasonal = {
    'utopia_halloween': 'halloween',
    'utopia_winter': 'winter',
  };

  /// Whether [id] can be bought or rented in the store.
  static bool sold(String id) =>
      !seasonal.containsKey(id) && !secret.any((t) => t.id == id);

  static final List<UtopiaTheme> utopia = [
    utopiaCalm,
    utopiaWarm,
    utopiaAdventure,
    noir,
    utopiaTwilight,
    utopiaAlien,
    utopiaTech,
    utopiaAnime,
    utopiaDeep,
    utopiaDoodle,
    utopiaDojo,
    utopiaZombie,
    utopiaHeaven,
    utopiaHell,
    utopiaMusic,
    utopiaHalloween,
    utopiaWinter,
  ];

  static final List<UtopiaTheme> colors = [
    for (final family in _families)
      for (final shade in _Shade.values) _colorTheme(family, shade),
  ];

  static final List<UtopiaTheme> all = [...utopia, ...colors];

  // ── The four Utopia worlds, hand-tuned ───────────────────────────────────

  static final utopiaTwilight = UtopiaTheme(
    // Its id stays utopia_dark: players own and wear it by that.
    id: 'utopia_dark',
    name: strings.utopiaThemesUtopiaTwilight,
    family: strings.utopiaThemesUtopia,
    tagline: strings.utopiaThemesTwilightIslandsFloatingOverA,
    background: Color(0xFF120B2E),
    surface: Color(0xFF241A4D),
    surfaceElevated: Color(0xFF2C2160),
    accent: Color(0xFF7C4DFF),
    trim: Color(0xFFFFC94D),
    trimBright: Color(0xFFFFE29A),
    glowRing: Color(0xFF9B7BFF),
    textSecondary: Color(0xFFB4A9D9),
    cardOutline: Color(0xFF0B0720),
    world: WorldStyle(
      biome: WorldBiome.islands,
      sky: [
        Color(0xFF120B2E),
        Color(0xFF1E1150),
        Color(0xFF34186B),
        Color(0xFF5A2582),
        Color(0xFF8A3A8C),
        Color(0xFFB45A8E),
      ],
      horizonGlow: Color(0x55FFB38A),
      aurora: [Color(0xFF6FF5D2), Color(0xFFC58BFF)],
      celestial: CelestialKind.ringedPlanet,
      celestialColors: [
        Color(0xFFFFD6EC),
        Color(0xFFD88AD8),
        Color(0xFF7443A8),
        Color(0xFF3A1D6B),
      ],
      ringColors: [Color(0xFFFFE29A), Color(0xFFFF9ECF)],
      cloudLight: Color(0xFFF3D2FF),
      cloudShade: Color(0xFF8C5BC0),
      layers: [
        (Color(0xFF8E5CC0), Color(0xFF3D1F72)),
        (Color(0xFFB07BD6), Color(0xFF55298A)),
        (Color(0xFFD6A2E6), Color(0xFF6E3A9E)),
      ],
      land: [Color(0xFFA6FFE3), Color(0xFF3FD9AE), Color(0xFF1FA586)],
      rock: [Color(0xFF7A55B0), Color(0xFF43247A), Color(0xFF1E0F45)],
      foliage: [Color(0xFFFFD0EA), Color(0xFFFF7EB8), Color(0xFFC2408A)],
      glow: Color(0xFFFFC94D),
      sparkles: [Color(0xFFFFE29A), Color(0xFF7DF5DA), Color(0xFFFFB3DA)],
      haze: Color(0xFF34186B),
    ),
  );

  /// Pure black and white, nothing in between. Free.
  static final noir = UtopiaTheme(
    id: 'noir',
    name: strings.utopiaThemesNoir,
    family: strings.utopiaThemesUtopia,
    tagline: strings.utopiaThemesPureBlackPureWhiteNothing,
    background: Color(0xFF000000),
    surface: Color(0xFF0D0D0D),
    surfaceElevated: Color(0xFF161616),
    // Dark enough for white labels on buttons, with white rims around them.
    accent: Color(0xFF2B2B2B),
    trim: Color(0xFFFFFFFF),
    trimBright: Color(0xFFFFFFFF),
    glowRing: Color(0xFFD9D9D9),
    textSecondary: Color(0xFFA6A6A6),
    cardOutline: Color(0xFF000000),
    world: WorldStyle(
      biome: WorldBiome.peaks,
      sky: [
        Color(0xFF000000),
        Color(0xFF040404),
        Color(0xFF0A0A0A),
        Color(0xFF141414),
        Color(0xFF222222),
        Color(0xFF383838),
      ],
      horizonGlow: Color(0x33FFFFFF),
      aurora: [Color(0xFFFFFFFF), Color(0xFF8C8C8C)],
      celestial: CelestialKind.moon,
      celestialColors: [
        Color(0xFFFFFFFF),
        Color(0xFFEDEDED),
        Color(0xFFBDBDBD),
        Color(0xFF6E6E6E),
      ],
      ringColors: [Color(0xFFFFFFFF), Color(0xFFBDBDBD)],
      cloudLight: Color(0xFFE6E6E6),
      cloudShade: Color(0xFF3D3D3D),
      layers: [
        (Color(0xFF3A3A3A), Color(0xFF141414)),
        (Color(0xFF262626), Color(0xFF0B0B0B)),
        (Color(0xFF161616), Color(0xFF000000)),
      ],
      land: [Color(0xFFFFFFFF), Color(0xFFD0D0D0), Color(0xFF8C8C8C)],
      rock: [Color(0xFF5C5C5C), Color(0xFF2B2B2B), Color(0xFF0F0F0F)],
      foliage: [Color(0xFFF0F0F0), Color(0xFFA8A8A8), Color(0xFF5A5A5A)],
      glow: Color(0xFFFFFFFF),
      sparkles: [Color(0xFFFFFFFF), Color(0xFFD6D6D6), Color(0xFF9E9E9E)],
      haze: Color(0xFF141414),
    ),
  );

  static final utopiaCalm = UtopiaTheme(
    id: 'utopia_calm',
    name: strings.utopiaThemesUtopiaCalm,
    family: strings.utopiaThemesUtopia,
    tagline: strings.utopiaThemesAGlassyOceanAtDusk,
    background: Color(0xFF0B1A2E),
    surface: Color(0xFF16304A),
    surfaceElevated: Color(0xFF1D3B59),
    accent: Color(0xFF3FB6E8),
    trim: Color(0xFFBDF4E8),
    trimBright: Color(0xFFE6FFF9),
    glowRing: Color(0xFF7FD8FF),
    textSecondary: Color(0xFF9FC3D9),
    cardOutline: Color(0xFF06101E),
    world: WorldStyle(
      biome: WorldBiome.ocean,
      sky: [
        Color(0xFF0B1A2E),
        Color(0xFF123056),
        Color(0xFF22507A),
        Color(0xFF4A7FA6),
        Color(0xFF9DB8D9),
        Color(0xFFF2C9D8),
      ],
      horizonGlow: Color(0x66FFD6E4),
      aurora: [Color(0xFF8CF2FF), Color(0xFFB9A8FF)],
      celestial: CelestialKind.moon,
      celestialColors: [
        Color(0xFFFFFFFF),
        Color(0xFFEAF4FF),
        Color(0xFFC3D8F0),
        Color(0xFF8FA9C9),
      ],
      ringColors: [Color(0xFFFFFFFF), Color(0xFFBDF4E8)],
      cloudLight: Color(0xFFFCE6F2),
      cloudShade: Color(0xFF6E8FB8),
      layers: [
        (Color(0xFF2E6C93), Color(0xFF123A5C)),
        (Color(0xFF235A80), Color(0xFF0E2F4D)),
        (Color(0xFF1A4A6C), Color(0xFF0A2440)),
      ],
      land: [Color(0xFFBFF6E4), Color(0xFF6FD8B8), Color(0xFF3AA58C)],
      rock: [Color(0xFF5C7FA6), Color(0xFF34557A), Color(0xFF1A3150)],
      foliage: [Color(0xFFD6FFF2), Color(0xFF7FE6C8), Color(0xFF3FB394)],
      glow: Color(0xFFBDF4E8),
      sparkles: [Color(0xFFE6FFF9), Color(0xFF8CF2FF), Color(0xFFFFD6E4)],
      haze: Color(0xFF4A7FA6),
      starDensity: 0.7,
    ),
  );

  static final utopiaAdventure = UtopiaTheme(
    id: 'utopia_adventure',
    name: strings.utopiaThemesUtopiaAdventure,
    family: strings.utopiaThemesUtopia,
    tagline: strings.utopiaThemesPeaksFloatingRocksAndA,
    background: Color(0xFF0D1F1C),
    surface: Color(0xFF173A35),
    surfaceElevated: Color(0xFF1E4842),
    accent: Color(0xFF1FB892),
    trim: Color(0xFFFFB74D),
    trimBright: Color(0xFFFFD699),
    glowRing: Color(0xFF5EE6C4),
    textSecondary: Color(0xFFA5CFC4),
    cardOutline: Color(0xFF061210),
    world: WorldStyle(
      biome: WorldBiome.peaks,
      sky: [
        Color(0xFF0D1F1C),
        Color(0xFF12362F),
        Color(0xFF1F5A4E),
        Color(0xFF3F8A70),
        Color(0xFFE0A15E),
        Color(0xFFFFC27A),
      ],
      horizonGlow: Color(0x66FFC27A),
      aurora: [Color(0xFF9CFFD9), Color(0xFFFFD699)],
      celestial: CelestialKind.sun,
      celestialColors: [
        Color(0xFFFFF6D6),
        Color(0xFFFFD27A),
        Color(0xFFFF9F45),
        Color(0xFFE0662E),
      ],
      ringColors: [Color(0xFFFFD699), Color(0xFFFF9F45)],
      cloudLight: Color(0xFFFFF0D6),
      cloudShade: Color(0xFF6FA88E),
      layers: [
        (Color(0xFF3E7A6A), Color(0xFF1C463D)),
        (Color(0xFF2C5E52), Color(0xFF15372F)),
        (Color(0xFF1C4239), Color(0xFF0B231E)),
      ],
      land: [Color(0xFFF4FFF9), Color(0xFFCFEFE4), Color(0xFF9FCFC0)],
      rock: [Color(0xFF6E8F7F), Color(0xFF3F5E52), Color(0xFF1F3630)],
      foliage: [Color(0xFFC8FF9C), Color(0xFF6FD66F), Color(0xFF2E9A55)],
      glow: Color(0xFFFF9F45),
      sparkles: [Color(0xFFFFD699), Color(0xFF9CFFD9), Color(0xFFFFFFFF)],
      haze: Color(0xFF3F8A70),
      starDensity: 0.5,
    ),
  );

  static final utopiaWarm = UtopiaTheme(
    id: 'utopia_warm',
    name: strings.utopiaThemesUtopiaWarm,
    family: strings.utopiaThemesUtopia,
    tagline: strings.utopiaThemesGoldenDunesAndASky,
    background: Color(0xFF24100E),
    surface: Color(0xFF3E1E1A),
    surfaceElevated: Color(0xFF4C2620),
    accent: Color(0xFFF26B45),
    trim: Color(0xFFFFD27A),
    trimBright: Color(0xFFFFE9B8),
    glowRing: Color(0xFFFFA07A),
    textSecondary: Color(0xFFE3BFAF),
    cardOutline: Color(0xFF140806),
    world: WorldStyle(
      biome: WorldBiome.dunes,
      sky: [
        Color(0xFF24100E),
        Color(0xFF4A1A22),
        Color(0xFF8A2E3A),
        Color(0xFFD45A3E),
        Color(0xFFF2994A),
        Color(0xFFFFD27A),
      ],
      horizonGlow: Color(0x77FFD27A),
      aurora: [Color(0xFFFFB38A), Color(0xFFFF7AA8)],
      celestial: CelestialKind.sun,
      celestialColors: [
        Color(0xFFFFFBE6),
        Color(0xFFFFE08A),
        Color(0xFFFFA94D),
        Color(0xFFF26B45),
      ],
      ringColors: [Color(0xFFFFE9B8), Color(0xFFFFA07A)],
      cloudLight: Color(0xFFFFE3C2),
      cloudShade: Color(0xFFB8574A),
      layers: [
        (Color(0xFFE08A4A), Color(0xFF9A4A2E)),
        (Color(0xFFC86A38), Color(0xFF7A3420)),
        (Color(0xFFA34E2C), Color(0xFF5A2416)),
      ],
      land: [Color(0xFFFFE0A8), Color(0xFFF2B56B), Color(0xFFC98543)],
      rock: [Color(0xFFB8735A), Color(0xFF7A4234), Color(0xFF42201A)],
      foliage: [Color(0xFFFFE9A8), Color(0xFFFFB84D), Color(0xFFD9822B)],
      glow: Color(0xFFFFB84D),
      sparkles: [Color(0xFFFFE9B8), Color(0xFFFFB84D), Color(0xFFFF8A6A)],
      haze: Color(0xFFD45A3E),
      starDensity: 0.45,
    ),
  );

  static final utopiaAlien = UtopiaTheme(
    id: 'utopia_alien',
    name: strings.utopiaThemesUtopiaAlien,
    family: strings.utopiaThemesUtopia,
    tagline: strings.utopiaThemesGlowingMushroomsTwoMoonsAnd,
    background: Color(0xFF0B0F24),
    surface: Color(0xFF17203D),
    surfaceElevated: Color(0xFF1E2A4D),
    accent: Color(0xFF2FB87E),
    trim: Color(0xFFB9FF66),
    trimBright: Color(0xFFE2FFB8),
    glowRing: Color(0xFF7CF5C8),
    textSecondary: Color(0xFFA9C7C0),
    cardOutline: Color(0xFF050813),
    world: WorldStyle(
      biome: WorldBiome.alien,
      sky: [
        Color(0xFF0B0F24),
        Color(0xFF141E45),
        Color(0xFF233066),
        Color(0xFF3A3F85),
        Color(0xFF6A4A9E),
        Color(0xFF9C5FB0),
      ],
      horizonGlow: Color(0x5566FFCC),
      aurora: [Color(0xFF7CFFB2), Color(0xFFC77DFF)],
      celestial: CelestialKind.ringedPlanet,
      celestialColors: [
        Color(0xFFE6FFD1),
        Color(0xFF9BE36A),
        Color(0xFF3F8F55),
        Color(0xFF1C4630),
      ],
      ringColors: [Color(0xFFC77DFF), Color(0xFF7CFFB2)],
      cloudLight: Color(0xFFD9C8FF),
      cloudShade: Color(0xFF5B4A9E),
      layers: [
        (Color(0xFF4B3F8C), Color(0xFF1E1A45)),
        (Color(0xFF3A6B5A), Color(0xFF132A24)),
        (Color(0xFF2C5A48), Color(0xFF0B1C17)),
      ],
      land: [Color(0xFFB9FF66), Color(0xFF5FD06A), Color(0xFF2E8F4A)],
      rock: [Color(0xFF8A7AE0), Color(0xFF3A2E7A), Color(0xFF1A1440)],
      foliage: [Color(0xFFFFB8EC), Color(0xFFC04FE0), Color(0xFF6A1F8C)],
      glow: Color(0xFF7CFFB2),
      sparkles: [Color(0xFFB9FF66), Color(0xFF7CF5FF), Color(0xFFFF9AE0)],
      haze: Color(0xFF233066),
    ),
  );

  static final utopiaTech = UtopiaTheme(
    id: 'utopia_tech',
    name: strings.utopiaThemesUtopiaTech,
    family: strings.utopiaThemesUtopia,
    tagline: strings.utopiaThemesANeonCityThatNever,
    background: Color(0xFF070A1A),
    surface: Color(0xFF121A33),
    surfaceElevated: Color(0xFF19234A),
    accent: Color(0xFFD12FC6),
    trim: Color(0xFF3DF5FF),
    trimBright: Color(0xFFBFFBFF),
    glowRing: Color(0xFFFF6BF5),
    textSecondary: Color(0xFFA8B4D9),
    cardOutline: Color(0xFF03050D),
    world: WorldStyle(
      biome: WorldBiome.city,
      sky: [
        Color(0xFF070A1A),
        Color(0xFF120F3A),
        Color(0xFF2A1259),
        Color(0xFF5A1A78),
        Color(0xFFA2268A),
        Color(0xFFFF4F8B),
      ],
      horizonGlow: Color(0x77FF4F8B),
      aurora: [Color(0xFF3DF5FF), Color(0xFFFF3DF2)],
      celestial: CelestialKind.sun,
      celestialColors: [
        Color(0xFFFFF3B0),
        Color(0xFFFFB23D),
        Color(0xFFFF4F8B),
        Color(0xFFB31E6F),
      ],
      ringColors: [Color(0xFF3DF5FF), Color(0xFFFF3DF2)],
      cloudLight: Color(0xFFFFB3E6),
      cloudShade: Color(0xFF5A1A78),
      layers: [
        (Color(0xFF2E2466), Color(0xFF141036)),
        (Color(0xFF1D1846), Color(0xFF0A0822)),
        (Color(0xFF0E0B24), Color(0xFF04030D)),
      ],
      land: [Color(0xFF3DF5FF), Color(0xFF2A9DB8), Color(0xFF145066)],
      rock: [Color(0xFF3A3570), Color(0xFF1E1A45), Color(0xFF0B0920)],
      foliage: [Color(0xFFFF3DF2), Color(0xFF3DF5FF), Color(0xFFFFD24D)],
      glow: Color(0xFFFF3DF2),
      sparkles: [Color(0xFF3DF5FF), Color(0xFFFF3DF2), Color(0xFFFFD24D)],
      haze: Color(0xFF2A1259),
      starDensity: 0.6,
    ),
  );

  static final utopiaAnime = UtopiaTheme(
    id: 'utopia_anime',
    name: strings.utopiaThemesUtopiaAnime,
    family: strings.utopiaThemesUtopia,
    tagline: strings.utopiaThemesCherryBlossomsAQuietShrine,
    background: Color(0xFF1A1230),
    surface: Color(0xFF2E2150),
    surfaceElevated: Color(0xFF3A2A63),
    accent: Color(0xFFE0558F),
    trim: Color(0xFFFFD6E8),
    trimBright: Color(0xFFFFF0F6),
    glowRing: Color(0xFFFF9EC7),
    textSecondary: Color(0xFFD9BCD8),
    cardOutline: Color(0xFF0E0A1C),
    world: WorldStyle(
      biome: WorldBiome.sakura,
      sky: [
        Color(0xFF1A1230),
        Color(0xFF2E1F57),
        Color(0xFF533A8A),
        Color(0xFF8C5BB0),
        Color(0xFFE08FB8),
        Color(0xFFFFD3C4),
      ],
      horizonGlow: Color(0x66FFD3C4),
      aurora: [Color(0xFFFFB3D9), Color(0xFFB9A8FF)],
      celestial: CelestialKind.moon,
      celestialColors: [
        Color(0xFFFFFFFF),
        Color(0xFFFFF0F5),
        Color(0xFFF2CDE0),
        Color(0xFFC79BB8),
      ],
      ringColors: [Color(0xFFFFD6E8), Color(0xFFFFFFFF)],
      cloudLight: Color(0xFFFFE6F0),
      cloudShade: Color(0xFFA07AB8),
      layers: [
        (Color(0xFF6E5AA8), Color(0xFF3A2A6B)),
        (Color(0xFF4F7A6E), Color(0xFF24423A)),
        (Color(0xFF3D6658), Color(0xFF17302A)),
      ],
      land: [Color(0xFFFFFFFF), Color(0xFFE6E0F5), Color(0xFFB8A8D9)],
      rock: [Color(0xFF7A6AB8), Color(0xFF4A3A80), Color(0xFF251B45)],
      foliage: [Color(0xFFFFE3F0), Color(0xFFFF9EC7), Color(0xFFE0609A)],
      glow: Color(0xFFE5483B),
      sparkles: [Color(0xFFFFD6E8), Color(0xFFFFFFFF), Color(0xFFFF9EC7)],
      haze: Color(0xFF533A8A),
      starDensity: 0.6,
    ),
  );

  /// A samurai castle at sunset, dark wood and lantern light: shadow
  /// fighters sparring, a dragon circling the sky.
  static final utopiaDojo = UtopiaTheme(
    id: 'utopia_dojo',
    name: strings.utopiaThemesUtopiaDojo,
    family: strings.utopiaThemesUtopia,
    tagline: strings.utopiaThemesASamuraiCastleAtSunset,
    background: Color(0xFF140B07),
    surface: Color(0xFF231510),
    surfaceElevated: Color(0xFF2E1C14),
    accent: Color(0xFFB8321C),
    trim: Color(0xFFD9A441),
    trimBright: Color(0xFFF2C46B),
    glowRing: Color(0xFFE07A3A),
    textSecondary: Color(0xFFC9AE95),
    cardOutline: Color(0xFF0B0604),
    world: WorldStyle(
      biome: WorldBiome.dojo,
      sky: [
        Color(0xFF140B07),
        Color(0xFF24120A),
        Color(0xFF3B1E10),
        Color(0xFF5E2E14),
        Color(0xFF8A4A1C),
        Color(0xFFC27A2E),
      ],
      horizonGlow: Color(0x66FF8A3D),
      aurora: [Color(0xFFFF8A3D), Color(0xFFB8321C)],
      celestial: CelestialKind.sun,
      celestialColors: [
        Color(0xFFFFE3A8),
        Color(0xFFFF9A3D),
        Color(0xFFD9481C),
        Color(0xFF8A1E10),
      ],
      ringColors: [Color(0xFFD9A441), Color(0xFFB8321C)],
      cloudLight: Color(0xFFD99A68),
      cloudShade: Color(0xFF5E2E14),
      layers: [
        (Color(0xFF6B3D22), Color(0xFF3A2013)),
        (Color(0xFF452717), Color(0xFF22120A)),
        (Color(0xFF2A170D), Color(0xFF100804)),
      ],
      land: [Color(0xFFD9A441), Color(0xFF8A5A2B), Color(0xFF4A2C17)],
      rock: [Color(0xFF6B4630), Color(0xFF3E2618), Color(0xFF1E120A)],
      foliage: [Color(0xFF9DB25E), Color(0xFF5E7A34), Color(0xFF34481E)],
      glow: Color(0xFFC8321E),
      sparkles: [Color(0xFFFFB45A), Color(0xFFFF7A3D), Color(0xFFFFD27A)],
      haze: Color(0xFF3B1E10),
      starDensity: 0.25,
    ),
  );

  /// A graveyard at midnight, all dark greens and fog. Worn with the Zombie
  /// Bite aura it gets deader still, and Chip gets bitten.
  static final utopiaZombie = UtopiaTheme(
    id: 'utopia_zombie',
    name: strings.utopiaThemesUtopiaZombie,
    family: strings.utopiaThemesUtopia,
    tagline: strings.utopiaThemesAGraveyardUnderASick,
    background: Color(0xFF060807),
    surface: Color(0xFF101511),
    surfaceElevated: Color(0xFF182019),
    accent: Color(0xFF4FA83A),
    trim: Color(0xFF8DB86A),
    trimBright: Color(0xFFC6F08C),
    glowRing: Color(0xFF6FD14A),
    textSecondary: Color(0xFFA3B09A),
    cardOutline: Color(0xFF030403),
    world: WorldStyle(
      biome: WorldBiome.zombie,
      sky: [
        Color(0xFF040605),
        Color(0xFF080D09),
        Color(0xFF0D150F),
        Color(0xFF132017),
        Color(0xFF1A2C1D),
        Color(0xFF243A25),
      ],
      horizonGlow: Color(0x4448C860),
      // Faint, so it reads as sickly mist rather than a light show.
      aurora: [Color(0x593FBF4A), Color(0x405A3A78)],
      celestial: CelestialKind.moon,
      celestialColors: [
        Color(0xFFF2FFE2),
        Color(0xFFCDEBA8),
        Color(0xFF86B062),
        Color(0xFF3E5A30),
      ],
      ringColors: [Color(0xFF6FD14A), Color(0xFF3E5A30)],
      cloudLight: Color(0xFF4A5E4A),
      cloudShade: Color(0xFF151F17),
      layers: [
        (Color(0xFF1C2A1E), Color(0xFF0E1610)),
        (Color(0xFF131D15), Color(0xFF090F0A)),
        (Color(0xFF0C130D), Color(0xFF050806)),
      ],
      land: [Color(0xFF3A4A34), Color(0xFF243022), Color(0xFF121A12)],
      rock: [Color(0xFF6E7468), Color(0xFF474D44), Color(0xFF262A24)],
      foliage: [Color(0xFF3E4A2E), Color(0xFF2A3220), Color(0xFF161B12)],
      glow: Color(0xFF7DFF3D),
      sparkles: [Color(0xFF9DFF5A), Color(0xFFCDEBA8), Color(0xFF6FD14A)],
      haze: Color(0xFF1A2C1D),
      starDensity: 0.35,
    ),
  );

  static final utopiaHeaven = UtopiaTheme(
    id: 'utopia_heaven',
    name: strings.utopiaThemesUtopiaHeaven,
    family: strings.utopiaThemesUtopia,
    tagline: strings.utopiaThemesPearlyGatesAboveTheClouds,
    background: Color(0xFF141A3A),
    surface: Color(0xFF1C2350),
    surfaceElevated: Color(0xFF262F66),
    accent: Color(0xFFD9A43A),
    trim: Color(0xFFF2D488),
    trimBright: Color(0xFFFFF1C4),
    glowRing: Color(0xFFFFE08A),
    textSecondary: Color(0xFFC4C9E8),
    cardOutline: Color(0xFF0A0E24),
    world: WorldStyle(
      biome: WorldBiome.heaven,
      sky: [
        Color(0xFF141A3A),
        Color(0xFF232E68),
        Color(0xFF46509A),
        Color(0xFF8A80C2),
        Color(0xFFDDB6CC),
        Color(0xFFFFE0B0),
      ],
      horizonGlow: Color(0x77FFE2A6),
      aurora: [Color(0x40FFF1C4), Color(0x30B8C8FF)],
      celestial: CelestialKind.sun,
      celestialColors: [
        Color(0xFFFFFFFF),
        Color(0xFFFFF6DC),
        Color(0xFFFFE08A),
        Color(0xFFF0B84A),
      ],
      ringColors: [Color(0xFFFFF1C4), Color(0xFFE0B84A)],
      cloudLight: Color(0xFFFFFFFF),
      cloudShade: Color(0xFFD6C8F0),
      layers: [
        (Color(0xFFFFFFFF), Color(0xFFE9E0FF)),
        (Color(0xFFF7F2FF), Color(0xFFDCD0F6)),
        (Color(0xFFFFFDF4), Color(0xFFEDE2D2)),
      ],
      land: [Color(0xFFFFFFFF), Color(0xFFF1EAFF), Color(0xFFD6C9EE)],
      rock: [Color(0xFFF6F2FC), Color(0xFFDDD4EE), Color(0xFFB4A8D2)],
      foliage: [Color(0xFFFFF1C4), Color(0xFFF2D488), Color(0xFFD9A43A)],
      glow: Color(0xFFFFE9A8),
      sparkles: [Color(0xFFFFF4D0), Color(0xFFFFFFFF), Color(0xFFFFD98A)],
      haze: Color(0xFFE8E0FF),
      starDensity: 0.5,
    ),
  );

  static final utopiaHell = UtopiaTheme(
    id: 'utopia_hell',
    name: strings.utopiaThemesUtopiaHell,
    family: strings.utopiaThemesUtopia,
    tagline: strings.utopiaThemesASeaOfFireUnder,
    background: Color(0xFF120504),
    surface: Color(0xFF1E0A07),
    surfaceElevated: Color(0xFF2A100B),
    accent: Color(0xFFD9381F),
    trim: Color(0xFFFF8A3D),
    trimBright: Color(0xFFFFC07A),
    glowRing: Color(0xFFFF5A2A),
    textSecondary: Color(0xFFD6A898),
    cardOutline: Color(0xFF060100),
    world: WorldStyle(
      biome: WorldBiome.hell,
      // Nearly black overhead, burning red down at the fire line.
      sky: [
        Color(0xFF030101),
        Color(0xFF0A0201),
        Color(0xFF1C0402),
        Color(0xFF3E0904),
        Color(0xFF7A1406),
        Color(0xFFC0360C),
      ],
      horizonGlow: Color(0x88FF6A2A),
      aurora: [Color(0x38FF5A1A), Color(0x28FFB040)],
      celestial: CelestialKind.moon,
      celestialColors: [
        Color(0xFFFFD2A6),
        Color(0xFFFF7A3A),
        Color(0xFFC0301A),
        Color(0xFF5A0E08),
      ],
      ringColors: [Color(0xFFFF8A3D), Color(0xFF5A0E08)],
      cloudLight: Color(0xFF5A2018),
      cloudShade: Color(0xFF1E0806),
      layers: [
        (Color(0xFF2E0E09), Color(0xFF140504)),
        (Color(0xFF210A07), Color(0xFF0E0302)),
        (Color(0xFF170605), Color(0xFF080101)),
      ],
      land: [Color(0xFF4A2018), Color(0xFF2A100B), Color(0xFF140605)],
      rock: [Color(0xFF4E2C26), Color(0xFF2C1713), Color(0xFF130807)],
      foliage: [Color(0xFFFF8A3D), Color(0xFFD9381F), Color(0xFF7A140A)],
      glow: Color(0xFFFF8A2A),
      sparkles: [Color(0xFFFFB050), Color(0xFFFF6A2A), Color(0xFFFFE0A0)],
      haze: Color(0xFF3A0E08),
      starDensity: 0.15,
    ),
  );

  static final utopiaMusic = UtopiaTheme(
    id: 'utopia_music',
    name: strings.utopiaThemesUtopiaMusic,
    family: strings.utopiaThemesUtopia,
    tagline: strings.utopiaThemesTheShowNeverEndsLasers,
    background: Color(0xFF0A0618),
    surface: Color(0xFF140C2A),
    surfaceElevated: Color(0xFF1E1240),
    accent: Color(0xFFFF2E9A),
    trim: Color(0xFF00E5FF),
    trimBright: Color(0xFF7CF7FF),
    glowRing: Color(0xFFB44CFF),
    textSecondary: Color(0xFFB8A8E0),
    cardOutline: Color(0xFF05020F),
    world: WorldStyle(
      biome: WorldBiome.music,
      // Midnight overhead, stage-light violet and magenta low down.
      sky: [
        Color(0xFF0A0618),
        Color(0xFF0B0524),
        Color(0xFF1A0A3D),
        Color(0xFF2E0F5C),
        Color(0xFF521578),
        Color(0xFF8A1F8F),
      ],
      horizonGlow: Color(0x77FF2E9A),
      aurora: [Color(0x4000E5FF), Color(0x40FF2E9A)],
      // Drawn as a turning vinyl record.
      celestial: CelestialKind.moon,
      celestialColors: [
        Color(0xFF3A3450),
        Color(0xFF1E1A2C),
        Color(0xFF110E1A),
        Color(0xFF07050C),
      ],
      ringColors: [Color(0xFF00E5FF), Color(0xFFFF2E9A)],
      cloudLight: Color(0xFF3A2470),
      cloudShade: Color(0xFF140A2E),
      layers: [
        (Color(0xFF1A0E3A), Color(0xFF0E0624)),
        (Color(0xFF140A2E), Color(0xFF09041A)),
        (Color(0xFF0E0624), Color(0xFF050210)),
      ],
      land: [Color(0xFF2E1F5C), Color(0xFF1C1240), Color(0xFF0E0824)],
      rock: [Color(0xFF3A2E66), Color(0xFF221A44), Color(0xFF110C24)],
      foliage: [Color(0xFFFF2E9A), Color(0xFFB44CFF), Color(0xFF00E5FF)],
      glow: Color(0xFF00E5FF),
      sparkles: [Color(0xFFFF2E9A), Color(0xFF00E5FF), Color(0xFFC6FF3D)],
      haze: Color(0xFF2A1250),
      starDensity: 0.6,
    ),
  );

  static final utopiaHalloween = UtopiaTheme(
    id: 'utopia_halloween',
    name: strings.utopiaThemesUtopiaHalloween,
    family: strings.utopiaThemesUtopia,
    tagline: strings.utopiaThemesAllHallowsEveEveryNight,
    background: Color(0xFF0D0716),
    surface: Color(0xFF1A0F26),
    surfaceElevated: Color(0xFF261636),
    accent: Color(0xFFF2761A),
    trim: Color(0xFFFFA53D),
    trimBright: Color(0xFFFFD08A),
    glowRing: Color(0xFF8BFF4A),
    textSecondary: Color(0xFFC9B3D9),
    cardOutline: Color(0xFF050208),
    world: WorldStyle(
      biome: WorldBiome.halloween,
      // Black-violet overhead down to a sick harvest orange.
      sky: [
        Color(0xFF0D0716),
        Color(0xFF140A22),
        Color(0xFF22103A),
        Color(0xFF3A1650),
        Color(0xFF6A2A4A),
        Color(0xFFB0501E),
      ],
      horizonGlow: Color(0x66FF7A1A),
      aurora: [Color(0x288BFF4A), Color(0x309B4BFF)],
      // Drawn by the scene: a huge harvest moon.
      celestial: CelestialKind.moon,
      celestialColors: [
        Color(0xFFFFF1C8),
        Color(0xFFFFC66A),
        Color(0xFFE8862A),
        Color(0xFF9A3E12),
      ],
      ringColors: [Color(0xFFFFA53D), Color(0xFF6A2A4A)],
      cloudLight: Color(0xFF3A2650),
      cloudShade: Color(0xFF140A20),
      layers: [
        (Color(0xFF1E1230), Color(0xFF100818)),
        (Color(0xFF160C24), Color(0xFF0A0512)),
        (Color(0xFF100818), Color(0xFF05020A)),
      ],
      land: [Color(0xFF2A1A36), Color(0xFF1A0F26), Color(0xFF0A0512)],
      rock: [Color(0xFF3A2C46), Color(0xFF221830), Color(0xFF100A18)],
      foliage: [Color(0xFFF2761A), Color(0xFFB0501E), Color(0xFF5A2A10)],
      glow: Color(0xFFFFA53D),
      sparkles: [Color(0xFFFFA53D), Color(0xFF8BFF4A), Color(0xFFB98CFF)],
      haze: Color(0xFF2A1A3A),
      starDensity: 0.45,
    ),
  );

  static final utopiaWinter = UtopiaTheme(
    id: 'utopia_winter',
    name: strings.utopiaThemesUtopiaWinter,
    family: strings.utopiaThemesUtopia,
    tagline: strings.utopiaThemesSnowOnACabinBy,
    background: Color(0xFF0A1230),
    surface: Color(0xFF121D42),
    surfaceElevated: Color(0xFF1B2A56),
    accent: Color(0xFF4FC3FF),
    trim: Color(0xFFBFE6FF),
    trimBright: Color(0xFFE8F6FF),
    glowRing: Color(0xFF5CFFB0),
    textSecondary: Color(0xFFB8C8E8),
    cardOutline: Color(0xFF050A1C),
    world: WorldStyle(
      biome: WorldBiome.winter,
      // Deep navy overhead down to a cold blue glow over the mountains.
      sky: [
        Color(0xFF060B22),
        Color(0xFF0A1230),
        Color(0xFF101C44),
        Color(0xFF1A2A5A),
        Color(0xFF2A3E74),
        Color(0xFF4A6098),
      ],
      horizonGlow: Color(0x557FA8FF),
      // The northern lights, strong: green over violet.
      aurora: [Color(0x665CFFB0), Color(0x558A6BFF)],
      celestial: CelestialKind.moon,
      celestialColors: [
        Color(0xFFFFFFFF),
        Color(0xFFE8F0FF),
        Color(0xFFB8C8E8),
        Color(0xFF8A9CC8),
      ],
      ringColors: [Color(0xFFBFE6FF), Color(0xFF4A6098)],
      cloudLight: Color(0xFF3A4A78),
      cloudShade: Color(0xFF141E40),
      layers: [
        (Color(0xFF2A3866), Color(0xFF1A2448)),
        (Color(0xFF1C2850), Color(0xFF121A36)),
        (Color(0xFF7084B8), Color(0xFF4A5C90)),
      ],
      land: [Color(0xFFC6D3F0), Color(0xFF7084B8), Color(0xFF3A4C80)],
      rock: [Color(0xFF5A5468), Color(0xFF3A3448), Color(0xFF1E1A2A)],
      foliage: [Color(0xFF1E5E46), Color(0xFF17463A), Color(0xFF0B2620)],
      glow: Color(0xFFFFC66A),
      sparkles: [Color(0xFFF2F6FF), Color(0xFF9FD8FF), Color(0xFF5CFFB0)],
      haze: Color(0xFF1A2A5A),
      starDensity: 0.85,
    ),
  );

  /// A birthday party at dusk, only ever seen on the player's own birthday.
  static final utopiaBirthday = UtopiaTheme(
    id: 'utopia_birthday',
    name: strings.utopiaThemesYourBirthday,
    family: strings.utopiaThemesUtopia,
    tagline: strings.utopiaThemesAPartyInTheSky,
    background: Color(0xFF241044),
    surface: Color(0xFF321A5A),
    surfaceElevated: Color(0xFF3F2370),
    accent: Color(0xFFFF6FAE),
    trim: Color(0xFFFFD166),
    trimBright: Color(0xFFFFE7A6),
    glowRing: Color(0xFFFFB3D9),
    textSecondary: Color(0xFFE2CFF5),
    cardOutline: Color(0xFF12061F),
    world: WorldStyle(
      biome: WorldBiome.birthday,
      // Deep plum overhead down to a warm peach sunset.
      sky: [
        Color(0xFF241044),
        Color(0xFF3A1A63),
        Color(0xFF6A2C82),
        Color(0xFFB4498A),
        Color(0xFFF07A72),
        Color(0xFFFFB37A),
      ],
      horizonGlow: Color(0x66FFB37A),
      aurora: [Color(0x30FF6FAE), Color(0x30FFD166)],
      // A low, warm sun behind the party island.
      celestial: CelestialKind.sun,
      celestialColors: [
        Color(0xFFFFF6D8),
        Color(0xFFFFE0A0),
        Color(0xFFFFB86B),
        Color(0xFFF08A5D),
      ],
      ringColors: [Color(0xFFFFD166), Color(0xFFFF6FAE)],
      cloudLight: Color(0xFFFFD1E8),
      cloudShade: Color(0xFF9C6BB8),
      layers: [
        (Color(0xFF7A3C8C), Color(0xFF4A2066)),
        (Color(0xFF5A2A78), Color(0xFF2E1450)),
        (Color(0xFF3A1A5A), Color(0xFF1E0C38)),
      ],
      land: [Color(0xFF8EE3B0), Color(0xFF5FC98F), Color(0xFF3A9E6E)],
      rock: [Color(0xFFC79BE0), Color(0xFF8E5DB5), Color(0xFF5A3584)],
      foliage: [Color(0xFFFF8FB9), Color(0xFFFF6FAE), Color(0xFFB4498A)],
      glow: Color(0xFFFFD166),
      sparkles: [Color(0xFFFFD166), Color(0xFFFF6FAE), Color(0xFF6EE7B7)],
      haze: Color(0xFF6A2C82),
      starDensity: 0.35,
    ),
  );

  /// Utopia sketched in ink on paper. The one light world: paper cards,
  /// ink text, ink buttons.
  static final utopiaDoodle = UtopiaTheme(
    id: 'utopia_doodle',
    name: strings.utopiaThemesUtopiaDoodle,
    family: strings.utopiaThemesUtopia,
    tagline: strings.utopiaThemesEverythingDrawnInInkOn,
    background: Color(0xFFF7F3EA),
    surface: Color(0xFFFFFDF7),
    surfaceElevated: Color(0xFFFFFFFF),
    // Ink buttons with paper-white labels.
    accent: Color(0xFF1F1E1B),
    trim: Color(0xFF1F1E1B),
    trimBright: Color(0xFF000000),
    glowRing: Color(0xFF9C978C),
    textSecondary: Color(0xFF5F5A50),
    cardOutline: Color(0xFF1F1E1B),
    textPrimary: Color(0xFF1C1B19),
    light: true,
    world: WorldStyle(
      biome: WorldBiome.doodle,
      sky: [
        Color(0xFFF7F3EA),
        Color(0xFFF7F3EA),
        Color(0xFFF5F1E7),
        Color(0xFFF3EFE4),
        Color(0xFFF1ECE1),
        Color(0xFFEFEADE),
      ],
      horizonGlow: Color(0x00000000),
      aurora: [Color(0xFF1C1B19), Color(0xFF8E8A80)],
      celestial: CelestialKind.sun,
      celestialColors: [
        Color(0xFFFFFFFF),
        Color(0xFFF7F3EA),
        Color(0xFF8E8A80),
        Color(0xFF1C1B19),
      ],
      ringColors: [Color(0xFF1C1B19), Color(0xFF8E8A80)],
      cloudLight: Color(0xFFFFFDF7),
      cloudShade: Color(0xFF8E8A80),
      layers: [
        (Color(0xFFF7F3EA), Color(0xFFEFEADE)),
        (Color(0xFFF3EFE4), Color(0xFFE9E3D5)),
        (Color(0xFFEFEADE), Color(0xFFE3DCCB)),
      ],
      land: [Color(0xFFFFFDF7), Color(0xFF8E8A80), Color(0xFF1C1B19)],
      rock: [Color(0xFFE9E3D5), Color(0xFF8E8A80), Color(0xFF1C1B19)],
      foliage: [Color(0xFFFFFDF7), Color(0xFF8E8A80), Color(0xFF1C1B19)],
      glow: Color(0xFF1C1B19),
      sparkles: [Color(0xFF1C1B19), Color(0xFF5F5A50), Color(0xFF8E8A80)],
      haze: Color(0xFFF7F3EA),
      starDensity: 0,
    ),
  );

  static final utopiaDeep = UtopiaTheme(
    id: 'utopia_deep',
    name: strings.utopiaThemesUtopiaDeep,
    family: strings.utopiaThemesUtopia,
    tagline: strings.utopiaThemesDownUnderTheWavesWhere,
    background: Color(0xFF0A4A75),
    surface: Color(0xFF082E4D),
    surfaceElevated: Color(0xFF0C3A5E),
    accent: Color(0xFF1FA5C4),
    trim: Color(0xFF7FFFE0),
    trimBright: Color(0xFFC9FFF2),
    glowRing: Color(0xFF4DE6FF),
    textSecondary: Color(0xFF9CC8D9),
    cardOutline: Color(0xFF020A17),
    world: WorldStyle(
      biome: WorldBiome.reef,
      sky: [
        Color(0xFF0A4A75),
        Color(0xFF083F68),
        Color(0xFF06345A),
        Color(0xFF05294A),
        Color(0xFF041F3A),
        Color(0xFF03162B),
      ],
      horizonGlow: Color(0x224DE6FF),
      aurora: [Color(0xFF7FFFE0), Color(0xFF4DE6FF)],
      celestial: CelestialKind.sun,
      celestialColors: [
        Color(0xFFFFFFFF),
        Color(0xFFCFFBFF),
        Color(0xFF7FE8F5),
        Color(0xFF2AA8C9),
      ],
      ringColors: [Color(0xFF7FFFE0), Color(0xFF4DE6FF)],
      cloudLight: Color(0xFFBFF6FF),
      cloudShade: Color(0xFF2A7A99),
      layers: [
        (Color(0xFF1F6E7A), Color(0xFF0B3540)),
        (Color(0xFFD9BE85), Color(0xFF7A6236)),
        (Color(0xFFE8D3A0), Color(0xFF9C8150)),
      ],
      land: [Color(0xFFFFE3A8), Color(0xFFE0B870), Color(0xFFA8803E)],
      rock: [Color(0xFF2E6E80), Color(0xFF1B4A5A), Color(0xFF0C2A33)],
      foliage: [Color(0xFFFF7A8A), Color(0xFFFFB04D), Color(0xFFB07BFF)],
      glow: Color(0xFF7FFFE0),
      sparkles: [Color(0xFFBFF6FF), Color(0xFF7FFFE0), Color(0xFFFFFFFF)],
      haze: Color(0xFF0A3D66),
      starDensity: 0,
    ),
  );

  // ── 12 color families × 3 shades, generated from a hue ──────────────────

  static final _families = [
    _Family(
      'ruby',
      strings.utopiaThemesRuby,
      352,
      0.75,
      WorldBiome.peaks,
      strings.utopiaThemesMoltenRidges,
    ),
    _Family(
      'ember',
      strings.utopiaThemesEmber,
      22,
      0.85,
      WorldBiome.dunes,
      strings.utopiaThemesCopperDunes,
    ),
    _Family(
      'sunbeam',
      strings.utopiaThemesSunbeam,
      45,
      0.9,
      WorldBiome.dunes,
      strings.utopiaThemesHoneySkies,
    ),
    _Family(
      'jade',
      strings.utopiaThemesJade,
      150,
      0.6,
      WorldBiome.islands,
      strings.utopiaThemesEmeraldIsles,
    ),
    _Family(
      'lagoon',
      strings.utopiaThemesLagoon,
      178,
      0.65,
      WorldBiome.ocean,
      strings.utopiaThemesTealShallows,
    ),
    _Family(
      'azure',
      strings.utopiaThemesAzure,
      205,
      0.75,
      WorldBiome.ocean,
      strings.utopiaThemesOpenSea,
    ),
    _Family(
      'sapphire',
      strings.utopiaThemesSapphire,
      225,
      0.7,
      WorldBiome.islands,
      strings.utopiaThemesDeepBlue,
    ),
    _Family(
      'amethyst',
      strings.utopiaThemesAmethyst,
      270,
      0.6,
      WorldBiome.islands,
      strings.utopiaThemesVioletIsles,
    ),
    _Family(
      'blossom',
      strings.utopiaThemesBlossom,
      325,
      0.7,
      WorldBiome.islands,
      strings.utopiaThemesCherryClouds,
    ),
    _Family(
      'rosegold',
      strings.utopiaThemesRoseGold,
      12,
      0.45,
      WorldBiome.dunes,
      strings.utopiaThemesRosySands,
    ),
    _Family(
      'onyx',
      strings.utopiaThemesOnyx,
      240,
      0.08,
      WorldBiome.peaks,
      strings.utopiaThemesObsidianPeaks,
    ),
    _Family(
      'pearl',
      strings.utopiaThemesPearl,
      215,
      0.14,
      WorldBiome.peaks,
      strings.utopiaThemesMoonlitSnow,
    ),
  ];

  static UtopiaTheme _colorTheme(_Family f, _Shade shade) {
    final h = f.hue;
    final s = f.saturation;
    // How light the base is: Dawn is brightest, Midnight deepest.
    final base = switch (shade) {
      _Shade.dawn => 0.12,
      _Shade.dusk => 0.09,
      _Shade.midnight => 0.06,
    };
    final skyLift = switch (shade) {
      _Shade.dawn => 1.35,
      _Shade.dusk => 1.0,
      _Shade.midnight => 0.7,
    };
    final neutral = s < 0.2;
    Color c(double hue, double sat, double light) => HSLColor.fromAHSL(
      1,
      hue % 360,
      sat.clamp(0.0, 1.0),
      light.clamp(0.0, 1.0),
    ).toColor();

    final background = c(h, s * 0.55, base);
    // Warm families keep the signature gold rim; the cool and neutral ones
    // get a silvery rim tinted toward their own hue.
    final goldTrim = h < 60 || h > 300;
    final trim = neutral || !goldTrim
        ? c(h, neutral ? 0.15 : 0.45, 0.84)
        : const Color(0xFFFFC94D);
    final trimBright = neutral || !goldTrim
        ? c(h, neutral ? 0.12 : 0.4, 0.93)
        : const Color(0xFFFFE29A);
    final accent = neutral
        ? c(h, 0.18, shade == _Shade.dawn ? 0.68 : 0.6)
        : c(h, s * 0.9 + 0.1, 0.6);

    final sky = [
      background,
      c(h, s * 0.6, base + 0.05 * skyLift),
      c(h + 8, s * 0.6, base + 0.12 * skyLift),
      c(h + 18, s * 0.55, base + 0.22 * skyLift),
      c(h + 32, s * 0.55, base + 0.34 * skyLift),
      c(h + 44, s * 0.6, base + 0.46 * skyLift),
    ];
    final layerBase = base + 0.2 * skyLift;

    return UtopiaTheme(
      id: '${f.id}_${shade.name}',
      name: '${f.name} ${shade.label}',
      family: f.name,
      tagline: '${f.mood}, ${shade.mood}.',
      background: background,
      surface: c(h, s * 0.45, base + 0.11),
      surfaceElevated: c(h, s * 0.45, base + 0.15),
      accent: accent,
      trim: trim,
      trimBright: trimBright,
      glowRing: c(h, neutral ? 0.25 : s * 0.9, 0.72),
      textSecondary: c(h, neutral ? 0.1 : 0.35, 0.76),
      cardOutline: c(h, s * 0.5, 0.035),
      world: WorldStyle(
        biome: f.biome,
        sky: sky,
        horizonGlow: c(h + 50, 0.9, 0.7).withValues(alpha: 0.33 * skyLift),
        aurora: [c(h + 150, 0.8, 0.68), c(h + 60, 0.8, 0.72)],
        celestial: switch (f.biome) {
          WorldBiome.islands => CelestialKind.ringedPlanet,
          WorldBiome.dunes => CelestialKind.sun,
          WorldBiome.ocean || WorldBiome.peaks =>
            shade == _Shade.dawn ? CelestialKind.sun : CelestialKind.moon,
          _ => CelestialKind.moon,
        },
        celestialColors: [
          c(h + 30, 0.9, 0.93),
          c(h + 20, 0.75, 0.72),
          c(h, 0.55, 0.45),
          c(h - 10, 0.5, 0.24),
        ],
        ringColors: [c(h + 40, 0.9, 0.82), c(h - 20, 0.8, 0.75)],
        cloudLight: c(h + 30, 0.6, 0.88),
        cloudShade: c(h, 0.4, 0.42),
        layers: [
          (
            c(h + 10, s * 0.5, layerBase + 0.14),
            c(h, s * 0.55, layerBase - 0.04),
          ),
          (
            c(h + 14, s * 0.5, layerBase + 0.22),
            c(h + 4, s * 0.55, layerBase + 0.02),
          ),
          (
            c(h + 18, s * 0.5, layerBase + 0.32),
            c(h + 8, s * 0.55, layerBase + 0.08),
          ),
        ],
        land: [
          c(_towards(150, h, 0.3), 0.75, 0.82),
          c(_towards(150, h, 0.3), 0.6, 0.6),
          c(_towards(150, h, 0.3), 0.6, 0.42),
        ],
        rock: [c(h, 0.3, 0.46), c(h, 0.35, 0.28), c(h, 0.4, 0.13)],
        foliage: [
          c(h + 15, 0.85, 0.86),
          c(h + 10, 0.75, 0.66),
          c(h, 0.65, 0.46),
        ],
        glow: neutral ? const Color(0xFFDDE8FF) : c(h + 18, 0.95, 0.64),
        sparkles: [
          c(h + 40, 0.9, 0.85),
          c(h + 150, 0.8, 0.78),
          c(h, 0.85, 0.82),
        ],
        haze: sky[2],
        starDensity: switch (shade) {
          _Shade.dawn => 0.35,
          _Shade.dusk => 0.8,
          _Shade.midnight => 1,
        },
      ),
    );
  }

  /// [from] moved [amount] (0-1) of the way around the hue wheel to [to].
  static double _towards(double from, double to, double amount) {
    final delta = ((to - from + 540) % 360) - 180;
    return from + delta * amount;
  }
}

class _Family {
  const _Family(
    this.id,
    this.name,
    this.hue,
    this.saturation,
    this.biome,
    this.mood,
  );

  final String id;
  final String name;
  final double hue;
  final double saturation;
  final WorldBiome biome;
  final String mood;
}

enum _Shade {
  dawn('Dawn', 'first light'),
  dusk('Dusk', 'golden hour'),
  midnight('Midnight', 'starlit');

  const _Shade(this.label, this.mood);

  final String label;
  final String mood;
}
