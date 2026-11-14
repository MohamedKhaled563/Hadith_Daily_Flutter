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
      // Sheets are parchment with the cards' gold hairline, so one opened
      // from a card reads as part of the same page rather than a grey slab.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.parchmentTop,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: palette.parchmentTop,
        dragHandleColor: palette.cardBorderStrong,
        dragHandleSize: const Size(44, 4),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet),
          ),
          side: BorderSide(color: palette.cardBorder, width: 1.2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: palette.parchmentTop,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: palette.cardBorder, width: 1.2),
        ),
      ),
      // Quiet actions in the app's own type, bold enough to read as buttons.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: const TextStyle(
            fontFamily: kSans,
            fontSize: 15,
            height: AppLeading.chrome,
            fontWeight: FontWeight.w700,
          ),
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.goldText,
          backgroundColor: palette.surface,
          textStyle: const TextStyle(
            fontFamily: kSans,
            fontSize: 15,
            height: AppLeading.chrome,
            fontWeight: FontWeight.w800,
          ),
          minimumSize: const Size(48, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: const StadiumBorder(),
          side: BorderSide(
            color: palette.ornamentGold.withValues(alpha: .6),
            width: 1.2,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: palette.cardBorder, thickness: 1),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: brightness == Brightness.dark
              ? AppColors.softCreamDark
              : AppColors.darkEmerald,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: TextStyle(
          fontFamily: kSans,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: brightness == Brightness.dark
              ? AppColors.primaryTextDark
              : AppColors.softCream,
        ),
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
