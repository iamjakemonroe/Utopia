import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import '../../../core/platform/bot_worker.dart';
import '../../../core/platform/off_main.dart';
import '../../chess/domain/chess_bot.dart' show BotLevel;
import 'pool_bot.dart';
import 'pool_rules.dart';

/// Chip's turn at the pool table, off the main thread so the table keeps
/// moving while it thinks: an isolate in the apps, the Web Worker in a
/// browser (the same thinking where the worker can't run).
Future<PoolBotMove> findPoolBotMove(PoolGame game, BotLevel level) async {
  final position = jsonEncode(game.toJson());
  final seed = Random().nextInt(1 << 30);
  if (kOnWeb) {
    try {
      final result = await botResultInWorker({
        'game': 'pool',
        'position': position,
        'level': level.name,
        'seed': seed,
      });
      if (result is Map) {
        return PoolBotMove.fromJson(result.cast<String, Object?>());
      }
    } catch (_) {}
    return offMainThread(() => _choose(position, level.name, seed));
  }
  return Isolate.run(() => _choose(position, level.name, seed));
}

PoolBotMove _choose(String position, String level, int seed) => choosePoolMove(
  PoolGame.fromJson(jsonDecode(position) as Map<String, Object?>),
  BotLevel.values.byName(level),
  seed,
);

/// For the browser's worker: the bot's move for [position] (a game, as
/// JSON), as JSON.
Map<String, Object?> poolBotMoveJson(String position, String level, int seed) =>
    _choose(position, level, seed).toJson();
