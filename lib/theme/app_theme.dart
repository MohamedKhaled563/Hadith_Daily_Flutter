import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette matched to the "رسالة اليوم" reference mockup:
/// warm cream background, sage/forest green for text & accents,
/// soft mint-cream card surface. No gold, no dark navy — keep it
/// light and airy like the reference, not "heavy religious" styling.
class AppColors {
  static const Color background = Color(0xFFF6F1E7); // warm cream
  static const Color cardTop = Color(0xFFF3EEE3); // card gradient start
  static const Color cardBottom = Color(0xFFE7EEE1); // card gradient end (mint)
  static const Color primary = Color(0xFF3C6B4A); // forest/sage green (headlines, icons)
  static const Color primarySoft = Color(0xFF6E8F73); // secondary green (subtitles)
  static const Color ink = Color(0xFF2B2B25);
  static const Color inkSoft = Color(0xFF7A7A6E);
  static const Color divider = Color(0xFFE1DACB);
  static const Color heart = Color(0xFFD97D6C); // warm coral for the heart icon

  static const Color darkBackground = Color(0xFF15201A);
  static const Color darkCard = Color(0xFF1E2B22);
  static const Color darkPrimary = Color(0xFF8FC49A);
  static const Color darkInk = Color(0xFFEDEAE0);
}

class AppTheme {
  static TextTheme _textTheme(Color ink, Color soft, Color primary) {
    return TextTheme(
      // Big screen title e.g. "رسالة اليوم"
      displaySmall: GoogleFonts.notoKufiArabic(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: primary,
      ),
      // Hadith body text inside the card
      bodyLarge: GoogleFonts.notoNaskhArabic(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: ink,
        height: 1.7,
      ),
      // Small footer line ("من حديث: ...")
      bodyMedium: GoogleFonts.notoKufiArabic(
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        color: soft,
        height: 1.6,
      ),
      // Action button labels (احفظ / شارك / ...)
      labelLarge: GoogleFonts.notoKufiArabic(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleLarge: GoogleFonts.notoKufiArabic(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      titleMedium: GoogleFonts.notoKufiArabic(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
    );
  }

  static ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.heart,
      surface: AppColors.cardTop,
    ),
    textTheme: _textTheme(AppColors.ink, AppColors.inkSoft, AppColors.primary),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      centerTitle: true,
      iconTheme: const IconThemeData(color: AppColors.primary),
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
    colorScheme: ColorScheme.dark(
      primary: AppColors.darkPrimary,
      secondary: AppColors.heart,
      surface: AppColors.darkCard,
    ),
    textTheme: _textTheme(
      AppColors.darkInk,
      AppColors.darkInk.withOpacity(0.65),
      AppColors.darkPrimary,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.darkBackground,
      elevation: 0,
      centerTitle: true,
      iconTheme: const IconThemeData(color: AppColors.darkPrimary),
      titleTextStyle: GoogleFonts.notoKufiArabic(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.darkInk,
      ),
    ),
    dividerColor: Colors.white12,
  );
}
