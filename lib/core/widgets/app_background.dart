import 'package:flutter/material.dart';

import 'utopia_world.dart';

/// Puts a screen's body in Utopia's living world ([UtopiaWorld]): the
/// twilight sky, floating islands and cloud sea every screen shares. The
/// world runs on one shared clock, so moving between screens never makes it
/// jump.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child, this.under});

  final Widget child;

  /// Drawn under the world, where it can't be seen (see DrawnAhead).
  final Widget? under;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Always there, so the world never moves along the list (it would
        // be made again).
        under ?? const SizedBox.shrink(),
        const UtopiaWorld(),
        LayoutIsland(child: child),
      ],
    );
  }
}

/// Where a screen's animations stop asking for layout. Flutter builds what
/// changes under a [LayoutBuilder] as part of laying it out, so every tick
/// of every animation on a screen whose Scaffold builds its body that way
/// (one behind its app bar) laid the whole Scaffold out again, every frame.
/// Under this they're built here instead: it's given its exact size, so
/// laying it out goes no further up; and it's a layer of its own, with the
/// screen in another, so what follows a layout (drawing it again) is only
/// this thin wrapper, not the screen and its app bar.
class LayoutIsland extends StatelessWidget {
  const LayoutIsland({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: RepaintBoundary(
      child: LayoutBuilder(builder: (_, _) => RepaintBoundary(child: child)),
    ),
  );
}
