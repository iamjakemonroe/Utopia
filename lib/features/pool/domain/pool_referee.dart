import 'dart:math' as math;

import '../../chess/domain/chess_bot.dart' show BotLevel;
import 'pool_bot.dart';
import 'pool_cues.dart';
import 'pool_physics.dart';
import 'pool_rules.dart';

/// The server's referee at the pool coin tables, where you play Chip for
/// coins: it racks the balls, plays your shot on the table it holds (with
/// your cue's stats, never the app's word for what happened), and plays
/// Chip's turns. Plain Dart, the apps' own physics and rules, compiled to
/// JavaScript for the pool-table function (lib/web_workers/
/// pool_referee_js.dart).
///
/// You're player 0 and Chip player 1. [ask] is one of:
///
/// * `{do: 'rack', seed}`: a new game; who breaks goes by the seed.
///   Answers `{state}`.
/// * `{do: 'shot', state, shot, place?, called?, cue, level}`: your shot
///   ([PoolShot] as JSON), where you put the cue ball if it was in hand,
///   and the pocket you call on the 8; [cue] and [level] are your cue's.
/// * `{do: 'chip', state, bot, seed, cue, level}`: Chip's turn, at [bot]
///   (a [BotLevel] name), with its cue.
///
/// A shot answers `{legal: false, reason}` or `{legal: true, state, over}`
/// (`over` null, or `{winner, win}`); Chip's also has `move: {shot,
/// place, called}`, for the app to play it out.
Map<String, Object?> poolReferee(Map<String, Object?> ask) {
  try {
    return switch (ask['do']) {
      'rack' => _rack(_int(ask['seed'])),
      'shot' => _shot(ask),
      'chip' => _chip(ask),
      _ => _illegal('unknown'),
    };
  } catch (_) {
    // Something that doesn't even parse.
    return _illegal('unreadable');
  }
}

Map<String, Object?> _rack(int seed) => {
  'state': PoolGame.rack(seed, breaker: seed.isEven ? 0 : 1).toJson(),
};

Map<String, Object?> _shot(Map<String, Object?> ask) {
  var game = PoolGame.fromJson(_map(ask['state']));
  if (game.over || game.turn != 0) return _illegal('not your shot');

  // The cue ball: placed where they put it when it was in hand (and only
  // then).
  final place = ask['place'];
  if (game.hand != PoolHand.none) {
    if (place == null) return _illegal('place the cue ball');
    final p = _map(place);
    final x = _num(p['x']), y = _num(p['y']);
    if (!game.canPlace(x, y)) return _illegal('the cue ball can\'t go there');
    game = game.placeCue(x, y);
  } else if (place != null) {
    return _illegal('the cue ball isn\'t in hand');
  }
  if (!game.balls.on[kCueBall]) {
    return _illegal('the cue ball isn\'t on the table');
  }

  final raw = _map(ask['shot']);
  final dx = _num(raw['dx']), dy = _num(raw['dy']);
  final power = _num(raw['power']);
  if ((dx * dx + dy * dy - 1).abs() > 1e-6) return _illegal('no aim');
  if (power < 0.02 || power > 1) return _illegal('no power');
  var shot = PoolShot.fromJson(raw);
  // The tip strikes within the cue ball's face: a spin past its edge is
  // brought back to it (an app does that itself, so this is a hair's
  // tolerance, not a rounding that would change an honest shot).
  final reach = shot.spinX * shot.spinX + shot.spinY * shot.spinY;
  if (reach > 1 + 1e-9) {
    final k = 1 / math.sqrt(reach);
    shot = PoolShot(
      dx: shot.dx,
      dy: shot.dy,
      power: shot.power,
      spinX: shot.spinX * k,
      spinY: shot.spinY * k,
    );
  }

  final int? called;
  if (game.callsPocket) {
    final c = ask['called'];
    if (c is! num || c < 0 || c >= kPockets.length || c != c.roundToDouble()) {
      return _illegal('call a pocket');
    }
    called = c.toInt();
  } else {
    called = null;
  }

  final cue = poolCue(ask['cue'] as String?).at(_int(ask['level']));
  return _played(game, shot, called, cue);
}

Map<String, Object?> _chip(Map<String, Object?> ask) {
  final start = PoolGame.fromJson(_map(ask['state']));
  if (start.over || start.turn != 1) return _illegal('not Chip\'s shot');
  final level = BotLevel.values.byName(ask['bot']! as String);
  final cue = poolCue(ask['cue'] as String?).at(_int(ask['level']));
  final move = choosePoolMove(start, level, _int(ask['seed']), cue: cue);

  var game = start;
  Map<String, Object?>? place;
  if (game.hand != PoolHand.none) {
    final (x, y) = _spot(game, move);
    game = game.placeCue(x, y);
    place = {'x': x, 'y': y};
  }
  final called = game.callsPocket
      ? (move.called ?? _nearestPocket(game.balls, kEightBall))
      : null;
  return {
    ..._played(game, move.shot, called, cue),
    'move': {'shot': move.shot.toJson(), 'place': place, 'called': called},
  };
}

/// [shot] played from [game] (the cue ball where it'll be struck from)
/// with [cue]'s stats, and the game after it.
Map<String, Object?> _played(
  PoolGame game,
  PoolShot shot,
  int? called,
  CueStats cue,
) {
  final result = simulateShot(
    game.balls,
    shot,
    record: false,
    maxSpeed: cue.maxSpeed,
    tipOffset: cue.tipOffset,
  );
  final next = game.after(result, called: called);
  return {
    'legal': true,
    'state': next.toJson(),
    'over': next.over ? {'winner': next.winner, 'win': next.win!.name} : null,
  };
}

/// Where Chip puts the cue ball in hand: where it chose, or failing that
/// the first free spot it may use.
(double, double) _spot(PoolGame game, PoolBotMove move) {
  final x = move.cueX, y = move.cueY;
  if (x != null && y != null && game.canPlace(x, y)) return (x, y);
  final maxX = game.hand == PoolHand.kitchen
      ? kHeadString - 0.01
      : kPoolLength - kBallRadius;
  for (var i = 0; i < 400; i++) {
    final px = kBallRadius + (i % 20) / 19 * (maxX - kBallRadius);
    final py = kBallRadius + (i ~/ 20) / 19 * (kPoolWidth - 2 * kBallRadius);
    if (game.canPlace(px, py)) return (px, py);
  }
  throw StateError('nowhere to put the cue ball');
}

int _nearestPocket(PoolBalls b, int ball) {
  var best = 0;
  var bestD = double.infinity;
  for (var p = 0; p < kPockets.length; p++) {
    final dx = b.x[ball] - kPockets[p].x, dy = b.y[ball] - kPockets[p].y;
    final d = dx * dx + dy * dy;
    if (d < bestD) {
      bestD = d;
      best = p;
    }
  }
  return best;
}

Map<String, Object?> _illegal(String reason) => {
  'legal': false,
  'reason': reason,
};

Map<String, Object?> _map(Object? v) => (v! as Map).cast<String, Object?>();

double _num(Object? v) {
  final n = (v! as num).toDouble();
  if (!n.isFinite) throw const FormatException('not a number');
  return n;
}

int _int(Object? v) => (v! as num).toInt();
