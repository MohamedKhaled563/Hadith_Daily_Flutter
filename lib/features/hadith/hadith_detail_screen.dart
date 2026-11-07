import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_links.dart';
import '../../core/auth/sign_in_gate.dart';
import '../../core/share/share_sheet.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_motion.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/widgets/circle_icon_button.dart';
import '../../core/widgets/entrance.dart';
import '../../core/widgets/parchment_card.dart';
import '../../core/widgets/smooth_page_route.dart';
import '../../core/widgets/tap_target.dart';
import '../../data/journey/journey_copy.dart';
import '../../data/journey/journey_repository.dart';
import '../../data/journey/memorization.dart';
import '../../data/journey/reading_tracker.dart';
import '../../data/models/hadith.dart';
import '../../data/repositories/hadith_repository.dart';
import '../../data/services/journey_reminders.dart';
import '../journey/completion_sheet.dart';
import '../journey/journey_links.dart';
import '../journey/journey_share_sheet.dart';
import '../memorize/memorize_screen.dart';
import 'hadith_explanation_screen.dart';

/// The hadith, its short explanation, and the reading the journey counts.
///
/// A gold thread fills beside the hadith and beside the short explanation
/// while each stays on screen (see [ReadingTracker]); there is no countdown,
/// since a timer teaches people to wait, not read. Once both have had their
/// time the leaf turns green, and «قرأت الحديث ونويت العمل به» can be
/// pressed. Pressing it is what turns the leaf gold: the time alone is not
/// enough, and neither is the press. The full explanation stays one tap
/// away, for whoever wants it.
class HadithDetailScreen extends StatefulWidget {
  const HadithDetailScreen({super.key, required this.hadith});

  final Hadith hadith;

  @override
  State<HadithDetailScreen> createState() => _HadithDetailScreenState();
}

class _HadithDetailScreenState extends State<HadithDetailScreen>
    with WidgetsBindingObserver {
  static const _tickEvery = Duration(milliseconds: 300);

  /// The most one tick can count. A timer held up by a suspended app must
  /// not arrive as reading time.
  static const _longestTick = Duration(seconds: 1);

  /// With no touch for this long the phone is probably on the table, so time
  /// stops counting. A long section asks for more, in [_idleLimit].
  static const _shortestIdleLimit = Duration(seconds: 45);

  final HadithRepository _repo = HadithRepository();

  Hadith get hadith => widget.hadith;

  bool get _isBookmarked => _repo.isHadithFavorite(hadith.number);

  late final ReadingTracker _tracker =
      ReadingTracker.sections(ReadingRule.pageSections(hadith));
  late final List<GlobalKey> _sectionKeys =
      List.generate(2, (_) => GlobalKey());
  final _viewportKey = GlobalKey();

  Timer? _ticker;
  DateTime _lastTick = DateTime.now();
  DateTime _lastTouch = DateTime.now();
  bool _inForeground = true;

  /// Whether the text and summary have had their time, already reported to
  /// the journey (the green leaf).
  bool _textRecorded = false;

  /// Whether the reader confirmed, this visit.
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repo.favoritesListenable.addListener(_onFavoritesChanged);
    JourneyRepository().listenable.addListener(_onFavoritesChanged);
    _ticker = Timer.periodic(_tickEvery, _onTick);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    JourneyRepository().listenable.removeListener(_onFavoritesChanged);
    _repo.favoritesListenable.removeListener(_onFavoritesChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _inForeground = state == AppLifecycleState.resumed;
  }

  void _onFavoritesChanged() {
    if (mounted) setState(() {});
  }

  double _progressOf(int section) {
    if (_finished) return 1;
    return section < _tracker.length ? _tracker.progressOf(section) : 0;
  }

  Duration get _idleLimit {
    final waiting = _tracker.firstUnread;
    if (waiting == null) return _shortestIdleLimit;
    final twice = _tracker.neededAt(waiting) * 2;
    return twice > _shortestIdleLimit ? twice : _shortestIdleLimit;
  }

  void _onTick(Timer _) {
    final now = DateTime.now();
    final elapsed = now.difference(_lastTick);
    _lastTick = now;

    if (!mounted || !_inForeground || _finished || _tracker.isComplete) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    if (now.difference(_lastTouch) > _idleLimit) return;

    final before = _shownSteps();
    _tracker.tick(
      elapsed > _longestTick ? _longestTick : elapsed,
      _sectionsOnScreen(),
    );
    if (_tracker.isComplete && !_textRecorded) {
      _textRecorded = true;
      JourneyRepository().recordTextRead(hadith.number);
    }
    // Redraw only when the thread visibly moves, not on every tick: this
    // page is often left open, and the thread animates between steps anyway.
    if (_shownSteps() != before) setState(() {});
  }

  static const _threadSteps = 24;

  String _shownSteps() => [
        for (var i = 0; i < _tracker.length; i++)
          (_tracker.progressOf(i) * _threadSteps).floor(),
        _tracker.isComplete,
      ].join(',');

  /// Which sections are readable right now. Measured against the screen as
  /// well as the section: one taller than the screen can never be mostly
  /// visible, and must still count while it fills the view.
  List<int> _sectionsOnScreen() {
    final viewport = _viewportKey.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return const [];

    final viewTop = viewport.localToGlobal(Offset.zero).dy;
    final viewBottom = viewTop + viewport.size.height;
    final onScreen = <int>[];
    for (var i = 0; i < _tracker.length; i++) {
      final box = _sectionKeys[i].currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      final showing =
          math.min(top + box.size.height, viewBottom) - math.max(top, viewTop);
      final enough = math.min(box.size.height * .6, viewport.size.height * .5);
      if (showing >= enough) onScreen.add(i);
    }
    return onScreen;
  }

  /// «قرأت الحديث ونويت العمل به»: the reader's own word, after the time.
  Future<void> _confirm() async {
    final navigator = Navigator.of(context);
    final journey = JourneyRepository();

    setState(() => _finished = true);
    final outcome = journey.recordFullRead(
      hadith.number,
      seconds: _tracker.activeSeconds,
    );
    AppHaptics.success();

    final nextNumber = journey.nextHadithNumber;
    final next =
        nextNumber == null ? null : HadithRepository().getByNumber(nextNumber);
    final choice = await showCompletionSheet(
      context: context,
      hadith: hadith,
      outcome: outcome,
      hasNext: next != null,
      canMemorize: !journey.data.memoOf(hadith.number).isMemorized,
    );
    if (!mounted) return;

    // Left unawaited: the reader's choice goes first, and a system dialog
    // waiting for an answer must not hold it up.
    unawaited(JourneyReminders.askAfterReading());

    switch (choice) {
      case CompletionChoice.write:
        JourneyLinks.openWriting(hadith);
      case CompletionChoice.next when next != null:
        unawaited(navigator.pushReplacement(
          appPageRoute(child: HadithDetailScreen(hadith: next)),
        ));
      case CompletionChoice.share:
        await shareHadith(context, hadith);
      case CompletionChoice.memorize:
        unawaited(navigator.push(
          appPageRoute(child: MemorizeScreen(hadith: hadith)),
        ));
      case CompletionChoice.next:
      case null:
        break;
    }
  }

  Future<void> _toggleBookmark() async {
    if (!await requireSignIn(context, reason: kFavoritesSignInReason)) return;
    if (!mounted) return;
    AppHaptics.toggle();
    setState(() => _repo.toggleFavoriteHadith(hadith.number));

    showAppSnack(
      context,
      _isBookmarked ? 'تم حفظ الحديث في المفضلة' : 'تمت الإزالة من المفضلة',
      tone: _isBookmarked ? SnackTone.success : SnackTone.neutral,
      action: _isBookmarked ? null : undoAction(context, _toggleBookmark),
    );
  }

  void _copyHadith(BuildContext context) {
    final buffer = StringBuffer()..writeln('« ${hadith.title} »');
    if (hadith.mukhrij.isNotEmpty) {
      buffer.writeln('رواه ${hadith.mukhrij}');
    }
    buffer.writeln('الحديث رقم ${hadith.number} من الأربعين النووية\n');
    buffer.writeln('نص الحديث:');
    if (hadith.isnad.isNotEmpty) {
      buffer.writeln(hadith.isnad);
    }
    buffer
      ..writeln(hadith.text)
      ..writeln('\nالمصدر: ${hadith.reference}');

    if (hadith.shortExplanation.isNotEmpty) {
      buffer
        ..writeln('\nخلاصة الشرح:')
        ..writeln(hadith.shortExplanation);
    }
    if (hadith.explanation.isNotEmpty) {
      buffer
        ..writeln('\nالشرح:')
        ..writeln(hadith.explanation);
    }
    if (hadith.keyLessons.isNotEmpty) {
      buffer.writeln('\nمن فوائد الحديث:');
      for (final lesson in hadith.keyLessons) {
        buffer.writeln('• $lesson');
      }
    }

    final link = AppLinks.storeLink;
    if (link != null) {
      buffer.writeln('\nمن تطبيق «طيّب قلبك»');
      buffer.writeln(link);
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    showAppSnack(
      context,
      'تم نسخ نص الحديث وشرحه بالكامل',
      tone: SnackTone.success,
    );
  }

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
            child: LayoutBuilder(
              builder: (context, constraints) {
                // The three action buttons ran into the centred emblem on
                // narrower phones (e.g. a 390pt iPhone). The buttons keep
                // their 44dp size; the header adapts around them instead:
                //   roomy   — 6dp gaps, full emblem
                //   compact — no extra gaps (the 48dp slots still leave 4dp
                //             between circles), smaller emblem
                //   tight   — no emblem at all
                const breathingRoom = 4.0;
                const fullEmblem = 36.0;
                const compactEmblem = 26.0;
                bool fits(double gap, double emblem) {
                  final cluster = CircleIconButton.slot * 3 + gap * 2;
                  final emblemHalf = (emblem + 11) / 2;
                  return constraints.maxWidth / 2 - emblemHalf >=
                      cluster + breathingRoom;
                }

                final roomy = fits(6, fullEmblem);
                final double gap = roomy ? 6 : 0;
                final double? emblemSize = roomy
                    ? fullEmblem
                    : fits(0, compactEmblem)
                        ? compactEmblem
                        : null;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Centred regardless of how wide the side clusters are —
                    // spaceBetween used to shift this toward whichever side had
                    // fewer/narrower buttons. Stack sizes itself to the tallest
                    // child (the emblem), so the 44dp buttons sit centred inside.
                    if (emblemSize != null)
                      EmblemBadge(size: emblemSize)
                    else
                      const SizedBox(height: CircleIconButton.slot),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      // chevron_right reads as "back" under RTL.
                      child: CircleIconButton(
                        icon: Icons.chevron_right_rounded,
                        semanticLabel: 'رجوع',
                        onTap: () => Navigator.maybePop(context),
                      ),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleIconButton(
                            icon: _isBookmarked
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            semanticLabel: 'حفظ الحديث في المفضلة',
                            toggled: _isBookmarked,
                            onTap: _toggleBookmark,
                          ),
                          SizedBox(width: gap),
                          CircleIconButton(
                            icon: Icons.copy_rounded,
                            semanticLabel: 'نسخ النص الكامل مع الشرح والفوائد',
                            onTap: () => _copyHadith(context),
                          ),
                          SizedBox(width: gap),
                          CircleIconButton(
                            icon: Icons.ios_share_rounded,
                            semanticLabel: 'مشاركة الحديث كصورة',
                            onTap: () => showShareSheet(
                              context: context,
                              message: hadith.text,
                              hadithTitle: hadith.title,
                              hadithNumber: toArabicDigits(hadith.number),
                              category: hadith.reference,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Entrance(
              child: Semantics(
                header: true,
                child: Column(
                  children: [
                    Text(
                      hadith.title,
                      textAlign: TextAlign.center,
                      style: textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'الحديث رقم ${toArabicDigits(hadith.number)} من الأربعين النووية',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: palette.goldText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Listener(
              onPointerDown: (_) => _lastTouch = DateTime.now(),
              onPointerMove: (_) => _lastTouch = DateTime.now(),
              child: ListView(
                key: _viewportKey,
                padding: EdgeInsets.fromLTRB(
                  20,
                  6,
                  20,
                  32 + MediaQuery.viewPaddingOf(context).bottom,
                ),
                children: [
                  Entrance.staggered(
                    index: 1,
                    child: ParchmentCard(
                      elevated: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _CardHeading(
                            icon: Icons.format_quote_rounded,
                            title: 'نص الحديث الشريف',
                          ),
                          const SizedBox(height: 14),
                          _ThreadedSection(
                            key: _sectionKeys[0],
                            progress: _progressOf(0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (hadith.isnad.isNotEmpty) ...[
                                  // The isnad/ananah phrase that introduces the hadith
                                  // (عنعنة) — set apart from the hadith text itself so
                                  // the reader can tell where the chain of narration
                                  // ends and the Prophet's words begin.
                                  Text(
                                    hadith.isnad,
                                    textAlign: TextAlign.start,
                                    // No italic. Arabic script has no italic form, and
                                    // no oblique Amiri is bundled — so `FontStyle.italic`
                                    // made the engine synthesise a slant by shearing the
                                    // glyphs, which is a Latin convention applied to a
                                    // script that does not take it. The chain of
                                    // narration is set apart by size and colour instead,
                                    // which is how Arabic typography does this.
                                    //
                                    // mutedText rather than bodyText at 70%: it is the
                                    // token that was measured against these surfaces,
                                    // and an arbitrary alpha was not.
                                    style: AppTextStyles.hadithText.copyWith(
                                      fontSize: 15,
                                      color: palette.mutedText,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                // The Prophetic text in Amiri — a Naskh face — set apart
                                // from the Tajawal UI chrome around it.
                                Text(
                                  hadith.text,
                                  textAlign: TextAlign.start,
                                  style: AppTextStyles.hadithText.copyWith(
                                    color: palette.bodyText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (hadith.mukhrij.isNotEmpty ||
                              (hadith.source?.trim().isNotEmpty ?? false)) ...[
                            const SizedBox(height: 16),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  // Labeled explicitly — this used to be a bare
                                  // name with a person icon and no label, which
                                  // is what read as the same thing as the
                                  // reference chip below (a tester flagged the
                                  // two as indistinguishable).
                                  if (hadith.mukhrij.isNotEmpty)
                                    _AttributionChip(
                                      icon: Icons.menu_book_rounded,
                                      label: 'رواه',
                                      value: hadith.mukhrij,
                                    ),
                                  // Deliberately reads `hadith.source` here, not
                                  // `hadith.reference` — reference falls back to
                                  // the generic "من الأربعين النووية" book title
                                  // when no real source was entered (true for
                                  // all 42 bundled hadiths today), and showing
                                  // that fallback as "أخرجه: ..." reads as a
                                  // fabricated isnad attribution. `source` has
                                  // no such fallback, so this chip only appears
                                  // once a real transmitter (e.g. "رواه مسلم")
                                  // is actually entered in the data.
                                  if (hadith.source?.trim().isNotEmpty ?? false)
                                    _AttributionChip(
                                      icon: Icons.auto_stories_rounded,
                                      label: 'أخرجه',
                                      value: hadith.source!.trim(),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (hadith.shortExplanation.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Entrance.staggered(
                      index: 2,
                      child: ParchmentCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _CardHeading(
                              icon: Icons.summarize_rounded,
                              title: 'خلاصة الشرح',
                            ),
                            const SizedBox(height: 12),
                            _ThreadedSection(
                              key: _sectionKeys[1],
                              progress: _progressOf(1),
                              child: Text(
                                hadith.shortExplanation,
                                textAlign: TextAlign.start,
                                style: TextStyle(
                                  fontFamily: kSans,
                                  fontSize: 14.5,
                                  height: AppLeading.body,
                                  color: palette.bodyText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _IntentionControl(
                    finished: _finished,
                    // A screen reader hears the text rather than scrolling
                    // through it, so time on screen means nothing there.
                    ready: _tracker.isComplete ||
                        MediaQuery.accessibleNavigationOf(context),
                    onConfirm: _confirm,
                  ),
                  if (JourneyRepository()
                      .data
                      .progressOf(hadith.number)
                      .isComplete) ...[
                    const SizedBox(height: 14),
                    _MemoCard(hadith: hadith),
                  ],
                  if (hadith.explanation.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Entrance.staggered(
                      index: 3,
                      child: _ExplanationTeaserCard(hadith: hadith),
                    ),
                  ],
                  if (hadith.narratorBio.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Entrance.staggered(
                      index: 4,
                      child: ParchmentCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _CardHeading(
                              icon: Icons.person_outline_rounded,
                              title: 'عن راوي الحديث',
                            ),
                            const SizedBox(height: 12),
                            Text(
                              hadith.narratorBio,
                              textAlign: TextAlign.start,
                              style: TextStyle(
                                fontFamily: kSans,
                                fontSize: 14,
                                height: AppLeading.body,
                                color: palette.bodyText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (hadith.keyLessons.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Entrance.staggered(
                      index: 5,
                      child: ParchmentCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _CardHeading(
                              icon: Icons.spa_rounded,
                              title: 'من فوائد الحديث وهداياته',
                            ),
                            const SizedBox(height: 12),
                            for (final lesson in hadith.keyLessons)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Container(
                                        width: 5,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: palette.goldText,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        lesson,
                                        textAlign: TextAlign.start,
                                        style: TextStyle(
                                          fontFamily: kSans,
                                          fontSize: 13.5,
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
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardHeading extends StatelessWidget {
  const _CardHeading({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        Icon(icon, size: 20, color: palette.goldText),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 16,
              height: AppLeading.chrome,
              fontWeight: FontWeight.w700,
              color: palette.goldText,
            ),
          ),
        ),
      ],
    );
  }
}

/// A single labeled fact about the hadith's attribution — who extracted/
/// collected it (رواه) or who transmitted/compiled it (أخرجه). Kept as
/// one small chip type used twice rather than two bespoke pills, so
/// "رواه البخاري ومسلم" and "أخرجه مسلم" always read the same way
/// instead of looking like two unrelated bits of chrome.
class _AttributionChip extends StatelessWidget {
  const _AttributionChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      constraints: const BoxConstraints(maxWidth: 260),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: palette.goldText),
          const SizedBox(width: 6),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label ',
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 12,
                      height: AppLeading.chrome,
                      fontWeight: FontWeight.w500,
                      color: palette.goldText.withValues(alpha: 0.75),
                    ),
                  ),
                  TextSpan(
                    text: value,
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// A teaser for "شرح الحديث وبيانه" — the opening line or two of the full
/// explanation, fading out, with a button that opens
/// [HadithExplanationScreen]. Kept off this page entirely (rather than an
/// in-place expand) so the hadith page stays a quick reference: text,
/// attribution, the short summary — someone who wants the full scholarly
/// explanation gets an uninterrupted reading screen for it instead of a
/// long block pushing everything else down.
class _ExplanationTeaserCard extends StatelessWidget {
  const _ExplanationTeaserCard({required this.hadith});

  final Hadith hadith;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const label = 'قراءة الشرح كاملاً';

    return ParchmentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeading(
            icon: Icons.menu_book_rounded,
            title: 'شرح الحديث وبيانه',
          ),
          const SizedBox(height: 10),
          // Plain ellipsis rather than a gradient fade: the card's
          // background is itself a gradient (see ParchmentCard), so a
          // flat-color fade never blends cleanly against it and shows up as
          // a visible seam. An ellipsis has no such problem and reads just
          // as clearly as "there's more".
          Text(
            hadith.explanation,
            textAlign: TextAlign.start,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 14.5,
              height: AppLeading.body,
              color: palette.bodyText,
            ),
          ),
          const SizedBox(height: 10),
          TapTarget(
            onTap: () => Navigator.push(
              context,
              appPageRoute(
                child: HadithExplanationScreen(hadith: hadith),
              ),
            ),
            semanticLabel: label,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 13,
                    height: AppLeading.chrome,
                    fontWeight: FontWeight.w700,
                    color: palette.goldText,
                  ),
                ),
                // chevron_left, not _right: this app reads right-to-left
                // (see the back button elsewhere using chevron_right for
                // the same reason), so "forward, keep reading" points left.
                Icon(
                  Icons.chevron_left_rounded,
                  size: 18,
                  color: palette.goldText,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The reader's confirmation, under the short explanation. Shown from the
/// start so the reader knows what the page asks, and pressable once both
/// sections have had their time.
class _IntentionControl extends StatelessWidget {
  const _IntentionControl({
    required this.finished,
    required this.ready,
    required this.onConfirm,
  });

  static const label = 'قرأت الحديث ونويت العمل به';

  final bool finished;
  final bool ready;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    // On parchment like the rest of the page: straight on the background
    // art, a button still waiting was too faint to read.
    return ParchmentCard(
      showWatermark: false,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: finished
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: palette.goldText,
                ),
                const SizedBox(width: 6),
                Text(
                  'قرأته ونويت العمل به',
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 14,
                    height: AppLeading.chrome,
                    fontWeight: FontWeight.w700,
                    color: palette.goldText,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppButton(
                  text: label,
                  icon: Icons.check_rounded,
                  isSecondary: !ready,
                  onPressed: ready ? onConfirm : null,
                ),
                if (!ready) ...[
                  const SizedBox(height: 8),
                  Text(
                    'يكتمل الخيط مع قراءتك، ثم يصير الزر جاهزاً',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 12.5,
                      height: AppLeading.chrome,
                      color: palette.mutedText,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

/// A section with the gold thread running down its start edge.
class _ThreadedSection extends StatelessWidget {
  const _ThreadedSection({
    super.key,
    required this.progress,
    required this.child,
  });

  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return TweenAnimationBuilder<double>(
      tween: Tween(end: progress),
      duration: context.motion(AppDurations.content),
      builder: (context, value, child) => CustomPaint(
        painter: _ThreadPainter(
          progress: value,
          track: palette.surfaceSunken,
          fill: palette.ornamentGold,
          textDirection: Directionality.of(context),
        ),
        child: child,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 14),
        child: child,
      ),
    );
  }
}

class _ThreadPainter extends CustomPainter {
  const _ThreadPainter({
    required this.progress,
    required this.track,
    required this.fill,
    required this.textDirection,
  });

  final double progress;
  final Color track;
  final Color fill;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    const width = 3.0;
    final x =
        textDirection == TextDirection.rtl ? size.width - width / 2 : width / 2;
    final paint = Paint()
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(x, 4),
      Offset(x, size.height - 4),
      paint..color = track,
    );
    if (progress > 0) {
      canvas.drawLine(
        Offset(x, 4),
        Offset(x, 4 + (size.height - 8) * progress),
        paint..color = fill,
      );
    }
  }

  @override
  bool shouldRepaint(_ThreadPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.track != track ||
      oldDelegate.fill != fill ||
      oldDelegate.textDirection != textDirection;
}

/// Memorizing this hadith, once it has been read: start, carry on with the
/// next part, review when due, or recite it for practice.
class _MemoCard extends StatelessWidget {
  const _MemoCard({required this.hadith});

  final Hadith hadith;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final journey = JourneyRepository();
    final memo = journey.data.memoOf(hadith.number);
    final parts = memoParts(hadith.text).length;
    final today = journey.today;

    final (line, action, opens) = switch (memo) {
      MemoProgress(isKept: true) => (
          'ثبت في حفظك، ولا مراجعة مجدولة له.',
          'سمّعه',
          false,
        ),
      MemoProgress(isMemorized: true) when memo.isDue(today) => (
          'مراجعته اليوم.',
          'راجعه الآن',
          false,
        ),
      MemoProgress(isMemorized: true) => (
          'في حفظك. المراجعة القادمة ${_when(memo.due!, today)}.',
          'سمّعه',
          false,
        ),
      MemoProgress(isLearning: true) => (
          'حفظت ${toArabicDigits(memo.parts)} من ${toArabicDigits(parts)} أجزاء.',
          'أكمل حفظه',
          true,
        ),
      _ => (
          parts == 1
              ? 'يُحفظ في جلسة واحدة.'
              : parts == 2
                  ? 'يُحفظ على جلستين.'
                  : 'يُحفظ على ${toArabicDigits(parts)} جلسات.',
          'احفظ هذا الحديث',
          true,
        ),
    };
    final primary = opens || memo.isDue(today);

    return ParchmentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardHeading(
              icon: Icons.psychology_alt_rounded, title: 'الحفظ'),
          const SizedBox(height: 10),
          Text(
            line,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 14,
              height: AppLeading.body,
              color: palette.bodyText,
            ),
          ),
          const SizedBox(height: 12),
          AppButton(
            text: action,
            isSecondary: !primary,
            onPressed: () => Navigator.push(
              context,
              appPageRoute(
                child: opens
                    ? MemorizeScreen(hadith: hadith)
                    : ReviewScreen(hadith: hadith),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _when(String due, String today) {
    final days = DateTime.parse(due).difference(DateTime.parse(today)).inDays;
    return days <= 1 ? 'غداً' : 'بعد ${arabicDayCount(days)}';
  }
}
