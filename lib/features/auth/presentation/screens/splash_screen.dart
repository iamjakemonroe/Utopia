import '../../../dev/sets_preview.dart';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/audio/game_audio.dart';
import '../../../../core/router/app_router.dart' show SplashHandoff;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/outlined_heading.dart';
import '../../../../core/widgets/utopia_loader.dart';
import '../../../../core/widgets/utopia_world.dart';
import '../../../auras/domain/aura.dart';
import '../../../auras/presentation/aura_sheet.dart';
import '../../../chip/presentation/chip_chat_sheet.dart';
import '../../../../core/bots/bots.dart';
import '../../../ludo/presentation/controllers/ludo_match_controller.dart';
import '../../../ludo/presentation/widgets/ludo_setup_widgets.dart';
import '../../../friends/presentation/widgets/friends_popup.dart';
import '../../../store/presentation/coin_shop.dart';
import '../providers/auth_providers.dart';

/// Shared with main.dart, which decodes this image while Supabase
/// initializes so the splash's first frame already has it — otherwise the
/// logo would flash empty for a frame right as the native screen hands off.
const kSplashLogoAsset = kUtopiaLogoAsset;

/// Must match the native launch image size (110pt on iOS, 110dp on Android).
const double kSplashLogoSize = 110;

/// The native launch screen's color (LaunchScreen.storyboard,
/// launch_background.xml). Fixed rather than themed: the splash's first
/// frame has to match the OS launch screen exactly, whatever theme is on.
const _launchBackground = Color(0xFF120B2E);

/// The branded intro on every cold start. Utopia's mark (the floating
/// island and its gateway) blows a soap bubble around itself, the bubble
/// swells out past the edges of the screen to reveal the utopia world, and
/// the island bounces while the title rises in. Then the app fades in.
///
/// Its first frame is deliberately identical to the native launch screen
/// (same mark, same size, same exact center, nothing else visible) so the
/// OS-to-Flutter handoff is seamless; everything starts moving only once
/// that frame is on screen. Supabase has already restored any session
/// before runApp (see main.dart), so the splash then routes itself to
/// `/home` or `/auth`. The router deliberately leaves `/splash` alone.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  /// Leave as the coin settles from its second landing.
  static const _exitAfter = UtopiaLoader.cycleSeconds * 2;

  final ValueNotifier<double> _seconds = ValueNotifier(0);
  late final Ticker _ticker = createTicker(_tick);
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    // Start once the splash is actually on screen, not when it's built:
    // the first frame can take a second or more to rasterize (debug
    // builds, slower phones), and a clock started now would cut the
    // animation short or skip it entirely. On the web a frame is drawn as
    // it's built, and the engine only reports a drawn frame once another
    // follows it, so waiting for that report on this still first frame
    // would wait forever: there, start when the first frame is done.
    final onScreen = kIsWeb
        ? WidgetsBinding.instance.endOfFrame
        : WidgetsBinding.instance.waitUntilFirstFrameRasterized;
    onScreen.then((_) {
      if (mounted) _ticker.start();
    });
  }

  void _tick(Duration elapsed) {
    final seconds = elapsed.inMicroseconds / 1e6;
    _seconds.value = seconds;
    if (_leaving || seconds < _exitAfter) return;
    _leaving = true;
    // The menu music starts as the app opens up.
    ref.read(gameAudioProvider).setBaseTrack(MusicTrack.menu);
    final signedIn = ref.read(authRepositoryProvider).currentSession != null;
    SplashHandoff.done = true;
    // Home takes the player back into any game they left unfinished (or
    // into a friend's room, when an invite link opened the app).
    context.go(signedIn ? '/home' : '/auth');
    if (kDebugMode && !kIsWeb) _debugStartRoute();
  }

  /// Debug builds only: opens the screen named in the file
  /// `<tmp>/utopia_debug_route` (e.g. "/ludo", "coins" for the coin shop,
  /// "chip" for a chat with Chip, or "aura:storm" for an aura), so a simulator can be put on any screen without tapping
  /// through. Compiled out of release builds.
  void _debugStartRoute() {
    final file = File('${Directory.systemTemp.path}/utopia_debug_route');
    if (!file.existsSync()) return;
    final route = file.readAsStringSync().trim();
    if (route.isEmpty) return;
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    Future.delayed(const Duration(milliseconds: 600), () {
      final ctx = navigator.context;
      if (route == 'coins') {
        if (ctx.mounted) showCoinShop(ctx);
      } else if (route == 'friends') {
        if (ctx.mounted) showFriendsPopup(ctx);
      } else if (route == 'chip') {
        if (ctx.mounted) showChipChat(ctx);
      } else if (route == 'sets') {
        navigator.push(
          MaterialPageRoute<void>(builder: (_) => const SetsPreview()),
        );
      } else if (route.startsWith('ludo-bots:')) {
        // "ludo-bots:<players>:<my seat>": an offline table with bots.
        final parts = route.split(':');
        final players = int.tryParse(parts[1]) ?? 4;
        final mySeat = int.tryParse(parts.length > 2 ? parts[2] : '') ?? 0;
        final me = Supabase.instance.client.auth.currentUser?.id ?? 'me';
        var next = 0;
        final id = startLocalLudo(
          LocalLudoSetup(
            playerIds: [
              for (var seat = 0; seat < players; seat++)
                seat == mySeat ? me : kLudoBots[next++].id,
            ],
            colors: ludoSeatColors(players),
            humanId: me,
          ),
        );
        router.push('/ludo/$id');
      } else if (route.startsWith('aura:')) {
        router.push('/store?tab=auras');
        final aura = Aura.byId(route.substring(5));
        if (aura != null) {
          Future.delayed(const Duration(milliseconds: 700), () {
            if (ctx.mounted) showAuraSheet(ctx, aura);
          });
        }
      } else {
        router.push(route);
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _launchBackground,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screen = constraints.biggest;
          final center = screen.center(Offset.zero);
          // Far enough to clear the corners.
          final fullReveal = screen.longestSide * 0.62 + 40;
          final loaderBox = UtopiaLoaderView.extentFor(kSplashLogoSize);
          // The world is built from the start (so it isn't created mid
          // animation) and uncovered by the growing circle.
          const world = UtopiaWorld();

          return ValueListenableBuilder<double>(
            valueListenable: _seconds,
            builder: (context, seconds, _) {
              double phase(double start, double length) =>
                  ((seconds - start) / length).clamp(0.0, 1.0);

              final reveal = Curves.easeInOutCubic.transform(phase(0.2, 0.9));
              final title = Curves.easeOutCubic.transform(phase(0.5, 0.55));

              return Stack(
                children: [
                  Positioned.fill(
                    child: ClipPath(
                      clipper: _CircleClipper(center, reveal * fullReveal),
                      child: world,
                    ),
                  ),
                  if (reveal > 0 && reveal < 1)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _RevealRimPainter(
                          center: center,
                          radius: reveal * fullReveal,
                          fade: 1 - reveal,
                        ),
                      ),
                    ),
                  Positioned(
                    left: center.dx - loaderBox.width / 2,
                    top: center.dy - loaderBox.height / 2,
                    width: loaderBox.width,
                    height: loaderBox.height,
                    child: UtopiaLoaderView(
                      size: kSplashLogoSize,
                      progress: seconds / UtopiaLoader.cycleSeconds,
                      shell: phase(0, 0.5),
                      brand: true,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: center.dy + kSplashLogoSize * 0.67 + AppSpacing.xl,
                    child: Opacity(
                      opacity: title,
                      child: Transform.translate(
                        offset: Offset(0, 16 * (1 - title)),
                        child: Column(
                          children: [
                            const OutlinedHeading('Utopia', fontSize: 36),
                            const SizedBox(height: AppSpacing.md),
                            _LoadingDots(phase: seconds / 0.9),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _CircleClipper extends CustomClipper<Path> {
  const _CircleClipper(this.center, this.radius);

  final Offset center;
  final double radius;

  @override
  Path getClip(Size size) =>
      Path()..addOval(Rect.fromCircle(center: center, radius: radius));

  @override
  bool shouldReclip(covariant _CircleClipper oldClipper) =>
      oldClipper.center != center || oldClipper.radius != radius;
}

/// The iridescent skin on the edge of the expanding reveal, so it reads as
/// a giant bubble swelling out rather than a plain circular wipe.
class _RevealRimPainter extends CustomPainter {
  const _RevealRimPainter({
    required this.center,
    required this.radius,
    required this.fade,
  });

  final Offset center;
  final double radius;
  final double fade;

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
    if (radius <= 0) return;
    final bounds = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..color = Colors.white.withValues(alpha: 0.08 * fade),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..shader = SweepGradient(
          colors: [
            for (final color in _sheen) color.withValues(alpha: 0.85 * fade),
          ],
          transform: GradientRotation(radius / 120),
        ).createShader(bounds),
    );
    canvas.drawArc(
      bounds.deflate(14),
      math.pi * 1.1,
      math.pi * 0.3,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 7
        ..color = Colors.white.withValues(alpha: 0.35 * fade),
    );
  }

  @override
  bool shouldRepaint(covariant _RevealRimPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.fade != fade;
}

/// Three glossy gold dots hopping in sequence — reads as "loading" at a
/// glance and matches the coin's bounce.
class _LoadingDots extends StatelessWidget {
  const _LoadingDots({required this.phase});

  /// Hop cycles elapsed.
  final double phase;

  double _hop(int i) {
    final t = (phase - i * 0.18) % 1.0;
    return t < 0.5 ? math.sin(t / 0.5 * math.pi) : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Transform.translate(
                offset: Offset(0, -12 * _hop(i)),
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: Alignment(-0.35, -0.4),
                      colors: [AppColors.goldBorderBright, Color(0xFFE08A00)],
                    ),
                    boxShadow: [
                      BoxShadow(color: Color(0x66FFC94D), blurRadius: 8),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
