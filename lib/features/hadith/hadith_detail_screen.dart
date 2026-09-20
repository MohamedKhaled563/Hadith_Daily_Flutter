import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_links.dart';
import '../../core/theme/app_colors.dart';
import '../../core/share/share_sheet.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/circle_icon_button.dart';
import '../../core/widgets/parchment_card.dart';
import '../../core/widgets/smooth_page_route.dart';
import '../../core/widgets/tap_target.dart';
import '../../data/models/hadith.dart';
import 'hadith_explanation_screen.dart';

class HadithDetailScreen extends StatelessWidget {
  const HadithDetailScreen({super.key, required this.hadith});

  final Hadith hadith;

  void _copyHadith(BuildContext context) {
    final buffer = StringBuffer()..writeln('« ${hadith.title} »');
    if (hadith.mukhrij.isNotEmpty) {
      buffer.writeln('المُخَرِّج: ${hadith.mukhrij}');
    }
    buffer.writeln('الحديث رقم ${hadith.number} من الأربعين النووية\n');
    buffer.writeln('نص الحديث:');
    if (hadith.isnad.isNotEmpty) {
      buffer.writeln(hadith.isnad);
    }
    buffer
      ..writeln(hadith.text)
      ..writeln('\nالمصدر: ${hadith.reference}');

    if (hadith.shortExplanation.isNotEmpty) {
      buffer
        ..writeln('\nخلاصة الشرح:')
        ..writeln(hadith.shortExplanation);
    }
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

    final link = AppLinks.storeLink;
    if (link != null) {
      buffer.writeln('\n🌿 من تطبيق «طيّب قلبك»');
      buffer.writeln(link);
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    showAppSnack(
      context,
      'تم نسخ نص الحديث وشرحه بالكامل',
      tone: SnackTone.success,
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
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Centred regardless of how wide the side clusters are —
                // spaceBetween used to shift this toward whichever side had
                // fewer/narrower buttons. Stack sizes itself to the tallest
                // child (the emblem), so the 44dp buttons sit centred inside.
                const EmblemBadge(),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  // chevron_right reads as "back" under RTL.
                  child: CircleIconButton(
                    icon: Icons.chevron_right_rounded,
                    semanticLabel: 'رجوع',
                    onTap: () => Navigator.maybePop(context),
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleIconButton(
                        icon: Icons.copy_rounded,
                        semanticLabel: 'نسخ النص الكامل مع الشرح والفوائد',
                        onTap: () => _copyHadith(context),
                      ),
                      const SizedBox(width: 6),
                      CircleIconButton(
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
                20,
                6,
                20,
                32 + MediaQuery.viewPaddingOf(context).bottom,
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
                      if (hadith.isnad.isNotEmpty) ...[
                        // The isnad/ananah phrase that introduces the hadith
                        // (عنعنة) — set apart from the hadith text itself so
                        // the reader can tell where the chain of narration
                        // ends and the Prophet's words begin.
                        Text(
                          hadith.isnad,
                          textAlign: TextAlign.start,
                          style: AppTextStyles.hadithText.copyWith(
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                            color: palette.bodyText.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      // The Prophetic text in Amiri — a Naskh face — set apart
                      // from the Tajawal UI chrome around it.
                      Text(
                        hadith.text,
                        textAlign: TextAlign.start,
                        style: AppTextStyles.hadithText.copyWith(
                          color: palette.bodyText,
                        ),
                      ),
                      if (hadith.mukhrij.isNotEmpty ||
                          (hadith.source?.trim().isNotEmpty ?? false)) ...[
                        const SizedBox(height: 16),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              // Labeled explicitly — this used to be a bare
                              // name with a person icon and no label, which
                              // is what read as the same thing as the
                              // reference chip below (a tester flagged the
                              // two as indistinguishable).
                              if (hadith.mukhrij.isNotEmpty)
                                _AttributionChip(
                                  icon: Icons.menu_book_rounded,
                                  label: 'المُخَرِّج',
                                  value: hadith.mukhrij,
                                ),
                              // Deliberately reads `hadith.source` here, not
                              // `hadith.reference` — reference falls back to
                              // the generic "من الأربعين النووية" book title
                              // when no real source was entered (true for
                              // all 42 bundled hadiths today), and showing
                              // that fallback as "أخرجه: ..." reads as a
                              // fabricated isnad attribution. `source` has
                              // no such fallback, so this chip only appears
                              // once a real transmitter (e.g. "رواه مسلم")
                              // is actually entered in the data.
                              if (hadith.source?.trim().isNotEmpty ?? false)
                                _AttributionChip(
                                  icon: Icons.auto_stories_rounded,
                                  label: 'أخرجه',
                                  value: hadith.source!.trim(),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (hadith.shortExplanation.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  ParchmentCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _CardHeading(
                          icon: Icons.summarize_rounded,
                          title: 'خلاصة الشرح',
                        ),
                        const SizedBox(height: 12),
                        Text(
                          hadith.shortExplanation,
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
                if (hadith.explanation.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _ExplanationTeaserCard(hadith: hadith),
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

/// A single labeled fact about the hadith's attribution — who extracted/
/// collected it (المُخَرِّج) or who transmitted/compiled it (أخرجه). Kept as
/// one small chip type used twice rather than two bespoke pills, so
/// "المُخَرِّج: البخاري ومسلم" and "أخرجه: رواه مسلم" always read the same way
/// instead of looking like two unrelated bits of chrome.
class _AttributionChip extends StatelessWidget {
  const _AttributionChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      constraints: const BoxConstraints(maxWidth: 260),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: palette.goldText),
          const SizedBox(width: 6),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 12,
                      height: AppLeading.chrome,
                      fontWeight: FontWeight.w500,
                      color: palette.goldText.withValues(alpha: 0.75),
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 12,
                      height: AppLeading.chrome,
                      fontWeight: FontWeight.w700,
                      color: palette.goldText,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// A teaser for "شرح الحديث وبيانه" — the opening line or two of the full
/// explanation, fading out, with a button that opens
/// [HadithExplanationScreen]. Kept off this page entirely (rather than an
/// in-place expand) so the hadith page stays a quick reference: text,
/// attribution, the short summary — someone who wants the full scholarly
/// explanation gets an uninterrupted reading screen for it instead of a
/// long block pushing everything else down.
class _ExplanationTeaserCard extends StatelessWidget {
  const _ExplanationTeaserCard({required this.hadith});

  final Hadith hadith;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ParchmentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeading(
            icon: Icons.menu_book_rounded,
            title: 'شرح الحديث وبيانه',
          ),
          const SizedBox(height: 10),
          // Plain ellipsis rather than a gradient fade: the card's
          // background is itself a gradient (see ParchmentCard), so a
          // flat-color fade never blends cleanly against it and shows up as
          // a visible seam. An ellipsis has no such problem and reads just
          // as clearly as "there's more".
          Text(
            hadith.explanation,
            textAlign: TextAlign.start,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 14.5,
              height: AppLeading.body,
              color: palette.bodyText,
            ),
          ),
          const SizedBox(height: 10),
          TapTarget(
            onTap: () => Navigator.push(
              context,
              appPageRoute(
                child: HadithExplanationScreen(hadith: hadith),
              ),
            ),
            semanticLabel: 'قراءة الشرح كاملاً',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'قراءة الشرح كاملاً',
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 13,
                    height: AppLeading.chrome,
                    fontWeight: FontWeight.w700,
                    color: palette.goldText,
                  ),
                ),
                // chevron_left, not _right: this app reads right-to-left
                // (see the back button elsewhere using chevron_right for
                // the same reason), so "forward, keep reading" points left.
                Icon(
                  Icons.chevron_left_rounded,
                  size: 18,
                  color: palette.goldText,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
