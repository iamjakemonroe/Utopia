import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/web_fullscreen.dart';
import '../router/app_router.dart';
import '../settings/gameplay_settings.dart';

/// In a browser, with Play full screen on: the game goes full screen at the
/// player's first tap (a browser allows it no sooner). Once a visit: if
/// they leave full screen it isn't forced back on them; the switch in
/// Settings puts it back.
///
/// Except on a phone's Back: in full screen the browser spends it on
/// leaving full screen, so Back looked as if it did nothing. There it
/// goes back as it should (a game still asks first) and full screen
/// returns at the next tap. With nowhere to go back to, Back just leaves
/// full screen.
class WebFullscreenStart extends ConsumerStatefulWidget {
  const WebFullscreenStart({super.key});

  @override
  ConsumerState<WebFullscreenStart> createState() => _WebFullscreenStartState();
}

class _WebFullscreenStartState extends ConsumerState<WebFullscreenStart> {
  @override
  void initState() {
    super.initState();
    if (!WebFullscreen.available) return;
    WebFullscreen.onNextTouch(_enterIfOn);
    WebFullscreen.onLeftByBrowser(_back);
  }

  void _enterIfOn() {
    if (mounted && ref.read(gameplaySettingsProvider).fullScreen) {
      WebFullscreen.enter();
    }
  }

  void _back() {
    if (!mounted || !WebFullscreen.touch) return;
    final router = ref.read(goRouterProvider);
    if (!router.canPop()) return;
    // As the system's Back would: a screen that asks first still does.
    router.routerDelegate.popRoute();
    WebFullscreen.onNextTouch(_enterIfOn);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
