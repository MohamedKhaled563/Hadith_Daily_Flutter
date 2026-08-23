import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_palette.dart';
import 'app_text_styles.dart';

class AppTheme {
  static ThemeData get light => _base(
    brightness: Brightness.light,
    palette: BotanicalPalette.light,
    scaffold: AppColors.background,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primaryGreen,
      secondary: AppColors.gold,
      surface: AppColors.card,
      onPrimary: Colors.white,
      onSurface: AppColors.primaryText,
    ),
    bodyColor: AppColors.primaryText,
    mutedColor: AppColors.secondaryText,
  );

  static ThemeData get dark => _base(
    brightness: Brightness.dark,
    palette: BotanicalPalette.dark,
    scaffold: AppColors.backgroundDark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryGreenDark,
      secondary: AppColors.goldTextDark,
      surface: AppColors.cardDark,
      onPrimary: AppColors.backgroundDark,
      onSurface: AppColors.primaryTextDark,
    ),
    bodyColor: AppColors.primaryTextDark,
    mutedColor: AppColors.secondaryTextDark,
  );

  static ThemeData _base({
    required Brightness brightness,
    required BotanicalPalette palette,
    required Color scaffold,
    required ColorScheme colorScheme,
    required Color bodyColor,
    required Color mutedColor,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: kSans,
      scaffoldBackgroundColor: scaffold,
      colorScheme: colorScheme,
      extensions: [palette],
      splashFactory: InkSparkle.splashFactory,
      textTheme: TextTheme(
        headlineLarge: AppTextStyles.screenTitle.copyWith(color: bodyColor),
        headlineMedium: AppTextStyles.screenTitle.copyWith(
          fontSize: 24,
          color: bodyColor,
        ),
        titleLarge: AppTextStyles.sectionTitle.copyWith(color: bodyColor),
        titleMedium: AppTextStyles.screenTitle.copyWith(
          fontSize: 17,
          color: bodyColor,
        ),
        bodyLarge: AppTextStyles.hadithText.copyWith(color: bodyColor),
        bodyMedium: AppTextStyles.explanationText.copyWith(color: bodyColor),
        bodySmall: AppTextStyles.smallText.copyWith(color: mutedColor),
        labelLarge: AppTextStyles.buttonText,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: brightness == Brightness.dark
            ? AppColors.secondaryCardDark
            : AppColors.primaryGreen,
        contentTextStyle: const TextStyle(
          fontFamily: kSans,
          fontSize: 14,
          height: AppLeading.body,
          color: Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.listItem),
        ),
      ),
    );
  }
}
