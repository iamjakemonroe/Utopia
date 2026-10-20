import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../l10n/strings.dart';

/// Decline and Accept (or Play) side by side, always the same height so they
/// line up. [compact] makes small pills that sit at the end of a row;
/// otherwise the two share the full width.
class AnswerButtons extends StatelessWidget {
  const AnswerButtons({
    super.key,
    required this.onDecline,
    required this.onAccept,
    this.acceptLabel,
    this.busy = false,
    this.compact = false,
  });

  final VoidCallback onDecline;

  /// Null keeps Accept off (a challenge whose sender stepped away).
  final VoidCallback? onAccept;

  /// "Accept" unless it says.
  final String? acceptLabel;
  final bool busy;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 34.0 : 40.0;
    final decline = _AnswerButton(
      label: strings.answerButtonsDecline,

      height: height,
      compact: compact,
      fill: (AppColors.light ? Colors.black : Colors.white).withValues(
        alpha: AppColors.light ? 0.04 : 0.1,
      ),
      border: (AppColors.light ? Colors.black : Colors.white).withValues(
        alpha: AppColors.light ? 0.25 : 0.22,
      ),
      textColor: AppColors.textSecondary,
      onTap: busy ? null : onDecline,
    );
    final accept = _AnswerButton(
      label: acceptLabel ?? strings.answerButtonsAccept,

      height: height,
      compact: compact,
      fill: AppColors.success,
      border: AppColors.success,
      textColor: Colors.white,
      busy: busy,
      onTap: busy ? null : onAccept,
    );
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [decline, const SizedBox(width: 6), accept],
      );
    }
    return Row(
      children: [
        Expanded(child: decline),
        const SizedBox(width: 8),
        Expanded(child: accept),
      ],
    );
  }
}

class _AnswerButton extends StatefulWidget {
  const _AnswerButton({
    required this.label,
    required this.height,
    required this.compact,
    required this.fill,
    required this.border,
    required this.textColor,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final double height;
  final bool compact;
  final Color fill;
  final Color border;
  final Color textColor;
  final VoidCallback? onTap;
  final bool busy;

  @override
  State<_AnswerButton> createState() => _AnswerButtonState();
}

class _AnswerButtonState extends State<_AnswerButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.94 : 1,
          duration: const Duration(milliseconds: 110),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: enabled || widget.busy ? 1 : 0.5,
            child: Container(
              height: widget.height,
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 12 : 14,
              ),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.fill,
                borderRadius: BorderRadius.circular(widget.height / 2.6),
                border: Border.all(color: widget.border, width: 1.2),
              ),
              child: widget.busy
                  ? SizedBox.square(
                      dimension: widget.compact ? 15 : 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: widget.textColor,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // On a very narrow screen (or with big text) it
                        // ends in "…" rather than running out of its button.
                        Flexible(
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.body(
                              fontSize: widget.compact ? 12.5 : 14,
                              fontWeight: FontWeight.w900,
                              color: widget.textColor,
                            ),
                          ),
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
