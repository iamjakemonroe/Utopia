import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:utopia/features/chess/domain/chess_bot.dart' show BotLevel;
import 'package:utopia/features/pool/data/pool_repository.dart';
import 'package:utopia/features/pool/domain/pool_cues.dart';
import 'package:utopia/features/pool/domain/pool_physics.dart';
import 'package:utopia/features/pool/domain/pool_referee.dart';
import 'package:utopia/features/pool/domain/pool_rules.dart';
import 'package:utopia/features/pool/presentation/pool_match_controller.dart';

Map<String, Object?> _json(Object? v) =>
    (jsonDecode(jsonEncode(v)) as Map).cast<String, Object?>();

/// The pool-table function and the database, here: every shot through the
/// referee (as JSON, as on the wire), the game kept as the server keeps it.
class _Server extends PoolRepository {
  _Server(int seed)
    : super(
        SupabaseClient(
          'http://localhost',
          'k',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      ) {
    state = (poolReferee({'do': 'rack', 'seed': seed})['state']! as Map)
        .cast<String, Object?>();
  }

  late Map<String, Object?> state;
  int shots = 0;
  String status = 'active';
  int chipSeed = 1;
  int refused = 0;

  PoolTableGame get table => PoolTableGame.fromRow({
    'id': 'g',
    'table_id': 'dunes',
    'entry': 1000,
    'prize': 1900,
    'bot': 'hard',
    'bot_cue': 'cue_oak',
    'bot_cue_level': 3,
    'cue_id': 'cue_neon',
    'cue_level': 4,
    'state': _json(state),
    'shots': shots,
    'status': status,
  });

  @override
  Future<PoolTableGame> game(String id) async => table;

  @override
  Future<PoolRuling> shoot({
    required String gameId,
    required int shots,
    required PoolShot shot,
    (double, double)? place,
    int? called,
  }) async {
    if (shots != this.shots) {
      throw const PoolRefused('out of sync', conflict: true);
    }
    final r = poolReferee(
      _json({
        'do': 'shot',
        'state': state,
        'shot': shot.toJson(),
        'place': place == null ? null : {'x': place.$1, 'y': place.$2},
        'called': called,
        'cue': 'cue_neon',
        'level': 4,
      }),
    );
    if (r['legal'] != true) {
      refused++;
      throw PoolRefused('${r['reason']}');
    }
    return _record(r, null);
  }

  @override
  Future<PoolRuling> chip({required String gameId, required int shots}) async {
    final r = poolReferee(
      _json({
        'do': 'chip',
        'state': state,
        'bot': BotLevel.hard.name,
        'seed': chipSeed++,
        'cue': 'cue_oak',
        'level': 3,
      }),
    );
    if (r['legal'] != true) throw PoolRefused('${r['reason']}', conflict: true);
    return _record(r, r['move']);
  }

  PoolRuling _record(Map<String, Object?> r, Object? move) {
    shots++;
    state = (r['state']! as Map).cast<String, Object?>();
    final over = r['over'] as Map?;
    if (over != null) status = over['winner'] == 0 ? 'won' : 'lost';
    return PoolRuling.fromJson(
      _json({
        'state': state,
        'shots': shots,
        'status': status,
        'prize': status == 'won' ? 1900 : 0,
        'move': move,
      }).cast<String, dynamic>(),
    );
  }
}

/// Plays a whole game at a coin table: the player's shots and Chip's, the
/// app and the server in step all the way.
Future<(_Server, PoolMatchController)> _play(
  WidgetTester tester,
  int seed,
) async {
  final server = _Server(seed);
  final c = PoolMatchController.table(table: server.table, repository: server);
  c.start();
  var aimSeed = seed;
  for (var i = 0; i < 40000 && !c.over; i++) {
    if (c.canPlay) {
      // Aim at a ball the player may hit (or anywhere), at a fair lick.
      final targets = c.game.targets.where((b) => c.game.balls.on[b]).toList();
      final t = targets.isEmpty ? null : targets[aimSeed % targets.length];
      aimSeed = (aimSeed * 1103515245 + 12345) & 0x7fffffff;
      if (t != null) {
        c.aimAt(c.game.balls.x[t], c.game.balls.y[t]);
      } else {
        c.nudge(0.7);
      }
      if (c.game.callsPocket) c.callPocket(aimSeed % 6);
      c.setSpin(((aimSeed >> 3) % 7 - 3) / 4, ((aimSeed >> 6) % 7 - 3) / 4);
      c.setPower(0.35 + (aimSeed % 50) / 100);
      expect(c.shoot(), isTrue);
    }
    c.advance(1 / 60);
    await tester.pump(const Duration(milliseconds: 16));
  }
  return (server, c);
}

void main() {
  testWidgets('a coin-table game: every shot lands where the server says', (
    tester,
  ) async {
    for (final seed in [3, 8]) {
      final (server, c) = await _play(tester, seed);
      expect(c.over, isTrue, reason: 'seed $seed: the game finished');
      expect(server.shots, greaterThan(4), reason: 'seed $seed: a real game');
      expect(
        c.mismatches,
        0,
        reason: 'seed $seed: the app and the server agreed',
      );
      expect(server.refused, 0, reason: 'seed $seed: no shot was turned down');
      expect(c.shots, server.shots);
      expect(c.status, server.status);
      expect(jsonEncode(c.game.toJson()), jsonEncode(server.state));
      c.dispose();
    }
  });

  testWidgets('a shot the server turns down puts the table back', (
    tester,
  ) async {
    final server = _Server(4);
    final c = PoolMatchController.table(
      table: server.table,
      repository: server,
    );
    // The app thinks it's further on than the server is.
    c.shots = 5;
    c.setPower(0.8);
    expect(c.shoot(), isTrue);
    for (var i = 0; i < 1200 && (c.moving || c.playing != null); i++) {
      c.advance(1 / 60);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 50));
    expect(c.shots, 0);
    expect(
      jsonEncode(c.game.balls.toJson()),
      jsonEncode(PoolGame.fromJson(server.state).balls.toJson()),
    );
    expect(c.trouble, isNull);
    c.dispose();
  });

  test(
    'on one phone: both players share the cue, the spin stays on the ball',
    () {
      final c = PoolMatchController.passAndPlay(
        cue: poolCue('cue_galaxy'),
        cueLevel: 7,
        seed: 2,
      );
      expect(c.shooterCue.id, 'cue_galaxy');
      c.setSpin(3, 4);
      expect(c.spinX * c.spinX + c.spinY * c.spinY, closeTo(1, 1e-9));
      c.setPower(0.9);
      expect(c.shoot(), isTrue);
      for (
        var i = 0;
        i < 2000 && (c.playing != null || c.striking != null);
        i++
      ) {
        c.advance(1 / 60);
      }
      expect(c.game.shots, 1);
      expect(c.game.breakShot, isFalse);
      c.dispose();
    },
  );
}
