import 'package:flutter/material.dart';

import '../../core/auth/sign_in_gate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_motion.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/asset_helper.dart';
import '../../core/widgets/bottom_navigation.dart';
import '../../core/widgets/circle_icon_button.dart';
import '../../core/widgets/parchment_card.dart';
import '../../core/widgets/smooth_page_route.dart';
import '../../core/widgets/tap_target.dart';
import '../../data/journey/journey_copy.dart';
import '../../data/journey/journey_engine.dart';
import '../../data/journey/journey_models.dart';
import '../../data/journey/journey_points.dart';
import '../../data/journey/journey_repository.dart';
import '../../data/journey/memorization.dart';
import '../../data/journey/reading_tracker.dart';
import '../../data/models/hadith.dart';
import '../../data/repositories/hadith_repository.dart';
import '../favorites/favorites_screen.dart';
import '../hadith/hadith_detail_screen.dart';
import '../memorize/memorize_screen.dart';
import 'journey_links.dart';
import 'journey_share_sheet.dart';
import 'journey_tree.dart';
import 'weekly_board_screen.dart';

/// A tab inside [HomeScreen]'s IndexedStack — the host supplies the Scaffold
/// and the background.
///
/// Everything that is the reader's own lives here: the journey, and the
/// favourites as a second section. A fifth tab would not fit a 320dp screen.
class JourneyScreen extends StatefulWidget {
  const JourneyScreen({
    super.key,
    required this.onOpenDrawer,
    required this.onOpenMessage,
  });

  final VoidCallback onOpenDrawer;

  /// Takes the reader to today's message.
  final VoidCallback onOpenMessage;

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  int _section = 0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleIconButton(
                icon: Icons.menu_rounded,
                semanticLabel: 'فتح قائمة الإعدادات',
                onTap: widget.onOpenDrawer,
              ),
              Flexible(
                child: Semantics(
                  header: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'رحلتي',
                        textAlign: TextAlign.center,
                        style: textTheme.titleMedium?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      AssetHelper.assetOrFallback(
                        assetPath: 'assets/images/golden_divider.png',
                        width: 80,
                        height: 10,
                        fallback: Container(
                          width: 40,
                          height: 1.5,
                          color: context.palette.cardBorderStrong,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // The tree is only worth sending once it has a leaf on it.
              AnimatedBuilder(
                animation: JourneyRepository().listenable,
                builder: (context, _) =>
                    _section == 0 && JourneyRepository().data.completeCount > 0
                        ? CircleIconButton(
                            icon: Icons.ios_share_rounded,
                            semanticLabel: 'مشاركة شجرتي',
                            onTap: () => shareTree(context),
                          )
                        : const SizedBox(width: CircleIconButton.slot),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _SectionTabs(
            selected: _section,
            onSelected: (section) {
              AppHaptics.selection();
              setState(() => _section = section);
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: IndexedStack(
            index: _section,
            children: [
              _JourneyBody(onOpenMessage: widget.onOpenMessage),
              const FavoritesScreen(showHeader: false),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  static const _labels = ['رحلتي', 'المفضلة'];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++)
            Expanded(
              child: TapTarget(
                onTap: () => onSelected(i),
                semanticLabel: _labels[i],
                selected: selected == i,
                pressScale: AppPress.cardScale,
                child: AnimatedContainer(
                  duration: context.motion(AppDurations.control),
                  curve: AppDurations.curve,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == i ? palette.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(
                    _labels[i],
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 14,
                      height: AppLeading.chrome,
                      fontWeight: FontWeight.w700,
                      color:
                          selected == i ? palette.goldText : palette.mutedText,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _JourneyBody extends StatelessWidget {
  const _JourneyBody({required this.onOpenMessage});

  final VoidCallback onOpenMessage;

  void _openHadith(BuildContext context, int number) {
    final hadith = HadithRepository().getByNumber(number);
    if (hadith == null) return;
    AppHaptics.tap();
    Navigator.push(
      context,
      appPageRoute(child: HadithDetailScreen(hadith: hadith)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final journey = JourneyRepository();
    final hadiths = HadithRepository();

    return AnimatedBuilder(
      animation: journey.listenable,
      builder: (context, _) {
        final data = journey.data;
        final next = journey.nextHadithNumber;
        final steps = journey.todaySteps;
        final streak = journey.streak;
        final weeks = journey.weeks;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            2,
            20,
            16 + BottomNavigation.reservedHeight(context),
          ),
          children: [
            ParchmentCard(
              elevated: true,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
              child: Column(
                children: [
                  // About two fifths of the screen: the hero, without
                  // pushing the day's steps below the fold.
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * .42,
                    ),
                    child: Center(
                      child: JourneyTree(
                        data: data,
                        next: next,
                        titleOf: (number) =>
                            hadiths.getByNumber(number)?.title ?? '',
                        onLeafTap: (number) => _openHadith(context, number),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _TreeSummary(
                    read: data.completeCount,
                    memorized: data.memorizedCount,
                    streak: streak.current,
                  ),
                  const SizedBox(height: 10),
                  _LeafKey(
                    looks: leafLooks(data, next: next).values.toSet(),
                    memorized: data.memorizedCount > 0,
                  ),
                  if (journey.isGuest && !data.isEmpty) ...[
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => requireSignIn(
                        context,
                        reason: JourneyCopy.signInReason,
                      ),
                      child: const Text('سجّل الدخول لتبقى شجرتك معك'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _TodayCard(
              steps: steps,
              next: next == null ? null : hadiths.getByNumber(next),
              writeAbout: hadiths.getByNumber(
                data.days[journey.today]?.hadiths.lastOrNull ?? next ?? 1,
              ),
              onOpenMessage: onOpenMessage,
              onOpenHadith: (number) => _openHadith(context, number),
            ),
            const SizedBox(height: 12),
            // Given the data, not const: a const card with nothing passed in
            // is never rebuilt when the journey changes.
            _MemoJourneyCard(data: data, today: journey.today),
            const SizedBox(height: 12),
            _YouVersusYou(
              streak: streak,
              weeks: weeks,
              points: journey.thisWeekPoints,
              lastPoints: journey.lastWeekPoints,
              canShare: weeks.thisWeek > 0,
            ),
            const SizedBox(height: 12),
            _RecordsCard(records: journey.records),
            const SizedBox(height: 12),
            const _BoardEntry(),
          ],
        );
      },
    );
  }
}

/// The day's three steps, in the order they lead into each other.
class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.steps,
    required this.next,
    required this.writeAbout,
    required this.onOpenMessage,
    required this.onOpenHadith,
  });

  final DaySteps steps;
  final Hadith? next;

  /// The hadith the writing step opens with: the one read today if there is
  /// one, which is what the reader has something to say about.
  final Hadith? writeAbout;
  final VoidCallback onOpenMessage;
  final ValueChanged<int> onOpenHadith;

  @override
  Widget build(BuildContext context) {
    final hadith = next;
    final writing = writeAbout;
    final (hadithStep, hadithNext) = switch ((hadith, steps.hadith)) {
      (null, _) => ('أتممت الأربعين', null),
      (final waiting?, true) => (
          'أتممت حديث اليوم',
          'التالي: «${waiting.title}»',
        ),
      (final waiting?, false) => ('اقرأ حديث «${waiting.title}»', null),
    };
    // The first step not done is the one to do now.
    final current = [steps.message, steps.hadith, steps.wrote].indexOf(false);

    return ParchmentCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      showWatermark: false,
      showCornerOrnaments: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: _CardTitle('خطوات اليوم')),
              Text(
                '${toArabicDigits(steps.done)} / ٣',
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.palette.mutedText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _StepRow(
            done: steps.message,
            current: current == 0,
            title: 'اقرأ رسالة اليوم',
            onTap: onOpenMessage,
          ),
          _StepRow(
            done: steps.hadith,
            current: current == 1,
            title: hadithStep,
            subtitle: hadithNext,
            detail: hadith == null || steps.hadith
                ? null
                : arabicMinuteCount(ReadingRule.minutesFor(hadith)),
            onTap: hadith == null ? null : () => onOpenHadith(hadith.number),
          ),
          _StepRow(
            done: steps.wrote,
            current: current == 2,
            title: 'اكتب رسالتك',
            onTap: writing == null
                ? null
                : () => JourneyLinks.openWriting(writing),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.done,
    required this.title,
    this.current = false,
    this.subtitle,
    this.detail,
    this.onTap,
  });

  final bool done;

  /// The step to do now: picked out so the eye lands on it.
  final bool current;
  final String title;

  /// A quieter second line, so a long step never wraps into a paragraph.
  final String? subtitle;
  final String? detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final green = context.isDarkMode
        ? AppColors.primaryGreenDark
        : AppColors.primaryGreen;

    final row = AnimatedContainer(
      duration: context.motion(AppDurations.control),
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: current
            ? palette.surfaceSunken
            : palette.surface.withValues(alpha: 0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 22,
            color: done ? green : palette.cardBorderStrong,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 14.5,
                    height: AppLeading.chrome,
                    fontWeight: current ? FontWeight.w800 : FontWeight.w700,
                    color: done ? palette.mutedText : palette.bodyText,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 12.5,
                      height: AppLeading.chrome,
                      color: palette.goldText,
                    ),
                  ),
              ],
            ),
          ),
          if (detail != null) ...[
            const SizedBox(width: 8),
            Text(
              detail!,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 12.5,
                height: AppLeading.chrome,
                fontWeight: FontWeight.w500,
                color: palette.goldText,
              ),
            ),
          ],
          // Only a step still to do points onward; a done one stays tappable
          // but quiet.
          if (onTap != null && !done)
            Icon(
              // chevron_left: "forward" in a right-to-left app.
              Icons.chevron_left_rounded,
              size: 20,
              color: palette.mutedText,
            ),
        ],
      ),
    );

    if (onTap == null) return row;
    return TapTarget(
      onTap: onTap!,
      semanticLabel: done ? '$title، تمّت' : title,
      pressScale: AppPress.cardScale,
      child: row,
    );
  }
}

/// The only competitor here is the reader's own last week.
class _YouVersusYou extends StatelessWidget {
  const _YouVersusYou({
    required this.streak,
    required this.weeks,
    required this.points,
    required this.lastPoints,
    required this.canShare,
  });

  final StreakResult streak;
  final WeekCompare weeks;
  final WeekPoints points;
  final WeekPoints lastPoints;

  /// Whether there is a week worth sharing yet.
  final bool canShare;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final widest =
        weeks.thisWeek > weeks.lastWeek ? weeks.thisWeek : weeks.lastWeek;

    return ParchmentCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      showWatermark: false,
      showCornerOrnaments: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('أنت مقابل نفسك'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Figure(
                  value: streak.current,
                  unit: _dayUnit(streak.current),
                  label: 'سلسلتك الآن',
                  color: palette.warmText,
                ),
              ),
              Expanded(
                child: _Figure(
                  value: streak.best,
                  unit: _dayUnit(streak.best),
                  label: 'أفضل سلسلة',
                  color: palette.goldText,
                ),
              ),
              Expanded(
                child: _Figure(
                  value: streak.graceBanked,
                  unit: _dayUnit(streak.graceBanked),
                  label: 'أيام سماح',
                  color: palette.bodyText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _WeekBar(
            label: 'هذا الأسبوع',
            minutes: weeks.thisWeek,
            widest: widest,
            color: palette.ornamentGold,
          ),
          const SizedBox(height: 8),
          _WeekBar(
            label: 'الأسبوع الماضي',
            minutes: weeks.lastWeek,
            widest: widest,
            color: palette.mutedText.withValues(alpha: .45),
          ),
          const SizedBox(height: 14),
          _PointsRow(points: points, lastPoints: lastPoints),
          if (canShare) ...[
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => shareHarvest(context),
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: const Text('شارك حصاد أسبوعك'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// This week's points against last week's. Points measure activity in the
/// app, nothing more, so they sit here quietly rather than on every screen.
class _PointsRow extends StatelessWidget {
  const _PointsRow({required this.points, required this.lastPoints});

  final WeekPoints points;
  final WeekPoints lastPoints;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = TextStyle(
      fontFamily: kSans,
      fontSize: 13,
      height: AppLeading.chrome,
      color: palette.mutedText,
    );

    return Semantics(
      label: 'نقاطك هذا الأسبوع ${toArabicDigits(points.total)}، '
          'والأسبوع الماضي ${toArabicDigits(lastPoints.total)}',
      excludeSemantics: true,
      child: Row(
        children: [
          Icon(Icons.eco_rounded, size: 18, color: palette.goldText),
          const SizedBox(width: 6),
          Text('نقاطك هذا الأسبوع', style: style),
          const SizedBox(width: 6),
          Text(
            toArabicDigits(points.total),
            style: style.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: palette.goldText,
            ),
          ),
          const Spacer(),
          Text('الماضي ${toArabicDigits(lastPoints.total)}', style: style),
        ],
      ),
    );
  }
}

/// The reader's eight personal records. A dash for one not set yet.
class _RecordsCard extends StatelessWidget {
  const _RecordsCard({required this.records});

  final Map<JourneyRecord, int> records;

  static String _value(JourneyRecord record, int value) {
    if (value == 0) return '—';
    return switch (record) {
      JourneyRecord.streak || JourneyRecord.weekDays => arabicDayCount(value),
      JourneyRecord.weekMinutes ||
      JourneyRecord.dayMinutes =>
        arabicMinuteCount(value),
      _ => toArabicDigits(value),
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final any = records.values.any((value) => value > 0);

    return ParchmentCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      showWatermark: false,
      showCornerOrnaments: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('أرقامك'),
          const SizedBox(height: 8),
          if (!any)
            Text(
              'أرقامك تظهر هنا بعد أول قراءة: أطول سلسلة، وأكثر أسبوع، وغيرها.',
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 13.5,
                height: AppLeading.body,
                color: palette.mutedText,
              ),
            )
          else
            // Label above value, in tiles: the eye no longer crosses the
            // card for every pair.
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth < 300 ? 1 : 2;
                const gap = 8.0;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final record in JourneyRecord.values)
                      SizedBox(
                        width: width,
                        child: _RecordTile(
                          label: record.label,
                          value: _value(record, records[record] ?? 0),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.value,
    required this.label,
    required this.color,
    this.unit,
  });

  final int value;
  final String label;
  final Color color;

  /// Said beside the number, so a lone «١» never reads as a bar.
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      children: [
        Text.rich(
          TextSpan(
            // The Arabic zero is a small dot, easy to miss at the top of a
            // card.
            text: value == 0 ? '—' : toArabicDigits(value),
            children: [
              if (value != 0 && unit != null)
                TextSpan(
                  text: ' $unit',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          style: TextStyle(
            fontFamily: kSans,
            fontSize: 24,
            height: 1.1,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: kSans,
            fontSize: 12,
            height: AppLeading.chrome,
            color: palette.mutedText,
          ),
        ),
      ],
    );
  }
}

class _WeekBar extends StatelessWidget {
  const _WeekBar({
    required this.label,
    required this.minutes,
    required this.widest,
    required this.color,
  });

  final String label;
  final int minutes;
  final int widest;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = TextStyle(
      fontFamily: kSans,
      fontSize: 12.5,
      height: AppLeading.chrome,
      color: palette.mutedText,
    );

    return Semantics(
      label: '$label: ${arabicMinuteCount(minutes)}',
      excludeSemantics: true,
      child: Row(
        children: [
          SizedBox(width: 92, child: Text(label, style: style)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: LinearProgressIndicator(
                value: widest == 0 ? 0 : minutes / widest,
                minHeight: 8,
                backgroundColor: palette.surfaceSunken,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          SizedBox(
            width: 54,
            child: Text(
              '${toArabicDigits(minutes)} د',
              textAlign: TextAlign.end,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

/// The way in to the weekly board. Quiet on purpose: the board is optional,
/// and the journey above it is the point.
class _BoardEntry extends StatelessWidget {
  const _BoardEntry();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ParchmentCard(
      padding: EdgeInsets.zero,
      showWatermark: false,
      showCornerOrnaments: false,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            AppHaptics.tap();
            Navigator.push(
              context,
              appPageRoute(child: const WeeklyBoardScreen()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                Icon(
                  Icons.format_list_numbered_rtl_rounded,
                  size: 22,
                  color: palette.goldText,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _CardTitle('لوحة الأسبوع'),
                      Text(
                        'اختيارية، وتُنشر كل جمعة',
                        style: TextStyle(
                          fontFamily: kSans,
                          fontSize: 13,
                          height: AppLeading.chrome,
                          color: palette.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_left_rounded, color: palette.mutedText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: kSans,
        fontSize: 16,
        height: AppLeading.chrome,
        fontWeight: FontWeight.w700,
        color: context.palette.goldText,
      ),
    );
  }
}

/// Memorizing, from the journey: how many are held, what is due today, and
/// what is half learned. With nothing started, the shortest hadith already
/// read, as the easiest place to begin.
class _MemoJourneyCard extends StatelessWidget {
  const _MemoJourneyCard({required this.data, required this.today});

  final JourneyData data;
  final String today;

  void _open(BuildContext context, Widget screen) {
    AppHaptics.tap();
    Navigator.push(context, appPageRoute(child: screen));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hadiths = HadithRepository();
    final due = dueReviews(data.memo, today);
    final learning = [
      for (final entry in data.memo.entries)
        if (entry.value.isLearning) entry.key,
    ]..sort();
    final body = TextStyle(
      fontFamily: kSans,
      fontSize: 14,
      height: AppLeading.body,
      color: palette.bodyText,
    );

    Widget row(String text, String action, VoidCallback onTap,
            {bool primary = false}) =>
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Expanded(child: Text(text, style: body)),
              const SizedBox(width: 8),
              AppButton(
                text: action,
                expand: false,
                isSecondary: !primary,
                onPressed: onTap,
              ),
            ],
          ),
        );

    final rows = <Widget>[
      for (final number in due.take(3))
        if (hadiths.getByNumber(number) case final hadith?)
          row(
            'مراجعة «${hadith.title}»',
            'راجع',
            () => _open(context, ReviewScreen(hadith: hadith)),
            primary: true,
          ),
      for (final number in learning.take(2))
        if (hadiths.getByNumber(number) case final hadith?)
          row(
            'أكمل حفظ «${hadith.title}»',
            'أكمل',
            () => _open(context, MemorizeScreen(hadith: hadith)),
          ),
    ];

    if (rows.isEmpty) {
      final upcoming = [
        for (final entry in data.memo.entries)
          if (entry.value.due != null) entry,
      ]..sort((a, b) => a.value.due!.compareTo(b.value.due!));
      if (upcoming.isNotEmpty) {
        final next = upcoming.first;
        final title = hadiths.getByNumber(next.key)?.title ?? '';
        final days = DateTime.parse(next.value.due!)
            .difference(DateTime.parse(today))
            .inDays;
        rows.add(Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'لا مراجعة اليوم. التالية «$title» '
            '${days <= 1 ? 'غداً' : 'بعد ${arabicDayCount(days)}'}.',
            style: body,
          ),
        ));
      } else {
        final read = [
          for (final number in data.hadith.keys)
            if (data.progressOf(number).isComplete &&
                !data.memoOf(number).isMemorized)
              if (hadiths.getByNumber(number) case final hadith?) hadith,
        ]..sort((a, b) => a.text.length.compareTo(b.text.length));
        rows.add(read.isEmpty
            ? Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'بعد أن تقرأ حديثاً تستطيع حفظه من صفحته، جزءاً جزءاً.',
                  style: body,
                ),
              )
            : row(
                'ابدأ بحفظ «${read.first.title}»',
                'ابدأ',
                () => _open(context, MemorizeScreen(hadith: read.first)),
                primary: true,
              ));
      }
    }

    return ParchmentCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      showWatermark: false,
      showCornerOrnaments: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: _CardTitle('الحفظ')),
              if (data.memorizedCount > 0)
                Text(
                  'في حفظك ${toArabicDigits(data.memorizedCount)}',
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: palette.goldText,
                  ),
                ),
            ],
          ),
          ...rows,
        ],
      ),
    );
  }
}

/// Days in the form the number takes, to sit beside a figure.
String _dayUnit(int days) => switch (days) {
      1 => 'يوم',
      2 => 'يومان',
      >= 3 && <= 10 => 'أيام',
      _ => 'يوماً',
    };

/// The facts under the tree, in a line of small pills.
class _TreeSummary extends StatelessWidget {
  const _TreeSummary({
    required this.read,
    required this.memorized,
    required this.streak,
  });

  final int read;
  final int memorized;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (read == 0 && memorized == 0) {
      return Text(
        'كل ورقة هنا حديث. ابدأ برسالة اليوم، وستنمو شجرتك مع قراءتك.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: kSans,
          fontSize: 13.5,
          height: AppLeading.body,
          fontWeight: FontWeight.w500,
          color: palette.mutedText,
        ),
      );
    }

    Widget pill(String text, {required bool strong}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: palette.surfaceSunken,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: strong ? 15 : 13,
              height: AppLeading.chrome,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w700,
              color: palette.goldText,
            ),
          ),
        );

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        pill('${toArabicDigits(read)} من ٤٢ حديثاً', strong: true),
        if (memorized > 0)
          pill('في حفظك ${toArabicDigits(memorized)}', strong: false),
        if (streak > 0) pill('سلسلة ${arabicDayCount(streak)}', strong: false),
      ],
    );
  }
}

/// What each leaf means, for the kinds of leaf this tree has right now.
class _LeafKey extends StatelessWidget {
  const _LeafKey({required this.looks, required this.memorized});

  final Set<LeafLook> looks;
  final bool memorized;

  static const _labels = {
    LeafLook.complete: 'مكتمل',
    LeafLook.started: 'بدأت قراءته',
    LeafLook.next: 'حديث اليوم',
    LeafLook.empty: 'لم يُقرأ بعد',
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    Widget entry(LeafLook look, String label, {bool dot = false}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LeafSwatch(look, memorized: dot),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 12,
                height: AppLeading.chrome,
                fontWeight: FontWeight.w600,
                color: palette.mutedText,
              ),
            ),
          ],
        );

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final MapEntry(key: look, value: label) in _labels.entries)
          if (looks.contains(look)) entry(look, label),
        if (memorized) entry(LeafLook.complete, 'في حفظك', dot: true),
      ],
    );
  }
}

/// One record: what it is, then the reader's best.
class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
        decoration: BoxDecoration(
          color: palette.surfaceSunken,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 12,
                height: AppLeading.chrome,
                color: palette.mutedText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 15,
                height: AppLeading.chrome,
                fontWeight: FontWeight.w800,
                color: palette.goldText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
