import 'package:flutter/widgets.dart';

import 'live_transform.dart';

/// [child] fading in while it rises [distance] into place, over [duration],
/// the last part of it from [start] (0 to 1) on.
///
/// Drawn differently each frame rather than built again (see
/// LiveTransform): a screen of things arriving at once (a list's rows)
/// laid the whole screen out again every frame they moved.
class Arrive extends StatefulWidget {
  const Arrive({
    super.key,
    required this.child,
    required this.duration,
    this.start = 0,
    this.distance = 16,
    this.rise = Curves.easeOutCubic,
    this.fade = Curves.linear,
  });

  final Widget child;
  final Duration duration;

  /// When in [duration] it begins, 0 to 1.
  final double start;
  final double distance;

  /// How it rises, and how it fades in.
  final Curve rise;
  final Curve fade;

  @override
  State<Arrive> createState() => _ArriveState();
}

class _ArriveState extends State<Arrive> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: Interval(widget.start, 1, curve: widget.fade),
  );

  late final Animation<double> _rise = CurvedAnimation(
    parent: _controller,
    curve: Interval(widget.start, 1, curve: widget.rise),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: LiveTransform(
        listenable: _rise,
        transform: () => Matrix4.translationValues(
          0,
          widget.distance * (1 - _rise.value),
          0,
        ),
        // What arrives is drawn once; only where it is changes.
        child: RepaintBoundary(child: widget.child),
      ),
    );
  }
}
