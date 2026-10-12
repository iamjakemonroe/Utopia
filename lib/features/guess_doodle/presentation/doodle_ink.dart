import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../doodle_studio/domain/art_doc.dart';
import '../../doodle_studio/presentation/art_render.dart';
import '../domain/doodle_game.dart';

/// A stroke on its way: the drawer's, as they draw it, or one arriving
/// from the drawer, played back smoothly as its points come in.
class LiveStroke {
  LiveStroke({required this.tool, required this.color, required this.size});

  final ArtTool tool;
  final int color;
  final double size;

  /// x, y, width per point (page units).
  final List<double> points = [];

  /// How many points are showing (playback catches up with [points]).
  double shown = 0;

  /// The drawer lifted their finger: this is the stroke as saved.
  StrokeOp? done;

  int get length => points.length ~/ 3;

  StrokeOp visible() {
    final n = math.min(length, shown.ceil());
    return StrokeOp(
      tool: tool,
      color: color,
      size: size,
      points: points.sublist(0, math.max(1, n) * 3),
    );
  }
}

/// The canvas everyone in a game sees: the finished strokes for this turn
/// (kept as pictures by [ArtRender]) and the stroke being drawn right now.
/// [rev] counts the changes seen (strokes, undos, clears) to match against
/// the game's canvas_rev, which says when this copy has fallen behind.
class DoodleInk extends ChangeNotifier {
  DoodleInk() {
    render = ArtRender(_doc, size: kDoodleGameSize);
  }

  final _doc = ArtDoc(
    id: 'guess-my-doodle',
    kind: ArtKind.sketch,
    created: DateTime.now(),
    updated: DateTime.now(),
  );
  late final ArtRender render;

  int turn = -1;
  int epoch = 0;
  int rev = 0;

  /// The drawer's own stroke changed (it's drawn straight from [mine]).
  void changed() => notifyListeners();

  /// Strokes arriving from the drawer, by the drawer's stroke number.
  final Map<int, LiveStroke> incoming = {};

  /// The drawer's own stroke while their finger's down.
  LiveStroke? mine;

  bool get isEmpty => _doc.ops.isEmpty && incoming.isEmpty && mine == null;
  bool get canUndo => _doc.ops.isNotEmpty;

  /// Still playing back strokes that came in.
  bool get animating =>
      incoming.values.any((s) => s.shown < s.length || s.done != null);

  /// A new turn (or a cleared canvas): nothing on it.
  void reset({required int turn, required int epoch, int rev = 0}) {
    this.turn = turn;
    this.epoch = epoch;
    this.rev = rev;
    incoming.clear();
    mine = null;
    _doc.ops.clear();
    _doc.redo.clear();
    render.update();
    notifyListeners();
  }

  /// The canvas exactly as saved on the server.
  void replaceAll(List<StrokeOp> ops, {required int rev}) {
    this.rev = rev;
    incoming.clear();
    _doc.ops
      ..clear()
      ..addAll(ops);
    render.update();
    notifyListeners();
  }

  void add(StrokeOp op) {
    _doc.add(op);
    render.update();
    notifyListeners();
  }

  StrokeOp? undo() {
    _finishIncoming();
    final op = _doc.undo();
    _doc.redo.clear();
    render.update();
    notifyListeners();
    return op as StrokeOp?;
  }

  void clear({required int epoch}) {
    this.epoch = epoch;
    incoming.clear();
    _doc.ops.clear();
    render.update();
    notifyListeners();
  }

  // ── strokes from the drawer ──────────────────────────────────────────────

  /// Points of stroke [sid] from index [from] on (in points).
  void receivePoints({
    required int sid,
    required ArtTool tool,
    required int color,
    required double size,
    required int from,
    required List<double> values,
  }) {
    final stroke = incoming.putIfAbsent(
      sid,
      () => LiveStroke(tool: tool, color: color, size: size),
    );
    // Only the next points in order; a gap waits for the finished stroke.
    if (from != stroke.length || stroke.done != null) return;
    stroke.points.addAll(values);
    notifyListeners();
  }

  /// Stroke [sid] is finished: it's added once its playback catches up.
  void receiveDone(int sid, StrokeOp op) {
    final stroke = incoming.putIfAbsent(
      sid,
      () => LiveStroke(tool: op.tool, color: op.color, size: op.size),
    );
    stroke.points
      ..clear()
      ..addAll(op.points);
    stroke.done = op;
    rev++;
    notifyListeners();
  }

  /// Moves playback on by [dt] seconds: a stroke catches up with its points
  /// in about a tenth of a second, however many arrive at once.
  void advance(double dt) {
    if (incoming.isEmpty) return;
    var changed = false;
    for (final stroke in incoming.values) {
      final behind = stroke.length - stroke.shown;
      if (behind > 0) {
        stroke.shown += math.max(1.0, behind * math.min(1.0, dt * 14));
        if (stroke.shown > stroke.length) {
          stroke.shown = stroke.length.toDouble();
        }
        changed = true;
      }
    }
    final keys = incoming.keys.toList()..sort();
    for (final sid in keys) {
      final stroke = incoming[sid]!;
      final done = stroke.done;
      if (done == null || stroke.shown < stroke.length) break;
      incoming.remove(sid);
      _doc.add(done);
      changed = true;
    }
    if (changed) {
      render.update();
      notifyListeners();
    }
  }

  /// Puts every finished incoming stroke down now, in order.
  void _finishIncoming() {
    final keys = incoming.keys.toList()..sort();
    for (final sid in keys) {
      final done = incoming[sid]!.done;
      if (done == null) continue;
      incoming.remove(sid);
      _doc.add(done);
    }
  }

  /// The strokes still being drawn, to paint over the finished ones.
  Iterable<StrokeOp> get liveStrokes sync* {
    for (final s in incoming.values) {
      if (s.length > 0 && s.shown > 0) yield s.visible();
    }
    final m = mine;
    if (m != null && m.length > 0) {
      yield StrokeOp(
        tool: m.tool,
        color: m.color,
        size: m.size,
        points: List.of(m.points),
      );
    }
  }

  @override
  void dispose() {
    render.dispose();
    super.dispose();
  }
}
