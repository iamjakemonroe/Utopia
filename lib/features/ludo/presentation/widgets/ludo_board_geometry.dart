import 'dart:math' as math;
import 'dart:ui';

import '../../domain/ludo_engine.dart';

/// Where everything sits on a Ludo board, in "cell" units around the
/// board's center (x right, y down).
///
/// Both boards are built the same way: one 3-cell-wide, 6-cell-long arm
/// per seat, radiating from a central home. The classic board's four arms
/// make the familiar cross (and reproduce the 15x15 grid exactly); the
/// six-arm board makes a star. Each arm carries 13 ring squares (out along
/// one side, across the tip, back in along the other) and its seat's
/// private home stretch up the middle. Each seat's yard sits in the gap
/// between its arm and the next one clockwise.
class LudoGeometry {
  LudoGeometry._(this.rules) {
    _build();
  }

  static final _cache = <LudoBoardKind, LudoGeometry>{};

  factory LudoGeometry.of(LudoBoardKind kind) =>
      _cache.putIfAbsent(kind, () => LudoGeometry._(LudoBoardRules.of(kind)));

  final LudoBoardRules rules;

  int get arms => rules.seats.length;

  /// Distance from the center to where the arms start: the apothem of the
  /// central polygon whose sides are the arms' 3-cell-wide bases.
  double get innerRadius => 3 / (2 * math.tan(math.pi / arms));

  double get outerRadius => innerRadius + 6;

  /// Direction the given seat's arm points (seat 0 points left).
  double armAngle(int seat) => math.pi + seat * 2 * math.pi / arms;

  /// Direction of the given seat's yard: halfway to the next arm clockwise.
  double yardAngle(int seat) => armAngle(seat) + math.pi / arms;

  Offset _dir(double a) => Offset(math.cos(a), math.sin(a));

  /// Arm [seat]'s cell [u] across (-1, 0, +1; +1 is the clockwise side) and
  /// [v] along (0 by the center, 5 at the tip).
  Offset armCell(int seat, int u, int v) {
    final a = armAngle(seat);
    final d = _dir(a);
    final p = Offset(-math.sin(a), math.cos(a));
    return d * (innerRadius + v + 0.5) + p * u.toDouble();
  }

  late final List<Offset> ring;

  /// Which arm each ring square lies on (for orienting its tile).
  late final List<int> ringArm;
  late final Map<LudoColor, List<Offset>> stretch;
  late final Map<LudoColor, List<Offset>> yardSlots;
  late final Map<LudoColor, Offset> yardCenter;
  late final List<Offset> outline;

  void _build() {
    ring = [
      for (var s = 0; s < arms; s++) ...[
        // In along this arm's clockwise side, from the seat's start square...
        for (var k = 0; k < 5; k++) armCell(s, 1, 4 - k),
        // ...out along the next arm's other side, across its tip, and onto
        // the first square of its clockwise side.
        for (var v = 0; v < 6; v++) armCell((s + 1) % arms, -1, v),
        armCell((s + 1) % arms, 0, 5),
        armCell((s + 1) % arms, 1, 5),
      ],
    ];

    ringArm = [
      for (var s = 0; s < arms; s++) ...[
        for (var k = 0; k < 5; k++) s,
        for (var k = 0; k < 8; k++) (s + 1) % arms,
      ],
    ];

    stretch = {
      for (final color in rules.seats)
        color: [
          for (var v = 4; v >= 0; v--) armCell(rules.seatOf(color), 0, v),
        ],
    };

    yardCenter = {};
    yardSlots = {};
    for (final color in rules.seats) {
      final s = rules.seatOf(color);
      final a = yardAngle(s);
      final d = _dir(a);
      final p = Offset(-math.sin(a), math.cos(a));
      if (rules.kind == LudoBoardKind.classic) {
        // A neat 2x2 square, aligned with the board.
        final c = d * (4.5 * math.sqrt2);
        final ax = _dir(armAngle(s));
        final ay = _dir(armAngle(s) + math.pi / 2);
        yardCenter[color] = c;
        yardSlots[color] = [
          c - ax * 1.15 - ay * 1.15,
          c - ax * 1.15 + ay * 1.15,
          c + ax * 1.15 - ay * 1.15,
          c + ax * 1.15 + ay * 1.15,
        ];
      } else {
        // A diamond that fits the wedge between two arms.
        final c = d * 6.9;
        yardCenter[color] = c;
        yardSlots[color] = [
          c - d * 1.0,
          c - p * 0.95,
          c + p * 0.95,
          c + d * 1.0,
        ];
      }
    }

    if (rules.kind == LudoBoardKind.classic) {
      outline = const [
        Offset(-7.5, -7.5),
        Offset(7.5, -7.5),
        Offset(7.5, 7.5),
        Offset(-7.5, 7.5),
      ];
    } else {
      final vertex = outerRadius / math.cos(math.pi / arms);
      outline = [for (var s = 0; s < arms; s++) _dir(yardAngle(s)) * vertex];
    }
  }

  /// The region a seat's yard fills: the gap between its arm and the next
  /// one clockwise, out to the board's edge.
  List<Offset> yardRegion(int seat) {
    final next = (seat + 1) % arms;
    final a = armAngle(seat);
    final b = armAngle(next);
    final pa = Offset(-math.sin(a), math.cos(a));
    final pb = Offset(-math.sin(b), math.cos(b));
    final bisector = _dir(yardAngle(seat));
    // Where the two arms' facing edges meet, near the center.
    final inner = bisector * (1.5 / math.sin(math.pi / arms));
    return [
      inner,
      _dir(a) * outerRadius + pa * 1.5,
      bisector * (outerRadius / math.cos(math.pi / arms)),
      _dir(b) * outerRadius - pb * 1.5,
    ];
  }

  /// The corners of the central home polygon.
  List<Offset> get centerPolygon => [
    for (var s = 0; s < arms; s++)
      _dir(yardAngle(s)) * (1.5 / math.sin(math.pi / arms)),
  ];

  /// Where a finished token rests: inside its color's slice of the center.
  Offset homeSlot(LudoColor color, int tokenIndex) {
    final a = armAngle(rules.seatOf(color));
    final d = _dir(a);
    final p = Offset(-math.sin(a), math.cos(a));
    const fan = [-0.42, 0.42, -0.14, 0.14];
    return d * (innerRadius * 0.48 + (tokenIndex < 2 ? 0 : 0.42)) +
        p * fan[tokenIndex % 4];
  }

  /// The resting spot for a token at [position] on its color's path.
  Offset positionOf(LudoColor color, int tokenIndex, int position) {
    if (position == kLudoBase) return yardSlots[color]![tokenIndex];
    if (position >= rules.finish) return homeSlot(color, tokenIndex);
    if (rules.isOnRing(position)) {
      return ring[rules.absoluteSquare(color, position)];
    }
    return stretch[color]![position - rules.ringLast - 1];
  }

  /// Every spot a token passes through (excluding where it starts) moving
  /// from [from] to [to], for step-by-step hop animations.
  List<Offset> path(LudoColor color, int tokenIndex, int from, int to) {
    if (to == kLudoBase) return [yardSlots[color]![tokenIndex]];
    if (from == kLudoBase) return [positionOf(color, tokenIndex, 0)];
    if (to <= from) return [positionOf(color, tokenIndex, to)];
    return [
      for (var p = from + 1; p <= to; p++) positionOf(color, tokenIndex, p),
    ];
  }

  /// Rotation that puts [me]'s yard at the bottom-left, so every player
  /// sees their own corner in the same place.
  double viewRotation(LudoColor? me) {
    final seat = me == null ? 0 : math.max(0, rules.seatOf(me));
    final target = rules.kind == LudoBoardKind.classic
        ? 3 * math.pi / 4
        : 5 * math.pi / 6;
    return target - yardAngle(seat);
  }

  /// Half the width and height the board needs once rotated by [rotation].
  Size halfExtent(double rotation) {
    var maxX = 0.0;
    var maxY = 0.0;
    for (final v in outline) {
      final r = rotate(v, rotation);
      maxX = math.max(maxX, r.dx.abs());
      maxY = math.max(maxY, r.dy.abs());
    }
    return Size(maxX, maxY);
  }

  static Offset rotate(Offset p, double a) {
    final c = math.cos(a);
    final s = math.sin(a);
    return Offset(p.dx * c - p.dy * s, p.dx * s + p.dy * c);
  }
}
