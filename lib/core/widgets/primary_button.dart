import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'utopia_loader.dart';

/// Full-width primary action button, styled as a gold-rimmed 3D pill — a
/// bright gradient fill sitting on a darker offset shadow of the same
/// color, wrapped in a bold gold ring, flattening down when pressed for a
/// tactile click. Matches PopCard's "royal panel" language so buttons and
/// cards read as one coherent theme.
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  /// Fill color. Defaults to the brand violet.
  final Color? color;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  static const double _depth = 5;

  @override
  Widget build(BuildContext context) {
    final fill = widget.color ?? AppColors.accent;
    final shade = AppColors.depthShade(fill);
    final lighter = Color.lerp(fill, Colors.white, 0.28)!;

    return GestureDetector(
      onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.onPressed,
      child: AnimatedOpacity(
        opacity: _enabled ? 1.0 : 0.5,
        duration: const Duration(milliseconds: 150),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          margin: EdgeInsets.only(
            top: _pressed ? _depth : 0,
            bottom: _pressed ? 0 : _depth,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: AppColors.goldBorder, width: 2.2),
            boxShadow: _pressed
                ? null
                : [BoxShadow(color: shade, offset: const Offset(0, _depth))],
          ),
          child: Container(
            width: double.infinity,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [lighter, fill],
                stops: const [0.0, 0.7],
              ),
            ),
            child: widget.isLoading
                ? const UtopiaLoader(size: 18, bubbles: false)
                : Text(
                    widget.label,
                    style:
                        AppTextStyles.body(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ).copyWith(
                          shadows: const [
                            Shadow(
                              color: Colors.black38,
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                  ),
          ),
        ),
      ),
    );
  }
}
