/// The apps think in an isolate instead (see the bots).
Future<int?> botMoveInWorker(Map<String, Object> job) =>
    throw UnsupportedError('Web Workers are for browsers');

/// The apps think in an isolate instead (see the bots).
Future<Object?> botResultInWorker(Map<String, Object> job) =>
    throw UnsupportedError('Web Workers are for browsers');
