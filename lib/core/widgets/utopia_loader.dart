import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';

/// Utopia's mark: a floating island with a glowing gateway into a sunrise
/// world (the app icon, the splash, the landing page).
const kUtopiaLogoAsset = 'assets/branding/logo_mark.png';

/// The face of a Utopia coin: the loader coin, and Chip's back.
const kCoinFaceAsset = 'assets/branding/coin_face.png';

/// Utopia's loading animation, shared by the splash screen, full-screen
/// loading states, the matchmaking wait and buttons: the coin sits inside a
/// wobbly soap bubble, crouches, leaps with a full 3D flip, lands with a
/// jelly squash and sprays little bubbles that float off and pop.
///
/// Runs itself. Use [UtopiaLoaderView] to drive the same animation from
/// your own clock (the splash does, to sync it with its intro), and
/// [runWithUtopiaLoader] to float it over the whole app during a task.
class UtopiaLoader extends StatefulWidget {
  const UtopiaLoader({super.key, this.size = 72, this.bubbles, this.label});

  /// Coin diameter. The widget itself is bigger, to fit the bounce.
  final double size;

  /// The spray of bubbles on landing and the ones drifting up around the
  /// coin. Defaults to on for loaders big enough to show them off.
  final bool? bubbles;

  /// Optional caption under the coin, e.g. "Setting up the board…".
  final String? label;

  /// Length of one bounce, in seconds.
  static const cycleSeconds = 1.2;

  @override
  State<UtopiaLoader> createState() => _UtopiaLoaderState();
}

class _UtopiaLoaderState extends State<UtopiaLoader>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _seconds = ValueNotifier(0);
  late final Ticker _ticker = createTicker(
    (elapsed) => _seconds.value = elapsed.inMicroseconds / 1e6,
  );

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loader = ValueListenableBuilder<double>(
      valueListenable: _seconds,
      builder: (context, seconds, _) => UtopiaLoaderView(
        size: widget.size,
        progress: seconds / UtopiaLoader.cycleSeconds,
        // The bubble inflates around the coin as the loader appears.
        shell: (seconds / 0.45).clamp(0.0, 1.0),
        bubbles: widget.bubbles ?? widget.size >= 40,
      ),
    );
    final label = widget.label;
    if (label == null) return loader;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        loader,
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.body(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// [UtopiaLoader]'s animation at one moment, as a pure function of its
/// inputs. The coin's resting center is always the exact center of this
/// widget, so centering the widget centers the coin.
class UtopiaLoaderView extends StatelessWidget {
  const UtopiaLoaderView({
    super.key,
    required this.size,
    required this.progress,
    this.shell = 1,
    this.bubbles = true,
    this.brand = false,
  });

  final double size;

  /// The splash: Utopia's mark bounces in the bubble instead of the coin
  /// (swaying in the air rather than flipping).
  final bool brand;

  /// Bounces elapsed. 0 is the coin at rest with nothing else showing.
  final double progress;

  /// 0-1: how far the soap bubble has inflated around the coin.
  final double shell;

  final bool bubbles;

  /// Soap bubble radius, as a fraction of the coin's diameter.
  static const _shellRatio = 0.67;

  static double _peakRatio(bool bubbles) => bubbles ? 0.62 : 0.36;

  /// The space the animation needs for a coin of [size]. Symmetric about
  /// the coin's resting center.
  static Size extentFor(double size, {bool bubbles = true}) {
    final shellRadius = size * _shellRatio;
    final halfHeight = size * _peakRatio(bubbles) + shellRadius * 1.14 + 2;
    final width = bubbles ? size * 2.8 : shellRadius * 2.4;
    return Size(width, halfHeight * 2);
  }

  @override
  Widget build(BuildContext context) {
    final box = extentFor(size, bubbles: bubbles);
    final center = box.center(Offset.zero);
    final radius = size * _shellRatio;
    final pose = _BouncePose.at(progress % 1.0);
    final lift = pose.lift * size * _peakRatio(bubbles);

    return SizedBox.fromSize(
      size: box,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _LoaderFxPainter(
                center: center,
                radius: radius,
                coinSize: size,
                progress: progress,
                lift: pose.lift,
                shell: shell,
                bubbles: bubbles,
              ),
            ),
          ),
          Positioned(
            left: center.dx - radius,
            top: center.dy - radius - lift,
            width: radius * 2,
            height: radius * 2,
            child: Transform(
              // Squash and stretch pivot on the bottom of the bubble, so a
              // landing looks like it's pressing into the ground.
              alignment: Alignment.bottomCenter,
              transform: Matrix4.diagonal3Values(pose.scaleX, pose.scaleY, 1),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (brand)
                    Transform.rotate(
                      angle: -0.3 * pose.tilt,
                      child: Image.asset(
                        kUtopiaLogoAsset,
                        width: size,
                        height: size,
                        filterQuality: FilterQuality.medium,
                      ),
                    )
                  else
                    Coin3D(size: size, angle: pose.spin, tilt: pose.tilt),
                  if (shell > 0)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _SoapBubblePainter(
                          inflate: shell,
                          shimmer: progress,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The coin at one point in a bounce ([t] 0-1): crouch, leap with a full
/// 3D flip, then land with a damped jelly wobble. t = 0 and t = 1 are
/// exactly the rest pose, so bounces chain seamlessly and a loader that
/// hasn't started yet sits perfectly still.
class _BouncePose {
  const _BouncePose({
    required this.lift,
    required this.scaleX,
    required this.scaleY,
    required this.spin,
    required this.tilt,
  });

  /// 0-1 of the peak height.
  final double lift;
  final double scaleX;
  final double scaleY;

  /// Flip around the vertical axis, in radians.
  final double spin;

  /// Lean back while airborne, in radians, so the face shows in 3D.
  final double tilt;

  static const takeoff = 0.14;
  static const touchdown = 0.8;
  static const _stretch = 0.12;

  factory _BouncePose.at(double t) {
    if (t < takeoff) {
      final s = math.sin(t / takeoff * math.pi) * 0.14;
      return _BouncePose(
        lift: 0,
        scaleX: 1 + s,
        scaleY: 1 - s,
        spin: 0,
        tilt: 0,
      );
    }
    if (t < touchdown) {
      final u = (t - takeoff) / (touchdown - takeoff);
      // Stretched along the direction of travel: most at takeoff and
      // touchdown, none at the apex. Eased in over the first few frames so
      // leaving the crouch doesn't snap.
      final stretch = _stretch * (1 - 2 * u).abs() * math.min(1.0, u / 0.06);
      return _BouncePose(
        lift: 4 * u * (1 - u),
        scaleX: 1 - stretch,
        scaleY: 1 + stretch,
        spin: 2 * math.pi * Curves.easeInOutCubic.transform(u),
        tilt: 0.35 * math.sin(math.pi * u),
      );
    }
    // Jelly landing: the touchdown stretch snaps into a squash that
    // wobbles out, and the (1 - w) envelope lands it exactly at rest.
    final w = (t - touchdown) / (1 - touchdown);
    final s =
        0.26 * math.sin(3.5 * math.pi * w) * math.exp(-2.2 * w) * (1 - w) -
        _stretch * math.exp(-w / 0.05);
    return _BouncePose(lift: 0, scaleX: 1 + s, scaleY: 1 - s, spin: 0, tilt: 0);
  }
}

/// The logo as a real coin with thickness: a front face, a back face, and
/// a stack of gold rim discs between them, rotated together in
/// perspective. Flutter doesn't depth-sort 3D children, so they're painted
/// far-to-near based on which face is toward the viewer.
class Coin3D extends StatelessWidget {
  const Coin3D({super.key, required this.size, this.angle = 0, this.tilt = 0});

  final double size;

  /// Rotation around the vertical axis, in radians.
  final double angle;

  /// Rotation around the horizontal axis, in radians. Keep within ±π/2.
  final double tilt;

  static const _rimLight = Color(0xFFFFD66B);
  static const _rimDark = Color(0xFFB8801F);

  @override
  Widget build(BuildContext context) {
    final layers = size >= 40 ? 10 : 6;
    final gap = size * 0.11 / layers;
    // In Flutter's 3D space +z points into the screen, so the face toward
    // the viewer sits at negative z.
    final half = layers * gap / 2;
    final frontFacing = math.cos(angle) >= 0;

    Widget at(double z, Widget child) => Transform(
      alignment: Alignment.center,
      transform: Matrix4.translationValues(0, 0, z),
      child: child,
    );

    final face = Image(
      image: const AssetImage(kCoinFaceAsset),
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
    );
    final front = at(-half, face);
    // Pre-flipped so the "S" reads correctly when the back is showing.
    final back = at(
      half,
      Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(math.pi),
        child: face,
      ),
    );
    // Ordered far to near while the front faces the viewer.
    final rim = [
      for (var i = 0; i < layers; i++)
        at(
          half - (i + 0.5) * gap,
          Container(
            width: size * 0.985,
            height: size * 0.985,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.lerp(_rimLight, _rimDark, i.isEven ? 0.35 : 0.6),
            ),
          ),
        ),
    ];

    return SizedBox.square(
      dimension: size,
      child: Transform(
        alignment: Alignment.center,
        // Same apparent depth at every size.
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.2 / size)
          ..rotateX(tilt)
          ..rotateY(angle),
        child: Stack(
          alignment: Alignment.center,
          children: frontFacing
              ? [back, ...rim, front]
              : [front, ...rim.reversed, back],
        ),
      ),
    );
  }
}

/// A glossy, iridescent soap bubble filling its box: nearly clear in the
/// middle, a rainbow sheen that slowly swirls around the rim, and the
/// highlights that make it read as a sphere.
class _SoapBubblePainter extends CustomPainter {
  _SoapBubblePainter({required this.inflate, required this.shimmer});

  /// 0-1; springs past full size and settles, like a bubble being blown.
  final double inflate;
  final double shimmer;

  static const _sheen = [
    Color(0xFF7DF5DA),
    Color(0xFF8FD3FF),
    Color(0xFFB79BFF),
    Color(0xFFFF9ECF),
    Color(0xFFFFE29A),
    Color(0xFF7DF5DA),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 * Curves.elasticOut.transform(inflate);
    if (r <= 0) return;
    final alpha = math.min(1.0, inflate * 3);
    final bounds = Rect.fromCircle(center: c, radius: r);

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.15, -0.2),
          stops: const [0.0, 0.62, 0.9, 1.0],
          colors: [
            Colors.white.withValues(alpha: 0),
            const Color(0xFFB79BFF).withValues(alpha: 0.05 * alpha),
            const Color(0xFFD9C8FF).withValues(alpha: 0.2 * alpha),
            Colors.white.withValues(alpha: 0.38 * alpha),
          ],
        ).createShader(bounds),
    );
    canvas.drawCircle(
      c,
      r * 0.975,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..shader = SweepGradient(
          colors: [
            for (final color in _sheen) color.withValues(alpha: 0.6 * alpha),
          ],
          transform: GradientRotation(shimmer * math.pi * 0.6),
        ).createShader(bounds),
    );

    final highlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      bounds.deflate(r * 0.16),
      math.pi * 1.08,
      math.pi * 0.36,
      false,
      highlight
        ..strokeWidth = r * 0.09
        ..color = Colors.white.withValues(alpha: 0.6 * alpha),
    );
    canvas.drawArc(
      bounds.deflate(r * 0.12),
      math.pi * 0.12,
      math.pi * 0.3,
      false,
      highlight
        ..strokeWidth = r * 0.04
        ..color = Colors.white.withValues(alpha: 0.25 * alpha),
    );
    canvas.drawCircle(
      c.translate(r * 0.42, -r * 0.52),
      r * 0.07,
      Paint()..color = Colors.white.withValues(alpha: 0.7 * alpha),
    );
  }

  @override
  bool shouldRepaint(covariant _SoapBubblePainter oldDelegate) =>
      oldDelegate.inflate != inflate || oldDelegate.shimmer != shimmer;
}

/// Everything around the coin: its shadow on the ground, and (when
/// [bubbles] is on) the ripple and burst of bubbles each landing sends out,
/// plus a few bubbles drifting up around it.
class _LoaderFxPainter extends CustomPainter {
  _LoaderFxPainter({
    required this.center,
    required this.radius,
    required this.coinSize,
    required this.progress,
    required this.lift,
    required this.shell,
    required this.bubbles,
  });

  final Offset center;
  final double radius;
  final double coinSize;
  final double progress;
  final double lift;
  final double shell;
  final bool bubbles;

  static const _burstCount = 8;
  static const _driftCount = 6;
  static final _tints = [
    Color(0xFFB79BFF),
    AppColors.mint,
    AppColors.accentSecondary,
    AppColors.sky,
    Color(0xFFFF9ECF),
  ];

  static double _rand(int i) {
    final x = math.sin(i * 12.9898) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final ground = Offset(center.dx, center.dy + radius);

    // Shadow: shrinks and fades as the coin rises. Hidden until the loader
    // has started, so an unstarted loader is just the coin.
    final shadowScale = 1 - 0.5 * lift;
    final shadowRect = Rect.fromCircle(
      center: Offset.zero,
      radius: radius * 0.85 * shadowScale,
    );
    canvas.save();
    canvas.translate(ground.dx, ground.dy + coinSize * 0.03);
    canvas.scale(1, 0.22);
    canvas.drawCircle(
      Offset.zero,
      shadowRect.width / 2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.black.withValues(alpha: 0.45 * (1 - 0.6 * lift) * shell),
            Colors.black.withValues(alpha: 0),
          ],
        ).createShader(shadowRect),
    );
    canvas.restore();

    if (!bubbles) return;

    for (var i = 0; i < _driftCount; i++) {
      final life = (progress * 0.4 + i / _driftCount) % 1.0;
      final p = Offset(
        center.dx +
            (_rand(i + 40) - 0.5) * size.width * 0.85 +
            math.sin(progress * 2 + i) * coinSize * 0.06,
        ground.dy + coinSize * 0.2 - life * size.height * 0.8,
      );
      _bubble(
        canvas,
        p,
        coinSize * (0.035 + 0.03 * _rand(i + 50)),
        math.sin(life * math.pi) * 0.8 * shell,
        _tints[i % _tints.length],
      );
    }

    if (progress < _BouncePose.touchdown) return;
    // Cycles since the most recent landing, and which landing it was (so
    // each burst sprays a little differently).
    final sinceLanding = (progress - _BouncePose.touchdown) % 1.0;
    final landing = (progress - _BouncePose.touchdown).floor();

    if (sinceLanding < 0.5) {
      final p = sinceLanding / 0.5;
      final width = radius * 2 * (1 + p * 1.2);
      canvas.drawOval(
        Rect.fromCenter(center: ground, width: width, height: width * 0.22),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, coinSize * 0.025 * (1 - p))
          ..color = AppColors.glowRing.withValues(alpha: 0.7 * (1 - p)),
      );
    }

    for (var i = 0; i < _burstCount; i++) {
      final life = sinceLanding / 0.85;
      if (life >= 1) break;
      final seed = i + landing * 13;
      final angle =
          -math.pi / 2 +
          (i / (_burstCount - 1) - 0.5) * 2.6 +
          (_rand(seed) - 0.5) * 0.3;
      final distance = coinSize * (0.75 + 0.55 * _rand(seed + 7));
      final travel = Curves.easeOutCubic.transform(math.min(1.0, life * 1.4));
      final p =
          ground.translate(0, -radius * 0.1) +
          Offset(math.cos(angle), math.sin(angle)) * (distance * travel) +
          Offset(0, -coinSize * 0.25 * life);
      final r =
          coinSize *
          (0.045 + 0.035 * _rand(seed + 3)) *
          Curves.easeOutBack.transform(math.min(1.0, life * 5));
      final tint = _tints[seed % _tints.length];
      if (life < 0.8) {
        _bubble(canvas, p, r, 1, tint);
      } else {
        // Pop: a ring bursting outward and fading.
        final pop = (life - 0.8) / 0.2;
        canvas.drawCircle(
          p,
          r * (1 + pop * 0.9),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(0.8, r * 0.18 * (1 - pop))
            ..color = tint.withValues(alpha: 0.9 * (1 - pop)),
        );
      }
    }
  }

  void _bubble(Canvas canvas, Offset c, double r, double alpha, Color tint) {
    if (alpha <= 0 || r <= 0) return;
    canvas.drawCircle(
      c,
      r,
      Paint()..color = tint.withValues(alpha: 0.18 * alpha),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, r * 0.14)
        ..color = tint.withValues(alpha: 0.9 * alpha),
    );
    canvas.drawCircle(
      c.translate(-r * 0.35, -r * 0.35),
      r * 0.3,
      Paint()..color = Colors.white.withValues(alpha: 0.85 * alpha),
    );
  }

  @override
  bool shouldRepaint(covariant _LoaderFxPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.shell != shell ||
      oldDelegate.center != center;
}

/// A full-screen, see-through loader: taps are blocked, and the bouncing
/// coin pops in at the center of the screen over whatever is showing. A
/// short [delay] keeps it from flashing for tasks that finish instantly.
class UtopiaLoadingOverlay extends StatefulWidget {
  const UtopiaLoadingOverlay({
    super.key,
    this.label,
    this.delay = const Duration(milliseconds: 180),
  });

  final String? label;
  final Duration delay;

  @override
  State<UtopiaLoadingOverlay> createState() => _UtopiaLoadingOverlayState();
}

class _UtopiaLoadingOverlayState extends State<UtopiaLoadingOverlay> {
  Timer? _reveal;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _reveal = Timer(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _reveal?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ModalBarrier(dismissible: false, color: Colors.transparent),
          if (_visible)
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 520),
                builder: (context, v, child) => Opacity(
                  opacity: Curves.easeOut.transform(math.min(1.0, v * 2)),
                  child: Transform.scale(
                    scale: 0.5 + 0.5 * Curves.elasticOut.transform(v),
                    child: child,
                  ),
                ),
                // A soft halo keeps the coin readable over busy screens
                // without dimming the screen itself.
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.background.withValues(alpha: 0.6),
                        AppColors.background.withValues(alpha: 0),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: UtopiaLoader(size: 84, label: widget.label),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Runs [task] with [UtopiaLoadingOverlay] floating over the whole app,
/// removing it when [task] finishes (or throws).
Future<T> runWithUtopiaLoader<T>(
  BuildContext context,
  Future<T> Function() task, {
  String? label,
}) async {
  final entry = OverlayEntry(
    builder: (context) => UtopiaLoadingOverlay(label: label),
  );
  Overlay.of(context, rootOverlay: true).insert(entry);
  try {
    return await task();
  } finally {
    entry.remove();
  }
}
