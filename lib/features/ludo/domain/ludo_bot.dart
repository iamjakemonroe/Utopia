import 'dart:math';

import 'ludo_engine.dart';

const _engine = LudoEngine();

/// How a computer player picks which piece to move: every legal move is
/// scored for what it achieves (winning, capturing, getting home, getting
/// out of base, reaching safety, running from danger) and what it risks
/// (landing where an opponent can hit it), with a dash of randomness so
/// bots don't all play the same.
int chooseLudoMove(LudoState state, int dice, {Random? random}) {
  final rng = random ?? Random();
  final options = _engine.legalTokenMoves(state, dice);
  if (options.length == 1) return options.first;
  final rules = state.rules;
  final color = state.turn;
  final mine = state.tokens[color]!;

  var best = options.first;
  var bestScore = double.negativeInfinity;
  for (final i in options) {
    final from = mine[i];
    final result = _engine.applyMove(state, i, dice);
    final to = result.toPosition;
    var score = 0.0;

    if (result.wonGame) score += 10000;
    if (result.captured) score += 140;
    if (result.reachedHome) score += 100;
    if (from == kLudoBase) score += 70;

    // Progress, a little more for pieces already far along.
    if (from != kLudoBase) score += dice * 2 + from * 0.15;

    // Into the private home stretch: nobody can touch it there.
    if (from != kLudoBase && rules.isOnRing(from) && !rules.isOnRing(to)) {
      score += 45;
    }

    // Safety where it lands, and whether it escaped danger.
    if (rules.isOnRing(to)) {
      final square = rules.absoluteSquare(color, to);
      if (rules.safeSquares.contains(square)) {
        score += 30;
      } else {
        score -= 45 * _threats(state, color, square);
      }
    }
    if (from != kLudoBase && rules.isOnRing(from)) {
      final square = rules.absoluteSquare(color, from);
      if (!rules.safeSquares.contains(square)) {
        score += 30 * _threats(state, color, square);
      }
    }

    score += rng.nextDouble() * 12;
    if (score > bestScore) {
      bestScore = score;
      best = i;
    }
  }
  return best;
}

/// How many opponent pieces could land on ring [square] with one roll.
int _threats(LudoState state, LudoColor me, int square) {
  final rules = state.rules;
  var count = 0;
  for (final other in state.activePlayers) {
    if (other == me) continue;
    for (final p in state.tokens[other]!) {
      if (!rules.isOnRing(p)) continue;
      final theirs = rules.absoluteSquare(other, p);
      final gap = (square - theirs) % rules.ringSize;
      // Within reach, and they won't have turned off toward home first.
      if (gap >= 1 && gap <= 6 && p + gap <= rules.ringLast) count++;
    }
  }
  return count;
}
