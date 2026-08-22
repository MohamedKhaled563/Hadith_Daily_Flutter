import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    fontFamily: 'Tajawal',
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primaryGreen,
      secondary: AppColors.gold,
      surface: AppColors.card,
    ),
    textTheme: const TextTheme(
      headlineLarge: AppTextStyles.screenTitle,
      titleLarge: AppTextStyles.sectionTitle,
      bodyLarge: AppTextStyles.hadithText,
      bodyMedium: AppTextStyles.explanationText,
      bodySmall: AppTextStyles.smallText,
    ),
  );
}
