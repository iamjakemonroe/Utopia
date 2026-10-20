part of 'coin_buddy.dart';

// Where Chip is and how he moves, moment by moment, for each mood.

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
    double dj = 0,
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
    if (dj > 0 && mood != BuddyMood.hot) pose = lerp(pose, _dj(t), dj);
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

  /// On the decks: nodding hard on the Music world's beat (so every Chip
  /// keeps time with the show), one hand pressing a headphone cup to his
  /// ear, the other scratching.
  static _ChipPose _dj(double t) {
    final beats = worldSeconds * 2;
    final nod = math.exp(-(beats % 1.0) * 6);
    final blinkPhase = t % 3.7;
    return _ChipPose(
      lift: 0.01 + nod * 0.022,
      yaw: 0.1 * math.sin(t * 1.1),
      pitch: 0.03 + 0.12 * nod,
      roll: 0.07 * math.sin(beats * math.pi / 2),
      scaleX: 1 + 0.03 * nod,
      scaleY: 1 - 0.04 * nod,
      blink: blinkPhase < 0.12 ? math.sin(blinkPhase / 0.12 * math.pi) : 0.0,
      look: const Offset(0, 0.2),
      leftHand: Offset(0.07, -0.12 + 0.01 * nod),
      rightHand: Offset(-0.04 + 0.05 * math.sin(t * 9), 0.05),
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
