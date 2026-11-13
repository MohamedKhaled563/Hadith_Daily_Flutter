import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_motion.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/circle_icon_button.dart';
import '../../core/widgets/parchment_card.dart';
import '../../core/widgets/smooth_page_route.dart';
import '../../data/journey/journey_copy.dart';
import '../../data/journey/journey_models.dart';
import '../../data/journey/journey_repository.dart';
import '../../data/journey/memorization.dart';
import '../../data/models/hadith.dart';
import '../../data/repositories/hadith_repository.dart';
import '../journey/journey_tree.dart';
import 'memorize_screen.dart';

/// Everything the reader holds by heart, with today's reviews first.
///
/// Today's are cards of their own at the top, each with one button; once
/// reviewed, a card says so and when the hadith comes back. Below a line,
/// every memorized hadith, with how firmly it is held.
class MemoListScreen extends StatelessWidget {
  const MemoListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final journey = JourneyRepository();

    return AppScreen(
      child: AnimatedBuilder(
        animation: journey.listenable,
        builder: (context, _) {
          final plan = MemoPlan.of(journey.data, journey.today);
          return Column(
            children: [
              const SizedBox(height: 8),
              _Header(held: plan.held.length),
              const SizedBox(height: 10),
              Expanded(
                child: plan.isEmpty
                    ? _Empty(start: plan.start)
                    : _Lists(plan: plan, today: journey.today),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// What the reader has to do with their memorizing today, and all they
/// hold, worked out from the journey.
class MemoPlan {
  MemoPlan._({
    required this.due,
    required this.reviewedToday,
    required this.learning,
    required this.held,
    required this.next,
    required this.start,
  });

  factory MemoPlan.of(JourneyData data, String today) {
    final hadiths = HadithRepository();
    final memo = data.memo;
    final reviewed = [
      for (final number in data.days[today]?.reviewed ?? const <int>[])
        if (memo[number]?.isMemorized ?? false) number,
    ];
    final due = [
      for (final number in dueReviews(memo, today))
        if (!reviewed.contains(number)) number,
    ];
    final upcoming = [
      for (final entry in memo.entries)
        if (entry.value.due != null && !entry.value.isDue(today)) entry,
    ]..sort((a, b) => a.value.due!.compareTo(b.value.due!));
    final read = [
      for (final number in data.hadith.keys)
        if (data.progressOf(number).isComplete &&
            !data.memoOf(number).isMemorized &&
            !data.memoOf(number).isLearning)
          if (hadiths.getByNumber(number) case final hadith?) hadith,
    ]..sort((a, b) => a.text.length.compareTo(b.text.length));

    return MemoPlan._(
      due: due,
      reviewedToday: reviewed,
      learning: [
        for (final entry in memo.entries)
          if (entry.value.isLearning) entry.key,
      ]..sort(),
      held: [
        for (final entry in memo.entries)
          if (entry.value.isMemorized) entry.key,
      ]..sort(),
      next: upcoming.isEmpty ? null : upcoming.first.key,
      start: read.firstOrNull,
    );
  }

  /// Due today and not yet reviewed, the longest waiting first.
  final List<int> due;

  /// Reviewed today, when the review was due.
  final List<int> reviewedToday;

  /// Started and not finished.
  final List<int> learning;

  /// Every hadith memorized.
  final List<int> held;

  /// The next review after today, if any is planned.
  final int? next;

  /// The shortest hadith read and not yet started: the easiest one to
  /// memorize next.
  final Hadith? start;

  bool get isEmpty => held.isEmpty && learning.isEmpty;

  /// Whether every review due today is done.
  bool get doneToday => due.isEmpty && reviewedToday.isNotEmpty;
}

/// Days from [today] to [day], negative when it has passed.
int _daysUntil(String day, String today) =>
    DateTime.parse(day).difference(DateTime.parse(today)).inDays;

/// «غداً» or «بعد ٣ أيام».
String _whenFrom(String day, String today) {
  final days = _daysUntil(day, today);
  return days <= 1 ? 'غداً' : 'بعد ${arabicDayCount(days)}';
}

/// [count] hadiths in the form that number takes.
String hadithCount(int count) => switch (count) {
      1 => 'حديث واحد',
      2 => 'حديثان',
      >= 3 && <= 10 => '${toArabicDigits(count)} أحاديث',
      _ => '${toArabicDigits(count)} حديثاً',
    };

void _open(BuildContext context, Widget screen) {
  AppHaptics.tap();
  Navigator.push(context, appPageRoute(child: screen));
}

class _Header extends StatelessWidget {
  const _Header({required this.held});

  final int held;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          CircleIconButton(
            icon: Icons.chevron_right_rounded,
            semanticLabel: 'رجوع',
            onTap: () => Navigator.maybePop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              header: true,
              child: Column(
                children: [
                  Text(
                    'راجع حفظك',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 19,
                      height: AppLeading.chrome,
                      fontWeight: FontWeight.w900,
                      color: palette.bodyText,
                    ),
                  ),
                  if (held > 0)
                    Text(
                      'في حفظك ${hadithCount(held)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: kSans,
                        fontSize: 13,
                        height: AppLeading.chrome,
                        fontWeight: FontWeight.w700,
                        color: palette.goldText,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: CircleIconButton.slot + 8),
        ],
      ),
    );
  }
}

class _Lists extends StatelessWidget {
  const _Lists({required this.plan, required this.today});

  final MemoPlan plan;
  final String today;

  @override
  Widget build(BuildContext context) {
    final hadiths = HadithRepository();
    final data = JourneyRepository().data;
    final todays = [...plan.due, ...plan.reviewedToday];

    return ListView(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        28 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      children: [
        _SectionTitle(
          'مراجعة اليوم',
          trailing: plan.doneToday ? 'تمّت' : null,
        ),
        const SizedBox(height: 8),
        if (todays.isEmpty)
          _Note(_nothingToday(data))
        else
          for (final number in todays)
            if (hadiths.getByNumber(number) case final hadith?)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                // A card turns from «راجعه» to done in place, so the reader
                // sees which one they have just finished.
                child: AnimatedSwitcher(
                  duration: context.motion(AppDurations.content),
                  switchInCurve: AppDurations.curve,
                  child: plan.due.contains(number)
                      ? _DueCard(
                          key: ValueKey('due$number'),
                          hadith: hadith,
                          memo: data.memoOf(number),
                          today: today,
                        )
                      : _DoneCard(
                          key: ValueKey('done$number'),
                          hadith: hadith,
                          memo: data.memoOf(number),
                          today: today,
                        ),
                ),
              ),
        if (plan.doneToday) const _Note('أتممت مراجعة اليوم.', done: true),
        if (plan.learning.isNotEmpty) ...[
          const SizedBox(height: 14),
          const _SectionTitle('تحفظه الآن'),
          const SizedBox(height: 8),
          _ListCard(
            children: [
              for (final number in plan.learning)
                if (hadiths.getByNumber(number) case final hadith?)
                  _LearningRow(hadith: hadith, memo: data.memoOf(number)),
            ],
          ),
        ],
        if (plan.held.isNotEmpty) ...[
          const SizedBox(height: 20),
          _Divider('كل ما تحفظه', count: plan.held.length),
          const SizedBox(height: 10),
          _ListCard(
            children: [
              for (final number in plan.held)
                if (hadiths.getByNumber(number) case final hadith?)
                  _HeldRow(
                    hadith: hadith,
                    memo: data.memoOf(number),
                    status: _status(number, data.memoOf(number)),
                    dueNow: plan.due.contains(number),
                  ),
            ],
          ),
        ],
        if (plan.start case final start?) ...[
          const SizedBox(height: 18),
          _StartCard(hadith: start, first: false),
        ],
      ],
    );
  }

  String _nothingToday(JourneyData data) {
    final next = plan.next;
    if (next == null) return 'لا مراجعة مجدولة. ما تحفظه ثابت.';
    final title = HadithRepository().getByNumber(next)?.title ?? '';
    return 'لا مراجعة اليوم. التالية «$title» '
        '${_whenFrom(data.memoOf(next).due!, today)}.';
  }

  String _status(int number, MemoProgress memo) {
    if (plan.due.contains(number)) return 'مراجعته اليوم';
    if (plan.reviewedToday.contains(number)) return 'راجعته اليوم';
    if (memo.isKept || memo.due == null) return 'ثبت في حفظك';
    return 'المراجعة القادمة ${_whenFrom(memo.due!, today)}';
  }
}

/// Rows on one card, with a hairline between them, so a list never sits on
/// the landscape behind the page.
class _ListCard extends StatelessWidget {
  const _ListCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ParchmentCard(
      showWatermark: false,
      showCornerOrnaments: false,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: palette.cardBorder),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      header: true,
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 16,
              height: AppLeading.chrome,
              fontWeight: FontWeight.w800,
              color: palette.goldText,
            ),
          ),
          const Spacer(),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 13,
                height: AppLeading.chrome,
                fontWeight: FontWeight.w700,
                color: palette.success,
              ),
            ),
        ],
      ),
    );
  }
}

/// A line across the page with a label in it, between today's reviews and
/// everything held.
class _Divider extends StatelessWidget {
  const _Divider(this.label, {required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final line = Expanded(
      child: Container(height: 1.2, color: palette.cardBorderStrong),
    );

    return Semantics(
      header: true,
      child: Row(
        children: [
          line,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '$label (${toArabicDigits(count)})',
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 14,
                height: AppLeading.chrome,
                fontWeight: FontWeight.w800,
                color: palette.mutedText,
              ),
            ),
          ),
          line,
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text, {this.done = false});

  final String text;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: done ? palette.successWash : palette.surfaceSunken,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.event_available_rounded,
            size: 20,
            color: done ? palette.success : palette.mutedText,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 14,
                height: AppLeading.body,
                fontWeight: FontWeight.w600,
                color: done ? palette.success : palette.bodyText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A leaf off the tree with the hadith's number on it, as on the tree.
class LeafNumber extends StatelessWidget {
  const LeafNumber({
    super.key,
    required this.number,
    required this.look,
    this.height = 40,
  });

  final int number;
  final LeafLook look;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: height * .8,
        child: Stack(
          alignment: Alignment.center,
          children: [
            LeafSwatch(look, height: height),
            Padding(
              padding: EdgeInsets.only(top: height * .08),
              child: Text(
                toArabicDigits(number),
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: height * .3,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: TreeColors.standard.inkOn(look),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A review due today: the one thing on the page that asks to be done.
class _DueCard extends StatelessWidget {
  const _DueCard({
    super.key,
    required this.hadith,
    required this.memo,
    required this.today,
  });

  final Hadith hadith;
  final MemoProgress memo;
  final String today;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final late = -_daysUntil(memo.due!, today);
    final line = switch (late) {
      <= 0 => 'موعد مراجعته اليوم، ودقيقة تكفي.',
      1 => 'كان موعده أمس.',
      _ => 'تأخر ${arabicDayCount(late)}.',
    };

    return ParchmentCard(
      elevated: true,
      borderColor: palette.ornamentGold,
      showWatermark: false,
      showCornerOrnaments: false,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LeafNumber(number: hadith.number, look: LeafLook.memorized),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hadith.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: kSans,
                        fontSize: 16,
                        height: AppLeading.chrome,
                        fontWeight: FontWeight.w800,
                        color: palette.bodyText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      line,
                      style: TextStyle(
                        fontFamily: kSans,
                        fontSize: 13,
                        height: AppLeading.chrome,
                        fontWeight: FontWeight.w600,
                        color: palette.goldText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppButton(
            text: 'راجعه الآن',
            icon: Icons.record_voice_over_rounded,
            onPressed: () => _open(context, ReviewScreen(hadith: hadith)),
          ),
        ],
      ),
    );
  }
}

/// A review done today: quiet, ticked, and when the hadith comes back.
class _DoneCard extends StatelessWidget {
  const _DoneCard({
    super.key,
    required this.hadith,
    required this.memo,
    required this.today,
  });

  final Hadith hadith;
  final MemoProgress memo;
  final String today;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final line = memo.isKept || memo.due == null
        ? 'راجعته اليوم، وثبت في حفظك.'
        : 'راجعته اليوم. نعود إليه ${_whenFrom(memo.due!, today)}.';

    return Semantics(
      label: '${hadith.title}، $line',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: palette.successWash,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: palette.success.withValues(alpha: .35)),
        ),
        child: Row(
          children: [
            LeafNumber(number: hadith.number, look: LeafLook.memorized),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hadith.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 15,
                      height: AppLeading.chrome,
                      fontWeight: FontWeight.w700,
                      color: palette.bodyText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    line,
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 13,
                      height: AppLeading.chrome,
                      fontWeight: FontWeight.w600,
                      color: palette.success,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.check_circle_rounded, color: palette.success, size: 26),
          ],
        ),
      ),
    );
  }
}

/// A hadith half learned, with the way back into it.
class _LearningRow extends StatelessWidget {
  const _LearningRow({required this.hadith, required this.memo});

  final Hadith hadith;
  final MemoProgress memo;

  @override
  Widget build(BuildContext context) {
    final parts = memoParts(hadith.text).length;
    return _Row(
      hadith: hadith,
      look: LeafLook.complete,
      status: 'حفظت ${toArabicDigits(memo.parts)} من '
          '${toArabicDigits(parts)} أجزاء',
      action: 'أكمل',
      onTap: () => _open(context, MemorizeScreen(hadith: hadith)),
    );
  }
}

/// One memorized hadith in the full list. Tapping recites it: a review if
/// it is due, practice otherwise.
class _HeldRow extends StatelessWidget {
  const _HeldRow({
    required this.hadith,
    required this.memo,
    required this.status,
    required this.dueNow,
  });

  final Hadith hadith;
  final MemoProgress memo;
  final String status;
  final bool dueNow;

  @override
  Widget build(BuildContext context) {
    return _Row(
      hadith: hadith,
      look: LeafLook.memorized,
      status: status,
      highlight: dueNow,
      strength: memo.box ?? 0,
      onTap: () => _open(context, ReviewScreen(hadith: hadith)),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.hadith,
    required this.look,
    required this.status,
    required this.onTap,
    this.action,
    this.highlight = false,
    this.strength,
  });

  final Hadith hadith;
  final LeafLook look;
  final String status;
  final VoidCallback onTap;
  final String? action;
  final bool highlight;

  /// Reviews in a row that went well, out of [kReviewIntervals].
  final int? strength;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      button: true,
      label: '${hadith.title}، $status',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                LeafNumber(number: hadith.number, look: look, height: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hadith.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: kSans,
                          fontSize: 14.5,
                          height: AppLeading.chrome,
                          fontWeight: FontWeight.w700,
                          color: palette.bodyText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              status,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: kSans,
                                fontSize: 12.5,
                                height: AppLeading.chrome,
                                fontWeight: highlight
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: highlight
                                    ? palette.goldText
                                    : palette.mutedText,
                              ),
                            ),
                          ),
                          if (strength case final strength?) ...[
                            const SizedBox(width: 8),
                            _Strength(strength),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (action != null)
                  Text(
                    action!,
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 14,
                      height: AppLeading.chrome,
                      fontWeight: FontWeight.w800,
                      color: palette.success,
                    ),
                  ),
                Icon(
                  // chevron_left: "forward" in a right-to-left app.
                  Icons.chevron_left_rounded,
                  size: 20,
                  color: palette.mutedText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// How firmly a hadith is held: one dot for each review in a row that went
/// well, all of them once it is kept.
class _Strength extends StatelessWidget {
  const _Strength(this.box);

  final int box;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < kReviewIntervals.length; i++)
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < box
                  ? palette.ornamentGold
                  : palette.mutedText.withValues(alpha: .22),
            ),
          ),
      ],
    );
  }
}

/// The easiest hadith to memorize next: the shortest one read.
class _StartCard extends StatelessWidget {
  const _StartCard({required this.hadith, required this.first});

  final Hadith hadith;

  /// Nothing memorized yet, so this is where memorizing begins.
  final bool first;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final parts = memoParts(hadith.text).length;

    return ParchmentCard(
      showWatermark: false,
      showCornerOrnaments: false,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LeafNumber(number: hadith.number, look: LeafLook.complete),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      first ? 'ابدأ من هنا' : 'حديث جديد تحفظه',
                      style: TextStyle(
                        fontFamily: kSans,
                        fontSize: 13,
                        height: AppLeading.chrome,
                        fontWeight: FontWeight.w700,
                        color: palette.mutedText,
                      ),
                    ),
                    Text(
                      hadith.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: kSans,
                        fontSize: 16,
                        height: AppLeading.chrome,
                        fontWeight: FontWeight.w800,
                        color: palette.bodyText,
                      ),
                    ),
                    Text(
                      parts == 1
                          ? 'أقصر ما قرأت، ويُحفظ في جلسة واحدة.'
                          : 'أقصر ما قرأت ولم تحفظه بعد.',
                      style: TextStyle(
                        fontFamily: kSans,
                        fontSize: 12.5,
                        height: AppLeading.chrome,
                        color: palette.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppButton(
            text: 'ابدأ حفظه',
            isSecondary: !first,
            onPressed: () => _open(context, MemorizeScreen(hadith: hadith)),
          ),
        ],
      ),
    );
  }
}

/// Nothing memorized or started yet.
class _Empty extends StatelessWidget {
  const _Empty({required this.start});

  final Hadith? start;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final start = this.start;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      children: [
        const Center(
          child: LeafSwatch(LeafLook.memorized, height: 72),
        ),
        const SizedBox(height: 14),
        Text(
          'لم تحفظ حديثاً بعد',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: kSans,
            fontSize: 18,
            height: AppLeading.chrome,
            fontWeight: FontWeight.w800,
            color: palette.bodyText,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          start == null
              ? 'بعد أن تقرأ حديثاً تستطيع حفظه من صفحته، جزءاً جزءاً، '
                  'ونذكّرك بمراجعته في وقتها حتى يثبت.'
              : 'تحفظ الحديث جزءاً جزءاً، ثم نذكّرك بمراجعته في وقتها '
                  'حتى يثبت. وكل حديث تحفظه تصير ورقته ذهبية في شجرتك.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: kSans,
            fontSize: 14,
            height: AppLeading.body,
            color: palette.mutedText,
          ),
        ),
        if (start != null) ...[
          const SizedBox(height: 20),
          _StartCard(hadith: start, first: true),
        ],
      ],
    );
  }
}

/// The way in from رحلتي: one card that says what memorizing asks of the
/// reader today, and opens [MemoListScreen].
class MemoEntry extends StatelessWidget {
  const MemoEntry({super.key, required this.data, required this.today});

  final JourneyData data;
  final String today;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final plan = MemoPlan.of(data, today);
    final hadiths = HadithRepository();
    String title(int number) => hadiths.getByNumber(number)?.title ?? '';

    final (heading, line) = switch (plan) {
      MemoPlan(isEmpty: true, start: final start?) => (
          'ابدأ حفظك',
          'ابدأ بحفظ «${start.title}»',
        ),
      MemoPlan(isEmpty: true) => (
          'ابدأ حفظك',
          'بعد أن تقرأ حديثاً تستطيع حفظه، جزءاً جزءاً.',
        ),
      MemoPlan(due: [final only]) => (
          'راجع حفظك',
          'موعد مراجعة «${title(only)}» اليوم',
        ),
      MemoPlan(due: final due) when due.isNotEmpty => (
          'راجع حفظك',
          'موعد مراجعة ${due.length == 2 ? 'حديثين' : hadithCount(due.length)} اليوم',
        ),
      MemoPlan(doneToday: true) => (
          'راجع حفظك',
          'أتممت مراجعة اليوم',
        ),
      MemoPlan(held: []) => (
          'راجع حفظك',
          'أكمل حفظ «${title(plan.learning.first)}»',
        ),
      _ => (
          'راجع حفظك',
          plan.next == null
              ? 'في حفظك ${hadithCount(plan.held.length)}، وكلها ثابتة.'
              : 'في حفظك ${hadithCount(plan.held.length)}. المراجعة '
                  'القادمة ${_whenFrom(data.memoOf(plan.next!).due!, today)}.',
        ),
    };
    final due = plan.due.length;

    return ParchmentCard(
      elevated: due > 0,
      borderColor: due > 0 ? palette.ornamentGold : null,
      showWatermark: false,
      showCornerOrnaments: false,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      semanticLabel: '$heading، $line',
      onTap: () => _open(context, const MemoListScreen()),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.surfaceSunken,
              shape: BoxShape.circle,
            ),
            child: const LeafSwatch(LeafLook.memorized, height: 38),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  heading,
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 17,
                    height: AppLeading.chrome,
                    fontWeight: FontWeight.w800,
                    color: palette.goldText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  line,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 13.5,
                    height: AppLeading.chrome,
                    fontWeight: due > 0 ? FontWeight.w700 : FontWeight.w500,
                    color: due > 0 ? palette.bodyText : palette.mutedText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (due > 0)
            Container(
              constraints: const BoxConstraints(minWidth: 26),
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.ornamentGold,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                toArabicDigits(due),
                style: const TextStyle(
                  fontFamily: kSans,
                  fontSize: 14,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkEmerald,
                ),
              ),
            )
          else if (plan.doneToday)
            Icon(Icons.check_circle_rounded, color: palette.success, size: 24),
          Icon(Icons.chevron_left_rounded, color: palette.mutedText),
        ],
      ),
    );
  }
}
