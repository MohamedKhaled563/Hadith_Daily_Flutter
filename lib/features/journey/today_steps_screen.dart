import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_motion.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/circle_icon_button.dart';
import '../../core/widgets/parchment_card.dart';
import '../../core/widgets/smooth_page_route.dart';
import '../../data/journey/journey_copy.dart';
import '../../data/journey/journey_engine.dart';
import '../../data/journey/journey_repository.dart';
import '../../data/journey/reading_tracker.dart';
import '../../data/models/hadith.dart';
import '../../data/repositories/hadith_repository.dart';
import '../hadith/hadith_detail_screen.dart';
import 'journey_links.dart';
import 'journey_ring.dart';

/// The day's three steps, on a page of their own: read the message, read
/// its hadith, write what stayed with you. Opened from the ring on the home
/// header and from the button on رحلتي.
///
/// One step is enough for the day to count; the page says so at the top,
/// so three open circles never read as a debt.
class TodayStepsScreen extends StatelessWidget {
  const TodayStepsScreen({super.key, required this.onOpenMessage});

  /// Opens today's message, from the home shell.
  final VoidCallback onOpenMessage;

  static Route<void> route({required VoidCallback onOpenMessage}) =>
      appPageRoute(child: TodayStepsScreen(onOpenMessage: onOpenMessage));

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
    final textTheme = Theme.of(context).textTheme;
    final journey = JourneyRepository();
    final hadiths = HadithRepository();

    return AppScreen(
      child: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleIconButton(
                  icon: Icons.chevron_right_rounded,
                  semanticLabel: 'رجوع',
                  onTap: () => Navigator.maybePop(context),
                ),
                Semantics(
                  header: true,
                  child: Text(
                    'خطوات اليوم',
                    style: textTheme.titleMedium?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: CircleIconButton.slot),
              ],
            ),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: journey.listenable,
              builder: (context, _) {
                final data = journey.data;
                final steps = journey.todaySteps;
                final next = journey.nextHadithNumber;
                final day = data.days[journey.today];
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: [
                    _Summary(
                      done: steps.done,
                      counted: day?.isPresent ?? false,
                    ),
                    const SizedBox(height: 18),
                    TodaySteps(
                      steps: steps,
                      next: next == null ? null : hadiths.getByNumber(next),
                      writeAbout: hadiths.getByNumber(
                        day?.hadiths.lastOrNull ?? next ?? 1,
                      ),
                      // Back to the home shell first: the message loads
                      // there, with its own loading veil, and opens on top.
                      onOpenMessage: () {
                        Navigator.pop(context);
                        onOpenMessage();
                      },
                      onOpenHadith: (number) => _openHadith(context, number),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The big ring and one line on where the day stands.
class _Summary extends StatelessWidget {
  const _Summary({required this.done, required this.counted});

  final int done;

  /// Whether today already counts towards the streak: a message or a
  /// hadith read, or a part memorized or reviewed. Writing alone does not.
  final bool counted;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final line = done >= StepsRing.total
        ? JourneyCopy.stepsAllDone
        : counted
            ? JourneyCopy.stepsDayCounted
            : JourneyCopy.stepsHowToCount;

    return Semantics(
      label: '${StepsRing.describe(done)}. $line',
      excludeSemantics: true,
      child: Column(
        children: [
          StepsRing(done: done, size: 112),
          const SizedBox(height: 12),
          Text(
            line,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 14.5,
              height: AppLeading.body,
              fontWeight: FontWeight.w600,
              color: palette.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}

/// The three steps, in the order they lead into each other.
class TodaySteps extends StatelessWidget {
  const TodaySteps({
    super.key,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepCard(
          number: 1,
          done: steps.message,
          current: current == 0,
          title: 'اقرأ رسالة اليوم',
          subtitle: steps.message ? null : 'رسالة قصيرة من كلام النبي ﷺ',
          onTap: onOpenMessage,
        ),
        const SizedBox(height: 10),
        _StepCard(
          number: 2,
          done: steps.hadith,
          current: current == 1,
          title: hadithStep,
          subtitle: hadithNext,
          detail: hadith == null || steps.hadith
              ? null
              : arabicMinuteCount(ReadingRule.minutesFor(hadith)),
          onTap: hadith == null ? null : () => onOpenHadith(hadith.number),
        ),
        const SizedBox(height: 10),
        _StepCard(
          number: 3,
          done: steps.wrote,
          current: current == 2,
          title: 'اكتب رسالتك',
          subtitle: writing == null || steps.wrote
              ? null
              : 'ما بقي معك من «${writing.title}»',
          onTap:
              writing == null ? null : () => JourneyLinks.openWriting(writing),
        ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.done,
    required this.title,
    this.current = false,
    this.subtitle,
    this.detail,
    this.onTap,
  });

  final int number;
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

    final badge = AnimatedContainer(
      duration: context.motion(AppDurations.content),
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done
            ? green
            : current
                ? palette.ornamentGold
                : palette.surfaceSunken,
      ),
      child: done
          ? const Icon(Icons.check_rounded,
              size: 20, color: AppColors.softCream)
          : Text(
              toArabicDigits(number),
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 15,
                height: 1,
                fontWeight: FontWeight.w800,
                color: current ? AppColors.darkEmerald : palette.goldText,
              ),
            ),
    );

    final content = Row(
      children: [
        badge,
        const SizedBox(width: 12),
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
                  fontSize: 15.5,
                  height: AppLeading.chrome,
                  fontWeight: current ? FontWeight.w800 : FontWeight.w700,
                  color: done ? palette.mutedText : palette.bodyText,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 13,
                    height: AppLeading.chrome,
                    color: done ? palette.mutedText : palette.goldText,
                  ),
                ),
              ],
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
              fontWeight: FontWeight.w600,
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
            size: 22,
            color: current ? palette.goldText : palette.mutedText,
          ),
      ],
    );

    return Opacity(
      opacity: done ? .78 : 1,
      child: ParchmentCard(
        onTap: onTap,
        semanticLabel: [
          title,
          if (subtitle != null) subtitle!,
          if (detail != null) detail!,
          if (done) 'تمّت',
        ].join('، '),
        elevated: current,
        borderColor: current ? palette.ornamentGold : null,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        showWatermark: false,
        showCornerOrnaments: false,
        // The label says it all once; the text inside would repeat it.
        child: ExcludeSemantics(child: content),
      ),
    );
  }
}

/// The button on رحلتي that opens the day's steps: the ring, what is left,
/// and the count.
class TodayStepsButton extends StatelessWidget {
  const TodayStepsButton({
    super.key,
    required this.steps,
    required this.onTap,
  });

  final DaySteps steps;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final left = StepsRing.total - steps.done;
    final line = switch (left) {
      <= 0 => JourneyCopy.stepsAllDone,
      3 => 'ابدأ برسالة اليوم',
      2 => 'بقيت خطوتان',
      _ => 'بقيت خطوة واحدة',
    };

    return ParchmentCard(
      onTap: onTap,
      semanticLabel: 'خطوات اليوم، ${StepsRing.describe(steps.done)}، $line',
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      showWatermark: false,
      showCornerOrnaments: false,
      child: ExcludeSemantics(
        child: Row(
          children: [
            StepsRing(done: steps.done, size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'خطوات اليوم',
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 16,
                      height: AppLeading.chrome,
                      fontWeight: FontWeight.w800,
                      color: palette.bodyText,
                    ),
                  ),
                  Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 13,
                      height: AppLeading.chrome,
                      color: palette.goldText,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${toArabicDigits(steps.done)} / ٣',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: palette.mutedText,
              ),
            ),
            Icon(
              Icons.chevron_left_rounded,
              size: 22,
              color: palette.mutedText,
            ),
          ],
        ),
      ),
    );
  }
}
