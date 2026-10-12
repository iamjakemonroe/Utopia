import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/art_doc.dart';

/// The studio's ink and paper (the Doodle world's own).
const kStudioInk = Color(0xFF1F1E1B);
const kStudioPaper = Color(0xFFFFFDF7);
const kStudioDesk = Color(0xFFF1ECE1);

/// The colors to draw and paint with.
const kArtPalette = <int>[
  0xFF1F1E1B, // ink
  0xFF5F5A50, // graphite
  0xFFFFFFFF, // white
  0xFFFF5A5F, // red
  0xFFFF8A3D, // orange
  0xFFFFC94D, // gold
  0xFFFFE66D, // lemon
  0xFF9BE15D, // lime
  0xFF3DDC84, // green
  0xFF2DE0C2, // mint
  0xFF5AB8FF, // sky
  0xFF2F7BFF, // blue
  0xFF7C4DFF, // violet
  0xFFB27BFF, // lilac
  0xFFFF6FB8, // pink
  0xFFFF3D9A, // magenta
  0xFF8D5A3B, // brown
  0xFFD9A066, // tan
  0xFFFFD7B5, // peach
  0xFFC68642, // caramel
  0xFF6B4226, // cocoa
  0xFFE9F4FF, // ice
];

/// Brush sizes, in page units, smallest to biggest.
const kBrushSizes = <double>[3, 6, 10, 16, 26];

extension ArtToolLook on ArtTool {
  String get label => switch (this) {
    ArtTool.pencil => 'Pencil',
    ArtTool.pen => 'Ink pen',
    ArtTool.marker => 'Marker',
    ArtTool.soft => 'Soft brush',
    ArtTool.highlighter => 'Highlighter',
    ArtTool.eraser => 'Eraser',
    ArtTool.bucket => 'Paint bucket',
  };

  IconData? get icon => switch (this) {
    ArtTool.pencil => Icons.edit_rounded,
    ArtTool.pen => Icons.draw_rounded,
    ArtTool.marker => Icons.brush_rounded,
    ArtTool.soft => Icons.blur_on_rounded,
    ArtTool.highlighter => Icons.border_color_rounded,
    ArtTool.eraser => null,
    ArtTool.bucket => Icons.format_color_fill_rounded,
  };

  /// Whether the tool uses the color and size pickers.
  bool get usesColor => this != ArtTool.eraser;
  bool get usesSize => this != ArtTool.bucket;
}

/// A round paper button with an ink outline that sinks a little when
/// pressed and pops up, inked in, when [selected].
class StudioButton extends StatefulWidget {
  const StudioButton({
    super.key,
    required this.onTap,
    required this.tooltip,
    this.icon,
    this.child,
    this.selected = false,
    this.enabled = true,
    this.size = 46,
  });

  final VoidCallback onTap;
  final String tooltip;
  final IconData? icon;
  final Widget? child;
  final bool selected;
  final bool enabled;
  final double size;

  @override
  State<StudioButton> createState() => _StudioButtonState();
}

class _StudioButtonState extends State<StudioButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.selected;
    final fg = on ? kStudioPaper : kStudioInk;
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        selected: on,
        enabled: widget.enabled,
        label: widget.tooltip,
        child: GestureDetector(
          onTapDown: widget.enabled
              ? (_) => setState(() => _down = true)
              : null,
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: widget.enabled
              ? () {
                  HapticFeedback.selectionClick();
                  widget.onTap();
                }
              : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: widget.enabled ? 1 : 0.32,
            child: AnimatedScale(
              scale: _down ? 0.88 : (on ? 1.1 : 1),
              duration: Duration(milliseconds: _down ? 90 : 420),
              curve: _down ? Curves.easeOut : Curves.elasticOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on ? kStudioInk : kStudioPaper,
                  border: Border.all(color: kStudioInk, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: kStudioInk.withValues(alpha: on ? 0.28 : 0.12),
                      offset: Offset(0, on ? 4 : 2),
                      blurRadius: on ? 8 : 3,
                    ),
                  ],
                ),
                child: Center(
                  child: IconTheme(
                    data: IconThemeData(color: fg, size: widget.size * 0.46),
                    child: widget.child ?? Icon(widget.icon),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An eraser, drawn: a tilted block with a band round it.
class EraserGlyph extends StatelessWidget {
  const EraserGlyph({super.key});

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color ?? kStudioInk;
    final size = IconTheme.of(context).size ?? 22;
    return CustomPaint(size: Size.square(size), painter: _EraserPainter(color));
  }
}

class _EraserPainter extends CustomPainter {
  _EraserPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.translate(s / 2, s / 2);
    canvas.rotate(-0.7);
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: s * 0.95, height: s * 0.48),
      Radius.circular(s * 0.1),
    );
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.09
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    canvas.drawRRect(body, line);
    canvas.drawRect(
      Rect.fromLTRB(-s * 0.47, -s * 0.24, -s * 0.05, s * 0.24),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_EraserPainter old) => old.color != color;
}

/// The tools, in a row (phones) or a column (tablets).
class ToolPicker extends StatelessWidget {
  const ToolPicker({
    super.key,
    required this.tools,
    required this.selected,
    required this.onChanged,
    this.axis = Axis.horizontal,
  });

  final List<ArtTool> tools;
  final ArtTool selected;
  final ValueChanged<ArtTool> onChanged;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // In a row, the buttons shrink to fit the width (down to a size
        // still easy to tap) rather than scroll.
        final room = axis == Axis.horizontal
            ? (constraints.maxWidth - 8) / tools.length - 8
            : 46.0;
        final size = room.clamp(36.0, 46.0);
        final buttons = [
          for (final t in tools)
            Padding(
              padding: const EdgeInsets.all(4),
              child: StudioButton(
                tooltip: t.label,
                icon: t.icon,
                size: size,
                selected: t == selected,
                onTap: () => onChanged(t),
                child: t.icon == null ? const EraserGlyph() : null,
              ),
            ),
        ];
        return SingleChildScrollView(
          scrollDirection: axis,
          padding: const EdgeInsets.all(4),
          child: Flex(
            direction: axis,
            mainAxisSize: MainAxisSize.min,
            children: buttons,
          ),
        );
      },
    );
  }
}

/// The color swatches.
class ColorPicker extends StatelessWidget {
  const ColorPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    this.axis = Axis.horizontal,
    this.columns = 2,
  });

  final int selected;
  final ValueChanged<int> onChanged;
  final bool enabled;
  final Axis axis;

  /// Tablets: how many swatches across.
  final int columns;

  @override
  Widget build(BuildContext context) {
    Widget swatch(int c) => _Swatch(
      color: Color(c),
      selected: c == selected,
      onTap: () => onChanged(c),
    );
    final body = axis == Axis.horizontal
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                for (final c in kArtPalette)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: swatch(c),
                  ),
              ],
            ),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final c in kArtPalette) swatch(c)],
            ),
          );
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: enabled ? 1 : 0.3,
      child: IgnorePointer(ignoring: !enabled, child: body),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Color',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedScale(
          scale: selected ? 1.18 : 1,
          duration: const Duration(milliseconds: 420),
          curve: Curves.elasticOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(color: kStudioInk, width: selected ? 3 : 1.5),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
            child: selected
                ? Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.computeLuminance() > 0.5
                            ? kStudioInk
                            : kStudioPaper,
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// Brush sizes as dots, smallest to biggest.
class SizePicker extends StatelessWidget {
  const SizePicker({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.color,
    this.enabled = true,
    this.axis = Axis.horizontal,
  });

  final int selected;
  final ValueChanged<int> onChanged;
  final Color color;
  final bool enabled;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: enabled ? 1 : 0.3,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Flex(
          direction: axis,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < kBrushSizes.length; i++)
              Semantics(
                button: true,
                selected: i == selected,
                label: 'Brush size ${i + 1}',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(i);
                  },
                  child: SizedBox.square(
                    dimension: 40,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutBack,
                        width: 7 + i * 5.0,
                        height: 7 + i * 5.0,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == selected
                              ? color
                              : kStudioInk.withValues(alpha: 0.18),
                          border: i == selected
                              ? Border.all(color: kStudioInk, width: 2)
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
