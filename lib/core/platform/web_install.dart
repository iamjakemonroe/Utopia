import 'web_install_native.dart'
    if (dart.library.js_interop) 'web_install_web.dart'
    as impl;

/// Installing the web game as an app (a PWA): its own icon on the home
/// screen or dock, full screen. Everything is false in the apps.
abstract final class WebInstall {
  /// Already opened from the home screen or dock.
  static bool get installed => impl.installed();

  /// The browser can show its own install dialog (Chrome, Edge, Android).
  static bool get canPrompt => impl.canPrompt();

  /// Shows the browser's install dialog: whether they installed.
  static Future<bool> prompt() => impl.prompt();

  /// Safari on a Mac (installs through File > Add to Dock).
  static bool get macSafari => impl.macSafari();
}
