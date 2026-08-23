import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Typography for the app.
///
/// Two families, two jobs:
///   * [kNaskh] (Amiri) — the Prophetic text itself. A Naskh face, the
///     traditional letterform for scripture.
///   * [kSans] (Tajawal) — everything around it. A geometric Arabic sans for
///     UI chrome, titles and explanatory copy.
///
/// Both are bundled in `assets/fonts/` and declared in pubspec.yaml. They are
/// NOT fetched at runtime, so the app renders correctly offline and on first
/// launch. Do not reintroduce `google_fonts`: it registers families under
/// variant-qualified names (`Tajawal_w700`), so a plain `fontFamily: 'Tajawal'`
/// silently falls back to the system font.
const String kSans = 'Tajawal';
const String kNaskh = 'Amiri';

/// Line-height scale. Arabic needs more leading than Latin because tashkeel
/// sit above and below the baseline.
class AppLeading {
  /// Hadith text, which may carry harakat.
  static const scripture = 2.0;

  /// Explanatory and UI body copy.
  static const body = 1.75;

  /// Tight single-line chrome: pills, badges, labels.
  static const chrome = 1.3;
}

class AppTextStyles {
  /// Arabic is a connected script — letterSpacing breaks the joins between
  /// glyphs. Every style here leaves it at zero deliberately; reach for a
  /// heavier weight instead of negative tracking.
  static const _tracking = 0.0;

  static const screenTitle = TextStyle(
    fontFamily: kSans,
    fontSize: 28,
    height: AppLeading.chrome,
    fontWeight: FontWeight.w700,
    letterSpacing: _tracking,
    color: AppColors.primaryText,
  );

  static const sectionTitle = TextStyle(
    fontFamily: kSans,
    fontSize: 22,
    height: AppLeading.chrome,
    fontWeight: FontWeight.w700,
    letterSpacing: _tracking,
    color: AppColors.primaryGreen,
  );

  /// The Prophetic text. Amiri, generous leading, never tracked.
  static const hadithText = TextStyle(
    fontFamily: kNaskh,
    fontSize: 20,
    height: AppLeading.scripture,
    fontWeight: FontWeight.w400,
    letterSpacing: _tracking,
    color: AppColors.primaryText,
  );

  static const explanationText = TextStyle(
    fontFamily: kSans,
    fontSize: 15,
    height: AppLeading.body,
    fontWeight: FontWeight.w400,
    letterSpacing: _tracking,
    color: AppColors.primaryText,
  );

  static const smallText = TextStyle(
    fontFamily: kSans,
    fontSize: 13,
    height: AppLeading.body,
    fontWeight: FontWeight.w500,
    letterSpacing: _tracking,
    color: AppColors.secondaryText,
  );

  static const buttonText = TextStyle(
    fontFamily: kSans,
    fontSize: 16,
    height: AppLeading.chrome,
    fontWeight: FontWeight.w700,
    letterSpacing: _tracking,
    color: Colors.white,
  );
}
