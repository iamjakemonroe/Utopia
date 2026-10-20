import 'package:flutter/widgets.dart';

/// Something built again every frame (Chip, a pulsing button, a spinning
/// die), kept to itself: a layer of its own, so drawing it doesn't draw
/// what's around it again, and a layout of its own at [size].
///
/// Flutter lays out the nearest LayoutBuilder above whatever is built
/// again, and a screen often has one around everything (see LayoutIsland):
/// a pulse anywhere on it laid the whole screen out, and drew it again,
/// every frame. Here that LayoutBuilder is this one, at a fixed size, so
/// it goes no further. What it shows may draw outside [size] (a glow, a
/// scale-up); only its layout is fixed.
class FrameIsland extends StatelessWidget {
  const FrameIsland({super.key, required this.size, required this.child});

  final Size size;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox.fromSize(
    size: size,
    child: RepaintBoundary(
      child: LayoutBuilder(builder: (context, _) => child),
    ),
  );
}
