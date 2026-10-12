import 'package:flutter/material.dart';

import 'utopia_themes.dart';

/// The app's color tokens. The structural ones (background, surfaces, the
/// brand accent, rims and glows) follow the active [UtopiaTheme], so
/// switching themes recolors every screen built from these tokens. The game
/// colors (mint, coral, sky), status colors and text stay fixed across
/// themes so gameplay and legibility never depend on the theme.
///
/// Because the themed tokens are getters, they can't appear inside `const`
/// expressions: widgets using them rebuild with the theme instead.
class AppColors {
  AppColors._();

  static UtopiaTheme get _theme => UtopiaThemes.active;

  static Color get background => _theme.background;
  static Color get surface => _theme.surface;
  static Color get surfaceElevated => _theme.surfaceElevated;

  /// The theme's primary color (violet in the default theme).
  static Color get accent => _theme.accent;

  /// Coins, rewards and the rim trim (bold gold in the default theme).
  static Color get accentSecondary => _theme.trim;

  static const Color mint = Color(0xFF2DE0C2);
  static const Color coral = Color(0xFFFF7A7A);
  static const Color sky = Color(0xFF5AB8FF);

  static const Color success = Color(0xFF3DDC84);
  static const Color error = Color(0xFFFF5A5F);

  static Color get textPrimary => _theme.textPrimary;

  /// Whether the active world is a light one (dark text on light paper).
  static bool get light => _theme.light;

  /// Text and icons on an accent fill (a selected chip, a filled button):
  /// white on a dark accent like Doodle's ink, dark ink on a pale one.
  static Color get onAccent =>
      accent.computeLuminance() > 0.5 ? const Color(0xFF1B1433) : Colors.white;
  static Color get textSecondary => _theme.textSecondary;

  // ── "royal card" tokens ───────────────────────────────────────────────
  // PopCard's border is the theme trim; the inner glow ring is a soft line
  // just inside it in the theme's glow color.
  static Color get goldBorder => _theme.trim;
  static Color get goldBorderBright => _theme.trimBright;
  static Color get glowRing => _theme.glowRing;

  /// Depth-shadow base, the darkest ink in the palette.
  static Color get cardOutline => _theme.cardOutline;

  /// The coin itself is always gold, whatever the theme's rim color.
  static const Color coinGold = Color(0xFFFFC94D);
  static const Color coinGoldBright = Color(0xFFFFE29A);

  /// Fixed dark ink for facial features on light/gold shapes (e.g. Chip
  /// the mascot's eyes/mouth) — independent of the theme so a face always
  /// reads dark-on-gold.
  static const Color faceInk = Color(0xFF241C3B);

  /// Darkens [color] for the offset "3D depth" shadow beneath a card or
  /// button — same hue, not a generic gray/black, so the depth shadow
  /// reads as part of the object instead of a separate drop shadow.
  static Color depthShade(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0)).toColor();
  }
}
