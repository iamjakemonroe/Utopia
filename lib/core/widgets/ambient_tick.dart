import 'package:flutter/scheduler.dart';

/// How often an ambient animation (a world, an aura, Chip) steps at most.
/// On a 120 Hz screen that's every other frame, halving the drawing for
/// motion that looks the same; 60 and 90 Hz screens step every frame.
const kAmbientStep = Duration(milliseconds: 10);

/// Wraps a ticker callback so it runs at most every [kAmbientStep]. Ticker
/// time restarts from zero when a ticker is restarted, so a step back in
/// time always runs.
TickerCallback ambientTick(TickerCallback onTick) {
  Duration? last;
  return (elapsed) {
    final previous = last;
    if (previous != null &&
        elapsed >= previous &&
        elapsed - previous < kAmbientStep) {
      return;
    }
    last = elapsed;
    onTick(elapsed);
  };
}
