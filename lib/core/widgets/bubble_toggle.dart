import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Utopia's switch: a glossy pill whose knob is a soap bubble. The knob
/// springs across with a jelly squash, and turning it on pops a little
/// burst of sparkles.
class BubbleToggle extends StatefulWidget {
  const BubbleToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.onIcon = Icons.check_rounded,
    this.offIcon = Icons.close_rounded,
    this.width = 62,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData onIcon;
  final IconData offIcon;
  final double width;
  final String? semanticLabel;

  @override
  State<BubbleToggle> createState() => _BubbleToggleState();
}

class _BubbleToggleState extends State<BubbleToggle>
    with TickerProviderStateMixin {
  late final AnimationController _position = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
    value: widget.value ? 1 : 0,
  );
  late final AnimationController _squash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void didUpdateWidget(covariant BubbleToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _position.animateTo(widget.value ? 1 : 0, curve: Curves.elasticOut);
      _squash.forward(from: 0);
      if (widget.value) _burst.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _position.dispose();
    _squash.dispose();
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.width * 0.55;
    final knob = height - 6;
    final enabled = widget.onChanged != null;

    return Semantics(
      toggled: widget.value,
      label: widget.semanticLabel,
      button: true,
      child: GestureDetector(
        onTap: enabled ? () => widget.onChanged!(!widget.value) : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: AnimatedBuilder(
            animation: Listenable.merge([_position, _squash, _burst]),
            builder: (context, _) {
              final p = _position.value;
              final on = p.clamp(0.0, 1.0);
              final squash = math.sin(_squash.value * math.pi);
              final trackColor = Color.lerp(
                AppColors.surfaceElevated,
                AppColors.accent,
                on,
              )!;
              return SizedBox(
                width: widget.width,
                height: height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(height / 2),
                          border: Border.all(
                            color: Color.lerp(
                              AppColors.glowRing.withValues(alpha: 0.5),
                              AppColors.goldBorder,
                              on,
                            )!,
                            width: 1.6,
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color.lerp(trackColor, Colors.white, 0.18)!,
                              trackColor,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(
                                alpha: 0.45 * on,
                              ),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Gloss along the top of the track.
                    Positioned(
                      left: height * 0.35,
                      right: height * 0.35,
                      top: 3,
                      height: height * 0.22,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(height),
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                    ),
                    if (_burst.isAnimating)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _BurstPainter(
                            center: Offset(
                              widget.width - height / 2,
                              height / 2,
                            ),
                            t: _burst.value,
                          ),
                        ),
                      ),
                    Positioned(
                      left: 3 + p * (widget.width - knob - 6),
                      top: 3,
                      width: knob,
                      height: knob,
                      child: Transform.scale(
                        scaleX: 1 + 0.22 * squash,
                        scaleY: 1 - 0.14 * squash,
                        child: _Knob(
                          size: knob,
                          icon: widget.value ? widget.onIcon : widget.offIcon,
                          on: on,
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

class _Knob extends StatelessWidget {
  const _Knob({required this.size, required this.icon, required this.on});

  final double size;
  final IconData icon;
  final double on;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.35, -0.4),
          colors: [Colors.white, Color(0xFFEDE6FF), Color(0xFFCBBDF0)],
          stops: [0.0, 0.6, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          icon,
          size: size * 0.58,
          color: Color.lerp(AppColors.cardOutline, AppColors.accent, on),
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.center, required this.t});

  final Offset center;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final ease = Curves.easeOutCubic.transform(t);
    final paint = Paint();
    for (var i = 0; i < 7; i++) {
      final angle = i / 7 * 2 * math.pi + 0.3;
      final p =
          center + Offset(math.cos(angle), math.sin(angle)) * (8 + 18 * ease);
      paint.color = (i.isEven ? AppColors.goldBorderBright : Colors.white)
          .withValues(alpha: 1 - t);
      canvas.drawCircle(p, 2.2 * (1 - t) + 0.6, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.center != center;
}
