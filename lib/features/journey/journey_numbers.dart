import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/widgets/parchment_card.dart';
import '../../data/journey/journey_engine.dart';
import '../../data/journey/journey_points.dart';
import 'journey_share_sheet.dart';

/// The reader's numbers on رحلتي, in two parts: this week's harvest and the
/// whole journey's. Three numbers each, the same three ideas: keeping at it,
/// the best run, and points; memorized hadiths stand in for the run on the
/// journey side, since the best run of all time sits there already.
class JourneyNumbers extends StatelessWidget {
  const JourneyNumbers({
    super.key,
    required this.streak,
    required this.bestThisWeek,
    required this.weekPoints,
    required this.allPoints,
    required this.memorized,
    required this.canShare,
  });

  final StreakResult streak;

  /// The most days in a row this week.
  final int bestThisWeek;
  final int weekPoints;
  final int allPoints;

  /// Hadiths held by heart, of the forty-two.
  final int memorized;

  /// Whether there is a week worth sharing yet.
  final bool canShare;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ParchmentCard(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 14),
      showWatermark: false,
      showCornerOrnaments: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: _PartTitle('حصاد الأسبوع')),
              IconButton(
                tooltip: 'كيف تُحسب؟',
                icon: Icon(
                  Icons.info_outline_rounded,
                  color: palette.goldText,
                ),
                onPressed: () => showHowCounted(context),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Row(
              children: [
                _Number(
                  value: toArabicDigits(streak.current),
                  unit: _dayUnit(streak.current),
                  label: 'الاستمرارية',
                ),
                _Number(
                  value: toArabicDigits(bestThisWeek),
                  unit: _dayUnit(bestThisWeek),
                  label: 'أفضل استمرارية',
                ),
                _Number(
                  value: toArabicDigits(weekPoints),
                  unit: 'نقطة',
                  label: 'نقاط الأسبوع',
                ),
              ],
            ),
          ),
          if (canShare)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => shareHarvest(context),
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: const Text('شارك حصاد أسبوعك'),
              ),
            )
          else
            const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Divider(height: 1, color: palette.cardBorder),
          ),
          const SizedBox(height: 12),
          const _PartTitle('حصاد رحلتك'),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Row(
              children: [
                _Number(
                  value: toArabicDigits(streak.best),
                  unit: _dayUnit(streak.best),
                  label: 'أفضل استمرارية',
                ),
                _Number(
                  value: toArabicDigits(allPoints),
                  unit: 'نقطة',
                  label: 'كل نقاطك',
                ),
                _Number(
                  value: '${toArabicDigits(memorized)} / ٤٢',
                  unit: 'حديثاً',
                  label: 'حفظت',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The noun that follows a count of days, as it would be read aloud.
String _dayUnit(int count) => switch (count) {
      1 => 'يوم',
      2 => 'يومان',
      >= 3 && <= 10 => 'أيام',
      _ => 'يوماً',
    };

class _PartTitle extends StatelessWidget {
  const _PartTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        child: Text(
          text,
          style: TextStyle(
            fontFamily: kSans,
            fontSize: 16,
            height: AppLeading.chrome,
            fontWeight: FontWeight.w800,
            color: context.palette.goldText,
          ),
        ),
      );
}

/// One number: the figure, its unit and what it counts.
class _Number extends StatelessWidget {
  const _Number({required this.value, required this.unit, required this.label});

  final String value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Expanded(
      child: Semantics(
        label: '$label: $value $unit',
        excludeSemantics: true,
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: TextStyle(
                        fontFamily: kSans,
                        fontSize: 22,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                        color: palette.bodyText,
                      ),
                    ),
                    TextSpan(
                      text: ' $unit',
                      style: TextStyle(
                        fontFamily: kSans,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: palette.mutedText,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 12.5,
                height: AppLeading.chrome,
                fontWeight: FontWeight.w600,
                color: palette.goldText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «كيف تُحسب؟»: what each number counts, short and calm.
Future<void> showHowCounted(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _HowCounted(),
    );

class _HowCounted extends StatelessWidget {
  const _HowCounted();

  static const _points = [
    ('رسالة اليوم تقرؤها', PointRules.message, 'حتى ١٠ في اليوم'),
    ('حديث تقرؤه وتؤكّد قراءته', PointRules.hadith, 'حتى حديثين في اليوم'),
    ('حديث تحفظه', PointRules.memorized, 'حديث في اليوم'),
    ('مراجعة في موعدها', PointRules.review, 'حتى ٥ في اليوم'),
    ('بطاقة تشاركها', PointRules.share, 'مرة في اليوم'),
    ('رسالة تقرؤها في المجتمع', PointRules.community, 'حتى ٣ في اليوم'),
    ('رسالة لك يقبلها المشرف', PointRules.approved, 'حتى ٣ في الأسبوع'),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final body = TextStyle(
      fontFamily: kSans,
      fontSize: 14,
      height: AppLeading.body,
      color: palette.bodyText,
    );
    final muted = body.copyWith(fontSize: 12.5, color: palette.mutedText);

    Widget section(String title, List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: body.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: palette.goldText,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              ...children,
            ],
          ),
        );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'كيف تُحسب أرقامك؟',
              textAlign: TextAlign.center,
              style: body.copyWith(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            section('الاستمرارية', [
              Text(
                'أيام متتالية قرأت فيها رسالة اليوم أو حديثاً، أو حفظت أو '
                'راجعت. وكل ${toArabicDigits(kDaysPerGrace)} أيام متتالية '
                'تمنحك يوم سماح، حتى يومين، يحفظ استمراريتك إن فاتك يوم.',
                style: body,
              ),
              const SizedBox(height: 4),
              Text(
                'وأفضل استمرارية أطول ما بلغته: في هذا الأسبوع، وفي رحلتك كلها.',
                style: muted,
              ),
            ]),
            section('النقاط', [
              for (final (what, points, limit) in _points)
                Semantics(
                  label: '$what: ${toArabicDigits(points)} نقاط، $limit',
                  excludeSemantics: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(child: Text(what, style: body)),
                        Text(limit, style: muted),
                        const SizedBox(width: 10),
                        Container(
                          constraints: const BoxConstraints(minWidth: 34),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: palette.ornamentGold.withValues(alpha: .18),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            toArabicDigits(points),
                            style: body.copyWith(
                              fontWeight: FontWeight.w800,
                              color: palette.goldText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                'وأقصى ما يُحسب من نشاطك على الهاتف '
                '${toArabicDigits(PointRules.deviceWeekCap)} نقطة في الأسبوع. '
                'النقاط تقيس نشاطك في التطبيق فقط.',
                style: muted,
              ),
            ]),
            section('حفظت', [
              Text(
                'الأحاديث التي أتممت حفظها من الأربعين النووية، من ٤٢ حديثاً.',
                style: body,
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
