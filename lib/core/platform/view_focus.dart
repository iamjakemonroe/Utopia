import 'dart:ui';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Focus changes that come before the first frame wait for it.
///
/// A browser focuses the game's view as it starts, before anything has been
/// laid out. Flutter then looks for the first thing that can take focus by
/// where things are on screen, when nothing has a place yet: an error on
/// every visit. Held until the first frame is drawn, focus lands just where
/// it would have.
void holdViewFocusUntilFirstFrame() {
  final binding = WidgetsBinding.instance;
  var ready = false;
  final waiting = <ViewFocusEvent>[];
  // In place of the binding's own handler, which it hands them on to.
  binding.platformDispatcher.onViewFocusChange = (event) {
    if (ready) {
      binding.handleViewFocusChanged(event);
    } else {
      waiting.add(event);
    }
  };
  SchedulerBinding.instance.addPostFrameCallback((_) {
    ready = true;
    for (final event in waiting) {
      binding.handleViewFocusChanged(event);
    }
    waiting.clear();
  });
}
