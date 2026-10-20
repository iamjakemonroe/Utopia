import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/app_colors.dart';
import 'utopia_loader.dart';
import 'utopia_world.dart' show worldSeconds;
import 'world_sets.dart';
import 'ambient_tick.dart';
import 'frame_island.dart';

part 'coin_buddy_pose.dart';
part 'coin_buddy_costumes.dart';
part 'coin_buddy_around.dart';

enum BuddyMood {
  idle,
  thinking,
  happy,
  sad,

  /// Horns, a wicked grin and a shaking laugh (a "war" capture).
  evil,

  /// Closed-eye smile, a halo and floating hearts (a "friendly" capture).
  peaceful,

  /// Star eyes and spinning: about to teleport to another world.
  excited,

  /// Headphones on, eyes closed, bobbing to the music the player is
  /// listening to.
  vibing,

  /// Headphones on, eyes open, nodding slowly along: taking in a podcast,
  /// a sermon or a story.
  listening,

  /// Wide eyes on a video, little play sparks drifting up.
  watching,

  /// Overheated: flushed, sweating and fanning himself, steam rising,
  /// eyes fixed on whatever's so hot (a dragon breathing fire nearby).
  hot,
}

/// How Chip feels about what's on, layered over [BuddyMood.vibing],
/// [BuddyMood.watching] or [BuddyMood.listening]: a hype song gets him
/// bouncing, a sad one slows him down with a tear, a study video puts his
/// glasses on.
enum ChipFlavor {
  none,
  hype,
  dance,
  chill,
  romantic,
  sad,
  worship,
  study,
  funny,
  gaming,
  sports;

  /// From the vibe names Chip's brain uses ('hype', 'study', ...).
  static ChipFlavor fromVibe(String? vibe) => switch (vibe) {
    'hype' => hype,
    'dance' => dance,
    'chill' || 'calm' => chill,
    'romantic' => romantic,
    'sad' => sad,
    'worship' => worship,
    'study' || 'news' => study,
    'funny' => funny,
    'gaming' => gaming,
    'sports' => sports,
    _ => none,
  };
}

/// "Chip", Utopia's mascot: a living 3D coin. The body is a real coin with
/// thickness (gold rim layers between a face and a back, rotated in
/// perspective), so it sways and spins in 3D, showing the Utopia mark on its
/// back. The enamel face takes the theme's color; a glowing sprout and two
/// floating hands move on their own beat; and every mood has its own face,
/// motion and props.
class CoinBuddy extends StatefulWidget {
  const CoinBuddy({
    super.key,
    this.mood = BuddyMood.idle,
    this.size = 96,
    this.flavor = ChipFlavor.none,
    this.lookAt,
    this.beret,
    this.party,
  });

  final BuddyMood mood;
  final double size;

  /// His birthday party hat: on or off whatever the day (to show it off),
  /// or null to wear it on the player's birthday.
  final bool? party;

  /// His artist's beret: on or off whatever the player's plan (to show it
  /// off), or null to wear it when they're a Chip Maestro member.
  final bool? beret;

  /// Where Chip looks, -1 to 1 each way (left/up negative), for moods that
  /// fix on something; null lets his eyes wander.
  final Offset? lookAt;

  /// The feel of what's playing, for the vibing, watching and listening
  /// moods.
  final ChipFlavor flavor;

  /// Tests set this so every Chip blinks and wanders the same way each run.
  @visibleForTesting
  static double? debugSeed;

  @override
  State<CoinBuddy> createState() => _CoinBuddyState();
}

class _CoinBuddyState extends State<CoinBuddy>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _time = ValueNotifier(0);
  late final Ticker _ticker = createTicker(
    ambientTick((elapsed) => _time.value = elapsed.inMicroseconds / 1e6),
  );

  /// When the current mood started, in ticker seconds.
  double _moodSince = 0;

  /// Random-ish but stable per instance, so several Chips on screen don't
  /// blink in unison.
  late final double _seed =
      CoinBuddy.debugSeed ?? math.Random().nextDouble() * 10;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void didUpdateWidget(covariant CoinBuddy oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood) _moodSince = _time.value;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    // His own layer and layout (see FrameIsland): he's built again every
    // frame, and without them whatever he's on (a whole screen, often)
    // would be laid out and drawn again with him.
    return FrameIsland(
      size: Size.square(s),
      child: ValueListenableBuilder<double>(
        valueListenable: _time,
        builder: (context, t, _) {
          // What the sets dress him as, each 0 (not at all) to 1: bitten
          // in the Zombie world, winged in Heaven, horned in Hell, in a
          // headband facing the Dojo's dragon.
          final zombie = WorldSets.zombie.amount;
          final angel = WorldSets.heaven.amount;
          final devil = WorldSets.hell.amount;
          final fighter = WorldSets.dragon.amount;
          final dj = WorldSets.music.amount;
          final pumpkin = WorldSets.halloween.amount;
          final winter = WorldSets.winter.amount;
          final party = switch (widget.party) {
            true => 1.0,
            false => 0.0,
            null => WorldSets.birthday.amount,
          };
          final artist = switch (widget.beret) {
            true => 1.0,
            false => 0.0,
            null => WorldSets.maestro.amount,
          };
          final pose = _ChipPose.compute(
            mood: widget.mood,
            flavor: widget.flavor,
            t: t + _seed,
            sinceMood: t - _moodSince,
            lookAt: widget.lookAt,
            zombie: zombie,
            fighter: fighter,
            angel: angel,
            dj: dj,
          );
          final body = s * 0.72;
          final center = Offset(s / 2, s * 0.5 - pose.lift * s);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _AuraPainter(
                    mood: widget.mood,
                    flavor: widget.flavor,
                    t: t,
                    center: center,
                    radius: body / 2,
                    lift: pose.lift,
                    sinceMood: t - _moodSince,
                  ),
                ),
              ),
              if (angel > 0 || devil > 0 || dj > 0 || pumpkin > 0)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CostumeBackPainter(
                      t: t,
                      center: center,
                      radius: body / 2,
                      angel: angel,
                      devil: devil,
                      dj: dj,
                      pumpkin: pumpkin,
                    ),
                  ),
                ),
              for (final side in const [-1.0, 1.0])
                _hand(side, pose, center, body, s, zombie, winter),
              Positioned(
                left: center.dx - body / 2,
                top: center.dy - body / 2,
                width: body,
                height: body,
                child: Transform(
                  alignment: Alignment.bottomCenter,
                  transform: Matrix4.diagonal3Values(
                    pose.scaleX,
                    pose.scaleY,
                    1,
                  )..rotateZ(pose.roll),
                  child: _ChipBody(
                    size: body,
                    yaw: pose.yaw,
                    pitch: pose.pitch,
                    zombie: zombie,
                    face: _FacePainter(
                      mood: widget.mood,
                      flavor: widget.flavor,
                      blink: pose.blink,
                      look: pose.look,
                      t: t,
                      sinceMood: t - _moodSince,
                      zombie: zombie,
                      angel: angel,
                      devil: devil,
                      fighter: fighter,
                      artist: artist,
                      dj: dj,
                      pumpkin: pumpkin,
                      winter: winter,
                      party: party,
                    ),
                  ),
                ),
              ),
              if (widget.mood == BuddyMood.thinking)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ThoughtDotsPainter(
                      t: t,
                      origin: center.translate(body * 0.45, -body * 0.5),
                      scale: s,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _hand(
    double side,
    _ChipPose pose,
    Offset center,
    double body,
    double s,
    double zombie,
    double winter,
  ) {
    final r = s * 0.1;
    final wave = side > 0 ? pose.rightHand : pose.leftHand;
    // Hands sit out to the sides and drift in toward the body as it turns
    // away, which sells the 3D sway.
    final spread = body * 0.62 * (0.85 + 0.15 * math.cos(pose.yaw));
    final c = center.translate(
      side * spread + wave.dx * s,
      body * 0.12 + wave.dy * s,
    );
    return Positioned(
      left: c.dx - r,
      top: c.dy - r,
      width: r * 2,
      height: r * 2,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.35, -0.4),
            // Grey-green and rotting once he's turned; red mittens in
            // the Winter world's set.
            colors: [
              for (final (plain, dead, mitten) in const [
                (Colors.white, Color(0xFFC9D4B6), Color(0xFFFF7A84)),
                (Color(0xFFEDE6FF), Color(0xFF9DAE88), Color(0xFFD7263D)),
                (Color(0xFFBFB0E8), Color(0xFF66784F), Color(0xFF8A1424)),
              ])
                Color.lerp(
                  Color.lerp(plain, dead, zombie),
                  mitten,
                  winter.clamp(0.0, 1.0),
                )!,
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}

/// The coin body in 3D: back (the Utopia mark), gold rim layers, and the
/// painted face, sorted far-to-near for the current yaw.
class _ChipBody extends StatelessWidget {
  const _ChipBody({
    required this.size,
    required this.yaw,
    required this.pitch,
    required this.face,
    this.zombie = 0,
  });

  final double size;
  final double yaw;
  final double pitch;
  final CustomPainter face;

  /// How far Chip has turned: the rim tarnishes and a bite comes out of
  /// the whole coin.
  final double zombie;

  static const _layers = 8;

  @override
  Widget build(BuildContext context) {
    final gap = size * 0.013;
    final half = _layers * gap / 2;
    final frontFacing = math.cos(yaw) * math.cos(pitch) >= 0;

    Widget at(double z, Widget child) => Transform(
      alignment: Alignment.center,
      transform: Matrix4.translationValues(0, 0, z),
      child: child,
    );

    final front = at(
      -half,
      CustomPaint(size: Size.square(size), painter: face),
    );
    final back = at(
      half,
      Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(math.pi),
        child: Image(
          image: const AssetImage(kCoinFaceAsset),
          width: size,
          height: size,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
    final rim = [
      for (var i = 0; i < _layers; i++)
        at(
          half - (i + 0.5) * gap,
          Container(
            width: size * 0.985,
            height: size * 0.985,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.lerp(
                Color.lerp(
                  const Color(0xFFFFD66B),
                  const Color(0xFFB8801F),
                  i.isEven ? 0.35 : 0.6,
                ),
                Color.lerp(
                  const Color(0xFFC2BC8A),
                  const Color(0xFF6E6840),
                  i.isEven ? 0.35 : 0.6,
                ),
                zombie,
              ),
            ),
          ),
        ),
    ];

    Widget coin = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: frontFacing
          ? [back, ...rim, front]
          : [front, ...rim.reversed, back],
    );
    if (zombie > 0) {
      coin = ClipPath(clipper: _BiteClipper(zombie), child: coin);
    }
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.25 / size)
        ..rotateX(pitch)
        ..rotateY(yaw),
      child: coin,
    );
  }
}

/// The bite out of a turned Chip's coin, at the upper right: three
/// overlapping tooth-round scoops that grow in with [amount].
Path _chipBite(Offset c, double r, double amount) {
  final path = Path();
  for (final (deg, k) in const [(-64.0, 0.78), (-45.0, 1.0), (-26.0, 0.84)]) {
    final a = deg * math.pi / 180;
    path.addOval(
      Rect.fromCircle(
        center: c + Offset(math.cos(a), math.sin(a)) * r * 1.02,
        radius: r * 0.21 * k * amount,
      ),
    );
  }
  return path;
}

/// Everything but the bite, with room around the coin for the sprout and
/// hands-free props that reach past it.
class _BiteClipper extends CustomClipper<Path> {
  const _BiteClipper(this.amount);

  final double amount;

  @override
  Path getClip(Size size) {
    final r = size.width / 2;
    return Path.combine(
      PathOperation.difference,
      Path()..addRect((Offset.zero & size).inflate(size.width)),
      _chipBite(Offset(r, r), r, amount),
    );
  }

  @override
  bool shouldReclip(covariant _BiteClipper oldClipper) =>
      oldClipper.amount != amount;
}

class _FacePainter extends CustomPainter {
  _FacePainter({
    required this.mood,
    this.flavor = ChipFlavor.none,
    required this.blink,
    required this.look,
    required this.t,
    required this.sinceMood,
    this.zombie = 0,
    this.angel = 0,
    this.devil = 0,
    this.fighter = 0,
    this.artist = 0,
    this.dj = 0,
    this.pumpkin = 0,
    this.winter = 0,
    this.party = 0,
  });

  final BuddyMood mood;
  final ChipFlavor flavor;
  final double blink;
  final Offset look;
  final double t;
  final double sinceMood;

  /// How far Chip has turned, 0 to 1.
  final double zombie;

  /// Halo (Heaven's set), baby horns and red eyes (Hell's), the headband
  /// (the Dojo's), each 0 to 1.
  final double angel;
  final double devil;
  final double fighter;

  /// Chip Maestro's beret and brush, 0 to 1.
  final double artist;

  /// DJ Chip (the Music world's set): headphones and neon shades, 0 to 1.
  final double dj;

  /// Jack-o'-lantern Chip (the Halloween world's set): carved and lit from
  /// inside, in a witch's hat, 0 to 1.
  final double pumpkin;

  /// Wrapped up for winter (the Winter world's set): a Santa hat, a knitted
  /// scarf, mittens, and his breath puffing in the cold, 0 to 1.
  final double winter;

  /// The player's birthday: a party hat (in place of his beret), 0 to 1.
  final double party;

  /// Turned far enough that his face is a zombie's, whatever his mood.
  bool get _dead => zombie >= 0.5;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);

    _sprout(canvas, c, r);
    if (mood == BuddyMood.evil && !_dead) {
      _horns(canvas, c, r);
    } else if (devil > 0 && !_dead) {
      _babyHorns(canvas, c, r);
    }

    // Gold rim with reeding, then the enamel face in the theme's color.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          // Tarnished once he's turned.
          colors: [
            Color.lerp(
              const Color(0xFFFFF0B8),
              const Color(0xFFD9D7B0),
              zombie,
            )!,
            Color.lerp(
              const Color(0xFFFFC94D),
              const Color(0xFFA59E6A),
              zombie,
            )!,
            Color.lerp(
              const Color(0xFFC98A1E),
              const Color(0xFF625C38),
              zombie,
            )!,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final notch = Paint()
      ..color = Color.lerp(
        const Color(0x66A8701A),
        const Color(0x66403A22),
        zombie,
      )!
      ..strokeWidth = r * 0.025;
    for (var i = 0; i < 28; i++) {
      final a = i / 28 * 2 * math.pi;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * r * 0.86, c + dir * r * 0.97, notch);
    }
    final enamelR = r * 0.8;
    // On a light world the theme color is ink, which would hide the face,
    // so Chip's face goes paper-white there, like a drawing of him.
    final accent = Color.lerp(
      Color.lerp(
        mood == BuddyMood.evil
            ? const Color(0xFFB0244A)
            : AppColors.light
            ? const Color(0xFFF4EFE2)
            : AppColors.accent,
        // Grey-green dead skin once he's turned.
        const Color(0xFF8C9C74),
        zombie * (mood == BuddyMood.evil ? 0.7 : 1),
      ),
      // Pumpkin orange once he's carved.
      const Color(0xFFE8701A),
      pumpkin.clamp(0.0, 1.0),
    )!;
    canvas.drawCircle(
      c,
      enamelR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.45),
          colors: [
            Color.lerp(accent, Colors.white, 0.45)!,
            accent,
            Color.lerp(accent, Colors.black, 0.35)!,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: enamelR)),
    );
    canvas.drawCircle(
      c,
      enamelR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.04
        ..color = const Color(0x88FFF0B8),
    );

    if (zombie > 0) _rot(canvas, c, r);
    if (pumpkin > 0) _ribs(canvas, c, enamelR);
    if (_dead) {
      _zombieFace(canvas, c, r);
    } else if (pumpkin >= 0.5) {
      _carved(canvas, c, r);
    } else {
      _cheeks(canvas, c, r);
      _eyes(canvas, c, r);
      _brows(canvas, c, r);
      _mouth(canvas, c, r);
      if (mood == BuddyMood.sad ||
          (mood == BuddyMood.vibing && flavor == ChipFlavor.sad)) {
        _tear(canvas, c, r);
      }
      if (mood == BuddyMood.watching && flavor == ChipFlavor.study) {
        _glasses(canvas, c, r);
      }
      if (winter > 0) _breath(canvas, c, r);
    }
    if (dj > 0 && !_dead) _shades(canvas, c, r);
    if (mood == BuddyMood.vibing || mood == BuddyMood.listening) {
      _headphones(canvas, c, r);
    } else if (dj > 0) {
      canvas.saveLayer(
        null,
        Paint()..color = Colors.black.withValues(alpha: dj.clamp(0.0, 1.0)),
      );
      _headphones(canvas, c, r);
      canvas.restore();
    }
    if (mood == BuddyMood.hot) _heat(canvas, c, r);

    // Glossy sheen across the top of the face.
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(-r * 0.25, -r * 0.62),
        width: r * 1.3,
        height: r * 0.5,
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.22 * (1 - zombie * 0.6)),
    );
    canvas.restore();

    if (zombie > 0) {
      // A dark, ragged edge where the bite came out.
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
      canvas.drawPath(
        _chipBite(c, r, zombie),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.07
          ..color = const Color(0xFF3A2C1C).withValues(alpha: zombie),
      );
      canvas.restore();
    }
    if (winter > 0 && !_dead) _scarf(canvas, c, r);
    if (fighter > 0) _headband(canvas, c, r);
    if (artist > 0 && party < 0.5 && winter < 0.5) _beret(canvas, c, r);
    if (angel > 0) _halo(canvas, c, r);
    if (pumpkin > 0) _witchHat(canvas, c, r);
    if (winter > 0 && party < 0.5) _santaHat(canvas, c, r);
    if (party > 0 && pumpkin < 0.5) _partyHat(canvas, c, r);
  }

  /// Sweat running down and steam curling off the top.
  void _heat(Canvas canvas, Offset c, double r) {
    final drop = Paint()..color = const Color(0xFFBFE9FF);
    for (var i = 0; i < 2; i++) {
      final k = ((t * 0.7 + i * 0.5) % 1.0);
      final side = i == 0 ? -1.0 : 1.0;
      final at = c.translate(
        side * r * (0.66 + 0.06 * k),
        -r * 0.25 + k * r * 0.6,
      );
      final s = r * 0.09 * (1 - k * 0.3);
      canvas.drawPath(
        Path()
          ..moveTo(at.dx, at.dy - s * 1.6)
          ..quadraticBezierTo(at.dx + s, at.dy, at.dx, at.dy + s * 0.8)
          ..quadraticBezierTo(at.dx - s, at.dy, at.dx, at.dy - s * 1.6)
          ..close(),
        drop..color = const Color(0xFFBFE9FF).withValues(alpha: 1 - k * 0.6),
      );
    }
    final steam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.05
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final k = (t * 0.6 + i / 3) % 1.0;
      final x = c.dx + (i - 1) * r * 0.38;
      final y = c.dy - r * (1.0 + 0.7 * k);
      final path = Path()..moveTo(x, y + r * 0.25);
      for (var j = 1; j <= 6; j++) {
        path.lineTo(
          x + math.sin(j * 1.2 + t * 4 + i) * r * 0.06,
          y + r * 0.25 - j * r * 0.06,
        );
      }
      canvas.drawPath(
        path,
        steam
          ..color = Colors.white.withValues(alpha: 0.5 * math.sin(k * math.pi)),
      );
    }
  }

  void _sprout(Canvas canvas, Offset c, double r) {
    // Turned, it wilts: the stem bends over, the leaves droop and brown,
    // and the bud goes out.
    final wilt = zombie;
    final sway = math.sin(t * 1.7) * r * 0.12 * (1 - 0.7 * wilt);
    final base = c.translate(0, -r * 0.92);
    final tip = base.translate(
      sway + r * 0.3 * wilt,
      -r * 0.5 + r * 0.24 * wilt,
    );
    final stem = Color.lerp(
      const Color(0xFF2DBE8C),
      const Color(0xFF6B6A3E),
      wilt,
    )!;
    canvas.drawPath(
      Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(
          base.dx - r * 0.1 + r * 0.14 * wilt,
          base.dy - r * 0.3 - r * 0.14 * wilt,
          tip.dx,
          tip.dy,
        ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.07
        ..strokeCap = StrokeCap.round
        ..color = stem,
    );
    final leaf = Paint()
      ..shader = LinearGradient(
        colors: [
          Color.lerp(const Color(0xFFB8FFE0), const Color(0xFFB9B48A), wilt)!,
          stem,
        ],
      ).createShader(Rect.fromCircle(center: tip, radius: r * 0.3));
    for (final side in const [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(tip.dx, tip.dy + r * 0.12);
      canvas.rotate(
        side * (0.9 + 0.12 * math.sin(t * 2.1 + side) * (1 - wilt)) +
            0.7 * wilt,
      );
      canvas.drawOval(Rect.fromLTWH(0, -r * 0.08, r * 0.32, r * 0.16), leaf);
      canvas.restore();
    }
    // Glowing bud at the tip, pulsing.
    final pulse = 0.75 + 0.25 * math.sin(t * 3);
    canvas.drawCircle(
      tip,
      r * 0.22 * pulse,
      Paint()
        ..color = const Color(0xFFFFE29A).withValues(alpha: 0.3 * (1 - wilt)),
    );
    canvas.drawCircle(
      tip,
      r * 0.09,
      Paint()
        ..color = Color.lerp(
          const Color(0xFFFFF4C9),
          const Color(0xFF9C9A6E),
          wilt,
        )!,
    );
  }

  void _horns(Canvas canvas, Offset c, double r) {
    final grow = Curves.elasticOut.transform((sinceMood / 0.7).clamp(0.0, 1.0));
    if (grow <= 0) return;
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Color(0xFF7A0F2E), Color(0xFFFF4D6D)],
      ).createShader(Rect.fromCircle(center: c, radius: r * 1.4));
    for (final side in const [-1.0, 1.0]) {
      final base = c.translate(side * r * 0.5, -r * 0.78);
      final tip = base.translate(side * r * 0.32 * grow, -r * 0.55 * grow);
      canvas.drawPath(
        Path()
          ..moveTo(base.dx - side * r * 0.2, base.dy + r * 0.1)
          ..quadraticBezierTo(
            base.dx + side * r * 0.05,
            base.dy - r * 0.35 * grow,
            tip.dx,
            tip.dy,
          )
          ..quadraticBezierTo(
            base.dx + side * r * 0.32,
            base.dy - r * 0.05,
            base.dx + side * r * 0.22,
            base.dy + r * 0.14,
          )
          ..close(),
        paint,
      );
    }
  }

  void _cheeks(Canvas canvas, Offset c, double r) {
    final blush = switch (mood) {
      BuddyMood.happy ||
      BuddyMood.excited ||
      BuddyMood.peaceful ||
      BuddyMood.vibing => 0.55,
      BuddyMood.evil => 0.2,
      BuddyMood.hot => 0.85 + 0.1 * math.sin(t * 3),
      _ => 0.35,
    };
    final paint = Paint()
      ..color = Color.lerp(
        (mood == BuddyMood.hot
                ? const Color(0xFFFF4A3A)
                : const Color(0xFFFF8FB8))
            .withValues(alpha: blush),
        // No blood in the cheeks once he's turned.
        const Color(0x7355663F),
        zombie,
      )!;
    for (final side in const [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(side * r * 0.5, r * 0.2),
          width: r * 0.26,
          height: r * 0.14,
        ),
        paint,
      );
    }
  }

  void _eyes(Canvas canvas, Offset c, double r) {
    final ink = Paint()..color = AppColors.faceInk;
    for (final side in const [-1.0, 1.0]) {
      final e = c.translate(side * r * 0.3, -r * 0.1);
      switch (mood) {
        case BuddyMood.vibing
            when flavor == ChipFlavor.hype ||
                flavor == ChipFlavor.dance ||
                flavor == ChipFlavor.romantic:
          // Grinning with his eyes shut: this one's a banger.
          canvas.drawArc(
            Rect.fromCenter(
              center: e.translate(0, r * 0.06),
              width: r * 0.32,
              height: r * 0.3,
            ),
            math.pi * 1.1,
            math.pi * 0.8,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = r * 0.07
              ..strokeCap = StrokeCap.round
              ..color = AppColors.faceInk,
          );
        case BuddyMood.watching when flavor == ChipFlavor.funny:
          // Laughing too hard to keep his eyes open.
          canvas.drawArc(
            Rect.fromCenter(
              center: e.translate(0, r * 0.06),
              width: r * 0.3,
              height: r * 0.26,
            ),
            math.pi * 1.1,
            math.pi * 0.8,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = r * 0.07
              ..strokeCap = StrokeCap.round
              ..color = AppColors.faceInk,
          );
        case BuddyMood.vibing:
          // Eyes closed, lost in the music: soft downward curves.
          canvas.drawArc(
            Rect.fromCenter(
              center: e.translate(0, -r * 0.04),
              width: r * 0.3,
              height: r * 0.22,
            ),
            math.pi * 0.15,
            math.pi * 0.7,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = r * 0.07
              ..strokeCap = StrokeCap.round
              ..color = AppColors.faceInk,
          );
        case BuddyMood.happy:
        case BuddyMood.peaceful:
          // Closed, smiling "^" eyes.
          canvas.drawArc(
            Rect.fromCenter(
              center: e.translate(0, r * 0.06),
              width: r * 0.32,
              height: r * 0.3,
            ),
            math.pi * 1.1,
            math.pi * 0.8,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = r * 0.07
              ..strokeCap = StrokeCap.round
              ..color = AppColors.faceInk,
          );
        case BuddyMood.excited:
          _sclera(canvas, e, r, 1);
          _star(canvas, e, r * 0.16, const Color(0xFFFFC94D), t * 2);
        case BuddyMood.evil:
          // Narrowed, slanted eyes with a red glint.
          final eye = Path()
            ..moveTo(e.dx - r * 0.17, e.dy - side * r * 0.0 - r * 0.02)
            ..lineTo(
              e.dx + r * 0.17,
              e.dy - (side < 0 ? -1 : 1) * r * 0.0 + r * 0.02,
            )
            ..quadraticBezierTo(
              e.dx,
              e.dy + r * 0.2,
              e.dx - r * 0.17,
              e.dy - r * 0.02,
            )
            ..close();
          canvas.drawPath(eye, Paint()..color = Colors.white);
          canvas.drawCircle(
            e.translate(-side * r * 0.03, r * 0.06),
            r * 0.075,
            ink,
          );
          canvas.drawCircle(
            e.translate(-side * r * 0.03 - r * 0.02, r * 0.04),
            r * 0.025,
            Paint()..color = const Color(0xFFFF6B6B),
          );
        case BuddyMood.idle:
        case BuddyMood.thinking:
        case BuddyMood.sad:
        case BuddyMood.listening:
        case BuddyMood.watching:
        case BuddyMood.hot:
          final open = (1 - blink) * (mood == BuddyMood.watching ? 1.12 : 1);
          if (open < 0.15) {
            canvas.drawLine(
              e.translate(-r * 0.13, 0),
              e.translate(r * 0.13, 0),
              Paint()
                ..strokeWidth = r * 0.06
                ..strokeCap = StrokeCap.round
                ..color = AppColors.faceInk,
            );
            break;
          }
          _sclera(canvas, e, r, open);
          final pupil = e.translate(
            look.dx * r * 0.06,
            look.dy * r * 0.07 * open,
          );
          // Turned, the pupils shrink to pinpricks.
          final shrink = 1 - 0.45 * zombie;
          // Hell's set gives him little red eyes, glowing.
          if (devil > 0) {
            canvas.drawCircle(
              pupil,
              r * 0.16,
              Paint()
                ..color = const Color(0xFFFF2A2A).withValues(alpha: 0.3 * devil)
                ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.05),
            );
          }
          canvas.drawOval(
            Rect.fromCenter(
              center: pupil,
              width: r * 0.2 * shrink,
              height: r * 0.24 * open * shrink,
            ),
            devil > 0
                ? (Paint()
                    ..color = Color.lerp(
                      AppColors.faceInk,
                      const Color(0xFFC0121E),
                      devil,
                    )!)
                : ink,
          );
          canvas.drawCircle(
            pupil.translate(-r * 0.04, -r * 0.06 * open),
            r * 0.045,
            Paint()..color = Colors.white,
          );
          canvas.drawCircle(
            pupil.translate(r * 0.04, r * 0.04 * open),
            r * 0.02,
            Paint()..color = Colors.white.withValues(alpha: 0.8),
          );
          if (zombie > 0 && side > 0) _droopyLid(canvas, e, r, open);
      }
    }
  }

  /// One heavy lid half down over a turned Chip's right eye.
  void _droopyLid(Canvas canvas, Offset e, double r, double open) {
    final eye = Rect.fromCenter(
      center: e,
      width: r * 0.36,
      height: r * 0.44 * open,
    );
    final line = eye.top + eye.height * 0.42 * zombie;
    canvas.save();
    canvas.clipPath(Path()..addOval(eye.inflate(0.5)));
    canvas.drawRect(
      Rect.fromLTRB(eye.left - 1, eye.top - 1, eye.right + 1, line),
      Paint()..color = const Color(0xFF7D8D66),
    );
    canvas.restore();
    canvas.drawLine(
      Offset(eye.left + r * 0.02, line + r * 0.01),
      Offset(eye.right - r * 0.02, line - r * 0.01),
      Paint()
        ..strokeWidth = r * 0.04
        ..strokeCap = StrokeCap.round
        ..color = AppColors.faceInk.withValues(alpha: zombie),
    );
  }

  void _sclera(Canvas canvas, Offset e, double r, double open) {
    canvas.drawOval(
      Rect.fromCenter(center: e, width: r * 0.36, height: r * 0.44 * open),
      // Yellowed once he's turned.
      Paint()
        ..color = Color.lerp(Colors.white, const Color(0xFFDCE3B8), zombie)!,
    );
  }

  void _star(Canvas canvas, Offset c, double r, Color color, double spin) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = spin + i * math.pi / 5 - math.pi / 2;
      final rr = i.isEven ? r : r * 0.45;
      final p = c + Offset(math.cos(a), math.sin(a)) * rr;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  void _brows(Canvas canvas, Offset c, double r) {
    final paint = Paint()
      ..strokeWidth = r * 0.06
      ..strokeCap = StrokeCap.round
      ..color = AppColors.faceInk;
    for (final side in const [-1.0, 1.0]) {
      final b = c.translate(side * r * 0.3, -r * 0.42);
      // Squaring up to the dragon: determined brows, whatever the mood
      // (but not when he's too hot, or sad).
      final determined =
          fighter >= 0.5 && mood != BuddyMood.hot && mood != BuddyMood.sad;
      final (inner, outer) = switch (mood) {
        _ when determined => (r * 0.1, -r * 0.05),
        BuddyMood.evil => (r * 0.1, -r * 0.06),
        BuddyMood.sad => (-r * 0.08, r * 0.05),
        BuddyMood.thinking => side > 0 ? (-r * 0.08, -r * 0.08) : (0.0, 0.0),
        BuddyMood.excited => (-r * 0.06, -r * 0.06),
        BuddyMood.listening => (-r * 0.03, -r * 0.05),
        BuddyMood.vibing when flavor == ChipFlavor.sad => (-r * 0.08, r * 0.05),
        BuddyMood.watching => (-r * 0.08, -r * 0.08),
        BuddyMood.hot => (-r * 0.09, r * 0.03),
        _ => (0.0, 0.0),
      };
      if (!determined &&
          (mood == BuddyMood.happy ||
              mood == BuddyMood.peaceful ||
              (mood == BuddyMood.vibing && flavor != ChipFlavor.sad))) {
        continue;
      }
      canvas.drawLine(
        b.translate(-side * r * 0.12, inner),
        b.translate(side * r * 0.12, outer),
        paint,
      );
    }
  }

  void _mouth(Canvas canvas, Offset c, double r) {
    final m = c.translate(0, r * 0.34);
    final ink = Paint()..color = AppColors.faceInk;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.065
      ..strokeCap = StrokeCap.round
      ..color = AppColors.faceInk;
    switch (mood) {
      case BuddyMood.watching when flavor == ChipFlavor.funny:
        // A big open laugh.
        canvas.drawPath(
          Path()
            ..moveTo(m.dx - r * 0.2, m.dy - r * 0.08)
            ..quadraticBezierTo(
              m.dx,
              m.dy + r * 0.28,
              m.dx + r * 0.2,
              m.dy - r * 0.08,
            )
            ..close(),
          ink,
        );
      case BuddyMood.watching when (t % 4.2) < 1.1:
        // A little "ooh" at the good part.
        canvas.drawOval(
          Rect.fromCenter(
            center: m.translate(0, -r * 0.03),
            width: r * 0.13,
            height: r * 0.16,
          ),
          ink,
        );
      case BuddyMood.hot:
        // Panting, tongue out.
        final pant = 0.85 + 0.15 * math.sin(t * 9);
        canvas.drawOval(
          Rect.fromCenter(center: m, width: r * 0.24, height: r * 0.2 * pant),
          ink,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: m.translate(0, r * 0.07 * pant),
            width: r * 0.14,
            height: r * 0.1,
          ),
          Paint()..color = const Color(0xFFFF6F8E),
        );
      case BuddyMood.idle:
      case BuddyMood.listening:
      case BuddyMood.watching:
        canvas.drawArc(
          Rect.fromCenter(
            center: m.translate(0, -r * 0.06),
            width: r * 0.36,
            height: r * 0.24,
          ),
          0.15 * math.pi,
          0.7 * math.pi,
          false,
          line,
        );
      case BuddyMood.vibing:
        // Smiling, and every so often singing along.
        final singing = (t % 2.6) < 0.9;
        if (singing) {
          final open = 0.6 + 0.4 * math.sin(t * 10).abs();
          canvas.drawOval(
            Rect.fromCenter(
              center: m.translate(0, -r * 0.02),
              width: r * 0.18,
              height: r * 0.2 * open,
            ),
            ink,
          );
        } else {
          canvas.drawArc(
            Rect.fromCenter(
              center: m.translate(0, -r * 0.08),
              width: r * 0.4,
              height: r * 0.28,
            ),
            0.12 * math.pi,
            0.76 * math.pi,
            false,
            line,
          );
        }
      case BuddyMood.peaceful:
        canvas.drawArc(
          Rect.fromCenter(
            center: m.translate(0, -r * 0.08),
            width: r * 0.44,
            height: r * 0.3,
          ),
          0.12 * math.pi,
          0.76 * math.pi,
          false,
          line,
        );
      case BuddyMood.happy:
      case BuddyMood.excited:
        final open = mood == BuddyMood.excited ? 1.25 : 1.0;
        final mouth = Path()
          ..moveTo(m.dx - r * 0.26, m.dy - r * 0.06)
          ..quadraticBezierTo(
            m.dx,
            m.dy - r * 0.0,
            m.dx + r * 0.26,
            m.dy - r * 0.06,
          )
          ..quadraticBezierTo(
            m.dx,
            m.dy + r * 0.34 * open,
            m.dx - r * 0.26,
            m.dy - r * 0.06,
          )
          ..close();
        canvas.drawPath(mouth, ink);
        canvas.save();
        canvas.clipPath(mouth);
        canvas.drawCircle(
          m.translate(0, r * 0.24 * open),
          r * 0.14,
          Paint()..color = const Color(0xFFFF7A9C),
        );
        canvas.restore();
      case BuddyMood.sad:
        canvas.drawArc(
          Rect.fromCenter(
            center: m.translate(0, r * 0.12),
            width: r * 0.34,
            height: r * 0.22,
          ),
          1.15 * math.pi,
          0.7 * math.pi,
          false,
          line,
        );
      case BuddyMood.thinking:
        canvas.drawOval(
          Rect.fromCenter(
            center: m.translate(r * 0.12, 0),
            width: r * 0.14,
            height: r * 0.12,
          ),
          ink,
        );
      case BuddyMood.evil:
        // A wide, wicked crescent grin with two little fangs.
        final grin = Path()
          ..moveTo(m.dx - r * 0.38, m.dy - r * 0.14)
          ..quadraticBezierTo(
            m.dx,
            m.dy + r * 0.06,
            m.dx + r * 0.38,
            m.dy - r * 0.14,
          )
          ..quadraticBezierTo(
            m.dx,
            m.dy + r * 0.38,
            m.dx - r * 0.38,
            m.dy - r * 0.14,
          )
          ..close();
        canvas.drawPath(grin, ink);
        final fang = Paint()..color = Colors.white;
        for (final side in const [-1.0, 1.0]) {
          final f = m.translate(side * r * 0.14, -r * 0.02);
          canvas.drawPath(
            Path()
              ..moveTo(f.dx - r * 0.05, f.dy - r * 0.03)
              ..lineTo(f.dx + r * 0.05, f.dy - r * 0.03)
              ..lineTo(f.dx, f.dy + r * 0.09)
              ..close(),
            fang,
          );
        }
    }
  }

  /// Round study glasses over the eyes.
  void _glasses(Canvas canvas, Offset c, double r) {
    final frame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.05
      ..color = AppColors.faceInk;
    for (final side in const [-1.0, 1.0]) {
      canvas.drawCircle(c.translate(side * r * 0.3, -r * 0.1), r * 0.21, frame);
      canvas.drawCircle(
        c.translate(side * r * 0.3 - r * 0.07, -r * 0.18),
        r * 0.04,
        Paint()..color = Colors.white.withValues(alpha: 0.7),
      );
    }
    canvas.drawLine(
      c.translate(-r * 0.09, -r * 0.12),
      c.translate(r * 0.09, -r * 0.12),
      frame,
    );
  }

  void _tear(Canvas canvas, Offset c, double r) {
    final p = (t % 2.2) / 2.2;
    final drop = c.translate(-r * 0.38, -r * 0.0 + p * r * 0.55);
    final alpha = math.sin(p * math.pi);
    canvas.drawPath(
      Path()
        ..moveTo(drop.dx, drop.dy - r * 0.1)
        ..quadraticBezierTo(
          drop.dx + r * 0.07,
          drop.dy,
          drop.dx,
          drop.dy + r * 0.05,
        )
        ..quadraticBezierTo(
          drop.dx - r * 0.07,
          drop.dy,
          drop.dx,
          drop.dy - r * 0.1,
        ),
      Paint()..color = const Color(0xFF8FD3FF).withValues(alpha: 0.9 * alpha),
    );
  }

  @override
  bool shouldRepaint(covariant _FacePainter oldDelegate) => true;
}
