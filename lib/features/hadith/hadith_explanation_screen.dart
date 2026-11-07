import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_motion.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/circle_icon_button.dart';
import '../../core/widgets/parchment_card.dart';
import '../../core/widgets/smooth_page_route.dart';
import '../../data/journey/journey_repository.dart';
import '../../data/journey/reading_tracker.dart';
import '../../data/models/hadith.dart';
import '../../data/repositories/hadith_repository.dart';
import '../../data/services/journey_reminders.dart';
import '../journey/completion_sheet.dart';
import '../journey/journey_links.dart';
import '../journey/journey_share_sheet.dart';
import 'hadith_detail_screen.dart';

/// The full "شرح الحديث وبيانه" reading, on its own screen rather than
/// inline on [HadithDetailScreen] — that page's job is a quick reference
/// (text, attribution, the short summary), while a full scholarly
/// explanation can run to several paragraphs and deserves its own
/// uninterrupted reading surface instead of pushing the hadith text further
/// down every time someone opens it.
///
/// This is the reading the journey rewards, so it is where reading is
/// noticed. A gold thread fills beside each paragraph while it stays on
/// screen, and the hadith counts once every paragraph has had its time — see
/// [ReadingTracker] for what that asks. There is no countdown: a timer
/// teaches people to wait, not read.
class HadithExplanationScreen extends StatefulWidget {
  const HadithExplanationScreen({super.key, required this.hadith});

  final Hadith hadith;

  @override
  State<HadithExplanationScreen> createState() =>
      _HadithExplanationScreenState();
}

class _HadithExplanationScreenState extends State<HadithExplanationScreen>
    with WidgetsBindingObserver {
  static const _tickEvery = Duration(milliseconds: 300);

  /// The most one tick can count. A timer held up by a suspended app must
  /// not arrive as reading time.
  static const _longestTick = Duration(seconds: 1);

  /// With no touch for this long the phone is probably on the table, so time
  /// stops counting. A long paragraph asks for more, in [_idleLimit].
  static const _shortestIdleLimit = Duration(seconds: 45);

  Hadith get hadith => widget.hadith;

  late final List<String> _paragraphs =
      ReadingRule.paragraphs(hadith.explanation);
  late final List<int> _words =
      _paragraphs.map(ReadingRule.wordCount).toList();
  late final ReadingTracker _tracker = ReadingTracker(_words);
  late final List<GlobalKey> _paragraphKeys =
      List.generate(_paragraphs.length, (_) => GlobalKey());
  final _viewportKey = GlobalKey();

  Timer? _ticker;
  DateTime _lastTick = DateTime.now();
  DateTime _lastTouch = DateTime.now();
  bool _inForeground = true;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(_tickEvery, _onTick);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _inForeground = state == AppLifecycleState.resumed;
  }

  Duration get _idleLimit {
    final waiting = _tracker.firstUnread;
    if (waiting == null) return _shortestIdleLimit;
    final twice = ReadingRule.neededFor(_words[waiting]) * 2;
    return twice > _shortestIdleLimit ? twice : _shortestIdleLimit;
  }

  void _onTick(Timer _) {
    final now = DateTime.now();
    final elapsed = now.difference(_lastTick);
    _lastTick = now;

    if (!mounted || !_inForeground || _finished || _tracker.isComplete) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    if (now.difference(_lastTouch) > _idleLimit) return;

    _tracker.tick(
      elapsed > _longestTick ? _longestTick : elapsed,
      _paragraphsOnScreen(),
    );
    setState(() {});
  }

  /// Which paragraphs are readable right now. Measured against the screen as
  /// well as the paragraph: one taller than the screen can never be mostly
  /// visible, and must still count while it fills the view.
  List<int> _paragraphsOnScreen() {
    final viewport = _viewportKey.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return const [];

    final viewTop = viewport.localToGlobal(Offset.zero).dy;
    final viewBottom = viewTop + viewport.size.height;
    final onScreen = <int>[];
    for (var i = 0; i < _paragraphKeys.length; i++) {
      final box = _paragraphKeys[i].currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      final showing = math.min(top + box.size.height, viewBottom) -
          math.max(top, viewTop);
      final enough =
          math.min(box.size.height * .6, viewport.size.height * .5);
      if (showing >= enough) onScreen.add(i);
    }
    return onScreen;
  }

  void _returnToUnread() {
    final waiting = _tracker.firstUnread;
    final target =
        waiting == null ? null : _paragraphKeys[waiting].currentContext;
    if (target == null) return;
    _lastTouch = DateTime.now();
    Scrollable.ensureVisible(
      target,
      alignment: .1,
      duration: context.motion(AppDurations.content),
      curve: AppDurations.curve,
    );
  }

  Future<void> _finish() async {
    final navigator = Navigator.of(context);
    final journey = JourneyRepository();

    setState(() => _finished = true);
    final outcome = journey.recordFullRead(
      hadith.number,
      seconds: _tracker.activeSeconds,
    );
    AppHaptics.success();

    final nextNumber = journey.nextHadithNumber;
    final next = nextNumber == null
        ? null
        : HadithRepository().getByNumber(nextNumber);
    final choice = await showCompletionSheet(
      context: context,
      hadith: hadith,
      outcome: outcome,
      hasNext: next != null,
    );
    if (!mounted) return;

    // Left unawaited: the reader's choice goes first, and a system dialog
    // waiting for an answer must not hold it up.
    unawaited(JourneyReminders.askAfterReading());

    switch (choice) {
      case CompletionChoice.write:
        JourneyLinks.openWriting(hadith);
      case CompletionChoice.next when next != null:
        navigator
          ..pop()
          ..pushReplacement(
            appPageRoute(child: HadithDetailScreen(hadith: next)),
          );
      case CompletionChoice.share:
        await shareHadith(context, hadith);
      case CompletionChoice.next:
      case null:
        break;
    }
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
              child: Column(
                children: [
                  Text(
                    'شرح الحديث وبيانه',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'الحديث ${toArabicDigits(hadith.number)}: ${hadith.title}',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: palette.goldText,
                    ),
                  ),
                ],
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
                  ParchmentCard(
                    elevated: true,
                    // Split on blank lines rather than set as one slab. This
                    // is the deepest reading surface in the app and it was
                    // getting the least typographic care of any screen:
                    // several paragraphs of scholarly commentary run together
                    // with no space between them.
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < _paragraphs.length; i++)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: i == _paragraphs.length - 1 ? 0 : 16,
                            ),
                            child: _ThreadedParagraph(
                              key: _paragraphKeys[i],
                              text: _paragraphs[i],
                              progress: _finished ? 1 : _tracker.progressOf(i),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FinishControl(
                    finished: _finished,
                    // A screen reader hears the text rather than scrolling
                    // through it, so time on screen means nothing there.
                    ready: _tracker.isComplete ||
                        MediaQuery.accessibleNavigationOf(context),
                    onFinish: _finish,
                    onReturnToUnread: _returnToUnread,
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

class _FinishControl extends StatelessWidget {
  const _FinishControl({
    required this.finished,
    required this.ready,
    required this.onFinish,
    required this.onReturnToUnread,
  });

  final bool finished;
  final bool ready;
  final VoidCallback onFinish;
  final VoidCallback onReturnToUnread;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (finished) {
      return Center(
        child: Text(
          'أتممت هذا الشرح',
          style: TextStyle(
            fontFamily: kSans,
            fontSize: 14,
            height: AppLeading.chrome,
            fontWeight: FontWeight.w700,
            color: palette.goldText,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton(
          text: ready ? 'أتممت القراءة' : 'أكمل من حيث توقفت',
          icon: ready ? Icons.check_rounded : null,
          isSecondary: !ready,
          onPressed: ready ? onFinish : onReturnToUnread,
        ),
        if (!ready) ...[
          const SizedBox(height: 8),
          Text(
            'يكتمل الخيط مع قراءتك',
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
    );
  }
}

/// A paragraph with the gold thread running down its start edge.
class _ThreadedParagraph extends StatelessWidget {
  const _ThreadedParagraph({
    super.key,
    required this.text,
    required this.progress,
  });

  final String text;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return TweenAnimationBuilder<double>(
      tween: Tween(end: progress),
      duration: context.motion(AppDurations.content),
      curve: Curves.linear,
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
        child: Text(
          text,
          textAlign: TextAlign.start,
          style: TextStyle(
            fontFamily: kSans,
            fontSize: 15.5,
            height: AppLeading.body,
            color: palette.bodyText,
          ),
        ),
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
