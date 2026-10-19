import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/game_audio.dart';

/// Hands out when each readout comes up, as it comes into view: after
/// the hologram is up, and a beat after the one before (so a screenful
/// comes up one after another, and one scrolled to comes up at once).
class ReadoutReveals extends ChangeNotifier {
  /// Time on the frame clock (what the animations draw by).
  static int get _ms =>
      SchedulerBinding.instance.currentFrameTimeStamp.inMilliseconds;

  final int _opened = _ms;

  /// The soonest the next readout may start, in ms since the hologram
  /// opened.
  int _next = 450;

  static const beat = 90;

  /// When a readout that's just come into view starts, in ms from now.
  int claim() {
    final now = _ms - _opened;
    final at = math.max(now, _next);
    _next = at + beat;
    return at - now;
  }

  /// The list scrolled: readouts look whether they're in view now.
  void look() => notifyListeners();
}

/// Whether the readout around it has come up yet (what [Grow] waits for).
class RevealScope extends InheritedWidget {
  const RevealScope({super.key, required this.started, required super.child});

  final ValueListenable<bool> started;

  static ValueListenable<bool>? of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<RevealScope>()?.started;

  @override
  bool updateShouldNotify(RevealScope old) => old.started != started;
}

/// A readout that materializes when it comes into view (a third of it,
/// or 60 points), with a data blip as it does, in time with its turn
/// ([ReadoutReveals]). Nothing comes up, or sounds, once the hologram has
/// gone.
class RevealOnView extends ConsumerStatefulWidget {
  const RevealOnView({
    super.key,
    required this.index,
    required this.reveals,
    required this.child,
  });

  final int index;
  final ReadoutReveals reveals;
  final Widget child;

  @override
  ConsumerState<RevealOnView> createState() => _RevealOnViewState();
}

class _RevealOnViewState extends ConsumerState<RevealOnView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _show = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  final _started = ValueNotifier(false);
  bool _claimed = false;
  Timer? _wait;

  @override
  void initState() {
    super.initState();
    widget.reveals.addListener(_look);
    WidgetsBinding.instance.addPostFrameCallback((_) => _look());
  }

  @override
  void dispose() {
    widget.reveals.removeListener(_look);
    _wait?.cancel();
    _show.dispose();
    _started.dispose();
    super.dispose();
  }

  /// In view now? Then it takes its turn.
  void _look() {
    if (_claimed || !mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    final view =
        Scrollable.maybeOf(context)?.context.findRenderObject() as RenderBox?;
    if (box == null || view == null || !box.attached || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero, ancestor: view).dy;
    final shown =
        math.min(top + box.size.height, view.size.height) - math.max(top, 0);
    if (shown < math.min(60, box.size.height / 3)) return;
    _claimed = true;
    _wait = Timer(Duration(milliseconds: widget.reveals.claim()), _start);
  }

  void _start() {
    if (!mounted) return;
    _started.value = true;
    _show.forward();
    ref.read(gameAudioProvider).play(Sfx.holoBlip(widget.index), volume: 0.6);
  }

  @override
  Widget build(BuildContext context) {
    return RevealScope(
      started: _started,
      child: AnimatedBuilder(
        animation: _show,
        builder: (context, child) {
          final p = _show.value;
          // A flicker as it comes on, like a projection catching.
          final flicker = p > 0 && p < 1 && (p * 10).floor().isOdd ? 0.55 : 1.0;
          return Opacity(
            opacity: p * flicker,
            child: Transform.translate(
              offset: Offset(0, 10 * (1 - p)),
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// A value growing from 0 to [to] once its readout comes up (eased: quick,
/// then settling), shown by [builder]. With [ticks], a counter ticks
/// that many times along the way, close together while it races and
/// further apart as it settles; silent once it stops.
class Grow extends ConsumerStatefulWidget {
  const Grow({
    super.key,
    required this.to,
    required this.duration,
    required this.builder,
    this.ticks = 0,
    this.tickVolume = 0.4,
  });

  final double to;
  final Duration duration;
  final Widget Function(BuildContext context, double value) builder;
  final int ticks;
  final double tickVolume;

  @override
  ConsumerState<Grow> createState() => _GrowState();
}

class _GrowState extends ConsumerState<Grow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _grow = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..addListener(_tick);
  ValueListenable<bool>? _started;
  double _from = 0;
  int _ticked = 0;

  /// The frame clock at the last tick (ticks are never closer than a
  /// counter could go).
  Duration _lastTick = Duration.zero;

  double get _value =>
      _from + (widget.to - _from) * Curves.easeOutCubic.transform(_grow.value);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final started = RevealScope.of(context);
    if (started == _started) return;
    _started?.removeListener(_go);
    _started = started?..addListener(_go);
    _go();
  }

  /// Starts with its readout (at once, outside one).
  void _go() {
    final started = _started;
    if ((started == null || started.value) && _grow.isDismissed) {
      _grow.forward();
    }
  }

  @override
  void didUpdateWidget(covariant Grow old) {
    super.didUpdateWidget(old);
    if (old.to != widget.to && !_grow.isDismissed) {
      _from = _value;
      _ticked = 0;
      _grow.forward(from: 0);
    }
  }

  void _tick() {
    setState(() {});
    if (widget.ticks <= 0 || !_grow.isAnimating) return;
    final at = (Curves.easeOutCubic.transform(_grow.value) * widget.ticks)
        .floor();
    final now = SchedulerBinding.instance.currentFrameTimeStamp;
    if (at > _ticked && now - _lastTick > const Duration(milliseconds: 34)) {
      _ticked = at;
      _lastTick = now;
      ref.read(gameAudioProvider).play(Sfx.holoTick, volume: widget.tickVolume);
    }
  }

  @override
  void dispose() {
    _started?.removeListener(_go);
    _grow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _value);
}
