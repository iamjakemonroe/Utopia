import 'dart:ui';

/// Guess My Doodle's page: square, so the drawing fits a phone held upright
/// with room for the chat under it.
const kDoodleGameSize = Size(1000, 1000);

/// Where a game is: waiting for players, someone picking a word, drawing,
/// showing the word, the final scores, or ended for good.
enum DoodlePhase {
  lobby,
  choosing,
  drawing,
  reveal,
  over,
  closed;

  static DoodlePhase parse(String? s) =>
      values.where((p) => p.name == s).firstOrNull ?? closed;
}

/// A game as the server has it (doodle_games). The word itself is never in
/// here: guessers get [wordMask], the drawer asks for the word.
class DoodleGame {
  const DoodleGame({
    required this.id,
    required this.code,
    required this.isPublic,
    required this.hostId,
    required this.phase,
    required this.rounds,
    required this.drawSeconds,
    required this.maxPlayers,
    required this.round,
    required this.turn,
    required this.drawerId,
    required this.phaseEndsAt,
    required this.wordMask,
    required this.revealedWord,
    required this.canvasEpoch,
    required this.canvasRev,
    required this.winnerIds,
  });

  final String id;
  final String code;
  final bool isPublic;
  final String hostId;
  final DoodlePhase phase;
  final int rounds;
  final int drawSeconds;
  final int maxPlayers;
  final int round;

  /// Counts up for the life of the game: names one turn.
  final int turn;
  final String? drawerId;

  /// When the current phase ends (server time).
  final DateTime? phaseEndsAt;

  /// The word with unguessed letters as '_' (spaces and hyphens shown).
  final String? wordMask;
  final String? revealedWord;
  final int canvasEpoch;
  final int canvasRev;
  final List<String> winnerIds;

  bool get playing =>
      phase == DoodlePhase.choosing ||
      phase == DoodlePhase.drawing ||
      phase == DoodlePhase.reveal;

  factory DoodleGame.fromRow(Map<String, dynamic> row) => DoodleGame(
    id: row['id'] as String,
    code: row['code'] as String,
    isPublic: row['is_public'] as bool? ?? false,
    hostId: row['host_id'] as String,
    phase: DoodlePhase.parse(row['status'] as String?),
    rounds: (row['rounds'] as num?)?.toInt() ?? 3,
    drawSeconds: (row['draw_seconds'] as num?)?.toInt() ?? 80,
    maxPlayers: (row['max_players'] as num?)?.toInt() ?? 20,
    round: (row['round'] as num?)?.toInt() ?? 0,
    turn: (row['turn'] as num?)?.toInt() ?? 0,
    drawerId: row['drawer_id'] as String?,
    phaseEndsAt: DateTime.tryParse(row['phase_ends_at'] as String? ?? ''),
    wordMask: row['word_mask'] as String?,
    revealedWord: row['revealed_word'] as String?,
    canvasEpoch: (row['canvas_epoch'] as num?)?.toInt() ?? 0,
    canvasRev: (row['canvas_rev'] as num?)?.toInt() ?? 0,
    winnerIds: [
      for (final id in (row['winner_ids'] as List?) ?? const []) id as String,
    ],
  );
}

class DoodlePlayer {
  const DoodlePlayer({
    required this.userId,
    required this.score,
    required this.turnPoints,
    required this.guessedTurn,
    required this.joinSeq,
    required this.left,
  });

  final String userId;
  final int score;

  /// Points from the latest turn.
  final int turnPoints;

  /// The turn they last guessed right in.
  final int guessedTurn;
  final int joinSeq;
  final bool left;

  factory DoodlePlayer.fromRow(Map<String, dynamic> row) => DoodlePlayer(
    userId: row['user_id'] as String,
    score: (row['score'] as num?)?.toInt() ?? 0,
    turnPoints: (row['turn_points'] as num?)?.toInt() ?? 0,
    guessedTurn: (row['guessed_turn'] as num?)?.toInt() ?? 0,
    joinSeq: (row['join_seq'] as num?)?.toInt() ?? 0,
    left: row['left_at'] != null,
  );
}

/// What a chat line is.
enum DoodleMessageKind {
  /// Typed by a player: a wrong guess, or chat.
  chat,

  /// Someone guessed the word (the word itself is never sent).
  guessed,

  /// The sender's own guess was nearly right (only they see it).
  close,

  /// The word, once the turn is over.
  reveal,
  joined,
  left,

  /// Someone started drawing.
  drawing;

  static DoodleMessageKind? parse(String? s) =>
      values.where((k) => k.name == s).firstOrNull;
}

class DoodleMessage {
  const DoodleMessage({
    required this.id,
    required this.senderId,
    required this.turn,
    required this.kind,
    required this.body,
    required this.guessedOnly,
  });

  final int id;
  final String? senderId;
  final int turn;
  final DoodleMessageKind kind;
  final String body;

  /// Only the drawer and players who've guessed can see it.
  final bool guessedOnly;

  static DoodleMessage? fromRow(Map<String, dynamic> row) {
    final kind = DoodleMessageKind.parse(row['kind'] as String?);
    if (kind == null) return null;
    return DoodleMessage(
      id: (row['id'] as num).toInt(),
      senderId: row['sender_id'] as String?,
      turn: (row['turn'] as num?)?.toInt() ?? 0,
      kind: kind,
      body: row['body'] as String? ?? '',
      guessedOnly: row['audience'] == 'guessed',
    );
  }
}

/// What the server made of a line typed into the chat.
enum GuessResult { correct, close, chat }

/// The blanks to show for a word mask: each word's letters (null for a
/// hidden one), so "ice cream" with a hint is [[null,'c',null],[...]].
List<List<String?>> maskWords(String mask) => [
  for (final word in mask.split(' '))
    if (word.isNotEmpty)
      [for (final ch in word.split('')) ch == '_' ? null : ch],
];
