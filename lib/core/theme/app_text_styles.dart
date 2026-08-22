import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  static TextStyle get screenTitle => GoogleFonts.tajawal(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.primaryText,
  );

  static TextStyle get sectionTitle => GoogleFonts.tajawal(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryGreen,
  );

  static TextStyle get hadithText => GoogleFonts.amiri(
    fontSize: 22,
    height: 1.9,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryText,
  );

  static TextStyle get explanationText => GoogleFonts.tajawal(
    fontSize: 17,
    height: 1.8,
    fontWeight: FontWeight.normal,
    color: AppColors.primaryText,
  );

  static TextStyle get smallText => GoogleFonts.tajawal(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.secondaryText,
  );

  static TextStyle get buttonText => GoogleFonts.tajawal(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
}
