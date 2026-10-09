import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/circle_icon_button.dart';
import '../../core/widgets/parchment_card.dart';
import '../../data/models/intro_section.dart';

/// A reading that comes before the forty hadiths — مقدمة الإمام النووي or
/// ترجمة الإمام النووي. Same reading surface as [HadithExplanationScreen],
/// with the source's section headings and lists kept.
class IntroSectionScreen extends StatelessWidget {
  const IntroSectionScreen({super.key, required this.section});

  final IntroSection section;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    final bodyStyle = TextStyle(
      fontFamily: kSans,
      fontSize: 15.5,
      height: AppLeading.body,
      color: palette.bodyText,
    );

    Widget block(IntroBlock b, {required bool first}) {
      switch (b.type) {
        case IntroBlockType.heading:
          return Padding(
            padding: EdgeInsets.only(top: first ? 0 : 10, bottom: 8),
            child: Semantics(
              header: true,
              child: Text(
                b.text,
                textAlign: TextAlign.start,
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 16.5,
                  height: AppLeading.chrome,
                  fontWeight: FontWeight.w700,
                  color: palette.goldText,
                ),
              ),
            ),
          );
        case IntroBlockType.bullet:
          return Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•', style: bodyStyle.copyWith(color: palette.goldText)),
                const SizedBox(width: 8),
                Expanded(child: Text(b.text, style: bodyStyle)),
              ],
            ),
          );
        case IntroBlockType.paragraph:
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(b.text, textAlign: TextAlign.start, style: bodyStyle),
          );
      }
    }

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
              child: Text(
                section.title,
                textAlign: TextAlign.center,
                style: textTheme.headlineMedium,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < section.blocks.length; i++)
                        block(section.blocks[i], first: i == 0),
                    ],
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
