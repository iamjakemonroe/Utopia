import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Wraps [child] in a real 3D perspective transform that tilts toward
/// wherever the user is pressing, and springs back to flat on release —
/// actual `Matrix4` rotation + perspective (`setEntry(3, 2, ...)`), not a
/// drop-shadow pretending to have depth. Use on hero cards/buttons where
/// the extra weight is worth it; not meant for every widget on screen.
class Tilt3D extends StatefulWidget {
  const Tilt3D({
    super.key,
    required this.child,
    this.maxTiltRadians = 0.12,
    this.perspective = 0.0016,
    this.scaleOnPress = 1.02,
  });

  final Widget child;
  final double maxTiltRadians;
  final double perspective;
  final double scaleOnPress;

  @override
  State<Tilt3D> createState() => _Tilt3DState();
}

class _Tilt3DState extends State<Tilt3D> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  Offset _target = Offset.zero; // -1..1 in each axis
  Offset _current = Offset.zero;
  Size _lastSize = Size.zero;

  void _updateFromLocalPosition(Offset local, Size size) {
    _lastSize = size;
    final dx = ((local.dx / size.width) * 2 - 1).clamp(-1.0, 1.0);
    final dy = ((local.dy / size.height) * 2 - 1).clamp(-1.0, 1.0);
    setState(() => _target = Offset(dx, dy));
    _controller
      ..value = 0
      ..forward();
  }

  void _reset() {
    setState(() => _target = Offset.zero);
    _controller
      ..value = 0
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanDown: (d) => _updateFromLocalPosition(d.localPosition, _lastSize),
      onPanUpdate: (d) => _updateFromLocalPosition(d.localPosition, _lastSize),
      onPanEnd: (_) => _reset(),
      onPanCancel: _reset,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _lastSize = constraints.biggest;
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              _current = Offset.lerp(
                _current,
                _target,
                Curves.easeOut.transform(_controller.value),
              )!;
              final rotateY = _current.dx * widget.maxTiltRadians;
              final rotateX = -_current.dy * widget.maxTiltRadians;
              final pressed = _target != Offset.zero;
              final scale = pressed ? widget.scaleOnPress : 1.0;

              final matrix = Matrix4.identity()
                ..setEntry(3, 2, widget.perspective)
                ..rotateX(rotateX)
                ..rotateY(rotateY)
                ..scaleByDouble(scale, scale, 1, 1);

              return Transform(
                alignment: Alignment.center,
                transform: matrix,
                child: child,
              );
            },
            child: widget.child,
          );
        },
      ),
    );
  }
}

/// A gentle, non-interactive 3D tilt for elements that should always read
/// as "sitting at an angle in space" (e.g. a hero mascot) rather than
/// reacting to touch — a slow continuous sway on both axes.
class AmbientTilt3D extends StatefulWidget {
  const AmbientTilt3D({super.key, required this.child, this.amount = 0.08});

  final Widget child;
  final double amount;

  @override
  State<AmbientTilt3D> createState() => _AmbientTilt3DState();
}

class _AmbientTilt3DState extends State<AmbientTilt3D>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Its own layer, and what it tilts in another: turning every frame,
    // only the turn is drawn again, not what it's on or what it holds.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value * 2 * math.pi;
          final matrix = Matrix4.identity()
            ..setEntry(3, 2, 0.0014)
            ..rotateX(math.sin(t) * widget.amount * 0.5)
            ..rotateY(math.sin(t * 0.7) * widget.amount);
          return Transform(
            alignment: Alignment.center,
            transform: matrix,
            child: child,
          );
        },
        child: RepaintBoundary(child: widget.child),
      ),
    );
  }
}
