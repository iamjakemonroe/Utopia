import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/coin_buddy.dart';
import '../../../../core/widgets/frame_island.dart';
import '../../../../l10n/strings.dart';

/// How far the piece is from the middle of what's anchored over it, when
/// the board kept that inside its edges: its point still points at it.
class LudoAnchorTail extends InheritedWidget {
  const LudoAnchorTail({super.key, required this.dx, required super.child});

  final double dx;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LudoAnchorTail>()?.dx ?? 0;

  @override
  bool updateShouldNotify(LudoAnchorTail oldWidget) => oldWidget.dx != dx;
}

/// [tail] moved [dx] along, kept [inset] inside a bubble [width] wide.
Widget _pointAt(BuildContext context, Widget tail, double width, double inset) {
  final dx = LudoAnchorTail.of(
    context,
  ).clamp(-(width / 2 - inset), width / 2 - inset);
  return Transform.translate(offset: Offset(dx, 0), child: tail);
}

/// How long is left of a capture's reaction window, 1 to 0.
double _left(DateTime deadline, Duration window) =>
    (deadline.difference(DateTime.now()).inMilliseconds / window.inMilliseconds)
        .clamp(0.0, 1.0);

/// The countdown's color: gold with time to spare, red as it runs out.
Color _timeColor(double left) =>
    Color.lerp(AppColors.error, AppColors.coinGold, left)!;

/// A small badge over a token that just captured, while its player can
/// react: a ring around it drains as the time runs out. For the player who
/// captured it says "React" (tap the piece, or the badge, to choose); for
/// everyone else it's a little "thinking". It sits over the piece, not
/// over the board.
class LudoCaptureBadge extends StatefulWidget {
  const LudoCaptureBadge({
    super.key,
    required this.deadline,
    required this.window,
    this.onTap,
  });

  final DateTime deadline;
  final Duration window;

  /// Opens the reaction card: set for the player who captured.
  final VoidCallback? onTap;

  static const size = Size(112, 40);

  @override
  State<LudoCaptureBadge> createState() => _LudoCaptureBadgeState();
}

class _LudoCaptureBadgeState extends State<LudoCaptureBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _beat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mine = widget.onTap != null;
    return FrameIsland(
      size: LudoCaptureBadge.size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _beat,
          builder: (context, _) {
            final t = _beat.value;
            // The one who captured gets a gentle pulse: tap me.
            final pulse = mine ? 1 + 0.06 * math.sin(t * 2 * math.pi) : 1.0;
            return Align(
              alignment: Alignment.bottomCenter,
              child: Transform.scale(
                scale: pulse,
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomPaint(
                      painter: _PillPainter(
                        left: _left(widget.deadline, widget.window),
                        glow: mine,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: mine
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.touch_app_rounded,
                                    size: 14,
                                    color: AppColors.faceInk,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    strings.ludoCaptureBubbleReact,
                                    style: AppTextStyles.body(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.faceInk,
                                    ),
                                  ),
                                ],
                              )
                            : _Thinking(t: t),
                      ),
                    ),
                    _pointAt(
                      context,
                      CustomPaint(
                        size: const Size(10, 6),
                        painter: _TailPainter(),
                      ),
                      LudoCaptureBadge.size.width - 20,
                      18,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// War or peace, for the player who captured, over the piece that did it.
/// Opens when they tap it; the time left runs along the bottom.
class LudoReactionCard extends StatefulWidget {
  const LudoReactionCard({
    super.key,
    required this.deadline,
    required this.window,
    required this.onWar,
    required this.onPeace,
  });

  final DateTime deadline;
  final Duration window;
  final VoidCallback onWar;
  final VoidCallback onPeace;

  static const size = Size(184, 116);

  @override
  State<LudoReactionCard> createState() => _LudoReactionCardState();
}

class _LudoReactionCardState extends State<LudoReactionCard>
    with TickerProviderStateMixin {
  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  )..forward();
  late final AnimationController _tick = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  @override
  void dispose() {
    _open.dispose();
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FrameIsland(
      size: LudoReactionCard.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_open, _tick]),
        builder: (context, _) {
          final v = _open.value;
          final left = _left(widget.deadline, widget.window);
          return Align(
            alignment: Alignment.bottomCenter,
            child: Opacity(
              opacity: v.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.8 + 0.2 * Curves.easeOutBack.transform(v),
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.goldBorder.withValues(alpha: 0.7),
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x55000000),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _Choice(
                                mood: BuddyMood.evil,
                                label: strings.ludoCaptureBubbleWar,
                                tint: AppColors.error,
                                onTap: widget.onWar,
                              ),
                              const SizedBox(width: 10),
                              _Choice(
                                mood: BuddyMood.peaceful,
                                label: strings.ludoCaptureBubblePeace,
                                tint: AppColors.success,
                                onTap: widget.onPeace,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // The time left, draining.
                          SizedBox(
                            width: 132,
                            height: 4,
                            child: CustomPaint(
                              painter: _BarPainter(left: left),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _pointAt(
                      context,
                      CustomPaint(
                        size: const Size(14, 8),
                        painter: _TailPainter(color: AppColors.surfaceElevated),
                      ),
                      LudoReactionCard.size.width,
                      22,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.mood,
    required this.label,
    required this.tint,
    required this.onTap,
  });

  final BuddyMood mood;
  final String label;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Semantics(
        button: true,
        label: label,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tint.withValues(alpha: 0.16),
                border: Border.all(
                  color: tint.withValues(alpha: 0.75),
                  width: 1.5,
                ),
              ),
              child: CoinBuddy(mood: mood, size: 42),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: AppTextStyles.body(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: AppColors.readable(tint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three dots bobbing in turn: someone's deciding.
class _Thinking extends StatelessWidget {
  const _Thinking({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.translate(
                offset: Offset(
                  0,
                  -3 * math.max(0.0, math.sin((t * 2 - i * 0.2) * 2 * math.pi)),
                ),
                child: Container(
                  width: 6,
                  height: 6,
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

/// A white pill with the time left as a ring around it.
class _PillPainter extends CustomPainter {
  _PillPainter({required this.left, required this.glow});

  final double left;

  /// A soft gold halo, for the badge to tap.
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final pill = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );
    if (glow) {
      canvas.drawRRect(
        pill.inflate(3),
        Paint()
          ..color = AppColors.coinGold.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
    canvas.drawRRect(
      pill.shift(const Offset(0, 2)),
      Paint()..color = Colors.black.withValues(alpha: 0.2),
    );
    canvas.drawRRect(pill, Paint()..color = Colors.white);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final track = Path()..addRRect(pill.inflate(2.5));
    canvas.drawPath(track, ring..color = Colors.white.withValues(alpha: 0.35));
    final metric = track.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * left),
      ring..color = _timeColor(left),
    );
  }

  @override
  bool shouldRepaint(covariant _PillPainter old) =>
      old.left != left || old.glow != glow;
}

/// A thin bar draining from the right.
class _BarPainter extends CustomPainter {
  _BarPainter({required this.left});

  final double left;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, r),
      Paint()..color = AppColors.textSecondary.withValues(alpha: 0.2),
    );
    if (left <= 0) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width * left, size.height),
        r,
      ),
      Paint()..color = _timeColor(left),
    );
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) => old.left != left;
}

/// The little point under a bubble, down at the piece.
class _TailPainter extends CustomPainter {
  _TailPainter({this.color = Colors.white});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _TailPainter old) => old.color != color;
}
