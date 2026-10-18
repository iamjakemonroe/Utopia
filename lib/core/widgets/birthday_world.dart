import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/utopia_themes.dart';
import 'world_sets.dart';

/// Stable pseudo-random 0-1 from an index.
double _rand(int i, int salt) {
  final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

Color _a(Color c, double alpha) =>
    c.withValues(alpha: (c.a * alpha).clamp(0.0, 1.0));

const _pink = Color(0xFFFF6FAE);
const _coral = Color(0xFFFF8A65);
const _gold = Color(0xFFFFD166);
const _mint = Color(0xFF6EE7B7);
const _blue = Color(0xFF64B5F6);
const _lilac = Color(0xFFB39DDB);
const _cream = Color(0xFFFFF4E0);
const _party = [_pink, _gold, _mint, _blue, _lilac, _coral];

/// The Birthday world: only ever seen on the player's own birthday. A
/// pastel dusk with a party in the sky: HAPPY BIRTHDAY spelled out on
/// bunting, fireworks bursting, balloons drifting up past the clouds, and
/// confetti falling. On a floating island below, a three-tier cake with its
/// candles flickering, presents (one keeps popping its lid open), a bunch
/// of balloons tied to them and fairy lights round the edge.
///
/// With the set on (the Birthday frame worn here, [WorldSets.birthday])
/// the party peaks: twice the fireworks and the candles blaze.
void paintBirthdayScene(
  Canvas canvas,
  Size size,
  double t,
  WorldStyle style, {
  required Offset sun,
}) {
  final w = size.width;
  final h = size.height;
  final party = WorldSets.birthday.amount;
  final island = Offset(w * 0.5, h * 0.74);

  _clouds(canvas, size, t, style);
  _fireworks(canvas, size, t, 3 + (party * 3).round());
  _risingBalloons(canvas, size, t);
  _bunting(
    canvas,
    Offset(-w * 0.04, h * 0.155),
    Offset(w * 0.56, h * 0.13),
    h * 0.05,
    'HAPPY',
    t,
    0,
  );
  _bunting(
    canvas,
    Offset(w * 0.44, h * 0.205),
    Offset(w * 1.04, h * 0.18),
    h * 0.05,
    'BIRTHDAY',
    t,
    7,
  );
  _island(canvas, island, w, t, style, party);
  _confetti(canvas, size, t, 46 + (party * 24).round());

  // A warm glow at the edges keeps the eye on the party.
  final rect = Offset.zero & size;
  canvas.drawRect(
    rect,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, 0.1),
        radius: 1.0,
        colors: [Colors.transparent, _a(const Color(0xFF1A0B33), 0.42)],
        stops: const [0.6, 1],
      ).createShader(rect),
  );
}

/// Soft pastel clouds drifting across the dusk.
void _clouds(Canvas canvas, Size size, double t, WorldStyle style) {
  final w = size.width;
  final h = size.height;
  for (var i = 0; i < 5; i++) {
    final speed = 4 + _rand(i, 10) * 6;
    final span = w * 1.6;
    final x = (_rand(i, 11) * span + t * speed) % span - w * 0.3;
    final y = h * (0.3 + 0.32 * _rand(i, 12));
    final s = w * (0.14 + 0.1 * _rand(i, 13));
    final light = Paint()..color = _a(style.cloudLight, 0.55);
    final shade = Paint()..color = _a(style.cloudShade, 0.35);
    for (final (dx, dy, r) in const [
      (0.0, 0.0, 0.5),
      (-0.45, 0.12, 0.36),
      (0.45, 0.1, 0.4),
      (0.15, -0.22, 0.38),
    ]) {
      canvas.drawCircle(
        Offset(x + dx * s, y + dy * s + s * 0.08),
        r * s,
        shade,
      );
    }
    for (final (dx, dy, r) in const [
      (0.0, 0.0, 0.5),
      (-0.45, 0.12, 0.36),
      (0.45, 0.1, 0.4),
      (0.15, -0.22, 0.38),
    ]) {
      canvas.drawCircle(Offset(x + dx * s, y + dy * s), r * s, light);
    }
  }
}

/// Fireworks: each one climbs on a fading trail, bursts into a ring of
/// sparks that droop and twinkle out, then goes again somewhere new.
void _fireworks(Canvas canvas, Size size, double t, int count) {
  final w = size.width;
  final h = size.height;
  for (var i = 0; i < count; i++) {
    final period = 3.6 + _rand(i, 20) * 2.2;
    final shift = _rand(i, 21) * period;
    final local = (t + shift) % period / period;
    final round = ((t + shift) / period).floor();
    final x = w * (0.14 + 0.72 * _rand(round * 7 + i, 22));
    final top = h * (0.17 + 0.24 * _rand(round * 7 + i, 23));
    final color = _party[(round + i) % _party.length];
    final launch = Offset(x + (_rand(round + i, 24) - 0.5) * w * 0.1, h * 0.7);
    if (local < 0.22) {
      // Climbing.
      final k = Curves.easeOut.transform(local / 0.22);
      final p = Offset.lerp(launch, Offset(x, top), k)!;
      canvas.drawLine(
        Offset.lerp(launch, Offset(x, top), (k - 0.12).clamp(0.0, 1.0))!,
        p,
        Paint()
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(
            colors: [_a(color, 0), _a(_cream, 0.9)],
          ).createShader(Rect.fromPoints(launch, p)),
      );
      canvas.drawCircle(p, 2.2, Paint()..color = _cream);
      continue;
    }
    // Bursting and falling.
    final k = (local - 0.22) / 0.78;
    final spread =
        Curves.easeOut.transform(k) * w * (0.12 + 0.06 * _rand(i, 25));
    final fade = 1 - k * k;
    final droop = k * k * h * 0.06;
    final sparks = 22 + (i % 3) * 6;
    if (k < 0.3) {
      final flash = 1 - k / 0.3;
      canvas.drawCircle(
        Offset(x, top),
        spread * 0.9 + 12,
        Paint()
          ..color = _a(color, 0.45 * flash)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
      canvas.drawCircle(Offset(x, top), 5 * flash, Paint()..color = _cream);
    }
    for (var s = 0; s < sparks; s++) {
      final a = s / sparks * math.pi * 2 + round * 0.4;
      final r = spread * (0.75 + 0.25 * _rand(s + i * 40, 26));
      final p = Offset(x + math.cos(a) * r, top + math.sin(a) * r + droop);
      final tail = Offset(
        x + math.cos(a) * r * 0.82,
        top + math.sin(a) * r * 0.82 + droop * 0.85,
      );
      final twinkle = 0.7 + 0.3 * math.sin(t * 30 + s * 2.1);
      final spark = s.isEven ? color : Color.lerp(color, _cream, 0.6)!;
      canvas.drawLine(
        tail,
        p,
        Paint()
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..color = _a(spark, fade * twinkle),
      );
      canvas.drawCircle(
        p,
        3.2,
        Paint()
          ..color = _a(spark, 0.5 * fade * twinkle)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }
}

/// Balloons let go somewhere below, drifting up past everything, strings
/// trailing and swinging.
void _risingBalloons(Canvas canvas, Size size, double t) {
  final w = size.width;
  final h = size.height;
  for (var i = 0; i < 6; i++) {
    final period = 15 + _rand(i, 30) * 8;
    final k = (t / period + _rand(i, 31)) % 1;
    final r = w * (0.035 + 0.02 * _rand(i, 32));
    final x =
        w * (0.08 + 0.84 * _rand(i, 33)) + math.sin(t * 0.8 + i * 2) * w * 0.03;
    final y = h * 1.1 - k * h * 1.35;
    _balloon(
      canvas,
      Offset(x, y),
      r,
      _party[i % _party.length],
      t + i,
      stringLength: r * 3.2,
    );
  }
}

/// One balloon at [c] (its middle), with a highlight, a knot and a string.
void _balloon(
  Canvas canvas,
  Offset c,
  double r,
  Color color,
  double t, {
  required double stringLength,
  Offset? tiedTo,
}) {
  final knot = c + Offset(0, r * 1.18);
  final string = Path()..moveTo(knot.dx, knot.dy);
  final end =
      tiedTo ?? knot + Offset(math.sin(t * 1.3) * r * 0.5, stringLength);
  final mid =
      Offset.lerp(knot, end, 0.5)! + Offset(math.sin(t * 2.1) * r * 0.4, 0);
  string.quadraticBezierTo(mid.dx, mid.dy, end.dx, end.dy);
  canvas.drawPath(
    string,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _a(_cream, 0.7),
  );
  final body = Rect.fromCenter(center: c, width: r * 1.8, height: r * 2.2);
  canvas.drawOval(
    body,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.4),
        radius: 0.9,
        colors: [
          Color.lerp(color, Colors.white, 0.45)!,
          color,
          Color.lerp(color, Colors.black, 0.28)!,
        ],
        stops: const [0, 0.55, 1],
      ).createShader(body),
  );
  canvas.drawPath(
    Path()
      ..moveTo(knot.dx - r * 0.14, knot.dy + r * 0.12)
      ..lineTo(knot.dx + r * 0.14, knot.dy + r * 0.12)
      ..lineTo(knot.dx, knot.dy - r * 0.06)
      ..close(),
    Paint()..color = Color.lerp(color, Colors.black, 0.2)!,
  );
  canvas.drawOval(
    Rect.fromCenter(
      center: c + Offset(-r * 0.35, -r * 0.5),
      width: r * 0.32,
      height: r * 0.55,
    ),
    Paint()..color = Colors.white.withValues(alpha: 0.55),
  );
}

/// The flag letters, laid out once (and again once the app's display font
/// has loaded, so none are left in the fallback font).
final Map<String, TextPainter> _letters = {};
bool _fontsAsked = false;

TextPainter _letter(String ch, double size) {
  if (!_fontsAsked) {
    _fontsAsked = true;
    GoogleFonts.pendingFonts().then((_) => _letters.clear());
  }
  final key = '$ch@${size.toStringAsFixed(1)}';
  return _letters.putIfAbsent(key, () {
    final painter = TextPainter(
      text: TextSpan(
        text: ch,
        style: GoogleFonts.spaceGrotesk(
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF3A1F5C),
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter;
  });
}

/// A string of bunting from [from] to [to], sagging by [sag], a pennant
/// for each letter of [word], swaying in the breeze.
void _bunting(
  Canvas canvas,
  Offset from,
  Offset to,
  double sag,
  String word,
  double t,
  int seed,
) {
  Offset at(double k) {
    final p = Offset.lerp(from, to, k)!;
    return p + Offset(0, 4 * sag * k * (1 - k));
  }

  final rope = Path()..moveTo(from.dx, from.dy);
  for (var k = 1; k <= 24; k++) {
    final p = at(k / 24);
    rope.lineTo(p.dx, p.dy);
  }
  canvas.drawPath(
    rope,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = _a(_cream, 0.85),
  );

  final n = word.length;
  final gap = (to - from).distance / (n + 1);
  final flagW = gap * 0.86;
  final flagH = flagW * 1.15;
  for (var i = 0; i < n; i++) {
    final k = (i + 1) / (n + 1);
    final p = at(k);
    final next = at(math.min(1, k + 0.01));
    final slope = math.atan2(next.dy - p.dy, next.dx - p.dx);
    final sway = math.sin(t * 1.6 + (i + seed) * 0.9) * 0.12;
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(slope + sway);
    final color = _party[(i + seed) % _party.length];
    final flag = Path()
      ..moveTo(-flagW / 2, 0)
      ..lineTo(flagW / 2, 0)
      ..lineTo(0, flagH)
      ..close();
    canvas.drawPath(flag, Paint()..color = color);
    canvas.drawPath(
      Path()
        ..moveTo(-flagW / 2, 0)
        ..lineTo(0, flagH)
        ..lineTo(-flagW * 0.1, 0)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
    final letter = _letter(word[i], flagW * 0.5);
    letter.paint(canvas, Offset(-letter.width / 2, flagH * 0.16));
    canvas.restore();
  }
}

/// The floating island with the cake, the presents, a bunch of balloons
/// tied to them, and fairy lights round its edge.
void _island(
  Canvas canvas,
  Offset c,
  double w,
  double t,
  WorldStyle style,
  double party,
) {
  final u = w * 0.1;
  final bob = math.sin(t * 0.7) * u * 0.06;
  final top = c.translate(0, bob);
  final rx = w * 0.38;
  final ry = u * 0.42;

  // The rock underneath, tapering to a point, with a few loose stones.
  final under = Path()..moveTo(top.dx - rx, top.dy);
  for (var k = 0; k <= 12; k++) {
    final f = k / 12;
    final x = top.dx - rx + f * rx * 2;
    final depth = math.sin(f * math.pi) * u * (1.8 + 0.5 * _rand(k, 40));
    under.lineTo(x, top.dy + depth);
  }
  under.close();
  canvas.drawPath(
    under,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [style.rock[0], style.rock[1], style.rock[2]],
      ).createShader(Rect.fromLTWH(top.dx - rx, top.dy, rx * 2, u * 2.4)),
  );
  for (var i = 0; i < 3; i++) {
    final p =
        top +
        Offset((i - 1) * rx * 0.7, u * (2.2 + 0.3 * i)) +
        Offset(0, math.sin(t * 0.9 + i) * u * 0.1);
    final stone = Rect.fromCenter(
      center: p,
      width: u * (0.42 - 0.08 * i),
      height: u * (0.3 - 0.05 * i),
    );
    canvas.drawOval(
      stone,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [style.rock[0], style.rock[2]],
        ).createShader(stone),
    );
  }

  // The lawn on top, with a frosting-white rim.
  final lawn = Rect.fromCenter(center: top, width: rx * 2, height: ry * 2);
  canvas.drawOval(
    lawn,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [style.land[0], style.land[1]],
      ).createShader(lawn),
  );
  canvas.drawOval(
    lawn,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 0.08
      ..color = _a(_cream, 0.7),
  );

  // Fairy lights hanging along the front edge.
  for (var i = 0; i < 13; i++) {
    final f = i / 12;
    final x = top.dx - rx * 0.96 + f * rx * 1.92;
    final y = top.dy + ry * 0.96 * math.sin(f * math.pi) + u * 0.12;
    final on = 0.55 + 0.45 * math.sin(t * 3 + i * 1.7);
    final color = _party[i % _party.length];
    canvas.drawCircle(
      Offset(x, y),
      u * 0.16,
      Paint()
        ..color = _a(color, 0.35 * on)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      Offset(x, y),
      u * 0.06,
      Paint()..color = _a(color, 0.6 + 0.4 * on),
    );
  }

  final ground = top.dy - ry * 0.2;
  // The balloons tied to the presents, behind everything on the lawn.
  final tie = Offset(top.dx + u * 2.55, ground - u * 0.7);
  for (var i = 0; i < 6; i++) {
    final a =
        -math.pi / 2 + 0.22 + (i - 2.5) * 0.24 + math.sin(t * 0.9 + i) * 0.05;
    final len = u * (2.4 + 0.5 * _rand(i, 41));
    final p = tie + Offset(math.cos(a) * len, math.sin(a) * len);
    _balloon(
      canvas,
      p,
      u * (0.36 + 0.06 * _rand(i, 42)),
      _party[(i + 2) % _party.length],
      t + i,
      stringLength: 0,
      tiedTo: tie,
    );
  }

  _gift(canvas, Offset(top.dx - u * 2.6, ground), u * 1.05, _blue, _gold, t, 0);
  _gift(canvas, Offset(top.dx + u * 2.5, ground), u * 1.2, _pink, _cream, t, 1);
  _gift(
    canvas,
    Offset(top.dx + u * 2.5, ground - u * 1.2),
    u * 0.75,
    _mint,
    _pink,
    t,
    2,
    pops: true,
  );
  _cake(canvas, Offset(top.dx, ground), u, t, party);
}

/// A wrapped present standing on [base] (the middle of its bottom edge).
/// One [pops] its lid open now and then, letting out a puff of confetti.
void _gift(
  Canvas canvas,
  Offset base,
  double s,
  Color paper,
  Color ribbon,
  double t,
  int seed, {
  bool pops = false,
}) {
  final box = Rect.fromLTWH(base.dx - s / 2, base.dy - s * 0.8, s, s * 0.8);
  canvas.drawRRect(
    RRect.fromRectAndRadius(box, Radius.circular(s * 0.06)),
    Paint()
      ..shader = LinearGradient(
        colors: [Color.lerp(paper, Colors.white, 0.2)!, paper],
      ).createShader(box),
  );
  final band = Paint()..color = ribbon;
  canvas.drawRect(
    Rect.fromCenter(center: box.center, width: s * 0.16, height: box.height),
    band,
  );

  // The lid, hopping up on a cycle if this one pops.
  var lift = 0.0;
  var burst = -1.0;
  if (pops) {
    final local = (t + seed * 1.3) % 6.0;
    if (local < 0.9) {
      lift = math.sin(local / 0.9 * math.pi) * s * 0.55;
      burst = local / 0.9;
    }
  }
  final lid = Rect.fromLTWH(
    box.left - s * 0.06,
    box.top - s * 0.2 - lift,
    s * 1.12,
    s * 0.22,
  );
  canvas.save();
  canvas.translate(lid.center.dx, lid.center.dy);
  canvas.rotate(lift > 0 ? -0.25 * lift / (s * 0.55) : 0);
  canvas.translate(-lid.center.dx, -lid.center.dy);
  canvas.drawRRect(
    RRect.fromRectAndRadius(lid, Radius.circular(s * 0.05)),
    Paint()..color = Color.lerp(paper, Colors.black, 0.08)!,
  );
  canvas.drawRect(
    Rect.fromCenter(center: lid.center, width: s * 0.16, height: lid.height),
    band,
  );
  // The bow.
  for (final side in const [-1.0, 1.0]) {
    canvas.drawOval(
      Rect.fromCenter(
        center: lid.topCenter + Offset(side * s * 0.13, -s * 0.06),
        width: s * 0.26,
        height: s * 0.16,
      ),
      band,
    );
  }
  canvas.restore();

  if (burst >= 0) {
    for (var i = 0; i < 14; i++) {
      final a = -math.pi / 2 + (_rand(i, 50) - 0.5) * 1.8;
      final d = burst * s * (0.9 + _rand(i, 51));
      final p =
          Offset(box.center.dx, box.top) +
          Offset(math.cos(a) * d, math.sin(a) * d + burst * burst * s * 0.4);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(burst * 8 + i);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: s * 0.09, height: s * 0.05),
        Paint()..color = _a(_party[i % _party.length], 1 - burst),
      );
      canvas.restore();
    }
  }
}

/// The cake: three tiers (strawberry, vanilla with dots, mint with
/// sprinkles), drips of icing, and candles flickering on top. With the set
/// on, the flames blaze.
void _cake(Canvas canvas, Offset base, double u, double t, double party) {
  final plate = Rect.fromCenter(
    center: base + Offset(0, u * 0.05),
    width: u * 3.9,
    height: u * 0.4,
  );
  canvas.drawOval(plate, Paint()..color = _a(_cream, 0.9));
  canvas.drawOval(
    plate.deflate(u * 0.06),
    Paint()..color = const Color(0xFFE8D9C3),
  );

  var floor = base.dy - u * 0.02;
  final tiers = [
    (3.3, 1.15, const Color(0xFFFF8FB9), _cream),
    (2.45, 0.98, _cream, const Color(0xFFFF8FB9)),
    (1.65, 0.85, const Color(0xFF9FF0CF), _cream),
  ];
  for (final (i, (width, height, sponge, icing)) in tiers.indexed) {
    final rect = Rect.fromLTWH(
      base.dx - width * u / 2,
      floor - height * u,
      width * u,
      height * u,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(u * 0.12)),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Color.lerp(sponge, Colors.white, 0.18)!,
            sponge,
            Color.lerp(sponge, Colors.black, 0.08)!,
          ],
        ).createShader(rect),
    );
    // Icing poured over the top, dripping down the sides.
    final drip = Path()..moveTo(rect.left, rect.top);
    final drips = 7 + i;
    for (var k = 0; k <= drips; k++) {
      final x = rect.left + rect.width * k / drips;
      final len = u * (0.16 + 0.22 * _rand(k + i * 10, 60));
      drip.lineTo(x - rect.width / drips * 0.5, rect.top + u * 0.1);
      drip.quadraticBezierTo(
        x - rect.width / drips * 0.25,
        rect.top + len + u * 0.1,
        x,
        rect.top + u * 0.1,
      );
    }
    drip
      ..lineTo(rect.right, rect.top)
      ..close();
    canvas.drawPath(drip, Paint()..color = icing);
    if (i == 1) {
      // Polka dots.
      for (var k = 0; k < 6; k++) {
        canvas.drawCircle(
          Offset(
            rect.left + rect.width * (k + 0.5) / 6,
            rect.center.dy + u * 0.18,
          ),
          u * 0.07,
          Paint()..color = _party[k % _party.length],
        );
      }
    } else {
      // Sprinkles.
      for (var k = 0; k < 14; k++) {
        final p = Offset(
          rect.left + rect.width * (0.06 + 0.88 * _rand(k + i * 20, 61)),
          rect.top + rect.height * (0.45 + 0.45 * _rand(k + i * 20, 62)),
        );
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.rotate(_rand(k, 63) * math.pi);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: u * 0.14,
              height: u * 0.04,
            ),
            Radius.circular(u * 0.02),
          ),
          Paint()..color = _party[(k + i) % _party.length],
        );
        canvas.restore();
      }
    }
    floor = rect.top;
  }

  // The candles, striped, each with its own flicker.
  final blaze = 1 + 0.6 * party;
  for (var k = 0; k < 5; k++) {
    final x = base.dx + (k - 2) * u * 0.32;
    final candle = Rect.fromLTWH(
      x - u * 0.06,
      floor - u * 0.62,
      u * 0.12,
      u * 0.62,
    );
    canvas.drawRect(candle, Paint()..color = _cream);
    for (var s = 0; s < 4; s++) {
      canvas.drawLine(
        Offset(candle.left, candle.top + candle.height * (s + 0.3) / 4),
        Offset(candle.right, candle.top + candle.height * (s + 0.5) / 4),
        Paint()
          ..strokeWidth = u * 0.04
          ..color = _party[(k + s) % _party.length],
      );
    }
    final flick =
        0.85 + 0.15 * math.sin(t * 18 + k * 2.3) + 0.08 * math.sin(t * 31 + k);
    final tip = Offset(
      x + math.sin(t * 7 + k) * u * 0.03,
      candle.top - u * 0.08,
    );
    canvas.drawCircle(
      tip.translate(0, -u * 0.1),
      u * 0.3 * flick * blaze,
      Paint()
        ..color = _a(_gold, 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    final fh = u * 0.3 * flick * blaze;
    final flame = Path()
      ..moveTo(tip.dx, tip.dy - fh)
      ..quadraticBezierTo(tip.dx + u * 0.1, tip.dy - fh * 0.3, tip.dx, tip.dy)
      ..quadraticBezierTo(
        tip.dx - u * 0.1,
        tip.dy - fh * 0.3,
        tip.dx,
        tip.dy - fh,
      )
      ..close();
    canvas.drawPath(flame, Paint()..color = const Color(0xFFFFB238));
    canvas.drawOval(
      Rect.fromCenter(
        center: tip.translate(0, -fh * 0.28),
        width: u * 0.07,
        height: fh * 0.4,
      ),
      Paint()..color = const Color(0xFFFFF6D5),
    );
  }
}

/// Confetti fluttering down over everything, each piece tumbling.
void _confetti(Canvas canvas, Size size, double t, int count) {
  final w = size.width;
  final h = size.height;
  for (var i = 0; i < count; i++) {
    final speed = 0.05 + 0.05 * _rand(i, 70);
    final k = (t * speed + _rand(i, 71)) % 1;
    final x = w * _rand(i, 72) + math.sin(t * 1.2 + i) * w * 0.03;
    final y = -h * 0.05 + k * h * 1.1;
    final spin = t * (2 + 3 * _rand(i, 73)) + i;
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(spin);
    canvas.scale(math.cos(spin * 1.3), 1);
    final color = _party[i % _party.length];
    if (i % 4 == 0) {
      canvas.drawCircle(Offset.zero, 2.6, Paint()..color = color);
    } else {
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: 7, height: 3.6),
        Paint()..color = color,
      );
    }
    canvas.restore();
  }
}
