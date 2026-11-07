import 'package:flutter/material.dart';

import '../../core/auth/sign_in_gate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_motion.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/widgets/asset_helper.dart';
import '../../core/widgets/bottom_navigation.dart';
import '../../core/widgets/circle_icon_button.dart';
import '../../core/widgets/parchment_card.dart';
import '../../core/widgets/smooth_page_route.dart';
import '../../core/widgets/tap_target.dart';
import '../../data/journey/journey_copy.dart';
import '../../data/journey/journey_engine.dart';
import '../../data/journey/journey_points.dart';
import '../../data/journey/journey_repository.dart';
import '../../data/journey/reading_tracker.dart';
import '../../data/models/hadith.dart';
import '../../data/repositories/hadith_repository.dart';
import '../favorites/favorites_screen.dart';
import '../hadith/hadith_detail_screen.dart';
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
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
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
                          color: const Color(0xFFD6BE88),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // The tree is only worth sending once it has a leaf on it.
              AnimatedBuilder(
                animation: JourneyRepository().listenable,
                builder: (context, _) => _section == 0 &&
                        JourneyRepository().data.completeCount > 0
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
        const SizedBox(height: 6),
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
        const SizedBox(height: 10),
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
                  height: 38,
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
                      color: selected == i
                          ? palette.goldText
                          : palette.mutedText,
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
                  JourneyTree(
                    data: data,
                    next: next,
                    titleOf: (number) =>
                        hadiths.getByNumber(number)?.title ?? '',
                    onLeafTap: (number) => _openHadith(context, number),
                  ),
                  const SizedBox(height: 6),
                  _TreeCaption(count: data.completeCount),
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
            const SizedBox(height: 14),
            _TodayCard(
              steps: steps,
              next: next == null ? null : hadiths.getByNumber(next),
              writeAbout: hadiths.getByNumber(
                data.days[journey.today]?.hadiths.lastOrNull ?? next ?? 1,
              ),
              onOpenMessage: onOpenMessage,
              onOpenHadith: (number) => _openHadith(context, number),
            ),
            const SizedBox(height: 14),
            _YouVersusYou(
              streak: streak,
              weeks: weeks,
              points: journey.thisWeekPoints,
              lastPoints: journey.lastWeekPoints,
              canShare: weeks.thisWeek > 0,
            ),
            const SizedBox(height: 14),
            _RecordsCard(records: journey.records),
            const SizedBox(height: 14),
            const _BoardEntry(),
          ],
        );
      },
    );
  }
}

class _TreeCaption extends StatelessWidget {
  const _TreeCaption({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Text(
      count == 0
          ? 'كل ورقة هنا حديث. ابدأ برسالة اليوم، وستنمو شجرتك مع قراءتك.'
          : '${toArabicDigits(count)} من ٤٢ حديثاً',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: kSans,
        fontSize: count == 0 ? 13.5 : 15,
        height: AppLeading.body,
        fontWeight: count == 0 ? FontWeight.w500 : FontWeight.w800,
        color: count == 0 ? palette.mutedText : palette.goldText,
      ),
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
    final hadithStep = switch ((hadith, steps.hadith)) {
      (null, _) => 'أتممت الأربعين',
      (final waiting?, true) => 'أتممت حديث اليوم. التالي: «${waiting.title}»',
      (final waiting?, false) => 'اقرأ حديث «${waiting.title}»',
    };

    return ParchmentCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      showWatermark: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('خطوات اليوم'),
          const SizedBox(height: 6),
          _StepRow(
            done: steps.message,
            title: 'اقرأ رسالة اليوم',
            onTap: onOpenMessage,
          ),
          _StepRow(
            done: steps.hadith,
            title: hadithStep,
            detail: hadith == null || steps.hadith
                ? null
                : arabicMinuteCount(ReadingRule.minutesFor(hadith)),
            onTap: hadith == null ? null : () => onOpenHadith(hadith.number),
          ),
          _StepRow(
            done: steps.wrote,
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
    this.detail,
    this.onTap,
  });

  final bool done;
  final String title;
  final String? detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final green = context.isDarkMode
        ? AppColors.primaryGreenDark
        : AppColors.primaryGreen;

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 22,
            color: done ? green : palette.cardBorderStrong,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 14.5,
                height: AppLeading.chrome,
                fontWeight: FontWeight.w700,
                color: done ? palette.mutedText : palette.bodyText,
              ),
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
          if (onTap != null)
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
    final widest = weeks.thisWeek > weeks.lastWeek
        ? weeks.thisWeek
        : weeks.lastWeek;

    return ParchmentCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      showWatermark: false,
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
                  label: 'سلسلتك الآن',
                  color: palette.warmText,
                ),
              ),
              Expanded(
                child: _Figure(
                  value: streak.best,
                  label: 'أفضل سلسلة',
                  color: palette.goldText,
                ),
              ),
              Expanded(
                child: _Figure(
                  value: streak.graceBanked,
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
      JourneyRecord.streak ||
      JourneyRecord.weekDays =>
        arabicDayCount(value),
      JourneyRecord.weekMinutes ||
      JourneyRecord.dayMinutes =>
        arabicMinuteCount(value),
      _ => toArabicDigits(value),
    };
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ParchmentCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      showWatermark: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('أرقامك'),
          const SizedBox(height: 6),
          for (final record in JourneyRecord.values)
            Semantics(
              label: '${record.label}: '
                  '${_value(record, records[record] ?? 0)}',
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        record.label,
                        style: TextStyle(
                          fontFamily: kSans,
                          fontSize: 13.5,
                          height: AppLeading.chrome,
                          color: palette.bodyText,
                        ),
                      ),
                    ),
                    Text(
                      _value(record, records[record] ?? 0),
                      style: TextStyle(
                        fontFamily: kSans,
                        fontSize: 13.5,
                        height: AppLeading.chrome,
                        fontWeight: FontWeight.w800,
                        color: palette.goldText,
                      ),
                    ),
                  ],
                ),
              ),
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
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      children: [
        Text(
          // The Arabic zero is a small dot, easy to miss at the top of a card.
          value == 0 ? '—' : toArabicDigits(value),
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
