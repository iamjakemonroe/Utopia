import 'package:flutter/material.dart';

/// Cheapest to wildest. Mythic sits above legendary.
enum AuraTier { common, rare, legendary, mythic }

extension AuraTierInfo on AuraTier {
  String get title => switch (this) {
    AuraTier.common => 'Common',
    AuraTier.rare => 'Rare',
    AuraTier.legendary => 'Legendary',
    AuraTier.mythic => 'Mythic',
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
    AuraLength.days3 => '3 days',
    AuraLength.week => '1 week',
    AuraLength.month => '1 month',
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

  static const all = [
    maestro,
    birthdayFrame,
    Aura(
      id: 'dragon',
      name: 'Dragon Coil',
      tagline:
          'A dragon wound round your picture, breathing fire. In the Dojo world, it flies free and Chip squares up to it.',
      tier: AuraTier.mythic,
      color: Color(0xFFFF4A1F),
      prices: _mythic,
    ),
    Aura(
      id: 'fury',
      name: 'Crimson Fury',
      tagline:
          'Red lightning, a roaring fire vortex and shockwaves. Pure fury.',
      tier: AuraTier.mythic,
      color: Color(0xFFFF1F3D),
      prices: _mythic,
    ),
    Aura(
      id: 'supernova',
      name: 'Supernova',
      tagline: 'A star exploding around you, over and over.',
      tier: AuraTier.mythic,
      color: Color(0xFFFFD24D),
      prices: _mythic,
    ),
    Aura(
      id: 'blackhole',
      name: 'Event Horizon',
      tagline: 'A black hole with a blazing disk, pulling the light in.',
      tier: AuraTier.mythic,
      color: Color(0xFFFF8A3D),
      prices: _mythic,
    ),
    Aura(
      id: 'frostfire',
      name: 'Frostfire',
      tagline: 'Ice and fire chasing each other round. Sparks where they meet.',
      tier: AuraTier.mythic,
      color: Color(0xFF5AB8FF),
      prices: _mythic,
    ),
    Aura(
      id: 'flame',
      name: 'Ring of Fire',
      tagline: 'A blazing ring of fire, spinning all around you.',
      tier: AuraTier.legendary,
      color: Color(0xFFFF7A2E),
      prices: _legendary,
    ),
    Aura(
      id: 'zombie',
      name: 'Zombie Bite',
      tagline:
          'Rotting hands claw up to grab you. Something took a bite. In the Zombie world, Chip gets bitten too.',
      tier: AuraTier.legendary,
      color: Color(0xFF7DFF3D),
      prices: _legendary,
    ),
    Aura(
      id: 'music',
      name: 'Encore',
      tagline:
          'Your picture on a spinning record, an equalizer jumping all around it on the beat. In the Music world, Chip takes the decks.',
      tier: AuraTier.legendary,
      color: Color(0xFFFF2E9A),
      prices: _legendary,
    ),
    Aura(
      id: 'jack',
      name: "Jack's Lantern",
      tagline:
          'Black brambles round your picture, grinning jack-o\'-lanterns on the rim, a spider on its web and bats circling. In the Halloween world, Chip gets carved.',
      tier: AuraTier.legendary,
      color: Color(0xFFF2761A),
      prices: _legendary,
      season: 'halloween',
    ),
    Aura(
      id: 'snow_globe',
      name: 'Snow Globe',
      tagline:
          'Your picture sealed in a snow globe on a polished stand, the snow swirling up round you every time it\'s shaken. In the Winter world, Chip wraps up warm.',
      tier: AuraTier.legendary,
      color: Color(0xFF9FD8FF),
      prices: _legendary,
      season: 'winter',
    ),
    Aura(
      id: 'demon',
      name: 'Inferno',
      tagline:
          'A frame of lava running down both sides, flames trying to catch, obsidian horns and tail. In the Hell world, Chip grows horns.',
      tier: AuraTier.legendary,
      color: Color(0xFFFF4A1F),
      prices: _legendary,
    ),
    Aura(
      id: 'phoenix',
      name: 'Phoenix',
      tagline: 'Wings of flame that beat behind you.',
      tier: AuraTier.legendary,
      color: Color(0xFFFF9A2E),
      prices: _legendary,
      retired: true,
    ),
    Aura(
      id: 'galaxy',
      name: 'Galaxy',
      tagline: 'A spiral of stars turning around you.',
      tier: AuraTier.legendary,
      color: Color(0xFF8A5CFF),
      prices: _legendary,
    ),
    Aura(
      id: 'shadow',
      name: 'Shadow Flame',
      tagline: 'Dark fire with a glowing green heart.',
      tier: AuraTier.legendary,
      color: Color(0xFF9DFF4D),
      prices: _legendary,
      retired: true,
    ),
    Aura(
      id: 'storm',
      name: 'Violet Storm',
      tagline: 'Purple lightning crackling all around you.',
      tier: AuraTier.legendary,
      color: Color(0xFFB27BFF),
      prices: _legendary,
    ),
    Aura(
      id: 'storm_white',
      name: 'White Storm',
      tagline: 'White lightning crackling all around you.',
      tier: AuraTier.legendary,
      color: Color(0xFFE6F0FF),
      prices: _legendary,
    ),
    Aura(
      id: 'storm_blue',
      name: 'Blue Storm',
      tagline: 'Electric blue bolts, never still.',
      tier: AuraTier.legendary,
      color: Color(0xFF4DA3FF),
      prices: _legendary,
    ),
    Aura(
      id: 'storm_green',
      name: 'Emerald Storm',
      tagline: 'Green lightning with a wild streak.',
      tier: AuraTier.legendary,
      color: Color(0xFF3DDC97),
      prices: _legendary,
    ),
    Aura(
      id: 'storm_gold',
      name: 'Golden Storm',
      tagline: 'Gold bolts, like a crown of thunder.',
      tier: AuraTier.legendary,
      color: Color(0xFFFFC94D),
      prices: _legendary,
    ),
    Aura(
      id: 'storm_pink',
      name: 'Pink Storm',
      tagline: 'Hot pink lightning that never calms down.',
      tier: AuraTier.legendary,
      color: Color(0xFFFF6FB8),
      prices: _legendary,
    ),
    Aura(
      id: 'sunburst',
      name: 'Sunburst',
      tagline: 'Golden rays turning slowly, like a sunrise.',
      tier: AuraTier.rare,
      color: Color(0xFFFFC94D),
      prices: _rare,
    ),
    Aura(
      id: 'prism',
      name: 'Prism',
      tagline: 'A rainbow ring that never stops turning.',
      tier: AuraTier.rare,
      color: Color(0xFFFF5C9C),
      prices: _rare,
    ),
    Aura(
      id: 'cosmic',
      name: 'Orbit',
      tagline: 'Little planets circling your picture.',
      tier: AuraTier.rare,
      color: Color(0xFF7C6BFF),
      prices: _rare,
    ),
    Aura(
      id: 'neon',
      name: 'Neon Pulse',
      tagline: 'Two neon rings racing opposite ways.',
      tier: AuraTier.rare,
      color: Color(0xFFFF3DF2),
      prices: _rare,
    ),
    Aura(
      id: 'tidal',
      name: 'Tidal',
      tagline: 'Waves rolling around you, splashing as they go.',
      tier: AuraTier.rare,
      color: Color(0xFF3FD8FF),
      prices: _rare,
    ),
    Aura(
      id: 'halo',
      name: 'Angel Halo',
      tagline:
          'A golden halo and feathers drifting down. In the Heaven world, Chip gets his wings.',
      tier: AuraTier.rare,
      color: Color(0xFFFFE9A3),
      prices: _rare,
    ),
    Aura(
      id: 'bubbles',
      name: 'Bubble Ring',
      tagline: 'Soap bubbles drifting up and away.',
      tier: AuraTier.common,
      color: Color(0xFF7FE3FF),
      prices: _common,
    ),
    Aura(
      id: 'sakura',
      name: 'Sakura',
      tagline: 'Cherry petals dancing in a circle.',
      tier: AuraTier.common,
      color: Color(0xFFFF8FC4),
      prices: _common,
    ),
    Aura(
      id: 'frost',
      name: 'Frost',
      tagline: 'Ice crystals and a cool blue shimmer.',
      tier: AuraTier.common,
      color: Color(0xFF9ED8F5),
      prices: _common,
    ),
    Aura(
      id: 'hearts',
      name: 'Lovestruck',
      tagline: 'Hearts circling you, beating as they go.',
      tier: AuraTier.common,
      color: Color(0xFFFF6FA8),
      prices: _common,
    ),
    Aura(
      id: 'fireflies',
      name: 'Fireflies',
      tagline: 'Little lights wandering around you at dusk.',
      tier: AuraTier.common,
      color: Color(0xFFD8FF6A),
      prices: _common,
    ),
    Aura(
      id: 'starlight',
      name: 'Starlight',
      tagline: 'Stars twinkling all around your picture.',
      tier: AuraTier.common,
      color: Color(0xFFFFE7A3),
      prices: _common,
    ),
    Aura(
      id: 'autumn',
      name: 'Autumn Leaves',
      tagline: 'Golden leaves swirling on the wind.',
      tier: AuraTier.common,
      color: Color(0xFFFF9A3D),
      prices: _common,
    ),
  ];

  /// Chip Maestro's frame.
  static const maestro = Aura(
    id: 'maestro',
    name: 'Maestro',
    tagline: 'A ring of wet paint, with a brush painting around you.',
    tier: AuraTier.legendary,
    color: Color(0xFFFF5C9C),
    prices: _legendary,
    includedWith: 'Chip Maestro',
  );

  /// The Birthday frame: worn all day on the player's birthday.
  static const birthdayFrame = Aura(
    id: 'birthday',
    name: 'Birthday Party',
    tagline:
        'A ribbon in every color, a party hat, balloons and a little cake. Only on your birthday.',
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
  if (d.isNegative) return 'Expired';
  if (d.inDays >= 1) return '${d.inDays}d ${d.inHours % 24}h left';
  if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m left';
  return '${d.inMinutes.clamp(1, 59)}m left';
}
