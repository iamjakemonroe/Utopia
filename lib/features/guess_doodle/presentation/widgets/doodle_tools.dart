import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../doodle_studio/domain/art_doc.dart';
import '../../../../l10n/strings.dart';

/// The drawer's colors: the basics, plus skin tones and browns that come
/// up all the time (faces, food, animals).
const kDoodleColors = [
  0xFF1F1E1B,
  0xFF8E8A80,
  0xFFFFFFFF,
  0xFFE53935,
  0xFFFF8F1F,
  0xFFFFD233,
  0xFF2FB34A,
  0xFF1B6E37,
  0xFF39B6F0,
  0xFF2B59D9,
  0xFF7B4BD8,
  0xFFFF6FAE,
  0xFF8B5A2B,
  0xFFF2C29B,
  0xFFB97A50,
  0xFF5C3A21,
];

/// Brush sizes, in page units.
const kDoodleSizes = [5.0, 12.0, 24.0, 44.0];

/// What the drawer has picked up.
class DoodlePen {
  const DoodlePen({
    this.color = 0xFF1F1E1B,
    this.size = 12,
    this.erasing = false,
  });

  final int color;
  final double size;
  final bool erasing;

  ArtTool get tool => erasing ? ArtTool.eraser : ArtTool.marker;

  DoodlePen copyWith({int? color, double? size, bool? erasing}) => DoodlePen(
    color: color ?? this.color,
    size: size ?? this.size,
    erasing: erasing ?? this.erasing,
  );
}

/// The drawer's tray: a row of colors, then sizes, the eraser, undo and
/// clear. Picking a color puts the pen back in hand.
class DoodleTools extends StatelessWidget {
  const DoodleTools({
    super.key,
    required this.pen,
    required this.onPen,
    required this.canUndo,
    required this.onUndo,
    required this.onClear,
  });

  final DoodlePen pen;
  final ValueChanged<DoodlePen> onPen;
  final bool canUndo;
  final VoidCallback onUndo;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Two even rows of eight.
          LayoutBuilder(
            builder: (context, c) {
              const perRow = 8;
              final dot = ((c.maxWidth - (perRow - 1) * 6) / perRow).clamp(
                20.0,
                28.0,
              );
              return Column(
                children: [
                  for (var row = 0; row < kDoodleColors.length; row += perRow)
                    Padding(
                      padding: EdgeInsets.only(top: row == 0 ? 0 : 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (final color
                              in kDoodleColors.skip(row).take(perRow))
                            _Swatch(
                              color: Color(color),
                              size: dot,
                              selected: !pen.erasing && pen.color == color,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                onPen(
                                  pen.copyWith(color: color, erasing: false),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final size in kDoodleSizes)
                _SizeDot(
                  size: size,
                  color: pen.erasing ? Colors.white : Color(pen.color),
                  selected: pen.size == size,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onPen(pen.copyWith(size: size));
                  },
                ),
              const Spacer(),
              _ToolButton(
                glyph: const _EraserGlyph(),
                label: strings.doodleToolsEraser,
                selected: pen.erasing,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onPen(pen.copyWith(erasing: !pen.erasing));
                },
              ),
              _ToolButton(
                icon: Icons.undo_rounded,
                label: strings.doodleToolsUndo,
                onTap: canUndo ? onUndo : null,
              ),
              _ToolButton(
                icon: Icons.delete_sweep_rounded,
                label: strings.doodleToolsClear,
                onTap: canUndo ? onClear : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final double size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.12 : 1,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: selected
                  ? AppColors.goldBorderBright
                  : Colors.white.withValues(alpha: 0.35),
              width: selected ? 3 : 1.5,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.6),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}

class _SizeDot extends StatelessWidget {
  const _SizeDot({
    required this.size,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final double size;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 38,
        height: 38,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? AppColors.goldBorderBright
                : Colors.white.withValues(alpha: 0.15),
            width: selected ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 4 + size * 0.5,
          height: 4 + size * 0.5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: color.computeLuminance() > 0.85
                ? Border.all(color: Colors.black26)
                : null,
          ),
        ),
      ),
    );
  }
}

/// An eraser, drawn (there's no eraser among the icons): a tilted block,
/// pink on top of a white sleeve.
class _EraserGlyph extends StatelessWidget {
  const _EraserGlyph();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.6,
      child: Container(
        width: 12,
        height: 22,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: Colors.white, width: 1.6),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.5, 0.5],
            colors: [Color(0xFFFF8FB8), Colors.white],
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    this.icon,
    this.glyph,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData? icon;

  /// Drawn instead of [icon].
  final Widget? glyph;
  final String label;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 40,
          height: 40,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected
                ? AppColors.accent
                : Colors.white.withValues(alpha: enabled ? 0.12 : 0.05),
            border: Border.all(
              color: selected
                  ? AppColors.goldBorderBright
                  : Colors.white.withValues(alpha: 0.15),
            ),
          ),
          child: Center(
            child:
                glyph ??
                Icon(
                  icon,
                  size: 22,
                  color: Colors.white.withValues(alpha: enabled ? 1 : 0.35),
                ),
          ),
        ),
      ),
    );
  }
}
