import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The fire dragon's colours.
class FireDragonColors {
  const FireDragonColors({
    required this.top,
    required this.body,
    required this.shadow,
    required this.belly,
    required this.membrane,
    required this.membraneDeep,
    required this.horn,
    required this.eye,
  });

  /// The hide: lit back, middle, shadowed underside.
  final Color top;
  final Color body;
  final Color shadow;

  /// Throat and belly plates.
  final Color belly;

  /// Wing membrane, near the bones and out at the edge.
  final Color membrane;
  final Color membraneDeep;

  /// Horns, spines and claws.
  final Color horn;
  final Color eye;

  /// Crimson with an ember belly and bone-white horns.
  static const crimson = FireDragonColors(
    top: Color(0xFFF0573F),
    body: Color(0xFFB8202C),
    shadow: Color(0xFF4A0A18),
    belly: Color(0xFFFFB063),
    membrane: Color(0xFFD8343F),
    membraneDeep: Color(0xFF4A0C24),
    horn: Color(0xFFF6E2B8),
    eye: Color(0xFFFFE04A),
  );

  /// Set free: hotter all over.
  static const blazing = FireDragonColors(
    top: Color(0xFFFF7A4A),
    body: Color(0xFFD62A2A),
    shadow: Color(0xFF5A0A12),
    belly: Color(0xFFFFC870),
    membrane: Color(0xFFF04A3A),
    membraneDeep: Color(0xFF5A0E1E),
    horn: Color(0xFFFFEFC8),
    eye: Color(0xFFFFF27A),
  );
}

/// A point on the dragon's spine and how far the body reaches above and
/// below it there.
class _Joint {
  const _Joint(this.p, this.up, this.down);

  final Offset p;
  final double up;
  final double down;
}

/// Where the dragon is in its breath of fire at [t]: drawing in (rearing
/// back), breathing (lunging, jaw open, fire pouring out), recovering.
class _Breath {
  const _Breath({
    required this.inhale,
    required this.lunge,
    required this.jaw,
    required this.fire,
    required this.fade,
  });

  /// 0-1 drawing breath: the neck rears back, the throat glows.
  final double inhale;

  /// 0-1 thrown forward into the blast.
  final double lunge;

  /// How far the jaw hangs open, in radians.
  final double jaw;

  /// Seconds into the blast (negative before it).
  final double fire;

  /// 0-1 how much fire there still is.
  final double fade;

  static _Breath at(double t, double every) {
    final k = t % every;
    const draw = 0.7, blast = 1.7, rest = 0.5;
    if (k < draw) {
      final e = Curves.easeInOut.transform(k / draw);
      return _Breath(inhale: e, lunge: 0, jaw: 0.05 * e, fire: -1, fade: 0);
    }
    if (k < draw + blast) {
      final b = k - draw;
      final into = Curves.easeOut.transform((b / 0.25).clamp(0.0, 1.0));
      return _Breath(
        inhale: 1 - into,
        lunge: into,
        jaw: 0.08 + 0.5 * into,
        fire: b,
        fade: 1,
      );
    }
    if (k < draw + blast + rest) {
      final r = (k - draw - blast) / rest;
      final e = Curves.easeInOut.transform(r);
      return _Breath(
        inhale: 0,
        lunge: 1 - e,
        jaw: 0.58 * (1 - e),
        fire: blast + r * rest,
        fade: 1 - e,
      );
    }
    return const _Breath(inhale: 0, lunge: 0, jaw: 0, fire: -1, fade: 0);
  }
}

/// Catmull-Rom through [p] for smooth outlines from a few points.
List<Offset> _smooth(List<Offset> p, {int steps = 6}) {
  if (p.length < 3) return p;
  final out = <Offset>[];
  Offset at(int i) => p[i.clamp(0, p.length - 1)];
  for (var i = 0; i < p.length - 1; i++) {
    final p0 = at(i - 1), p1 = at(i), p2 = at(i + 1), p3 = at(i + 2);
    for (var k = 0; k < steps; k++) {
      final u = k / steps, u2 = u * u, u3 = u2 * u;
      out.add(
        (p1 * 2 +
                (p2 - p0) * u +
                (p0 * 2 - p1 * 5 + p2 * 4 - p3) * u2 +
                (p1 * 3 - p0 - p2 * 3 + p3) * u3) *
            0.5,
      );
    }
  }
  out.add(p.last);
  return out;
}

Offset _dir(double a) => Offset(math.cos(a), math.sin(a));

/// Rotates [v] by [a].
Offset _rot(Offset v, double a) {
  final c = math.cos(a), s = math.sin(a);
  return Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
}

/// The fire dragon in flight, facing +x, centred on [at], [s] pixels to a
/// unit (it's about four and a half units nose to tail). One spine runs
/// from the back of its skull down a long S of a neck, along the body and
/// out to the tip of a tail that ripples behind it, and the hide is
/// wrapped round that spine, so head, neck, body and tail are one creature.
/// Big bat wings beat with a hard downstroke. Every [breathEvery] seconds
/// it rears back, draws breath, then lunges and pours fire from its open
/// jaws; [fireScale] sets how far the fire reaches.
void paintFireDragon(
  Canvas canvas,
  Offset at,
  double s,
  double t,
  FireDragonColors col, {
  bool facingLeft = false,
  double tilt = 0,
  double breathEvery = 7,
  double fireScale = 1,
}) {
  final breath = _Breath.at(t, breathEvery);
  // The wingbeat: 1 wings up, -1 at the bottom of a hard downstroke; the
  // recovery stroke is slower.
  const period = 1.35;
  final k = (t % period) / period;
  final beat = k < 0.36
      ? math.cos(k / 0.36 * math.pi)
      : -math.cos((k - 0.36) / 0.64 * math.pi);
  // The body rides up as the wings push down.
  final bob = 0.07 * beat;

  canvas.save();
  canvas.translate(at.dx, at.dy);
  canvas.rotate(tilt);
  canvas.scale(facingLeft ? -s : s, s);
  // Centre the creature on [at].
  canvas.translate(0.3, 0.05 + bob);

  final spine = _spineAt(t, breath);
  final head = spine.head;

  // Back to front: far wing, far legs, the hide, belly, spines, near legs,
  // head, near wing, then the fire over everything.
  _wing(canvas, t, beat - 0.12, col, far: true);
  _leg(canvas, const Offset(-1.05, 0.24), t, col, far: true);
  _arm(canvas, const Offset(0.02, 0.28), t, col, far: true);
  _hide(canvas, spine.joints, col);
  _belly(canvas, spine.joints, spine.neckJoints, col);
  _spines(canvas, spine.joints, col);
  _leg(canvas, const Offset(-0.95, 0.27), t, col, far: false);
  _arm(canvas, const Offset(0.1, 0.3), t, col, far: false);
  _head(canvas, head.$1, head.$2, t, breath, col);
  _wing(canvas, t, beat, col, far: false);
  if (breath.fire >= 0 && breath.fade > 0) {
    _fire(canvas, head.$1, head.$2, breath, t, fireScale);
  }
  canvas.restore();
}

/// The fire dragon wound round a picture of radius [r] at [c], for the
/// Dragon Coil aura. Its body circles the frame, back and spines out,
/// belly in, from a tail that lifts off the frame and curls (top right)
/// all the way round to its chest; from there its neck rises in an S to
/// the head, in profile, with its wings half raised behind it, flexing.
/// Every few seconds it rears, draws breath and pours fire out over the
/// side, away from the picture. Nothing crosses the picture itself.
/// [lite] (small avatars) skips the costly soft edges.
void paintFireDragonCoiled(
  Canvas canvas,
  Offset c,
  double r,
  double t,
  FireDragonColors col, {
  bool lite = false,
}) {
  final breath = _Breath.at(t, 6.5);
  canvas.save();
  canvas.translate(c.dx, c.dy);
  // The picture is 3 units across the radius.
  canvas.scale(r / 3);
  final coil = _coilSpine(t, breath);

  // The wings, from the shoulders: resting half raised and flexing, thrown
  // up as it rears to breathe.
  final flare = math.max(breath.inhale, breath.lunge);
  final beat = 0.8 + 0.12 * math.sin(t * 1.3) + 0.2 * flare;
  void wing({required bool far}) {
    canvas.save();
    canvas.translate(coil.chest.dx, coil.chest.dy);
    canvas.rotate(coil.chestAngle);
    // The far wing a little further back along the body.
    canvas.translate(far ? -0.45 : -0.15, 0.04);
    canvas.scale(1.3);
    _wing(canvas, t, far ? beat - 0.2 : beat, col, far: far);
    canvas.restore();
  }

  wing(far: true);
  _coilHide(canvas, coil.joints, col, lite: lite);
  _belly(canvas, coil.joints, coil.neckJoints, col, start: 7);
  _spines(canvas, coil.joints, col, size: 1.7);
  _tailSpade(canvas, coil.joints, col);
  // A big head on a long neck, the fire scaled with it.
  final (back, angle) = coil.head;
  canvas.save();
  canvas.translate(back.dx, back.dy);
  canvas.scale(_coilHead);
  _head(canvas, Offset.zero, angle, t, breath, col);
  canvas.restore();
  wing(far: false);
  if (breath.fire >= 0 && breath.fade > 0) {
    canvas.save();
    canvas.translate(back.dx, back.dy);
    canvas.scale(_coilHead);
    _fire(canvas, Offset.zero, angle, breath, t, lite ? 0.7 : 0.95, lite: lite);
    canvas.restore();
  }
  canvas.restore();
}

/// How much bigger than the flying dragon's the coiled one's head is.
const _coilHead = 1.55;

/// A spade at the tip of the tail.
void _tailSpade(Canvas canvas, List<_Joint> j, FireDragonColors col) {
  final tip = j.first.p;
  final d = tip - j[2].p;
  final dir = d / (d.distance == 0 ? 1 : d.distance);
  final side = Offset(-dir.dy, dir.dx);
  final spade = Path()
    ..moveTo(tip.dx, tip.dy)
    ..quadraticBezierTo(
      (tip + side * 0.2 + dir * 0.05).dx,
      (tip + side * 0.2 + dir * 0.05).dy,
      (tip + dir * 0.42).dx,
      (tip + dir * 0.42).dy,
    )
    ..quadraticBezierTo(
      (tip - side * 0.2 + dir * 0.05).dx,
      (tip - side * 0.2 + dir * 0.05).dy,
      tip.dx,
      tip.dy,
    )
    ..close();
  canvas.drawPath(
    spade,
    Paint()
      ..shader = ui.Gradient.linear(tip, tip + dir * 0.42, [col.body, col.top]),
  );
  canvas.drawPath(
    spade,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.018
      ..color = col.shadow,
  );
}

class _Coil {
  const _Coil(
    this.joints,
    this.neckJoints,
    this.head,
    this.chest,
    this.chestAngle,
  );

  /// Tail tip first, to the back of the skull last.
  final List<_Joint> joints;
  final int neckJoints;
  final (Offset, double) head;

  /// Where the neck rises off the frame, and which way the body runs there.
  final Offset chest;
  final double chestAngle;
}

_Coil _coilSpine(double t, _Breath b) {
  // The body lies along a circle round the picture (radius 3), running
  // clockwise from the tail to the chest so its back faces out.
  const ring = 3.45;
  const chestAt = -1.32; // just right of the top
  const tailAt = chestAt - 2 * math.pi + 0.75; // where the tail lifts off
  Offset onRing(double a, double rr) => _dir(a) * rr;

  final joints = <_Joint>[];
  // The end of the tail, lifted off the frame and curling out, swaying.
  final flick = <Offset>[];
  var q = onRing(tailAt, ring);
  var heading = tailAt - math.pi / 2;
  for (var i = 0; i < 7; i++) {
    heading += 0.42 + 0.14 * math.sin(t * 1.7 - i * 0.6);
    q += _dir(heading) * 0.17;
    flick.add(q);
  }
  for (var i = flick.length - 1; i >= 0; i--) {
    final w = 0.04 + 0.014 * (flick.length - 1 - i);
    joints.add(_Joint(flick[i], w * 0.95, w));
  }
  // Round the frame, thickening from the tail to the body, the coils
  // shifting a little as it breathes.
  const steps = 44;
  final swell = 0.03 * b.inhale;
  for (var i = 0; i <= steps; i++) {
    final u = i / steps;
    final a = tailAt + (chestAt - tailAt) * u;
    final shift = 0.035 * math.sin(a * 3 - t * 1.2);
    final w = 0.13 + 0.22 * Curves.easeOut.transform((u / 0.4).clamp(0.0, 1.0));
    final chestUp = u > 0.92 ? swell : 0.0;
    joints.add(_Joint(onRing(a, ring + shift), w + chestUp, w + chestUp));
  }
  final chest = onRing(chestAt, ring);
  final along = chestAt + math.pi / 2;

  // The neck: up off the frame and curling level by the head, rearing back
  // to draw breath, thrown forward to breathe.
  final neck = <Offset>[];
  var p = chest;
  var a = along - 1.6 - 0.2 * b.inhale + 0.3 * b.lunge;
  final sway = math.sin(t * 1.1) * 0.1;
  const links = 8;
  final curl = 0.17 - 0.012 * b.inhale - 0.03 * b.lunge + sway / links;
  for (var i = 0; i < links; i++) {
    a += curl;
    p += _dir(a) * (0.22 + 0.025 * b.lunge);
    neck.add(p);
  }
  for (var i = 0; i < links; i++) {
    final w = 0.35 - (i + 1) / links * 0.13;
    joints.add(_Joint(neck[i], w * 0.92, w * 1.05));
  }
  final headAngle = a - 0.15 + 0.15 * b.lunge - 0.15 * b.inhale;
  return _Coil(joints, links, (neck.last, headAngle), chest, along);
}

/// The hide for a body that bends any which way (round a frame): one
/// outline round the spine, lit along the back and shadowed along the
/// belly side wherever it goes, so it reads as round.
void _coilHide(
  Canvas canvas,
  List<_Joint> j,
  FireDragonColors col, {
  required bool lite,
}) {
  final top = <Offset>[];
  final bottom = <Offset>[];
  for (var i = 0; i < j.length; i++) {
    final n = _normal(j, i);
    top.add(j[i].p + n * j[i].up);
    bottom.add(j[i].p - n * j[i].down);
  }
  final back = _smooth(top);
  final under = _smooth(bottom);
  final outline = Path()..addPolygon([...back, ...under.reversed], true);
  canvas.drawPath(outline, Paint()..color = col.body);
  canvas.save();
  canvas.clipPath(outline);
  MaskFilter? soft(double sigma) =>
      lite ? null : MaskFilter.blur(BlurStyle.normal, sigma);
  canvas.drawPath(
    Path()..addPolygon(back, false),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.26
      ..strokeJoin = StrokeJoin.round
      ..color = col.top
      ..maskFilter = soft(0.07),
  );
  canvas.drawPath(
    Path()..addPolygon(under, false),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.3
      ..strokeJoin = StrokeJoin.round
      ..color = col.shadow
      ..maskFilter = soft(0.08),
  );
  // Rows of scales down the flanks.
  if (!lite) {
    final scale = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.012
      ..color = col.shadow.withValues(alpha: 0.45);
    for (var i = 2; i < j.length - 2; i++) {
      final n = _normal(j, i);
      final d = Offset(-n.dy, n.dx);
      for (final k in const [0.45, -0.05]) {
        final at = j[i].p + n * (j[i].up * k);
        final size = (j[i].up + j[i].down) * 0.16;
        canvas.drawArc(
          Rect.fromCircle(center: at, radius: size),
          math.atan2(d.dy, d.dx) - math.pi * 0.5,
          math.pi,
          false,
          scale,
        );
      }
    }
  }
  canvas.restore();
  // A rim of light along the back, and the outline.
  canvas.drawPath(
    Path()..addPolygon(back, false),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.025
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(col.top, Colors.white, 0.35)!.withValues(alpha: 0.7),
  );
  canvas.drawPath(
    outline,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.018
      ..color = col.shadow.withValues(alpha: 0.9),
  );
}

class _Spine {
  const _Spine(this.joints, this.neckJoints, this.head);

  /// Tail tip first, to the back of the skull last.
  final List<_Joint> joints;

  /// How many of [joints] (from the end) are neck.
  final int neckJoints;

  /// The back of the skull and which way the head points.
  final (Offset, double) head;
}

_Spine _spineAt(double t, _Breath b) {
  // The neck: from the chest up and forward in an S, levelling out at the
  // head. Rearing back to draw breath bends it back; the lunge throws it
  // forward.
  final neck = <Offset>[];
  var p = const Offset(0.08, -0.08);
  // Rising steeply from the chest and curling level by the head; rearing
  // back tips it up, the lunge straightens it out forward.
  var a = -1.25 - 0.2 * b.inhale + 0.3 * b.lunge;
  final sway = math.sin(t * 1.1) * 0.12;
  const links = 7;
  final curl = 0.18 - 0.012 * b.inhale - 0.03 * b.lunge + sway / links;
  for (var i = 0; i < links; i++) {
    a += curl;
    p += _dir(a) * (0.16 + 0.02 * b.lunge);
    neck.add(p);
  }
  // The head looks a little down along the blast, up as it draws breath.
  final headAngle = a + 0.05 + 0.18 * b.lunge - 0.12 * b.inhale;

  // The body, chest to hips.
  const body = [Offset(0.08, -0.08), Offset(-0.35, 0.02), Offset(-0.78, 0.06)];
  final hips = const Offset(-1.15, 0.03);

  // The tail: a wave travelling back along it, growing toward the tip.
  final tail = <Offset>[];
  var q = hips;
  const tailLinks = 14;
  for (var i = 0; i < tailLinks; i++) {
    final angle =
        math.pi -
        0.12 +
        (0.06 + 0.028 * i) * math.sin(t * 2.3 - i * 0.48) +
        0.012 * i;
    q += _dir(angle) * 0.165;
    tail.add(q);
  }

  final joints = <_Joint>[];
  // Tail tip to hips.
  for (var i = tailLinks - 1; i >= 0; i--) {
    final w = 0.03 + 0.2 * (1 - i / tailLinks);
    joints.add(_Joint(tail[i], w * 0.95, w));
  }
  joints.add(_Joint(hips, 0.25, 0.27));
  // Hips to chest (the chest swells drawing breath).
  final swell = 0.03 * b.inhale;
  joints.add(_Joint(body[2], 0.28, 0.36));
  joints.add(_Joint(body[1], 0.3 + swell, 0.4 + swell));
  joints.add(_Joint(body[0], 0.3 + swell, 0.36 + swell));
  // Up the neck to the skull.
  for (var i = 0; i < links; i++) {
    final w = 0.25 - (i + 1) / links * 0.12;
    joints.add(_Joint(neck[i], w * 0.92, w * 1.05));
  }
  return _Spine(joints, links, (neck.last, headAngle));
}

/// Which way is "up" off the spine at joint [i] (toward the back).
Offset _normal(List<_Joint> j, int i) {
  final a = j[math.max(0, i - 1)].p;
  final b = j[math.min(j.length - 1, i + 1)].p;
  final d = b - a;
  final len = d.distance == 0 ? 1.0 : d.distance;
  return Offset(d.dy / len, -d.dx / len);
}

/// The hide: one outline round the whole spine, lit along the back.
void _hide(Canvas canvas, List<_Joint> j, FireDragonColors col) {
  final top = <Offset>[];
  final bottom = <Offset>[];
  for (var i = 0; i < j.length; i++) {
    final n = _normal(j, i);
    top.add(j[i].p + n * j[i].up);
    bottom.add(j[i].p - n * j[i].down);
  }
  final outline = Path()
    ..addPolygon([..._smooth(top), ..._smooth(bottom.reversed.toList())], true);
  final bounds = outline.getBounds();
  canvas.drawPath(
    outline,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, bounds.top),
        Offset(0, bounds.bottom),
        [col.top, col.body, col.shadow],
        [0, 0.45, 1],
      ),
  );
  // A rim of light along the back.
  canvas.drawPath(
    Path()..addPolygon(_smooth(top), false),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.025
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(col.top, Colors.white, 0.35)!.withValues(alpha: 0.7),
  );
  canvas.drawPath(
    outline,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.018
      ..color = col.shadow.withValues(alpha: 0.9),
  );
}

/// Plated belly and throat along the underside, chest up the neck and back
/// along the body.
void _belly(
  Canvas canvas,
  List<_Joint> j,
  int neck,
  FireDragonColors col, {
  int? start,
}) {
  final from = start ?? j.length - neck - 5;
  final inner = <Offset>[];
  final outer = <Offset>[];
  for (var i = math.max(0, from); i < j.length - 1; i++) {
    final n = _normal(j, i);
    outer.add(j[i].p - n * j[i].down * 0.94);
    inner.add(j[i].p - n * j[i].down * 0.4);
  }
  if (outer.length < 3) return;
  final band = Path()
    ..addPolygon([
      ..._smooth(outer),
      ..._smooth(inner.reversed.toList()),
    ], true);
  canvas.drawPath(
    band,
    Paint()
      ..shader = ui.Gradient.linear(outer.first, outer.last, [
        col.belly,
        Color.lerp(col.belly, col.body, 0.35)!,
      ]),
  );
  // The plates.
  final line = Paint()
    ..strokeWidth = 0.014
    ..color = Color.lerp(col.belly, col.shadow, 0.55)!;
  for (var i = 0; i < outer.length; i++) {
    canvas.drawLine(outer[i], inner[i], line);
  }
}

/// Spines along the back, biggest over the shoulders.
void _spines(
  Canvas canvas,
  List<_Joint> j,
  FireDragonColors col, {
  double size = 1,
}) {
  final paint = Paint()
    ..shader = ui.Gradient.linear(j.first.p, j.last.p, [
      col.horn,
      Color.lerp(col.horn, col.body, 0.3)!,
    ]);
  final edge = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.012
    ..color = col.shadow.withValues(alpha: 0.8);
  for (var i = 1; i < j.length - 1; i++) {
    final n = _normal(j, i);
    final d = Offset(-n.dy, n.dx); // toward the head
    final u = i / (j.length - 1);
    // Small on the tail, tall over the shoulders, smaller up the neck.
    final h = (0.04 + 0.11 * math.sin(math.pi * math.pow(u, 1.2))) * size;
    final base = j[i].p + n * (j[i].up * 0.92);
    final foot = 0.05 * size;
    final spike = Path()
      ..moveTo((base + d * foot).dx, (base + d * foot).dy)
      ..lineTo(
        (base + n * h - d * h * 0.55).dx,
        (base + n * h - d * h * 0.55).dy,
      )
      ..lineTo((base - d * foot).dx, (base - d * foot).dy)
      ..close();
    canvas.drawPath(spike, paint);
    canvas.drawPath(spike, edge);
  }
}

/// The head, from the back of the skull at [back] pointing along [angle]:
/// swept horns, a heavy brow over a burning eye, and a jaw that drops
/// open on a hinge to breathe fire.
void _head(
  Canvas canvas,
  Offset back,
  double angle,
  double t,
  _Breath breath,
  FireDragonColors col,
) {
  canvas.save();
  canvas.translate(back.dx, back.dy);
  canvas.rotate(angle);
  // A big, heavy head.
  canvas.scale(1.18);
  final edge = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.016
    ..strokeJoin = StrokeJoin.round
    ..color = col.shadow;

  // Horns, swept back over the neck.
  for (final (root, tip, w, shade) in const [
    (Offset(0.06, -0.1), Offset(-0.5, -0.34), 0.065, 0.25),
    (Offset(0.14, -0.12), Offset(-0.36, -0.42), 0.075, 0.0),
  ]) {
    final mid = Offset.lerp(root, tip, 0.5)! + const Offset(0.05, -0.08);
    final n = _rot(Offset.lerp(root, tip, 0.5)! - root, -math.pi / 2);
    final nn = n / n.distance;
    final horn = Path()
      ..moveTo((root + nn * w).dx, (root + nn * w).dy)
      ..quadraticBezierTo(
        mid.dx + nn.dx * w * 0.5,
        mid.dy + nn.dy * w * 0.5,
        tip.dx,
        tip.dy,
      )
      ..quadraticBezierTo(
        mid.dx - nn.dx * w * 0.5,
        mid.dy - nn.dy * w * 0.5,
        (root - nn * w).dx,
        (root - nn * w).dy,
      )
      ..close();
    canvas.drawPath(
      horn,
      Paint()
        ..shader = ui.Gradient.linear(root, tip, [
          Color.lerp(col.horn, col.shadow, 0.2 + shade)!,
          Color.lerp(col.horn, Colors.white, 0.3)!,
        ]),
    );
    canvas.drawPath(horn, edge);
  }

  // The lower jaw, hinged under the ear, dropping open.
  final hinge = const Offset(0.1, 0.05);
  canvas.save();
  canvas.translate(hinge.dx, hinge.dy);
  canvas.rotate(breath.jaw);
  final jaw = Path()
    ..moveTo(-0.06, -0.02)
    ..lineTo(0.46, -0.01)
    ..quadraticBezierTo(0.5, 0.0, 0.47, 0.03)
    ..quadraticBezierTo(0.25, 0.09, -0.02, 0.1)
    ..close();
  // Mouth inside, then lower teeth, then the jaw.
  if (breath.jaw > 0.04) {
    canvas.drawPath(
      Path()..addPolygon(const [
        Offset(-0.04, -0.02),
        Offset(0.46, -0.02),
        Offset(0.46, -0.14),
        Offset(-0.04, -0.08),
      ], true),
      Paint()..color = const Color(0xFF3A0610),
    );
  }
  final tooth = Paint()..color = const Color(0xFFFFF4E0);
  for (var i = 0; i < 5; i++) {
    final x = 0.08 + i * 0.08;
    canvas.drawPath(
      Path()..addPolygon([
        Offset(x - 0.018, -0.01),
        Offset(x, -0.055),
        Offset(x + 0.018, -0.01),
      ], true),
      tooth,
    );
  }
  canvas.drawPath(
    jaw,
    Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, -0.02),
        const Offset(0, 0.1),
        [col.belly, Color.lerp(col.belly, col.shadow, 0.5)!],
      ),
  );
  canvas.drawPath(jaw, edge);
  canvas.restore();

  // The skull: back of the head flush with the neck, a heavy brow, a long
  // snout down to the nose.
  final skull = Path()
    ..moveTo(-0.06, -0.11)
    ..quadraticBezierTo(0.08, -0.17, 0.22, -0.15)
    ..quadraticBezierTo(0.3, -0.14, 0.36, -0.1)
    ..quadraticBezierTo(0.5, -0.08, 0.62, -0.06)
    ..quadraticBezierTo(0.67, -0.04, 0.63, 0.0)
    ..lineTo(0.55, 0.035)
    ..lineTo(0.14, 0.05)
    ..quadraticBezierTo(0.0, 0.1, -0.06, 0.12)
    ..close();
  canvas.drawPath(
    skull,
    Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, -0.17),
        const Offset(0, 0.12),
        [col.top, col.body, col.shadow],
        [0, 0.55, 1],
      ),
  );
  // Upper teeth along the lip.
  for (var i = 0; i < 6; i++) {
    final x = 0.18 + i * 0.065;
    canvas.drawPath(
      Path()..addPolygon([
        Offset(x - 0.016, 0.045 - i * 0.002),
        Offset(x, 0.085 - i * 0.002),
        Offset(x + 0.016, 0.045 - i * 0.002),
      ], true),
      tooth,
    );
  }
  canvas.drawPath(skull, edge);
  // Scales along the snout, and the cheek frill.
  final scale = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.01
    ..color = col.shadow.withValues(alpha: 0.6);
  for (var i = 0; i < 3; i++) {
    canvas.drawArc(
      Rect.fromCircle(center: Offset(0.4 + i * 0.07, -0.05), radius: 0.03),
      math.pi * 1.1,
      math.pi * 0.8,
      false,
      scale,
    );
  }
  for (var i = 0; i < 3; i++) {
    final base = Offset(-0.02 + i * 0.03, 0.06 + i * 0.012);
    canvas.drawPath(
      Path()..addPolygon([
        base,
        base + Offset(-0.14 + i * 0.02, 0.06 + i * 0.03),
        base + const Offset(0.05, 0.02),
      ], true),
      Paint()..color = Color.lerp(col.body, col.shadow, 0.4)!,
    );
  }
  // Nostril, smoking between breaths.
  canvas.drawOval(
    Rect.fromCenter(
      center: const Offset(0.58, -0.045),
      width: 0.04,
      height: 0.018,
    ),
    Paint()..color = col.shadow,
  );
  if (breath.fire < 0) {
    for (var i = 0; i < 3; i++) {
      final k = ((t * 0.7 + i / 3) % 1.0);
      canvas.drawCircle(
        Offset(0.6 + k * 0.18, -0.07 - k * 0.2 + math.sin(k * 6 + i) * 0.02),
        0.015 + k * 0.04,
        Paint()
          ..color = const Color(0xFF6E6060).withValues(alpha: 0.35 * (1 - k)),
      );
    }
  }
  // The eye under a heavy brow, glowing hotter as it breathes.
  final eye = const Offset(0.27, -0.08);
  final heat = math.max(breath.inhale, breath.lunge);
  canvas.drawCircle(
    eye,
    0.07 + 0.03 * heat,
    Paint()
      ..color = col.eye.withValues(alpha: 0.25 + 0.35 * heat)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.04),
  );
  final almond = Path()
    ..moveTo(eye.dx - 0.05, eye.dy + 0.005)
    ..quadraticBezierTo(eye.dx, eye.dy - 0.035, eye.dx + 0.05, eye.dy - 0.005)
    ..quadraticBezierTo(eye.dx, eye.dy + 0.03, eye.dx - 0.05, eye.dy + 0.005)
    ..close();
  canvas.drawPath(almond, Paint()..color = col.eye);
  canvas.drawOval(
    Rect.fromCenter(
      center: eye.translate(0.008, 0),
      width: 0.014,
      height: 0.05,
    ),
    Paint()..color = const Color(0xFF1A0408),
  );
  canvas.drawLine(
    eye.translate(-0.07, -0.02),
    eye.translate(0.07, -0.06),
    Paint()
      ..strokeWidth = 0.035
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(col.body, col.shadow, 0.5)!,
  );
  // The throat glows as it draws breath.
  if (breath.inhale > 0) {
    canvas.drawCircle(
      const Offset(0.05, 0.08),
      0.12,
      Paint()
        ..color = const Color(
          0xFFFF8A2A,
        ).withValues(alpha: 0.45 * breath.inhale)
        ..blendMode = BlendMode.plus
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.06),
    );
  }
  canvas.restore();
}

/// The fire, pouring out of the open jaws along the line of the head: a
/// white-hot core, roiling orange and red, smoke at the far end, embers.
void _fire(
  Canvas canvas,
  Offset back,
  double angle,
  _Breath b,
  double t,
  double reach, {
  bool lite = false,
}) {
  MaskFilter? blur(double sigma) =>
      lite ? null : MaskFilter.blur(BlurStyle.normal, sigma);
  // The mouth, between the jaws, in the dragon's frame.
  // (The head is drawn 1.18 times its plan size.)
  final mouth = back + _rot(Offset(0.58, 0.04 + 0.12 * b.jaw) * 1.18, angle);
  final dir = _dir(angle + 0.18 * b.jaw);
  final side = Offset(-dir.dy, dir.dx);
  final grow = Curves.easeOut.transform((b.fire / 0.35).clamp(0.0, 1.0));
  final length = 2.6 * reach * grow;
  final alpha = b.fade.clamp(0.0, 1.0);

  // The glow it throws.
  if (!lite) {
    canvas.drawCircle(
      mouth + dir * length * 0.45,
      length * 0.45,
      Paint()
        ..color = const Color(0xFFFF6A1A).withValues(alpha: 0.28 * alpha)
        ..blendMode = BlendMode.plus
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, length * 0.25),
    );
  }

  // A stream of puffs, each born at the mouth and swelling as it flies,
  // white to yellow to orange to red, ending in smoke.
  final n = lite ? 16 : 40;
  for (var i = 0; i < n; i++) {
    final age = ((b.fire * 1.6) + i / n) % 1.0;
    // Nothing further out than the fire has had time to reach.
    if (age > b.fire * 1.6 + 0.02) continue;
    final wander =
        math.sin(i * 7.31 + t * 9) * 0.5 + math.sin(i * 3.7 - t * 5) * 0.3;
    final p =
        mouth +
        dir * (age * length) +
        side * (wander * age * length * 0.18) +
        Offset(0, -age * age * 0.25);
    final r = 0.035 + 0.24 * age * reach;
    final Color c;
    if (age < 0.15) {
      c = Color.lerp(Colors.white, const Color(0xFFFFE27A), age / 0.15)!;
    } else if (age < 0.45) {
      c = Color.lerp(
        const Color(0xFFFFE27A),
        const Color(0xFFFF8A1F),
        (age - 0.15) / 0.3,
      )!;
    } else if (age < 0.78) {
      c = Color.lerp(
        const Color(0xFFFF8A1F),
        const Color(0xFFD6281A),
        (age - 0.45) / 0.33,
      )!;
    } else {
      // Smoke.
      canvas.drawCircle(
        p,
        r * 1.1,
        Paint()
          ..color = const Color(
            0xFF3A2A2A,
          ).withValues(alpha: 0.35 * alpha * (1 - age))
          ..maskFilter = blur(r * 0.4),
      );
      continue;
    }
    canvas.drawCircle(
      p,
      r,
      Paint()
        ..color = c.withValues(alpha: 0.75 * alpha)
        ..blendMode = BlendMode.plus
        ..maskFilter = blur(r * 0.35),
    );
  }

  // The core: a tongue of white-hot flame straight out of the mouth.
  final coreLen = length * 0.42;
  final flick = math.sin(t * 31) * 0.02;
  final core = Path()
    ..moveTo(mouth.dx, mouth.dy)
    ..quadraticBezierTo(
      (mouth + dir * coreLen * 0.5 + side * (0.07 + flick)).dx,
      (mouth + dir * coreLen * 0.5 + side * (0.07 + flick)).dy,
      (mouth + dir * coreLen).dx,
      (mouth + dir * coreLen).dy,
    )
    ..quadraticBezierTo(
      (mouth + dir * coreLen * 0.5 - side * (0.07 - flick)).dx,
      (mouth + dir * coreLen * 0.5 - side * (0.07 - flick)).dy,
      mouth.dx,
      mouth.dy,
    )
    ..close();
  canvas.drawPath(
    core,
    Paint()
      ..shader = ui.Gradient.linear(
        mouth,
        mouth + dir * coreLen,
        [
          Colors.white.withValues(alpha: alpha),
          const Color(0xFFFFE27A).withValues(alpha: alpha * 0.8),
          const Color(0x00FF8A1F),
        ],
        [0, 0.5, 1],
      )
      ..blendMode = BlendMode.plus,
  );

  // Embers thrown off the blast.
  for (var i = 0; i < 12; i++) {
    final age = ((b.fire * 1.3) + i / 12) % 1.0;
    if (age > b.fire * 1.3) continue;
    final p =
        mouth +
        dir * (age * length * 1.05) +
        side * (math.sin(i * 5.1) * age * length * 0.35) +
        Offset(0, -age * 0.4);
    canvas.drawCircle(
      p,
      0.012 + 0.012 * (1 - age),
      Paint()
        ..color = const Color(0xFFFFD27A).withValues(alpha: alpha * (1 - age)),
    );
  }
}

/// A great bat wing from the shoulder: a strong arm up to the wrist, four
/// long fingers fanning back, the membrane slung between them in scallops
/// back to the flank. [beat] 1 is fully raised, -1 driven down below the
/// body; the far wing is darker and smaller.
void _wing(
  Canvas canvas,
  double t,
  double beat,
  FireDragonColors col, {
  required bool far,
}) {
  final shoulder = far ? const Offset(-0.05, -0.3) : const Offset(-0.12, -0.2);
  canvas.save();
  canvas.translate(shoulder.dx, shoulder.dy);
  if (far) canvas.scale(0.88);
  // Raised (1) or driven down (-1): the wing swings round the shoulder
  // from high over the back to low under the belly, full-size all the way,
  // a little foreshortened in the middle of the stroke.
  final v = beat.clamp(-1.0, 1.0);
  // (Counterclockwise: down and back, never forward over the head.)
  canvas.rotate(-(1 - v) / 2 * 1.7);
  canvas.scale(1, 0.72 + 0.28 * v.abs());

  // The fingers spread more as it drives down.
  final spread = 1.0 + 0.1 * (1 - v);
  const wrist = Offset(0.18, -0.95);
  const elbow = Offset(-0.12, -0.45);
  final tips = [
    const Offset(-0.2, -1.55),
    const Offset(-0.75, -1.35),
    const Offset(-1.2, -1.0),
    const Offset(-1.35, -0.48),
  ].map((tip) => wrist + (tip - wrist) * spread).toList();
  const flank = Offset(-0.95, 0.12);

  // The membrane: from the wrist round the finger tips in scallops, back
  // to the flank and the shoulder.
  final membrane = Path()..moveTo(0, 0);
  membrane.lineTo(elbow.dx, elbow.dy);
  membrane.lineTo(wrist.dx, wrist.dy);
  membrane.lineTo(tips[0].dx, tips[0].dy);
  for (var i = 1; i < tips.length; i++) {
    final a = tips[i - 1], b = tips[i];
    final mid = Offset.lerp(a, b, 0.5)!;
    final toward = (wrist - mid) * 0.22;
    membrane.quadraticBezierTo(
      mid.dx + toward.dx,
      mid.dy + toward.dy,
      b.dx,
      b.dy,
    );
  }
  final lastMid = Offset.lerp(tips.last, flank, 0.5)!;
  membrane.quadraticBezierTo(
    lastMid.dx + (wrist - lastMid).dx * 0.18,
    lastMid.dy + (wrist - lastMid).dy * 0.18,
    flank.dx,
    flank.dy,
  );
  membrane.close();
  final deep = far
      ? Color.lerp(col.membraneDeep, Colors.black, 0.25)!
      : col.membraneDeep;
  final light = far
      ? Color.lerp(col.membrane, col.membraneDeep, 0.45)!
      : col.membrane;
  canvas.drawPath(
    membrane,
    Paint()..shader = ui.Gradient.radial(wrist, 1.6, [light, deep]),
  );
  // Light through the membrane near the bones.
  canvas.drawPath(
    membrane,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.018
      ..color = col.shadow.withValues(alpha: 0.9),
  );

  // Bones: arm and fingers, tapering.
  final bone = Paint()
    ..strokeCap = StrokeCap.round
    ..color = far ? Color.lerp(col.body, col.shadow, 0.5)! : col.body;
  canvas.drawLine(Offset.zero, elbow, bone..strokeWidth = 0.1);
  canvas.drawLine(elbow, wrist, bone..strokeWidth = 0.075);
  for (final tip in tips) {
    canvas.drawLine(wrist, tip, bone..strokeWidth = 0.032);
  }
  // A claw at the wrist.
  canvas.drawPath(
    Path()..addPolygon([
      wrist + const Offset(-0.03, -0.02),
      wrist + const Offset(0.12, -0.1),
      wrist + const Offset(0.03, 0.03),
    ], true),
    Paint()..color = col.horn,
  );
  canvas.restore();
}

/// The hind leg, tucked up in flight, claws trailing.
void _leg(
  Canvas canvas,
  Offset hip,
  double t,
  FireDragonColors col, {
  required bool far,
}) {
  final shade = far ? Color.lerp(col.body, col.shadow, 0.55)! : col.body;
  final sway = math.sin(t * 1.4 + (far ? 1 : 0)) * 0.03;
  final knee = hip + Offset(0.12, 0.18 + sway);
  final ankle = knee + Offset(-0.28, 0.1);
  final foot = ankle + Offset(-0.12, 0.04);
  // A heavy thigh tapering to the knee.
  final along = knee - hip;
  final side = Offset(-along.dy, along.dx) / along.distance;
  canvas.drawPath(
    Path()
      ..moveTo((hip + side * 0.16).dx, (hip + side * 0.16).dy)
      ..quadraticBezierTo(
        (hip + along * 0.6 + side * 0.17).dx,
        (hip + along * 0.6 + side * 0.17).dy,
        (knee + side * 0.05).dx,
        (knee + side * 0.05).dy,
      )
      ..lineTo((knee - side * 0.05).dx, (knee - side * 0.05).dy)
      ..quadraticBezierTo(
        (hip + along * 0.4 - side * 0.14).dx,
        (hip + along * 0.4 - side * 0.14).dy,
        (hip - side * 0.12).dx,
        (hip - side * 0.12).dy,
      )
      ..close(),
    Paint()..color = shade,
  );
  final limb = Paint()
    ..strokeCap = StrokeCap.round
    ..color = shade;
  canvas.drawLine(knee, ankle, limb..strokeWidth = 0.09);
  canvas.drawLine(ankle, foot, limb..strokeWidth = 0.06);
  final claw = Paint()
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 0.02
    ..color = col.horn;
  for (var i = 0; i < 3; i++) {
    canvas.drawLine(foot, foot + Offset(-0.07, -0.03 + i * 0.035), claw);
  }
}

/// The forelimb, folded under the chest.
void _arm(
  Canvas canvas,
  Offset shoulder,
  double t,
  FireDragonColors col, {
  required bool far,
}) {
  final shade = far ? Color.lerp(col.body, col.shadow, 0.55)! : col.body;
  final elbow = shoulder + Offset(-0.06, 0.16 + math.sin(t * 1.6) * 0.02);
  final wrist = elbow + const Offset(0.16, 0.05);
  final limb = Paint()
    ..strokeCap = StrokeCap.round
    ..color = shade;
  canvas.drawLine(shoulder, elbow, limb..strokeWidth = 0.08);
  canvas.drawLine(elbow, wrist, limb..strokeWidth = 0.055);
  final claw = Paint()
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 0.018
    ..color = col.horn;
  for (var i = 0; i < 3; i++) {
    canvas.drawLine(wrist, wrist + Offset(0.06, 0.02 + i * 0.025), claw);
  }
}
