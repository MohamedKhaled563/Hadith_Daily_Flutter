import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central place for all colors, gradients and text styles.
/// Palette: warm sage green + deep ink + soft cream background —
/// calm, "Islamic app" feel without being cliché (no generic gold/teal).
class AppColors {
  static const Color background = Color(0xFFF7F4EE); // warm cream
  static const Color surface = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF3F6250); // deep sage green
  static const Color primaryLight = Color(0xFFDCE7DC); // pale sage
  static const Color accent = Color(0xFFB98B4E); // muted gold accent
  static const Color ink = Color(0xFF23291F); // near-black warm ink
  static const Color inkSoft = Color(0xFF5A5F55);
  static const Color divider = Color(0xFFE4DFD3);

  static const Color darkBackground = Color(0xFF161C17);
  static const Color darkSurface = Color(0xFF1F281F);
  static const Color darkPrimary = Color(0xFF8FB89B);
  static const Color darkInk = Color(0xFFEDEAE0);

  static const List<Color> cardGradient = [
    Color(0xFFEFEAE0),
    Color(0xFFE1E9DE),
  ];
}

class AppTheme {
  // Arabic serif-ish look for hadith text, clean sans for UI chrome.
  static TextTheme _textTheme(Color base, Color soft) {
    return TextTheme(
      headlineMedium: GoogleFonts.notoNaskhArabic(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: base,
        height: 1.5,
      ),
      titleLarge: GoogleFonts.notoKufiArabic(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: base,
      ),
      titleMedium: GoogleFonts.notoKufiArabic(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: base,
      ),
      bodyLarge: GoogleFonts.notoNaskhArabic(
        fontSize: 19,
        fontWeight: FontWeight.w500,
        color: base,
        height: 1.9,
      ),
      bodyMedium: GoogleFonts.notoKufiArabic(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: soft,
        height: 1.7,
      ),
      labelLarge: GoogleFonts.notoKufiArabic(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: base,
      ),
    );
  }

  static ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
    ),
    textTheme: _textTheme(AppColors.ink, AppColors.inkSoft),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      centerTitle: true,
      iconTheme: const IconThemeData(color: AppColors.ink),
      titleTextStyle: GoogleFonts.notoKufiArabic(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
    ),
    dividerColor: AppColors.divider,
  );

  static ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.darkPrimary,
      secondary: AppColors.accent,
      surface: AppColors.darkSurface,
    ),
    textTheme:
        _textTheme(AppColors.darkInk, AppColors.darkInk.withValues(alpha: 0.7)),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.darkBackground,
      elevation: 0,
      centerTitle: true,
      iconTheme: const IconThemeData(color: AppColors.darkInk),
      titleTextStyle: GoogleFonts.notoKufiArabic(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.darkInk,
      ),
    ),
    dividerColor: Colors.white12,
  );
}
