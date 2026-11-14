import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/widgets/botanical_sheet.dart';
import '../../core/widgets/glass_panel.dart';
import '../../core/widgets/icon_badge.dart';
import '../../core/widgets/parchment_card.dart';
import '../../core/widgets/tap_target.dart';
import '../../data/journey/journey_engine.dart';
import '../../data/journey/journey_points.dart';
import 'journey_share_sheet.dart';
import 'journey_tree.dart';

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
    this.canShareJourney = false,
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

  /// Whether the whole journey has anything to show yet.
  final bool canShareJourney;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ParchmentCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      showWatermark: false,
      showCornerOrnaments: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PartHeader(
            icon: Icons.calendar_month_rounded,
            title: 'حصاد الأسبوع',
            trailing: _HowButton(),
          ),
          const SizedBox(height: 12),
          _Tiles(
            children: [
              _Number(
                icon: Icons.local_fire_department_rounded,
                tone: BadgeTone.warm,
                value: toArabicDigits(streak.current),
                unit: _dayUnit(streak.current),
                label: 'الاستمرارية',
              ),
              _Number(
                icon: Icons.workspace_premium_rounded,
                tone: BadgeTone.green,
                value: toArabicDigits(bestThisWeek),
                unit: _dayUnit(bestThisWeek),
                label: 'أفضل استمرارية',
              ),
              _Number(
                icon: kPointsIcon,
                tone: BadgeTone.gold,
                value: toArabicDigits(weekPoints),
                unit: 'نقطة',
                label: 'نقاط الأسبوع',
              ),
            ],
          ),
          if (canShare) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => shareHarvest(context),
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: const Text('شارك حصاد أسبوعك'),
            ),
          ],
          const SizedBox(height: 16),
          _OrnamentRule(color: palette.cardBorderStrong),
          const SizedBox(height: 14),
          const _PartHeader(
            icon: Icons.park_rounded,
            title: 'حصاد رحلتك',
          ),
          const SizedBox(height: 12),
          _Tiles(
            children: [
              _Number(
                icon: Icons.emoji_events_rounded,
                tone: BadgeTone.gold,
                value: toArabicDigits(streak.best),
                unit: _dayUnit(streak.best),
                label: 'أفضل استمرارية',
              ),
              _Number(
                icon: Icons.stars_rounded,
                tone: BadgeTone.gold,
                value: toArabicDigits(allPoints),
                unit: 'نقطة',
                label: 'كل نقاطك',
              ),
              _Number(
                leaf: true,
                tone: BadgeTone.gold,
                value: '${toArabicDigits(memorized)} / ٤٢',
                unit: 'حديثاً',
                label: 'حفظت',
              ),
            ],
          ),
          if (canShareJourney) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => shareJourneyHarvest(context),
              icon: const Icon(Icons.ios_share_rounded, size: 18),
              label: const Text('شارك حصاد رحلتك'),
            ),
          ],
        ],
      ),
    );
  }
}

/// The mark for points, here, in «كيف تُحسب؟» and on the posters.
const kPointsIcon = Icons.star_rounded;

/// The noun that follows a count of days, as it would be read aloud.
String _dayUnit(int count) => switch (count) {
      1 => 'يوم',
      2 => 'يومان',
      >= 3 && <= 10 => 'أيام',
      _ => 'يوماً',
    };

/// A part's title with its mark, and anything that belongs beside it.
class _PartHeader extends StatelessWidget {
  const _PartHeader({required this.icon, required this.title, this.trailing});

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        IconBadge(icon: icon, size: 34),
        const SizedBox(width: 10),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 16.5,
                height: AppLeading.chrome,
                fontWeight: FontWeight.w800,
                color: palette.bodyText,
              ),
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// The ⓘ beside the week's title: a small round button, not a stray icon.
class _HowButton extends StatelessWidget {
  const _HowButton();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Tooltip(
      message: 'كيف تُحسب؟',
      // The button says it already; the tooltip is for the eye.
      excludeFromSemantics: true,
      child: TapTarget(
        onTap: () => showHowCounted(context),
        semanticLabel: 'كيف تُحسب؟',
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: glassTile(context, radius: 17),
          child: Icon(
            Icons.question_mark_rounded,
            size: 18,
            color: palette.goldText,
          ),
        ),
      ),
    );
  }
}

/// A fine gold rule with a diamond at its middle, between the two parts.
class _OrnamentRule extends StatelessWidget {
  const _OrnamentRule({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    Widget line(bool towardsCentreAtEnd) => Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.centerStart,
                end: AlignmentDirectional.centerEnd,
                colors: towardsCentreAtEnd
                    ? [color.withValues(alpha: 0), color]
                    : [color, color.withValues(alpha: 0)],
              ),
            ),
          ),
        );

    return ExcludeSemantics(
      child: Row(
        children: [
          line(true),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Transform.rotate(
              angle: .785398,
              child: Container(width: 6, height: 6, color: color),
            ),
          ),
          line(false),
        ],
      ),
    );
  }
}

/// Three tiles in a row, a small gap between them.
class _Tiles extends StatelessWidget {
  const _Tiles({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }
}

/// One number on a tile of its own: its mark, the figure with its unit, and
/// what it counts.
class _Number extends StatelessWidget {
  const _Number({
    required this.value,
    required this.unit,
    required this.label,
    required this.tone,
    this.icon,
    this.leaf = false,
  });

  final String value;
  final String unit;
  final String label;
  final BadgeTone tone;
  final IconData? icon;

  /// A gold leaf for the mark, as on the tree.
  final bool leaf;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (_, ink) = IconBadge.toneColors(palette, tone);

    return Semantics(
      // Each figure is read on its own, not run together with the rest.
      container: true,
      label: '$label: $value $unit',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
        decoration: glassTile(context),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 22,
              child: leaf
                  ? const LeafSwatch(LeafLook.memorized, height: 20)
                  : Icon(icon, size: 20, color: ink),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: TextStyle(
                        fontFamily: kSans,
                        fontSize: 21,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                        color: palette.bodyText,
                      ),
                    ),
                    TextSpan(
                      text: ' $unit',
                      style: TextStyle(
                        fontFamily: kSans,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: palette.mutedText,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
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
      ),
    );
  }
}

/// «كيف تُحسب؟»: what each number counts, short and calm.
Future<void> showHowCounted(BuildContext context) => showBotanicalSheet<void>(
      context: context,
      title: 'كيف تُحسب أرقامك؟',
      child: const _HowCounted(),
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

    Widget section({
      required Widget mark,
      required String title,
      required List<Widget> children,
    }) =>
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          decoration: glassTile(context, radius: AppRadii.listItem),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  mark,
                  const SizedBox(width: 10),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: body.copyWith(
                          fontSize: 16,
                          height: AppLeading.chrome,
                          fontWeight: FontWeight.w800,
                          color: palette.goldText,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        section(
          mark: const IconBadge(
            icon: Icons.local_fire_department_rounded,
            tone: BadgeTone.warm,
            size: 32,
          ),
          title: 'الاستمرارية',
          children: [
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
          ],
        ),
        section(
          mark: const IconBadge(icon: kPointsIcon, size: 32),
          title: 'النقاط',
          children: [
            for (final (i, (what, points, limit)) in _points.indexed) ...[
              if (i > 0) Divider(height: 1, color: palette.cardBorder),
              Semantics(
                label: '$what: ${toArabicDigits(points)} نقاط، $limit',
                excludeSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              what,
                              style: body.copyWith(
                                height: AppLeading.chrome,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              limit,
                              style: muted.copyWith(height: AppLeading.chrome),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        constraints: const BoxConstraints(minWidth: 38),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: palette.goldWash,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          border: Border.all(
                            color: palette.ornamentGold.withValues(alpha: .5),
                          ),
                        ),
                        child: Text(
                          toArabicDigits(points),
                          style: body.copyWith(
                            height: AppLeading.chrome,
                            fontWeight: FontWeight.w800,
                            color: palette.goldText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'وأقصى ما يُحسب من نشاطك على الهاتف '
              '${toArabicDigits(PointRules.deviceWeekCap)} نقطة في الأسبوع. '
              'النقاط تقيس نشاطك في التطبيق فقط.',
              style: muted,
            ),
          ],
        ),
        section(
          mark: const IconBadge(
            size: 32,
            child: LeafSwatch(LeafLook.memorized),
          ),
          title: 'حفظت',
          children: [
            Text(
              'الأحاديث التي أتممت حفظها من الأربعين النووية، من ٤٢ حديثاً.',
              style: body,
            ),
          ],
        ),
      ],
    );
  }
}
