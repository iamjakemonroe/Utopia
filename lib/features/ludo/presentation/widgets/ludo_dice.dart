import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/game_audio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/frame_island.dart';

/// The least time the die tumbles, so it reads as a real roll.
const kDiceTumbleMin = Duration(milliseconds: 300);

/// How long it takes to come to rest on its face.
const kDiceSettle = Duration(milliseconds: 200);

/// From the tap until the number is plain to see. Pieces wait for this:
/// the tumble and the settle (500ms), plus a beat so a late frame never
/// lets a piece light while the die is still turning.
const kDiceReveal = Duration(milliseconds: 600);

/// How long the number stays in view before a piece moves on its own.
const kDiceReadTime = Duration(milliseconds: 250);

/// How long a roll that can't be played stays up before the turn passes,
/// so everyone sees what came up.
const kNoMoveHold = Duration(milliseconds: 900);

/// A genuinely 3D die: six distinct faces arranged as a real cube in
/// `Matrix4` space, depth-sorted every frame so the right faces occlude
/// each other as it tumbles.
///
/// Every roll in the match bumps [rollSeq]; whenever it changes (your roll
/// or anyone else's) the die tumbles and lands exactly on [value]. Tapping
/// starts the tumble immediately; if no new roll arrives (a network error,
/// say) it settles back after a couple of seconds instead of spinning
/// forever.
class LudoDice extends ConsumerStatefulWidget {
  const LudoDice({
    super.key,
    required this.rollSeq,
    required this.value,
    required this.enabled,
    required this.onRoll,
    this.active = true,
    this.size = 58,
    this.glow,
  });

  final int rollSeq;
  final int? value;
  final bool enabled;
  final VoidCallback onRoll;

  /// It's this die's owner's turn: the die stays bright the whole turn,
  /// not just while it can be tapped.
  final bool active;

  /// Edge length of a face.
  final double size;

  /// Halo color while waiting to be rolled (the roller's seat color).
  final Color? glow;

  @override
  ConsumerState<LudoDice> createState() => _LudoDiceState();
}

/// rotX/rotY that bring each face value to rest facing the viewer — the
/// inverse of that face's own base rotation (see [_kFaces]).
const Map<int, (double, double)> _kRestAngles = {
  1: (0, 0),
  6: (0, math.pi),
  3: (0, -math.pi / 2),
  4: (0, math.pi / 2),
  2: (math.pi / 2, 0),
  5: (-math.pi / 2, 0),
};

class _LudoDiceState extends ConsumerState<LudoDice>
    with TickerProviderStateMixin {
  late final AnimationController _tumble = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: kDiceSettle,
  );
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  double _rotX = 0, _rotY = 0; // continuous, not wrapped
  double _fromX = 0, _fromY = 0, _toX = 0, _toY = 0;
  bool _tumbling = false;
  DateTime _tumbleStarted = DateTime.now();
  late int _seenSeq = widget.rollSeq;
  Timer? _settleTimer;
  Timer? _failsafe;

  @override
  void initState() {
    super.initState();
    final rest = _kRestAngles[widget.value];
    if (rest != null) {
      _rotX = rest.$1;
      _rotY = rest.$2;
    }
    _settle.addListener(() {
      final t = Curves.easeOutBack.transform(_settle.value);
      setState(() {
        _rotX = _fromX + (_toX - _fromX) * t;
        _rotY = _fromY + (_toY - _fromY) * t;
      });
    });
  }

  @override
  void didUpdateWidget(covariant LudoDice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rollSeq != _seenSeq) {
      _seenSeq = widget.rollSeq;
      if (!_tumbling) _startTumble();
      final value = widget.value;
      if (value != null) _settleOn(value);
    }
  }

  void _startTumble() {
    _tumbling = true;
    _tumbleStarted = DateTime.now();
    _settle.stop();
    _tumble.repeat();
    ref.read(gameAudioProvider).play(Sfx.diceShake);
  }

  /// Lands on [value] once the die has tumbled long enough to look real.
  void _settleOn(int value) {
    _failsafe?.cancel();
    _settleTimer?.cancel();
    final elapsed = DateTime.now().difference(_tumbleStarted);
    // Long enough to read as a roll, short enough not to keep anyone
    // waiting; the number then holds before any piece moves.
    final wait = kDiceTumbleMin - elapsed;
    _settleTimer = Timer(wait.isNegative ? Duration.zero : wait, () {
      if (!mounted) return;
      _land(value);
    });
  }

  void _land(int? value) {
    final spin = _tumbleAngles();
    _tumble.stop();
    _tumbling = false;
    final (rx, ry) = _kRestAngles[value] ?? _kRestAngles[1]!;
    _fromX = spin.$1;
    _fromY = spin.$2;
    _toX = _nearestEquivalent(_fromX, rx);
    _toY = _nearestEquivalent(_fromY, ry);
    _settle.forward(from: 0);
    ref.read(gameAudioProvider).play(Sfx.diceLand);
  }

  (double, double) _tumbleAngles() => (
    _rotX + _tumble.value * 2 * math.pi,
    _rotY + _tumble.value * 2.6 * math.pi,
  );

  /// The equivalent of [target] closest to [current], so the settle never
  /// spins the long way around.
  double _nearestEquivalent(double current, double target) {
    final turns = ((current - target) / (2 * math.pi)).round();
    return target + turns * 2 * math.pi;
  }

  void _handleTap() {
    if (!widget.enabled || _tumbling) return;
    _startTumble();
    widget.onRoll();
    _failsafe?.cancel();
    _failsafe = Timer(const Duration(milliseconds: 2500), () {
      if (mounted && _tumbling) _land(widget.value);
    });
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    _failsafe?.cancel();
    _tumble.dispose();
    _settle.dispose();
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return Semantics(
      button: widget.enabled,
      label: widget.enabled
          ? 'Roll the die'
          : 'Die showing ${widget.value ?? ''}',
      child: GestureDetector(
        onTap: _handleTap,
        child: FrameIsland(
          size: Size.square(s * 1.6),
          child: AnimatedBuilder(
            animation: Listenable.merge([_tumble, _idle]),
            builder: (context, child) {
              final (rotX, rotY) = _tumbling ? _tumbleAngles() : (_rotX, _rotY);
              final ready = widget.enabled && !_tumbling;
              final bob = ready
                  ? math.sin(_idle.value * 2 * math.pi) * s * 0.06
                  : 0.0;
              final hop = _tumbling
                  ? (math.sin(_tumble.value * 2 * math.pi * 2)).abs() * s * 0.18
                  : 0.0;
              final glow = widget.glow ?? AppColors.accentSecondary;
              final pulse = 0.5 + 0.5 * math.sin(_idle.value * 2 * math.pi);
              return SizedBox(
                width: s * 1.6,
                height: s * 1.6,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (ready)
                      Container(
                        width: s * (1.3 + 0.12 * pulse),
                        height: s * (1.3 + 0.12 * pulse),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              glow.withValues(alpha: 0.8),
                              glow.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    if (ready)
                      // A ring breathing out from the die: "tap me".
                      Container(
                        width: s * (1.05 + 0.4 * _idle.value),
                        height: s * (1.05 + 0.4 * _idle.value),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(
                              alpha: 0.8 * (1 - _idle.value),
                            ),
                            width: 2.5,
                          ),
                        ),
                      ),
                    Transform.translate(
                      offset: Offset(0, -bob - hop),
                      child: Transform.scale(
                        scale: ready ? 1 + 0.06 * pulse : 1,
                        child: _Die3D(
                          size: s,
                          rotX: rotX,
                          rotY: rotY,
                          dimmed: !widget.active && !_tumbling,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Face {
  const _Face(
    this.pips,
    this.rotation,
    this.normalX,
    this.normalY,
    this.normalZ,
  );
  final int pips;
  final Matrix4 rotation;
  // This face's base rotation applied to local +Z, at rest (tumble =
  // identity). Flutter's +Z points into the screen, so each face is pushed
  // out along local −Z (toward the viewer) and sits opposite this vector:
  // the most positive normal Z is the farthest-forward face, painted last.
  // Kept alongside [rotation] (rather than derived from it via a Vector3
  // transform) so depth sorting doesn't need the vector_math package as a
  // direct dependency.
  final double normalX, normalY, normalZ;
}

final List<_Face> _kFaces = [
  _Face(1, Matrix4.identity(), 0, 0, 1),
  _Face(6, Matrix4.identity()..rotateY(math.pi), 0, 0, -1),
  _Face(3, Matrix4.identity()..rotateY(math.pi / 2), 1, 0, 0),
  _Face(4, Matrix4.identity()..rotateY(-math.pi / 2), -1, 0, 0),
  _Face(2, Matrix4.identity()..rotateX(-math.pi / 2), 0, 1, 0),
  _Face(5, Matrix4.identity()..rotateX(math.pi / 2), 0, -1, 0),
];

/// Applies the same `Matrix4.identity()..rotateX(rotX)..rotateY(rotY)`
/// rotation (rotateY first, then rotateX — see how the chain composes) to
/// a direction vector, in plain trig, returning just the resulting z —
/// all this needs for back-to-front sorting.
double _tumbledNormalZ(
  double x0,
  double y0,
  double z0,
  double rotX,
  double rotY,
) {
  final cy = math.cos(rotY), sy = math.sin(rotY);
  final y1 = y0;
  final z1 = -x0 * sy + z0 * cy;

  final cx = math.cos(rotX), sx = math.sin(rotX);
  return y1 * sx + z1 * cx;
}

class _Die3D extends StatelessWidget {
  const _Die3D({
    required this.size,
    required this.rotX,
    required this.rotY,
    required this.dimmed,
  });

  final double size;
  final double rotX;
  final double rotY;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final ordered = [..._kFaces]
      ..sort((a, b) {
        final za = _tumbledNormalZ(a.normalX, a.normalY, a.normalZ, rotX, rotY);
        final zb = _tumbledNormalZ(b.normalX, b.normalY, b.normalZ, rotX, rotY);
        return za.compareTo(zb);
      });

    final outer = Matrix4.identity()
      ..setEntry(3, 2, 0.16 / size)
      ..rotateX(rotX)
      ..rotateY(rotY);

    return Opacity(
      opacity: dimmed ? 0.6 : 1,
      child: Transform(
        transform: outer,
        alignment: Alignment.center,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final face in ordered)
                Transform(
                  transform: face.rotation.clone()
                    ..translateByDouble(0.0, 0.0, -size / 2, 1.0),
                  alignment: Alignment.center,
                  child: _DieFace(pips: face.pips, size: size),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

const Map<int, List<Alignment>> _pipLayouts = {
  1: [Alignment.center],
  2: [Alignment.topLeft, Alignment.bottomRight],
  3: [Alignment.topLeft, Alignment.center, Alignment.bottomRight],
  4: [
    Alignment.topLeft,
    Alignment.topRight,
    Alignment.bottomLeft,
    Alignment.bottomRight,
  ],
  5: [
    Alignment.topLeft,
    Alignment.topRight,
    Alignment.center,
    Alignment.bottomLeft,
    Alignment.bottomRight,
  ],
  6: [
    Alignment.topLeft,
    Alignment.topRight,
    Alignment.centerLeft,
    Alignment.centerRight,
    Alignment.bottomLeft,
    Alignment.bottomRight,
  ],
};

class _DieFace extends StatelessWidget {
  const _DieFace({required this.pips, required this.size});

  final int pips;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Real dice look 3D because of light, not geometry: a radial highlight
    // offset toward one corner, a diagonal gloss streak, an inner edge that
    // brightens on the lit side, and pips with their own tiny highlight so
    // they read as embossed rather than painted-on dots.
    final pip = size * 0.14;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.2),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.goldBorder, width: size * 0.026),
          gradient: const RadialGradient(
            center: Alignment(-0.4, -0.5),
            radius: 1.15,
            stops: [0.0, 0.55, 1.0],
            colors: [Colors.white, Color(0xFFEFE8FA), Color(0xFFD3C6EC)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -size * 0.25,
              left: -size * 0.2,
              child: Transform.rotate(
                angle: -0.6,
                child: Container(
                  width: size * 1.1,
                  height: size * 0.38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(size),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.6),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(size * 0.16),
              child: Stack(
                children: [
                  for (final align in _pipLayouts[pips] ?? const [])
                    Align(
                      alignment: align,
                      child: Container(
                        width: pip,
                        height: pip,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            center: Alignment(-0.35, -0.35),
                            colors: [Color(0xFF4A3B7A), AppColors.faceInk],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              offset: Offset(0, pip * 0.1),
                              blurRadius: pip * 0.1,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
