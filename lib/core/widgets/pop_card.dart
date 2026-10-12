import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The trim for a bottom drawer: top, left and right only. A drawer runs
/// off the bottom of the screen, so a line along its bottom edge looks
/// wrong. Pair it with top-only rounded corners.
Border sheetBorder(Color color, {double width = 1.5}) {
  final side = BorderSide(color: color, width: width);
  return Border(top: side, left: side, right: side);
}

/// Top corners rounded, bottom square, for a drawer.
BorderRadius sheetRadius([double radius = 30]) =>
    BorderRadius.vertical(top: Radius.circular(radius));

/// The app's core "royal panel" surface: a dark violet card with a bold
/// gold outer border, a soft violet glow ring just inside it, and an
/// offset drop-shadow in a darker shade beneath — reads as a chunky,
/// slightly regal game-UI panel (mobile board-game apps like Ludo King use
/// this exact gold-trim-on-dark language) rather than a flat rectangle.
/// Every card, sheet, and dialog in the app should be built from this.
class PopCard extends StatelessWidget {
  const PopCard({
    super.key,
    required this.child,
    this.borderRadius = 22,
    this.padding,
    this.tint,

    /// Accent glow color — used for state highlights (gold on "your turn",
    /// green on a win, red on check/loss). Null keeps the default violet
    /// glow ring.
    this.glow,
    this.borderWidth = 2.5,
    this.depth = 5,

    // Accepted for call-site compatibility with earlier redesigns of this
    // widget; unused in this version.
    this.blur,

    /// A bottom drawer: only the top corners round, the trim stops at the
    /// bottom edge, and there's no drop shadow underneath.
    this.sheet = false,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? tint;
  final Color? glow;
  final double borderWidth;
  final double depth;
  final double? blur;
  final bool sheet;

  @override
  Widget build(BuildContext context) {
    final fill = tint == null
        ? AppColors.surface
        : Color.alphaBlend(tint!.withValues(alpha: 0.22), AppColors.surface);
    final shade = AppColors.depthShade(fill);
    final ringColor = glow ?? AppColors.glowRing;
    final inner = (borderRadius - borderWidth).clamp(0.0, borderRadius);
    final radius = sheet
        ? sheetRadius(borderRadius)
        : BorderRadius.circular(borderRadius);
    final innerRadius = sheet
        ? sheetRadius(inner)
        : BorderRadius.circular(inner);
    final ring = ringColor.withValues(alpha: 0.5);

    return Container(
      margin: EdgeInsets.only(bottom: sheet ? 0 : depth),
      decoration: BoxDecoration(
        borderRadius: radius,
        // Bold gold outer trim — the theme's signature.
        border: sheet
            ? sheetBorder(AppColors.goldBorder, width: borderWidth)
            : Border.all(color: AppColors.goldBorder, width: borderWidth),
        boxShadow: [
          if (!sheet) BoxShadow(color: shade, offset: Offset(0, depth)),
          BoxShadow(
            color: ringColor.withValues(alpha: 0.35),
            blurRadius: 14,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Container(
        margin: sheet
            ? const EdgeInsets.fromLTRB(1.5, 1.5, 1.5, 0)
            : const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          borderRadius: innerRadius,
          // Soft inner glow ring, just inside the gold trim.
          border: sheet
              ? sheetBorder(ring, width: 1.2)
              : Border.all(color: ring, width: 1.2),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.alphaBlend(Colors.white.withValues(alpha: 0.06), fill),
              fill,
            ],
          ),
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}
