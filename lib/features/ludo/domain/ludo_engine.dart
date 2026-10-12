import 'dart:math';

/// Token colors. The classic board seats red, green, yellow, blue; the
/// six-arm board adds orange and purple (see [LudoBoardRules]).
enum LudoColor { red, green, yellow, blue, orange, purple }

enum LudoBoardKind { classic, hex }

/// A single token's progress along its color's private path:
/// -1 = still in base, 0..[LudoBoardRules.ringLast] = steps on the shared
/// outer ring (see [LudoBoardRules.absoluteSquare]), then the five squares
/// of the color's private home stretch, and [LudoBoardRules.finish] = home
/// (so from the first stretch square it takes five more to get home).
typedef TokenPositions = List<int>;

const int kLudoBase = -1;
const int kLudoTokensPerColor = 4;

// Classic-board constants, kept for readability in tests and callers that
// only ever deal with the 4-seat board.
const int kLudoRingLength = 51;
const int kLudoPathLength = 56;
const Map<LudoColor, int> kLudoStartSquare = {
  LudoColor.red: 0,
  LudoColor.green: 13,
  LudoColor.yellow: 26,
  LudoColor.blue: 39,
};
const Set<int> kLudoSafeSquares = {0, 8, 13, 21, 26, 34, 39, 47};

/// The geometry-free rules of a board: which seats it has, how long its
/// ring is, and where each seat enters it. Every arm contributes 13 ring
/// squares, so a 4-seat board has a 52-square ring and a 6-seat one 78.
class LudoBoardRules {
  const LudoBoardRules._(this.kind, this.seats);

  static const classic = LudoBoardRules._(LudoBoardKind.classic, [
    LudoColor.red,
    LudoColor.green,
    LudoColor.yellow,
    LudoColor.blue,
  ]);

  static const hex = LudoBoardRules._(LudoBoardKind.hex, [
    LudoColor.red,
    LudoColor.orange,
    LudoColor.yellow,
    LudoColor.green,
    LudoColor.blue,
    LudoColor.purple,
  ]);

  static LudoBoardRules of(LudoBoardKind kind) =>
      kind == LudoBoardKind.hex ? hex : classic;

  final LudoBoardKind kind;

  /// Every seat on the board in clockwise order (whether or not occupied).
  final List<LudoColor> seats;

  int get ringSize => 13 * seats.length;

  /// The last ring step a token takes before turning into its home stretch.
  int get ringLast => ringSize - 2;

  /// The position of a token that has reached home: one step past the
  /// fifth home-stretch square.
  int get finish => ringSize + 4;

  /// Whether a token at [position] is home. (Games saved before the
  /// stretch was shortened can hold one step past [finish].)
  bool isHome(int position) => position >= finish;

  int seatOf(LudoColor color) => seats.indexOf(color);

  int startSquare(LudoColor color) => seatOf(color) * 13;

  bool isOnRing(int position) => position >= 0 && position <= ringLast;

  int absoluteSquare(LudoColor color, int relative) {
    assert(isOnRing(relative));
    return (startSquare(color) + relative) % ringSize;
  }

  /// Squares no token can be captured on: every seat's start square plus a
  /// star square 8 steps after it.
  Set<int> get safeSquares => {
    for (var s = 0; s < seats.length; s++) ...{s * 13, s * 13 + 8},
  };
}

/// One die roll, kept in the shared state so every player sees it land.
class LudoRoll {
  const LudoRoll(this.color, this.value);

  final LudoColor color;
  final int value;

  Map<String, dynamic> toJson() => {'color': color.name, 'value': value};

  @override
  bool operator ==(Object other) =>
      other is LudoRoll && other.color == color && other.value == value;

  @override
  int get hashCode => Object.hash(color, value);
}

/// The most recent capture: who captured (and with which token) and whose
/// tokens were sent home. [seq] increases with every capture so clients
/// can tell a new one from one they've already shown.
class LudoCapture {
  const LudoCapture({
    required this.seq,
    required this.by,
    required this.token,
    required this.victims,
  });

  final int seq;
  final LudoColor by;
  final int token;
  final List<(LudoColor, int)> victims;

  Map<String, dynamic> toJson() => {
    'seq': seq,
    'by': by.name,
    'token': token,
    'victims': [
      for (final (color, token) in victims)
        {'color': color.name, 'token': token},
    ],
  };

  static LudoCapture? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return LudoCapture(
      seq: (json['seq'] as num).toInt(),
      by: LudoState._colorByName(json['by'] as String),
      token: (json['token'] as num).toInt(),
      victims: [
        for (final v in (json['victims'] as List? ?? const []))
          (
            LudoState._colorByName((v as Map)['color'] as String),
            (v['token'] as num).toInt(),
          ),
      ],
    );
  }
}

class LudoState {
  const LudoState({
    required this.players,
    required this.tokens,
    required this.turn,
    this.board = LudoBoardKind.classic,
    this.diceValue,
    this.hasRolled = false,
    this.consecutiveSixes = 0,
    this.winner,
    this.left = const [],
    this.rollSeq = 0,
    this.lastRoll,
    this.capture,
  });

  /// Colors in this match, in turn order.
  final List<LudoColor> players;
  final Map<LudoColor, TokenPositions> tokens;
  final LudoColor turn;
  final LudoBoardKind board;
  final int? diceValue;
  final bool hasRolled;
  final int consecutiveSixes;
  final LudoColor? winner;

  /// Players who quit or timed out: skipped, their tokens off the board.
  final List<LudoColor> left;

  /// How many rolls this match has had; changes with every roll.
  final int rollSeq;
  final LudoRoll? lastRoll;
  final LudoCapture? capture;

  LudoBoardRules get rules => LudoBoardRules.of(board);

  List<LudoColor> get activePlayers => [
    for (final c in players)
      if (!left.contains(c)) c,
  ];

  static LudoState initial(List<LudoColor> players, {LudoBoardKind? board}) {
    return LudoState(
      players: players,
      board:
          board ??
          (players.length > 4 ? LudoBoardKind.hex : LudoBoardKind.classic),
      tokens: {
        for (final c in players) c: List.filled(kLudoTokensPerColor, kLudoBase),
      },
      turn: players.first,
    );
  }

  /// The next player in turn order who is still in the game.
  LudoColor nextPlayer() {
    final i = players.indexOf(turn);
    for (var step = 1; step <= players.length; step++) {
      final candidate = players[(i + step) % players.length];
      if (!left.contains(candidate)) return candidate;
    }
    return turn;
  }

  LudoState copyWith({
    Map<LudoColor, TokenPositions>? tokens,
    LudoColor? turn,
    int? diceValue,
    bool clearDiceValue = false,
    bool? hasRolled,
    int? consecutiveSixes,
    LudoColor? winner,
    List<LudoColor>? left,
    int? rollSeq,
    LudoRoll? lastRoll,
    LudoCapture? capture,
  }) {
    return LudoState(
      players: players,
      board: board,
      tokens: tokens ?? this.tokens,
      turn: turn ?? this.turn,
      diceValue: clearDiceValue ? null : (diceValue ?? this.diceValue),
      hasRolled: hasRolled ?? this.hasRolled,
      consecutiveSixes: consecutiveSixes ?? this.consecutiveSixes,
      winner: winner ?? this.winner,
      left: left ?? this.left,
      rollSeq: rollSeq ?? this.rollSeq,
      lastRoll: lastRoll ?? this.lastRoll,
      capture: capture ?? this.capture,
    );
  }

  Map<String, dynamic> toJson() => {
    'board': board.name,
    'players': players.map((c) => c.name).toList(),
    'tokens': tokens.map((c, ps) => MapEntry(c.name, ps)),
    'turn': turn.name,
    'dice_value': diceValue,
    'has_rolled': hasRolled,
    'consecutive_sixes': consecutiveSixes,
    'winner': winner?.name,
    'left': left.map((c) => c.name).toList(),
    'roll_seq': rollSeq,
    'last_roll': lastRoll?.toJson(),
    'capture': capture?.toJson(),
  };

  static LudoColor _colorByName(String name) =>
      LudoColor.values.firstWhere((c) => c.name == name);

  factory LudoState.fromJson(Map<String, dynamic> json) {
    final lastRoll = json['last_roll'];
    return LudoState(
      board: json['board'] == 'hex' ? LudoBoardKind.hex : LudoBoardKind.classic,
      players: (json['players'] as List)
          .map((n) => _colorByName(n as String))
          .toList(),
      tokens: (json['tokens'] as Map<String, dynamic>).map(
        (name, ps) => MapEntry(
          _colorByName(name),
          (ps as List).map((p) => (p as num).toInt()).toList(),
        ),
      ),
      turn: _colorByName(json['turn'] as String),
      diceValue: (json['dice_value'] as num?)?.toInt(),
      hasRolled: json['has_rolled'] as bool? ?? false,
      consecutiveSixes: (json['consecutive_sixes'] as num?)?.toInt() ?? 0,
      winner: json['winner'] == null
          ? null
          : _colorByName(json['winner'] as String),
      left: [
        for (final n in (json['left'] as List? ?? const []))
          _colorByName(n as String),
      ],
      rollSeq: (json['roll_seq'] as num?)?.toInt() ?? 0,
      lastRoll: lastRoll is Map<String, dynamic>
          ? LudoRoll(
              _colorByName(lastRoll['color'] as String),
              (lastRoll['value'] as num).toInt(),
            )
          : null,
      capture: LudoCapture.fromJson(json['capture']),
    );
  }
}

/// Outcome of rolling the die: either the roll stands (movable tokens
/// follow), or three sixes in a row void it and pass the turn immediately.
class LudoRollOutcome {
  const LudoRollOutcome({
    required this.state,
    required this.forfeited,
    required this.movableTokens,
  });

  final LudoState state;
  final bool forfeited;
  final List<int> movableTokens;
}

/// Outcome of moving one token: the resulting state plus enough metadata
/// for the UI to animate/narrate what happened.
class LudoMoveResult {
  const LudoMoveResult({
    required this.state,
    required this.fromPosition,
    required this.toPosition,
    required this.captured,
    required this.reachedHome,
    required this.extraTurn,
    required this.wonGame,
  });

  final LudoState state;
  final int fromPosition;
  final int toPosition;
  final bool captured;
  final bool reachedHome;
  final bool extraTurn;
  final bool wonGame;
}

/// Pure Ludo rules: dice, legal moves, capturing, and win detection. No
/// Flutter/Supabase imports — the same "engine has zero I/O" shape as
/// ChessEngine, so it's trivially unit-testable and can run identically on
/// every client for realtime sync (like chess, this is a sync source of
/// truth, not a server-verified anti-cheat oracle — acceptable while coins
/// are virtual-only; revisit before real money).
class LudoEngine {
  const LudoEngine();

  int rollDie([Random? random]) => (random ?? Random()).nextInt(6) + 1;

  bool isTokenMovable(
    int position,
    int diceValue, {
    LudoBoardRules rules = LudoBoardRules.classic,
  }) {
    if (position == kLudoBase) return diceValue == 6;
    if (rules.isHome(position)) return false;
    return position + diceValue <= rules.finish;
  }

  List<int> legalTokenMoves(LudoState state, int diceValue) {
    final positions = state.tokens[state.turn]!;
    return [
      for (var i = 0; i < positions.length; i++)
        if (isTokenMovable(positions[i], diceValue, rules: state.rules)) i,
    ];
  }

  /// Maps a color's relative ring step to the shared board-wide square.
  int absoluteSquare(
    LudoColor color,
    int relativePosition, {
    LudoBoardRules rules = LudoBoardRules.classic,
  }) => rules.absoluteSquare(color, relativePosition);

  /// Registers a die roll: records it for everyone to see, bumps the
  /// consecutive-sixes counter, and if this is the third six in a row,
  /// voids the roll and passes the turn without letting any token move.
  LudoRollOutcome registerRoll(LudoState state, int diceValue) {
    final streak = diceValue == 6 ? state.consecutiveSixes + 1 : 0;
    final seen = state.copyWith(
      rollSeq: state.rollSeq + 1,
      lastRoll: LudoRoll(state.turn, diceValue),
    );

    if (diceValue == 6 && streak >= 3) {
      final next = seen.copyWith(
        turn: seen.nextPlayer(),
        clearDiceValue: true,
        hasRolled: false,
        consecutiveSixes: 0,
      );
      return LudoRollOutcome(
        state: next,
        forfeited: true,
        movableTokens: const [],
      );
    }

    final rolled = seen.copyWith(
      diceValue: diceValue,
      hasRolled: true,
      consecutiveSixes: streak,
    );
    return LudoRollOutcome(
      state: rolled,
      forfeited: false,
      movableTokens: legalTokenMoves(rolled, diceValue),
    );
  }

  /// No legal move existed for the rolled value — passes the turn.
  LudoState passTurnNoMove(LudoState state) {
    return state.copyWith(
      turn: state.nextPlayer(),
      clearDiceValue: true,
      hasRolled: false,
      consecutiveSixes: 0,
    );
  }

  LudoMoveResult applyMove(LudoState state, int tokenIndex, int diceValue) {
    final rules = state.rules;
    final color = state.turn;
    final positions = Map<LudoColor, TokenPositions>.fromEntries(
      state.tokens.entries.map((e) => MapEntry(e.key, List<int>.from(e.value))),
    );
    final mine = positions[color]!;
    final from = mine[tokenIndex];
    // Leaving base consumes the 6 as permission to enter, not as travel
    // distance — the token lands on its start square (relative 0), it
    // doesn't move 6 steps past it.
    final to = from == kLudoBase ? 0 : from + diceValue;
    mine[tokenIndex] = to;

    final victims = <(LudoColor, int)>[];
    // Capturing only happens on the shared ring, never in a color's private
    // home stretch, and never on a safe square.
    if (rules.isOnRing(to)) {
      final targetSquare = rules.absoluteSquare(color, to);
      if (!rules.safeSquares.contains(targetSquare)) {
        for (final otherColor in state.players) {
          if (otherColor == color || state.left.contains(otherColor)) continue;
          final theirs = positions[otherColor]!;
          for (var i = 0; i < theirs.length; i++) {
            final p = theirs[i];
            if (!rules.isOnRing(p)) continue;
            if (rules.absoluteSquare(otherColor, p) == targetSquare) {
              theirs[i] = kLudoBase;
              victims.add((otherColor, i));
            }
          }
        }
      }
    }
    final captured = victims.isNotEmpty;

    final reachedHome = rules.isHome(to);
    final wonGame = mine.every(rules.isHome);
    final extraTurn = !wonGame && (diceValue == 6 || captured || reachedHome);

    final next = state.copyWith(
      tokens: positions,
      turn: wonGame ? color : (extraTurn ? color : state.nextPlayer()),
      clearDiceValue: true,
      hasRolled: false,
      consecutiveSixes: extraTurn && diceValue == 6
          ? state.consecutiveSixes
          : 0,
      winner: wonGame ? color : null,
      capture: captured
          ? LudoCapture(
              seq: (state.capture?.seq ?? 0) + 1,
              by: color,
              token: tokenIndex,
              victims: victims,
            )
          : null,
    );

    return LudoMoveResult(
      state: next,
      fromPosition: from,
      toPosition: to,
      captured: captured,
      reachedHome: reachedHome,
      extraTurn: extraTurn,
      wonGame: wonGame,
    );
  }
}
