import 'package:flutter/material.dart';

import '../../../l10n/strings.dart';
import '../../chess/domain/chess_bot.dart' show BotLevel;
import '../domain/pool_cues.dart';

/// What the pool tables, cues and tiers are called, in the player's
/// language.

String poolTableName(String id) => switch (id) {
  'lagoon' => strings.poolTableLagoon,
  'dunes' => strings.poolTableDunes,
  'neon' => strings.poolTableNeon,
  'summit' => strings.poolTableSummit,
  _ => strings.poolEightBall,
};

/// The colours a table's card is painted in (its felt, and its glow).
(Color, Color) poolTableColors(String id) => switch (id) {
  'lagoon' => (const Color(0xFF137A6B), const Color(0xFF39E6C4)),
  'dunes' => (const Color(0xFF8C5A1E), const Color(0xFFFFB443)),
  'neon' => (const Color(0xFF3D1A7A), const Color(0xFFFF4FD8)),
  'summit' => (const Color(0xFF1B3554), const Color(0xFF9FD8FF)),
  _ => (const Color(0xFF1F6B57), const Color(0xFF2FD98E)),
};

/// Chip's level at [table] (the summit's Chip, with its best cue, is a
/// cut above even the deadly one).
String poolChipAt(String table, BotLevel level) =>
    table == 'summit' ? strings.poolChipMaster : poolBotLevelName(level);

String poolBotLevelName(BotLevel level) => switch (level) {
  BotLevel.easy => strings.poolChipEasy,
  BotLevel.normal => strings.poolChipNormal,
  BotLevel.hard => strings.poolChipHard,
};

String cueTierName(CueTier tier) => switch (tier) {
  CueTier.regular => strings.poolTierRegular,
  CueTier.rare => strings.poolTierRare,
  CueTier.epic => strings.poolTierEpic,
  CueTier.legendary => strings.poolTierLegendary,
  CueTier.mythic => strings.poolTierMythic,
};

/// A tier's colour, for its badge and its cards' glow.
Color cueTierColor(CueTier tier) => switch (tier) {
  CueTier.regular => const Color(0xFFB8C2D6),
  CueTier.rare => const Color(0xFF4DA3FF),
  CueTier.epic => const Color(0xFFB45CFF),
  CueTier.legendary => const Color(0xFFFFB020),
  CueTier.mythic => const Color(0xFFFF4F7B),
};

String cueName(PoolCue cue) => switch (cue.look) {
  CueLook.classic => strings.poolCueClassic,
  CueLook.oak => strings.poolCueOak,
  CueLook.carbon => strings.poolCueCarbon,
  CueLook.ivory => strings.poolCueIvory,
  CueLook.neon => strings.poolCueNeon,
  CueLook.frost => strings.poolCueFrost,
  CueLook.inferno => strings.poolCueInferno,
  CueLook.thunder => strings.poolCueThunder,
  CueLook.galaxy => strings.poolCueGalaxy,
  CueLook.phoenix => strings.poolCuePhoenix,
  CueLook.prism => strings.poolCuePrism,
  CueLook.dragon => strings.poolCueDragon,
};

String cueTagline(PoolCue cue) => switch (cue.look) {
  CueLook.classic => strings.poolCueClassicLine,
  CueLook.oak => strings.poolCueOakLine,
  CueLook.carbon => strings.poolCueCarbonLine,
  CueLook.ivory => strings.poolCueIvoryLine,
  CueLook.neon => strings.poolCueNeonLine,
  CueLook.frost => strings.poolCueFrostLine,
  CueLook.inferno => strings.poolCueInfernoLine,
  CueLook.thunder => strings.poolCueThunderLine,
  CueLook.galaxy => strings.poolCueGalaxyLine,
  CueLook.phoenix => strings.poolCuePhoenixLine,
  CueLook.prism => strings.poolCuePrismLine,
  CueLook.dragon => strings.poolCueDragonLine,
};
