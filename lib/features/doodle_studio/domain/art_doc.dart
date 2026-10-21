import 'dart:ui';

/// Every piece of art is drawn on a page this size (in page units), so it
/// looks the same on any phone and at any zoom.
const kPageSize = Size(1000, 1300);

/// A blank page to draw on, or a picture to color in.
enum ArtKind { sketch, coloring }

/// What's in the player's hand.
enum ArtTool {
  /// Thin and soft, a little see-through, like graphite.
  pencil,

  /// Ink that swells when you slow down and thins when you flick.
  pen,

  /// Bold, flat and solid.
  marker,

  /// A wide airbrush with soft edges.
  soft,

  /// See-through and flat-ended, for glazing over color.
  highlighter,

  /// Takes paint away (never the paper or a picture's outlines).
  eraser,

  /// Fills a whole shape of a coloring page in one tap.
  bucket,
}

/// One change to a piece of art, in the order it was made.
sealed class ArtOp {
  const ArtOp();

  Map<String, Object?> toJson();

  static ArtOp? fromJson(Map<String, Object?> json) => switch (json['t']) {
    's' => StrokeOp.fromJson(json),
    'f' => FillOp.fromJson(json),
    'F' => FillsOp.fromJson(json),
    'b' => SpillOp.fromJson(json),
    _ => null,
  };
}

/// A line drawn with a brush (or the eraser).
class StrokeOp extends ArtOp {
  const StrokeOp({
    required this.tool,
    required this.color,
    required this.size,
    required this.points,
  });

  final ArtTool tool;

  /// ARGB.
  final int color;

  /// The brush's size, in page units.
  final double size;

  /// x, y and width (page units) for each point along the line.
  final List<double> points;

  int get length => points.length ~/ 3;

  @override
  Map<String, Object?> toJson() => {
    't': 's',
    'tool': tool.name,
    'c': color,
    'w': _round(size),
    'p': [for (final v in points) _round(v)],
  };

  static StrokeOp? fromJson(Map<String, Object?> json) {
    final tool = ArtTool.values
        .where((t) => t.name == json['tool'])
        .firstOrNull;
    final points = json['p'];
    if (tool == null || tool == ArtTool.bucket || points is! List) return null;
    final values = [for (final v in points) (v as num).toDouble()];
    if (values.length < 3 || values.length % 3 != 0) return null;
    return StrokeOp(
      tool: tool,
      color: (json['c'] as num?)?.toInt() ?? 0xFF1F1E1B,
      size: (json['w'] as num?)?.toDouble() ?? 8,
      points: values,
    );
  }
}

/// Paint poured where a freehand drawing was tapped, filling the shape
/// there (Guess My Doodle's bucket; see SpillGrid).
class SpillOp extends ArtOp {
  const SpillOp({required this.x, required this.y, required this.color});

  /// Where it was poured, in page units.
  final double x;
  final double y;

  /// ARGB.
  final int color;

  @override
  Map<String, Object?> toJson() => {
    't': 'b',
    'x': _round(x),
    'y': _round(y),
    'c': color,
  };

  static SpillOp? fromJson(Map<String, Object?> json) {
    final x = (json['x'] as num?)?.toDouble();
    final y = (json['y'] as num?)?.toDouble();
    final color = (json['c'] as num?)?.toInt();
    if (x == null || y == null || color == null) return null;
    return SpillOp(x: x, y: y, color: color);
  }
}

/// A shape of a coloring page filled in one color.
class FillOp extends ArtOp {
  const FillOp({required this.region, required this.color});

  /// Which shape (see RegionMap).
  final int region;

  /// ARGB; fully clear empties the shape again.
  final int color;

  @override
  Map<String, Object?> toJson() => {'t': 'f', 'r': region, 'c': color};

  static FillOp? fromJson(Map<String, Object?> json) {
    final region = (json['r'] as num?)?.toInt();
    final color = (json['c'] as num?)?.toInt();
    if (region == null || color == null) return null;
    return FillOp(region: region, color: color);
  }
}

/// Many shapes filled at once (Chip coloring the page): one step, so one
/// undo takes it all back.
class FillsOp extends ArtOp {
  const FillsOp(this.fills);

  /// Shape (see RegionMap) to ARGB color.
  final Map<int, int> fills;

  @override
  Map<String, Object?> toJson() => {
    't': 'F',
    'f': [
      for (final e in fills.entries) [e.key, e.value],
    ],
  };

  static FillsOp? fromJson(Map<String, Object?> json) {
    final list = json['f'];
    if (list is! List) return null;
    final fills = <int, int>{};
    for (final pair in list) {
      if (pair is List &&
          pair.length == 2 &&
          pair[0] is num &&
          pair[1] is num) {
        fills[(pair[0] as num).toInt()] = (pair[1] as num).toInt();
      }
    }
    return fills.isEmpty ? null : FillsOp(fills);
  }
}

double _round(double v) => (v * 10).roundToDouble() / 10;

/// A sketch or coloring page and everything done to it. [ops] is the
/// history in order; [redo] holds what was undone, newest last, until
/// something new is drawn.
class ArtDoc {
  ArtDoc({
    required this.id,
    required this.kind,
    required this.created,
    required this.updated,
    this.pageId,
    List<ArtOp>? ops,
  }) : ops = ops ?? [];

  /// A fresh blank page, or a fresh copy of coloring page [pageId].
  factory ArtDoc.blank(ArtKind kind, {String? pageId, DateTime? now}) {
    final at = now ?? DateTime.now();
    return ArtDoc(
      id: 'art-${at.microsecondsSinceEpoch}',
      kind: kind,
      pageId: pageId,
      created: at,
      updated: at,
    );
  }

  final String id;
  final ArtKind kind;

  /// The coloring page this is (null for a sketch).
  final String? pageId;
  final DateTime created;
  DateTime updated;
  final List<ArtOp> ops;
  final List<ArtOp> redo = [];

  bool get isEmpty => ops.isEmpty;
  bool get canUndo => ops.isNotEmpty;
  bool get canRedo => redo.isNotEmpty;

  /// Something new: it goes on the end, and what was undone is gone.
  void add(ArtOp op) {
    ops.add(op);
    redo.clear();
    updated = DateTime.now();
  }

  ArtOp? undo() {
    if (ops.isEmpty) return null;
    final op = ops.removeLast();
    redo.add(op);
    updated = DateTime.now();
    return op;
  }

  ArtOp? redoLast() {
    if (redo.isEmpty) return null;
    final op = redo.removeLast();
    ops.add(op);
    updated = DateTime.now();
    return op;
  }

  /// The color each shape of a coloring page ends up, from the fills in
  /// order (a later fill of the same shape wins).
  Map<int, int> get fills => {
    for (final op in ops)
      if (op is FillOp) op.region: op.color else if (op is FillsOp) ...op.fills,
  };

  Map<String, Object?> toJson() => {
    'v': 1,
    'id': id,
    'kind': kind.name,
    'page': pageId,
    'created': created.toIso8601String(),
    'updated': updated.toIso8601String(),
    'ops': [for (final op in ops) op.toJson()],
  };

  static ArtDoc? fromJson(Map<String, Object?> json) {
    final id = json['id'] as String?;
    final kind = ArtKind.values
        .where((k) => k.name == json['kind'])
        .firstOrNull;
    if (id == null || kind == null) return null;
    final created = DateTime.tryParse(json['created'] as String? ?? '');
    final updated = DateTime.tryParse(json['updated'] as String? ?? '');
    return ArtDoc(
      id: id,
      kind: kind,
      pageId: json['page'] as String?,
      created: created ?? DateTime.now(),
      updated: updated ?? created ?? DateTime.now(),
      ops: [
        for (final raw in (json['ops'] as List? ?? const []))
          if (raw is Map) ?ArtOp.fromJson(raw.cast<String, Object?>()),
      ],
    );
  }
}
