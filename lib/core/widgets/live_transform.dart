import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A [Transform] that follows [listenable] as it changes, without being
/// built again: [transform] is asked for the matrix each time it notifies.
///
/// An AnimatedBuilder around a Transform builds it again every frame, and
/// Flutter lays out the nearest LayoutBuilder above whatever's built again
/// (often a whole screen's; see FrameIsland). Moving it here costs only
/// the move.
class LiveTransform extends SingleChildRenderObjectWidget {
  const LiveTransform({
    super.key,
    required this.listenable,
    required this.transform,
    this.alignment = Alignment.center,
    super.child,
  });

  final Listenable listenable;
  final Matrix4 Function() transform;
  final AlignmentGeometry alignment;

  @override
  RenderLiveTransform createRenderObject(BuildContext context) =>
      RenderLiveTransform(
        listenable: listenable,
        compute: transform,
        alignment: alignment,
        textDirection: Directionality.maybeOf(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderLiveTransform renderObject,
  ) {
    renderObject
      ..alignment = alignment
      ..textDirection = Directionality.maybeOf(context)
      ..follow(listenable, transform);
  }
}

class RenderLiveTransform extends RenderTransform {
  RenderLiveTransform({
    required this._listenable,
    required Matrix4 Function() compute,
    super.alignment,
    super.textDirection,
  }) : _compute = compute,
       super(transform: compute());

  Listenable _listenable;
  Matrix4 Function() _compute;

  /// Follows [listenable], asking [compute] for the matrix.
  void follow(Listenable listenable, Matrix4 Function() compute) {
    _compute = compute;
    if (!identical(listenable, _listenable)) {
      if (attached) _listenable.removeListener(_update);
      _listenable = listenable;
      if (attached) _listenable.addListener(_update);
    }
    _update();
  }

  void _update() => transform = _compute();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _listenable.addListener(_update);
    _update();
  }

  @override
  void detach() {
    _listenable.removeListener(_update);
    super.detach();
  }
}
