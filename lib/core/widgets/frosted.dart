import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Frosted glass: [child] (its own see-through tint) over a blur of what's
/// behind it. A browser has to blur everything behind again every frame,
/// one of the dearest things it draws, so there it's the plain see-through
/// tint; the apps keep the frost.
class Frosted extends StatelessWidget {
  const Frosted({super.key, required this.sigma, required this.child});

  final double sigma;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || sigma <= 0) return child;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: child,
    );
  }
}
