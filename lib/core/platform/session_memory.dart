import 'session_memory_native.dart'
    if (dart.library.js_interop) 'session_memory_web.dart'
    as impl;

/// In a browser tab, what's remembered until the tab is closed: a refresh
/// keeps it, so a refresh isn't taken for a new visit. Elsewhere nothing is
/// kept (reads are null): the app's own memory already lasts the session.
/// Never throws.
abstract final class SessionMemory {
  static String? read(String key) => impl.read(key);

  static void write(String key, String? value) => impl.write(key, value);
}
