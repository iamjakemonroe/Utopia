import 'package:flutter/material.dart';

import 'utopia_world.dart';

/// Puts a screen's body in Utopia's living world ([UtopiaWorld]): the
/// twilight sky, floating islands and cloud sea every screen shares. The
/// world runs on one shared clock, so moving between screens never makes it
/// jump.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [const UtopiaWorld(), child]);
  }
}
