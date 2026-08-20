import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color background = Color(0xFFF7F5EF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF2F5B46);
  static const Color primaryDark = Color(0xFF234333);
  static const Color primarySoft = Color(0xFFE6EEE8);
  static const Color accent = Color(0xFFB58A52);
  static const Color ink = Color(0xFF20271F);
  static const Color inkSoft = Color(0xFF70766F);
  static const Color divider = Color(0xFFE5E1D8);
  static const Color darkBackground = Color(0xFF101611);
  static const Color darkSurface = Color(0xFF18211B);
  static const Color darkCard = Color(0xFF202B23);
  static const Color darkPrimary = Color(0xFFA9C9B1);
  static const Color darkInk = Color(0xFFF2F0E8);
  static const List<Color> cardGradient = [Color(0xFFFFFEFA), Color(0xFFEAF1EA)];
  static const List<Color> darkCardGradient = [Color(0xFF27342B), Color(0xFF1B251E)];
}

class AppTheme {
  static TextTheme _textTheme(Color base, Color soft) => TextTheme(
        displaySmall: GoogleFonts.notoNaskhArabic(fontSize: 31, fontWeight: FontWeight.w700, color: base, height: 1.5),
        headlineMedium: GoogleFonts.notoNaskhArabic(fontSize: 26, fontWeight: FontWeight.w700, color: base, height: 1.55),
        headlineSmall: GoogleFonts.notoKufiArabic(fontSize: 20, fontWeight: FontWeight.w700, color: base, height: 1.4),
        titleLarge: GoogleFonts.notoKufiArabic(fontSize: 18, fontWeight: FontWeight.w700, color: base, height: 1.45),
        titleMedium: GoogleFonts.notoKufiArabic(fontSize: 14.5, fontWeight: FontWeight.w700, color: base, height: 1.45),
        bodyLarge: GoogleFonts.notoNaskhArabic(fontSize: 22, fontWeight: FontWeight.w500, color: base, height: 1.95),
        bodyMedium: GoogleFonts.notoKufiArabic(fontSize: 12.5, fontWeight: FontWeight.w400, color: soft, height: 1.8),
        labelLarge: GoogleFonts.notoKufiArabic(fontSize: 11.5, fontWeight: FontWeight.w700, color: base, height: 1.4),
        labelMedium: GoogleFonts.notoKufiArabic(fontSize: 10.5, fontWeight: FontWeight.w600, color: soft, height: 1.4),
      );

  static ThemeData _base({required bool dark}) {
    final background = dark ? AppColors.darkBackground : AppColors.background;
    final surface = dark ? AppColors.darkSurface : AppColors.surface;
    final primary = dark ? AppColors.darkPrimary : AppColors.primary;
    final ink = dark ? AppColors.darkInk : AppColors.ink;
    final soft = dark ? AppColors.darkInk.withValues(alpha: .68) : AppColors.inkSoft;

    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: (dark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
        primary: primary,
        onPrimary: dark ? AppColors.primaryDark : Colors.white,
        secondary: AppColors.accent,
        onSecondary: Colors.white,
        surface: surface,
      ),
      textTheme: _textTheme(ink, soft),
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.notoKufiArabic(fontSize: 17, fontWeight: FontWeight.w700, color: ink),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        height: 76,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        indicatorColor: dark ? AppColors.darkCard : AppColors.primarySoft,
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.notoKufiArabic(fontSize: 10, fontWeight: FontWeight.w700, color: ink),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: dark ? AppColors.darkCard : AppColors.ink,
        contentTextStyle: GoogleFonts.notoKufiArabic(fontSize: 12.5, color: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? AppColors.darkSurface : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: GoogleFonts.notoKufiArabic(fontSize: 12, color: soft),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: dark ? Colors.white12 : AppColors.divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: primary, width: 1.2)),
      ),
      dividerColor: dark ? Colors.white12 : AppColors.divider,
    );
  }

  static ThemeData get light => _base(dark: false);
  static ThemeData get dark => _base(dark: true);
}
