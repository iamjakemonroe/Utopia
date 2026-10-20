import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/utopia_themes.dart';
import '../audio/room_sound.dart';
import 'world_sets.dart';

/// Stable pseudo-random 0-1 from an index.
double _rand(int i, int salt) {
  final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

Color _a(Color c, double alpha) =>
    c.withValues(alpha: (c.a * alpha).clamp(0.0, 1.0));

const _magenta = Color(0xFFFF2E9A);
const _cyan = Color(0xFF00E5FF);
const _lime = Color(0xFFC6FF3D);
const _violet = Color(0xFF9B6BFF);
const _gold = Color(0xFFFFD447);
const _neon = [_magenta, _cyan, _lime, _violet, _gold];
const _night = Color(0xFF05020F);

/// The beat: 120 a minute. [pulse] hits 1 on each beat and falls away.
class _Beat {
  _Beat(double t, double bpm) {
    final beats = t * bpm / 60;
    count = beats.floor();
    phase = beats - count;
    pulse = math.exp(-phase * 6);
    bar = count ~/ 4;
  }

  /// The room's beat (see [RoomSound]): its tempo once it has a steady
  /// one (the grid runs ahead, so the pulse lands on the beat); until
  /// then each hit heard is a beat, the pulse falling away after it.
  _Beat.room(double t) {
    final period = RoomSound.period;
    if (period > 0) {
      final beats = (t - RoomSound.anchor) / period;
      final whole = beats.floor();
      count = RoomSound.anchorCount + whole;
      phase = beats - whole;
      pulse = math.exp(-phase * 6);
    } else {
      final since = (t - RoomSound.beatAt).clamp(0.0, 10.0);
      count = RoomSound.beats;
      phase = (since / 0.5).clamp(0.0, 1.0);
      pulse = math.exp(-since * 7);
    }
    bar = count ~/ 4;
  }

  late final int count;
  late final double phase;
  late final double pulse;
  late final int bar;
}

/// The Music world: a festival at night. A giant vinyl record turns in the
/// sky, lasers sweep from the stage, the skyline is an equalizer bouncing
/// to the beat, speakers pump, a screen shows the waveform, notes drift up
/// and the crowd bounces with their hands in the air. When the player's
/// own music is playing ([WorldSets.musicLive]) it all dances harder; and
/// when it's allowed to hear the room ([RoomSound]), it dances to that:
/// the beats it hears and how loud it is.
///
/// With the set on (Encore worn here, [WorldSets.music]) the show peaks:
/// fireworks, confetti, bass shockwaves from the stage, twice the lasers,
/// and the crowd jumps.
void paintMusicScene(
  Canvas canvas,
  Size size,
  double t,
  WorldStyle style, {
  required Offset moon,
}) {
  final w = size.width;
  final h = size.height;
  final encore = WorldSets.music.amount;
  final live = WorldSets.musicLive.amount;
  // The room, when the world's allowed to hear it and something's playing:
  // its loudness lifts the whole show, its beats are the show's, the
  // equalizer is its spectrum and the stage's screen its waveform.
  RoomSound.drawnAt = t;
  final hearing = RoomSound.presenceAt(t);
  if (hearing > 0) RoomSound.show(t);
  final room = hearing * RoomSound.level;
  final energy = (0.55 + 0.25 * live + 0.45 * encore + 0.75 * room).clamp(
    0.0,
    1.5,
  );
  // The room's beat while it has one (a tempo, or hits lately); in a room
  // that's only noisy, the show keeps its own.
  final roomBeat =
      hearing > 0 && (RoomSound.period > 0 || t - RoomSound.beatAt < 2);
  final beat = roomBeat ? _Beat.room(t) : _Beat(t, 120);
  final stage = Offset(w * 0.5, h * 0.74);

  // The whole night lifts a little on every beat (a flash, to the room's).
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..color = _a(
        Color.lerp(_magenta, _violet, (beat.bar % 2).toDouble())!,
        (0.05 * energy + 0.1 * hearing) * beat.pulse,
      ),
  );
  _vinylMoon(canvas, moon, w * 0.17, t, beat);
  if (encore > 0) _fireworks(canvas, size, t, encore);
  _spotlights(canvas, size, t, energy);
  _lasers(canvas, stage, size, t, beat, energy, encore);
  _equalizer(canvas, size, t, beat, energy, hearing);
  _stage(canvas, stage, w, h, t, beat, energy, hearing);
  if (encore > 0) _shockwaves(canvas, stage, w, beat, encore);
  _notes(canvas, size, t, 10 + (energy * 8).round());
  _crowd(canvas, size, t, beat, energy, encore);
  if (encore > 0) _confetti(canvas, size, t, encore);

  // A deep violet at the edges keeps the eye on the show.
  final rect = Offset.zero & size;
  canvas.drawRect(
    rect,
    Paint()
      ..shader = RadialGradient(
        radius: 0.95,
        colors: [Colors.transparent, _a(_night, 0.5)],
        stops: const [0.6, 1],
      ).createShader(rect),
  );
}

/// A giant vinyl record hanging in the sky, turning, its grooves catching
/// the light and its label pulsing with the beat.
void _vinylMoon(Canvas canvas, Offset c, double r, double t, _Beat beat) {
  canvas.drawCircle(
    c,
    r * 1.5,
    Paint()
      ..shader = RadialGradient(
        colors: [
          _a(_magenta, 0.28 + 0.1 * beat.pulse),
          const Color(0x00FF2E9A),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: r * 1.5)),
  );
  canvas.drawCircle(c, r, Paint()..color = const Color(0xFF0B0812));
  final groove = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8
    ..color = const Color(0x22FFFFFF);
  for (var k = 0.42; k < 0.97; k += 0.05) {
    canvas.drawCircle(c, r * k, groove);
  }
  // The sheen turning with the record.
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(t * 0.6);
  canvas.drawCircle(
    Offset.zero,
    r,
    Paint()
      ..shader = SweepGradient(
        colors: const [
          Color(0x00FFFFFF),
          Color(0x30FFFFFF),
          Color(0x00FFFFFF),
          Color(0x00FFFFFF),
          Color(0x26C6E8FF),
          Color(0x00FFFFFF),
        ],
        stops: const [0, 0.08, 0.2, 0.5, 0.58, 0.7],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
  );
  // The label, with a stripe that shows it turning.
  final label = r * (0.34 + 0.02 * beat.pulse);
  canvas.drawCircle(
    Offset.zero,
    label,
    Paint()
      ..shader = const LinearGradient(
        colors: [_magenta, _violet],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: label)),
  );
  canvas.drawRect(
    Rect.fromCenter(
      center: Offset.zero,
      width: label * 2,
      height: label * 0.22,
    ),
    Paint()..color = const Color(0x55FFFFFF),
  );
  canvas.drawCircle(Offset.zero, r * 0.035, Paint()..color = _night);
  canvas.restore();
}

/// Spotlights from the top corners, sweeping slowly across the crowd.
void _spotlights(Canvas canvas, Size size, double t, double energy) {
  final w = size.width;
  final h = size.height;
  for (final (x, phase, color) in const [
    (-0.05, 0.0, Color(0xFFBFD8FF)),
    (1.05, 2.4, Color(0xFFFFC2E8)),
  ]) {
    final from = Offset(w * x, -h * 0.02);
    final aim = Offset(w * (0.5 + 0.35 * math.sin(t * 0.5 + phase)), h * 0.95);
    final dir = aim - from;
    final normal = Offset(-dir.dy, dir.dx) / dir.distance;
    final spread = w * 0.16;
    final cone = Path()
      ..moveTo(from.dx, from.dy)
      ..lineTo(aim.dx + normal.dx * spread, aim.dy + normal.dy * spread)
      ..lineTo(aim.dx - normal.dx * spread, aim.dy - normal.dy * spread)
      ..close();
    canvas.drawPath(
      cone,
      Paint()
        ..shader = ui.Gradient.linear(from, aim, [
          _a(color, 0.22 * energy),
          _a(color, 0),
        ]),
    );
  }
}

/// Laser beams fanning up from the stage, sweeping and changing color with
/// the bars; twice as many, sweeping wilder, with the set on.
void _lasers(
  Canvas canvas,
  Offset stage,
  Size size,
  double t,
  _Beat beat,
  double energy,
  double encore,
) {
  final count = 6 + (encore * 8).round();
  final reach = size.height * 1.1;
  final from = stage.translate(0, -size.height * 0.08);
  for (var i = 0; i < count; i++) {
    final spread = (i / (count - 1) - 0.5) * 1.9;
    final sweep =
        math.sin(t * (0.9 + encore * 1.1) + i * 0.7) * (0.25 + 0.2 * encore);
    final a = -math.pi / 2 + spread + sweep;
    final to = from + Offset(math.cos(a), math.sin(a)) * reach;
    final color = _neon[(i + beat.bar) % _neon.length];
    final strength = (0.6 + 0.4 * beat.pulse) * energy;
    canvas.drawLine(
      from,
      to,
      Paint()
        ..strokeWidth = 7
        ..shader = ui.Gradient.linear(from, to, [
          _a(color, 0.22 * strength),
          _a(color, 0),
        ]),
    );
    canvas.drawLine(
      from,
      to,
      Paint()
        ..strokeWidth = 1.4
        ..shader = ui.Gradient.linear(from, to, [
          _a(Color.lerp(color, Colors.white, 0.5)!, 0.9 * strength),
          _a(color, 0),
        ]),
    );
  }
}

/// The skyline is an equalizer: towers of glowing segments rising and
/// falling to the beat, the low end on the left thumping hardest. Hearing
/// the room, it's the room's spectrum ([RoomSound.bands]).
void _equalizer(
  Canvas canvas,
  Size size,
  double t,
  _Beat beat,
  double energy,
  double hearing,
) {
  final w = size.width;
  final h = size.height;
  final ground = h * 0.7;
  canvas.drawRect(
    Rect.fromLTRB(0, ground - h * 0.02, w, h),
    Paint()
      ..shader = ui.Gradient.linear(Offset(0, ground), Offset(0, h), [
        const Color(0xFF120830),
        const Color(0xFF07031A),
      ]),
  );
  const bars = 24;
  final gap = w * 0.008;
  final bw = w / bars - gap;
  const seg = 6.0;
  for (var i = 0; i < bars; i++) {
    final band = i / (bars - 1); // 0 = bass, 1 = treble
    final x = i * (bw + gap) + gap / 2;
    final kick = beat.pulse * (1 - band) * 0.9;
    final flutter = 0.5 + 0.5 * math.sin(t * (6 + band * 14) + i * 1.9);
    var level =
        (0.25 + 0.35 * _rand(i, 400) + 0.4 * kick + 0.25 * flutter * band) *
        energy;
    if (hearing > 0) {
      final heard = 0.1 + 0.95 * RoomSound.bands[i] + 0.15 * kick;
      level += (heard - level) * hearing;
    }
    final tall = h * 0.26 * level.clamp(0.08, 1.15);
    final color = Color.lerp(_cyan, _magenta, band)!;
    final top = ground - tall;
    for (var y = ground - seg; y > top; y -= seg + 2) {
      final heat = (ground - y) / (h * 0.26);
      canvas.drawRect(
        Rect.fromLTWH(x, y, bw, seg),
        Paint()
          ..color = _a(Color.lerp(color, Colors.white, heat * 0.35)!, 0.85),
      );
    }
    // The peak cap glowing above each tower.
    canvas.drawRect(
      Rect.fromLTWH(x, top - seg - 3, bw, 3),
      Paint()..color = _a(Colors.white, 0.8),
    );
    canvas.drawRect(
      Rect.fromLTWH(x - 2, top - 8, bw + 4, tall + 8),
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, top - 8), Offset(0, ground), [
          _a(color, 0.18),
          _a(color, 0),
        ]),
    );
  }
  // Its reflection on the floor.
  canvas.drawRect(
    Rect.fromLTRB(0, ground, w, ground + h * 0.06),
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, ground),
        Offset(0, ground + h * 0.06),
        [_a(_magenta, 0.25 * energy), _a(_magenta, 0)],
      ),
  );
}

/// The stage: a truss arch of lights, a big screen showing the waveform
/// (the room's, with a red light on, while it's heard), and speaker stacks
/// whose woofers pump on every beat.
void _stage(
  Canvas canvas,
  Offset c,
  double w,
  double h,
  double t,
  _Beat beat,
  double energy,
  double hearing,
) {
  final sw = w * 0.86;
  final floor = Rect.fromCenter(center: c, width: sw, height: h * 0.05);
  canvas.drawRRect(
    RRect.fromRectAndRadius(floor, const Radius.circular(8)),
    Paint()
      ..shader = ui.Gradient.linear(floor.topCenter, floor.bottomCenter, const [
        Color(0xFF2A1A52),
        Color(0xFF0C0620),
      ]),
  );
  canvas.drawLine(
    floor.topLeft.translate(6, 1),
    floor.topRight.translate(-6, 1),
    Paint()
      ..strokeWidth = 2
      ..color = _a(_cyan, 0.7 + 0.3 * beat.pulse),
  );

  // The truss: an arch of girders studded with lights.
  final arch = Rect.fromCenter(
    center: c.translate(0, -h * 0.02),
    width: sw * 0.95,
    height: h * 0.28,
  );
  canvas.drawArc(
    arch,
    math.pi,
    math.pi,
    false,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = const Color(0xFF3A2C66),
  );
  for (var k = 0; k <= 12; k++) {
    final a = math.pi + math.pi * k / 12;
    final p =
        arch.center +
        Offset(math.cos(a) * arch.width / 2, math.sin(a) * arch.height / 2);
    final on = (k + beat.count) % 3 == 0;
    canvas.drawCircle(
      p,
      on ? 4.2 : 3,
      Paint()..color = _a(_neon[k % _neon.length], on ? 1 : 0.45),
    );
  }

  // The screen with the waveform.
  final screen = Rect.fromCenter(
    center: c.translate(0, -h * 0.085),
    width: sw * 0.44,
    height: h * 0.075,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(screen, const Radius.circular(6)),
    Paint()..color = const Color(0xFF080414),
  );
  final wave = Path();
  const last = RoomSound.waveLength - 1;
  for (var i = 0; i <= last; i++) {
    final u = i / last;
    final x = screen.left + screen.width * u;
    var swing = math.sin(u * 18 + t * 9) * (0.18 + 0.22 * beat.pulse * energy);
    if (hearing > 0) {
      swing += (RoomSound.wave[i] * 0.42 - swing) * hearing;
    }
    final y = screen.center.dy + swing * math.sin(u * math.pi) * screen.height;
    if (i == 0) {
      wave.moveTo(x, y);
    } else {
      wave.lineTo(x, y);
    }
  }
  canvas.drawPath(
    wave,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..shader = const LinearGradient(
        colors: [_cyan, _magenta],
      ).createShader(screen),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(screen, const Radius.circular(6)),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = _a(_violet, 0.8),
  );
  // On air: the room's being heard.
  if (hearing > 0) {
    final dot = screen.topLeft.translate(9, 9);
    final glow = 0.75 + 0.25 * math.sin(t * 5);
    canvas.drawCircle(
      dot,
      7,
      Paint()..color = _a(const Color(0xFFFF2D55), 0.25 * hearing * glow),
    );
    canvas.drawCircle(
      dot,
      3.2,
      Paint()..color = _a(const Color(0xFFFF2D55), hearing * glow),
    );
  }

  // Speaker stacks, woofers pumping.
  for (final side in const [-1.0, 1.0]) {
    final x = c.dx + side * sw * 0.4;
    for (var k = 0; k < 2; k++) {
      final box = Rect.fromCenter(
        center: Offset(x, c.dy - h * (0.045 + k * 0.06)),
        width: w * 0.12,
        height: h * 0.055,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(4)),
        Paint()..color = const Color(0xFF0A0616),
      );
      final pump = 1 + 0.12 * beat.pulse * energy;
      canvas.drawCircle(
        box.center,
        box.height * 0.36 * pump,
        Paint()..color = const Color(0xFF1E1440),
      );
      canvas.drawCircle(
        box.center,
        box.height * 0.36 * pump,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = _a(_cyan, 0.4 + 0.5 * beat.pulse),
      );
      canvas.drawCircle(
        box.center,
        box.height * 0.1,
        Paint()..color = _a(_magenta, 0.8),
      );
    }
  }
}

/// Bass shockwaves rolling out from the stage on every beat.
void _shockwaves(Canvas canvas, Offset c, double w, _Beat beat, double encore) {
  for (var k = 0; k < 2; k++) {
    final p = (beat.phase + k * 0.5) % 1.0;
    canvas.drawOval(
      Rect.fromCenter(
        center: c,
        width: w * (0.3 + 1.4 * p),
        height: w * (0.08 + 0.36 * p),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = _a(_cyan, 0.5 * encore * (1 - p)),
    );
  }
}

/// Music notes drifting up and swaying, glowing.
void _notes(Canvas canvas, Size size, double t, int count) {
  final w = size.width;
  final h = size.height;
  for (var i = 0; i < count; i++) {
    final speed = 0.05 + _rand(i, 410) * 0.05;
    final k = (t * speed + _rand(i, 411)) % 1.0;
    final x = w * _rand(i, 412) + math.sin(t * 1.2 + i) * 20;
    final y = h * (0.9 - k * 0.8);
    final s = 8 + _rand(i, 413) * 8;
    final color = _neon[i % _neon.length];
    final fade = math.sin(k * math.pi);
    final paint = Paint()..color = _a(color, 0.85 * fade);
    final head = Offset(x, y);
    canvas.drawOval(
      Rect.fromCenter(center: head, width: s * 0.9, height: s * 0.65),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(head.dx + s * 0.32, head.dy - s * 1.6, s * 0.14, s * 1.6),
      paint,
    );
    if (i.isEven) {
      // A pair joined by a beam.
      final second = head.translate(s * 1.2, -s * 0.3);
      canvas.drawOval(
        Rect.fromCenter(center: second, width: s * 0.9, height: s * 0.65),
        paint,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          second.dx + s * 0.32,
          second.dy - s * 1.6,
          s * 0.14,
          s * 1.6,
        ),
        paint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(head.dx + s * 0.32, head.dy - s * 1.6)
          ..lineTo(second.dx + s * 0.46, second.dy - s * 1.6)
          ..lineTo(second.dx + s * 0.46, second.dy - s * 1.3)
          ..lineTo(head.dx + s * 0.32, head.dy - s * 1.3)
          ..close(),
        paint,
      );
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(head.dx + s * 0.46, head.dy - s * 1.6)
          ..quadraticBezierTo(
            head.dx + s * 1.1,
            head.dy - s * 1.2,
            head.dx + s * 0.8,
            head.dy - s * 0.7,
          ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.14
          ..color = _a(color, 0.85 * fade),
      );
    }
  }
}

/// The crowd: silhouettes bouncing to the beat, hands up, phones glowing.
/// They jump with the set on.
void _crowd(
  Canvas canvas,
  Size size,
  double t,
  _Beat beat,
  double energy,
  double encore,
) {
  final w = size.width;
  final h = size.height;
  // Light spilling off the stage behind them, so they stand out against it.
  final spill = Rect.fromCenter(
    center: Offset(w * 0.5, h * 0.82),
    width: w * 1.6,
    height: h * 0.2,
  );
  canvas.drawOval(
    spill,
    Paint()
      ..shader = RadialGradient(
        colors: [
          _a(
            Color.lerp(_magenta, _violet, 0.4)!,
            0.42 + 0.12 * beat.pulse * energy,
          ),
          _a(_violet, 0.12),
          _a(_violet, 0),
        ],
        stops: const [0, 0.55, 1],
      ).createShader(spill),
  );
  for (final (row, top, scale, shade) in const [
    (0, 0.86, 0.8, Color(0xFF1A0C38)),
    (1, 0.92, 1.0, Color(0xFF05020F)),
  ]) {
    final count = row == 0 ? 11 : 9;
    for (var i = 0; i < count; i++) {
      final seed = row * 50 + i;
      final x = w * (i + 0.5 + (_rand(seed, 420) - 0.5) * 0.4) / count;
      final s = w * 0.06 * scale * (0.85 + 0.3 * _rand(seed, 421));
      final lag = _rand(seed, 422) * 0.25;
      final bounce =
          math.exp(-((beat.phase + lag) % 1.0) * 6) *
          s *
          (0.25 * energy + 0.9 * encore);
      final base = Offset(x, h * top - bounce);
      final body = Paint()..color = shade;
      final head = base.translate(0, -s * 1.15);
      final torso = Path()
        ..moveTo(base.dx - s * 0.8, h + 4)
        ..lineTo(base.dx - s * 0.78, base.dy - s * 0.25)
        ..quadraticBezierTo(
          base.dx - s * 0.74,
          base.dy - s * 0.7,
          base.dx - s * 0.3,
          base.dy - s * 0.74,
        )
        ..lineTo(base.dx + s * 0.3, base.dy - s * 0.74)
        ..quadraticBezierTo(
          base.dx + s * 0.74,
          base.dy - s * 0.7,
          base.dx + s * 0.78,
          base.dy - s * 0.25,
        )
        ..lineTo(base.dx + s * 0.8, h + 4)
        ..close();
      // A rim of stage light along the top of each head and shoulders.
      final rim = Paint()..color = _a(_neon[seed % 3], row == 0 ? 0.5 : 0.75);
      canvas.drawCircle(head.translate(0, -1.4), s * 0.42 + 0.6, rim);
      canvas.drawPath(torso.shift(const Offset(0, -1.6)), rim);
      // Hands up: some wave, some hold up a phone.
      final arm = _rand(seed, 423) < 0.5 + 0.4 * encore;
      final side = _rand(seed, 424) < 0.5 ? -1.0 : 1.0;
      final wave = math.sin(t * 4 + seed) * s * 0.2;
      final shoulder = base.translate(side * s * 0.55, -s * 0.6);
      final hand = shoulder.translate(side * s * 0.3 + wave, -s * 1.15);
      if (arm) {
        canvas.drawLine(
          shoulder,
          hand.translate(0, -1.4),
          Paint()
            ..strokeWidth = s * 0.2 + 2.4
            ..strokeCap = StrokeCap.round
            ..color = rim.color,
        );
      }
      canvas.drawCircle(head, s * 0.42, body);
      canvas.drawPath(torso, body);
      if (arm) {
        canvas.drawLine(
          shoulder,
          hand,
          Paint()
            ..strokeWidth = s * 0.2
            ..strokeCap = StrokeCap.round
            ..color = shade,
        );
        if (_rand(seed, 425) < 0.4) {
          final glow = hand.translate(0, -s * 0.12);
          canvas.drawCircle(
            glow,
            s * 0.45,
            Paint()
              ..shader = RadialGradient(
                colors: [_a(Colors.white, 0.35), const Color(0x00FFFFFF)],
              ).createShader(Rect.fromCircle(center: glow, radius: s * 0.45)),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: glow, width: s * 0.2, height: s * 0.32),
              Radius.circular(s * 0.04),
            ),
            Paint()..color = const Color(0xFFEAF6FF),
          );
        }
      }
    }
  }
}

/// Fireworks bursting high over the stage.
void _fireworks(Canvas canvas, Size size, double t, double amount) {
  final w = size.width;
  final h = size.height;
  for (var i = 0; i < 4; i++) {
    const cycle = 2.6;
    final local = t + i * 0.65;
    final n = (local / cycle).floor();
    final k = (local % cycle) / cycle;
    if (k > 0.7) continue;
    final life = k / 0.7;
    final c = Offset(
      w * (0.15 + 0.7 * _rand(n * 4 + i, 430)),
      h * (0.1 + 0.25 * _rand(n * 4 + i, 431)),
    );
    final color = _neon[(n + i) % _neon.length];
    final radius =
        w * (0.12 + 0.06 * _rand(n, 432)) * Curves.easeOut.transform(life);
    // The flash as it bursts.
    canvas.drawCircle(
      c,
      w * 0.16,
      Paint()
        ..shader = RadialGradient(
          colors: [_a(color, 0.3 * amount * (1 - life)), _a(color, 0)],
        ).createShader(Rect.fromCircle(center: c, radius: w * 0.16)),
    );
    for (var s = 0; s < 22; s++) {
      final a = s * 2 * math.pi / 22;
      final dir = Offset(math.cos(a), math.sin(a));
      final drop = Offset(0, life * life * 22);
      final p = c + dir * radius + drop;
      canvas.drawLine(
        c + dir * radius * 0.55 + drop * 0.6,
        p,
        Paint()
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..shader = ui.Gradient.linear(c + dir * radius * 0.55, p, [
            _a(color, 0),
            _a(color, 0.7 * amount * (1 - life)),
          ]),
      );
      canvas.drawCircle(
        p,
        3.2 * (1 - life * 0.5),
        Paint()
          ..color = _a(
            Color.lerp(color, Colors.white, 0.45)!,
            amount * (1 - life * 0.8),
          ),
      );
    }
  }
}

/// Confetti fluttering down.
void _confetti(Canvas canvas, Size size, double t, double amount) {
  final w = size.width;
  final h = size.height;
  for (var i = 0; i < 46; i++) {
    final speed = 0.09 + _rand(i, 440) * 0.08;
    final k = (t * speed + _rand(i, 441)) % 1.0;
    final x = w * _rand(i, 442) + math.sin(t * 2 + i) * 16;
    final y = -10 + k * (h + 20);
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(t * (2 + _rand(i, 443) * 3) + i);
    canvas.scale(1, 0.4 + 0.6 * math.cos(t * 4 + i).abs());
    canvas.drawRect(
      const Rect.fromLTWH(-3.5, -2, 7, 4),
      Paint()..color = _a(_neon[i % _neon.length], amount),
    );
    canvas.restore();
  }
}
