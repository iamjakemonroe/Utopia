import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/game_audio.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/utopia_themes.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/coin_buddy.dart';
import 'store_controller.dart';
import '../../../l10n/strings.dart';

/// Requests a trip to another world; [ThemeTeleportLayer] plays it.
class ThemeTeleportController extends StateNotifier<UtopiaTheme?> {
  ThemeTeleportController() : super(null);

  VoidCallback? _atFlash;

  void travelTo(UtopiaTheme theme) {
    if (state != null) return;
    state = theme;
  }

  /// The same trip used as an entrance: Chip carries the player into
  /// [theme] (usually the world they're already in), and [atFlash] runs
  /// under the flash, so a screen change happens out of sight. Returns
  /// false if a trip is already playing.
  bool welcome(UtopiaTheme theme, {required VoidCallback atFlash}) {
    if (state != null) return false;
    _atFlash = atFlash;
    state = theme;
    return true;
  }

  /// Runs (once) whatever was waiting for the flash.
  void flash() {
    final action = _atFlash;
    _atFlash = null;
    action?.call();
  }

  void done() => state = null;
}

final themeTeleportProvider =
    StateNotifierProvider<ThemeTeleportController, UtopiaTheme?>(
      (ref) => ThemeTeleportController(),
    );

/// The theme switch as a little film starring Chip: Chip pops in, a
/// swirling portal in the new world's colors opens behind it, Chip spins
/// and gets sucked in, a flash covers the switch (the whole app recolors
/// underneath), hyperspace streaks fly past, and Chip bursts back out into
/// the new world to say hi.
///
/// Sits above the router in the app's builder, so the rebuild that the
/// theme switch triggers never interrupts it.
class ThemeTeleportLayer extends ConsumerStatefulWidget {
  const ThemeTeleportLayer({super.key});

  @override
  ConsumerState<ThemeTeleportLayer> createState() => _ThemeTeleportLayerState();
}

class _ThemeTeleportLayerState extends ConsumerState<ThemeTeleportLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  UtopiaTheme? _target;
  bool _switched = false;

  /// When, in the clip (0-1), the flash peaks and the theme switches.
  static const _flashAt = 0.46;

  @override
  void initState() {
    super.initState();
    _clip.addListener(() {
      if (!_switched && _clip.value >= _flashAt && _target != null) {
        _switched = true;
        final changing = ref.read(themeControllerProvider).id != _target!.id;
        ref.read(themeControllerProvider.notifier).apply(_target!);
        if (changing) {
          ref.read(storeControllerProvider.notifier).rememberTheme(_target!.id);
        }
        ref.read(themeTeleportProvider.notifier).flash();
      }
    });
    _clip.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _target = null);
        ref.read(themeTeleportProvider.notifier).done();
      }
    });
  }

  @override
  void dispose() {
    _clip.dispose();
    super.dispose();
  }

  void _start(UtopiaTheme theme) {
    setState(() {
      _target = theme;
      _switched = false;
    });
    ref.read(gameAudioProvider).play(Sfx.teleport);
    _clip.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(themeTeleportProvider, (prev, next) {
      if (next != null && prev == null) _start(next);
    });
    final target = _target;
    if (target == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _clip,
      builder: (context, _) {
        final t = _clip.value;
        double phase(double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

        final dim = t < 0.85 ? phase(0, 0.12) : 1 - phase(0.85, 1);
        final portalOpen = Curves.easeOutBack.transform(phase(0.1, 0.38));
        final suck = Curves.easeInCubic.transform(phase(0.24, 0.44));
        final flash = t < _flashAt
            ? phase(0.38, _flashAt)
            : 1 - phase(_flashAt, 0.62);
        final warp = phase(0.46, 0.72);
        final pop = phase(0.58, 0.72);
        final leave = phase(0.86, 1);

        final size = MediaQuery.sizeOf(context);
        final buddySize = size.width * 0.36;
        final before = t < _flashAt;

        return Material(
          type: MaterialType.transparency,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Blocks taps for the whole trip.
              const ModalBarrier(dismissible: false, color: Colors.transparent),
              ColoredBox(color: Colors.black.withValues(alpha: 0.62 * dim)),
              if (before)
                CustomPaint(
                  painter: _PortalPainter(
                    style: target.world,
                    accent: target.accent,
                    open: portalOpen,
                    spin: t * 18,
                    // The portal swells to swallow the screen at the flash.
                    swallow: phase(0.36, _flashAt),
                  ),
                ),
              if (!before && warp < 1)
                CustomPaint(
                  painter: _WarpPainter(style: target.world, progress: warp),
                ),
              Center(
                child: before
                    ? Transform.rotate(
                        angle: suck * 6 * math.pi,
                        child: Transform.scale(
                          scaleX:
                              (1 - suck) *
                              Curves.elasticOut.transform(phase(0, 0.16)),
                          scaleY:
                              (1 - suck) *
                              (1 + suck * 0.9) *
                              Curves.elasticOut.transform(phase(0, 0.16)),
                          child: CoinBuddy(
                            mood: BuddyMood.excited,
                            size: buddySize,
                          ),
                        ),
                      )
                    : Transform.scale(
                        scale:
                            Curves.elasticOut.transform(pop) *
                            (1 - Curves.easeInBack.transform(leave)),
                        child: CoinBuddy(
                          mood: BuddyMood.happy,
                          size: buddySize,
                        ),
                      ),
              ),
              if (!before)
                Positioned(
                  left: 24,
                  right: 24,
                  top: size.height * 0.5 + buddySize * 0.62,
                  child: Opacity(
                    opacity: (phase(0.62, 0.7) * (1 - leave)).clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(
                        0,
                        20 *
                            (1 -
                                Curves.easeOutBack.transform(
                                  phase(0.62, 0.74),
                                )),
                      ),
                      child: Column(
                        children: [
                          Text(
                            strings.themeTeleportWelcomeTo,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.body(
                              fontSize: 16,
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            target.name,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.display(
                              fontSize: 32,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (flash > 0)
                IgnorePointer(
                  child: ColoredBox(
                    color: Color.lerp(
                      Colors.white,
                      target.world.glow,
                      0.25,
                    )!.withValues(alpha: flash),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A spinning vortex in the destination world's colors, with sparks being
/// pulled into its center.
class _PortalPainter extends CustomPainter {
  _PortalPainter({
    required this.style,
    required this.accent,
    required this.open,
    required this.spin,
    required this.swallow,
  });

  final WorldStyle style;
  final Color accent;
  final double open;
  final double spin;
  final double swallow;

  @override
  void paint(Canvas canvas, Size size) {
    if (open <= 0) return;
    final c = size.center(Offset.zero);
    final full = size.longestSide;
    final r = (size.width * 0.42 * open) + swallow * swallow * full;

    // The world on the other side, seen through the portal.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [style.sky[4], style.sky[2], style.sky[0]],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // Spiral arms.
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
    final colors = [style.aurora[0], accent, style.glow, style.aurora[1]];
    for (var arm = 0; arm < 4; arm++) {
      final path = Path();
      for (var i = 0; i <= 40; i++) {
        final u = i / 40;
        final a = spin + arm * math.pi / 2 + u * 5.5;
        final p = c + Offset(math.cos(a), math.sin(a)) * r * u;
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = r * 0.09
          ..color = colors[arm].withValues(alpha: 0.55),
      );
    }
    canvas.restore();

    // Sparks spiralling inward.
    final spark = Paint();
    for (var i = 0; i < 40; i++) {
      final life = (spin * 0.08 + i / 40) % 1.0;
      final a = i * 2.4 + spin * 0.6 + life * 4;
      final d = r * 1.25 * (1 - life);
      final p = c + Offset(math.cos(a), math.sin(a)) * d;
      spark.color = style.sparkles[i % style.sparkles.length].withValues(
        alpha: math.sin(life * math.pi),
      );
      canvas.drawCircle(p, 1.5 + 2.5 * (1 - life), spark);
    }

    // Glowing rim.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..shader = SweepGradient(
          colors: [...colors, colors.first],
          transform: GradientRotation(spin),
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  bool shouldRepaint(covariant _PortalPainter old) => true;
}

/// Hyperspace: streaks rushing outward from the center as the new world
/// arrives.
class _WarpPainter extends CustomPainter {
  _WarpPainter({required this.style, required this.progress});

  final WorldStyle style;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final fade = 1 - progress;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4;
    for (var i = 0; i < 70; i++) {
      final a = i * 2.39996; // golden angle: an even spread
      final speed = 0.6 + (i * 37 % 10) / 10;
      final near = (progress * speed * 1.6 + (i * 13 % 7) / 7) % 1.0;
      final d0 = size.longestSide * 0.7 * near * near;
      final d1 = d0 + 30 + 120 * near;
      final dir = Offset(math.cos(a), math.sin(a));
      paint.color = style.sparkles[i % style.sparkles.length].withValues(
        alpha: fade * near,
      );
      canvas.drawLine(c + dir * d0, c + dir * d1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WarpPainter old) => old.progress != progress;
}
