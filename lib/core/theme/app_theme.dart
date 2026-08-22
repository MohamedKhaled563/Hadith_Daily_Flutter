import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    fontFamily: GoogleFonts.tajawal().fontFamily,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primaryGreen,
      secondary: AppColors.gold,
      surface: AppColors.card,
    ),
    textTheme: GoogleFonts.tajawalTextTheme().copyWith(
      headlineLarge: AppTextStyles.screenTitle,
      titleLarge: AppTextStyles.sectionTitle,
      bodyLarge: AppTextStyles.hadithText,
      bodyMedium: AppTextStyles.explanationText,
      bodySmall: AppTextStyles.smallText,
    ),
  );
}
