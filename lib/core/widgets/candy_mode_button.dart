import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'pop_card.dart';
import 'utopia_icons.dart';

/// One way to play (online, with friends, offline), as a card in the app's
/// own style rather than a loud banner: a glossy icon in the mode's colour,
/// a clear title and a line about what happens, and an arrow. The [primary]
/// mode is gently lit in its colour so the main choice stands out. Presses
/// sink a little, with a tap of feedback.
class CandyModeButton extends StatefulWidget {
  const CandyModeButton({
    super.key,
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
    this.subtitle,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;

  /// The mode's colour, light to deep (the icon and the highlight use it).
  final List<Color> colors;
  final VoidCallback onTap;
  final bool primary;

  @override
  State<CandyModeButton> createState() => _CandyModeButtonState();
}

class _CandyModeButtonState extends State<CandyModeButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.colors.last;
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: const Duration(milliseconds: 110),
          child: PopCard(
            borderRadius: 22,
            tint: widget.primary ? color : null,
            glow: widget.primary ? color : null,
            borderWidth: widget.primary ? 2 : 1.4,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              children: [
                GlossyBadge(icon: widget.icon, color: color, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.display(fontSize: 18),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.primary
                        ? color
                        : color.withValues(alpha: 0.16),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 24,
                    color: widget.primary ? Colors.white : color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
