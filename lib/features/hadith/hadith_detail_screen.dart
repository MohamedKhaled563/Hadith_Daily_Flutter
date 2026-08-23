import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/share/share_sheet.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/asset_helper.dart';
import '../../core/widgets/parchment_card.dart';
import '../../core/widgets/tap_target.dart';
import '../../data/models/hadith.dart';

class HadithDetailScreen extends StatelessWidget {
  const HadithDetailScreen({super.key, required this.hadith});

  final Hadith hadith;

  void _copyHadith(BuildContext context) {
    final buffer = StringBuffer()
      ..writeln('« ${hadith.title} »')
      ..writeln('الحديث رقم ${hadith.number} من الأربعين النووية\n')
      ..writeln('نص الحديث:')
      ..writeln(hadith.text)
      ..writeln('\nالمصدر: ${hadith.reference}');

    if (hadith.explanation.isNotEmpty) {
      buffer
        ..writeln('\nالشرح:')
        ..writeln(hadith.explanation);
    }
    if (hadith.keyLessons.isNotEmpty) {
      buffer.writeln('\nمن فوائد الحديث:');
      for (final lesson in hadith.keyLessons) {
        buffer.writeln('• $lesson');
      }
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ نص الحديث وشرحه بالكامل 🌿')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return AppScreen(
      child: Column(
        children: [
          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // chevron_right reads as "back" under RTL.
                _CircleIconButton(
                  icon: Icons.chevron_right_rounded,
                  semanticLabel: 'رجوع',
                  onTap: () => Navigator.maybePop(context),
                ),
                _EmblemBadge(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CircleIconButton(
                      icon: Icons.copy_rounded,
                      semanticLabel: 'نسخ الحديث وشرحه',
                      onTap: () => _copyHadith(context),
                    ),
                    const SizedBox(width: 6),
                    _CircleIconButton(
                      icon: Icons.ios_share_rounded,
                      semanticLabel: 'مشاركة الحديث كصورة',
                      onTap: () => showShareSheet(
                        context: context,
                        message: hadith.text,
                        hadithTitle: hadith.title,
                        hadithNumber: toArabicDigits(hadith.number),
                        category: hadith.reference,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Semantics(
              header: true,
              child: Column(
                children: [
                  Text(
                    hadith.title,
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'الحديث رقم ${toArabicDigits(hadith.number)} من الأربعين النووية',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: palette.goldText,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                20, 6, 20, 32 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                ParchmentCard(
                  elevated: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _CardHeading(
                        icon: Icons.format_quote_rounded,
                        title: 'نص الحديث الشريف',
                      ),
                      const SizedBox(height: 14),
                      // The Prophetic text in Amiri — a Naskh face — set apart
                      // from the Tajawal UI chrome around it.
                      Text(
                        hadith.text,
                        textAlign: TextAlign.start,
                        style: AppTextStyles.hadithText.copyWith(
                          color: palette.bodyText,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: palette.surface,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                            border: Border.all(color: palette.cardBorder),
                          ),
                          child: Text(
                            hadith.reference,
                            style: TextStyle(
                              fontFamily: kSans,
                              fontSize: 12,
                              height: AppLeading.chrome,
                              fontWeight: FontWeight.w700,
                              color: palette.goldText,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (hadith.explanation.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  ParchmentCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _CardHeading(
                          icon: Icons.menu_book_rounded,
                          title: 'شرح الحديث وبيانه',
                        ),
                        const SizedBox(height: 12),
                        Text(
                          hadith.explanation,
                          textAlign: TextAlign.start,
                          style: TextStyle(
                            fontFamily: kSans,
                            fontSize: 14.5,
                            height: AppLeading.body,
                            color: palette.bodyText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (hadith.narratorBio.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  ParchmentCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _CardHeading(
                          icon: Icons.person_outline_rounded,
                          title: 'عن راوي الحديث',
                        ),
                        const SizedBox(height: 12),
                        Text(
                          hadith.narratorBio,
                          textAlign: TextAlign.start,
                          style: TextStyle(
                            fontFamily: kSans,
                            fontSize: 14,
                            height: AppLeading.body,
                            color: palette.bodyText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (hadith.keyLessons.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  ParchmentCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _CardHeading(
                          icon: Icons.spa_rounded,
                          title: 'من فوائد الحديث وهداياته 🌿',
                        ),
                        const SizedBox(height: 12),
                        for (final lesson in hadith.keyLessons)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: palette.goldText,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    lesson,
                                    textAlign: TextAlign.start,
                                    style: TextStyle(
                                      fontFamily: kSans,
                                      fontSize: 13.5,
                                      height: AppLeading.body,
                                      color: palette.bodyText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardHeading extends StatelessWidget {
  const _CardHeading({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        Icon(icon, size: 20, color: palette.goldText),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 16,
              height: AppLeading.chrome,
              fontWeight: FontWeight.w700,
              color: palette.goldText,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmblemBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: palette.surface,
        border: Border.all(color: palette.cardBorderStrong, width: 1.5),
        boxShadow: AppElevation.card,
      ),
      child: AssetHelper.assetOrFallback(
        assetPath: 'assets/images/heart_leaf_emblem.png',
        width: 36,
        height: 36,
        fallback: const Icon(
          Icons.favorite_rounded,
          color: AppColors.primaryGreen,
          size: 24,
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return TapTarget(
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: palette.surface,
          border: Border.all(color: palette.cardBorder),
          boxShadow: AppElevation.card,
        ),
        child: Icon(icon, color: palette.bodyText, size: 22),
      ),
    );
  }
}
