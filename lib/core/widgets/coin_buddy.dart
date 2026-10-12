import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/app_colors.dart';
import 'utopia_loader.dart';
import 'world_sets.dart';

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
  });

  final BuddyMood mood;
  final double size;

  /// Where Chip looks, -1 to 1 each way (left/up negative), for moods that
  /// fix on something; null lets his eyes wander.
  final Offset? lookAt;

  /// The feel of what's playing, for the vibing, watching and listening
  /// moods.
  final ChipFlavor flavor;

  @override
  State<CoinBuddy> createState() => _CoinBuddyState();
}

class _CoinBuddyState extends State<CoinBuddy>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _time = ValueNotifier(0);
  late final Ticker _ticker = createTicker(
    (elapsed) => _time.value = elapsed.inMicroseconds / 1e6,
  );

  /// When the current mood started, in ticker seconds.
  double _moodSince = 0;

  /// Random-ish but stable per instance, so several Chips on screen don't
  /// blink in unison.
  late final double _seed = math.Random().nextDouble() * 10;

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
    return SizedBox.square(
      dimension: s,
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
          final pose = _ChipPose.compute(
            mood: widget.mood,
            flavor: widget.flavor,
            t: t + _seed,
            sinceMood: t - _moodSince,
            lookAt: widget.lookAt,
            zombie: zombie,
            fighter: fighter,
            angel: angel,
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
              if (angel > 0 || devil > 0)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CostumeBackPainter(
                      t: t,
                      center: center,
                      radius: body / 2,
                      angel: angel,
                      devil: devil,
                    ),
                  ),
                ),
              for (final side in const [-1.0, 1.0])
                _hand(side, pose, center, body, s, zombie),
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
            // Grey-green and rotting once he's turned.
            colors: [
              Color.lerp(Colors.white, const Color(0xFFC9D4B6), zombie)!,
              Color.lerp(
                const Color(0xFFEDE6FF),
                const Color(0xFF9DAE88),
                zombie,
              )!,
              Color.lerp(
                const Color(0xFFBFB0E8),
                const Color(0xFF66784F),
                zombie,
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

/// Where everything is at time [t] for a [mood].
class _ChipPose {
  const _ChipPose({
    required this.lift,
    required this.yaw,
    required this.pitch,
    required this.roll,
    required this.scaleX,
    required this.scaleY,
    required this.blink,
    required this.look,
    required this.leftHand,
    required this.rightHand,
  });

  /// Height above rest, as a fraction of the widget size.
  final double lift;
  final double yaw;
  final double pitch;
  final double roll;
  final double scaleX;
  final double scaleY;

  /// 0 eyes open, 1 shut.
  final double blink;

  /// Pupil offset, -1..1.
  final Offset look;

  /// Hand offsets from their rest spots, as fractions of the widget size.
  final Offset leftHand;
  final Offset rightHand;

  static _ChipPose lerp(_ChipPose a, _ChipPose b, double k) {
    double l(double x, double y) => x + (y - x) * k;
    return _ChipPose(
      lift: l(a.lift, b.lift),
      yaw: l(a.yaw, b.yaw),
      pitch: l(a.pitch, b.pitch),
      roll: l(a.roll, b.roll),
      scaleX: l(a.scaleX, b.scaleX),
      scaleY: l(a.scaleY, b.scaleY),
      blink: l(a.blink, b.blink),
      look: Offset.lerp(a.look, b.look, k)!,
      leftHand: Offset.lerp(a.leftHand, b.leftHand, k)!,
      rightHand: Offset.lerp(a.rightHand, b.rightHand, k)!,
    );
  }

  /// The pose for [mood], with what a set dresses him as layered over it:
  /// an angel floats, a fighter squares up (unless he's too hot, facing
  /// the dragon), a zombie shambles whatever his mood.
  static _ChipPose compute({
    required BuddyMood mood,
    ChipFlavor flavor = ChipFlavor.none,
    required double t,
    required double sinceMood,
    Offset? lookAt,
    double zombie = 0,
    double fighter = 0,
    double angel = 0,
  }) {
    var pose = _forMood(
      mood: mood,
      flavor: flavor,
      t: t,
      sinceMood: sinceMood,
      lookAt: lookAt,
    );
    if (angel > 0) {
      // Wings keep him a little higher, drifting.
      pose = _ChipPose(
        lift: pose.lift + angel * (0.03 + 0.015 * math.sin(t * 1.3)),
        yaw: pose.yaw,
        pitch: pose.pitch,
        roll: pose.roll + angel * 0.03 * math.sin(t * 0.7),
        scaleX: pose.scaleX,
        scaleY: pose.scaleY,
        blink: pose.blink,
        look: pose.look,
        leftHand: pose.leftHand,
        rightHand: pose.rightHand,
      );
    }
    if (fighter > 0 && mood != BuddyMood.hot) {
      pose = lerp(pose, _fight(t), fighter);
    }
    if (zombie > 0) pose = lerp(pose, _shamble(t), zombie);
    return pose;
  }

  /// Squared up to fight: bouncing on his toes, fists up by his face, a
  /// quick jab every so often.
  static _ChipPose _fight(double t) {
    final bounce = math.sin(t * 7).abs();
    final beat = t % 1.6;
    final jab = beat < 0.2 ? math.sin(beat / 0.2 * math.pi) : 0.0;
    final blinkPhase = t % 3.7;
    return _ChipPose(
      lift: 0.012 + bounce * 0.025,
      yaw: 0.12 * math.sin(t * 0.9),
      pitch: 0.06,
      roll: 0.05 * math.sin(t * 3.5),
      scaleX: 1 + 0.02 * bounce,
      scaleY: 1 - 0.02 * bounce,
      blink: blinkPhase < 0.12 ? math.sin(blinkPhase / 0.12 * math.pi) : 0.0,
      look: const Offset(0, 0.1),
      leftHand: Offset(0.12, -0.15 + 0.02 * math.sin(t * 7)),
      rightHand: Offset(-0.1 - 0.12 * jab, -0.12 - 0.05 * jab),
    );
  }

  /// Turned: a lurching shamble, head lolling, slow heavy blinks, both arms
  /// up and out in front.
  static _ChipPose _shamble(double t) {
    final step = math.sin(t * 1.5);
    final blinkPhase = t % 3.7;
    return _ChipPose(
      lift: 0.01 + step.abs() * 0.025,
      yaw: 0.16 * math.sin(t * 0.75),
      pitch: 0.1 + 0.04 * math.sin(t * 1.1),
      roll: 0.16 * step,
      scaleX: 1,
      scaleY: 1,
      blink: blinkPhase < 0.5 ? math.sin(blinkPhase / 0.5 * math.pi) : 0.0,
      look: Offset(0.3 * math.sin(t * 0.4), 0.2),
      leftHand: Offset(0.08, -0.13 + 0.03 * math.sin(t * 1.5)),
      rightHand: Offset(-0.08, -0.13 + 0.03 * math.sin(t * 1.5 + 1.2)),
    );
  }

  static _ChipPose _forMood({
    required BuddyMood mood,
    ChipFlavor flavor = ChipFlavor.none,
    required double t,
    required double sinceMood,
    Offset? lookAt,
  }) {
    // Mood change: an anticipation squash, then a springy overshoot.
    var popX = 1.0;
    var popY = 1.0;
    if (sinceMood < 0.6) {
      final p = sinceMood / 0.6;
      if (p < 0.2) {
        final a = math.sin(p / 0.2 * math.pi) * 0.12;
        popX = 1 + a * 0.7;
        popY = 1 - a;
      } else {
        final e = Curves.elasticOut.transform((p - 0.2) / 0.8);
        popY = 0.9 + 0.1 * e;
        popX = 1.05 - 0.05 * e;
      }
    }

    // Blinks every few seconds; mood-specific eyes override it in the face.
    final blinkPhase = t % 3.7;
    final blink = blinkPhase < 0.14
        ? math.sin(blinkPhase / 0.14 * math.pi)
        : 0.0;

    final bob = math.sin(t * 2.2) * 0.035;
    final look = Offset(math.sin(t * 0.7) * 0.6, math.cos(t * 0.45) * 0.3);
    final idleHandL = Offset(0, math.sin(t * 2.2 + 0.8) * 0.03);
    final idleHandR = Offset(0, math.sin(t * 2.2 + 2.0) * 0.03);

    switch (mood) {
      case BuddyMood.hot:
        // Wilting in the heat, swaying, one hand fanning his face, eyes
        // locked on the source.
        final fix = lookAt ?? const Offset(-0.8, 0.6);
        return _ChipPose(
          lift: bob * 0.4 - 0.01,
          yaw: fix.dx * 0.28 + 0.05 * math.sin(t * 1.1),
          pitch: fix.dy * 0.1,
          roll: 0.06 * math.sin(t * 1.3),
          scaleX: popX * (1.02 + 0.015 * math.sin(t * 2.4)),
          scaleY: popY * (0.97 - 0.015 * math.sin(t * 2.4)),
          blink: blink,
          look: fix,
          leftHand: Offset(0.2 + 0.05 * math.sin(t * 18), -0.12),
          rightHand: idleHandR,
        );
      case BuddyMood.idle:
        return _ChipPose(
          lift: bob,
          yaw: 0.38 * math.sin(t * 0.9),
          pitch: 0.08 * math.sin(t * 1.3),
          roll: 0.04 * math.sin(t * 0.8),
          scaleX: popX,
          scaleY: popY,
          blink: blink,
          look: look,
          leftHand: idleHandL,
          rightHand: idleHandR,
        );
      case BuddyMood.thinking:
        return _ChipPose(
          lift: bob * 0.6,
          yaw: -0.3 + 0.08 * math.sin(t * 0.6),
          pitch: -0.12,
          roll: 0.14,
          scaleX: popX,
          scaleY: popY,
          blink: blink,
          look: const Offset(0.7, -0.8),
          // One hand on the chin, tapping.
          leftHand: Offset(0.22, 0.12 + 0.015 * math.sin(t * 6)),
          rightHand: idleHandR,
        );
      case BuddyMood.happy:
      case BuddyMood.excited:
        // Hop every 1.6s with a full 3D spin in the air.
        final excited = mood == BuddyMood.excited;
        final cycle = excited ? 1.1 : 1.6;
        final h = (t % cycle) / cycle;
        final air = h < 0.55 ? math.sin(h / 0.55 * math.pi) : 0.0;
        final land = h >= 0.55 && h < 0.75
            ? math.sin((h - 0.55) / 0.2 * math.pi) * 0.14
            : 0.0;
        final spin = h < 0.55
            ? Curves.easeInOutCubic.transform(h / 0.55) * 2 * math.pi
            : 0.0;
        final wave = math.sin(t * (excited ? 16 : 10));
        return _ChipPose(
          lift: air * (excited ? 0.24 : 0.18) + bob * 0.4,
          yaw: spin + 0.2 * math.sin(t * 1.2),
          pitch: -0.1 * air,
          roll: 0,
          scaleX: popX * (1 + land),
          scaleY: popY * (1 - land) * (1 + 0.06 * air),
          blink: 0,
          look: Offset.zero,
          leftHand: Offset(-0.04, -0.2 - 0.05 * wave),
          rightHand: Offset(0.04, -0.2 + 0.05 * wave),
        );
      case BuddyMood.sad:
        return _ChipPose(
          lift: -0.04 + bob * 0.3,
          yaw: 0.12 * math.sin(t * 0.5),
          pitch: 0.18,
          roll: -0.08,
          scaleX: popX * 1.03,
          scaleY: popY * 0.96,
          blink: blink,
          look: const Offset(0, 0.8),
          leftHand: Offset(0.02, 0.08 + idleHandL.dy * 0.4),
          rightHand: Offset(-0.02, 0.08 + idleHandR.dy * 0.4),
        );
      case BuddyMood.evil:
        // A shaking, cackling laugh.
        final cackle = math.sin(t * 28) * math.max(0.0, math.sin(t * 2.4));
        return _ChipPose(
          lift: bob * 0.5 + cackle.abs() * 0.02,
          yaw: 0.18 * math.sin(t * 1.1),
          pitch: -0.08,
          roll: 0.07 * cackle,
          scaleX: popX * (1 + 0.03 * cackle),
          scaleY: popY * (1 - 0.03 * cackle),
          blink: 0,
          look: const Offset(0, 0.2),
          // Rubbing hands together.
          leftHand: Offset(0.16 + 0.02 * math.sin(t * 14), 0.05),
          rightHand: Offset(-0.16 - 0.02 * math.sin(t * 14), 0.05),
        );
      case BuddyMood.vibing:
        // Nodding on the beat, swaying from side to side, fingers tapping.
        // The song sets the beat: a hype track bounces, a sad one sways.
        final (beat, amp) = switch (flavor) {
          ChipFlavor.hype => (7.0, 1.6),
          ChipFlavor.dance => (6.4, 1.4),
          ChipFlavor.chill => (3.4, 0.7),
          ChipFlavor.romantic => (3.8, 0.8),
          ChipFlavor.sad => (2.6, 0.5),
          ChipFlavor.worship => (2.8, 0.6),
          _ => (5.2, 1.0),
        };
        final nod = math.sin(t * beat).abs();
        return _ChipPose(
          lift: 0.01 + nod * 0.03 * amp,
          yaw: 0.22 * math.sin(t * beat / 4) * math.min(amp, 1.2),
          pitch: 0.1 * nod * amp - 0.04,
          roll: 0.13 * math.sin(t * beat / 2) * amp,
          scaleX: popX * (1 + 0.02 * nod * amp),
          scaleY: popY * (1 - 0.02 * nod * amp),
          blink: 0,
          look: Offset.zero,
          leftHand: Offset(0.02, -0.02 - 0.05 * math.sin(t * beat).abs()),
          rightHand: Offset(-0.02, -0.02 - 0.05 * math.cos(t * beat).abs()),
        );
      case BuddyMood.listening:
        // A slow, thoughtful nod with the head tipped, taking it in.
        final nod = math.sin(t * 2.1);
        return _ChipPose(
          lift: 0.02 + 0.015 * nod,
          yaw: 0.12 * math.sin(t * 0.5),
          pitch: 0.06 * nod.abs() - 0.02,
          roll: 0.09 + 0.03 * math.sin(t * 0.8),
          scaleX: popX,
          scaleY: popY,
          blink: blink,
          look: const Offset(0.3, -0.25),
          leftHand: Offset(0.04, -0.05),
          rightHand: Offset(-0.03, 0.02),
        );
      case BuddyMood.watching:
        // Leaning in, eyes on the screen. A funny video gets giggles, a game
        // or a match gets him bouncing, a lesson a slow thoughtful nod.
        final giggle = flavor == ChipFlavor.funny
            ? math.sin(t * 22) * math.max(0.0, math.sin(t * 1.7))
            : 0.0;
        final bounce =
            flavor == ChipFlavor.gaming || flavor == ChipFlavor.sports
            ? math.sin(t * 6).abs() * 0.025
            : 0.0;
        final studyNod = flavor == ChipFlavor.study
            ? 0.05 * math.sin(t * 1.6)
            : 0.0;
        return _ChipPose(
          lift: 0.015 + 0.01 * math.sin(t * 1.3) + bounce,
          yaw: 0.05 * math.sin(t * 0.4),
          pitch: 0.08 + studyNod,
          roll: 0.02 * math.sin(t * 0.6) + 0.06 * giggle,
          scaleX: popX,
          scaleY: popY,
          blink: blink,
          look: const Offset(0, 0.45),
          leftHand: Offset(0.06, 0.06),
          rightHand: Offset(-0.06, 0.06),
        );
      case BuddyMood.peaceful:
        return _ChipPose(
          lift: 0.04 + math.sin(t * 1.4) * 0.05,
          yaw: 0.2 * math.sin(t * 0.6),
          pitch: -0.05,
          roll: 0.06 * math.sin(t * 0.7),
          scaleX: popX,
          scaleY: popY,
          blink: 0,
          look: Offset.zero,
          // Hands together, as if in a little bow.
          leftHand: Offset(0.14, -0.02 + 0.02 * math.sin(t * 1.4)),
          rightHand: Offset(-0.14, -0.02 + 0.02 * math.sin(t * 1.4)),
        );
    }
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
      mood == BuddyMood.evil
          ? const Color(0xFFB0244A)
          : AppColors.light
          ? const Color(0xFFF4EFE2)
          : AppColors.accent,
      // Grey-green dead skin once he's turned.
      const Color(0xFF8C9C74),
      zombie * (mood == BuddyMood.evil ? 0.7 : 1),
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
    if (_dead) {
      _zombieFace(canvas, c, r);
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
    }
    if (mood == BuddyMood.vibing || mood == BuddyMood.listening) {
      _headphones(canvas, c, r);
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
    if (fighter > 0) _headband(canvas, c, r);
    if (angel > 0) _halo(canvas, c, r);
  }

  /// Fully turned, his face is a zombie's whatever his mood: one eye
  /// staring wide with a pinprick pupil, the other half shut, no brows, a
  /// slack jaw slowly working, and now and then a drop of drool.
  void _zombieFace(Canvas canvas, Offset c, double r) {
    final ink = Paint()..color = AppColors.faceInk;
    final sclera = Paint()..color = const Color(0xFFDCE3B8);
    final drift = Offset(
      math.sin(t * 0.37) * r * 0.03,
      math.cos(t * 0.29) * r * 0.02,
    );
    final wide = c.translate(-r * 0.3, -r * 0.1);
    canvas.drawOval(
      Rect.fromCenter(center: wide, width: r * 0.4, height: r * 0.46),
      sclera,
    );
    canvas.drawCircle(wide + drift, r * 0.045, ink);
    final shut = c.translate(r * 0.3, -r * 0.06);
    canvas.drawOval(
      Rect.fromCenter(center: shut, width: r * 0.36, height: r * 0.4),
      sclera,
    );
    canvas.drawCircle(shut + drift * 0.7 + Offset(0, r * 0.05), r * 0.035, ink);
    _droopyLid(canvas, shut, r, 0.9);

    // The jaw, hanging crooked, opening and closing slowly.
    final open = 0.55 + 0.45 * (0.5 + 0.5 * math.sin(t * 1.3));
    canvas.save();
    canvas.translate(c.dx + r * 0.02, c.dy + r * 0.36);
    canvas.rotate(0.1);
    final jaw = Rect.fromCenter(
      center: Offset.zero,
      width: r * 0.38,
      height: r * (0.06 + 0.18 * open),
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        jaw,
        topLeft: Radius.circular(r * 0.05),
        topRight: Radius.circular(r * 0.1),
        bottomLeft: Radius.circular(r * 0.12),
        bottomRight: Radius.circular(r * 0.08),
      ),
      Paint()..color = const Color(0xFF2A1A12),
    );
    // Teeth along the top, one missing.
    final tooth = Paint()..color = const Color(0xFFE8E2C4);
    for (var i = 0; i < 4; i++) {
      if (i == 2) continue;
      canvas.drawRect(
        Rect.fromLTWH(
          jaw.left + r * 0.04 + i * r * 0.08,
          jaw.top,
          r * 0.055,
          r * 0.06,
        ),
        tooth,
      );
    }
    // Drool from the corner every few seconds, stretching and dropping.
    final k = (t % 4.0) / 4.0;
    if (k < 0.6) {
      final len = r * 0.22 * (k / 0.6);
      final at = Offset(jaw.right - r * 0.04, jaw.bottom - r * 0.01);
      final drool = Paint()
        ..color = const Color(0xFFCFE6C2).withValues(alpha: 0.85);
      canvas.drawLine(
        at,
        at.translate(0, len),
        drool
          ..strokeWidth = r * 0.025
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(at.translate(0, len), r * 0.03, drool);
    }
    canvas.restore();
  }

  /// Hell's set: two baby horns poking up, growing in as it comes on.
  void _babyHorns(Canvas canvas, Offset c, double r) {
    final grow = Curves.easeOutBack.transform(devil.clamp(0.0, 1.0));
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Color(0xFF8E1010), Color(0xFFFF4D4D)],
      ).createShader(Rect.fromCircle(center: c, radius: r * 1.3));
    for (final side in const [-1.0, 1.0]) {
      final base = c.translate(side * r * 0.42, -r * 0.8);
      final tip = base.translate(side * r * 0.12 * grow, -r * 0.32 * grow);
      canvas.drawPath(
        Path()
          ..moveTo(base.dx - side * r * 0.13, base.dy + r * 0.08)
          ..quadraticBezierTo(base.dx, base.dy - r * 0.2 * grow, tip.dx, tip.dy)
          ..quadraticBezierTo(
            base.dx + side * r * 0.16,
            base.dy - r * 0.05,
            base.dx + side * r * 0.14,
            base.dy + r * 0.1,
          )
          ..close(),
        paint,
      );
    }
  }

  /// Heaven's set: a gold halo floating over him, bobbing, glowing.
  void _halo(Canvas canvas, Offset c, double r) {
    final at = c.translate(0, -r * 1.68 + math.sin(t * 1.6) * r * 0.05);
    final ring = Rect.fromCenter(center: at, width: r * 1.0, height: r * 0.26);
    canvas.drawOval(
      ring.inflate(r * 0.06),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.14
        ..color = const Color(0xFFFFE08A).withValues(alpha: 0.35 * angel)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.08),
    );
    canvas.drawOval(
      ring,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.08
        ..shader = LinearGradient(
          colors: [
            const Color(0xFFFFF4C9).withValues(alpha: angel),
            const Color(0xFFE0A93A).withValues(alpha: angel),
          ],
        ).createShader(ring),
    );
  }

  /// The Dojo's set: a white headband across his brow with 勇 ("courage")
  /// on a red disc, knotted at the side, its tails fluttering.
  void _headband(Canvas canvas, Offset c, double r) {
    final a = fighter.clamp(0.0, 1.0);
    final top = c.dy - r * 0.76;
    final bottom = c.dy - r * 0.58;
    final band = Path()
      ..moveTo(c.dx - r, top + r * 0.06)
      ..quadraticBezierTo(c.dx, top - r * 0.04, c.dx + r, top + r * 0.06)
      ..lineTo(c.dx + r, bottom + r * 0.06)
      ..quadraticBezierTo(c.dx, bottom - r * 0.04, c.dx - r, bottom + r * 0.06)
      ..close();
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    canvas.drawPath(
      band,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: a),
            const Color(0xFFDCDCE6).withValues(alpha: a),
          ],
        ).createShader(Rect.fromLTRB(c.dx - r, top, c.dx + r, bottom)),
    );
    canvas.drawPath(
      band,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.03
        ..color = const Color(0xFFC8102E).withValues(alpha: a),
    );
    canvas.restore();

    // Knot and tails at his right side, fluttering.
    final knot = c.translate(r * 0.9, -r * 0.62);
    final tail = Paint()..color = Colors.white.withValues(alpha: a);
    for (var k = 0; k < 2; k++) {
      final flutter = math.sin(t * 9 + k * 1.7) * r * 0.06;
      canvas.drawPath(
        Path()
          ..moveTo(knot.dx, knot.dy - r * 0.04)
          ..quadraticBezierTo(
            knot.dx + r * 0.25,
            knot.dy + r * (0.02 + k * 0.12) + flutter,
            knot.dx + r * 0.5,
            knot.dy + r * (0.1 + k * 0.2) + flutter * 1.6,
          )
          ..lineTo(knot.dx + r * 0.46, knot.dy + r * (0.2 + k * 0.2) + flutter)
          ..quadraticBezierTo(
            knot.dx + r * 0.22,
            knot.dy + r * (0.12 + k * 0.12) + flutter,
            knot.dx,
            knot.dy + r * 0.05,
          )
          ..close(),
        tail,
      );
    }
    canvas.drawCircle(
      knot,
      r * 0.07,
      Paint()..color = const Color(0xFFEDEDF3).withValues(alpha: a),
    );

    // The emblem.
    final e = Offset(c.dx, (top + bottom) / 2 - r * 0.01);
    canvas.drawCircle(
      e,
      r * 0.15,
      Paint()..color = const Color(0xFFC8102E).withValues(alpha: a),
    );
    final glyph = TextPainter(
      text: TextSpan(
        text: '勇',
        style: TextStyle(
          color: Colors.white.withValues(alpha: a),
          fontSize: r * 0.19,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    glyph.paint(canvas, e - Offset(glyph.width / 2, glyph.height / 2));
    glyph.dispose();
  }

  /// Turned: rot blotches, a stitched scar and sunken sockets.
  void _rot(Canvas canvas, Offset c, double r) {
    final rot = Paint()
      ..color = const Color(0xFF55663F).withValues(alpha: 0.65 * zombie);
    for (final (dx, dy, w, h) in const [
      (-0.42, -0.42, 0.26, 0.18),
      (0.48, 0.36, 0.18, 0.13),
      (-0.18, 0.6, 0.12, 0.08),
      (0.12, -0.66, 0.1, 0.07),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(dx * r, dy * r),
          width: w * r,
          height: h * r,
        ),
        rot,
      );
    }
    final thread = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = r * 0.03
      ..color = const Color(0xFF3B2E22).withValues(alpha: zombie);
    final from = c.translate(-r * 0.62, r * 0.02);
    final to = c.translate(-r * 0.4, r * 0.42);
    canvas.drawLine(from, to, thread);
    final along = to - from;
    final across = Offset(-along.dy, along.dx) / along.distance * r * 0.07;
    for (var i = 1; i <= 3; i++) {
      final p = from + along * (i / 4);
      canvas.drawLine(p - across, p + across, thread);
    }
    final socket = Paint()
      ..color = const Color(0xFF2E3A26).withValues(alpha: 0.5 * zombie)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.04);
    for (final side in const [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(side * r * 0.3, -r * 0.1),
          width: r * 0.48,
          height: r * 0.56,
        ),
        socket,
      );
    }
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

  /// Big comfy headphones: a band over the top and glowing cups.
  void _headphones(Canvas canvas, Offset c, double r) {
    final band = Rect.fromCircle(center: c, radius: r * 1.06);
    canvas.drawArc(
      band,
      math.pi * 1.08,
      math.pi * 0.84,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.16
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF2A2050),
    );
    canvas.drawArc(
      band,
      math.pi * 1.12,
      math.pi * 0.76,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.25),
    );
    final pulse = 0.6 + 0.4 * math.sin(t * 5.2).abs();
    for (final side in const [-1.0, 1.0]) {
      final cup = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: c.translate(side * r * 0.98, r * 0.02),
          width: r * 0.34,
          height: r * 0.62,
        ),
        Radius.circular(r * 0.16),
      );
      canvas.drawRRect(
        cup.inflate(r * 0.06),
        Paint()..color = AppColors.accent.withValues(alpha: 0.35 * pulse),
      );
      canvas.drawRRect(
        cup,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(AppColors.accent, Colors.white, 0.35)!,
              AppColors.accent,
              const Color(0xFF2A2050),
            ],
          ).createShader(cup.outerRect),
      );
      canvas.drawCircle(
        cup.center,
        r * 0.07,
        Paint()..color = Colors.white.withValues(alpha: 0.5 + 0.4 * pulse),
      );
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

/// Behind and around Chip: the hover glow and shadow, plus mood props (a
/// halo and hearts when peaceful, a red aura when evil, sparkles when
/// excited).
class _AuraPainter extends CustomPainter {
  _AuraPainter({
    required this.mood,
    this.flavor = ChipFlavor.none,
    required this.t,
    required this.center,
    required this.radius,
    required this.lift,
    required this.sinceMood,
  });

  final BuddyMood mood;
  final ChipFlavor flavor;
  final double t;
  final Offset center;
  final double radius;
  final double lift;
  final double sinceMood;

  @override
  void paint(Canvas canvas, Size size) {
    final ground = Offset(size.width / 2, size.height * 0.97);
    final hover = (1 - lift * 3).clamp(0.4, 1.2);

    // Hover glow pad and soft shadow.
    canvas.save();
    canvas.translate(ground.dx, ground.dy);
    canvas.scale(1, 0.24);
    final pad = Rect.fromCircle(center: Offset.zero, radius: radius * 1.1);
    canvas.drawCircle(
      Offset.zero,
      radius * 1.1 * hover,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.glowRing.withValues(alpha: 0.45),
            AppColors.glowRing.withValues(alpha: 0),
          ],
        ).createShader(pad),
    );
    canvas.drawCircle(
      Offset.zero,
      radius * 0.7 * hover,
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );
    canvas.restore();

    switch (mood) {
      case BuddyMood.evil:
        final pulse = 0.7 + 0.3 * math.sin(t * 6);
        canvas.drawCircle(
          center,
          radius * 1.7,
          Paint()
            ..shader =
                RadialGradient(
                  colors: [
                    const Color(0xFFFF3D6E).withValues(alpha: 0.35 * pulse),
                    const Color(0x00FF3D6E),
                  ],
                ).createShader(
                  Rect.fromCircle(center: center, radius: radius * 1.7),
                ),
        );
      case BuddyMood.peaceful:
        // Halo, settling in from above.
        final drop = Curves.easeOutBack.transform(
          (sinceMood / 0.8).clamp(0.0, 1.0),
        );
        final halo = center.translate(
          0,
          -radius * (1.55 + 0.6 * (1 - drop)) + math.sin(t * 2) * 2,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: halo,
            width: radius * 1.1,
            height: radius * 0.32,
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = radius * 0.1
            ..color = const Color(0xFFFFE29A).withValues(alpha: drop),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: halo,
            width: radius * 1.4,
            height: radius * 0.5,
          ),
          Paint()
            ..color = const Color(0xFFFFE29A).withValues(alpha: 0.18 * drop),
        );
        for (var i = 0; i < 4; i++) {
          final life = (t * 0.45 + i / 4) % 1.0;
          final p = center.translate(
            (i.isEven ? -1 : 1) * radius * (0.9 + 0.2 * math.sin(t + i)),
            -life * radius * 2.2,
          );
          _heart(canvas, p, radius * 0.16, math.sin(life * math.pi));
        }
      case BuddyMood.excited:
        for (var i = 0; i < 8; i++) {
          final a = t * 3 + i * math.pi / 4;
          final p = center + Offset(math.cos(a), math.sin(a)) * radius * 1.45;
          canvas.drawCircle(
            p,
            radius * 0.05 * (0.6 + 0.4 * math.sin(t * 8 + i)),
            Paint()..color = const Color(0xFFFFE29A),
          );
        }
      case BuddyMood.vibing:
        // Music notes floating up out of the headphones: hearts for a love
        // song, a halo for worship, sparkles flying for a hype track.
        final speed = switch (flavor) {
          ChipFlavor.hype || ChipFlavor.dance => 0.55,
          ChipFlavor.sad || ChipFlavor.worship => 0.2,
          _ => 0.32,
        };
        if (flavor == ChipFlavor.worship) _vibeHalo(canvas);
        for (var i = 0; i < 5; i++) {
          final life = (t * speed + i / 5) % 1.0;
          final side = i.isEven ? -1.0 : 1.0;
          final p = center.translate(
            side * radius * (1.1 + 0.35 * life) +
                math.sin(t * 2 + i) * radius * 0.1,
            -radius * 0.1 - life * radius * 1.8,
          );
          final a = math.sin(life * math.pi);
          if (flavor == ChipFlavor.romantic) {
            _heart(canvas, p, radius * 0.16, a);
          } else if (flavor == ChipFlavor.sad) {
            _note(canvas, p, radius * 0.18, a * 0.7, 1);
          } else {
            _note(canvas, p, radius * 0.2, a, i);
          }
        }
        if (flavor == ChipFlavor.hype || flavor == ChipFlavor.dance) {
          for (var i = 0; i < 6; i++) {
            final ang = t * 2.4 + i * math.pi / 3;
            final p =
                center + Offset(math.cos(ang), math.sin(ang)) * radius * 1.5;
            canvas.drawCircle(
              p,
              radius * 0.045 * (0.6 + 0.4 * math.sin(t * 9 + i)),
              Paint()..color = const Color(0xFFFFE29A),
            );
          }
        }
      case BuddyMood.listening:
        // Soft sound waves rolling out from both ear cups.
        final wave = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = radius * 0.06;
        for (final side in const [-1.0, 1.0]) {
          for (var i = 0; i < 3; i++) {
            final life = (t * 0.55 + i / 3) % 1.0;
            final rr = radius * (0.25 + 0.55 * life);
            wave.color = const Color(
              0xFF7DF5DA,
            ).withValues(alpha: 0.75 * math.sin(life * math.pi));
            canvas.drawArc(
              Rect.fromCircle(
                center: center.translate(side * radius * 1.05, 0),
                radius: rr,
              ),
              side > 0 ? -0.6 : math.pi - 0.6,
              1.2,
              false,
              wave,
            );
          }
        }
      case BuddyMood.watching:
        // Little play sparks drifting up, like light off a screen.
        for (var i = 0; i < 4; i++) {
          final life = (t * 0.28 + i / 4) % 1.0;
          final side = i.isEven ? -1.0 : 1.0;
          final p = center.translate(
            side * radius * (0.95 + 0.3 * life) +
                math.sin(t * 1.6 + i) * radius * 0.08,
            -radius * 0.2 - life * radius * 1.6,
          );
          final s = radius * 0.17;
          final alpha = math.sin(life * math.pi);
          switch (flavor) {
            case ChipFlavor.study:
              // Little bright ideas floating up.
              canvas.drawCircle(
                p,
                s * 0.42,
                Paint()
                  ..color = const Color(0xFFFFE29A).withValues(alpha: alpha),
              );
              canvas.drawCircle(
                p,
                s * 0.75,
                Paint()
                  ..color = const Color(
                    0xFFFFE29A,
                  ).withValues(alpha: 0.25 * alpha),
              );
            case ChipFlavor.gaming:
              // Pixels.
              canvas.drawRect(
                Rect.fromCenter(center: p, width: s * 0.7, height: s * 0.7),
                Paint()
                  ..color = [
                    const Color(0xFF7DF5DA),
                    const Color(0xFFFF9ECF),
                  ][i % 2].withValues(alpha: alpha),
              );
            default:
              final play = Path()
                ..moveTo(p.dx - s * 0.4, p.dy - s * 0.5)
                ..lineTo(p.dx + s * 0.55, p.dy)
                ..lineTo(p.dx - s * 0.4, p.dy + s * 0.5)
                ..close();
              canvas.drawPath(
                play,
                Paint()
                  ..color = [
                    const Color(0xFFFF9ECF),
                    const Color(0xFF8FD3FF),
                  ][i % 2].withValues(alpha: alpha),
              );
          }
        }
      case BuddyMood.hot:
        // A shimmer of heat round him.
        final pulse = 0.7 + 0.3 * math.sin(t * 5);
        canvas.drawCircle(
          center,
          radius * 1.6,
          Paint()
            ..shader =
                RadialGradient(
                  colors: [
                    const Color(0xFFFF6A1F).withValues(alpha: 0.38 * pulse),
                    const Color(0x00FF6A1F),
                  ],
                ).createShader(
                  Rect.fromCircle(center: center, radius: radius * 1.6),
                ),
        );
      case BuddyMood.idle:
      case BuddyMood.thinking:
      case BuddyMood.happy:
      case BuddyMood.sad:
        break;
    }
  }

  /// A soft gold halo over Chip, for worship songs.
  void _vibeHalo(Canvas canvas) {
    final halo = center.translate(0, -radius * 1.55 + math.sin(t * 1.4) * 2);
    canvas.drawOval(
      Rect.fromCenter(center: halo, width: radius * 1.4, height: radius * 0.5),
      Paint()..color = const Color(0xFFFFE29A).withValues(alpha: 0.16),
    );
    canvas.drawOval(
      Rect.fromCenter(center: halo, width: radius * 1.1, height: radius * 0.32),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.08
        ..color = const Color(0xFFFFE29A),
    );
  }

  /// A little eighth note (or a pair, beamed).
  void _note(Canvas canvas, Offset p, double s, double alpha, int i) {
    final colors = [
      const Color(0xFFFFE29A),
      const Color(0xFF7DF5DA),
      const Color(0xFFFF9ECF),
    ];
    final paint = Paint()..color = colors[i % 3].withValues(alpha: alpha);
    final stem = Paint()
      ..color = paint.color
      ..strokeWidth = s * 0.18
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(
      Rect.fromCenter(center: p, width: s * 0.75, height: s * 0.55),
      paint,
    );
    final top = p.translate(s * 0.32, -s * 1.3);
    canvas.drawLine(p.translate(s * 0.32, 0), top, stem);
    if (i.isEven) {
      final p2 = p.translate(s * 0.9, -s * 0.2);
      canvas.drawOval(
        Rect.fromCenter(center: p2, width: s * 0.75, height: s * 0.55),
        paint,
      );
      final top2 = p2.translate(s * 0.32, -s * 1.3);
      canvas.drawLine(p2.translate(s * 0.32, 0), top2, stem);
      canvas.drawLine(top, top2, stem..strokeWidth = s * 0.26);
    } else {
      canvas.drawLine(top, top.translate(s * 0.4, s * 0.35), stem);
    }
  }

  void _heart(Canvas canvas, Offset c, double s, double alpha) {
    final path = Path()
      ..moveTo(c.dx, c.dy + s * 0.9)
      ..cubicTo(
        c.dx - s * 1.4,
        c.dy - s * 0.1,
        c.dx - s * 0.6,
        c.dy - s,
        c.dx,
        c.dy - s * 0.35,
      )
      ..cubicTo(
        c.dx + s * 0.6,
        c.dy - s,
        c.dx + s * 1.4,
        c.dy - s * 0.1,
        c.dx,
        c.dy + s * 0.9,
      )
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = const Color(0xFFFF8FB8).withValues(alpha: alpha),
    );
  }

  @override
  bool shouldRepaint(covariant _AuraPainter oldDelegate) => true;
}

/// "…" thought bubbles rising beside Chip while it thinks.
/// What a set puts behind him: Heaven's feathered wings, beating gently,
/// and Hell's swishing spade-tipped tail.
class _CostumeBackPainter extends CustomPainter {
  _CostumeBackPainter({
    required this.t,
    required this.center,
    required this.radius,
    required this.angel,
    required this.devil,
  });

  final double t;
  final Offset center;
  final double radius;
  final double angel;
  final double devil;

  @override
  void paint(Canvas canvas, Size size) {
    if (angel > 0) _wings(canvas);
    if (devil > 0) _tail(canvas);
  }

  void _wings(Canvas canvas) {
    final r = radius;
    final beat = math.sin(t * 2.6);
    final feather = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: angel),
          const Color(0xFFFFF1C4).withValues(alpha: angel),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: r * 2));
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.025
      ..color = const Color(0xFFD9C79A).withValues(alpha: 0.7 * angel);
    for (final side in const [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(center.dx + side * r * 0.75, center.dy - r * 0.15);
      canvas.scale(side, 1);
      canvas.rotate(-0.35 + beat * 0.2);
      // Three rows of feathers fanning out and up, longest at the back.
      for (var row = 0; row < 3; row++) {
        for (var k = 0; k < 4 - row; k++) {
          final len = r * (0.95 - row * 0.22 - k * 0.1);
          final at = Offset(r * (0.18 + k * 0.17), -r * (0.1 + row * 0.08));
          canvas.save();
          canvas.translate(at.dx, at.dy);
          canvas.rotate(-0.9 + k * 0.32);
          final f = Rect.fromLTWH(0, -r * 0.09, len, r * 0.18);
          canvas.drawOval(f, feather);
          canvas.drawOval(f, edge);
          canvas.restore();
        }
      }
      canvas.restore();
    }
  }

  void _tail(Canvas canvas) {
    final r = radius;
    final swish = math.sin(t * 2.2) * r * 0.18;
    final start = center.translate(r * 0.45, r * 0.75);
    final end = center.translate(r * 1.35, r * 0.15 + swish);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.09
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFB0141E).withValues(alpha: devil);
    canvas.drawPath(
      Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(
          center.dx + r * 1.25,
          center.dy + r * 0.95 + swish * 0.5,
          end.dx,
          end.dy,
        ),
      paint,
    );
    // The spade tip.
    final tip = Paint()
      ..color = const Color(0xFFD9262E).withValues(alpha: devil);
    canvas.drawPath(
      Path()
        ..moveTo(end.dx, end.dy - r * 0.2)
        ..quadraticBezierTo(
          end.dx + r * 0.18,
          end.dy - r * 0.02,
          end.dx + r * 0.03,
          end.dy + r * 0.06,
        )
        ..lineTo(end.dx - r * 0.03, end.dy + r * 0.06)
        ..quadraticBezierTo(
          end.dx - r * 0.18,
          end.dy - r * 0.02,
          end.dx,
          end.dy - r * 0.2,
        )
        ..close(),
      tip,
    );
  }

  @override
  bool shouldRepaint(covariant _CostumeBackPainter oldDelegate) => true;
}

class _ThoughtDotsPainter extends CustomPainter {
  _ThoughtDotsPainter({
    required this.t,
    required this.origin,
    required this.scale,
  });

  final double t;
  final Offset origin;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 3; i++) {
      final bob = math.sin(t * 3 + i) * scale * 0.012;
      final p = origin.translate(i * scale * 0.08, -i * scale * 0.1 + bob);
      final r = scale * (0.025 + i * 0.015);
      canvas.drawCircle(
        p,
        r,
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
      canvas.drawCircle(
        p,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = AppColors.glowRing,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ThoughtDotsPainter oldDelegate) => true;
}
