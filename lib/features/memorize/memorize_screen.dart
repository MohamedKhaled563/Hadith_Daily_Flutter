import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_motion.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/botanical_sheet.dart';
import '../../core/widgets/circle_icon_button.dart';
import '../../core/widgets/parchment_card.dart';
import '../../data/journey/journey_copy.dart';
import '../../data/journey/journey_repository.dart';
import '../../data/journey/memorization.dart';
import '../../data/models/hadith.dart';

/// The three steps of learning one part of a hadith by heart.
enum MemoStep { read, complete, recite }

/// Learning a hadith by heart, one part a session — see [memoParts]. Three
/// steps: read it sentence by sentence, fill in words as more of them are
/// hidden, then recite it from memory and say honestly whether you had it.
class MemorizeScreen extends StatefulWidget {
  const MemorizeScreen({super.key, required this.hadith});

  final Hadith hadith;

  @override
  State<MemorizeScreen> createState() => _MemorizeScreenState();
}

class _MemorizeScreenState extends State<MemorizeScreen> {
  final _journey = JourneyRepository();

  late final List<List<String>> _parts = memoParts(widget.hadith.text);

  /// The part this session is for: the first one not yet learned.
  late final int _part = _journey.data
      .memoOf(widget.hadith.number)
      .parts
      .clamp(0, _parts.length - 1);

  List<String> get _sentences => _parts[_part];

  MemoStep _step = MemoStep.read;
  int _sentence = 0;

  /// 1 or 2: one word in three hidden, then two in three.
  int _level = 1;
  bool _shown = false;
  final Set<int> _revealed = {};

  void _go(MemoStep step, {int level = 1}) {
    AppHaptics.selection();
    setState(() {
      _step = step;
      _level = level;
      _shown = false;
      _revealed.clear();
    });
  }

  Future<void> _learned() async {
    final navigator = Navigator.of(context);
    final outcome = _journey.learnPart(
      widget.hadith.number,
      totalParts: _parts.length,
    );
    AppHaptics.success();
    final words = outcome.milestone != null
        ? JourneyCopy.memoMilestone(
            outcome.milestone!,
            lastTitle: widget.hadith.title,
          )
        : outcome.memorized
            ? JourneyCopy.memorized(widget.hadith.title)
            : JourneyCopy.partLearned(
                outcome.progress.parts,
                outcome.totalParts,
              );
    await showBotanicalSheet<void>(
      context: context,
      title: words.title,
      subtitle: words.body,
      child: Builder(
        builder: (sheet) => AppButton(
          text: 'تم',
          onPressed: () => Navigator.pop(sheet),
        ),
      ),
    );
    if (mounted) navigator.pop(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return AppScreen(
      child: Column(
        children: [
          const SizedBox(height: 8),
          _Header(
            title: 'حفظ «${widget.hadith.title}»',
            subtitle: _parts.length > 1
                ? 'الجزء ${toArabicDigits(_part + 1)} من '
                    '${toArabicDigits(_parts.length)}'
                : null,
          ),
          const SizedBox(height: 12),
          _StepRow(step: _step),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                28 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                ParchmentCard(
                  elevated: true,
                  child: switch (_step) {
                    MemoStep.read => _ReadSentences(
                        sentences: _sentences,
                        current: _sentence,
                      ),
                    MemoStep.complete => HiddenText(
                        text: _sentences.join(' '),
                        level: _level,
                        revealed: _revealed,
                        onReveal: (i) => setState(() => _revealed.add(i)),
                      ),
                    MemoStep.recite => HiddenText(
                        text: _sentences.join(' '),
                        level: _shown ? 0 : 3,
                        revealed: _revealed,
                        onReveal: (i) => setState(() => _revealed.add(i)),
                      ),
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  switch (_step) {
                    MemoStep.read =>
                      'اقرأ الجملة المضيئة، وردّدها حتى تألفها، ثم انتقل إلى التالية.',
                    MemoStep.complete =>
                      'أكمل الكلمات الناقصة من ذاكرتك، وإن احتجت فالمس الفراغ ليظهر.',
                    MemoStep.recite => _shown
                        ? 'قارن بما سمّعته، وقل بصدق: هل كان معك؟'
                        : 'سمّعه من ذاكرتك، بصوت أو في نفسك، ثم أظهر النص لتقارن.',
                  },
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: palette.mutedText,
                    height: AppLeading.body,
                  ),
                ),
                const SizedBox(height: 14),
                ..._actions(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _actions() {
    switch (_step) {
      case MemoStep.read:
        final last = _sentence >= _sentences.length - 1;
        return [
          AppButton(
            text: last ? 'أخفِ بعض الكلمات' : 'الجملة التالية',
            onPressed: last
                ? () => _go(MemoStep.complete)
                : () {
                    AppHaptics.selection();
                    setState(() => _sentence++);
                  },
          ),
          if (_sentence > 0) ...[
            const SizedBox(height: 8),
            AppButton(
              text: 'من البداية',
              isSecondary: true,
              onPressed: () => setState(() => _sentence = 0),
            ),
          ],
        ];
      case MemoStep.complete:
        return [
          AppButton(
            text: _level == 1 ? 'أخفِ أكثر' : 'سمّعه كاملاً',
            onPressed: _level == 1
                ? () => _go(MemoStep.complete, level: 2)
                : () => _go(MemoStep.recite),
          ),
          const SizedBox(height: 8),
          AppButton(
            text: 'اقرأه مرة أخرى',
            isSecondary: true,
            onPressed: () {
              _sentence = 0;
              _go(MemoStep.read);
            },
          ),
        ];
      case MemoStep.recite:
        if (!_shown) {
          return [
            AppButton(
              text: 'أظهر النص',
              onPressed: () => setState(() => _shown = true),
            ),
          ];
        }
        return [
          AppButton(
            text: 'حفظته',
            icon: Icons.check_rounded,
            onPressed: _learned,
          ),
          const SizedBox(height: 8),
          AppButton(
            text: 'ليس بعد',
            isSecondary: true,
            onPressed: () => _go(MemoStep.complete),
          ),
        ];
    }
  }
}

/// Reciting a memorized hadith, then saying whether it was all there. Only a
/// review that is due counts; any other is practice.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.hadith});

  final Hadith hadith;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final _journey = JourneyRepository();
  bool _shown = false;
  final Set<int> _revealed = {};
  String? _result;

  late final bool _due =
      _journey.data.memoOf(widget.hadith.number).isDue(_journey.today);

  void _answer(bool remembered) {
    final outcome = _journey.review(
      widget.hadith.number,
      remembered: remembered,
    );
    remembered ? AppHaptics.success() : AppHaptics.tap();
    final due = outcome.progress.due;
    final days = due == null
        ? null
        : DateTime.parse(due).difference(DateTime.parse(_journey.today)).inDays;
    setState(() {
      _result = outcome.counted
          ? JourneyCopy.reviewed(remembered: remembered, days: days)
          : 'مراجعة حرة، لم تُسجَّل. موعد مراجعته كما هو.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final result = _result;

    return AppScreen(
      child: Column(
        children: [
          const SizedBox(height: 8),
          _Header(
            title: 'مراجعة «${widget.hadith.title}»',
            subtitle: _due ? null : 'ليست مستحقة اليوم، فهذه مراجعة حرة',
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                28 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                ParchmentCard(
                  elevated: true,
                  child: HiddenText(
                    text: widget.hadith.text,
                    level: _shown ? 0 : 3,
                    revealed: _revealed,
                    onReveal: (i) => setState(() => _revealed.add(i)),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  result ??
                      (_shown
                          ? 'قارن بما سمّعته، وقل بصدق: هل كان كله معك؟'
                          : 'سمّعه من ذاكرتك، ثم أظهر النص لتقارن. المس أي فراغ إن احتجت تلميحاً.'),
                  textAlign: TextAlign.center,
                  style: (result != null
                          ? textTheme.bodyMedium?.copyWith(
                              color: palette.goldText,
                              fontWeight: FontWeight.w700,
                            )
                          : textTheme.bodySmall
                              ?.copyWith(color: palette.mutedText))
                      ?.copyWith(height: AppLeading.body),
                ),
                const SizedBox(height: 14),
                if (result != null)
                  AppButton(
                    text: 'تم',
                    onPressed: () => Navigator.maybePop(context),
                  )
                else if (!_shown)
                  AppButton(
                    text: 'أظهر النص',
                    onPressed: () => setState(() => _shown = true),
                  )
                else ...[
                  AppButton(
                    text: 'تذكرته',
                    icon: Icons.check_rounded,
                    onPressed: () => _answer(true),
                  ),
                  const SizedBox(height: 8),
                  AppButton(
                    text: 'نسيت بعضه',
                    isSecondary: true,
                    onPressed: () => _answer(false),
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

class _Header extends StatelessWidget {
  const _Header({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Padding(
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
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(fontSize: 18),
                ),
              ),
              const SizedBox(width: CircleIconButton.slot + 8),
            ],
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: textTheme.bodySmall?.copyWith(
              color: palette.goldText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

/// Where the reader is among the three steps.
class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});

  final MemoStep step;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const labels = ['اقرأ', 'أكمل', 'سمّع'];

    return Semantics(
      label: 'الخطوة ${toArabicDigits(step.index + 1)} من ٣: '
          '${labels[step.index]}',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0)
              Container(
                width: 18,
                height: 1.5,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: palette.cardBorder,
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: i == step.index ? palette.ornamentGold : palette.surface,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: i <= step.index
                      ? palette.ornamentGold
                      : palette.cardBorder,
                ),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: i == step.index
                      ? palette.parchmentTop
                      : palette.mutedText,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The part's sentences, the current one lit and the rest quiet.
class _ReadSentences extends StatelessWidget {
  const _ReadSentences({required this.sentences, required this.current});

  final List<String> sentences;
  final int current;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < sentences.length; i++)
            TextSpan(
              text: '${sentences[i]} ',
              style: AppTextStyles.hadithText.copyWith(
                color: i == current
                    ? palette.bodyText
                    : palette.mutedText
                        .withValues(alpha: i < current ? .7 : .35),
                fontWeight: i == current ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
        ],
      ),
      textAlign: TextAlign.start,
    );
  }
}

/// A passage with words hidden by [hiddenWords] at [level]. A hidden word
/// keeps its exact place and size, as a blank the reader can tap to reveal.
class HiddenText extends StatelessWidget {
  const HiddenText({
    super.key,
    required this.text,
    required this.level,
    required this.revealed,
    required this.onReveal,
  });

  final String text;
  final int level;
  final Set<int> revealed;
  final ValueChanged<int> onReveal;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final words = text.trim().split(RegExp(r'\s+'));
    final hidden = hiddenWords(words.length, level);
    final style = AppTextStyles.hadithText.copyWith(color: palette.bodyText);

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (var i = 0; i < words.length; i++)
          if (!hidden[i] || revealed.contains(i))
            Text(words[i], style: style)
          else
            Semantics(
              button: true,
              label: 'كلمة مخفية، المس لإظهارها',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => onReveal(i),
                child: Container(
                  decoration: BoxDecoration(
                    color: palette.surfaceSunken,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: palette.cardBorder),
                  ),
                  child: Text(
                    words[i],
                    style: style.copyWith(color: Colors.transparent),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}
