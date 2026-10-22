// Utopia's trailer, played as a film: you wake on an island at night, Chip
// finds you, and you fly through the gateway and the worlds, past the
// games standing in them like monuments, through the dark where something
// watches, and back to the gate. Filmed in Chrome by tool/ads (scene
// "cinema" of tool/perf/perf_main.dart, started by window.__start());
// tool/ads/trailer.py lays titles, the score and the narrator over it.
//
// Its times match tool/ads/score.py: the gate at 11.5 s, the worlds a bar
// (2 s) each from 19.5, the games from 43.5, the dark from 55.5, the chase
// from 60, the second impact at 63.5.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:utopia/core/theme/utopia_themes.dart';
import 'package:utopia/core/widgets/coin_buddy.dart';
import 'package:utopia/core/widgets/utopia_world.dart';
import 'package:utopia/core/widgets/world_sets.dart';
import 'package:utopia/features/checkers/domain/checkers_engine.dart';
import 'package:utopia/features/checkers/presentation/widgets/checkers_disc.dart';
import 'package:utopia/features/chess/domain/chess_types.dart';
import 'package:utopia/features/chess/presentation/widgets/chess_piece_art.dart';
import 'package:utopia/features/chess/presentation/widgets/chess_piece_styles.dart';
import 'package:utopia/features/eights/domain/eights_engine.dart';
import 'package:utopia/features/eights/presentation/widgets/card_art.dart';
import 'package:utopia/features/ludo/domain/ludo_engine.dart';
import 'package:utopia/features/ludo/presentation/widgets/ludo_pieces.dart';

/// Starts the film (from window.__start()).
final cinemaStart = ValueNotifier<bool>(false);

// For timing the film: &from=<s> starts it there, &cut=world,flight,chip,
// overlay,fog,particles leaves those out.
final _from = double.tryParse(Uri.base.queryParameters['from'] ?? '') ?? 0;
final _cut = (Uri.base.queryParameters['cut'] ?? '').split(',').toSet();

const _tour = [
  'utopia_doodle',
  'utopia_winter',
  'utopia_music',
  'utopia_heaven',
  'utopia_hell',
  'utopia_dojo',
  'utopia_deep',
  'utopia_alien',
  'utopia_tech',
  'utopia_zombie',
  'utopia_halloween',
];

const _rush = [
  'utopia_calm',
  'utopia_warm',
  'utopia_adventure',
  'noir',
  'utopia_anime',
  'utopia_hell',
  'utopia_heaven',
  'utopia_halloween',
  'utopia_winter',
  'utopia_music',
  'utopia_zombie',
  'utopia_birthday',
  'utopia_deep',
  'utopia_dark',
];

/// The world you're in at [t].
String worldAt(double t) {
  if (t < 19.5) return 'utopia_dark';
  if (t < 41.5) {
    return _tour[((t - 19.5) / 2).floor().clamp(0, _tour.length - 1)];
  }
  if (t < 43.5) return 'utopia_anime';
  if (t < 55.5) return 'utopia_dark';
  if (t < 60) return 'utopia_hell';
  if (t < 63.5) return _rush[((t - 60) / 0.25).floor() % _rush.length];
  return 'utopia_dark';
}

/// The camera's speed (units a second) through the film.
const _speeds = [
  (0.0, 0.0),
  (6.0, 0.6),
  (9.0, 3.0),
  (10.4, 10.0),
  (11.5, 34.0),
  (12.2, 13.0),
  (19.5, 17.0),
  (41.5, 17.0),
  (42.2, 6.0),
  (43.5, 12.0),
  (49.5, 9.0),
  (55.5, 3.5),
  (59.6, 3.5),
  (60.2, 70.0),
  (63.5, 70.0),
  (63.9, 2.5),
  (76.0, 1.4),
];

double _lerpKeys(List<(double, double)> keys, double t) {
  if (t <= keys.first.$1) return keys.first.$2;
  for (var i = 1; i < keys.length; i++) {
    if (t <= keys[i].$1) {
      final (t0, v0) = keys[i - 1];
      final (t1, v1) = keys[i];
      return v0 + (v1 - v0) * ((t - t0) / (t1 - t0));
    }
  }
  return keys.last.$2;
}

/// Where the camera is (how far it has come) at each 1/120 s.
final List<double> _zTable = () {
  final out = <double>[0];
  var z = 0.0;
  for (var i = 1; i <= 80 * 120; i++) {
    z += _lerpKeys(_speeds, i / 120) / 120;
    out.add(z);
  }
  return out;
}();

double camZ(double t) {
  final i = (t * 120).clamp(0, _zTable.length - 1.0);
  final a = i.floor();
  final b = math.min(a + 1, _zTable.length - 1);
  return _zTable[a] + (_zTable[b] - _zTable[a]) * (i - a);
}

// ── what's out there ───────────────────────────────────────────────────────

enum _Kind { island, cloud, king, knight, queen, token, die, card, disc }

class _Thing {
  _Thing(
    this.kind,
    this.x,
    this.y,
    this.z,
    this.size, {
    this.seed = 0,
    this.tint = 0,
  });

  final _Kind kind;
  final double x, y, z, size;
  final double seed;
  final int tint;
}

final List<_Thing> _things = () {
  final rng = math.Random(11);
  final out = <_Thing>[];
  final end = camZ(76) + 140;
  var z = 8.0;
  while (z < end) {
    // Islands to either side and below; the middle stays clear to fly.
    final side = rng.nextBool() ? 1 : -1;
    out.add(
      _Thing(
        _Kind.island,
        side * (3.5 + rng.nextDouble() * 12),
        -2 + rng.nextDouble() * 9,
        z,
        2.4 + rng.nextDouble() * 4.5,
        seed: rng.nextDouble(),
      ),
    );
    if (rng.nextDouble() < 0.55) {
      out.add(
        _Thing(
          _Kind.cloud,
          (rng.nextDouble() - 0.5) * 34,
          3 + rng.nextDouble() * 6,
          z + rng.nextDouble() * 4,
          3 + rng.nextDouble() * 5,
          seed: rng.nextDouble(),
        ),
      );
    }
    z += 4.5 + rng.nextDouble() * 4;
  }
  // The games, standing in the world: each comes close at its moment.
  void at(
    double t,
    double ahead,
    _Kind kind,
    double x,
    double y,
    double size, [
    int tint = 0,
  ]) {
    out.add(
      _Thing(
        kind,
        x,
        y,
        camZ(t) + ahead,
        size,
        seed: rng.nextDouble(),
        tint: tint,
      ),
    );
  }

  at(44.1, 5, _Kind.token, -1.6, 0.4, 2.6, 0);
  at(44.2, 4.2, _Kind.die, 1.9, -0.6, 1.3);
  at(44.6, 9, _Kind.token, 3.0, 1.0, 1.8, 1);
  at(45.3, 5, _Kind.king, -2.2, 0.6, 4.2, 0);
  at(45.4, 6, _Kind.knight, 2.4, 0.9, 3.6, 1);
  at(45.9, 10, _Kind.queen, -4.4, 1.6, 4.4, 1);
  at(46.5, 4.6, _Kind.disc, -1.6, 0.2, 1.6, 0);
  at(46.6, 5.4, _Kind.disc, 1.8, 0.7, 1.6, 1);
  at(47.7, 4.4, _Kind.card, 0, -0.3, 2.0, 0);
  at(47.75, 4.9, _Kind.card, -1.8, 0.2, 1.8, 1);
  at(47.8, 5.3, _Kind.card, 1.9, 0.4, 1.8, 2);
  // Scattered through the games and the feelings after them.
  for (var i = 0; i < 40; i++) {
    final t = 43.5 + rng.nextDouble() * 12;
    final kinds = [_Kind.card, _Kind.die, _Kind.disc, _Kind.token];
    at(
      t,
      14 + rng.nextDouble() * 20,
      kinds[i % 4],
      (rng.nextBool() ? 1 : -1) * (3 + rng.nextDouble() * 8),
      -3 + rng.nextDouble() * 8,
      0.9 + rng.nextDouble() * 0.8,
      i % 3,
    );
  }
  out.sort((a, b) => b.z.compareTo(a.z));
  return out;
}();

/// The gateways: the one Chip leads you through, and the one at the end.
final _gates = [camZ(11.42), camZ(76) + 9];

// ── the film ───────────────────────────────────────────────────────────────

class Cinema extends StatefulWidget {
  const Cinema({super.key});

  @override
  State<Cinema> createState() => _CinemaState();
}

class _CinemaState extends State<Cinema> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((e) {
    final t = _from + e.inMicroseconds / 1e6;
    _dress(worldAt(t));
    _t.value = t;
  });
  final _t = ValueNotifier<double>(0);
  ui.Image? _gate;
  String? _world;

  @override
  void initState() {
    super.initState();
    cinemaStart.addListener(_go);
    const AssetImage('assets/branding/logo_mark.png')
        .resolve(ImageConfiguration.empty)
        .addListener(
          ImageStreamListener((info, _) => setState(() => _gate = info.image)),
        );
  }

  void _go() {
    if (cinemaStart.value && !_ticker.isActive) _ticker.start();
  }

  @override
  void dispose() {
    cinemaStart.removeListener(_go);
    _ticker.dispose();
    super.dispose();
  }

  /// Chip wears the world he's in.
  void _dress(String world) {
    if (world == _world) return;
    _world = world;
    final sets = {
      'utopia_winter': WorldSets.winter,
      'utopia_music': WorldSets.music,
      'utopia_heaven': WorldSets.heaven,
      'utopia_hell': WorldSets.hell,
      'utopia_dojo': WorldSets.dragon,
      'utopia_zombie': WorldSets.zombie,
      'utopia_halloween': WorldSets.halloween,
    };
    for (final entry in sets.entries) {
      entry.value.on.value = entry.key == world;
      entry.value.settle();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: _t,
      builder: (context, t, _) {
        if (!cinemaStart.value) return const ColoredBox(color: Colors.black);
        final world = worldAt(t);
        final theme = UtopiaThemes.byId(world);
        UtopiaThemes.active = theme;
        final shake = _shake(t);
        final roll =
            math.sin(t * 0.21) * 0.025 +
            (t > 60 && t < 63.5 ? math.sin(t * 37) * 0.02 : 0);
        final chip = _chip(t);
        final size = MediaQuery.sizeOf(context);
        return ClipRect(
          child: Transform.translate(
            offset: shake,
            child: Transform.rotate(
              angle: roll,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // The world itself, far off: drawing nearer as you fly.
                  if (!_cut.contains('world'))
                    Transform.scale(
                      scale: 1.12 + 0.06 * math.sin(t * 0.13) + _push(t),
                      child: KeyedSubtree(
                        key: ValueKey(world),
                        child: UtopiaWorld(style: theme.world),
                      ),
                    ),
                  if (!_cut.contains('flight'))
                    CustomPaint(painter: _Flight(t, theme.world, _gate)),
                  if (chip != null && !_cut.contains('chip'))
                    Positioned(
                      left: chip.x * size.width - chip.size / 2,
                      top: chip.y * size.height - chip.size / 2,
                      width: chip.size,
                      height: chip.size,
                      child: Opacity(
                        opacity: chip.opacity,
                        child: CoinBuddy(
                          mood: chip.mood,
                          size: chip.size,
                          lookAt: chip.look,
                        ),
                      ),
                    ),
                  if (!_cut.contains('overlay'))
                    CustomPaint(painter: _Overlay(t, theme.world)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  double _push(double t) {
    // The backdrop swells as the camera rushes (into the gate, the chase).
    if (t > 10.4 && t < 11.5) return (t - 10.4) * 0.5;
    if (t > 60 && t < 63.5) return 0.12 + 0.06 * math.sin(t * 9);
    return 0;
  }

  Offset _shake(double t) {
    var a = 0.0;
    if (t > 11.3 && t < 12.3) a = 9 * (1 - (t - 11.3));
    if (t > 57.5 && t < 60) a = 3 + (t - 57.5) * 2;
    if (t > 60 && t < 63.5) a = 7;
    if (t > 63.5 && t < 64.3) a = 10 * (1 - (t - 63.5) / 0.8);
    if (a <= 0) return Offset.zero;
    return Offset(math.sin(t * 71) * a, math.cos(t * 59) * a);
  }
}

class _ChipShot {
  _ChipShot(
    this.x,
    this.y,
    this.size,
    this.mood, {
    this.look,
    this.opacity = 1,
  });

  final double x, y, size;
  final BuddyMood mood;
  final Offset? look;
  final double opacity;
}

double _ease(double k) => Curves.easeInOutCubic.transform(k.clamp(0.0, 1.0));

/// Where Chip is, how big, and how he feels.
_ChipShot? _chip(double t) {
  final bob = math.sin(t * 2.2) * 0.012;
  const atYou = Offset.zero;
  if (t < 7.4) return null;
  if (t < 8.4) {
    final k = _ease((t - 7.4) / 1.0);
    return _ChipShot(
      1.25 - 0.7 * k,
      0.85 - 0.33 * k + bob,
      120 + 110 * k,
      BuddyMood.happy,
      look: atYou,
    );
  }
  if (t < 9.8) {
    return _ChipShot(0.55, 0.52 + bob, 230, BuddyMood.excited, look: atYou);
  }
  if (t < 11.25) {
    final k = _ease((t - 9.8) / 1.45);
    return _ChipShot(
      0.55 - 0.05 * k,
      0.52 - 0.1 * k,
      230 - 215 * k,
      BuddyMood.happy,
      opacity: 1 - k * 0.6,
    );
  }
  if (t < 11.6) return null;
  if (t < 16.5) {
    final k = _ease((t - 11.6) / 0.8);
    return _ChipShot(0.2, 0.75 + bob + (1 - k) * 0.3, 96, BuddyMood.happy);
  }
  if (t < 19.5) {
    final k = _ease((t - 16.5) / 0.9);
    return _ChipShot(
      0.2 + 0.3 * k,
      0.75 - 0.2 * k + bob,
      96 + 124 * k,
      BuddyMood.excited,
      look: atYou,
    );
  }
  if (t < 41.5) {
    final i = ((t - 19.5) / 2).floor();
    final mood = switch (_tour[i.clamp(0, _tour.length - 1)]) {
      'utopia_winter' => BuddyMood.happy,
      'utopia_music' => BuddyMood.vibing,
      'utopia_heaven' => BuddyMood.peaceful,
      'utopia_hell' => BuddyMood.evil,
      'utopia_zombie' => BuddyMood.sad,
      'utopia_halloween' => BuddyMood.evil,
      _ => null,
    };
    if (mood == null) return null;
    final local = (t - 19.5) % 2;
    final k = _ease(local / 0.4);
    final left = i.isEven;
    return _ChipShot(
      left ? 0.27 : 0.73,
      0.66 + bob,
      60 + 100 * k,
      mood,
      look: atYou,
    );
  }
  if (t < 43.5) return _ChipShot(0.74, 0.68 + bob, 110, BuddyMood.thinking);
  if (t < 49.5) return _ChipShot(0.14, 0.86 + bob, 70, BuddyMood.excited);
  if (t < 55.5) {
    // Win, lose, feel everything.
    final mood = t < 51.0
        ? BuddyMood.excited
        : t < 52.5
        ? BuddyMood.sad
        : [
            BuddyMood.evil,
            BuddyMood.peaceful,
            BuddyMood.vibing,
            BuddyMood.hot,
          ][((t - 52.5) / 0.75).floor() % 4];
    final k = _ease((t - 49.5) / 0.6);
    return _ChipShot(0.5, 0.56 + bob, 150 + 110 * k, mood, look: atYou);
  }
  if (t < 57.4) return null;
  if (t < 60) {
    // Watching. Coming closer.
    final k = _ease((t - 57.4) / 2.6);
    return _ChipShot(
      0.5,
      0.52,
      110 + 330 * k,
      BuddyMood.evil,
      look: atYou,
      opacity: math.min(1, (t - 57.4) * 2),
    );
  }
  if (t < 63.9) return null;
  if (t < 68.3) {
    final k = _ease((t - 63.9) / 4.4);
    return _ChipShot(
      0.5,
      0.6 + bob,
      130 + 80 * k,
      BuddyMood.happy,
      look: atYou,
    );
  }
  return null;
}

// ── the flight: islands, clouds, the games, the gate ──────────────────────

class _Flight extends CustomPainter {
  _Flight(this.t, this.style, this.gate);

  final double t;
  final WorldStyle style;
  final ui.Image? gate;

  @override
  void paint(Canvas canvas, Size size) {
    final cz = camZ(t);
    final cx = math.sin(t * 0.31) * 1.3;
    final cy = -1.2 + math.cos(t * 0.23) * 0.5 + (t < 7 ? (7 - t) * 0.5 : 0);
    final f = size.width * 1.05;
    final vx = size.width / 2;
    final vy = size.height * 0.44;
    final sky = style.sky.length > 2 ? style.sky[2] : style.sky.first;

    Offset project(double x, double y, double d) =>
        Offset(vx + (x - cx) * f / d, vy + (y - cy) * f / d);

    // Gates, furthest first, between the things around them.
    final gates = [
      for (final gz in _gates)
        if (gz - cz > 0.3 && gz - cz < 160) gz,
    ];
    var gi = 0;
    for (final th in _things) {
      final d = th.z - cz;
      while (gi < gates.length && gates[gi] - cz > d) {
        _gateAt(
          canvas,
          project(0, -0.2, gates[gi] - cz),
          f / (gates[gi] - cz),
          gates[gi] - cz,
        );
        gi++;
      }
      if (d < 0.5 || d > 150) continue;
      final p = project(th.x, th.y, d);
      final s = f / d;
      final fog = ((d - 40) / 110).clamp(0.0, 1.0);
      final near = (1 - ((0.9 - d) / 0.4).clamp(0.0, 1.0));
      final alpha = (1 - fog * 0.85) * near;
      if (alpha <= 0.02) continue;
      final w = th.size * s;
      // What it covers: a layer only that big, and nothing drawn off screen.
      final bounds = switch (th.kind) {
        _Kind.island => Rect.fromLTRB(
          p.dx - w * 0.56,
          p.dy - w * 0.4,
          p.dx + w * 0.56,
          p.dy + w * 0.86,
        ),
        _Kind.cloud => Rect.fromLTRB(
          p.dx - w * 1.2,
          p.dy - w * 0.6,
          p.dx + w * 1.2,
          p.dy + w * 0.4,
        ),
        _ => Rect.fromCenter(
          center: p.translate(0, -w * 0.4),
          width: w * 3,
          height: w * 3,
        ),
      };
      if (!bounds.overlaps(Offset.zero & size)) continue;
      final layered = !_cut.contains('fog') && (alpha < 0.99 || fog > 0);
      if (layered) {
        canvas.saveLayer(
          bounds,
          Paint()..color = Color.fromRGBO(0, 0, 0, alpha),
        );
      }
      switch (th.kind) {
        case _Kind.island:
          _island(canvas, p, w, th.seed);
        case _Kind.cloud:
          _cloud(canvas, p, w);
        default:
          _game(canvas, th, p, w);
      }
      if (layered && fog > 0) {
        // Haze: far things take the sky's color.
        canvas.drawColor(sky.withValues(alpha: fog * 0.6), BlendMode.srcATop);
      }
      if (layered) canvas.restore();
    }
    while (gi < gates.length) {
      _gateAt(
        canvas,
        project(0, -0.2, gates[gi] - cz),
        f / (gates[gi] - cz),
        gates[gi] - cz,
      );
      gi++;
    }
    // The doodle: a cat drawing itself in the air ahead of you, then flown
    // through.
    if (t > 48.25 && t < 49.6) {
      final through = t < 49.15 ? 0.0 : (t - 49.15) / 0.45;
      canvas.saveLayer(
        null,
        Paint()..color = Color.fromRGBO(0, 0, 0, (1 - through).clamp(0.0, 1.0)),
      );
      _cat(
        canvas,
        Offset(vx, vy),
        size.width * 0.62 * (1 + through * through * 3),
      );
      canvas.restore();
    }
    if (!_cut.contains('particles')) {
      _particles(canvas, size, cz, cx, cy, f, vx, vy);
    }
  }

  void _gateAt(Canvas canvas, Offset p, double s, double d) {
    final img = gate;
    if (img == null) return;
    final w = 7.5 * s;
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFD9B8FF).withValues(alpha: 0.75),
          const Color(0xFF8E5CFF).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: p, radius: w * 0.9));
    canvas.drawCircle(p, w * 0.9 * (1 + 0.05 * math.sin(t * 3)), glow);
    final dst = Rect.fromCenter(
      center: p.translate(0, w * 0.06),
      width: w,
      height: w,
    );
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  void _island(Canvas canvas, Offset top, double w, double seed) {
    final h = w * 0.62;
    final left = top.translate(-w / 2, 0);
    final right = top.translate(w / 2, 0);
    final tip = top.translate(w * (seed - 0.5) * 0.2, h);
    final rock = Path()
      ..moveTo(left.dx, left.dy)
      ..cubicTo(
        left.dx + w * 0.08,
        top.dy + h * 0.4,
        top.dx - w * 0.2,
        top.dy + h * 0.72,
        tip.dx,
        tip.dy,
      )
      ..cubicTo(
        top.dx + w * 0.2,
        top.dy + h * 0.7,
        right.dx - w * 0.06,
        top.dy + h * 0.36,
        right.dx,
        right.dy,
      )
      ..close();
    canvas.drawPath(
      rock,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: style.rock.length >= 2
              ? style.rock
              : [style.rock.first, style.rock.first],
        ).createShader(rock.getBounds()),
    );
    if (seed > 0.55) {
      // A waterfall off its edge.
      final fall = Rect.fromLTWH(top.dx + w * 0.32, top.dy, w * 0.035, h * 1.3);
      canvas.drawRect(
        fall,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xCC9FE8FF), Color(0x005AB8FF)],
          ).createShader(fall),
      );
    }
    final cap = Rect.fromCenter(center: top, width: w * 1.04, height: w * 0.2);
    canvas.drawOval(
      cap.shift(Offset(0, w * 0.03)),
      Paint()..color = style.land.last,
    );
    canvas.drawOval(
      cap,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: style.land.length >= 2
              ? style.land
              : [style.land.first, style.land.first],
        ).createShader(cap),
    );
    if (seed < 0.4 && style.foliage.isNotEmpty) {
      // A tree.
      final base = top.translate(-w * 0.18, -w * 0.02);
      canvas.drawLine(
        base,
        base.translate(0, -w * 0.18),
        Paint()
          ..color = style.rock.last
          ..strokeWidth = w * 0.025,
      );
      canvas.drawCircle(
        base.translate(0, -w * 0.24),
        w * 0.09,
        Paint()..color = style.foliage.first,
      );
    }
  }

  void _cloud(Canvas canvas, Offset c, double r) {
    final paint = Paint()..color = style.cloudLight.withValues(alpha: 0.55);
    canvas.drawOval(
      Rect.fromCenter(center: c, width: r * 1.6, height: r * 0.7),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(r * 0.5, -r * 0.18),
        width: r * 1.2,
        height: r * 0.7,
      ),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(-r * 0.55, -r * 0.08),
        width: r,
        height: r * 0.55,
      ),
      paint,
    );
  }

  void _game(Canvas canvas, _Thing th, Offset p, double w) {
    final spin = t * (0.8 + th.seed) + th.seed * 6;
    switch (th.kind) {
      case _Kind.king || _Kind.knight || _Kind.queen:
        final styleSet = ChessPieceStyle.byId('classic');
        final finish = th.tint == 0 ? styleSet.white : styleSet.black;
        final type = switch (th.kind) {
          _Kind.king => PieceType.king,
          _Kind.knight => PieceType.knight,
          _ => PieceType.queen,
        };
        canvas.save();
        canvas.translate(p.dx - w / 2, p.dy - w * 0.9);
        ChessPieceArtPainter(
          type: type,
          finish: finish,
          t: t,
        ).paint(canvas, Size.square(w));
        canvas.restore();
      case _Kind.token:
        canvas.save();
        final hop = (math.sin(t * 6 + th.seed * 9)).abs() * w * 0.25;
        canvas.translate(
          p.dx - w / 2,
          p.dy - w * LudoTokenPainter.aspect - hop,
        );
        LudoTokenPainter(
          setId: 'classic',
          color: LudoColor.values[th.tint % 4],
          t: t,
        ).paint(canvas, Size(w, w * LudoTokenPainter.aspect));
        canvas.restore();
      case _Kind.die:
        _die(canvas, p, w, spin);
      case _Kind.card:
        const cards = [
          PlayingCard(8, CardSuit.hearts),
          PlayingCard(1, CardSuit.spades),
          PlayingCard(12, CardSuit.diamonds),
        ];
        drawCard(
          canvas,
          cards[th.tint % 3],
          at: p,
          width: w,
          dpr: 2.6667,
          angle: math.sin(spin) * 0.6,
        );
      case _Kind.disc:
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.scale(1, 0.55 + 0.45 * math.cos(spin).abs());
        paintCheckersDisc(
          canvas,
          Offset.zero,
          w / 2,
          finish: checkersFinish(
            'classic',
            th.tint == 0 ? CheckersSide.dark : CheckersSide.light,
          ),
          king: th.tint == 0,
        );
        canvas.restore();
      default:
    }
  }

  void _die(Canvas canvas, Offset c, double w, double spin) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(spin);
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w, height: w),
      Radius.circular(w * 0.2),
    );
    canvas.drawRRect(
      r.shift(Offset(w * 0.05, w * 0.07)),
      Paint()..color = const Color(0x55000000),
    );
    canvas.drawRRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFDCD6F0)],
        ).createShader(r.outerRect),
    );
    final pip = Paint()..color = const Color(0xFF241A4D);
    final face = ((spin * 2).floor() % 6) + 1;
    const spots = {
      1: [(0.0, 0.0)],
      2: [(-1.0, -1.0), (1.0, 1.0)],
      3: [(-1.0, -1.0), (0.0, 0.0), (1.0, 1.0)],
      4: [(-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0)],
      5: [(-1.0, -1.0), (1.0, -1.0), (0.0, 0.0), (-1.0, 1.0), (1.0, 1.0)],
      6: [
        (-1.0, -1.0),
        (1.0, -1.0),
        (-1.0, 0.0),
        (1.0, 0.0),
        (-1.0, 1.0),
        (1.0, 1.0),
      ],
    };
    for (final (x, y) in spots[face]!) {
      canvas.drawCircle(Offset(x * w * 0.26, y * w * 0.26), w * 0.085, pip);
    }
    canvas.restore();
  }

  /// A cat drawing itself in ink, in the air.
  void _cat(Canvas canvas, Offset c, double w) {
    final k = ((t - 48.3) / 0.7).clamp(0.0, 1.0);
    Offset at(double u, double v) =>
        c.translate((u - 0.5) * w, (v - 0.5) * w * 0.82);
    final path = Path()
      ..moveTo(at(0.3, 0.42).dx, at(0.3, 0.42).dy)
      ..lineTo(at(0.33, 0.18).dx, at(0.33, 0.18).dy)
      ..lineTo(at(0.44, 0.32).dx, at(0.44, 0.32).dy)
      ..quadraticBezierTo(
        at(0.5, 0.3).dx,
        at(0.5, 0.3).dy,
        at(0.56, 0.32).dx,
        at(0.56, 0.32).dy,
      )
      ..lineTo(at(0.67, 0.18).dx, at(0.67, 0.18).dy)
      ..lineTo(at(0.7, 0.42).dx, at(0.7, 0.42).dy)
      ..quadraticBezierTo(
        at(0.76, 0.8).dx,
        at(0.76, 0.8).dy,
        at(0.5, 0.82).dx,
        at(0.5, 0.82).dy,
      )
      ..quadraticBezierTo(
        at(0.24, 0.8).dx,
        at(0.24, 0.8).dy,
        at(0.3, 0.42).dx,
        at(0.3, 0.42).dy,
      );
    final drawn = Path();
    var left = 0.0;
    final metrics = path.computeMetrics().toList();
    final total = metrics.fold<double>(0, (a, m) => a + m.length);
    left = total * k;
    for (final m in metrics) {
      if (left <= 0) break;
      final len = math.min(left, m.length);
      drawn.addPath(m.extractPath(0, len), Offset.zero);
      left -= len;
    }
    canvas.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.035
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );
    if (k >= 1) {
      for (final (u, v) in [(0.41, 0.5), (0.59, 0.5)]) {
        canvas.drawCircle(at(u, v), w * 0.025, Paint()..color = Colors.white);
      }
    }
  }

  /// The world's own specks rushing past: snow, embers, bubbles, ink,
  /// petals, sparkles. Streaks when you're fast.
  void _particles(
    Canvas canvas,
    Size size,
    double cz,
    double cx,
    double cy,
    double f,
    double vx,
    double vy,
  ) {
    final rng = math.Random(4);
    final speed = _lerpKeys(_speeds, t);
    final world = worldAt(t);
    final (color, shape) = switch (world) {
      'utopia_winter' => (Colors.white, 0),
      'utopia_hell' => (const Color(0xFFFF8A3D), 1),
      'utopia_deep' => (const Color(0xAAC9F2FF), 2),
      'utopia_doodle' => (const Color(0xFF1F1E1B), 0),
      'utopia_anime' => (const Color(0xFFFFB7D5), 3),
      'utopia_halloween' => (const Color(0xFFFFA43A), 1),
      'utopia_zombie' => (const Color(0xFF9BE36B), 0),
      'utopia_heaven' => (const Color(0xFFFFE9A8), 0),
      _ => (style.sparkles.isNotEmpty ? style.sparkles.first : Colors.white, 0),
    };
    for (var i = 0; i < 160; i++) {
      final px = (rng.nextDouble() - 0.5) * 30;
      final py =
          (rng.nextDouble() - 0.5) * 18 +
          (shape == 1 || shape == 2 ? -t * 0.8 % 18 : t * 0.4 % 18);
      final pz = rng.nextDouble() * 40;
      final d = ((pz - cz) % 40 + 40) % 40 + 0.3;
      final p = Offset(vx + (px - cx) * f / d, vy + (py - cy) * f / d);
      if (p.dx < -40 ||
          p.dx > size.width + 40 ||
          p.dy < -40 ||
          p.dy > size.height + 40) {
        continue;
      }
      final r = (f / d) * 0.035;
      final a = ((1 - d / 40) * 1.2).clamp(0.0, 1.0);
      final paint = Paint()..color = color.withValues(alpha: color.a * a);
      if (speed > 25) {
        final back = Offset(
          vx + (px - cx) * f / (d + speed * 0.03),
          vy + (py - cy) * f / (d + speed * 0.03),
        );
        canvas.drawLine(back, p, paint..strokeWidth = math.max(1, r * 0.8));
        continue;
      }
      switch (shape) {
        case 1:
          paint.maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.8);
          canvas.drawCircle(p, r * 0.8, paint);
        case 2:
          canvas.drawCircle(
            p,
            r,
            paint
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(0.8, r * 0.18),
          );
        case 3:
          canvas.drawOval(
            Rect.fromCenter(center: p, width: r * 2, height: r),
            paint,
          );
        default:
          canvas.drawCircle(p, r * 0.6, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Flight old) => true;
}

// ── over everything: eyelids, flashes, lightning, the red, speed ─────────

class _Overlay extends CustomPainter {
  _Overlay(this.t, this.style);

  final double t;
  final WorldStyle style;

  static const _lids = [
    (0.0, 0.0),
    (2.0, 0.0),
    (2.55, 0.32),
    (3.05, 0.0),
    (4.5, 0.03),
    (6.2, 1.0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Waking: the lids part (twice), the dark lifting.
    if (t < 6.2) {
      final open = _lerpKeys(_lids, t);
      final dark = Paint()..color = Colors.black;
      final gap = size.height * 0.5 * open;
      final mid = size.height * 0.48;
      final top = Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, mid - gap * 0.6)
        ..quadraticBezierTo(size.width / 2, mid - gap * 1.4, 0, mid - gap * 0.6)
        ..close();
      final bottom = Path()
        ..moveTo(0, size.height)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width, mid + gap * 0.6)
        ..quadraticBezierTo(size.width / 2, mid + gap * 1.4, 0, mid + gap * 0.6)
        ..close();
      canvas.drawRect(
        rect,
        Paint()..color = Colors.black.withValues(alpha: (1 - open) * 0.55),
      );
      canvas.drawPath(
        top,
        dark..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
      canvas.drawPath(bottom, dark);
    }
    var white = 0.0;
    // Into the gate.
    if (t > 11.0 && t < 12.1) {
      white = t < 11.5 ? (t - 11.0) / 0.5 : 1 - (t - 11.5) / 0.6;
    }
    // Each world, a flash on the way in.
    for (var k = 19.5; k < 41.4; k += 2) {
      if (t >= k && t < k + 0.14) white = math.max(white, 1 - (t - k) / 0.14);
    }
    // Lightning, in the dark.
    for (final k in [58.15, 58.35, 59.2]) {
      if (t >= k && t < k + 0.09) white = math.max(white, 0.85);
    }
    // The chase: flicker on every world.
    if (t >= 60 && t < 63.5) {
      final local = (t - 60) % 0.25;
      if (local < 0.06) white = math.max(white, 0.55);
    }
    if (white > 0) {
      canvas.drawRect(
        rect,
        Paint()
          ..color = const Color(
            0xFFFFFBF0,
          ).withValues(alpha: white.clamp(0.0, 1.0)),
      );
    }
    // The dark: red at the edges, breathing.
    if (t > 55.5 && t < 60) {
      final k = ((t - 55.5) / 1.0).clamp(0.0, 1.0);
      final beat = 0.5 + 0.5 * math.sin(t * 5);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            radius: 0.85,
            colors: [
              Colors.transparent,
              const Color(
                0xFF7A0010,
              ).withValues(alpha: 0.55 * k * (0.6 + 0.4 * beat)),
            ],
          ).createShader(rect),
      );
      canvas.drawRect(
        rect,
        Paint()..color = Colors.black.withValues(alpha: 0.35 * k),
      );
    }
    // Speed: lines from the middle.
    final rushing = (t > 10.5 && t < 11.5) || (t > 60 && t < 63.5);
    if (rushing) {
      final rng = math.Random((t * 30).floor());
      final c = Offset(size.width / 2, size.height * 0.44);
      final line = Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..strokeWidth = 1.4;
      for (var i = 0; i < 44; i++) {
        final a = rng.nextDouble() * math.pi * 2;
        final r0 = size.height * (0.18 + rng.nextDouble() * 0.3);
        final r1 = r0 + size.height * (0.12 + rng.nextDouble() * 0.25);
        canvas.drawLine(
          c + Offset(math.cos(a), math.sin(a)) * r0,
          c + Offset(math.cos(a), math.sin(a)) * r1,
          line,
        );
      }
    }
    // The cut to black at the second impact.
    if (t >= 63.5 && t < 63.9) {
      canvas.drawRect(rect, Paint()..color = Colors.black);
    }
    if (t >= 63.9 && t < 64.6) {
      canvas.drawRect(
        rect,
        Paint()..color = Colors.black.withValues(alpha: 1 - (t - 63.9) / 0.7),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Overlay old) => true;
}
