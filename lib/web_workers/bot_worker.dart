// The chess and checkers bots' thinking, in a browser's background thread
// (a Web Worker). tool/build_web_game.sh compiles it to bot_worker.js:
//   dart compile js -O4 lib/web_workers/bot_worker.dart -o build/web/bot_worker.js
// It gets {id, game, position, level, seed} and answers {id, move}: the
// index of the bot's move among the legal moves, or null.
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../features/checkers/domain/checkers_bot.dart';
import '../features/chess/domain/chess_bot.dart';

@JS('self')
external web.DedicatedWorkerGlobalScope get _self;

void main() {
  _self.onmessage = ((web.MessageEvent event) {
    final data = event.data;
    if (data == null || !data.isA<JSString>()) return;
    final job = jsonDecode((data as JSString).toDart) as Map<String, dynamic>;
    int? move;
    try {
      final position = job['position'] as String;
      final level = job['level'] as String;
      final seed = job['seed'] as int;
      move = switch (job['game']) {
        'chess' => chessBotMoveIndex(position, level, seed),
        'checkers' => checkersBotMoveIndex(position, level, seed),
        _ => null,
      };
    } catch (_) {}
    _self.postMessage(jsonEncode({'id': job['id'], 'move': move}).toJS);
  }).toJS;
}
