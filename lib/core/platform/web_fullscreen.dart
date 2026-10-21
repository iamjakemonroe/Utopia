import 'package:flutter/foundation.dart';

import 'web_fullscreen_native.dart'
    if (dart.library.js_interop) 'web_fullscreen_web.dart'
    as impl;

/// The web game full screen: the browser's address bar and tabs out of the
/// way while playing. Browsers only allow it from a tap or a key, and the
/// way back out is the browser's own (Esc on a computer, a swipe from the
/// top or Back on a phone), or the switch in Settings: nothing of ours sits
/// over the game. Everything is false in the apps.
abstract final class WebFullscreen {
  /// Worth offering here. Not in the apps or an installed web app (they're
  /// full screen already), not on an iPhone (Safari can't), and not on an
  /// iPad, where Safari puts its own close button over the game's corner.
  static bool get available => impl.available();

  /// A phone or tablet, played by touch.
  static bool get touch => impl.touch();

  /// Full screen right now, and as it changes.
  static final ValueNotifier<bool> active = impl.watch();

  /// Goes full screen: only from a tap or key (or within a few seconds of
  /// one).
  static void enter() => impl.enter();

  static void exit() => impl.exit();

  /// Runs [action] once, on the next tap or key, from inside the browser's
  /// own event (where going full screen is allowed).
  static void onNextTouch(void Function() action) => impl.onNextTouch(action);

  /// Runs [action] whenever full screen ends by the browser's doing, not
  /// the game's: on a phone, the Back button (which the browser spends on
  /// leaving full screen rather than going back); Esc on a computer.
  static void onLeftByBrowser(void Function() action) =>
      impl.onLeftByBrowser(action);
}
