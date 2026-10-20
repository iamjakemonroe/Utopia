import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/utopia_themes.dart';
import 'soft_band.dart';
import 'sprite_cache.dart';
import 'world_sets.dart';

/// Stable pseudo-random 0-1 from an index.
double _rand(int i, int salt) {
  final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

Color _a(Color c, double alpha) =>
    c.withValues(alpha: (c.a * alpha).clamp(0.0, 1.0));

const _ink = Color(0xFF070D24);
const _snow = Color(0xFFF2F6FF);
const _snowLit = Color(0xFFDCE6FA);
const _snowShade = Color(0xFF8A9CC8);
const _warm = Color(0xFFFFC66A);
const _ember = Color(0xFFFF8A3D);
const _pine = Color(0xFF17463A);
const _pineDark = Color(0xFF0B2620);
const _red = Color(0xFFD7263D);
const _gold = Color(0xFFFFD447);
const _wood = Color(0xFF6B4026);
const _woodDark = Color(0xFF3E2414);
const _bulbs = [
  Color(0xFFFF4D5E),
  Color(0xFFFFD447),
  Color(0xFF4DD8FF),
  Color(0xFF7DFF8A),
  Color(0xFFFF8AE0),
];

/// When things happen in the Winter world, shared by its painter and its
/// sounds (world_soundscape.dart), so the sleigh bells ring as Santa
/// crosses the moon and the wind howls with the gusts. [cheer] is the
/// set's amount.
abstract final class WinterTimeline {
  /// Santa's sleigh sets off across the sky at every multiple of this, and
  /// takes [sleighCrossing] seconds to cross.
  static double sleighPeriod(double cheer) => 24 - 12 * cheer;
  static const sleighCrossing = 7.5;

  /// Where the sleigh is across the screen (0 left edge, 1 right) [s]
  /// seconds into a crossing: in from off the left, out off the right
  /// (the reindeer go first).
  static double sleighAcross(double s) => -0.45 + 1.75 * (s / sleighCrossing);

  /// The moon's place across the screen (see the world's moon anchor).
  static const moonAcross = 0.72;

  /// How far the wind has blown the snow sideways by [t], in screen
  /// widths: a steady breeze with gusts that come and go (and now and then
  /// a moment's lull when it eddies back).
  static double drift(double t) =>
      0.012 * t + 0.05 * math.sin(t * 0.21) + 0.02 * math.sin(t * 0.57 + 1);

  /// How hard the wind is blowing at [t], 0 (a lull) to 1 (a gust).
  static double gust(double t) {
    final speed =
        0.012 +
        0.05 * 0.21 * math.cos(t * 0.21) +
        0.02 * 0.57 * math.cos(t * 0.57 + 1);
    return ((speed + 0.0094) / 0.0434).clamp(0.0, 1.0);
  }

  /// New Year's Eve from six in the evening to the end of New Year's Day,
  /// by the player's own clock: fireworks over the mountains.
  static bool newYear(DateTime now) =>
      (now.month == 12 && now.day == 31 && now.hour >= 18) ||
      (now.month == 1 && now.day == 1);

  /// The fireworks' bursts: each of [fireworks] goes off every
  /// [fireworkPeriod] of its own, [fireworkClimb] of the way through.
  static const fireworks = 3;
  static double fireworkPeriod(int i) => 3.4 + _rand(i, 720) * 2.4;
  static double fireworkShift(int i) => _rand(i, 721) * fireworkPeriod(i);
  static const fireworkClimb = 0.22;
}

/// Winter: a snowy night by a frozen lake. The northern lights ripple over
/// snow-capped mountains, snow falls in drifts the wind blows about, smoke
/// curls from a log cabin's chimney, its windows lit with firelight, a
/// Christmas tree twinkles by the shore, a snowman keeps watch, someone
/// skates figure-eights on the ice, and now and then Santa's sleigh
/// crosses the moon, Rudolph's nose glowing out in front. On New Year's
/// Eve, there are fireworks.
///
/// With the set on (the Snow Globe worn here, [WorldSets.winter]) it's
/// Christmas Eve: the sleigh comes round twice as often, the tree's lights
/// chase, its star blazes, the lights burn brighter, big snowflakes drift
/// past and the snowman waves.
///
/// In a browser, [dpr] is the screen's pixels a point: the mountains, the
/// land, the cabin, the tree and the snowman are kept as pixels (see
/// [SpriteCache]). [newYear] overrides the clock (for previews).
void paintWinterScene(
  Canvas canvas,
  Size size,
  double t,
  WorldStyle style, {
  required Offset moon,
  double? dpr,
  bool? newYear,
}) {
  final w = size.width;
  final h = size.height;
  final cheer = WorldSets.winter.amount;
  final scene = _Layout(size);

  if (cheer > 0) _curtain(canvas, size, t, cheer, dpr);
  if (newYear ?? WinterTimeline.newYear(DateTime.now())) {
    _fireworks(canvas, size, t);
  }
  _sleigh(canvas, size, moon, t, cheer);

  _still(
    canvas,
    dpr,
    ('winter far', w, h),
    Rect.fromLTRB(0, h * 0.3, w, h * 0.76),
    (canvas) => _far(canvas, size),
  );
  _snowfall(canvas, size, t, cheer, 0);
  _still(
    canvas,
    dpr,
    ('winter land', w, h),
    Rect.fromLTRB(0, h * 0.66, w, h),
    (canvas) => _land(canvas, size, scene),
  );
  _lakeLight(canvas, scene, t, moon);
  _skater(canvas, scene, t);
  _lampLight(canvas, scene, t, cheer);

  final u = scene.cabinSize;
  final cabin = scene.cabin;
  _smoke(canvas, scene, t);
  _still(
    canvas,
    dpr,
    ('winter cabin', u),
    Rect.fromLTRB(-u * 0.8, -u * 1.2, u * 0.8, u * 0.16).shift(cabin),
    (canvas) => _cabin(canvas, cabin, u),
  );
  _cabinLight(canvas, scene, t, cheer);

  final tree = scene.tree;
  final th = scene.treeHeight;
  _still(
    canvas,
    dpr,
    ('winter tree', th),
    Rect.fromLTRB(-th * 0.5, -th * 1.02, th * 0.5, th * 0.08).shift(tree),
    (canvas) => _tree(canvas, tree, th),
  );
  _treeLights(canvas, tree, th, t, cheer);

  final man = scene.snowman;
  final sh = scene.snowmanHeight;
  _still(
    canvas,
    dpr,
    ('winter snowman', sh),
    Rect.fromLTRB(-sh * 0.7, -sh * 1.25, sh * 0.5, sh * 0.06).shift(man),
    (canvas) => _snowman(canvas, man, sh),
  );
  _snowmanArm(canvas, man, sh, t, cheer);

  _snowfall(canvas, size, t, cheer, 1);
  // The night pressing in at the edges.
  final rect = Offset.zero & size;
  canvas.drawRect(
    rect,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.15),
        radius: 0.95,
        colors: [Colors.transparent, _a(_ink, 0.5)],
        stops: const [0.55, 1],
      ).createShader(rect),
  );
  _snowfall(canvas, size, t, cheer, 2);
  if (cheer > 0) _crystals(canvas, size, t, cheer, dpr);
}

/// Where everything stands, from the screen's size.
class _Layout {
  _Layout(this.size)
    : cabinSize = math.min(size.width * 0.3, size.height * 0.16),
      treeHeight = math.min(size.height * 0.26, size.width * 0.55),
      snowmanHeight = math.min(size.height * 0.12, size.width * 0.24);

  final Size size;
  final double cabinSize;
  final double treeHeight;
  final double snowmanHeight;

  double get w => size.width;
  double get h => size.height;

  /// The middle of the cabin's floor.
  Offset get cabin => Offset(w * 0.2, h * 0.815);
  Offset get tree => Offset(w * 0.77, h * 0.875);
  Offset get snowman => Offset(w * 0.52, h * 0.94);
  Offset get lamp => Offset(w * 0.42, h * 0.8);
  double get lampHeight => h * 0.085;

  /// The frozen lake: an oval across the middle.
  Rect get lake => Rect.fromCenter(
    center: Offset(w * 0.6, h * 0.772),
    width: w * 0.8,
    height: h * 0.064,
  );
}

/// Draws what [paint] draws: in a browser ([dpr]) kept as pixels.
void _still(
  Canvas canvas,
  double? dpr,
  Object key,
  Rect bounds,
  void Function(Canvas canvas) paint,
) {
  if (dpr == null) {
    paint(canvas);
    return;
  }
  worldSprites.draw(
    canvas,
    key,
    bounds: bounds,
    dpr: dpr,
    absolute: true,
    paint: paint,
  );
}

// ── The sky ───────────────────────────────────────────────────────────────

/// With the set on, a bright green curtain of the northern lights across
/// the stars.
void _curtain(Canvas canvas, Size size, double t, double cheer, double? dpr) {
  const steps = 28;
  final baseY = size.height * 0.23;
  final amp = size.height * 0.03;
  final height = size.height * 0.16;
  final lower = <Offset>[];
  final upper = <Offset>[];
  for (var s = 0; s <= steps; s++) {
    final u = s / steps;
    final y =
        baseY +
        amp * math.sin(u * 4 + t * 0.3) +
        amp * 0.5 * math.sin(u * 9 - t * 0.5);
    final curtain = height * (0.55 + 0.45 * math.sin(u * 6 + t * 0.4 + 1));
    lower.add(Offset(size.width * u, y));
    upper.add(Offset(size.width * u, y - curtain));
  }
  const glow = Color(0xFF5CFFB0);
  final paint = Paint()
    ..shader = ui.Gradient.linear(
      Offset(0, baseY + amp * 1.5),
      Offset(0, baseY - amp - height),
      [_a(glow, 0.32 * cheer), _a(const Color(0xFF8A6BFF), 0)],
    );
  if (dpr != null) {
    canvas.drawVertices(softBand(lower, upper, dpr), BlendMode.modulate, paint);
  } else {
    canvas.drawPath(
      Path()..addPolygon([...lower, ...upper.reversed], true),
      paint,
    );
  }
  canvas.drawPath(
    Path()..addPolygon(lower, false),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = _a(glow, 0.5 * cheer),
  );
}

/// Fireworks over the mountains (New Year's Eve): each climbs on a trail,
/// bursts into a ring of sparks that droop and twinkle out, and goes again
/// somewhere new.
void _fireworks(Canvas canvas, Size size, double t) {
  const colors = [
    Color(0xFFFFD447),
    Color(0xFFE8F0FF),
    Color(0xFF7FD8FF),
    Color(0xFFFF7AB8),
    Color(0xFF9DFFB0),
  ];
  final w = size.width;
  final h = size.height;
  for (var i = 0; i < WinterTimeline.fireworks; i++) {
    final period = WinterTimeline.fireworkPeriod(i);
    final shift = WinterTimeline.fireworkShift(i);
    final local = (t + shift) % period / period;
    final round = ((t + shift) / period).floor();
    final x = w * (0.12 + 0.76 * _rand(round * 7 + i, 722));
    final top = h * (0.16 + 0.2 * _rand(round * 7 + i, 723));
    final color = colors[(round + i) % colors.length];
    final launch = Offset(x + (_rand(round + i, 724) - 0.5) * w * 0.1, h * 0.6);
    const climb = WinterTimeline.fireworkClimb;
    if (local < climb) {
      final k = Curves.easeOut.transform(local / climb);
      final p = Offset.lerp(launch, Offset(x, top), k)!;
      canvas.drawLine(
        Offset.lerp(launch, Offset(x, top), (k - 0.12).clamp(0.0, 1.0))!,
        p,
        Paint()
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(
            colors: [_a(color, 0), _a(Colors.white, 0.9)],
          ).createShader(Rect.fromPoints(launch, p)),
      );
      canvas.drawCircle(p, 2.2, Paint()..color = Colors.white);
      continue;
    }
    final k = (local - climb) / (1 - climb);
    final spread =
        Curves.easeOut.transform(k) * w * (0.11 + 0.06 * _rand(i, 725));
    final fade = 1 - k * k;
    final droop = k * k * h * 0.05;
    if (k < 0.3) {
      final flash = 1 - k / 0.3;
      final glow = Rect.fromCircle(
        center: Offset(x, top),
        radius: spread * 0.9 + 16,
      );
      canvas.drawOval(
        glow,
        Paint()
          ..shader = RadialGradient(
            colors: [_a(color, 0.4 * flash), _a(color, 0)],
          ).createShader(glow),
      );
      canvas.drawCircle(Offset(x, top), 5 * flash, Paint()..color = _snow);
    }
    final sparks = 22 + (i % 3) * 6;
    for (var s = 0; s < sparks; s++) {
      final a = s / sparks * math.pi * 2 + round * 0.4;
      final r = spread * (0.75 + 0.25 * _rand(s + i * 40, 726));
      final p = Offset(x + math.cos(a) * r, top + math.sin(a) * r + droop);
      final tail = Offset(
        x + math.cos(a) * r * 0.82,
        top + math.sin(a) * r * 0.82 + droop * 0.85,
      );
      final twinkle = 0.7 + 0.3 * math.sin(t * 30 + s * 2.1);
      final spark = s.isEven ? color : Color.lerp(color, Colors.white, 0.6)!;
      canvas.drawLine(
        tail,
        p,
        Paint()
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..color = _a(spark, fade * twinkle),
      );
    }
  }
}

/// Santa's sleigh: four reindeer at a gallop (Rudolph out in front, his
/// nose glowing), the sleigh behind with Santa waving and his
/// sack of presents, a trail of gold sparkles behind it all.
void _sleigh(Canvas canvas, Size size, Offset moon, double t, double cheer) {
  final period = WinterTimeline.sleighPeriod(cheer);
  final s = t % period;
  if (s > WinterTimeline.sleighCrossing) return;
  final w = size.width;
  final h = size.height;
  final k = math.min(w * 0.014, h * 0.012);

  Offset at(double s) {
    final across = WinterTimeline.sleighAcross(s);
    return Offset(
      across * w,
      moon.dy +
          h * 0.012 -
          (across - WinterTimeline.moonAcross) * h * 0.09 +
          math.sin(s * 2.2) * k * 0.5,
    );
  }

  final sled = at(s);
  // The sparkles it leaves.
  for (var j = 1; j <= 16; j++) {
    final back = s - j * 0.09;
    if (back < 0) break;
    final p = at(back).translate(-k * 3.2, k * 0.6);
    final fade = 1 - j / 17;
    final twinkle = 0.5 + 0.5 * math.sin(t * 18 + j * 1.7);
    canvas.drawCircle(
      p.translate(0, math.sin(j * 1.3) * k * 0.5),
      k * (0.12 + 0.22 * fade),
      Paint()..color = _a(_gold, fade * (0.4 + 0.6 * twinkle)),
    );
  }

  // The team, in front of the sleigh, rising and falling at a gallop.
  final ahead = at(s + 0.35);
  final tilt = math.atan2(ahead.dy - sled.dy, ahead.dx - sled.dx);
  canvas.save();
  canvas.translate(sled.dx, sled.dy);
  canvas.rotate(tilt);
  final reins = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(0.8, k * 0.12)
    ..color = _a(const Color(0xFFE8C88A), 0.8);
  for (var i = 0; i < 4; i++) {
    final p = Offset(
      k * (7.5 + i * 4.6),
      -k * 1.2 + math.sin(t * 9 + i) * k * 0.3,
    );
    canvas.drawLine(Offset(k * 2.4, -k * 1.4), p.translate(-k * 1.2, 0), reins);
    _reindeer(canvas, p, k, t * 9 + i * 1.3, rudolph: i == 3);
  }
  _sled(canvas, k, t, s);
  canvas.restore();
}

/// One reindeer facing right, its body's middle at [p], legs stretched in
/// a flying gallop ([beat]); Rudolph's nose glows.
void _reindeer(
  Canvas canvas,
  Offset p,
  double k,
  double beat, {
  required bool rudolph,
}) {
  const coat = Color(0xFF7A5230);
  const belly = Color(0xFFB08A5A);
  final leg = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = k * 0.42
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFF5A3A20);
  final swing = math.sin(beat) * 0.45;
  for (final (x, base, sign) in const [
    (1.0, 0.7, 1.0),
    (0.7, 0.9, 1.0),
    (-1.0, -0.7, -1.0),
    (-0.7, -0.9, -1.0),
  ]) {
    final a = math.pi / 2 - base - swing * sign;
    final top = p.translate(x * k, k * 0.35);
    final knee = top + Offset(math.cos(a), math.sin(a)) * k * 0.9;
    final hoof =
        knee +
        Offset(math.cos(a - sign * 0.6), math.sin(a - sign * 0.6)) * k * 0.7;
    canvas.drawLine(top, knee, leg);
    canvas.drawLine(knee, hoof, leg);
  }
  // A white tuft of a tail.
  canvas.drawCircle(
    p.translate(-k * 1.7, -k * 0.35),
    k * 0.3,
    Paint()..color = _snow,
  );
  canvas.drawOval(
    Rect.fromCenter(center: p, width: k * 3.4, height: k * 1.45),
    Paint()..color = coat,
  );
  canvas.drawOval(
    Rect.fromCenter(
      center: p.translate(0, k * 0.32),
      width: k * 2.4,
      height: k * 0.6,
    ),
    Paint()..color = belly,
  );
  // The harness and its bell.
  canvas.drawLine(
    p.translate(k * 0.9, -k * 0.65),
    p.translate(k * 1.1, k * 0.55),
    Paint()
      ..strokeWidth = k * 0.28
      ..color = _red,
  );
  canvas.drawCircle(
    p.translate(k * 1.15, k * 0.6),
    k * 0.22,
    Paint()..color = _gold,
  );
  // Neck and head.
  canvas.drawLine(
    p.translate(k * 1.1, -k * 0.3),
    p.translate(k * 1.85, -k * 1.15),
    Paint()
      ..strokeWidth = k * 0.85
      ..strokeCap = StrokeCap.round
      ..color = coat,
  );
  final head = p.translate(k * 2.15, -k * 1.3);
  canvas.drawOval(
    Rect.fromCenter(center: head, width: k * 1.35, height: k * 0.8),
    Paint()..color = coat,
  );
  canvas.drawCircle(
    head.translate(-k * 0.05, -k * 0.12),
    k * 0.08,
    Paint()..color = _ink,
  );
  // Antlers.
  final antler = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = k * 0.2
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFFD8B888);
  final root = head.translate(-k * 0.3, -k * 0.35);
  for (final side in const [-1.0, 1.0]) {
    final tip = root.translate(side * k * 0.5 - k * 0.3, -k * 1.2);
    canvas.drawLine(root, tip, antler);
    canvas.drawLine(
      Offset.lerp(root, tip, 0.5)!,
      Offset.lerp(
        root,
        tip,
        0.5,
      )!.translate(side * k * 0.45 + k * 0.1, -k * 0.35),
      antler,
    );
  }
  final nose = head.translate(k * 0.7, k * 0.05);
  if (rudolph) {
    final glow = Rect.fromCircle(center: nose, radius: k * 1.3);
    canvas.drawOval(
      glow,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _a(const Color(0xFFFF3A3A), 0.55 + 0.2 * math.sin(beat * 0.4)),
            _a(const Color(0xFFFF3A3A), 0),
          ],
        ).createShader(glow),
    );
    canvas.drawCircle(nose, k * 0.3, Paint()..color = const Color(0xFFFF4040));
    canvas.drawCircle(
      nose.translate(-k * 0.08, -k * 0.1),
      k * 0.1,
      Paint()..color = Colors.white,
    );
  } else {
    canvas.drawCircle(nose, k * 0.2, Paint()..color = const Color(0xFF2A1A10));
  }
}

/// The sleigh, its front at the origin facing right: red with gold trim,
/// on curled runners, Santa in it with his sack. He waves as he passes the
/// moon.
void _sled(Canvas canvas, double k, double t, double s) {
  // The sack behind him, presents peeking out.
  for (final (dx, dy, c) in const [
    (-2.6, -2.9, Color(0xFF4DD8FF)),
    (-1.8, -3.2, Color(0xFF7DFF8A)),
  ]) {
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(dx * k, dy * k),
        width: k * 0.9,
        height: k * 0.9,
      ),
      Paint()..color = c,
    );
  }
  canvas.drawCircle(
    Offset(-k * 2.2, -k * 2.1),
    k * 1.15,
    Paint()..color = const Color(0xFF8A5A3A),
  );
  // Santa.
  final body = Offset(-k * 0.5, -k * 2.0);
  canvas.drawCircle(body, k * 1.05, Paint()..color = _red);
  canvas.drawLine(
    body.translate(-k * 0.9, k * 0.3),
    body.translate(k * 0.9, k * 0.3),
    Paint()
      ..strokeWidth = k * 0.3
      ..color = _ink,
  );
  final head = body.translate(k * 0.2, -k * 1.35);
  canvas.drawCircle(head, k * 0.5, Paint()..color = const Color(0xFFF2C6A0));
  canvas.drawCircle(
    head.translate(k * 0.05, k * 0.45),
    k * 0.55,
    Paint()..color = _snow,
  );
  canvas.drawPath(
    Path()
      ..moveTo(head.dx - k * 0.55, head.dy - k * 0.2)
      ..quadraticBezierTo(
        head.dx - k * 0.2,
        head.dy - k * 1.3,
        head.dx - k * 1.2,
        head.dy - k * 0.7,
      )
      ..lineTo(head.dx + k * 0.55, head.dy - k * 0.2)
      ..close(),
    Paint()..color = _red,
  );
  canvas.drawLine(
    head.translate(-k * 0.6, -k * 0.2),
    head.translate(k * 0.6, -k * 0.2),
    Paint()
      ..strokeWidth = k * 0.3
      ..strokeCap = StrokeCap.round
      ..color = _snow,
  );
  canvas.drawCircle(
    head.translate(-k * 1.2, -k * 0.7),
    k * 0.25,
    Paint()..color = _snow,
  );
  // His arm: waving while he's over the middle of the sky.
  final across = WinterTimeline.sleighAcross(s);
  final waving = across > 0.35 && across < 0.95;
  final shoulder = body.translate(k * 0.5, -k * 0.5);
  final hand = waving
      ? shoulder.translate(k * (0.6 + 0.35 * math.sin(t * 10)), -k * 1.3)
      : shoulder.translate(k * 1.2, k * 0.2);
  canvas.drawLine(
    shoulder,
    hand,
    Paint()
      ..strokeWidth = k * 0.45
      ..strokeCap = StrokeCap.round
      ..color = _red,
  );
  canvas.drawCircle(hand, k * 0.28, Paint()..color = _snow);
  // The sleigh.
  final shell = Path()
    ..moveTo(-k * 3.4, -k * 0.2)
    ..quadraticBezierTo(-k * 3.9, -k * 2.4, -k * 3.0, -k * 2.7)
    ..quadraticBezierTo(-k * 2.5, -k * 2.8, -k * 2.7, -k * 2.2)
    ..quadraticBezierTo(-k * 1.0, -k * 1.3, k * 1.6, -k * 1.4)
    ..quadraticBezierTo(k * 2.6, -k * 1.5, k * 2.4, -k * 0.7)
    ..quadraticBezierTo(k * 2.0, -k * 0.1, k * 1.0, 0)
    ..close();
  canvas.drawPath(shell, Paint()..color = const Color(0xFFB81E30));
  canvas.drawPath(
    shell,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = k * 0.22
      ..color = _gold,
  );
  final runner = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = k * 0.25
    ..strokeCap = StrokeCap.round
    ..color = _gold;
  canvas.drawLine(Offset(-k * 2.2, 0), Offset(-k * 2.2, k * 0.7), runner);
  canvas.drawLine(Offset(k * 0.8, 0), Offset(k * 0.8, k * 0.7), runner);
  canvas.drawPath(
    Path()
      ..moveTo(-k * 3.4, k * 0.7)
      ..lineTo(k * 2.6, k * 0.7)
      ..quadraticBezierTo(k * 3.6, k * 0.7, k * 3.4, -k * 0.2),
    runner,
  );
}

// ── The land ──────────────────────────────────────────────────────────────

/// The far mountains, snow on their peaks, and the forested hills below
/// them.
void _far(Canvas canvas, Size size) {
  final w = size.width;
  final h = size.height;
  for (final (base, low, high, peaks, body, salt, dim) in [
    // More peaks across a wider screen, so they keep their shape.
    (
      h * 0.64,
      h * 0.41,
      h * 0.5,
      (w / 70).clamp(6, 12).round(),
      const Color(0xFF2A3866),
      0,
      1.0,
    ),
    (
      h * 0.69,
      h * 0.5,
      h * 0.58,
      (w / 85).clamp(5, 10).round(),
      const Color(0xFF1C2850),
      10,
      0.85,
    ),
  ]) {
    final step = w * 1.1 / peaks;
    final points = <Offset>[Offset(-w * 0.05, base)];
    final tops = <Offset>[];
    for (var i = 0; i < peaks; i++) {
      final x =
          -w * 0.05 +
          step * (i + 0.5) +
          (_rand(i, 700 + salt) - 0.5) * step * 0.4;
      final top = Offset(x, low + (high - low) * _rand(i, 701 + salt));
      final valley = Offset(
        x + step * (0.45 + 0.15 * _rand(i, 705 + salt)),
        top.dy + (base - top.dy) * (0.45 + 0.25 * _rand(i, 702 + salt)),
      );
      // A shoulder partway down each side, so no slope is a straight line.
      Offset shoulder(Offset from, Offset to, int k) =>
          Offset.lerp(from, to, 0.45 + 0.2 * _rand(i * 3 + k, 706 + salt))! +
          Offset(
            0,
            (_rand(i * 3 + k, 707 + salt) - 0.5) * (base - top.dy) * 0.1,
          );
      points
        ..add(shoulder(points.last, top, 0))
        ..add(top)
        ..add(shoulder(top, valley, 1))
        ..add(valley);
      tops.add(top);
    }
    points
      ..add(Offset(w * 1.05, base))
      ..add(Offset(w * 1.05, h * 0.76))
      ..add(Offset(-w * 0.05, h * 0.76));
    final range = Path()..addPolygon(points, true);
    canvas.drawPath(
      range,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, low), Offset(0, base), [
          body,
          Color.lerp(body, _ink, 0.35)!,
        ]),
    );
    canvas.save();
    canvas.clipPath(range);
    for (var i = 0; i < tops.length; i++) {
      final top = tops[i];
      final fall = base - top.dy;
      // The face away from the moon (the left) in shadow.
      canvas.drawPath(
        Path()..addPolygon([
          top,
          Offset(top.dx - step * 0.75, base),
          Offset(top.dx + fall * 0.12, base),
        ], true),
        Paint()..color = _a(_ink, 0.22),
      );
      // Snow down from the peak to a ragged line, streaking down the
      // gullies; the clip keeps it on the mountain.
      final drop = fall * (0.3 + 0.12 * _rand(i, 703 + salt));
      final edge = <Offset>[];
      for (var j = 0; j <= 10; j++) {
        final x = top.dx - step * 0.6 + step * 1.2 * j / 10;
        final streak = j.isEven
            ? 0.95 + 0.3 * _rand(i * 11 + j, 704 + salt)
            : 0.65 + 0.15 * _rand(i * 11 + j, 708 + salt);
        // Lower near the peak's middle, as it would lie.
        final middle = 1 - ((x - top.dx) / (step * 0.6)).abs() * 0.35;
        edge.add(Offset(x, top.dy + drop * streak * middle));
      }
      final ridge = Offset(top.dx - drop * 0.12, top.dy + drop * 0.75);
      final half = edge.indexWhere((p) => p.dx >= top.dx);
      canvas.drawPath(
        Path()..addPolygon([
          Offset(edge.first.dx, top.dy - 4),
          Offset(top.dx, top.dy - 4),
          top,
          ridge,
          ...edge.take(half).toList().reversed,
        ], true),
        Paint()..color = _a(_snowShade, 0.8 * dim),
      );
      canvas.drawPath(
        Path()..addPolygon([
          Offset(top.dx, top.dy - 4),
          Offset(edge.last.dx, top.dy - 4),
          ...edge.skip(half).toList().reversed,
          ridge,
          top,
        ], true),
        Paint()..color = _a(_snowLit, 0.92 * dim),
      );
    }
    canvas.restore();
  }

  // The snowy hills, a row of pines along them.
  final hills = Path()..moveTo(-w * 0.05, h * 0.7);
  for (var i = 0; i <= 6; i++) {
    final x = w * (i / 6);
    hills.quadraticBezierTo(
      x - w / 12,
      h * (0.655 + 0.02 * _rand(i, 710)),
      x,
      h * (0.68 + 0.012 * _rand(i, 711)),
    );
  }
  hills
    ..lineTo(w * 1.05, h * 0.76)
    ..lineTo(-w * 0.05, h * 0.76)
    ..close();
  canvas.drawPath(
    hills,
    Paint()
      ..shader = ui.Gradient.linear(Offset(0, h * 0.65), Offset(0, h * 0.74), [
        const Color(0xFF7A8EC0),
        const Color(0xFF55689C),
      ]),
  );
  final count = (w / 26).clamp(12, 40).round();
  for (var i = 0; i < count; i++) {
    final x = w * (i + _rand(i, 712) * 0.8) / count;
    final y = h * (0.672 + 0.025 * _rand(i, 713));
    final tall = h * (0.03 + 0.03 * _rand(i, 714));
    _pineTree(canvas, Offset(x, y), tall, Color.lerp(_pine, _ink, 0.45)!);
  }
}

/// A snow-laden pine: three tiers, each with snow along its top.
void _pineTree(Canvas canvas, Offset base, double tall, Color color) {
  final wide = tall * 0.55;
  canvas.drawRect(
    Rect.fromLTWH(
      base.dx - wide * 0.06,
      base.dy - tall * 0.12,
      wide * 0.12,
      tall * 0.14,
    ),
    Paint()..color = _woodDark,
  );
  for (var k = 0; k < 3; k++) {
    final bottom = base.dy - tall * (0.1 + k * 0.27);
    final top = bottom - tall * 0.42;
    final half = wide * (1 - k * 0.27) / 2;
    canvas.drawPath(
      Path()
        ..moveTo(base.dx - half, bottom)
        ..lineTo(base.dx, top)
        ..lineTo(base.dx + half, bottom)
        ..close(),
      Paint()..color = color,
    );
    canvas.drawPath(
      Path()
        ..moveTo(base.dx - half * 0.55, top + (bottom - top) * 0.55)
        ..lineTo(base.dx, top)
        ..lineTo(base.dx + half * 0.7, top + (bottom - top) * 0.62)
        ..lineTo(base.dx + half * 0.2, top + (bottom - top) * 0.5)
        ..lineTo(base.dx - half * 0.15, top + (bottom - top) * 0.6)
        ..close(),
      Paint()..color = _a(_snowLit, 0.92),
    );
  }
}

/// The snowfield, the frozen lake (with the northern lights faint in its
/// ice), footprints from the cabin door to the shore, the lamp post and
/// the drifts in front.
void _land(Canvas canvas, Size size, _Layout scene) {
  final w = size.width;
  final h = size.height;
  final field = Path()
    ..moveTo(0, h * 0.715)
    ..quadraticBezierTo(w * 0.5, h * 0.69, w, h * 0.71)
    ..lineTo(w, h)
    ..lineTo(0, h)
    ..close();
  canvas.drawPath(
    field,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, h * 0.7),
        Offset(0, h),
        const [Color(0xFF7084B8), Color(0xFFA9BAE2), Color(0xFFC6D3F0)],
        const [0, 0.5, 1],
      ),
  );

  // The lake: a snowy rim, then the ice.
  final lake = scene.lake;
  canvas.drawOval(
    lake.inflate(h * 0.006),
    Paint()..color = const Color(0xFFD2DDF5),
  );
  canvas.drawOval(
    lake,
    Paint()
      ..shader = ui.Gradient.linear(
        lake.topCenter,
        lake.bottomCenter,
        const [Color(0xFF2E4A7E), Color(0xFF4F76B0), Color(0xFF7FA4D8)],
        const [0, 0.55, 1],
      ),
  );
  canvas.save();
  canvas.clipPath(Path()..addOval(lake));
  // The aurora's green, faint in the ice.
  canvas.drawOval(
    Rect.fromCenter(
      center: lake.center.translate(-lake.width * 0.2, -lake.height * 0.15),
      width: lake.width * 0.7,
      height: lake.height * 0.5,
    ),
    Paint()
      ..shader =
          RadialGradient(
            colors: [const Color(0x3A5CFFB0), const Color(0x005CFFB0)],
          ).createShader(
            Rect.fromCenter(
              center: lake.center.translate(
                -lake.width * 0.2,
                -lake.height * 0.15,
              ),
              width: lake.width * 0.7,
              height: lake.height * 0.5,
            ),
          ),
  );
  // Skate scratches.
  final scratch = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8
    ..color = const Color(0x40E8F2FF);
  for (var i = 0; i < 7; i++) {
    final c = lake.center.translate(
      (_rand(i, 730) - 0.5) * lake.width * 0.6,
      (_rand(i, 731) - 0.5) * lake.height * 0.5,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: c,
        width: lake.width * (0.15 + 0.2 * _rand(i, 732)),
        height: lake.height * 0.4,
      ),
      _rand(i, 733) * math.pi,
      1.2 + _rand(i, 734),
      false,
      scratch,
    );
  }
  canvas.restore();

  // Footprints from the cabin door down to the shore.
  final door = scene.cabin.translate(
    -scene.cabinSize * 0.12,
    scene.cabinSize * 0.06,
  );
  final shore = Offset(lake.left + lake.width * 0.12, lake.bottom + h * 0.004);
  final step = Paint()..color = const Color(0x553A4C80);
  for (var i = 0; i < 9; i++) {
    final u = (i + 0.5) / 9;
    final p = Offset.lerp(door, shore, u)!.translate(
      math.sin(u * 5) * scene.cabinSize * 0.1 + (i.isEven ? -2.0 : 2.0),
      0,
    );
    canvas.drawOval(
      Rect.fromCenter(center: p, width: 3 + 2 * u, height: 1.6 + u),
      step,
    );
  }

  // The lamp post.
  final lamp = scene.lamp;
  final lh = scene.lampHeight;
  final iron = Paint()
    ..strokeWidth = math.max(1.5, lh * 0.05)
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFF141A30);
  canvas.drawLine(lamp, lamp.translate(0, -lh * 0.86), iron);
  canvas.drawLine(
    lamp.translate(-lh * 0.08, 0),
    lamp.translate(lh * 0.08, 0),
    iron..strokeWidth = math.max(2.5, lh * 0.08),
  );
  final head = Rect.fromCenter(
    center: lamp.translate(0, -lh * 0.93),
    width: lh * 0.2,
    height: lh * 0.18,
  );
  canvas.drawRect(head, Paint()..color = const Color(0xFFFFE2A0));
  canvas.drawRect(
    head,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, lh * 0.03)
      ..color = const Color(0xFF141A30),
  );
  canvas.drawPath(
    Path()
      ..moveTo(head.left - lh * 0.04, head.top)
      ..lineTo(head.center.dx, head.top - lh * 0.09)
      ..lineTo(head.right + lh * 0.04, head.top)
      ..close(),
    Paint()..color = const Color(0xFF141A30),
  );
  canvas.drawOval(
    Rect.fromCenter(
      center: head.topCenter.translate(0, -lh * 0.06),
      width: lh * 0.24,
      height: lh * 0.06,
    ),
    Paint()..color = _snow,
  );

  // Drifts in front, lit along their crests.
  for (final (x, y, wide, tall) in [
    (0.08, 0.97, 0.5, 0.06),
    (0.62, 0.985, 0.7, 0.05),
    (1.0, 0.95, 0.45, 0.07),
  ]) {
    final drift = Rect.fromCenter(
      center: Offset(w * x, h * y),
      width: w * wide,
      height: h * tall * 2,
    );
    canvas.drawOval(
      drift,
      Paint()
        ..shader = ui.Gradient.linear(drift.topCenter, drift.center, const [
          Color(0xFFE6EEFF),
          Color(0xFFBCCAEC),
        ]),
    );
  }
}

/// The moon's light on the ice, shimmering, and a glint here and there.
void _lakeLight(Canvas canvas, _Layout scene, double t, Offset moon) {
  final lake = scene.lake;
  final x = moon.dx;
  final rx = lake.width / 2;
  final ry = lake.height / 2;
  final glint = Paint()..strokeCap = StrokeCap.round;
  for (var i = 0; i < 7; i++) {
    final u = (i + 0.5) / 7;
    final y = lake.top + lake.height * (0.12 + 0.8 * u);
    final dy = (y - lake.center.dy) / ry;
    final half = rx * math.sqrt(math.max(0, 1 - dy * dy));
    final width =
        lake.width *
        0.04 *
        (0.5 + u) *
        (0.6 + 0.4 * math.sin(t * 2.3 + i * 1.7));
    final left = math.max(lake.center.dx - half + 2, x - width);
    final right = math.min(lake.center.dx + half - 2, x + width);
    if (right <= left) continue;
    canvas.drawLine(
      Offset(left, y),
      Offset(right, y),
      glint
        ..strokeWidth = math.max(1, lake.height * 0.06)
        ..color = _a(
          const Color(0xFFE8F2FF),
          0.35 + 0.25 * math.sin(t * 3 + i),
        ),
    );
  }
  for (var i = 0; i < 5; i++) {
    final phase = (t * 0.4 + _rand(i, 740)) % 1.0;
    if (phase > 0.15) continue;
    final p = lake.center.translate(
      (_rand(i + (t * 0.4).floor() * 5, 741) - 0.5) * lake.width * 0.7,
      (_rand(i + (t * 0.4).floor() * 5, 742) - 0.5) * lake.height * 0.5,
    );
    final k = math.sin(phase / 0.15 * math.pi);
    final r = 3.0 * k;
    final white = Paint()
      ..strokeWidth = 1
      ..color = _a(Colors.white, k);
    canvas.drawLine(p.translate(-r, 0), p.translate(r, 0), white);
    canvas.drawLine(p.translate(0, -r), p.translate(0, r), white);
  }
}

/// Someone skating figure-eights on the ice, leaning into the turns, a
/// scarf flying behind.
void _skater(Canvas canvas, _Layout scene, double t) {
  final lake = scene.lake;
  Offset at(double t) {
    final a = t * 0.45;
    return lake.center.translate(
      math.sin(a) * lake.width * 0.28,
      math.sin(a * 2) * lake.height * 0.22,
    );
  }

  final p = at(t);
  final next = at(t + 0.1);
  final heading = next.dx - p.dx;
  final turn = (at(t + 0.2) - next).direction - (next - p).direction;
  final tall = scene.h * 0.032;
  // The trail cut in the ice behind.
  final trail = Path()..moveTo(p.dx, p.dy);
  for (var j = 1; j <= 8; j++) {
    final q = at(t - j * 0.12);
    trail.lineTo(q.dx, q.dy);
  }
  canvas.drawPath(
    trail,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x55E8F2FF),
  );
  canvas.save();
  canvas.translate(p.dx, p.dy);
  canvas.rotate((turn * 4).clamp(-0.3, 0.3));
  if (heading < 0) canvas.scale(-1, 1);
  final body = Paint()
    ..strokeWidth = tall * 0.2
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFF2A3050);
  final glide = math.sin(t * 3);
  canvas.drawLine(
    Offset(0, -tall * 0.45),
    Offset(-tall * 0.15 * glide, 0),
    body,
  );
  canvas.drawLine(
    Offset(0, -tall * 0.45),
    Offset(tall * 0.25, -tall * 0.05),
    body,
  );
  canvas.drawLine(
    Offset(tall * 0.1, -tall * 0.95),
    Offset(0, -tall * 0.45),
    body..strokeWidth = tall * 0.32,
  );
  canvas.drawLine(
    Offset(tall * 0.05, -tall * 0.8),
    Offset(tall * 0.35, -tall * 0.55 - glide * tall * 0.1),
    body..strokeWidth = tall * 0.14,
  );
  canvas.drawCircle(
    Offset(tall * 0.14, -tall * 1.15),
    tall * 0.15,
    Paint()..color = const Color(0xFFF2C6A0),
  );
  canvas.drawCircle(
    Offset(tall * 0.12, -tall * 1.25),
    tall * 0.13,
    Paint()..color = _red,
  );
  canvas.drawLine(
    Offset(tall * 0.08, -tall * 0.98),
    Offset(-tall * 0.35, -tall * (0.95 + 0.08 * math.sin(t * 8))),
    Paint()
      ..strokeWidth = tall * 0.09
      ..strokeCap = StrokeCap.round
      ..color = _red,
  );
  canvas.restore();
}

/// The lamp post's warm light, and the pool of it on the snow.
void _lampLight(Canvas canvas, _Layout scene, double t, double cheer) {
  final lh = scene.lampHeight;
  final light = scene.lamp.translate(0, -lh * 0.93);
  final glow = (0.85 + 0.15 * math.sin(t * 1.3)) * (1 + 0.3 * cheer);
  final halo = Rect.fromCircle(center: light, radius: lh * 0.7);
  canvas.drawOval(
    halo,
    Paint()
      ..shader = RadialGradient(
        colors: [_a(_warm, 0.45 * glow), _a(_warm, 0)],
      ).createShader(halo),
  );
  final pool = Rect.fromCenter(
    center: scene.lamp,
    width: lh * 1.4,
    height: lh * 0.3,
  );
  canvas.drawOval(
    pool,
    Paint()
      ..shader = RadialGradient(
        colors: [_a(_warm, 0.25 * glow), _a(_warm, 0)],
      ).createShader(pool),
  );
}

// ── The cabin ─────────────────────────────────────────────────────────────

/// The cabin's shape, [u] wide, its floor's middle at [c].
class _Cabin {
  _Cabin(this.c, this.u);

  final Offset c;
  final double u;

  Rect get wall =>
      Rect.fromLTRB(c.dx - u * 0.46, c.dy - u * 0.44, c.dx + u * 0.46, c.dy);
  Offset get ridge => Offset(c.dx, c.dy - u * 0.96);
  Offset get eaveL => Offset(c.dx - u * 0.62, c.dy - u * 0.38);
  Offset get eaveR => Offset(c.dx + u * 0.62, c.dy - u * 0.38);

  /// How deep the roof's boards are.
  double get fascia => u * 0.06;

  /// The point [k] of the way along the roof's lower edge, left eave to
  /// ridge to right eave.
  Offset under(double k) {
    final drop = Offset(0, fascia);
    return k < 0.5
        ? Offset.lerp(eaveL, ridge, k * 2)! + drop
        : Offset.lerp(ridge, eaveR, k * 2 - 1)! + drop;
  }

  Rect get chimney => Rect.fromLTRB(
    c.dx + u * 0.2,
    c.dy - u * 1.0,
    c.dx + u * 0.34,
    c.dy - u * 0.62,
  );

  Rect get door =>
      Rect.fromLTRB(c.dx - u * 0.24, c.dy - u * 0.34, c.dx - u * 0.07, c.dy);

  /// The window beside the door and the little one up in the gable.
  List<Rect> get windows => [
    Rect.fromLTRB(
      c.dx + u * 0.06,
      c.dy - u * 0.32,
      c.dx + u * 0.32,
      c.dy - u * 0.13,
    ),
    Rect.fromCenter(
      center: Offset(c.dx, c.dy - u * 0.62),
      width: u * 0.14,
      height: u * 0.12,
    ),
  ];
}

/// The log cabin, [u] wide, its floor's middle at [c]: log walls, a board
/// gable with a little window, a door with a wreath, a window full of
/// firelight, a roof deep in snow with icicles, a stone chimney.
void _cabin(Canvas canvas, Offset c, double u) {
  final cabin = _Cabin(c, u);
  final wall = cabin.wall;

  // The chimney, behind the roof.
  final chimney = cabin.chimney;
  canvas.drawRect(chimney, Paint()..color = const Color(0xFF5A5468));
  final stone = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(0.8, u * 0.008)
    ..color = const Color(0xFF3A3448);
  for (var row = 0; row < 4; row++) {
    final y = chimney.top + chimney.height * (row + 1) / 5;
    canvas.drawLine(Offset(chimney.left, y), Offset(chimney.right, y), stone);
  }
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTRB(
        chimney.left - u * 0.02,
        chimney.top - u * 0.05,
        chimney.right + u * 0.02,
        chimney.top + u * 0.02,
      ),
      Radius.circular(u * 0.03),
    ),
    Paint()..color = _snow,
  );

  // The gable: upright boards.
  final gable = Path()
    ..addPolygon([
      wall.topLeft,
      cabin.ridge + Offset(0, cabin.fascia),
      wall.topRight,
    ], true);
  canvas.drawPath(gable, Paint()..color = const Color(0xFF5A3420));
  canvas.save();
  canvas.clipPath(gable);
  final board = Paint()
    ..strokeWidth = math.max(0.8, u * 0.008)
    ..color = _woodDark;
  for (var i = 1; i < 9; i++) {
    final x = wall.left + wall.width * i / 9;
    canvas.drawLine(Offset(x, wall.top), Offset(x, cabin.ridge.dy), board);
  }
  canvas.restore();

  // Log walls.
  canvas.drawRect(wall, Paint()..color = _wood);
  const logs = 6;
  for (var i = 0; i < logs; i++) {
    final y = wall.top + wall.height * (i + 0.5) / logs;
    final thick = wall.height / logs;
    canvas.drawLine(
      Offset(wall.left - u * 0.03, y),
      Offset(wall.right + u * 0.03, y),
      Paint()
        ..strokeWidth = thick * 0.88
        ..strokeCap = StrokeCap.round
        ..color = Color.lerp(_wood, const Color(0xFF8A5634), _rand(i, 750))!,
    );
    canvas.drawLine(
      Offset(wall.left, y + thick * 0.4),
      Offset(wall.right, y + thick * 0.4),
      Paint()
        ..strokeWidth = math.max(0.8, thick * 0.12)
        ..color = _woodDark,
    );
    // Log ends at the corners.
    for (final x in [wall.left - u * 0.03, wall.right + u * 0.03]) {
      canvas.drawCircle(
        Offset(x, y),
        thick * 0.42,
        Paint()..color = const Color(0xFFC89A6A),
      );
      canvas.drawCircle(
        Offset(x, y),
        thick * 0.22,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.6, thick * 0.06)
          ..color = const Color(0xFF8A5634),
      );
    }
  }

  // The door, a wreath on it.
  final door = cabin.door;
  canvas.drawRRect(
    RRect.fromRectAndCorners(
      door,
      topLeft: Radius.circular(u * 0.06),
      topRight: Radius.circular(u * 0.06),
    ),
    Paint()..color = _woodDark,
  );
  canvas.drawCircle(
    door.center.translate(u * 0.05, u * 0.03),
    u * 0.012,
    Paint()..color = _gold,
  );
  final wreath = door.center.translate(0, -u * 0.07);
  canvas.drawCircle(
    wreath,
    u * 0.045,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 0.025
      ..color = const Color(0xFF2E7A4A),
  );
  for (var i = 0; i < 5; i++) {
    final a = i / 5 * 2 * math.pi;
    canvas.drawCircle(
      wreath + Offset(math.cos(a), math.sin(a)) * u * 0.045,
      u * 0.009,
      Paint()..color = _red,
    );
  }
  canvas.drawCircle(
    wreath.translate(0, u * 0.045),
    u * 0.014,
    Paint()..color = _red,
  );

  // The windows: warm with firelight (it flickers on top of this),
  // crossed by their frames, snow on their sills.
  for (final window in cabin.windows) {
    canvas.drawRect(window.inflate(u * 0.018), Paint()..color = _woodDark);
    canvas.drawRect(
      window,
      Paint()
        ..shader = ui.Gradient.linear(
          window.topCenter,
          window.bottomCenter,
          const [Color(0xFFFFD98A), Color(0xFFFF9A3D)],
        ),
    );
    final frame = Paint()
      ..strokeWidth = math.max(1, u * 0.014)
      ..color = _woodDark;
    canvas.drawLine(window.topCenter, window.bottomCenter, frame);
    canvas.drawLine(window.centerLeft, window.centerRight, frame);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          window.left - u * 0.03,
          window.bottom + u * 0.005,
          window.right + u * 0.03,
          window.bottom + u * 0.035,
        ),
        Radius.circular(u * 0.015),
      ),
      Paint()..color = _snow,
    );
  }

  // The roof: dark boards, a thick blanket of snow on top drooping over
  // their edge, icicles hanging from them.
  final ridge = cabin.ridge;
  final eaveL = cabin.eaveL;
  final eaveR = cabin.eaveR;
  final fascia = Offset(0, cabin.fascia);
  canvas.drawPath(
    Path()..addPolygon([
      eaveL,
      ridge,
      eaveR,
      eaveR + fascia,
      ridge + fascia,
      eaveL + fascia,
    ], true),
    Paint()..color = _woodDark,
  );
  final deep = u * 0.1;
  final snowRoof = Path()
    ..moveTo(eaveL.dx - u * 0.05, eaveL.dy + u * 0.02)
    ..quadraticBezierTo(
      eaveL.dx - u * 0.07,
      eaveL.dy - deep * 0.9,
      eaveL.dx + u * 0.06,
      eaveL.dy - deep,
    )
    ..lineTo(ridge.dx, ridge.dy - deep * 1.1)
    ..lineTo(eaveR.dx - u * 0.06, eaveR.dy - deep)
    ..quadraticBezierTo(
      eaveR.dx + u * 0.07,
      eaveR.dy - deep * 0.9,
      eaveR.dx + u * 0.05,
      eaveR.dy + u * 0.02,
    );
  // Its lower edge droops over the boards in soft lumps.
  const lumps = 10;
  for (var i = lumps - 1; i >= 0; i--) {
    final k = i / lumps;
    final from = cabin.under(k + 1 / lumps) - fascia;
    final to = cabin.under(k) - fascia;
    final droop = u * (0.025 + 0.025 * _rand(i, 751));
    final mid = Offset.lerp(from, to, 0.5)!;
    snowRoof.quadraticBezierTo(mid.dx, mid.dy + droop * 2, to.dx, to.dy);
  }
  snowRoof.close();
  canvas.drawPath(
    snowRoof,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(ridge.dx, ridge.dy - deep),
        Offset(ridge.dx, eaveL.dy + u * 0.03),
        const [Color(0xFFF4F8FF), Color(0xFFC8D4F0)],
      ),
  );
  // The left slope faces away from the moon.
  canvas.drawPath(
    Path()..addPolygon([
      Offset(ridge.dx, ridge.dy - deep * 1.1),
      Offset(eaveL.dx + u * 0.06, eaveL.dy - deep),
      Offset(eaveL.dx - u * 0.05, eaveL.dy + u * 0.02),
      Offset(ridge.dx, ridge.dy + u * 0.02),
    ], true),
    Paint()..color = const Color(0x2E6070A8),
  );
  final icicle = Paint()..color = const Color(0xDDE8F4FF);
  for (var i = 1; i < 16; i++) {
    final k = i / 16;
    if ((k - 0.5).abs() < 0.12) continue;
    final p = cabin.under(k);
    final long =
        u * (0.03 + 0.07 * _rand(i, 752)) * (0.4 + (k - 0.5).abs() * 1.2);
    canvas.drawPath(
      Path()
        ..moveTo(p.dx - u * 0.012, p.dy - 1)
        ..lineTo(p.dx, p.dy + long)
        ..lineTo(p.dx + u * 0.012, p.dy - 1)
        ..close(),
      icicle,
    );
  }
  // Snow banked against the walls.
  canvas.drawOval(
    Rect.fromCenter(
      center: c.translate(u * 0.25, 0),
      width: u * 0.7,
      height: u * 0.1,
    ),
    Paint()..color = const Color(0xFFD8E2F8),
  );
  canvas.drawOval(
    Rect.fromCenter(
      center: c.translate(-u * 0.42, u * 0.005),
      width: u * 0.4,
      height: u * 0.09,
    ),
    Paint()..color = const Color(0xFFD8E2F8),
  );
}

/// The firelight flickering in the cabin's windows and spilling onto the
/// snow, and the fairy lights strung along its eaves.
void _cabinLight(Canvas canvas, _Layout scene, double t, double cheer) {
  final c = scene.cabin;
  final u = scene.cabinSize;
  final cabin = _Cabin(c, u);
  final fire = 0.75 + 0.25 * math.sin(t * 7.3) * math.sin(t * 2.9 + 1);
  for (final window in cabin.windows) {
    canvas.drawRect(
      window,
      Paint()..color = _a(const Color(0xFFFFF0C0), 0.35 * fire),
    );
    final halo = window.inflate(u * 0.12);
    canvas.drawOval(
      halo,
      Paint()
        ..shader = RadialGradient(
          colors: [_a(_ember, 0.3 * fire), _a(_ember, 0)],
        ).createShader(halo),
    );
  }
  final spill = Rect.fromCenter(
    center: c.translate(u * 0.19, u * 0.1),
    width: u * 0.7,
    height: u * 0.16,
  );
  canvas.drawOval(
    spill,
    Paint()
      ..shader = RadialGradient(
        colors: [_a(_warm, 0.32 * fire), _a(_warm, 0)],
      ).createShader(spill),
  );

  // Fairy lights strung under the roof's edge, sagging between hooks.
  const bulbs = 15;
  final bright = 0.75 + 0.25 * cheer;
  for (var i = 0; i < bulbs; i++) {
    final k = (i + 0.5) / bulbs;
    final p = cabin
        .under(k)
        .translate(0, math.sin(k * math.pi * 6).abs() * u * 0.025 + u * 0.012);
    final color = _bulbs[i % _bulbs.length];
    final on = 0.55 + 0.45 * math.sin(t * 2.4 + i * 1.9);
    canvas.drawCircle(
      p,
      u * 0.035,
      Paint()..color = _a(color, 0.3 * on * bright),
    );
    canvas.drawCircle(
      p,
      u * 0.014,
      Paint()
        ..color = _a(Color.lerp(color, Colors.white, 0.4)!, 0.6 + 0.4 * on),
    );
  }
}

/// Smoke curling up from the chimney and drifting off on the wind.
void _smoke(Canvas canvas, _Layout scene, double t) {
  final u = scene.cabinSize;
  final top = scene.cabin.translate(u * 0.28, -u * 1.06);
  for (var i = 0; i < 6; i++) {
    final k = (t * 0.16 + i / 6) % 1.0;
    final p = top.translate(
      k * k * u * 0.9 + math.sin(t * 0.9 + i * 2) * u * 0.05 * k,
      -k * u * 1.1,
    );
    final puff = Rect.fromCircle(center: p, radius: u * (0.06 + 0.16 * k));
    canvas.drawOval(
      puff,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _a(
              const Color(0xFFC8D0E8),
              0.42 * math.sin(math.min(1.0, k * 1.15) * math.pi),
            ),
            _a(const Color(0xFFC8D0E8), 0),
          ],
        ).createShader(puff),
    );
  }
}

// ── The tree ──────────────────────────────────────────────────────────────

/// Where the tree's lights hang (as fractions of its height, across and
/// up from its foot), along the garlands.
final _treeBulbs = <Offset>[
  for (var tier = 0; tier < 4; tier++)
    for (var i = 0; i < 9 - tier * 2; i++)
      () {
        final u = (i + 0.5) / (9 - tier * 2);
        final bottom = 0.14 + tier * 0.2;
        final half = 0.36 * (1 - tier * 0.22);
        // Each garland sags across its tier, a little lower to the right.
        return Offset(
          (u - 0.5) * 2 * half * 0.86,
          -(bottom + 0.06 + 0.05 * u - 0.035 * math.sin(u * math.pi)),
        );
      }(),
];

/// The Christmas tree, [tall] high, its foot at [c]: four tiers of
/// branches with snow along them, a gold garland, baubles, presents
/// underneath. Its lights and star are drawn live over it.
void _tree(Canvas canvas, Offset c, double tall) {
  canvas.drawOval(
    Rect.fromCenter(center: c, width: tall * 0.8, height: tall * 0.08),
    Paint()..color = const Color(0x332A3A70),
  );
  canvas.drawRect(
    Rect.fromLTRB(
      c.dx - tall * 0.035,
      c.dy - tall * 0.12,
      c.dx + tall * 0.035,
      c.dy,
    ),
    Paint()..color = _woodDark,
  );
  for (var tier = 0; tier < 4; tier++) {
    final bottom = c.dy - tall * (0.08 + tier * 0.2);
    final top = c.dy - tall * (0.4 + tier * 0.19);
    final half = tall * 0.36 * (1 - tier * 0.22);
    final branches = Path()..moveTo(c.dx, top);
    branches.quadraticBezierTo(
      c.dx - half * 0.4,
      top + (bottom - top) * 0.5,
      c.dx - half,
      bottom,
    );
    // Drooping branch tips along the bottom.
    const tips = 5;
    for (var i = 1; i <= tips; i++) {
      final x = c.dx - half + 2 * half * i / tips;
      branches.quadraticBezierTo(
        x - half / tips,
        bottom - tall * 0.04,
        x,
        bottom + (i == tips ? 0 : tall * 0.012),
      );
    }
    branches
      ..quadraticBezierTo(
        c.dx + half * 0.4,
        top + (bottom - top) * 0.5,
        c.dx,
        top,
      )
      ..close();
    canvas.drawPath(
      branches,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(c.dx - half, top),
          Offset(c.dx + half, bottom),
          [const Color(0xFF1E5E46), _pine, _pineDark],
          const [0, 0.5, 1],
        ),
    );
    // Snow along the tier's upper edge, and resting on its tips.
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, top)
        ..quadraticBezierTo(
          c.dx + half * 0.35,
          top + (bottom - top) * 0.45,
          c.dx + half * 0.85,
          bottom - tall * 0.02,
        )
        ..quadraticBezierTo(
          c.dx + half * 0.4,
          top + (bottom - top) * 0.62,
          c.dx + half * 0.05,
          top + (bottom - top) * 0.3,
        )
        ..close(),
      Paint()..color = _a(_snowLit, 0.85),
    );
    for (var i = 1; i < tips; i++) {
      final x = c.dx - half + 2 * half * i / tips;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, bottom - tall * 0.012),
          width: tall * 0.045,
          height: tall * 0.022,
        ),
        Paint()..color = _snow,
      );
    }
  }
  // A gold garland swagged across each tier.
  final garland = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1, tall * 0.01)
    ..color = _a(_gold, 0.85);
  for (var tier = 0; tier < 3; tier++) {
    final y = c.dy - tall * (0.2 + tier * 0.2);
    final half = tall * 0.3 * (1 - tier * 0.25);
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - half, y - tall * 0.03)
        ..quadraticBezierTo(
          c.dx,
          y + tall * 0.05,
          c.dx + half,
          y - tall * 0.06,
        ),
      garland,
    );
  }
  // Baubles.
  for (var i = 0; i < 9; i++) {
    final tier = i % 3;
    final y = c.dy - tall * (0.16 + tier * 0.2 + 0.06 * _rand(i, 760));
    final half = tall * 0.26 * (1 - tier * 0.25);
    final p = Offset(c.dx + (_rand(i, 761) - 0.5) * 2 * half, y);
    final color = const [
      Color(0xFFE23A4E),
      Color(0xFFFFD447),
      Color(0xFF4DB8FF),
    ][i % 3];
    final r = tall * 0.022;
    canvas.drawCircle(
      p,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.4),
          colors: [
            Color.lerp(color, Colors.white, 0.6)!,
            color,
            Color.lerp(color, Colors.black, 0.4)!,
          ],
          stops: const [0, 0.4, 1],
        ).createShader(Rect.fromCircle(center: p, radius: r)),
    );
  }
  // Presents underneath.
  for (final (dx, wide, high, box, ribbon) in const [
    (-0.27, 0.13, 0.09, Color(0xFFE23A4E), Color(0xFFFFD447)),
    (-0.14, 0.09, 0.065, Color(0xFF4DB8FF), Color(0xFFF2F6FF)),
    (0.22, 0.12, 0.1, Color(0xFF3CB46E), Color(0xFFE23A4E)),
    (0.33, 0.08, 0.06, Color(0xFFB98CFF), Color(0xFFFFD447)),
  ]) {
    final rect = Rect.fromLTWH(
      c.dx + tall * dx - tall * wide / 2,
      c.dy - tall * high,
      tall * wide,
      tall * high,
    );
    canvas.drawRect(rect, Paint()..color = box);
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.top, rect.width * 0.32, rect.height),
      Paint()..color = _a(Colors.white, 0.12),
    );
    final band = Paint()
      ..strokeWidth = math.max(1.2, tall * 0.012)
      ..color = ribbon;
    canvas.drawLine(rect.topCenter, rect.bottomCenter, band);
    canvas.drawLine(rect.centerLeft, rect.centerRight, band);
    final bow = rect.topCenter;
    for (final side in const [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: bow.translate(side * tall * 0.016, -tall * 0.01),
          width: tall * 0.03,
          height: tall * 0.02,
        ),
        Paint()..color = ribbon,
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(
        rect.left,
        rect.top - tall * 0.006,
        rect.width,
        tall * 0.012,
      ),
      Paint()..color = _a(_snow, 0.9),
    );
  }
}

/// The tree's lights twinkling (chasing round it with the set on) and its
/// star shining on top (blazing, its rays turning, with the set on).
void _treeLights(Canvas canvas, Offset c, double tall, double t, double cheer) {
  final r = tall * 0.016;
  for (var i = 0; i < _treeBulbs.length; i++) {
    final at = c + _treeBulbs[i] * tall;
    final color = _bulbs[i % _bulbs.length];
    final twinkle =
        0.5 + 0.5 * math.sin(t * (1.5 + _rand(i, 770) * 2) + i * 2.3);
    final chase = 0.5 + 0.5 * math.sin(t * 6 - i * 0.7);
    final on = twinkle * (1 - cheer) + chase * cheer;
    canvas.drawCircle(
      at,
      r * (2.0 + 0.6 * cheer),
      Paint()..color = _a(color, 0.22 * on),
    );
    canvas.drawCircle(
      at,
      r,
      Paint()..color = Color.lerp(_a(color, 0.6), Colors.white, 0.35 * on)!,
    );
  }

  final star = c.translate(0, -tall * 1.0);
  final s = tall * 0.06;
  final pulse = 0.8 + 0.2 * math.sin(t * 2);
  final halo = Rect.fromCircle(center: star, radius: s * (2.6 + 1.6 * cheer));
  canvas.drawOval(
    halo,
    Paint()
      ..shader = RadialGradient(
        colors: [_a(_gold, (0.5 + 0.2 * cheer) * pulse), _a(_gold, 0)],
      ).createShader(halo),
  );
  if (cheer > 0) {
    final ray = Paint()
      ..strokeWidth = math.max(1, s * 0.12)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final a = i / 8 * 2 * math.pi + t * 0.5;
      final long = s * (i.isEven ? 3.2 : 2.2) * cheer;
      canvas.drawLine(
        star,
        star + Offset(math.cos(a), math.sin(a)) * long,
        ray..color = _a(const Color(0xFFFFF0B0), 0.5 * cheer * pulse),
      );
    }
  }
  final points = Path();
  for (var i = 0; i < 10; i++) {
    final a = -math.pi / 2 + i * math.pi / 5;
    final d = i.isEven ? s : s * 0.45;
    final p = star + Offset(math.cos(a), math.sin(a)) * d;
    if (i == 0) {
      points.moveTo(p.dx, p.dy);
    } else {
      points.lineTo(p.dx, p.dy);
    }
  }
  points.close();
  canvas.drawPath(
    points,
    Paint()..color = Color.lerp(_gold, Colors.white, 0.3 * pulse)!,
  );
}

// ── The snowman ───────────────────────────────────────────────────────────

/// The snowman, [tall] high, his foot at [c]: three balls of snow, coal
/// eyes and buttons, a carrot nose, a top hat, a red scarf and a stick arm
/// (his other arm is drawn live: it waves).
void _snowman(Canvas canvas, Offset c, double tall) {
  canvas.drawOval(
    Rect.fromCenter(center: c, width: tall * 0.75, height: tall * 0.08),
    Paint()..color = const Color(0x332A3A70),
  );
  final arm = Paint()
    ..strokeWidth = math.max(1.2, tall * 0.025)
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFF4A3020);
  final shoulder = c.translate(-tall * 0.12, -tall * 0.6);
  final hand = shoulder.translate(-tall * 0.34, tall * 0.12);
  canvas.drawLine(shoulder, hand, arm);
  canvas.drawLine(
    Offset.lerp(shoulder, hand, 0.7)!,
    Offset.lerp(shoulder, hand, 0.7)!.translate(-tall * 0.04, -tall * 0.08),
    arm,
  );
  for (final (y, r) in [(0.2, 0.22), (0.55, 0.16), (0.8, 0.12)]) {
    final p = c.translate(0, -tall * y);
    final rr = tall * r;
    canvas.drawCircle(
      p,
      rr,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.35, -0.35),
          radius: 1.1,
          colors: const [
            Color(0xFFFFFFFF),
            Color(0xFFDCE6FA),
            Color(0xFF94A6D2),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(Rect.fromCircle(center: p, radius: rr)),
    );
  }
  final coal = Paint()..color = const Color(0xFF1A1A24);
  for (final y in [0.47, 0.56, 0.65]) {
    canvas.drawCircle(c.translate(tall * 0.01, -tall * y), tall * 0.018, coal);
  }
  final face = c.translate(0, -tall * 0.8);
  canvas.drawCircle(
    face.translate(-tall * 0.04, -tall * 0.03),
    tall * 0.016,
    coal,
  );
  canvas.drawCircle(
    face.translate(tall * 0.05, -tall * 0.03),
    tall * 0.016,
    coal,
  );
  for (var i = 0; i < 5; i++) {
    final a = math.pi * (0.2 + 0.6 * i / 4);
    canvas.drawCircle(
      face.translate(math.cos(a) * tall * 0.06, math.sin(a) * tall * 0.05),
      tall * 0.009,
      coal,
    );
  }
  canvas.drawPath(
    Path()
      ..moveTo(face.dx + tall * 0.005, face.dy - tall * 0.005)
      ..lineTo(face.dx + tall * 0.13, face.dy + tall * 0.015)
      ..lineTo(face.dx + tall * 0.005, face.dy + tall * 0.03)
      ..close(),
    Paint()..color = const Color(0xFFFF8A2A),
  );
  // The scarf, one end hanging.
  final neck = c.translate(0, -tall * 0.69);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: neck, width: tall * 0.27, height: tall * 0.06),
      Radius.circular(tall * 0.03),
    ),
    Paint()..color = _red,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(neck.dx - tall * 0.1, neck.dy, tall * 0.055, tall * 0.16),
      Radius.circular(tall * 0.015),
    ),
    Paint()..color = const Color(0xFFB81E30),
  );
  // The top hat.
  final brim = c.translate(0, -tall * 0.91);
  final felt = Paint()..color = const Color(0xFF1A1A24);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(center: brim, width: tall * 0.3, height: tall * 0.035),
      Radius.circular(tall * 0.015),
    ),
    felt,
  );
  canvas.drawRect(
    Rect.fromLTRB(
      brim.dx - tall * 0.1,
      brim.dy - tall * 0.17,
      brim.dx + tall * 0.1,
      brim.dy,
    ),
    felt,
  );
  canvas.drawRect(
    Rect.fromLTRB(
      brim.dx - tall * 0.1,
      brim.dy - tall * 0.05,
      brim.dx + tall * 0.1,
      brim.dy - tall * 0.02,
    ),
    Paint()..color = _red,
  );
  canvas.drawOval(
    Rect.fromCenter(
      center: brim.translate(0, -tall * 0.175),
      width: tall * 0.22,
      height: tall * 0.035,
    ),
    Paint()..color = _snow,
  );
  canvas.drawPath(
    Path()
      ..moveTo(brim.dx + tall * 0.04, brim.dy - tall * 0.05)
      ..lineTo(brim.dx + tall * 0.075, brim.dy - tall * 0.09)
      ..lineTo(brim.dx + tall * 0.085, brim.dy - tall * 0.04)
      ..close(),
    Paint()..color = const Color(0xFF2E7A4A),
  );
}

/// The snowman's other stick arm: it sways in the wind; with the set on,
/// he waves.
void _snowmanArm(Canvas canvas, Offset c, double tall, double t, double cheer) {
  final shoulder = c.translate(tall * 0.13, -tall * 0.6);
  final idle = -0.35 + 0.06 * math.sin(t * 1.3);
  final wave = -1.1 + 0.35 * math.sin(t * 7);
  final a = idle + (wave - idle) * cheer;
  final dir = Offset(math.cos(a), math.sin(a));
  final hand = shoulder + dir * tall * 0.36;
  final arm = Paint()
    ..strokeWidth = math.max(1.2, tall * 0.025)
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFF4A3020);
  canvas.drawLine(shoulder, hand, arm);
  final fork = Offset.lerp(shoulder, hand, 0.72)!;
  canvas.drawLine(
    fork,
    fork + Offset(math.cos(a - 0.7), math.sin(a - 0.7)) * tall * 0.09,
    arm,
  );
  canvas.drawLine(
    hand,
    hand + Offset(math.cos(a + 0.5), math.sin(a + 0.5)) * tall * 0.05,
    arm,
  );
}

// ── Snow ──────────────────────────────────────────────────────────────────

/// One of three layers of falling snow ([layer] 0, far and fine, to 2,
/// big and near), blown about by the wind (nearer flakes further: they
/// pass by faster). With the set on there's more of it.
void _snowfall(Canvas canvas, Size size, double t, double cheer, int layer) {
  final (count, extra, dot, alpha, fall, depth) = switch (layer) {
    0 => (90, 50, 2.0, 0.6, 0.035, 0.4),
    1 => (48, 30, 3.2, 0.8, 0.07, 0.75),
    _ => (16, 12, 5.2, 0.9, 0.14, 1.4),
  };
  final n = count + (extra * cheer).round();
  final w = size.width + 20;
  final h = size.height + 20;
  final drift = WinterTimeline.drift(t) * depth * size.width / w;
  final points = Float32List(n * 2);
  for (var i = 0; i < n; i++) {
    final salt = 780 + layer * 3;
    final speed = fall * (0.75 + 0.5 * _rand(i, salt));
    final y = (_rand(i, salt + 1) + t * speed) % 1.0;
    final sway = 0.012 * math.sin(t * (0.6 + _rand(i, salt + 2)) + i);
    final x = (_rand(i, salt + 2) + drift + sway) % 1.0;
    points[i * 2] = x * w - 10;
    points[i * 2 + 1] = y * h - 10;
  }
  if (layer == 2) {
    // A soft edge round the near flakes.
    canvas.drawRawPoints(
      ui.PointMode.points,
      points,
      Paint()
        ..strokeWidth = dot * 2
        ..strokeCap = StrokeCap.round
        ..color = _a(_snow, 0.18),
    );
  }
  canvas.drawRawPoints(
    ui.PointMode.points,
    points,
    Paint()
      ..strokeWidth = dot
      ..strokeCap = StrokeCap.round
      ..color = _a(_snow, alpha),
  );
}

/// With the set on, big six-armed snowflakes tumbling slowly past.
void _crystals(Canvas canvas, Size size, double t, double cheer, double? dpr) {
  final n = (6 * cheer).round();
  for (var i = 0; i < n; i++) {
    final r =
        math.min(size.width, size.height) * (0.025 + 0.015 * _rand(i, 790));
    final y = (_rand(i, 791) + t * 0.05 * (0.7 + 0.5 * _rand(i, 792))) % 1.0;
    final x =
        (_rand(i, 793) +
            WinterTimeline.drift(t) * 1.6 +
            0.03 * math.sin(t * 0.7 + i)) %
        1.0;
    final at = Offset(
      x * (size.width + r * 4) - r * 2,
      y * (size.height + r * 4) - r * 2,
    );
    final spin = t * (0.3 + 0.3 * _rand(i, 794)) * (i.isEven ? 1 : -1);
    if (dpr == null) {
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(spin);
      _crystal(canvas, r);
      canvas.restore();
    } else {
      worldSprites.draw(
        canvas,
        ('winter crystal', r),
        bounds: Rect.fromCircle(center: Offset.zero, radius: r * 1.1),
        dpr: dpr,
        at: at,
        angle: spin,
        paint: (canvas) => _crystal(canvas, r),
      );
    }
  }
}

/// A six-armed snowflake of radius [r] round the origin.
void _crystal(Canvas canvas, double r) {
  final line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1, r * 0.09)
    ..strokeCap = StrokeCap.round
    ..color = _a(_snow, 0.8);
  final flake = Path();
  for (var i = 0; i < 6; i++) {
    final a = i / 6 * 2 * math.pi;
    final d = Offset(math.cos(a), math.sin(a));
    flake
      ..moveTo(0, 0)
      ..lineTo(d.dx * r, d.dy * r);
    for (final (along, long) in const [(0.45, 0.32), (0.72, 0.22)]) {
      final p = d * r * along;
      for (final side in const [-1.0, 1.0]) {
        final b = a + side * math.pi / 3;
        flake
          ..moveTo(p.dx, p.dy)
          ..lineTo(
            p.dx + math.cos(b) * r * long,
            p.dy + math.sin(b) * r * long,
          );
      }
    }
  }
  canvas.drawPath(flake, line);
  canvas.drawCircle(Offset.zero, r * 0.1, Paint()..color = _a(_snow, 0.9));
}
