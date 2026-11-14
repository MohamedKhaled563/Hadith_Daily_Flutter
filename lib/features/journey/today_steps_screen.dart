import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_motion.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/circle_icon_button.dart';
import '../../core/widgets/icon_badge.dart';
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
                    const SizedBox(height: 20),
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

//// The big ring and one line on where the day stands, on a card of their
/// own with a soft light behind the ring.
class _Summary extends StatelessWidget {
  const _Summary({required this.done, required this.counted});

  final int done;

  /// Whether today already counts towards the streak: a message or a
  /// hadith read, or a part memorized or reviewed. Writing alone does not.
  final bool counted;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final complete = done >= StepsRing.total;
    final line = complete
        ? JourneyCopy.stepsAllDone
        : counted
            ? JourneyCopy.stepsDayCounted
            : JourneyCopy.stepsHowToCount;
    final glow = complete ? palette.success : palette.ornamentGold;

    return Semantics(
      label: '${StepsRing.describe(done)}. $line',
      excludeSemantics: true,
      child: ParchmentCard(
        elevated: true,
        showWatermark: false,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        // Full width, so the ring and the line centre on the card rather
        // than on the widest of the two.
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      glow.withValues(alpha: .3),
                      glow.withValues(alpha: 0),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: StepsRing(done: done, size: 112),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: complete ? palette.successWash : palette.surface,
                  borderRadius: BorderRadius.circular(AppRadii.listItem - 4),
                  border: Border.all(
                    color: complete
                        ? palette.success.withValues(alpha: .35)
                        : palette.cardBorder,
                  ),
                ),
                child: Text(
                  line,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 14.5,
                    height: AppLeading.body,
                    fontWeight: FontWeight.w600,
                    color: complete ? palette.success : palette.bodyText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The three steps, in the order they lead into each other, on a line that
/// joins their numbers.
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
          first: true,
          done: steps.message,
          current: current == 0,
          nextDone: steps.hadith,
          icon: Icons.mail_outline_rounded,
          title: 'اقرأ رسالة اليوم',
          subtitle: steps.message ? null : 'رسالة قصيرة من كلام النبي ﷺ',
          onTap: onOpenMessage,
        ),
        _StepCard(
          number: 2,
          previousDone: steps.message,
          done: steps.hadith,
          current: current == 1,
          nextDone: steps.wrote,
          icon: Icons.menu_book_rounded,
          title: hadithStep,
          subtitle: hadithNext,
          detail: hadith == null || steps.hadith
              ? null
              : arabicMinuteCount(ReadingRule.minutesFor(hadith)),
          onTap: hadith == null ? null : () => onOpenHadith(hadith.number),
        ),
        _StepCard(
          number: 3,
          previousDone: steps.hadith,
          done: steps.wrote,
          current: current == 2,
          last: true,
          icon: Icons.edit_note_rounded,
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
    required this.icon,
    this.first = false,
    this.last = false,
    this.previousDone = false,
    this.nextDone = false,
    this.current = false,
    this.subtitle,
    this.detail,
    this.onTap,
  });

  final int number;
  final bool done;

  /// The step to do now: picked out so the eye lands on it.
  final bool current;

  /// The first step has no line running in above its number, the last
  /// none running on below it.
  final bool first;
  final bool last;

  /// Whether the step before this one is done, for the line coming in.
  final bool previousDone;

  /// Whether the step after this one is done too, so the line between them
  /// is drawn as travelled.
  final bool nextDone;
  final IconData icon;
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
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done
            ? green
            : current
                ? palette.ornamentGold
                : palette.surface,
        border: Border.all(
          color: done
              ? green
              : current
                  ? palette.ornamentGold
                  : palette.cardBorderStrong,
          width: 1.4,
        ),
        boxShadow: current
            ? [
                BoxShadow(
                  color: palette.ornamentGold.withValues(alpha: .4),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: done
          ? const Icon(
              Icons.check_rounded,
              size: 20,
              color: AppColors.softCream,
            )
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

    // The number sits on a line outside the card, so the three read as one
    // path from the first step to the last: green where both ends are done,
    // gold where the path has got to, a hairline ahead.
    Color segment(bool from, bool to) => from && to
        ? green.withValues(alpha: .55)
        : from
            ? palette.ornamentGold.withValues(alpha: .6)
            : palette.cardBorder;
    Widget line(Color color) => Container(width: 2.5, color: color);
    final rail = SizedBox(
      width: 36,
      child: Column(
        children: [
          SizedBox(
            height: 16,
            child: first ? null : line(segment(previousDone, done)),
          ),
          badge,
          if (!last) Expanded(child: line(segment(done, nextDone))),
        ],
      ),
    );

    final content = Row(
      children: [
        IconBadge(
          icon: icon,
          size: 38,
          tone: done
              ? BadgeTone.green
              : current
                  ? BadgeTone.gold
                  : BadgeTone.quiet,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              if (detail != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: palette.goldWash,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 13,
                        color: palette.goldText,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        detail!,
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
              ],
            ],
          ),
        ),
        // Only a step still to do points onward; a done one stays tappable
        // but quiet.
        if (onTap != null && !done) ...[
          const SizedBox(width: 8),
          ForwardChevron(emphasised: current),
        ],
      ],
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          rail,
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 12),
              child: Opacity(
                opacity: done ? .82 : 1,
                child: ParchmentCard(
                  onTap: onTap,
                  semanticLabel: [
                    title,
                    if (subtitle != null) subtitle!,
                    if (detail != null) detail!,
                    if (done) 'تمّت',
                  ].join('، '),
                  elevated: current,
                  borderColor: current
                      ? palette.ornamentGold
                      : done
                          ? palette.success.withValues(alpha: .35)
                          : null,
                  padding: const EdgeInsets.all(12),
                  showWatermark: false,
                  showCornerOrnaments: false,
                  // The label says it all once; the text inside would repeat
                  // it.
                  child: ExcludeSemantics(child: content),
                ),
              ),
            ),
          ),
        ],
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
    final complete = left <= 0;
    final line = switch (left) {
      <= 0 => JourneyCopy.stepsAllDone,
      3 => 'ابدأ برسالة اليوم',
      2 => 'بقيت خطوتان',
      _ => 'بقيت خطوة واحدة',
    };

    return ParchmentCard(
      onTap: onTap,
      semanticLabel: 'خطوات اليوم، ${StepsRing.describe(steps.done)}، $line',
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      showWatermark: false,
      showCornerOrnaments: false,
      child: ExcludeSemantics(
        child: Row(
          children: [
            StepsRing(done: steps.done, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'خطوات اليوم',
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 16.5,
                      height: AppLeading.chrome,
                      fontWeight: FontWeight.w800,
                      color: palette.bodyText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 13,
                      height: AppLeading.chrome,
                      fontWeight: FontWeight.w600,
                      color: complete ? palette.success : palette.goldText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: complete ? palette.successWash : palette.goldWash,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(
                  color: complete
                      ? palette.success.withValues(alpha: .35)
                      : palette.ornamentGold.withValues(alpha: .5),
                ),
              ),
              child: Text(
                '${toArabicDigits(steps.done)} / ٣',
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 13.5,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: complete ? palette.success : palette.goldText,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const ForwardChevron(),
          ],
        ),
      ),
    );
  }
}
