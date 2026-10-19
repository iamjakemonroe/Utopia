import 'dart:async';
import 'dart:isolate';

/// Whether this is running in a browser (without needing Flutter).
const kOnWeb = bool.fromEnvironment('dart.library.js_interop');

/// Runs [job] off the main thread in the apps (an isolate). A browser
/// can't start isolates (Isolate.run throws there), so it runs here, a
/// moment later.
Future<T> offMainThread<T>(FutureOr<T> Function() job) =>
    kOnWeb ? Future<T>(job) : Isolate.run(job);
