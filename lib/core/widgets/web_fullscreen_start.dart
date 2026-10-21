import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/web_fullscreen.dart';
import '../settings/gameplay_settings.dart';

/// In a browser, with Play full screen on: the game goes full screen at the
/// player's first tap (a browser allows it no sooner). Once a visit: if
/// they leave full screen it isn't forced back on them; the switch in
/// Settings puts it back.
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
    WebFullscreen.onNextTouch(() {
      if (mounted && ref.read(gameplaySettingsProvider).fullScreen) {
        WebFullscreen.enter();
      }
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
