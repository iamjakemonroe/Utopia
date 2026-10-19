import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// The bots' thinking in a browser: a Web Worker (bot_worker.js, built from
/// lib/web_workers/bot_worker.dart) runs the same engines in the
/// background, as the apps do in an isolate, so the board keeps moving.
web.Worker? _worker;
var _next = 0;
final _waiting = <int, Completer<int?>>{};

web.Worker _start() {
  final worker = web.Worker('bot_worker.js'.toJS);
  worker.onmessage = ((web.MessageEvent event) {
    final data = event.data;
    if (data == null || !data.isA<JSString>()) return;
    final answer =
        jsonDecode((data as JSString).toDart) as Map<String, dynamic>;
    _waiting.remove(answer['id'])?.complete(answer['move'] as int?);
  }).toJS;
  worker.onerror = ((web.Event _) {
    final failed = StateError('The bot worker failed');
    for (final waiting in _waiting.values) {
      waiting.completeError(failed);
    }
    _waiting.clear();
    _worker = null;
  }).toJS;
  return worker;
}

/// The index of the bot's move among the position's legal moves (null when
/// it has none), worked out by the worker for [job]: {game, position,
/// level, seed}.
Future<int?> botMoveInWorker(Map<String, Object> job) {
  final worker = _worker ??= _start();
  final id = _next++;
  final done = Completer<int?>();
  _waiting[id] = done;
  worker.postMessage(jsonEncode({...job, 'id': id}).toJS);
  return done.future;
}
