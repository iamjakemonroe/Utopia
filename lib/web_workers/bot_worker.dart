// The bots' thinking (chess, checkers, pool), in a browser's background thread
// (a Web Worker). tool/build_web_game.sh compiles it to bot_worker.js:
//   dart compile js -O4 lib/web_workers/bot_worker.dart -o build/web/bot_worker.js
// It gets {id, game, position, level, seed} and answers {id, move, result}:
// for chess and checkers the index of the bot's move among the legal moves
// (or null), for pool the shot (JSON, see pool_bot_runner.dart).
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../features/checkers/domain/checkers_bot.dart';
import '../features/chess/domain/chess_bot.dart';
import '../features/pool/domain/pool_bot_runner.dart';

@JS('self')
external web.DedicatedWorkerGlobalScope get _self;

void main() {
  _self.onmessage = ((web.MessageEvent event) {
    final data = event.data;
    if (data == null || !data.isA<JSString>()) return;
    final job = jsonDecode((data as JSString).toDart) as Map<String, dynamic>;
    int? move;
    Object? result;
    try {
      final position = job['position'] as String;
      final level = job['level'] as String;
      final seed = job['seed'] as int;
      switch (job['game']) {
        case 'chess':
          move = chessBotMoveIndex(position, level, seed);
        case 'checkers':
          move = checkersBotMoveIndex(position, level, seed);
        case 'pool':
          result = poolBotMoveJson(position, level, seed);
      }
    } catch (_) {}
    _self.postMessage(
      jsonEncode({'id': job['id'], 'move': move, 'result': result}).toJS,
    );
  }).toJS;
}
