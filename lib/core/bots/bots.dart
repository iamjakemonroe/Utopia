/// Computer players for offline games. A bot plays under an id like
/// `bot:pip`, and [botProfile] gives it a profile shaped like a real
/// player's (name, generated avatar, piece sets), so every screen that
/// shows players works for bots without asking the server.
library;

import '../../l10n/strings.dart';

const kBotPrefix = 'bot:';

bool isBotId(String? id) => id != null && id.startsWith(kBotPrefix);

/// A friend taking turns on this phone in an offline game: `friend:2` is
/// Player 2. Like a bot, it has its profile built in ([friendSeatProfile]).
const kFriendSeatPrefix = 'friend:';

bool isFriendSeatId(String? id) =>
    id != null && id.startsWith(kFriendSeatPrefix);

/// Players with no account behind them: bots and friends on this phone.
bool isOfflinePlayerId(String? id) => isBotId(id) || isFriendSeatId(id);

/// The name a friend's seat goes by ("Player 2").
String friendSeatName(String id) =>
    strings.botsPlayer(id.substring(kFriendSeatPrefix.length));

/// A profile row for a friend's seat, shaped like a real player's.
Map<String, dynamic> friendSeatProfile(String id) {
  final n = int.tryParse(id.substring(kFriendSeatPrefix.length)) ?? 2;
  return {
    'id': id,
    'display_name': friendSeatName(id),
    'username': 'player$n',
    'avatar_url': null,
    'avatar_kind': 'human',
    'avatar_seed': n * 3,
    'equipped_ludo_pieces': 'classic',
    'equipped_chess_pieces': 'classic',
    'equipped_aura': null,
  };
}

class BotPersona {
  const BotPersona({
    required this.key,
    required this.name,
    required this.avatarKind,
    required this.avatarSeed,
    this.ludoPieces = 'classic',
    this.chessPieces = 'classic',
  });

  final String key;
  final String name;
  final String avatarKind;
  final int avatarSeed;
  final String ludoPieces;
  final String chessPieces;

  String get id => '$kBotPrefix$key';
}

/// The Ludo table's computer players, in the order seats fill.
final kLudoBots = [
  BotPersona(
    key: 'pip',
    name: strings.botsPip,
    avatarKind: 'animal',
    avatarSeed: 2,
    ludoPieces: 'bubble',
  ),
  BotPersona(
    key: 'momo',
    name: strings.botsMomo,
    avatarKind: 'plant',
    avatarSeed: 5,
    ludoPieces: 'jelly',
  ),
  BotPersona(
    key: 'kiki',
    name: strings.botsKiki,
    avatarKind: 'human',
    avatarSeed: 3,
    ludoPieces: 'candy',
  ),
  BotPersona(
    key: 'bolt',
    name: strings.botsBolt,
    avatarKind: 'animal',
    avatarSeed: 6,
    ludoPieces: 'crystal',
  ),
  BotPersona(
    key: 'nova',
    name: strings.botsNova,
    avatarKind: 'human',
    avatarSeed: 7,
    ludoPieces: 'cosmic',
  ),
];

/// Chess opponents. Chip plays with the Chess Buddies set (faces and all);
/// the robot with Robo Knights.
final kChessChip = BotPersona(
  key: 'chip',
  name: strings.botsChip,
  avatarKind: 'chip',
  avatarSeed: 0,
  chessPieces: 'chess_buddies',
);

final kChessRobot = BotPersona(
  key: 'robo',
  name: strings.botsRobo,
  avatarKind: 'robot',
  avatarSeed: 0,
  chessPieces: 'chess_robots',
);

BotPersona? botById(String? id) {
  if (!isBotId(id)) return null;
  for (final b in [...kLudoBots, kChessChip, kChessRobot]) {
    if (b.id == id) return b;
  }
  return null;
}

/// A profile row for a bot, shaped like the profiles table's public
/// columns.
Map<String, dynamic>? botProfile(String id) {
  final b = botById(id);
  if (b == null) return null;
  return {
    'id': b.id,
    'display_name': b.name,
    'username': b.key,
    'avatar_url': null,
    'avatar_kind': b.avatarKind,
    'avatar_seed': b.avatarSeed,
    'equipped_ludo_pieces': b.ludoPieces,
    'equipped_chess_pieces': b.chessPieces,
    'equipped_aura': null,
  };
}
