import 'dart:math' as math;
import 'dart:typed_data';

import 'pool_physics.dart';

/// 8-ball's rules, as most people play them online:
///
/// * The break is taken from behind the head string. A ball pocketed on it
///   keeps the turn; the 8 pocketed on it comes back to the foot spot.
/// * The table is open until a player pockets a ball (after the break):
///   that ball's group, solids (1-7) or stripes (9-15), is theirs.
/// * A player keeps shooting while they pocket their own balls without a
///   foul. Once their group's gone, they shoot the 8 into a pocket they
///   call first: that wins.
/// * Fouls: pocketing the cue ball, hitting nothing, hitting the other
///   group (or the 8 too soon) first, and nothing pocketed and no ball
///   touching a cushion after the hit. The other player then gets the cue
///   ball in hand, anywhere.
/// * Pocketing the 8 too soon, in a pocket not called, or with a foul
///   loses.
enum PoolGroup {
  solids,
  stripes;

  bool has(int ball) =>
      this == solids ? ball >= 1 && ball <= 7 : ball >= 9 && ball <= 15;

  PoolGroup get other => this == solids ? stripes : solids;
}

/// Where the cue ball may go, when a player has it in hand.
enum PoolHand {
  /// Not in hand: it's where it stopped.
  none,

  /// Behind the head string (the break).
  kitchen,

  /// Anywhere free (after the other player's foul).
  anywhere,
}

/// Why a shot was a foul.
enum PoolFoul { scratch, noContact, wrongBall, noCushion }

/// How a game was won.
enum PoolWin { eight, eightEarly, eightWrongPocket, eightFoul, resign }

/// A game of 8-ball between two players (0 and 1), at a shot.
class PoolGame {
  const PoolGame({
    required this.balls,
    required this.turn,
    required this.groups,
    required this.hand,
    required this.breakShot,
    this.winner,
    this.win,
    this.shots = 0,
    this.lastFouls = const [],
  });

  /// A new rack, the balls placed by [seed], player [breaker] to break.
  factory PoolGame.rack(int seed, {int breaker = 0}) => PoolGame(
    balls: rackBalls(seed),
    turn: breaker,
    groups: const [null, null],
    hand: PoolHand.kitchen,
    breakShot: true,
  );

  final PoolBalls balls;
  final int turn;

  /// Each player's group, once the table's no longer open.
  final List<PoolGroup?> groups;

  /// Whether, and where, the player to shoot has the cue ball in hand.
  final PoolHand hand;
  final bool breakShot;
  final int? winner;
  final PoolWin? win;
  final int shots;

  /// The last shot's fouls (for what the table says).
  final List<PoolFoul> lastFouls;

  bool get over => winner != null;
  bool get open => groups[0] == null;
  PoolGroup? get myGroup => groups[turn];

  /// Whether [player] has pocketed all their group (and so shoots the 8).
  bool onTheEight(int player) {
    final g = groups[player];
    if (g == null) return false;
    for (var b = 1; b < kBalls; b++) {
      if (g.has(b) && balls.on[b]) return false;
    }
    return true;
  }

  /// The balls the player to shoot may hit first.
  List<int> get targets {
    if (onTheEight(turn)) return const [kEightBall];
    final g = myGroup;
    return [
      for (var b = 1; b < kBalls; b++)
        if (balls.on[b] && b != kEightBall && (g == null || g.has(b))) b,
    ];
  }

  /// Whether a shot now needs a called pocket (it's on the 8).
  bool get callsPocket => !breakShot && onTheEight(turn);

  /// Whether the cue ball may be placed at ([x], [y]) while in hand.
  bool canPlace(double x, double y) {
    if (hand == PoolHand.none) return false;
    if (hand == PoolHand.kitchen && x > kHeadString) return false;
    return balls.isFree(x, y, except: kCueBall);
  }

  PoolGame copyWith({
    PoolBalls? balls,
    int? turn,
    List<PoolGroup?>? groups,
    PoolHand? hand,
    bool? breakShot,
    int? winner,
    PoolWin? win,
    int? shots,
    List<PoolFoul>? lastFouls,
  }) => PoolGame(
    balls: balls ?? this.balls,
    turn: turn ?? this.turn,
    groups: groups ?? this.groups,
    hand: hand ?? this.hand,
    breakShot: breakShot ?? this.breakShot,
    winner: winner ?? this.winner,
    win: win ?? this.win,
    shots: shots ?? this.shots,
    lastFouls: lastFouls ?? this.lastFouls,
  );

  /// The cue ball placed at ([x], [y]) (in hand).
  PoolGame placeCue(double x, double y) {
    if (!canPlace(x, y)) throw StateError("can't place the cue ball there");
    final b = balls.copy();
    b.x[kCueBall] = x;
    b.y[kCueBall] = y;
    b.on[kCueBall] = true;
    return copyWith(balls: b);
  }

  /// The player to shoot resigns: the other wins.
  PoolGame resign() => copyWith(winner: 1 - turn, win: PoolWin.resign);

  /// The game after the player to shoot played [shot] with [result]
  /// ([simulateShot] from [balls]), [called] the pocket called for the 8.
  PoolGame after(PoolShotResult result, {int? called}) {
    final me = turn;
    final fouls = <PoolFoul>[];
    final first = result.firstContact;
    final dropped = result.pocketed;
    final scratched = dropped.any((d) => d.$1 == kCueBall);
    final eight = dropped.where((d) => d.$1 == kEightBall).firstOrNull;
    final wasOnEight = onTheEight(me);

    if (scratched) fouls.add(PoolFoul.scratch);
    if (first == null) {
      fouls.add(PoolFoul.noContact);
    } else if (!breakShot) {
      final g = groups[me];
      final legal = wasOnEight
          ? first == kEightBall
          : g == null
          ? first != kEightBall
          : g.has(first);
      if (!legal) fouls.add(PoolFoul.wrongBall);
    }
    final objectDropped = dropped.any((d) => d.$1 != kCueBall);
    if (!breakShot &&
        first != null &&
        !objectDropped &&
        !result.cushionAfterContact) {
      fouls.add(PoolFoul.noCushion);
    }

    final end = result.end.copy();

    // The 8.
    if (eight != null) {
      if (breakShot) {
        _respotEight(end);
      } else {
        final win = !wasOnEight
            ? PoolWin.eightEarly
            : fouls.isNotEmpty
            ? PoolWin.eightFoul
            : called != eight.$2
            ? PoolWin.eightWrongPocket
            : PoolWin.eight;
        return copyWith(
          balls: end,
          winner: win == PoolWin.eight ? me : 1 - me,
          win: win,
          shots: shots + 1,
          lastFouls: fouls,
        );
      }
    }

    // Groups: decided by the first ball pocketed after the break, on a
    // clean shot.
    var nextGroups = groups;
    if (open && !breakShot && fouls.isEmpty) {
      final firstBall = dropped
          .map((d) => d.$1)
          .where((b) => b != kCueBall && b != kEightBall)
          .firstOrNull;
      if (firstBall != null) {
        final g = PoolGroup.solids.has(firstBall)
            ? PoolGroup.solids
            : PoolGroup.stripes;
        nextGroups = me == 0 ? [g, g.other] : [g.other, g];
      }
    }

    // Who's next.
    final mine = nextGroups[me];
    final pocketedMine = dropped.any(
      (d) =>
          d.$1 != kCueBall &&
          d.$1 != kEightBall &&
          (breakShot || mine == null || mine.has(d.$1)),
    );
    final keeps = fouls.isEmpty && pocketedMine;
    if (scratched) end.on[kCueBall] = false;

    return PoolGame(
      balls: end,
      turn: keeps ? me : 1 - me,
      groups: nextGroups,
      hand: fouls.isNotEmpty ? PoolHand.anywhere : PoolHand.none,
      breakShot: false,
      shots: shots + 1,
      lastFouls: fouls,
    );
  }

  /// The 8 back on the table (pocketed on the break): on the foot spot, or
  /// the nearest free point behind it.
  static void _respotEight(PoolBalls b) {
    final (fx, fy) = kFootSpot;
    for (var k = 0; k < 40; k++) {
      final x = fx + k * kBallRadius * 0.5;
      if (b.isFree(x, fy, except: kEightBall)) {
        b.x[kEightBall] = x;
        b.y[kEightBall] = fy;
        b.on[kEightBall] = true;
        return;
      }
    }
  }

  Map<String, Object?> toJson() => {
    'balls': balls.toJson(),
    'turn': turn,
    'groups': [for (final g in groups) g?.name],
    'hand': hand.name,
    'break': breakShot,
    'winner': winner,
    'win': win?.name,
    'shots': shots,
    'fouls': [for (final f in lastFouls) f.name],
  };

  factory PoolGame.fromJson(Map<String, Object?> json) => PoolGame(
    balls: PoolBalls.fromJson(json['balls']! as Map<String, Object?>),
    turn: json['turn']! as int,
    groups: [
      for (final g in json['groups']! as List)
        g == null ? null : PoolGroup.values.byName(g as String),
    ],
    hand: PoolHand.values.byName(json['hand']! as String),
    breakShot: json['break']! as bool,
    winner: json['winner'] as int?,
    win: json['win'] == null
        ? null
        : PoolWin.values.byName(json['win']! as String),
    shots: (json['shots'] ?? 0) as int,
    lastFouls: [
      for (final f in (json['fouls'] ?? const []) as List)
        PoolFoul.values.byName(f as String),
    ],
  );
}

/// A rack: the 15 balls in a triangle with its apex on the foot spot, the 8
/// in the middle, a solid and a stripe in the back corners, the rest mixed
/// by [seed]; the cue ball on the head spot.
PoolBalls rackBalls(int seed) {
  final rng = math.Random(seed);
  final solids = [1, 2, 3, 4, 5, 6, 7]..shuffle(rng);
  final stripes = [9, 10, 11, 12, 13, 14, 15]..shuffle(rng);
  // The rows from the apex, 1 to 5 balls; the 8 in row 3's middle, a
  // solid and a stripe at row 5's ends (which corner is which, by seed).
  final order = List<int?>.filled(15, null);
  order[4] = kEightBall; // row 3, middle
  final solidLeft = rng.nextBool();
  order[10] = solidLeft ? solids.removeLast() : stripes.removeLast();
  order[14] = solidLeft ? stripes.removeLast() : solids.removeLast();
  final rest = [...solids, ...stripes]..shuffle(rng);
  for (var i = 0; i < 15; i++) {
    order[i] ??= rest.removeLast();
  }

  final b = PoolBalls.empty();
  final (fx, fy) = kFootSpot;
  const gap = 1.0005; // a hair apart, so nothing starts touching
  final rowStep = 2 * kBallRadius * gap * 0.8660254037844386; // cos 30°
  var i = 0;
  for (var row = 0; row < 5; row++) {
    for (var k = 0; k <= row; k++) {
      final ball = order[i++]!;
      b.x[ball] = fx + row * rowStep;
      b.y[ball] = fy + (k - row / 2) * 2 * kBallRadius * gap;
      b.on[ball] = true;
    }
  }
  final (hx, hy) = kHeadSpot;
  b.x[kCueBall] = hx;
  b.y[kCueBall] = hy;
  b.on[kCueBall] = true;
  return b;
}

/// [group]'s balls still on the table.
Uint8List remaining(PoolGame game, PoolGroup group) => Uint8List.fromList([
  for (var b = 1; b < kBalls; b++)
    if (group.has(b) && game.balls.on[b]) b,
]);
