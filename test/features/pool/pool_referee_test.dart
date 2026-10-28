import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:utopia/features/pool/domain/pool_cues.dart';
import 'package:utopia/features/pool/domain/pool_physics.dart';
import 'package:utopia/features/pool/domain/pool_referee.dart';
import 'package:utopia/features/pool/domain/pool_rules.dart';

/// [ask] as the server sends it: through JSON and back.
Map<String, Object?> _rule(Map<String, Object?> ask) =>
    (jsonDecode(
              jsonEncode(
                poolReferee(
                  jsonDecode(jsonEncode(ask)) as Map<String, Object?>,
                ),
              ),
            )
            as Map)
        .cast<String, Object?>();

PoolGame _game(Map<String, Object?> json) => PoolGame.fromJson(json);

void main() {
  test('a rack: sixteen balls, the break with whoever the seed says', () {
    final even = _game(
      _rule({'do': 'rack', 'seed': 10})['state']! as Map<String, Object?>,
    );
    final odd = _game(
      _rule({'do': 'rack', 'seed': 11})['state']! as Map<String, Object?>,
    );
    expect(even.balls.on.every((on) => on), isTrue);
    expect(even.turn, 0);
    expect(odd.turn, 1);
    expect(even.breakShot && even.hand == PoolHand.kitchen, isTrue);
  });

  test('a shot plays out exactly as the app plays it', () {
    final rack =
        _rule({'do': 'rack', 'seed': 4})['state']! as Map<String, Object?>;
    final shot = PoolShot(dx: 1, dy: 0.013, power: 0.93, spinY: 0.2);
    final ruling = _rule({
      'do': 'shot',
      'state': rack,
      'shot': shot.toJson(),
      'place': {'x': 0.45, 'y': 0.52},
      'cue': 'cue_inferno',
      'level': 4,
    });
    expect(ruling['legal'], isTrue);
    // The app: the same table, the cue ball placed, the same cue.
    final stats = poolCue('cue_inferno').at(4);
    final start = _game(rack).placeCue(0.45, 0.52);
    final result = simulateShot(
      start.balls,
      shot,
      maxSpeed: stats.maxSpeed,
      tipOffset: stats.tipOffset,
    );
    expect(
      jsonEncode(start.after(result).toJson()),
      jsonEncode(ruling['state']),
    );
  });

  test('a shot read back from JSON is the very shot written', () {
    for (var i = 1; i < 200; i++) {
      final shot = PoolShot(
        dx: i * 0.37,
        dy: -i * 0.11 + 3,
        power: i / 200,
        spinX: 0.3,
        spinY: -0.4,
      );
      final back = PoolShot.fromJson(
        jsonDecode(jsonEncode(shot.toJson())) as Map<String, Object?>,
      );
      expect(back.dx, shot.dx);
      expect(back.dy, shot.dy);
      expect(back.power, shot.power);
    }
  });

  test(
    'a stronger cue sends the ball further; a spinnier one screws it back more',
    () {
      final balls = PoolBalls.empty()
        ..x[kCueBall] = 0.3
        ..y[kCueBall] = 0.5
        ..on[kCueBall] = true;
      // A gentle shot down an empty table, short of the far cushion.
      PoolShotResult roll(PoolShot shot, CueStats s) => simulateShot(
        balls,
        shot,
        maxSpeed: s.maxSpeed,
        tipOffset: s.tipOffset,
      );
      final gentle = PoolShot(dx: 1, dy: 0, power: 0.06);
      final weak = roll(gentle, const CueStats(40, 50, 50));
      final strong = roll(gentle, const CueStats(100, 50, 50));
      expect(
        weak.events.where((e) => e.kind == PoolEventKind.cushion),
        isEmpty,
      );
      expect(
        strong.events.where((e) => e.kind == PoolEventKind.cushion),
        isEmpty,
      );
      expect(strong.end.x[kCueBall], greaterThan(weak.end.x[kCueBall]));
      final screw = PoolShot(dx: 1, dy: 0, power: 0.06, spinY: -1);
      expect(
        roll(screw, const CueStats(50, 50, 100)).end.x[kCueBall],
        lessThan(roll(screw, const CueStats(50, 50, 0)).end.x[kCueBall]),
      );
    },
  );

  group('it turns down', () {
    final rack =
        _rule({'do': 'rack', 'seed': 4})['state']! as Map<String, Object?>;
    final good = PoolShot(dx: 1, dy: 0, power: 0.9).toJson();
    Map<String, Object?> ask(Map<String, Object?> extra) => {
      'do': 'shot',
      'state': rack,
      'shot': good,
      'place': {'x': 0.45, 'y': 0.5},
      'cue': 'cue_classic',
      'level': 1,
      ...extra,
    };

    test('a shot that isn\'t the player\'s', () {
      final chips = {...rack, 'turn': 1};
      expect(_rule(ask({'state': chips}))['legal'], isFalse);
    });
    test('the cue ball in hand, not placed', () {
      expect(_rule(ask({'place': null}))['legal'], isFalse);
    });
    test('the cue ball placed where it can\'t go', () {
      expect(
        _rule(
          ask({
            'place': {'x': 1.2, 'y': 0.5},
          }),
        )['legal'],
        isFalse,
      );
    });
    test('an aim that isn\'t a direction', () {
      expect(
        _rule(
          ask({
            'shot': {'dx': 3, 'dy': 0, 'power': 0.5},
          }),
        )['legal'],
        isFalse,
      );
    });
    test('no power', () {
      expect(
        _rule(
          ask({
            'shot': {'dx': 1, 'dy': 0, 'power': 0},
          }),
        )['legal'],
        isFalse,
      );
    });
    test('nonsense', () {
      expect(_rule(ask({'shot': 'hit it hard'}))['legal'], isFalse);
      expect(_rule({'do': 'shot'})['legal'], isFalse);
    });
    test('the 8 without a called pocket', () {
      // Player 0 has potted every solid: on the 8.
      final g = _game(rack);
      final balls = g.balls.copy();
      for (var b = 1; b <= 7; b++) {
        balls.on[b] = false;
      }
      final onEight = g
          .copyWith(
            balls: balls,
            groups: [PoolGroup.solids, PoolGroup.stripes],
            breakShot: false,
            hand: PoolHand.none,
          )
          .toJson();
      final call = {'state': onEight, 'place': null};
      expect(_rule(ask(call))['legal'], isFalse);
      expect(_rule(ask({...call, 'called': 9}))['legal'], isFalse);
      expect(_rule(ask({...call, 'called': 3}))['legal'], isTrue);
    });
  });

  test('Chip\'s turn plays out exactly as the app plays it back', () {
    var state =
        _rule({'do': 'rack', 'seed': 7})['state']!
            as Map<String, Object?>; // Chip breaks
    for (var k = 0; k < 6; k++) {
      final game = _game(state);
      if (game.over || game.turn != 1) break;
      final ruling = _rule({
        'do': 'chip',
        'state': state,
        'bot': 'hard',
        'seed': 100 + k,
        'cue': 'cue_carbon',
        'level': 4,
      });
      expect(ruling['legal'], isTrue);
      final move = (ruling['move']! as Map).cast<String, Object?>();
      var start = game;
      final place = move['place'] as Map?;
      if (place != null) {
        start = start.placeCue(
          (place['x']! as num).toDouble(),
          (place['y']! as num).toDouble(),
        );
      }
      final stats = poolCue('cue_carbon').at(4);
      final result = simulateShot(
        start.balls,
        PoolShot.fromJson((move['shot']! as Map).cast<String, Object?>()),
        maxSpeed: stats.maxSpeed,
        tipOffset: stats.tipOffset,
      );
      final mine = start.after(result, called: move['called'] as int?);
      expect(
        jsonEncode(mine.toJson()),
        jsonEncode(ruling['state']),
        reason: 'shot $k',
      );
      state = ruling['state']! as Map<String, Object?>;
    }
  });

  test('Chip doesn\'t play the player\'s shot', () {
    final rack =
        _rule({'do': 'rack', 'seed': 4})['state']! as Map<String, Object?>;
    expect(
      _rule({
        'do': 'chip',
        'state': rack,
        'bot': 'easy',
        'seed': 1,
        'cue': 'cue_classic',
        'level': 1,
      })['legal'],
      isFalse,
    );
  });
}
