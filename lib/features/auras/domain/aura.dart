import 'package:flutter/material.dart';
import '../../../l10n/strings.dart';

/// Cheapest to wildest. Mythic sits above legendary.
enum AuraTier { common, rare, legendary, mythic }

extension AuraTierInfo on AuraTier {
  String get title => switch (this) {
    AuraTier.common => strings.auraCommon,
    AuraTier.rare => strings.auraRare,
    AuraTier.legendary => strings.auraLegendary,
    AuraTier.mythic => strings.auraMythic,
  };

  Color get color => switch (this) {
    AuraTier.common => const Color(0xFF3DDC97),
    AuraTier.rare => const Color(0xFF4DA3FF),
    AuraTier.legendary => const Color(0xFFFFB020),
    AuraTier.mythic => const Color(0xFFFF1F3D),
  };

  IconData get icon => switch (this) {
    AuraTier.common => Icons.auto_awesome_rounded,
    AuraTier.rare => Icons.diamond_rounded,
    AuraTier.legendary => Icons.local_fire_department_rounded,
    AuraTier.mythic => Icons.bolt_rounded,
  };
}

/// How long an aura can be bought for. Only [offered] are sold now (the
/// server still reports a 3-day price).
enum AuraLength {
  days3,
  week,
  month;

  static const offered = [week, month];
}

extension AuraLengthInfo on AuraLength {
  int get days => switch (this) {
    AuraLength.days3 => 3,
    AuraLength.week => 7,
    AuraLength.month => 30,
  };

  String get label => switch (this) {
    AuraLength.days3 => strings.aura3Days,
    AuraLength.week => strings.aura1Week,
    AuraLength.month => strings.aura1Month,
  };
}

/// An animated frame around a player's picture. Prices come from the
/// server's aura_catalog; the ones here are only shown until it loads.
class Aura {
  const Aura({
    required this.id,
    required this.name,
    required this.tagline,
    required this.tier,
    required this.color,
    required this.prices,
    this.retired = false,
    this.includedWith,
    this.season,
    this.birthday = false,
  });

  final String id;
  final String name;
  final String tagline;
  final AuraTier tier;

  /// The aura's signature color, for cards and glows.
  final Color color;
  final Map<AuraLength, int> prices;

  /// No longer sold. Anyone renting it keeps it until their time runs out
  /// (the server refuses new purchases too).
  final bool retired;

  /// Never sold on its own: it comes with this plan ("Chip Maestro"), worn
  /// while the plan lasts.
  final String? includedWith;

  /// An event frame's season ('halloween'): earned by playing in its event,
  /// and only worn while it's on. Never sold.
  final String? season;

  /// The Birthday frame: only ever given on the player's birthday.
  final bool birthday;

  /// Not for sale (retired, part of a plan, an event's or the birthday's):
  /// shown only to whoever has it.
  bool get notSold =>
      retired || includedWith != null || season != null || birthday;

  int priceFor(AuraLength length) => prices[length]!;

  static const _common = {
    AuraLength.days3: 3000,
    AuraLength.week: 9000,
    AuraLength.month: 35000,
  };
  static const _rare = {
    AuraLength.days3: 4000,
    AuraLength.week: 12000,
    AuraLength.month: 45000,
  };
  static const _legendary = {
    AuraLength.days3: 5000,
    AuraLength.week: 15000,
    AuraLength.month: 60000,
  };
  static const _mythic = {
    AuraLength.days3: 8000,
    AuraLength.week: 24000,
    AuraLength.month: 90000,
  };

  static final all = [
    maestro,
    birthdayFrame,
    Aura(
      id: 'dragon',
      name: strings.auraDragonCoil,
      tagline: strings.auraADragonWoundRoundYour,
      tier: AuraTier.mythic,
      color: Color(0xFFFF4A1F),
      prices: _mythic,
    ),
    Aura(
      id: 'fury',
      name: strings.auraCrimsonFury,
      tagline: strings.auraRedLightningARoaringFire,
      tier: AuraTier.mythic,
      color: Color(0xFFFF1F3D),
      prices: _mythic,
    ),
    Aura(
      id: 'supernova',
      name: strings.auraSupernova,
      tagline: strings.auraAStarExplodingAroundYou,
      tier: AuraTier.mythic,
      color: Color(0xFFFFD24D),
      prices: _mythic,
    ),
    Aura(
      id: 'blackhole',
      name: strings.auraEventHorizon,
      tagline: strings.auraABlackHoleWithA,
      tier: AuraTier.mythic,
      color: Color(0xFFFF8A3D),
      prices: _mythic,
    ),
    Aura(
      id: 'frostfire',
      name: strings.auraFrostfire,
      tagline: strings.auraIceAndFireChasingEach,
      tier: AuraTier.mythic,
      color: Color(0xFF5AB8FF),
      prices: _mythic,
    ),
    Aura(
      id: 'flame',
      name: strings.auraRingOfFire,
      tagline: strings.auraABlazingRingOfFire,
      tier: AuraTier.legendary,
      color: Color(0xFFFF7A2E),
      prices: _legendary,
    ),
    Aura(
      id: 'zombie',
      name: strings.auraZombieBite,
      tagline: strings.auraRottingHandsClawUpTo,
      tier: AuraTier.legendary,
      color: Color(0xFF7DFF3D),
      prices: _legendary,
    ),
    Aura(
      id: 'music',
      name: strings.auraEncore,
      tagline: strings.auraYourPictureOnASpinning,
      tier: AuraTier.legendary,
      color: Color(0xFFFF2E9A),
      prices: _legendary,
    ),
    Aura(
      id: 'jack',
      name: strings.auraJackSLantern,
      tagline: strings.auraBlackBramblesRoundYourPicture,
      tier: AuraTier.legendary,
      color: Color(0xFFF2761A),
      prices: _legendary,
      season: 'halloween',
    ),
    Aura(
      id: 'snow_globe',
      name: strings.auraSnowGlobe,
      tagline: strings.auraYourPictureSealedInA,
      tier: AuraTier.legendary,
      color: Color(0xFF9FD8FF),
      prices: _legendary,
      season: 'winter',
    ),
    Aura(
      id: 'demon',
      name: strings.auraInferno,
      tagline: strings.auraAFrameOfLavaRunning,
      tier: AuraTier.legendary,
      color: Color(0xFFFF4A1F),
      prices: _legendary,
    ),
    Aura(
      id: 'phoenix',
      name: strings.auraPhoenix,
      tagline: strings.auraWingsOfFlameThatBeat,
      tier: AuraTier.legendary,
      color: Color(0xFFFF9A2E),
      prices: _legendary,
      retired: true,
    ),
    Aura(
      id: 'galaxy',
      name: strings.auraGalaxy,
      tagline: strings.auraASpiralOfStarsTurning,
      tier: AuraTier.legendary,
      color: Color(0xFF8A5CFF),
      prices: _legendary,
    ),
    Aura(
      id: 'shadow',
      name: strings.auraShadowFlame,
      tagline: strings.auraDarkFireWithAGlowing,
      tier: AuraTier.legendary,
      color: Color(0xFF9DFF4D),
      prices: _legendary,
      retired: true,
    ),
    Aura(
      id: 'storm',
      name: strings.auraVioletStorm,
      tagline: strings.auraPurpleLightningCracklingAllAround,
      tier: AuraTier.legendary,
      color: Color(0xFFB27BFF),
      prices: _legendary,
    ),
    Aura(
      id: 'storm_white',
      name: strings.auraWhiteStorm,
      tagline: strings.auraWhiteLightningCracklingAllAround,
      tier: AuraTier.legendary,
      color: Color(0xFFE6F0FF),
      prices: _legendary,
    ),
    Aura(
      id: 'storm_blue',
      name: strings.auraBlueStorm,
      tagline: strings.auraElectricBlueBoltsNeverStill,
      tier: AuraTier.legendary,
      color: Color(0xFF4DA3FF),
      prices: _legendary,
    ),
    Aura(
      id: 'storm_green',
      name: strings.auraEmeraldStorm,
      tagline: strings.auraGreenLightningWithAWild,
      tier: AuraTier.legendary,
      color: Color(0xFF3DDC97),
      prices: _legendary,
    ),
    Aura(
      id: 'storm_gold',
      name: strings.auraGoldenStorm,
      tagline: strings.auraGoldBoltsLikeACrown,
      tier: AuraTier.legendary,
      color: Color(0xFFFFC94D),
      prices: _legendary,
    ),
    Aura(
      id: 'storm_pink',
      name: strings.auraPinkStorm,
      tagline: strings.auraHotPinkLightningThatNever,
      tier: AuraTier.legendary,
      color: Color(0xFFFF6FB8),
      prices: _legendary,
    ),
    Aura(
      id: 'sunburst',
      name: strings.auraSunburst,
      tagline: strings.auraGoldenRaysTurningSlowlyLike,
      tier: AuraTier.rare,
      color: Color(0xFFFFC94D),
      prices: _rare,
    ),
    Aura(
      id: 'prism',
      name: strings.auraPrism,
      tagline: strings.auraARainbowRingThatNever,
      tier: AuraTier.rare,
      color: Color(0xFFFF5C9C),
      prices: _rare,
    ),
    Aura(
      id: 'cosmic',
      name: strings.auraOrbit,
      tagline: strings.auraLittlePlanetsCirclingYourPicture,
      tier: AuraTier.rare,
      color: Color(0xFF7C6BFF),
      prices: _rare,
    ),
    Aura(
      id: 'neon',
      name: strings.auraNeonPulse,
      tagline: strings.auraTwoNeonRingsRacingOpposite,
      tier: AuraTier.rare,
      color: Color(0xFFFF3DF2),
      prices: _rare,
    ),
    Aura(
      id: 'tidal',
      name: strings.auraTidal,
      tagline: strings.auraWavesRollingAroundYouSplashing,
      tier: AuraTier.rare,
      color: Color(0xFF3FD8FF),
      prices: _rare,
    ),
    Aura(
      id: 'halo',
      name: strings.auraAngelHalo,
      tagline: strings.auraAGoldenHaloAndFeathers,
      tier: AuraTier.rare,
      color: Color(0xFFFFE9A3),
      prices: _rare,
    ),
    Aura(
      id: 'bubbles',
      name: strings.auraBubbleRing,
      tagline: strings.auraSoapBubblesDriftingUpAnd,
      tier: AuraTier.common,
      color: Color(0xFF7FE3FF),
      prices: _common,
    ),
    Aura(
      id: 'sakura',
      name: strings.auraSakura,
      tagline: strings.auraCherryPetalsDancingInA,
      tier: AuraTier.common,
      color: Color(0xFFFF8FC4),
      prices: _common,
    ),
    Aura(
      id: 'frost',
      name: strings.auraFrost,
      tagline: strings.auraIceCrystalsAndACool,
      tier: AuraTier.common,
      color: Color(0xFF9ED8F5),
      prices: _common,
    ),
    Aura(
      id: 'hearts',
      name: strings.auraLovestruck,
      tagline: strings.auraHeartsCirclingYouBeatingAs,
      tier: AuraTier.common,
      color: Color(0xFFFF6FA8),
      prices: _common,
    ),
    Aura(
      id: 'fireflies',
      name: strings.auraFireflies,
      tagline: strings.auraLittleLightsWanderingAroundYou,
      tier: AuraTier.common,
      color: Color(0xFFD8FF6A),
      prices: _common,
    ),
    Aura(
      id: 'starlight',
      name: strings.auraStarlight,
      tagline: strings.auraStarsTwinklingAllAroundYour,
      tier: AuraTier.common,
      color: Color(0xFFFFE7A3),
      prices: _common,
    ),
    Aura(
      id: 'autumn',
      name: strings.auraAutumnLeaves,
      tagline: strings.auraGoldenLeavesSwirlingOnThe,
      tier: AuraTier.common,
      color: Color(0xFFFF9A3D),
      prices: _common,
    ),
  ];

  /// Chip Maestro's frame.
  static final maestro = Aura(
    id: 'maestro',
    name: strings.auraMaestro,
    tagline: strings.auraARingOfWetPaint,
    tier: AuraTier.legendary,
    color: Color(0xFFFF5C9C),
    prices: _legendary,
    includedWith: strings.auraChipMaestro,
  );

  /// The Birthday frame: worn all day on the player's birthday.
  static final birthdayFrame = Aura(
    id: 'birthday',
    name: strings.auraBirthdayParty,
    tagline: strings.auraARibbonInEveryColor,
    tier: AuraTier.legendary,
    color: Color(0xFFFF6FAE),
    prices: _legendary,
    birthday: true,
  );

  static Aura? byId(String? id) =>
      id == null ? null : all.where((a) => a.id == id).firstOrNull;
}

/// The aura a profile is wearing right now, if any (null once it runs out).
String? activeAura(Map<String, dynamic>? profile) {
  final id = profile?['equipped_aura'] as String?;
  final until = DateTime.tryParse(profile?['aura_expires_at'] as String? ?? '');
  if (id == null || until == null || until.isBefore(DateTime.now())) {
    return null;
  }
  return id;
}

/// 2d 14h, 5h 20m, 12m.
String auraTimeLeft(DateTime until) {
  final d = until.difference(DateTime.now());
  if (d.isNegative) return strings.auraExpired;
  if (d.inDays >= 1) return strings.auraDHLeft(d.inDays, d.inHours % 24);
  if (d.inHours >= 1) return strings.auraHMLeft(d.inHours, d.inMinutes % 60);
  return strings.auraMLeft(d.inMinutes.clamp(1, 59));
}
