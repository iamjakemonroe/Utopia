import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/coin_buddy.dart';

/// The thought bubble that floats over a token right after it captures.
/// The capturing player picks a reaction (war or peace) before the
/// ring runs out; everyone else watches the same bubble "thinking".
class LudoCaptureBubble extends StatefulWidget {
  const LudoCaptureBubble({
    super.key,
    required this.deadline,
    required this.window,
    this.onWar,
    this.onPeace,
  });

  final DateTime deadline;
  final Duration window;

  /// Null for spectators: they see the thinking dots instead of buttons.
  final VoidCallback? onWar;
  final VoidCallback? onPeace;

  @override
  State<LudoCaptureBubble> createState() => _LudoCaptureBubbleState();
}

class _LudoCaptureBubbleState extends State<LudoCaptureBubble>
    with TickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

  @override
  void dispose() {
    _float.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final choosing = widget.onWar != null;
    return AnimatedBuilder(
      animation: Listenable.merge([_float, _pop]),
      builder: (context, _) {
        final remaining = widget.deadline
            .difference(DateTime.now())
            .inMilliseconds;
        final left = (remaining / widget.window.inMilliseconds).clamp(0.0, 1.0);
        final bob = math.sin(_float.value * 2 * math.pi) * 4;
        return Transform.translate(
          offset: Offset(0, bob),
          child: Transform.scale(
            scale: Curves.elasticOut.transform(_pop.value),
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomPaint(
                  painter: _CloudPainter(timeLeft: left),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: choosing
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _Choice(
                                mood: BuddyMood.evil,
                                label: 'War',
                                onTap: widget.onWar!,
                              ),
                              const SizedBox(width: 10),
                              _Choice(
                                mood: BuddyMood.peaceful,
                                label: 'Peace',
                                onTap: widget.onPeace!,
                              ),
                            ],
                          )
                        : _ThinkingDots(t: _float.value),
                  ),
                ),
                // The little trail of bubbles down to the token.
                const SizedBox(height: 2),
                _dot(9),
                const SizedBox(height: 2),
                _dot(6),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _dot(double size) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white,
      boxShadow: [BoxShadow(color: Color(0x44000000), blurRadius: 3)],
    ),
  );
}

class _Choice extends StatelessWidget {
  const _Choice({required this.mood, required this.label, required this.onTap});

  final BuddyMood mood;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface.withValues(alpha: 0.08),
              border: Border.all(
                color: AppColors.glowRing.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: CoinBuddy(mood: mood, size: 44),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.body(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.faceInk,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThinkingDots extends StatelessWidget {
  const _ThinkingDots({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CoinBuddy(mood: BuddyMood.thinking, size: 28),
          const SizedBox(width: 6),
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.translate(
                offset: Offset(
                  0,
                  -4 * math.max(0.0, math.sin((t * 2 - i * 0.2) * 2 * math.pi)),
                ),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.faceInk,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A puffy white cloud with a countdown ring tracing its outline.
class _CloudPainter extends CustomPainter {
  _CloudPainter({required this.timeLeft});

  final double timeLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.height * 0.5;
    final body = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(r),
    );
    final cloud = Path()
      ..addRRect(body)
      ..addOval(
        Rect.fromCircle(center: Offset(size.width * 0.3, 4), radius: r * 0.55),
      )
      ..addOval(
        Rect.fromCircle(center: Offset(size.width * 0.62, 2), radius: r * 0.65),
      );
    canvas.drawPath(
      cloud.shift(const Offset(0, 3)),
      Paint()..color = Colors.black.withValues(alpha: 0.2),
    );
    canvas.drawPath(cloud, Paint()..color = Colors.white);

    // The timer: a ring that drains around the bubble.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final track = Path()..addRRect(body.inflate(4));
    canvas.drawPath(track, ring..color = Colors.white.withValues(alpha: 0.35));
    final metric = track.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * timeLeft),
      ring..color = Color.lerp(AppColors.error, AppColors.coinGold, timeLeft)!,
    );
  }

  @override
  bool shouldRepaint(covariant _CloudPainter old) => old.timeLeft != timeLeft;
}
