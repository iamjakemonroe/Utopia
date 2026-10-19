import 'web_render_native.dart'
    if (dart.library.js_interop) 'web_render_web.dart'
    as impl;

/// How sharp the game draws in a browser (web/index.html keeps it): at
/// most 2x, lowered on a device that can't keep up. Nothing in the apps.
abstract final class WebRender {
  /// Whether it can be changed (in a browser, without ?hires).
  static bool get available => impl.available();

  /// The sharpness it draws at now (2 is a phone's "retina", 1 plain).
  static double get cap => impl.cap();

  /// The screen's own sharpness (3 on most phones).
  static double get screen => impl.screen();

  /// Draws at [value] from now on (remembered on this device).
  static void lower(double value) => impl.setCap(value);
}
