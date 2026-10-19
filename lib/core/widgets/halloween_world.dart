import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/utopia_themes.dart';
import 'sprite_cache.dart';
import 'world_sets.dart';

/// Stable pseudo-random 0-1 from an index.
double _rand(int i, int salt) {
  final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

Color _a(Color c, double alpha) =>
    c.withValues(alpha: (c.a * alpha).clamp(0.0, 1.0));

const _ink = Color(0xFF07040C);
const _shade = Color(0xFF120A1C);
const _candle = Color(0xFFFFC23D);
const _flame = Color(0xFFFF7A1A);
const _pumpkin = Color(0xFFF2761A);
const _wisp = Color(0xFF8CFFE0);
const _fog = Color(0xFFB9A8D6);

/// When things happen in the Halloween world, shared by its painter and its
/// sounds (world_soundscape.dart), so the thunder follows the flash and the
/// witch cackles as she crosses the moon. [night] is the set's amount.
abstract final class HalloweenTimeline {
  /// Lightning flashes at every multiple of this.
  static double lightningPeriod(double night) => 9 - 3.5 * night;

  /// Which strike of lightning it is at [t]: they're numbered in order.
  static int strike(double t, double night) =>
      (t / lightningPeriod(night)).floor();

  /// How near strike [n] is, 0 (far off) to 1 (right overhead). A near one
  /// flashes bright and cracks loud at once; a far one flashes dim and
  /// rumbles faintly, a moment later.
  static double strikeNear(int n) => _rand(n, 523);

  /// The witch sets off across the moon at every multiple of this, and
  /// takes [witchCrossing] seconds to cross.
  static double witchPeriod(double night) => 15 - 7 * night;
  static const witchCrossing = 5.5;

  /// Where the witch is across the screen (0 left edge, 1 right) [s]
  /// seconds into a crossing: she comes in from off the left and flies off
  /// the right.
  static double witchAcross(double s) => -0.2 + 1.4 * (s / witchCrossing);

  /// The moon's place across the screen (see the world's moon anchor).
  static const moonAcross = 0.32;

  /// She laughs from this many seconds into a crossing (as she comes into
  /// view), for up to [cackleLength]: all the way across the moon.
  static const cackleAt = 1.0;
  static const cackleLength = 3.2;

  /// Someone stands in the tower window from [watcherFrom] to [watcherTo]
  /// of every [watcherPeriod] seconds.
  static const watcherPeriod = 13.0;
  static const watcherFrom = 0.55;
  static const watcherTo = 0.85;

  /// The jump scare: once in a while a wraith rushes out of the forest at
  /// you, screaming. It's what this world is for.
  ///
  /// At most one scare in each [scareSlot] seconds, at a moment in it no
  /// one can guess (and some slots have none): every 2 or 3 minutes.
  static const scareSlot = 150.0;

  /// How long the wraith takes to reach you and vanish.
  static const scareLength = 0.85;

  /// How long before a warned scare the dread starts to swell. It cuts
  /// off 0.4 seconds before the scream: the silence before it.
  static const dreadLead = 5.6;

  /// When slot [k]'s scare comes, in seconds from the slot's start, or
  /// null if it has none.
  static double? scareIn(int k) =>
      _rand(k, 580) < 0.85 ? 25 + _rand(k, 581) * 100 : null;

  /// Whether slot [k]'s scare is warned of by a swell of dread (half are;
  /// the rest come out of nowhere).
  static bool scareWarned(int k) => _rand(k, 582) < 0.5;

  /// A swell of dread in slot [k] that leads to nothing, in seconds from
  /// the slot's start (or null): never near the real scare.
  static double? falseAlarmIn(int k) {
    if (_rand(k, 583) > 0.55) return null;
    return ((scareIn(k) ?? 60) + 60 + _rand(k, 584) * 20) % scareSlot;
  }

  /// How far into a scare [t] is, 0 to 1, or null when there's none.
  static double? scareProgress(double t) {
    final k = (t / scareSlot).floor();
    final at = scareIn(k);
    if (at == null) return null;
    final p = (t - k * scareSlot - at) / scareLength;
    return p >= 0 && p <= 1 ? p : null;
  }

  /// The eyes in the trees: pairs of them, each opening for a while and
  /// closing again on its own cycle, on the left (even) or right (odd).
  static int eyePairs(double night) => 6 + (night * 6).round();
  static double eyeCycle(int i) => 4 + _rand(i, 560) * 5;

  /// Where pair [i] is in its cycle, 0 to 1: open while under 0.6.
  static double eyePhase(double t, int i) {
    final cycle = eyeCycle(i);
    return ((t + _rand(i, 561) * cycle) % cycle) / cycle;
  }

  static int ghostCount(double night) => 3 + (night * 4).round();
  static int batCount(double night) => 12 + (night * 16).round();

  /// How far ghost [i] is across the screen, 0 to 1.
  static double ghostCrossed(double t, int i) =>
      (t * (0.025 + _rand(i, 570) * 0.025) + _rand(i, 571)) % 1.0;

  /// How visible ghost [i] is, 0 to about 0.9.
  static double ghostFade(double t, int i) =>
      math.sin(ghostCrossed(t, i) * math.pi) *
      (0.6 + 0.3 * math.sin(t * 0.7 + i));

  /// How wide ghost [i]'s scream is, 0.4 to 1 (widest every ~7 seconds).
  static double ghostScream(double t, int i) =>
      0.4 + 0.6 * (0.5 + 0.5 * math.sin(t * 0.9 + i * 1.7));
}

/// The lightning: 0 most of the time, flashing twice in quick succession
/// every [period] seconds.
double _flash(double t, double period) {
  final local = t % period;
  if (local < 0.08) return 1 - local / 0.08;
  if (local > 0.16 && local < 0.4) return (1 - (local - 0.16) / 0.24) * 0.8;
  return 0;
}

/// Halloween: All Hallows' Eve in a haunted hollow. A huge harvest moon
/// with a witch crossing it and bats pouring out, a crooked manor on the
/// hill with one window you shouldn't look at, a twisted forest where eyes
/// blink in the dark, ghosts drifting between the trees, a scarecrow that
/// turns its head, an iron fence, a patch of grinning jack-o'-lanterns,
/// will-o'-the-wisps (Stingy Jack's lost lights) and thick rolling fog.
/// Every so often lightning shows something tall standing in the trees.
///
/// With the set on (Jack's Lantern worn here, [WorldSets.halloween]) the
/// night turns: the moon goes blood-orange, every lantern blazes and
/// watches you, the scarecrow's eyes light, the ghosts multiply, the
/// witch comes round again and again, and the tall thing comes closer.
///
/// In a browser, [dpr] is the screen's pixels a point: the trees and the
/// fence are kept as pixels (see [SpriteCache]).
void paintHalloweenScene(
  Canvas canvas,
  Size size,
  double t,
  WorldStyle style, {
  required Offset moon,
  double? dpr,
}) {
  final w = size.width;
  final h = size.height;
  final night = WorldSets.halloween.amount;
  // Near strikes flash bright, far ones dim (and sound it: see
  // HalloweenTimeline.strikeNear).
  final near = HalloweenTimeline.strikeNear(HalloweenTimeline.strike(t, night));
  final flash =
      _flash(t, HalloweenTimeline.lightningPeriod(night)) *
      (0.45 + 0.55 * near);

  _moon(canvas, moon, w * 0.21, t, night);
  _witch(canvas, size, moon, w * 0.21, t, night);
  _bats(canvas, size, t, moon, HalloweenTimeline.batCount(night));
  _moonClouds(canvas, size, moon, w * 0.21, t);

  if (flash > 0) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = _a(const Color(0xFFD8CCFF), 0.22 * flash),
    );
    _bolt(canvas, size, t, flash);
  }

  _hill(canvas, size, t, night, flash);
  _fogBand(canvas, size, t, h * 0.6, 0.5, 0.06);
  _forest(canvas, size, t, night, flash, dpr);
  _ghosts(canvas, size, t, HalloweenTimeline.ghostCount(night), night);
  _ground(canvas, size);
  _scarecrow(canvas, Offset(w * 0.8, h * 0.79), h * 0.2, t, night);
  if (dpr == null) {
    _fence(canvas, size, h * 0.83);
  } else {
    worldSprites.draw(
      canvas,
      ('halloween fence', w, h),
      bounds: Rect.fromLTRB(-4, h * 0.83 - 60, w + 10, h * 0.83 + 4),
      dpr: dpr,
      absolute: true,
      paint: (canvas) => _fence(canvas, size, h * 0.83),
    );
  }
  _wisps(canvas, size, t, 7 + (night * 5).round());
  _fogBand(canvas, size, t, h * 0.8, 0.75, 0.09);
  // Darkness pressing in from the edges.
  final rect = Offset.zero & size;
  canvas.drawRect(
    rect,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.1),
        radius: 0.9,
        colors: [Colors.transparent, _a(_ink, 0.55 + 0.2 * night)],
        stops: const [0.5, 1],
      ).createShader(rect),
  );
  _patch(canvas, size, t, night);
  _fogBand(canvas, size, t, h * 0.95, 1.1, 0.12);
  _leaves(canvas, size, t);
  _web(canvas, Offset(w, 0), w * 0.36, t);
  if (HalloweenTimeline.scareProgress(t) case final p?) {
    _wraith(canvas, size, t, p);
    _wraithFlash(canvas, size, p);
  }
}

/// The jump scare: a wraith rushing out of the trees at you, faster and
/// faster, jaw stretched in a scream, until it fills the screen in a flash
/// and is gone.
void _wraith(Canvas canvas, Size size, double t, double p) {
  final w = size.width;
  final h = size.height;
  const reach = 0.6;
  final u = math.min(1.0, p / reach);
  final gone = p <= reach ? 0.0 : (p - reach) / (1 - reach);
  // The world darkens as it comes.
  canvas.drawRect(
    Offset.zero & size,
    Paint()..color = _a(Colors.black, 0.5 * u * (1 - gone)),
  );
  final shake = gone > 0
      ? Offset.zero
      : Offset(
          math.sin(t * 91) * w * 0.014 * u,
          math.cos(t * 77) * w * 0.014 * u,
        );
  final r = w * (0.05 + 1.1 * math.pow(u, 2.2) + 0.6 * gone);
  final c = Offset(w * 0.5, h * (0.6 - 0.14 * u)) + shake;
  final alpha = (0.35 + 0.65 * u) * (1 - math.min(1.0, gone * 1.6));
  if (alpha <= 0) return;
  // Echoes trailing behind it, as it rushes.
  for (final (scale, fade) in const [(0.55, 0.12), (0.75, 0.2)]) {
    _wraithFace(canvas, c, r * scale, u, alpha * fade, t, hair: false);
  }
  _wraithFace(canvas, c, r, u, alpha, t, hair: true);
}

void _wraithFace(
  Canvas canvas,
  Offset c,
  double r,
  double u,
  double alpha,
  double t, {
  required bool hair,
}) {
  Offset at(double x, double y) => c.translate(x * r, y * r);
  // Hair streaming out behind, blown back by the rush.
  if (hair) {
    final strand = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = r * 0.025
      ..color = _a(const Color(0xFF1B1820), 0.7 * alpha);
    for (var k = 0; k < 18; k++) {
      final a = -math.pi * 0.95 + k / 17 * math.pi * 0.9;
      final from = at(math.cos(a) * 0.38, -0.25 + math.sin(a) * 0.5);
      final len = 0.6 + 0.5 * _rand(k, 590);
      final wave = math.sin(t * 20 + k) * 0.08;
      final to =
          from + Offset(math.cos(a + wave), math.sin(a + wave)) * r * len;
      canvas.drawPath(
        Path()
          ..moveTo(from.dx, from.dy)
          ..quadraticBezierTo(
            (from.dx + to.dx) / 2 + r * 0.06 * math.sin(k + t * 9),
            (from.dy + to.dy) / 2,
            to.dx,
            to.dy,
          ),
        strand,
      );
    }
  }
  // The face: long and gaunt, the jaw dropping as it screams.
  final jaw = 0.75 + 0.25 * u;
  final face = Path()
    ..moveTo(at(0, -0.78).dx, at(0, -0.78).dy)
    ..cubicTo(
      at(0.36, -0.78).dx,
      at(0.36, -0.78).dy,
      at(0.48, -0.42).dx,
      at(0.48, -0.42).dy,
      at(0.44, -0.1).dx,
      at(0.44, -0.1).dy,
    )
    ..cubicTo(
      at(0.41, 0.15).dx,
      at(0.41, 0.15).dy,
      at(0.3, jaw * 0.6).dx,
      at(0.3, jaw * 0.6).dy,
      at(0, jaw).dx,
      at(0, jaw).dy,
    )
    ..cubicTo(
      at(-0.3, jaw * 0.6).dx,
      at(-0.3, jaw * 0.6).dy,
      at(-0.41, 0.15).dx,
      at(-0.41, 0.15).dy,
      at(-0.44, -0.1).dx,
      at(-0.44, -0.1).dy,
    )
    ..cubicTo(
      at(-0.48, -0.42).dx,
      at(-0.48, -0.42).dy,
      at(-0.36, -0.78).dx,
      at(-0.36, -0.78).dy,
      at(0, -0.78).dx,
      at(0, -0.78).dy,
    )
    ..close();
  final bounds = Rect.fromCenter(
    center: at(0, -0.1),
    width: r * 1.1,
    height: r * 1.9,
  );
  canvas.drawPath(
    face,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.2),
        colors: [
          _a(const Color(0xFFEAF1EC), 0.95 * alpha),
          _a(const Color(0xFFAEBDB6), 0.85 * alpha),
          _a(const Color(0xFF5E6E68), 0.0),
        ],
        stops: const [0, 0.6, 1],
      ).createShader(bounds),
  );
  // Sunken cheeks.
  for (final side in const [-1.0, 1.0]) {
    final cheek = Rect.fromCenter(
      center: at(side * 0.26, 0.18),
      width: r * 0.22,
      height: r * 0.4,
    );
    canvas.drawOval(
      cheek,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _a(const Color(0xFF2A2F33), 0.45 * alpha),
            _a(const Color(0xFF2A2F33), 0),
          ],
        ).createShader(cheek),
    );
  }
  // Eyes: slanted black hollows with a red glint deep in each.
  for (final side in const [-1.0, 1.0]) {
    final socket = at(side * 0.19, -0.2);
    canvas.save();
    canvas.translate(socket.dx, socket.dy);
    canvas.rotate(side * 0.38);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 0.26, height: r * 0.17),
      Paint()..color = _a(const Color(0xFF040205), alpha),
    );
    canvas.restore();
    canvas.drawCircle(
      socket.translate(side * r * 0.01, r * 0.01),
      r * 0.045,
      Paint()
        ..color = _a(const Color(0xFFFF1A1A), 0.8 * alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.03),
    );
    canvas.drawCircle(
      socket.translate(side * r * 0.01, r * 0.01),
      r * 0.016,
      Paint()..color = _a(const Color(0xFFFFD0C0), alpha),
    );
  }
  // The mouth: stretched open in a scream, ragged teeth top and bottom.
  final top = 0.1;
  final bottom = 0.1 + 0.62 * jaw;
  const half = 0.15;
  final mouth = Path()..moveTo(at(-half, top).dx, at(-half, top).dy);
  for (var k = 1; k <= 7; k++) {
    final x = -half + 2 * half * k / 7;
    final y = k.isOdd ? top + 0.07 : top;
    mouth.lineTo(at(x, y).dx, at(x, y).dy);
  }
  mouth.quadraticBezierTo(
    at(half + 0.04, (top + bottom) / 2).dx,
    at(half + 0.04, (top + bottom) / 2).dy,
    at(half * 0.6, bottom).dx,
    at(half * 0.6, bottom).dy,
  );
  for (var k = 1; k <= 5; k++) {
    final x = half * 0.6 - 1.2 * half * k / 5;
    final y = k.isOdd ? bottom - 0.06 : bottom;
    mouth.lineTo(at(x, y).dx, at(x, y).dy);
  }
  mouth
    ..quadraticBezierTo(
      at(-half - 0.04, (top + bottom) / 2).dx,
      at(-half - 0.04, (top + bottom) / 2).dy,
      at(-half, top).dx,
      at(-half, top).dy,
    )
    ..close();
  final throat = Rect.fromCenter(
    center: at(0, (top + bottom) / 2),
    width: r * 0.4,
    height: r * (bottom - top),
  );
  canvas.drawPath(
    mouth,
    Paint()
      ..shader = RadialGradient(
        colors: [
          _a(const Color(0xFF000000), alpha),
          _a(const Color(0xFF2B030A), alpha),
          _a(const Color(0xFF5A0A16), alpha),
        ],
        stops: const [0, 0.7, 1],
      ).createShader(throat),
  );
}

/// The flash as the wraith reaches you.
void _wraithFlash(Canvas canvas, Size size, double p) {
  const reach = 0.6;
  final gone = p <= reach ? 0.0 : (p - reach) / (1 - reach);
  if (gone > 0) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = _a(Colors.white, 0.55 * (1 - gone) * (1 - gone)),
    );
  }
}

/// The harvest moon, huge and low, blood-orange with the set on.
void _moon(Canvas canvas, Offset c, double r, double t, double night) {
  final glow = Color.lerp(
    const Color(0xFFFFB24A),
    const Color(0xFFFF4A1A),
    night,
  )!;
  canvas.drawCircle(
    c,
    r * 2.6,
    Paint()
      ..shader = RadialGradient(
        colors: [_a(glow, 0.35), _a(glow, 0.1), _a(glow, 0)],
        stops: const [0.3, 0.6, 1],
      ).createShader(Rect.fromCircle(center: c, radius: r * 2.6)),
  );
  final face = Rect.fromCircle(center: c, radius: r);
  canvas.drawCircle(
    c,
    r,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.35),
        colors: [
          Color.lerp(const Color(0xFFFFF1C8), const Color(0xFFFFC09A), night)!,
          Color.lerp(const Color(0xFFFFC66A), const Color(0xFFFF6A2A), night)!,
          Color.lerp(const Color(0xFFE8862A), const Color(0xFFB0240A), night)!,
          Color.lerp(const Color(0xFF9A3E12), const Color(0xFF4A0806), night)!,
        ],
        stops: const [0, 0.5, 0.85, 1],
      ).createShader(face),
  );
  final crater = Paint()..color = _a(const Color(0xFF8A3A12), 0.28);
  for (final (x, y, s) in const [
    (0.32, 0.2, 0.2),
    (-0.3, 0.35, 0.14),
    (0.05, -0.38, 0.12),
    (-0.4, -0.15, 0.09),
    (0.45, -0.25, 0.07),
  ]) {
    canvas.drawCircle(c.translate(r * x, r * y), r * s, crater);
  }
}

/// A witch on her broom crossing the moon, cloak flapping; with the set on
/// she comes round much more often.
void _witch(
  Canvas canvas,
  Size size,
  Offset moon,
  double r,
  double t,
  double night,
) {
  final period = HalloweenTimeline.witchPeriod(night);
  final into = t % period;
  final p = into / HalloweenTimeline.witchCrossing;
  if (p > 1) return;
  final w = size.width;
  final x = w * HalloweenTimeline.witchAcross(into);
  final y =
      moon.dy +
      r * 0.25 -
      math.sin(p * math.pi) * r * 0.55 +
      math.sin(t * 3) * 4;
  final s = r * 0.62;
  final ink = Paint()..color = const Color(0xFF05020A);
  canvas.save();
  canvas.translate(x, y);
  canvas.rotate(-0.12 + math.sin(t * 3) * 0.05);
  // The broom and its bristles.
  canvas.drawLine(
    Offset(-s * 1.1, s * 0.05),
    Offset(s * 0.9, -s * 0.08),
    Paint()
      ..strokeWidth = s * 0.07
      ..strokeCap = StrokeCap.round
      ..color = ink.color,
  );
  canvas.drawPath(
    Path()
      ..moveTo(-s * 1.0, s * 0.02)
      ..lineTo(-s * 1.55, -s * 0.18)
      ..lineTo(-s * 1.6, s * 0.08)
      ..lineTo(-s * 1.5, s * 0.3)
      ..close(),
    ink,
  );
  // Her cloak streaming back, her body, head and hat.
  final flap = math.sin(t * 9) * s * 0.08;
  canvas.drawPath(
    Path()
      ..moveTo(s * 0.2, -s * 0.05)
      ..quadraticBezierTo(
        -s * 0.3,
        -s * 0.2 + flap,
        -s * 0.85,
        -s * 0.05 + flap,
      )
      ..lineTo(-s * 0.55, s * 0.12)
      ..lineTo(-s * 0.1, s * 0.05)
      ..close(),
    ink,
  );
  canvas.drawPath(
    Path()
      ..moveTo(-s * 0.05, 0)
      ..lineTo(s * 0.12, -s * 0.55)
      ..lineTo(s * 0.35, -s * 0.5)
      ..lineTo(s * 0.32, 0)
      ..close(),
    ink,
  );
  canvas.drawCircle(Offset(s * 0.27, -s * 0.62), s * 0.12, ink);
  canvas.drawPath(
    Path()
      ..moveTo(s * 0.06, -s * 0.68)
      ..lineTo(s * 0.5, -s * 0.72)
      ..lineTo(s * 0.33, -s * 0.76)
      ..quadraticBezierTo(s * 0.28, -s * 1.05, s * 0.05, -s * 1.15)
      ..quadraticBezierTo(s * 0.2, -s * 0.98, s * 0.18, -s * 0.76)
      ..close(),
    ink,
  );
  // A knee and a pointed boot over the broom.
  canvas.drawLine(
    Offset(s * 0.2, -s * 0.05),
    Offset(s * 0.48, s * 0.12),
    Paint()
      ..strokeWidth = s * 0.09
      ..strokeCap = StrokeCap.round
      ..color = ink.color,
  );
  canvas.restore();
}

/// Bats pouring out of the moon and swirling.
void _bats(Canvas canvas, Size size, double t, Offset moon, int count) {
  final w = size.width;
  final ink = Paint()..color = const Color(0xFF05020A);
  for (var i = 0; i < count; i++) {
    final speed = 0.06 + _rand(i, 500) * 0.06;
    final k = (t * speed + _rand(i, 501)) % 1.0;
    final a = _rand(i, 502) * math.pi * 2 + k * (1 + _rand(i, 503)) * 2;
    final dist = w * (0.05 + 0.9 * k);
    final x = moon.dx + math.cos(a) * dist;
    final y = moon.dy + math.sin(a) * dist * 0.55 + math.sin(t * 3 + i) * 6;
    final s = (3 + _rand(i, 504) * 5) * (0.5 + k);
    final flap = math.sin(t * (14 + _rand(i, 505) * 6) + i);
    canvas.drawPath(
      Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(
          x - s,
          y - s * (0.4 + flap),
          x - s * 2,
          y - s * 0.2 * flap,
        )
        ..lineTo(x - s * 1.4, y + s * 0.2)
        ..lineTo(x - s * 0.8, y)
        ..lineTo(x - s * 0.4, y + s * 0.4)
        ..lineTo(x, y + s * 0.15)
        ..lineTo(x + s * 0.4, y + s * 0.4)
        ..lineTo(x + s * 0.8, y)
        ..lineTo(x + s * 1.4, y + s * 0.2)
        ..lineTo(x + s * 2, y - s * 0.2 * flap)
        ..quadraticBezierTo(x + s, y - s * (0.4 + flap), x, y)
        ..close(),
      ink,
    );
  }
}

/// Thin dark clouds sliding across the moon.
void _moonClouds(Canvas canvas, Size size, Offset moon, double r, double t) {
  final w = size.width;
  for (var i = 0; i < 4; i++) {
    final speed = 6 + i * 3.0;
    final span = w + r * 4;
    final x = (t * speed + _rand(i, 510) * span) % span - r * 2;
    final y = moon.dy + r * (-0.6 + 0.45 * i);
    final cloud = Rect.fromCenter(
      center: Offset(x, y),
      width: r * (2.2 + _rand(i, 511)),
      height: r * 0.22,
    );
    // Soft-edged with a gradient rather than a blur: far cheaper to draw
    // every frame.
    canvas.drawOval(
      cloud,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _a(const Color(0xFF1A0E26), 0.8),
            _a(const Color(0xFF1A0E26), 0.5),
            _a(const Color(0xFF1A0E26), 0),
          ],
          stops: const [0, 0.6, 1],
        ).createShader(cloud),
    );
  }
}

/// A forked bolt down the far sky.
void _bolt(Canvas canvas, Size size, double t, double flash) {
  final w = size.width;
  final h = size.height;
  final n = (t / 9).floor();
  var p = Offset(w * (0.5 + 0.4 * _rand(n, 520)), 0);
  final path = Path()..moveTo(p.dx, p.dy);
  for (var k = 0; k < 14; k++) {
    p = p.translate((_rand(n * 20 + k, 521) - 0.5) * w * 0.16, h * 0.035);
    path.lineTo(p.dx, p.dy);
    // A fork splitting off partway down.
    if (k == 5) {
      var q = p;
      final fork = Path()..moveTo(q.dx, q.dy);
      for (var j = 0; j < 5; j++) {
        q = q.translate(-w * (0.03 + 0.04 * _rand(n + j, 522)), h * 0.03);
        fork.lineTo(q.dx, q.dy);
      }
      path.addPath(fork, Offset.zero);
    }
  }
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeJoin = StrokeJoin.round
      ..color = _a(const Color(0xFFB8A8FF), 0.3 * flash),
  );
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = _a(Colors.white, flash),
  );
}

/// The hill with the haunted manor: crooked towers, windows flickering
/// with candlelight, and in one of them, now and then, someone standing.
void _hill(Canvas canvas, Size size, double t, double night, double flash) {
  final w = size.width;
  final h = size.height;
  final hill = Path()
    ..moveTo(0, h * 0.66)
    ..quadraticBezierTo(w * 0.3, h * 0.6, w * 0.55, h * 0.58)
    ..quadraticBezierTo(w * 0.78, h * 0.53, w, h * 0.57)
    ..lineTo(w, h)
    ..lineTo(0, h)
    ..close();
  canvas.drawPath(
    hill,
    Paint()..color = Color.lerp(_shade, const Color(0xFF3A2C5A), flash)!,
  );

  final base = Offset(w * 0.7, h * 0.56);
  final u = w * 0.068;
  final house = Paint()
    ..color = Color.lerp(_ink, const Color(0xFF2A1F40), flash)!;
  final body = Path()
    // Main house.
    ..addRect(Rect.fromLTWH(base.dx - u * 2, base.dy - u * 2.2, u * 4, u * 2.2))
    // Roof, sagging.
    ..moveTo(base.dx - u * 2.3, base.dy - u * 2.1)
    ..lineTo(base.dx - u * 0.2, base.dy - u * 3.6)
    ..lineTo(base.dx + u * 2.3, base.dy - u * 2.05)
    ..close()
    // The leaning tower.
    ..moveTo(base.dx + u * 1.1, base.dy - u * 2)
    ..lineTo(base.dx + u * 1.2, base.dy - u * 4.2)
    ..lineTo(base.dx + u * 2.1, base.dy - u * 4.3)
    ..lineTo(base.dx + u * 2.0, base.dy - u * 2)
    ..close()
    ..moveTo(base.dx + u * 0.95, base.dy - u * 4.15)
    ..lineTo(base.dx + u * 1.75, base.dy - u * 5.9)
    ..lineTo(base.dx + u * 2.35, base.dy - u * 4.25)
    ..close()
    // The small turret on the left.
    ..moveTo(base.dx - u * 1.9, base.dy - u * 2.4)
    ..lineTo(base.dx - u * 1.9, base.dy - u * 3.4)
    ..lineTo(base.dx - u * 1.2, base.dy - u * 3.4)
    ..lineTo(base.dx - u * 1.2, base.dy - u * 2.6)
    ..close()
    ..moveTo(base.dx - u * 2.05, base.dy - u * 3.35)
    ..lineTo(base.dx - u * 1.55, base.dy - u * 4.3)
    ..lineTo(base.dx - u * 1.05, base.dy - u * 3.35)
    ..close()
    // A chimney.
    ..addRect(
      Rect.fromLTWH(base.dx - u * 0.9, base.dy - u * 3.6, u * 0.35, u * 0.9),
    );
  canvas.drawPath(body, house);
  // A weathervane bent on the tower.
  canvas.drawLine(
    Offset(base.dx + u * 1.75, base.dy - u * 5.9),
    Offset(base.dx + u * 1.85, base.dy - u * 6.5),
    Paint()
      ..strokeWidth = 1.4
      ..color = house.color,
  );

  // Windows: candlelight flickering, more lit as the night turns.
  final windows = [
    Offset(base.dx - u * 1.4, base.dy - u * 1.5),
    Offset(base.dx - u * 0.5, base.dy - u * 1.5),
    Offset(base.dx + u * 0.4, base.dy - u * 1.5),
    Offset(base.dx - u * 1.4, base.dy - u * 0.6),
    Offset(base.dx + u * 0.4, base.dy - u * 0.6),
    Offset(base.dx + u * 1.6, base.dy - u * 3.3),
    Offset(base.dx - u * 1.55, base.dy - u * 2.95),
  ];
  for (var i = 0; i < windows.length; i++) {
    final lit = i < 3 || night > _rand(i, 530);
    if (!lit) continue;
    final flicker =
        0.7 + 0.3 * math.sin(t * (7 + i) + i * 2) * math.sin(t * 3.1 + i);
    final win = Rect.fromCenter(
      center: windows[i],
      width: u * 0.45,
      height: u * 0.62,
    );
    final halo = win.inflate(u * 0.35);
    canvas.drawOval(
      halo,
      Paint()
        ..shader = RadialGradient(
          colors: [_a(_candle, 0.3 * flicker), _a(_candle, 0)],
        ).createShader(halo),
    );
    canvas.drawRect(
      win,
      Paint()..color = _a(Color.lerp(_flame, _candle, flicker)!, 0.95),
    );
    // The window frame's cross.
    final bar = Paint()
      ..strokeWidth = 1
      ..color = house.color;
    canvas.drawLine(win.topCenter, win.bottomCenter, bar);
    canvas.drawLine(win.centerLeft, win.centerRight, bar);
  }
  // Someone in the tower window, now and then, watching.
  final watch =
      (t % HalloweenTimeline.watcherPeriod) / HalloweenTimeline.watcherPeriod;
  final there =
      watch > HalloweenTimeline.watcherFrom &&
          watch < HalloweenTimeline.watcherTo
      ? math.sin((watch - 0.55) / 0.3 * math.pi)
      : 0.0;
  final who = math.max(there, night * 0.85);
  if (who > 0) {
    final at = windows[5];
    canvas.drawCircle(
      at.translate(0, -u * 0.12),
      u * 0.11,
      Paint()..color = _a(_ink, who),
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: at.translate(0, u * 0.14),
        width: u * 0.26,
        height: u * 0.32,
      ),
      Paint()..color = _a(_ink, who),
    );
  }
}

/// A gnarled dead tree: a tapered, twisting trunk forking into crooked
/// branches.
/// A tree's roots and branches, each a curve from [from] to [to] bending
/// through [mid], [width] thick.
void _treeLines(
  Offset base,
  double height,
  double lean,
  int seed,
  double sway,
  void Function(Offset from, Offset mid, Offset to, double width) line,
) {
  void branch(Offset from, double angle, double len, double width, int depth) {
    final bend = (_rand(seed * 31 + depth * 7 + len.round(), 540) - 0.5) * 0.9;
    final mid =
        from +
        Offset(math.cos(angle + bend * 0.5), math.sin(angle + bend * 0.5)) *
            len *
            0.5;
    final to =
        mid +
        Offset(
              math.cos(angle - bend * 0.4 + sway),
              math.sin(angle - bend * 0.4 + sway),
            ) *
            len *
            0.5;
    line(from, mid, to, width);
    if (depth == 0 || width < 0.8) return;
    final forks = depth > 2 ? 2 : 3;
    for (var k = 0; k < forks; k++) {
      final spread =
          (k - (forks - 1) / 2) *
          (0.55 + 0.25 * _rand(seed + k + depth * 5, 541));
      branch(
        to,
        angle + spread + (_rand(seed * 3 + k + depth, 542) - 0.5) * 0.4,
        len * (0.6 + 0.15 * _rand(seed + k * 2 + depth, 543)),
        width * 0.6,
        depth - 1,
      );
    }
  }

  // The roots clawing into the ground.
  for (final dir in const [-1.0, 1.0]) {
    line(
      Offset(base.dx, base.dy - height * 0.05),
      Offset(base.dx + dir * height * 0.06, base.dy),
      Offset(base.dx + dir * height * 0.13, base.dy + height * 0.02),
      height * 0.035,
    );
  }
  branch(base, -math.pi / 2 + lean, height * 0.42, height * 0.075, 4);
}

void _tree(
  Canvas canvas,
  Offset base,
  double height,
  double lean,
  int seed,
  Color color,
  double t, {
  double? sway,
}) {
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..color = color;
  _treeLines(
    base,
    height,
    lean,
    seed,
    sway ?? math.sin(t * 0.6 + seed) * 0.02,
    (from, mid, to, width) {
      paint.strokeWidth = width;
      canvas.drawPath(
        Path()
          ..moveTo(from.dx, from.dy)
          ..quadraticBezierTo(mid.dx, mid.dy, to.dx, to.dy),
        paint,
      );
    },
  );
}

/// A tree, in a browser ([dpr]) kept as pixels and turned about its foot
/// as it sways (its branch tips travel as far as when each branch bends).
/// Lightning recolors it, so then it's drawn as it is.
void _treeAt(
  Canvas canvas,
  Size size,
  Offset base,
  double height,
  double lean,
  int seed,
  Color color,
  double t,
  double? dpr, {
  required bool lit,
}) {
  if (dpr == null || lit) {
    _tree(canvas, base, height, lean, seed, color, t);
    return;
  }
  var box = Rect.fromPoints(base, base);
  _treeLines(base, height, lean, seed, 0, (from, mid, to, width) {
    box = box
        .expandToInclude(Rect.fromPoints(from, mid).inflate(width / 2 + 2))
        .expandToInclude(Rect.fromPoints(mid, to).inflate(width / 2 + 2));
  });
  // Off the screen, it's never seen.
  box = box.intersect((Offset.zero & size).inflate(height * 0.05 + 8));
  worldSprites.draw(
    canvas,
    ('halloween tree', seed, height, lean, color),
    bounds: box.shift(-base).inflate(2),
    dpr: dpr,
    at: base,
    angle: math.sin(t * 0.6 + seed) * 0.02 * 0.6,
    absolute: true,
    paint: (canvas) =>
        _tree(canvas, base, height, lean, seed, color, t, sway: 0),
  );
}

/// The twisted forest on both sides, eyes blinking between the trees, and
/// in the lightning, something tall standing among them.
void _forest(
  Canvas canvas,
  Size size,
  double t,
  double night,
  double flash,
  double? dpr,
) {
  final w = size.width;
  final h = size.height;
  final far = Color.lerp(
    const Color(0xFF1A1028),
    const Color(0xFF453866),
    flash,
  )!;
  // The far trees, leaving the manor clear.
  const spots = [0.02, 0.17, 0.32, 0.46, 0.94];
  for (var i = 0; i < spots.length; i++) {
    final x = w * (spots[i] + 0.03 * _rand(i, 550));
    final ground = h * (0.63 - 0.03 * math.sin(i * 1.7));
    _treeAt(
      canvas,
      size,
      Offset(x, ground),
      h * (0.14 + 0.05 * _rand(i, 551)),
      (_rand(i, 552) - 0.5) * 0.4,
      100 + i,
      far,
      t,
      dpr,
      lit: flash > 0,
    );
  }

  // The tall thing: there only in the lightning, closer with the set on.
  if (flash > 0) {
    final x = w * (0.2 - 0.04 * night);
    final ground = h * (0.7 + 0.04 * night);
    final tall = h * (0.2 + 0.08 * night);
    final ink = Paint()..color = _a(const Color(0xFF020104), flash);
    canvas.drawPath(
      Path()
        ..moveTo(x - tall * 0.04, ground)
        ..lineTo(x - tall * 0.06, ground - tall * 0.78)
        ..quadraticBezierTo(
          x,
          ground - tall * 0.84,
          x + tall * 0.06,
          ground - tall * 0.78,
        )
        ..lineTo(x + tall * 0.04, ground)
        ..close(),
      ink,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(x, ground - tall * 0.9),
        width: tall * 0.1,
        height: tall * 0.14,
      ),
      ink,
    );
    final arm = Paint()
      ..strokeWidth = tall * 0.025
      ..strokeCap = StrokeCap.round
      ..color = ink.color;
    for (final dir in const [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(x + dir * tall * 0.05, ground - tall * 0.74)
          ..quadraticBezierTo(
            x + dir * tall * 0.12,
            ground - tall * 0.5,
            x + dir * tall * 0.1,
            ground - tall * 0.22,
          ),
        arm..style = PaintingStyle.stroke,
      );
    }
  }

  final near = Color.lerp(_ink, const Color(0xFF2A2040), flash)!;
  for (final (base, height, lean, seed) in [
    (Offset(w * 0.06, h * 0.78), h * 0.42, 0.18, 7),
    (Offset(w * 0.97, h * 0.74), h * 0.36, -0.22, 11),
  ]) {
    _treeAt(
      canvas,
      size,
      base,
      height,
      lean,
      seed,
      near,
      t,
      dpr,
      lit: flash > 0,
    );
  }

  // Eyes in the dark, blinking, appearing and gone.
  final pairs = HalloweenTimeline.eyePairs(night);
  for (var i = 0; i < pairs; i++) {
    final k = HalloweenTimeline.eyePhase(t, i);
    if (k > 0.6) continue;
    final open = math.sin(k / 0.6 * math.pi).clamp(0.0, 1.0);
    final blink = (t * 1.3 + i) % 3.1 < 0.12 ? 0.1 : 1.0;
    final side = i.isEven ? 0.0 : 0.75;
    final at = Offset(
      w * (side + 0.25 * _rand(i, 562)),
      h * (0.6 + 0.12 * _rand(i, 563)),
    );
    final color = _rand(i, 564) < 0.5 + 0.3 * night
        ? const Color(0xFFFF3A1A)
        : const Color(0xFFE8FF4A);
    final s = 2.2 + _rand(i, 565) * 1.6;
    final halo = Rect.fromCenter(center: at, width: s * 8, height: s * 4);
    canvas.drawOval(
      halo,
      Paint()
        ..shader = RadialGradient(
          colors: [_a(color, 0.35 * open), _a(color, 0)],
        ).createShader(halo),
    );
    for (final dx in [-s * 1.6, s * 1.6]) {
      final eye = Rect.fromCenter(
        center: at.translate(dx, 0),
        width: s * 1.6,
        height: s * 1.1 * open * blink,
      );
      canvas.drawOval(eye, Paint()..color = _a(color, open));
    }
  }
}

/// Wraiths drifting between the trees: tall, tattered and see-through,
/// long arms reaching ahead of them, hollow eye sockets with a pinprick of
/// light in each, and a mouth that slowly stretches into a scream.
void _ghosts(Canvas canvas, Size size, double t, int count, double night) {
  final w = size.width;
  final h = size.height;
  for (var i = 0; i < count; i++) {
    final k = HalloweenTimeline.ghostCrossed(t, i);
    final dir = i.isEven ? 1.0 : -1.0;
    final x = dir > 0 ? -w * 0.15 + k * w * 1.3 : w * 1.15 - k * w * 1.3;
    final y = h * (0.52 + 0.18 * _rand(i, 572)) + math.sin(t * 1.1 + i) * 10;
    final s = w * (0.045 + 0.025 * _rand(i, 573)) * (1 + 0.25 * night);
    final fade = HalloweenTimeline.ghostFade(t, i);
    if (fade <= 0.02) continue;
    canvas.save();
    canvas.translate(x, y);
    canvas.scale(dir, 1);
    canvas.rotate(0.18 + 0.06 * math.sin(t * 1.1 + i));

    // The body: a hooded head over a long, tattered robe that trails off.
    final body = Path()
      ..moveTo(-s * 0.45, -s * 1.3)
      ..quadraticBezierTo(-s * 0.5, -s * 2.1, s * 0.1, -s * 2.15)
      ..quadraticBezierTo(s * 0.6, -s * 2.05, s * 0.55, -s * 1.3)
      ..quadraticBezierTo(s * 0.9, -s * 0.4, s * 0.7, s * 1.2);
    for (var j = 0; j <= 7; j++) {
      final u = j / 7;
      final rip = math.sin(t * 4 + j * 1.9 + i) * s * 0.2;
      body.lineTo(
        s * 0.7 - u * s * 1.9 - u * u * s * 0.6,
        s * (1.2 + 0.9 * u) + rip + (j.isEven ? s * 0.35 : -s * 0.1),
      );
    }
    body
      ..quadraticBezierTo(-s * 0.9, -s * 0.2, -s * 0.45, -s * 1.3)
      ..close();
    final pale = Color.lerp(
      const Color(0xFFDCE6FF),
      const Color(0xFFC8FFE8),
      night,
    )!;
    // A faint larger copy for the glow, instead of a costly blur.
    canvas.save();
    canvas.translate(0, -s * 0.4);
    canvas.scale(1.12);
    canvas.translate(0, s * 0.4);
    canvas.drawPath(body, Paint()..color = _a(pale, 0.08 * fade));
    canvas.restore();
    canvas.drawPath(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, -s * 2.1),
          Offset(-s * 0.5, s * 2.2),
          [_a(pale, 0.6 * fade), _a(pale, 0.2 * fade), _a(pale, 0)],
          const [0, 0.5, 1],
        ),
    );

    // Long thin arms reaching ahead, fading out at hooked claws.
    for (var j = 0; j < 2; j++) {
      final reach = math.sin(t * 1.6 + i + j * 0.8) * s * 0.12;
      final shoulder = Offset(s * 0.4, -s * (1.1 - j * 0.3));
      final hand = Offset(
        s * (1.5 + j * 0.12) + reach,
        -s * (0.95 - j * 0.4) + reach * 0.5,
      );
      canvas.drawPath(
        Path()
          ..moveTo(shoulder.dx, shoulder.dy)
          ..quadraticBezierTo(s * 1.0, -s * (1.3 - j * 0.3), hand.dx, hand.dy),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = s * 0.09
          ..shader = ui.Gradient.linear(shoulder, hand, [
            _a(pale, 0.5 * fade),
            _a(pale, 0.25 * fade),
          ]),
      );
      final claw = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = s * 0.035
        ..color = _a(pale, 0.35 * fade);
      for (var f = 0; f < 3; f++) {
        final a = -0.5 + f * 0.4;
        final tip = hand + Offset(math.cos(a), math.sin(a)) * s * 0.3;
        canvas.drawPath(
          Path()
            ..moveTo(hand.dx, hand.dy)
            ..quadraticBezierTo(
              hand.dx + math.cos(a - 0.4) * s * 0.22,
              hand.dy + math.sin(a - 0.4) * s * 0.22,
              tip.dx,
              tip.dy + s * 0.08,
            ),
          claw,
        );
      }
    }

    // The face: dark sockets with a cold point of light, a stretched scream.
    final hollow = Paint()..color = _a(const Color(0xFF07040C), 0.9 * fade);
    final scream = HalloweenTimeline.ghostScream(t, i);
    for (final (ex, tilt) in const [(-0.08, 0.35), (0.3, -0.35)]) {
      canvas.save();
      canvas.translate(s * ex, -s * 1.62);
      canvas.rotate(tilt);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: s * 0.22, height: s * 0.36),
        hollow,
      );
      canvas.restore();
      canvas.drawCircle(
        Offset(s * ex, -s * 1.6),
        s * 0.035,
        Paint()
          ..color = _a(
            Color.lerp(
              const Color(0xFFBFF6FF),
              const Color(0xFFFF3A1A),
              night,
            )!,
            fade,
          ),
      );
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * 0.12, -s * (1.22 - 0.1 * scream)),
        width: s * 0.2,
        height: s * (0.22 + 0.42 * scream),
      ),
      hollow,
    );
    canvas.restore();
  }
}

/// The field in front of the hill.
void _ground(Canvas canvas, Size size) {
  final w = size.width;
  final h = size.height;
  final field = Path()
    ..moveTo(0, h * 0.76)
    ..quadraticBezierTo(w * 0.5, h * 0.72, w, h * 0.75)
    ..lineTo(w, h)
    ..lineTo(0, h)
    ..close();
  canvas.drawPath(
    field,
    Paint()
      ..shader = ui.Gradient.linear(Offset(0, h * 0.72), Offset(0, h), const [
        Color(0xFF160C20),
        Color(0xFF07040C),
      ]),
  );
}

/// A scarecrow on its post, arms out on the crossbar, straw poking from
/// its sleeves, its sack head slowly tilting; with the set on its eyes
/// light and it turns to look at you.
void _scarecrow(
  Canvas canvas,
  Offset base,
  double height,
  double t,
  double night,
) {
  final s = height;
  final wood = Paint()..color = const Color(0xFF1C120C);
  canvas.drawRect(
    Rect.fromLTWH(base.dx - s * 0.02, base.dy - s, s * 0.04, s),
    wood,
  );
  canvas.drawRect(
    Rect.fromLTWH(base.dx - s * 0.32, base.dy - s * 0.78, s * 0.64, s * 0.035),
    wood,
  );
  final cloth = Paint()..color = const Color(0xFF2A1A26);
  // The shirt hanging off the bar, ragged at the bottom.
  canvas.drawPath(
    Path()
      ..moveTo(base.dx - s * 0.3, base.dy - s * 0.79)
      ..lineTo(base.dx + s * 0.3, base.dy - s * 0.79)
      ..lineTo(base.dx + s * 0.28, base.dy - s * 0.7)
      ..lineTo(base.dx + s * 0.12, base.dy - s * 0.68)
      ..lineTo(base.dx + s * 0.13, base.dy - s * 0.42)
      ..lineTo(base.dx + s * 0.06, base.dy - s * 0.46)
      ..lineTo(base.dx, base.dy - s * 0.4)
      ..lineTo(base.dx - s * 0.07, base.dy - s * 0.46)
      ..lineTo(base.dx - s * 0.13, base.dy - s * 0.42)
      ..lineTo(base.dx - s * 0.12, base.dy - s * 0.68)
      ..lineTo(base.dx - s * 0.28, base.dy - s * 0.7)
      ..close(),
    cloth,
  );
  // Straw at the cuffs, twitching in the wind.
  final straw = Paint()
    ..strokeWidth = 1.2
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFF6A5420);
  for (final dir in const [-1.0, 1.0]) {
    for (var k = 0; k < 4; k++) {
      final from = Offset(
        base.dx + dir * s * 0.3,
        base.dy - s * (0.78 - k * 0.025),
      );
      final a = dir > 0 ? 0.3 - k * 0.25 : math.pi - 0.3 + k * 0.25;
      final twitch = math.sin(t * 4 + k + dir) * 0.15;
      canvas.drawLine(
        from,
        from + Offset(math.cos(a + twitch), math.sin(a + twitch)) * s * 0.08,
        straw,
      );
    }
  }
  // The sack head, tilting, turning to face you with the set on.
  final tilt = 0.25 * math.sin(t * 0.35) * (1 - night) + 0.05 * night;
  canvas.save();
  canvas.translate(base.dx, base.dy - s * 0.86);
  canvas.rotate(tilt);
  canvas.drawOval(
    Rect.fromCenter(center: Offset.zero, width: s * 0.2, height: s * 0.2),
    Paint()..color = const Color(0xFF3A2A1A),
  );
  // Hat.
  canvas.drawRect(
    Rect.fromLTWH(-s * 0.17, -s * 0.09, s * 0.34, s * 0.025),
    wood,
  );
  canvas.drawPath(
    Path()
      ..moveTo(-s * 0.09, -s * 0.09)
      ..lineTo(-s * 0.06, -s * 0.22)
      ..lineTo(s * 0.08, -s * 0.26)
      ..lineTo(s * 0.09, -s * 0.09)
      ..close(),
    wood,
  );
  // Stitched eyes and grin; burning once the night turns.
  final eye = night > 0
      ? (Paint()..color = _a(const Color(0xFFFF4A1A), 0.4 + 0.6 * night))
      : (Paint()..color = const Color(0xFF0A0604));
  for (final dx in const [-0.045, 0.045]) {
    canvas.drawPath(
      Path()
        ..moveTo(s * dx - s * 0.025, -s * 0.02)
        ..lineTo(s * dx + s * 0.025, -s * 0.02)
        ..lineTo(s * dx, s * 0.015)
        ..close(),
      eye,
    );
  }
  if (night > 0) {
    canvas.drawCircle(
      Offset.zero,
      s * 0.16,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _a(const Color(0xFFFF4A1A), 0.3 * night),
            const Color(0x00FF4A1A),
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: s * 0.16)),
    );
  }
  final stitch = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = const Color(0xFF0A0604);
  canvas.drawArc(
    Rect.fromCenter(
      center: Offset(0, s * 0.02),
      width: s * 0.12,
      height: s * 0.08,
    ),
    0.2,
    math.pi - 0.4,
    false,
    stitch,
  );
  for (var k = 0; k < 5; k++) {
    final x = -s * 0.05 + k * s * 0.025;
    canvas.drawLine(Offset(x, s * 0.045), Offset(x, s * 0.072), stitch);
  }
  canvas.restore();
  // A crow on the crossbar.
  final crow = Offset(base.dx - s * 0.24, base.dy - s * 0.79);
  final ink = Paint()..color = _ink;
  canvas.drawOval(
    Rect.fromCenter(
      center: crow.translate(0, -s * 0.03),
      width: s * 0.07,
      height: s * 0.05,
    ),
    ink,
  );
  canvas.drawCircle(crow.translate(-s * 0.03, -s * 0.06), s * 0.018, ink);
  canvas.drawPath(
    Path()
      ..moveTo(crow.dx + s * 0.03, crow.dy - s * 0.03)
      ..lineTo(crow.dx + s * 0.07, crow.dy - s * 0.01)
      ..lineTo(crow.dx + s * 0.03, crow.dy - s * 0.015)
      ..close(),
    ink,
  );
}

/// A wrought-iron graveyard fence with spear tips, a few bars bent.
void _fence(Canvas canvas, Size size, double y) {
  final w = size.width;
  final iron = Paint()
    ..color = const Color(0xFF05030A)
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.butt;
  canvas.drawLine(
    Offset(0, y - 30),
    Offset(w, y - 34),
    iron..strokeWidth = 2.2,
  );
  canvas.drawLine(Offset(0, y - 6), Offset(w, y - 8), iron..strokeWidth = 2.2);
  const gap = 14.0;
  for (var x = 4.0; x < w; x += gap) {
    final i = (x / gap).round();
    final bent = _rand(i, 580) < 0.12 ? (_rand(i, 581) - 0.5) * 10 : 0.0;
    final top = Offset(x + bent, y - 44 - 4 * _rand(i, 582));
    canvas.drawLine(Offset(x, y + 2), top, iron..strokeWidth = 2);
    canvas.drawPath(
      Path()
        ..moveTo(top.dx - 3.5, top.dy + 2)
        ..lineTo(top.dx, top.dy - 7)
        ..lineTo(top.dx + 3.5, top.dy + 2)
        ..close(),
      iron,
    );
  }
}

/// Will-o'-the-wisps: Stingy Jack's lost lights, bobbing low over the
/// field, leading nowhere good.
void _wisps(Canvas canvas, Size size, double t, int count) {
  final w = size.width;
  final h = size.height;
  for (var i = 0; i < count; i++) {
    final x =
        w * _rand(i, 590) +
        math.sin(t * (0.3 + _rand(i, 591) * 0.3) + i) * w * 0.08;
    final y = h * (0.7 + 0.18 * _rand(i, 592)) + math.sin(t * 1.3 + i * 2) * 8;
    final pulse = 0.5 + 0.5 * math.sin(t * (1.5 + _rand(i, 593)) + i);
    final r = 3 + 2 * pulse;
    canvas.drawCircle(
      Offset(x, y),
      r * 5,
      Paint()
        ..shader = RadialGradient(
          colors: [_a(_wisp, 0.35 * pulse), _a(_wisp, 0)],
        ).createShader(Rect.fromCircle(center: Offset(x, y), radius: r * 5)),
    );
    canvas.drawCircle(
      Offset(x, y),
      r * 0.6,
      Paint()..color = _a(Colors.white, 0.8 * pulse),
    );
  }
}

/// Thick fog rolling across at [y], drifting at [speed].
void _fogBand(
  Canvas canvas,
  Size size,
  double t,
  double y,
  double speed,
  double depth,
) {
  final w = size.width;
  final h = size.height;
  for (var i = 0; i < 7; i++) {
    final span = w * 1.8;
    final x =
        (t * 10 * speed + _rand(i, 600 + y.round()) * span) % span - w * 0.4;
    final puff = Rect.fromCenter(
      center: Offset(x, y + math.sin(t * 0.4 + i) * h * 0.01),
      width: w * (0.6 + 0.3 * _rand(i, 601)),
      height: h * depth,
    );
    canvas.drawOval(
      puff,
      Paint()
        ..shader = RadialGradient(
          colors: [_a(_fog, 0.22), _a(_fog, 0)],
        ).createShader(puff),
    );
  }
}

/// The jack-o'-lantern patch: pumpkins of every size on their vines, each
/// carved with its own face and lit by a flickering candle; one old turnip
/// lantern among them, the way it started. With the set on they blaze and
/// their eyes follow you.
void _patch(Canvas canvas, Size size, double t, double night) {
  final w = size.width;
  final h = size.height;
  // The vines, curling between them.
  final vine = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..color = const Color(0xFF1E2A14);
  canvas.drawPath(
    Path()
      ..moveTo(-10, h * 0.9)
      ..cubicTo(w * 0.2, h * 0.86, w * 0.3, h * 0.95, w * 0.5, h * 0.9)
      ..cubicTo(w * 0.7, h * 0.85, w * 0.8, h * 0.95, w + 10, h * 0.89),
    vine,
  );
  for (final (x, y, s, face) in const [
    (0.14, 0.905, 0.13, 0),
    (0.38, 0.93, 0.09, 1),
    (0.6, 0.915, 0.16, 2),
    (0.86, 0.9, 0.11, 3),
    (0.27, 0.87, 0.06, 1),
    (0.74, 0.865, 0.065, 0),
  ]) {
    _jack(canvas, Offset(w * x, h * y), w * s, t, face, night);
  }
  _turnip(canvas, Offset(w * 0.49, h * 0.875), w * 0.045, t, night);
}

/// One jack-o'-lantern: ribbed and glossy, stem on top, carved [face] lit
/// from inside.
void _jack(
  Canvas canvas,
  Offset c,
  double s,
  double t,
  int face,
  double night,
) {
  final flicker =
      0.75 +
      0.25 * math.sin(t * (9 + face) + face) * math.sin(t * 4.3 + face * 2);
  final light = (flicker * (0.75 + 0.45 * night)).clamp(0.0, 1.2);
  // Its light on the ground.
  canvas.drawOval(
    Rect.fromCenter(
      center: c.translate(0, s * 0.4),
      width: s * 3.2,
      height: s * 0.9,
    ),
    Paint()
      ..shader =
          RadialGradient(
            colors: [_a(_flame, 0.35 * light), _a(_flame, 0)],
          ).createShader(
            Rect.fromCenter(
              center: c.translate(0, s * 0.4),
              width: s * 3.2,
              height: s * 0.9,
            ),
          ),
  );
  final body = Rect.fromCenter(center: c, width: s * 1.5, height: s * 1.1);
  // Ribs: overlapping lobes, darker toward the edges.
  for (final (dx, wide, dark) in const [
    (-0.42, 0.7, 0.35),
    (0.42, 0.7, 0.35),
    (-0.2, 0.75, 0.15),
    (0.2, 0.75, 0.15),
    (0.0, 0.7, 0.0),
  ]) {
    final lobe = Rect.fromCenter(
      center: c.translate(s * dx, 0),
      width: s * wide,
      height: s * 1.1,
    );
    canvas.drawOval(
      lobe,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [
            Color.lerp(const Color(0xFFFFA24A), Colors.black, dark)!,
            Color.lerp(_pumpkin, Colors.black, dark + 0.1)!,
            Color.lerp(const Color(0xFF9A3A08), Colors.black, dark + 0.2)!,
          ],
          stops: const [0, 0.6, 1],
        ).createShader(lobe),
    );
  }
  // Stem.
  canvas.drawPath(
    Path()
      ..moveTo(c.dx - s * 0.07, c.dy - s * 0.5)
      ..quadraticBezierTo(
        c.dx - s * 0.05,
        c.dy - s * 0.72,
        c.dx + s * 0.12,
        c.dy - s * 0.8,
      )
      ..lineTo(c.dx + s * 0.13, c.dy - s * 0.72)
      ..quadraticBezierTo(
        c.dx + s * 0.06,
        c.dy - s * 0.66,
        c.dx + s * 0.07,
        c.dy - s * 0.5,
      )
      ..close(),
    Paint()..color = const Color(0xFF3A3A16),
  );
  // The carved face, glowing.
  final glow = Paint()
    ..shader = RadialGradient(
      colors: [
        _a(const Color(0xFFFFF2B0), light),
        _a(_candle, light),
        _a(_flame, light),
      ],
      stops: const [0, 0.5, 1],
    ).createShader(body);
  final carve = Path();
  final look = night * s * 0.05 * math.sin(t * 0.8);
  switch (face) {
    case 0: // The classic: triangle eyes, triangle nose, a toothy grin.
      for (final dx in const [-0.28, 0.28]) {
        carve
          ..moveTo(c.dx + s * dx - s * 0.14 + look, c.dy - s * 0.08)
          ..lineTo(c.dx + s * dx + look, c.dy - s * 0.32)
          ..lineTo(c.dx + s * dx + s * 0.14 + look, c.dy - s * 0.08)
          ..close();
      }
      carve
        ..moveTo(c.dx - s * 0.06, c.dy + s * 0.03)
        ..lineTo(c.dx, c.dy - s * 0.08)
        ..lineTo(c.dx + s * 0.06, c.dy + s * 0.03)
        ..close()
        ..moveTo(c.dx - s * 0.45, c.dy + s * 0.08)
        ..quadraticBezierTo(
          c.dx,
          c.dy + s * 0.5,
          c.dx + s * 0.45,
          c.dy + s * 0.08,
        )
        ..lineTo(c.dx + s * 0.3, c.dy + s * 0.15)
        ..lineTo(c.dx + s * 0.22, c.dy + s * 0.08)
        ..lineTo(c.dx + s * 0.1, c.dy + s * 0.2)
        ..lineTo(c.dx - s * 0.05, c.dy + s * 0.12)
        ..lineTo(c.dx - s * 0.18, c.dy + s * 0.2)
        ..lineTo(c.dx - s * 0.3, c.dy + s * 0.12)
        ..close();
    case 1: // Angry: slanted eyes and a jagged scowl.
      for (final dir in const [-1.0, 1.0]) {
        carve
          ..moveTo(c.dx + dir * s * 0.1 + look, c.dy - s * 0.12)
          ..lineTo(c.dx + dir * s * 0.45 + look, c.dy - s * 0.3)
          ..lineTo(c.dx + dir * s * 0.35 + look, c.dy - s * 0.05)
          ..close();
      }
      carve.moveTo(c.dx - s * 0.4, c.dy + s * 0.25);
      for (var k = 1; k <= 8; k++) {
        carve.lineTo(
          c.dx - s * 0.4 + k * s * 0.1,
          c.dy + s * (k.isEven ? 0.25 : 0.1),
        );
      }
      carve
        ..lineTo(c.dx + s * 0.3, c.dy + s * 0.35)
        ..quadraticBezierTo(
          c.dx,
          c.dy + s * 0.42,
          c.dx - s * 0.3,
          c.dy + s * 0.35,
        )
        ..close();
    case 2: // The scary one: big hollow eyes and a mouth full of fangs.
      for (final dx in const [-0.28, 0.28]) {
        carve.addOval(
          Rect.fromCenter(
            center: Offset(c.dx + s * dx + look, c.dy - s * 0.15),
            width: s * 0.26,
            height: s * 0.3,
          ),
        );
      }
      carve
        ..moveTo(c.dx - s * 0.5, c.dy + s * 0.05)
        ..quadraticBezierTo(
          c.dx,
          c.dy + s * 0.25,
          c.dx + s * 0.5,
          c.dy + s * 0.05,
        )
        ..quadraticBezierTo(
          c.dx,
          c.dy + s * 0.65,
          c.dx - s * 0.5,
          c.dy + s * 0.05,
        )
        ..close();
    default: // Sly: one eye winking shut, a crooked smirk.
      carve
        ..moveTo(c.dx - s * 0.42 + look, c.dy - s * 0.1)
        ..lineTo(c.dx - s * 0.25 + look, c.dy - s * 0.32)
        ..lineTo(c.dx - s * 0.1 + look, c.dy - s * 0.1)
        ..close()
        ..addRect(
          Rect.fromLTWH(
            c.dx + s * 0.12 + look,
            c.dy - s * 0.2,
            s * 0.28,
            s * 0.06,
          ),
        )
        ..moveTo(c.dx - s * 0.35, c.dy + s * 0.15)
        ..quadraticBezierTo(
          c.dx + s * 0.1,
          c.dy + s * 0.3,
          c.dx + s * 0.45,
          c.dy + s * 0.02,
        )
        ..quadraticBezierTo(
          c.dx + s * 0.15,
          c.dy + s * 0.45,
          c.dx - s * 0.35,
          c.dy + s * 0.15,
        )
        ..close();
  }
  // Candlelight spilling over the face round the cuts.
  final spill = Rect.fromCircle(
    center: c.translate(0, s * 0.05),
    radius: s * 0.62,
  );
  canvas.drawOval(
    spill,
    Paint()
      ..shader = RadialGradient(
        colors: [_a(_candle, 0.35 * light), _a(_candle, 0)],
      ).createShader(spill),
  );
  canvas.drawPath(carve, glow);
}

/// The turnip lantern: how jack-o'-lanterns began, a small pale bulb with
/// a coal glowing through its carved face.
void _turnip(Canvas canvas, Offset c, double s, double t, double night) {
  final light = 0.6 + 0.3 * math.sin(t * 6.3) * math.sin(t * 2.2) + 0.3 * night;
  final bulb = Rect.fromCenter(center: c, width: s * 1.3, height: s * 1.2);
  canvas.drawOval(
    bulb,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        colors: const [Color(0xFFE8DCC8), Color(0xFFB89AB0), Color(0xFF6A4060)],
      ).createShader(bulb),
  );
  canvas.drawLine(
    c.translate(0, -s * 0.6),
    c.translate(s * 0.1, -s * 0.95),
    Paint()
      ..strokeWidth = 2
      ..color = const Color(0xFF3A5A20),
  );
  final face = Paint()
    ..color = _a(const Color(0xFFFF6A1A), light.clamp(0.0, 1.0));
  canvas.drawCircle(c.translate(-s * 0.2, -s * 0.1), s * 0.09, face);
  canvas.drawCircle(c.translate(s * 0.2, -s * 0.1), s * 0.09, face);
  canvas.drawOval(
    Rect.fromCenter(
      center: c.translate(0, s * 0.22),
      width: s * 0.4,
      height: s * 0.14,
    ),
    face,
  );
}

/// Dead leaves tumbling down.
void _leaves(Canvas canvas, Size size, double t) {
  final w = size.width;
  final h = size.height;
  const colors = [Color(0xFF8A3A12), Color(0xFFB0581A), Color(0xFF5A2A10)];
  for (var i = 0; i < 16; i++) {
    final speed = 0.04 + _rand(i, 610) * 0.04;
    final k = (t * speed + _rand(i, 611)) % 1.0;
    final x = w * _rand(i, 612) + math.sin(t * 1.3 + i) * 30;
    final y = -10 + k * (h + 20);
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(t * (1 + _rand(i, 613)) + i);
    canvas.scale(1, 0.4 + 0.6 * math.cos(t * 2 + i).abs());
    canvas.drawPath(
      Path()
        ..moveTo(-5, 0)
        ..quadraticBezierTo(0, -4, 5, 0)
        ..quadraticBezierTo(0, 4, -5, 0)
        ..close(),
      Paint()..color = _a(colors[i % 3], 0.85),
    );
    canvas.restore();
  }
}

/// A spider web strung across the corner, a spider climbing up and down
/// its thread.
void _web(Canvas canvas, Offset corner, double r, double t) {
  final silk = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.9
    ..color = _a(const Color(0xFFD8D0F0), 0.35);
  const spokes = 7;
  final angles = [
    for (var i = 0; i < spokes; i++)
      math.pi / 2 + i * (math.pi / 2) / (spokes - 1),
  ];
  for (final a in angles) {
    canvas.drawLine(
      corner,
      corner + Offset(math.cos(a), math.sin(a)) * r,
      silk,
    );
  }
  for (var ring = 1; ring <= 6; ring++) {
    final d = r * ring / 6.5;
    final path = Path();
    for (var i = 0; i < spokes; i++) {
      final p = corner + Offset(math.cos(angles[i]), math.sin(angles[i])) * d;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        // Sagging between spokes, like real silk.
        final prev =
            corner +
            Offset(math.cos(angles[i - 1]), math.sin(angles[i - 1])) * d;
        final mid = Offset.lerp(prev, p, 0.5)!;
        final sag = mid + (corner - mid) * 0.08;
        path.quadraticBezierTo(sag.dx, sag.dy, p.dx, p.dy);
      }
    }
    canvas.drawPath(path, silk);
  }
  // The spider on its thread.
  final drop = r * (0.5 + 0.35 * math.sin(t * 0.5));
  final anchor = corner + Offset(-r * 0.42, 0);
  final spider = anchor.translate(0, drop);
  canvas.drawLine(anchor, spider, silk);
  final ink = Paint()..color = const Color(0xFF05020A);
  final legs = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2
    ..color = ink.color;
  for (final dir in const [-1.0, 1.0]) {
    for (var k = 0; k < 4; k++) {
      final wiggle = math.sin(t * 6 + k) * 1.5;
      final from = spider.translate(0, -2 + k * 1.6);
      canvas.drawPath(
        Path()
          ..moveTo(from.dx, from.dy)
          ..quadraticBezierTo(
            from.dx + dir * 6,
            from.dy - 5 + k * 2 + wiggle,
            from.dx + dir * 9,
            from.dy + 2 + k * 2.5,
          ),
        legs,
      );
    }
  }
  canvas.drawOval(
    Rect.fromCenter(center: spider.translate(0, 2), width: 7, height: 9),
    ink,
  );
  canvas.drawCircle(spider.translate(0, -3), 2.6, ink);
  canvas.drawCircle(
    spider.translate(-1, -3.4),
    0.7,
    Paint()..color = const Color(0xFFFF3A1A),
  );
  canvas.drawCircle(
    spider.translate(1, -3.4),
    0.7,
    Paint()..color = const Color(0xFFFF3A1A),
  );
}
