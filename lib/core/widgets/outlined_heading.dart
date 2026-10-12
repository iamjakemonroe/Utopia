import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';

/// Bold text with a dark stroked outline behind the fill — the "game show
/// lettering" look from the reference screenshots (thick outlined type on
/// logos and section headers). Built from two stacked [Text] widgets: a
/// back layer painted as a stroke only, and a normal filled layer on top.
class OutlinedHeading extends StatelessWidget {
  const OutlinedHeading(
    this.text, {
    super.key,
    this.fontSize = 40,
    this.fillColor = Colors.white,
    this.outlineColor = const Color(0xFF15102E),
    this.strokeWidth = 6,
    this.textAlign,
  });

  final String text;
  final double fontSize;
  final Color fillColor;
  final Color outlineColor;
  final double strokeWidth;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final base = AppTextStyles.display(fontSize: fontSize, color: fillColor);
    return Stack(
      children: [
        Text(
          text,
          textAlign: textAlign,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..color = outlineColor,
          ),
        ),
        Text(text, textAlign: textAlign, style: base),
      ],
    );
  }
}
