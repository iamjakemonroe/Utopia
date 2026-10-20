import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Centralized text styles. [display] uses a distinct display font to give
/// headings/balances more visual weight than the default body font.
class AppTextStyles {
  AppTextStyles._();

  /// [color] defaults to the theme's text color.
  static TextStyle display({
    double fontSize = 32,
    FontWeight fontWeight = FontWeight.w800,
    Color? color,
  }) => GoogleFonts.spaceGrotesk(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color ?? AppColors.textPrimary,
  );

  /// Starts loading every weight the app uses (each font file loads the
  /// first time its weight is asked for). Called as the app starts: a
  /// font arriving lays out all the text on screen again, which then
  /// happened as a screen opened (notifications, the first time, waited
  /// on its titles' weight). Over the splash, there's next to no text.
  static void preloadFonts() {
    for (final w in const [
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
      FontWeight.w800,
      FontWeight.w900,
    ]) {
      GoogleFonts.inter(fontWeight: w);
    }
    for (final w in const [
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
    ]) {
      GoogleFonts.spaceGrotesk(fontWeight: w);
    }
  }

  static TextStyle body({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
  }) => GoogleFonts.inter(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color ?? AppColors.textPrimary,
  );
}
