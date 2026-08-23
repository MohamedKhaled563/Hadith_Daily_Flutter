import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: GoogleFonts.tajawal().fontFamily,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primaryGreen,
      secondary: AppColors.gold,
      surface: AppColors.card,
      onPrimary: Colors.white,
      onSurface: AppColors.primaryText,
    ),
    textTheme: GoogleFonts.tajawalTextTheme().copyWith(
      headlineLarge: AppTextStyles.screenTitle,
      titleLarge: AppTextStyles.sectionTitle,
      bodyLarge: AppTextStyles.hadithText,
      bodyMedium: AppTextStyles.explanationText,
      bodySmall: AppTextStyles.smallText,
    ),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: GoogleFonts.tajawal().fontFamily,
    scaffoldBackgroundColor: AppColors.backgroundDark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryGreenDark,
      secondary: AppColors.gold,
      surface: AppColors.cardDark,
      onPrimary: AppColors.backgroundDark,
      onSurface: AppColors.primaryTextDark,
    ),
    textTheme: GoogleFonts.tajawalTextTheme(ThemeData.dark().textTheme).copyWith(
      headlineLarge: AppTextStyles.screenTitle.copyWith(color: AppColors.primaryTextDark),
      titleLarge: AppTextStyles.sectionTitle.copyWith(color: AppColors.primaryTextDark),
      bodyLarge: AppTextStyles.hadithText.copyWith(color: AppColors.primaryTextDark),
      bodyMedium: AppTextStyles.explanationText.copyWith(color: AppColors.secondaryTextDark),
      bodySmall: AppTextStyles.smallText.copyWith(color: AppColors.secondaryTextDark),
    ),
  );
}
