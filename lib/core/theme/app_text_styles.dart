import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  static const screenTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryText,
    fontFamily: 'Tajawal',
  );

  static const sectionTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryGreen,
    fontFamily: 'Tajawal',
  );

  static const hadithText = TextStyle(
    fontSize: 21,
    height: 1.9,
    fontWeight: FontWeight.w500,
    color: AppColors.primaryText,
    fontFamily: 'Tajawal',
  );

  static const explanationText = TextStyle(
    fontSize: 17,
    height: 1.8,
    fontWeight: FontWeight.normal,
    color: AppColors.primaryText,
    fontFamily: 'Tajawal',
  );

  static const smallText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.secondaryText,
    fontFamily: 'Tajawal',
  );

  static const buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    fontFamily: 'Tajawal',
  );
}
