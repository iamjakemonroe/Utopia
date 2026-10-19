import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/coin_buddy.dart';
import '../../../../core/widgets/utopia_icons.dart';
import '../../../../core/widgets/frosted.dart';

/// The Utopia gateway floating in a halo of turning light, with Chip
/// hovering beside it.
class AuthHero extends StatefulWidget {
  const AuthHero({super.key, this.mood = BuddyMood.happy, this.size = 150});

  final BuddyMood mood;
  final double size;

  @override
  State<AuthHero> createState() => _AuthHeroState();
}

class _AuthHeroState extends State<AuthHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 12))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s * 1.9,
      height: s * 1.25,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value * 12;
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                size: Size(s * 1.9, s * 1.25),
                painter: _HaloPainter(t: t, color: AppColors.glowRing),
              ),
              Transform.translate(
                offset: Offset(0, math.sin(t * 1.6) * 6),
                child: Image.asset(
                  'assets/branding/logo_mark.png',
                  width: s,
                  height: s,
                ),
              ),
              Positioned(
                right: 0,
                bottom: s * 0.02 + math.sin(t * 2.1 + 1) * 8,
                child: CoinBuddy(mood: widget.mood, size: s * 0.62),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HaloPainter extends CustomPainter {
  _HaloPainter({required this.t, required this.color});

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.height * 0.5;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.45), color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // Slowly turning rays.
    for (var i = 0; i < 12; i++) {
      final a = t * 0.25 + i * math.pi / 6;
      final w = i.isEven ? 0.09 : 0.05;
      final len = r * (i.isEven ? 1.05 : 0.85);
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + math.cos(a - w) * len, c.dy + math.sin(a - w) * len)
        ..lineTo(c.dx + math.cos(a + w) * len, c.dy + math.sin(a + w) * len)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFE29A).withValues(alpha: 0.35),
              const Color(0x00FFE29A),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: len)),
      );
    }
    // Sparkles twinkling around the gateway.
    for (var i = 0; i < 7; i++) {
      final phase = (t * 0.6 + i * 0.29) % 1.4;
      if (phase > 1) continue;
      final s = math.sin(phase * math.pi) * 7;
      final a = i * 0.9 + 0.4;
      final p =
          c + Offset(math.cos(a), math.sin(a)) * r * (0.72 + (i % 3) * 0.1);
      canvas.drawPath(
        Path()
          ..moveTo(p.dx, p.dy - s)
          ..quadraticBezierTo(p.dx, p.dy, p.dx + s, p.dy)
          ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + s)
          ..quadraticBezierTo(p.dx, p.dy, p.dx - s, p.dy)
          ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - s),
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HaloPainter old) => old.t != t;
}

/// Frosted glass over the living world.
class GlassPanel extends StatelessWidget {
  const GlassPanel({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Frosted(
        sigma: 18,
        child: Container(
          padding: padding ?? const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.surfaceElevated.withValues(alpha: 0.72),
                AppColors.surface.withValues(alpha: 0.6),
              ],
            ),
            border: Border.all(
              color: AppColors.glowRing.withValues(alpha: 0.45),
              width: 1.4,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A rounded, glowing text field with a glossy icon, lighting up when
/// focused.
class UtopiaTextField extends StatefulWidget {
  const UtopiaTextField({
    super.key,
    required this.controller,
    required this.icon,
    required this.hint,
    this.keyboardType,
    this.autofillHints,
    this.onSubmitted,
    this.prefixText,
    this.autofocus = false,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.enabled = true,
  });

  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final String? prefixText;
  final bool autofocus;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final bool enabled;

  @override
  State<UtopiaTextField> createState() => _UtopiaTextFieldState();
}

class _UtopiaTextFieldState extends State<UtopiaTextField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = _focus.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.fromLTRB(8, 4, 14, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.black.withValues(alpha: on ? 0.32 : 0.24),
        border: Border.all(
          color: on
              ? AppColors.goldBorderBright
              : Colors.white.withValues(alpha: 0.12),
          width: on ? 2 : 1.2,
        ),
        boxShadow: on
            ? [
                BoxShadow(
                  color: AppColors.goldBorderBright.withValues(alpha: 0.3),
                  blurRadius: 16,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          AnimatedScale(
            scale: on ? 1.08 : 1,
            duration: const Duration(milliseconds: 400),
            curve: Curves.elasticOut,
            child: GlossyBadge(
              icon: widget.icon,
              color: AppColors.accent,
              size: 38,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              autofocus: widget.autofocus,
              keyboardType: widget.keyboardType,
              autofillHints: widget.autofillHints,
              onSubmitted: widget.onSubmitted,
              inputFormatters: widget.inputFormatters,
              textCapitalization: widget.textCapitalization,
              enabled: widget.enabled,
              style: AppTextStyles.body(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                prefixText: widget.prefixText,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Digit tiles over one hidden field, for one-time codes. Calls
/// [onCompleted] once every tile is filled.
class CodeTilesInput extends StatefulWidget {
  const CodeTilesInput({
    super.key,
    required this.controller,
    required this.length,
    this.onCompleted,
  });

  final TextEditingController controller;
  final int length;
  final ValueChanged<String>? onCompleted;

  @override
  State<CodeTilesInput> createState() => _CodeTilesInputState();
}

class _CodeTilesInputState extends State<CodeTilesInput> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// Brings the keyboard up. If the field still has focus but the keyboard
  /// was put away (the back button, a swipe down), asking for focus does
  /// nothing, so ask the system to show the keyboard again instead.
  void _openKeyboard() {
    if (_focus.hasFocus) {
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    } else {
      _focus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;
    return GestureDetector(
      // The gaps between tiles count too.
      behavior: HitTestBehavior.opaque,
      onTap: _openKeyboard,
      child: Stack(
        children: [
          Opacity(
            opacity: 0,
            child: SizedBox(
              height: 10,
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                maxLength: widget.length,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) {
                  setState(() {});
                  if (v.length == widget.length) {
                    HapticFeedback.lightImpact();
                    widget.onCompleted?.call(v);
                  }
                },
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, c) {
              const gap = 6.0;
              final tile =
                  ((c.maxWidth - gap * (widget.length - 1)) / widget.length)
                      .clamp(24.0, 48.0);
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.length; i++) ...[
                    if (i > 0) const SizedBox(width: gap),
                    AnimatedScale(
                      scale: i < code.length ? 1 : 0.92,
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.elasticOut,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: tile,
                        height: tile * 1.25,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(tile * 0.3),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: i < code.length
                                ? [Colors.white, const Color(0xFFE9E2FF)]
                                : [
                                    Colors.white.withValues(alpha: 0.12),
                                    Colors.white.withValues(alpha: 0.06),
                                  ],
                          ),
                          border: Border.all(
                            color: _focus.hasFocus && i == code.length
                                ? AppColors.goldBorderBright
                                : Colors.white.withValues(alpha: 0.25),
                            width: _focus.hasFocus && i == code.length
                                ? 2.4
                                : 1.2,
                          ),
                        ),
                        child: Text(
                          i < code.length ? code[i] : '',
                          style: AppTextStyles.display(
                            fontSize: tile * 0.55,
                            color: AppColors.faceInk,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Fades and lifts its child in after [delay], for staggered entrances.
class RiseIn extends StatelessWidget {
  const RiseIn({super.key, required this.child, this.delay = 0});

  final Widget child;

  /// Seconds.
  final double delay;

  @override
  Widget build(BuildContext context) {
    final total = 700 + (delay * 1000).round();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      builder: (context, v, child) {
        final start = delay * 1000 / total;
        final p = ((v - start) / (1 - start)).clamp(0.0, 1.0);
        final e = Curves.easeOutBack.transform(p);
        return Opacity(
          opacity: p,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - e)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
