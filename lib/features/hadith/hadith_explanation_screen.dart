import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/circle_icon_button.dart';
import '../../core/widgets/parchment_card.dart';
import '../../data/models/hadith.dart';

/// The full "شرح الحديث وبيانه" reading, on its own screen rather than
/// inline on [HadithDetailScreen] — that page's job is a quick reference
/// (text, attribution, the short summary), while a full scholarly
/// explanation can run to several paragraphs and deserves its own
/// uninterrupted reading surface instead of pushing the hadith text further
/// down every time someone opens it.
class HadithExplanationScreen extends StatelessWidget {
  const HadithExplanationScreen({super.key, required this.hadith});

  final Hadith hadith;

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
                const EmblemBadge(),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: CircleIconButton(
                    icon: Icons.chevron_right_rounded,
                    semanticLabel: 'رجوع',
                    onTap: () => Navigator.maybePop(context),
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
                    'شرح الحديث وبيانه',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'الحديث ${toArabicDigits(hadith.number)}: ${hadith.title}',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
                  child: Text(
                    hadith.explanation,
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 15.5,
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
    );
  }
}
