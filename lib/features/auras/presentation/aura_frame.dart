import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:flutter/scheduler.dart';

import '../../../core/theme/utopia_themes.dart';
import '../../../core/widgets/dojo_dragon.dart';
import '../../../core/widgets/fire_dragon.dart';
import '../../../core/widgets/utopia_world.dart' show worldSeconds;
import '../../../core/widgets/ambient_tick.dart';

part 'aura_frame_events.dart';
part 'aura_frame_fire.dart';
part 'aura_frame_cosmic.dart';
part 'aura_frame_zombie.dart';
part 'aura_frame_gentle.dart';

/// Draws an aura around [child], an avatar of [radius]. The aura spills
/// outside the avatar's box (flames, lightning, petals), behind and in
/// front of it, and animates for as long as it's on screen.
class AuraFrame extends StatefulWidget {
  const AuraFrame({
    super.key,
    required this.aura,
    required this.radius,
    required this.child,
  });

  final String aura;
  final double radius;
  final Widget child;

  @override
  State<AuraFrame> createState() => _AuraFrameState();
}

class _AuraFrameState extends State<AuraFrame>
    with SingleTickerProviderStateMixin {
  final _t = ValueNotifier<double>(0);
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    // Started here, not lazily: a lazy ticker would never start.
    _ticker = createTicker(
      ambientTick((e) {
        _t.value = e.inMicroseconds / 1e6;
        _callDragon();
      }),
    )..start();
  }

  /// A big Dragon Coil frame in the Dojo world (a profile picture) calls
  /// the world's dragon down to circle it.
  void _callDragon() {
    final wants =
        widget.aura == 'dragon' &&
        widget.radius >= 40 &&
        UtopiaThemes.active.world.biome == WorldBiome.dojo;
    if (!wants) {
      DojoDragon.release(this, worldSeconds);
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    DojoDragon.claim(
      this,
      box.localToGlobal(box.size.center(Offset.zero)),
      widget.radius,
      worldSeconds,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    if (still && _ticker.isActive) _ticker.stop();
    if (!still && !_ticker.isActive) _ticker.start();
  }

  @override
  void dispose() {
    DojoDragon.release(this, worldSeconds);
    _ticker.dispose();
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var child = widget.child;
    // Zombie Bite takes its chunk out of the picture too, border and all.
    if (widget.aura == 'zombie') {
      child = ClipPath(clipper: const _Bitten(), child: child);
    }
    return RepaintBoundary(
      child: CustomPaint(
        painter: AuraPainter(widget.aura, _t, front: false),
        foregroundPainter: AuraPainter(widget.aura, _t, front: true),
        child: SizedBox.square(dimension: widget.radius * 2, child: child),
      ),
    );
  }
}

/// Everything but the Zombie Bite's bite, for the picture inside it.
class _Bitten extends CustomClipper<Path> {
  const _Bitten();

  @override
  Path getClip(Size size) {
    final r = size.width / 2;
    final fit = (Matrix4.translationValues(
      r,
      r,
      0,
    )..scaleByDouble(r, r, 1, 1)).storage;
    return _biteShapes.unbitten.transform(fit);
  }

  @override
  bool shouldReclip(covariant _Bitten oldClipper) => false;
}

double _rand(int i, int salt) {
  final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

Offset _dir(double a) => Offset(math.cos(a), math.sin(a));

/// One layer of an aura: [front] draws over the avatar, otherwise behind.
class AuraPainter extends CustomPainter {
  AuraPainter(this.aura, this.clock, {required this.front})
    : super(repaint: clock);

  final String aura;
  final ValueNotifier<double> clock;
  final bool front;

  /// Small avatars (chat rows, lists) skip the blurs: they cost the most
  /// to draw every frame and barely show at that size.
  bool _lite = false;

  MaskFilter? _blur(double sigma) =>
      _lite ? null : MaskFilter.blur(BlurStyle.normal, sigma);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final t = clock.value;
    _lite = r < 20;
    switch (aura) {
      case 'dragon':
        _dragon(canvas, c, r, t);
      case 'flame':
        _flame(canvas, c, r, t);
      case 'storm' ||
          'storm_white' ||
          'storm_blue' ||
          'storm_green' ||
          'storm_gold' ||
          'storm_pink':
        _storm(canvas, c, r, t, _stormColors[aura]!);
      case 'supernova':
        _supernova(canvas, c, r, t);
      case 'blackhole':
        _blackhole(canvas, c, r, t);
      case 'frostfire':
        _frostfire(canvas, c, r, t);
      case 'sunburst':
        _sunburst(canvas, c, r, t);
      case 'prism':
        _prism(canvas, c, r, t);
      case 'cosmic':
        _cosmic(canvas, c, r, t);
      case 'bubbles':
        _bubbles(canvas, c, r, t);
      case 'sakura':
        _sakura(canvas, c, r, t);
      case 'frost':
        _frost(canvas, c, r, t);
      case 'fury':
        _fury(canvas, c, r, t);
      case 'phoenix':
        _phoenix(canvas, c, r, t);
      case 'galaxy':
        _galaxy(canvas, c, r, t);
      case 'shadow':
        _shadow(canvas, c, r, t);
      case 'neon':
        _neon(canvas, c, r, t);
      case 'tidal':
        _tidal(canvas, c, r, t);
      case 'halo':
        _halo(canvas, c, r, t);
      case 'zombie':
        _zombie(canvas, c, r, t);
      case 'demon':
        _demon(canvas, c, r, t);
      case 'hearts':
        _hearts(canvas, c, r, t);
      case 'fireflies':
        _fireflies(canvas, c, r, t);
      case 'starlight':
        _starlight(canvas, c, r, t);
      case 'autumn':
        _autumn(canvas, c, r, t);
      case 'maestro':
        _maestro(canvas, c, r, t);
      case 'music':
        _music(canvas, c, r, t);
      case 'jack':
        _hallows(canvas, c, r, t);
      case 'snow_globe':
        _snowGlobe(canvas, c, r, t);
      case 'birthday':
        _birthday(canvas, c, r, t);
    }
  }

  void _glowRing(
    Canvas canvas,
    Offset c,
    double r,
    Color color, {
    double width = 0.18,
    double blur = 0.18,
    double scale = 1.04,
  }) {
    canvas.drawCircle(
      c,
      r * scale,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * width
        ..color = color
        ..maskFilter = _blur(r * blur),
    );
  }

  @override
  bool shouldRepaint(covariant AuraPainter old) =>
      old.aura != aura || old.front != front;
}
