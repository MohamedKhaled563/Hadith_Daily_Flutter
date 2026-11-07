import 'dart:async';

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/bottom_navigation.dart';
import '../../core/widgets/asset_helper.dart';
import '../../core/widgets/circle_icon_button.dart';
import '../../core/widgets/app_loading_overlay.dart';
import '../../core/widgets/smooth_page_route.dart';
import '../../core/widgets/tap_target.dart';
import '../../core/theme/app_state_controller.dart';
import '../../core/utils/app_motion.dart';
import '../../core/utils/notification_reliability_tip.dart';
import '../../data/repositories/hadith_repository.dart';
import '../../data/services/daily_tip_service.dart';
import '../../data/services/journey_reminders.dart';
import '../../data/services/notification_scheduler.dart';
import '../messages/daily_message_card.dart';
import '../messages/today_message_screen.dart';
import '../hadith/hadith_detail_screen.dart';
import '../hadith/hadith_list_screen.dart';
import '../community/community_screen.dart';
import '../community/my_submissions_screen.dart';
import '../share/add_message_screen.dart';
import '../journey/journey_links.dart';
import '../journey/journey_ring.dart';
import '../journey/journey_screen.dart';
import '../memorize/memorize_screen.dart';
import '../profile/settings_drawer.dart';
import 'reminder_offer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.openMessageOnStart = false,
    this.openSubmissionsOnStart = false,
    this.openHadithOnStart,
    this.offerRemindersOnStart = false,
    this.openJourneyOnStart = false,
    this.openReviewOnStart,
  });

  /// Open the review of this hadith. Only for a launch from a review
  /// reminder.
  final int? openReviewOnStart;

  /// Start on the journey tab. Only for a launch from the Friday harvest.
  final bool openJourneyOnStart;

  /// Open today's message as soon as home is up, instead of waiting for the
  /// emblem. Only for a launch from a reminder tap — see SplashScreen.
  final bool openMessageOnStart;

  /// Open the reader's submissions on top of Home. Only for a launch from
  /// tapping an approval notification — see SplashScreen.
  final bool openSubmissionsOnStart;

  /// Open this hadith on top of Home. Only for a launch from tapping a
  /// reminder about it — see SplashScreen.
  final int? openHadithOnStart;

  /// Offer reminders once Home is up, if this reader has never been offered
  /// them. Only for an ordinary launch: someone who arrived by tapping a
  /// notification already has them.
  final bool offerRemindersOnStart;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentTabIndex = 0;

  /// Drives the arriving tab's fade-through. IndexedStack swaps its child in
  /// a single frame, which is correct for keeping every tab's state alive but
  /// reads as a hard cut on the app's most frequent transition. This plays
  /// the incoming half of a Material fade-through over the top of that swap —
  /// the new body arrives rather than simply being there.
  late final AnimationController _tabFade = AnimationController(
    vsync: this,
    duration: AppDurations.content,
    value: 1,
  );

  final HadithRepository _repo = HadithRepository();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _loadingDailyTip = false;

  @override
  void initState() {
    super.initState();
    // After the first frame: the Navigator cannot take a push during a build.
    if (widget.openMessageOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openDailyMessage());
    }
    // A reminder tapped while the app is running should land on the message,
    // not on an emblem waiting to be pressed. Cold starts go through
    // SplashScreen, which does the same thing before handing over.
    NotificationScheduler.notificationTapped.addListener(_onReminderTapped);
    NotificationScheduler.submissionApprovalTapped
        .addListener(_openMySubmissions);
    NotificationScheduler.hadithTapped.addListener(_onHadithReminderTapped);
    NotificationScheduler.harvestTapped.addListener(_openJourney);
    JourneyLinks.writeAbout.addListener(_onWriteAbout);
    if (widget.openJourneyOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openJourney());
    }
    if (widget.openSubmissionsOnStart) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _openMySubmissions());
    }
    final hadith = widget.openHadithOnStart;
    if (hadith != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openHadith(hadith));
    }
    final review = widget.openReviewOnStart;
    if (review != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _openHadith(review, review: true));
    }
    if (widget.offerRemindersOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _offerReminders());
    }
  }

  /// Waits a moment so the reader sees Home first, and stays out of the way
  /// if they have already moved on from it.
  Future<void> _offerReminders() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    final state = AppStateController();
    if (!state.morningReminderEnabled && !state.eveningReminderEnabled) return;
    await offerReminders(context);
  }

  @override
  void dispose() {
    NotificationScheduler.notificationTapped.removeListener(_onReminderTapped);
    NotificationScheduler.submissionApprovalTapped
        .removeListener(_openMySubmissions);
    NotificationScheduler.hadithTapped.removeListener(_onHadithReminderTapped);
    NotificationScheduler.harvestTapped.removeListener(_openJourney);
    JourneyLinks.writeAbout.removeListener(_onWriteAbout);
    _tabFade.dispose();
    super.dispose();
  }

  Future<void> _onReminderTapped() async {
    await DailyTipService().ensureOpenedToday();
    if (!mounted) return;
    // Back to the home tab from wherever they were, so that leaving the
    // message lands on the emblem. Closes the window too, if it was open:
    // reopening it is simpler than working out what is on top.
    Navigator.of(context).popUntil((route) => route.isFirst);
    if (mounted) _goToTab(0);
    await _openDailyMessage();
  }

  /// A finished hadith led the reader to write about it: back to this shell
  /// and on to the writing tab, which selects that hadith itself.
  void _onWriteAbout() {
    if (JourneyLinks.writeAbout.value == null || !mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    _goToTab(3);
  }

  /// The journey's first step: back to the emblem, and open today's message.
  void _openMessageFromJourney() {
    _goToTab(0);
    _openDailyMessage();
  }

  /// An approval notification was tapped: show the reader the message itself,
  /// from wherever they were.
  void _openMySubmissions() {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    navigator.popUntil((route) => route.isFirst);
    navigator.push(appPageRoute(child: const MySubmissionsScreen()));
  }

  /// The Friday harvest was tapped: show the week on the journey tab.
  void _openJourney() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    _goToTab(1);
  }

  void _onHadithReminderTapped() {
    final tap = NotificationScheduler.hadithTapped.value;
    if (tap != null) _openHadith(tap.number, review: tap.review);
  }

  /// A reminder named this hadith: open it, or its review, from wherever the
  /// reader was.
  void _openHadith(int number, {bool review = false}) {
    final hadith = _repo.getByNumber(number);
    if (hadith == null || !mounted) return;
    final navigator = Navigator.of(context);
    navigator.popUntil((route) => route.isFirst);
    _goToTab(review ? 1 : 0);
    navigator.push(appPageRoute(
      child: review
          ? ReviewScreen(hadith: hadith)
          : HadithDetailScreen(hadith: hadith),
    ));
  }

  Future<List<DailyMessageEntry>> _loadTodayEntries() async {
    final tips = await DailyTipService().getTodayTips();
    return [
      for (final tip in tips)
        DailyMessageEntry(
          insight: tip.toInsight(),
          hadith: _repo.getByNumber(tip.hadithNumber),
        ),
    ];
  }

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  void _goToTab(int index) {
    if (index == _currentTabIndex) return;
    setState(() => _currentTabIndex = index);
    if (!context.reduceMotion) _tabFade.forward(from: 0);
  }

  /// Opens today's message in its own window.
  ///
  /// Home keeps nothing about it and never changes, so the emblem is waiting
  /// when the reader comes back, and every press reads today afresh. An app
  /// left open overnight therefore cannot show yesterday's message.
  Future<void> _openDailyMessage() async {
    if (_loadingDailyTip) return; // A second tap while the first one loads.
    setState(() => _loadingDailyTip = true);
    // Opened earlier today? Then this returns to where they left off rather
    // than starting the day's set over.
    final alreadyRevealed = await DailyTipService().revealedCount();
    final entries = await _loadTodayEntries();
    if (!mounted) return;
    setState(() => _loadingDailyTip = false);

    if (entries.isEmpty) {
      showAppSnack(
        context,
        'لم يتم تحميل الرسائل بعد، حاول مجدداً',
        tone: SnackTone.warning,
      );
      return;
    }

    if (alreadyRevealed < 1) DailyTipService().saveRevealedCount(1);
    await Navigator.of(context).push(
      appMessageRoute(
        child: TodayMessageScreen(entries: entries, revealed: alreadyRevealed),
      ),
    );
    // Back from reading their first message: the reader now has a reason to
    // want a reminder, and nothing is on screen for the dialog to interrupt.
    unawaited(JourneyReminders.askAfterReading());
  }

  @override
  Widget build(BuildContext context) {
    // One Scaffold and one background for the whole tab shell. Each tab used to
    // build its own AppBackground, which kept four full-screen images decoded
    // at once because IndexedStack keeps every child mounted.
    return AppLoadingOverlay(
      visible: _loadingDailyTip,
      message: 'جارٍ تحضير رسالة اليوم…',
      child: Scaffold(
        key: _scaffoldKey,
        drawer: const SettingsDrawer(),
        backgroundColor: Colors.transparent,
        // Body runs behind the floating nav bar so the scene fills the screen.
        extendBody: true,
        body: AppBackground(
          showBottomLandscape: true,
          child: SafeArea(
            bottom: false,
            // See BottomNavigation.scope: lets every tab's call to
            // BottomNavigation.reservedHeight(context) reserve the bar's
            // real measured height instead of a hand-computed estimate.
            child: BottomNavigation.scope(
              child: _TabFadeThrough(
                animation: _tabFade,
                child: IndexedStack(
                  index: _currentTabIndex,
                    children: [
                    // TickerMode pauses the home screen's ambient animations
                    // while another tab is showing — IndexedStack does not do
                    // this for us.
                    TickerMode(
                      enabled: _currentTabIndex == 0,
                      // The emblem is always mounted, and a Hero on a hidden
                      // tab still answers to its tag: opening a saved message
                      // from favourites would fly an emblem in from a tab
                      // that is not on screen.
                      child: HeroMode(
                        enabled: _currentTabIndex == 0,
                        child: _HomeMainView(
                          onOpenDrawer: _openDrawer,
                          onOpenJourney: () => _goToTab(1),
                          onOpenAllHadiths: () => Navigator.push(
                            context,
                            appPageRoute(child: const HadithListScreen()),
                          ),
                          onHeartClick: _openDailyMessage,
                        ),
                      ),
                    ),
                    JourneyScreen(
                      onOpenDrawer: _openDrawer,
                      onOpenMessage: _openMessageFromJourney,
                    ),
                    CommunityScreen(
                      onOpenDrawer: _openDrawer,
                      onSwitchToShareTab: () => _goToTab(3),
                    ),
                    AddMessageScreen(onPostCreated: () => _goToTab(2)),
                  ],
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: BottomNavigation(
          currentIndex: _currentTabIndex,
          onTap: _goToTab,
        ),
      ),
    );
  }
}

/// Fades and lifts the arriving tab body.
///
/// Sits *outside* the IndexedStack rather than around each child, so it costs
/// one repaint boundary rather than four and never disturbs the fact that
/// every tab stays mounted.
class _TabFadeThrough extends StatelessWidget {
  const _TabFadeThrough({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return child;

    final curved = CurvedAnimation(
      parent: animation,
      curve: AppDurations.curve,
    );

    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) => Opacity(
        opacity: curved.value,
        child: Transform.scale(
          // A small rise from 97% reads as arriving; any more and the whole
          // app looks like it is zooming on every tap.
          scale: 0.97 + 0.03 * curved.value,
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _HomeMainView extends StatelessWidget {
  const _HomeMainView({
    required this.onOpenDrawer,
    required this.onOpenJourney,
    required this.onOpenAllHadiths,
    required this.onHeartClick,
  });

  final VoidCallback onOpenDrawer;
  final VoidCallback onOpenJourney;
  final VoidCallback onOpenAllHadiths;
  final VoidCallback onHeartClick;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = context.isDarkMode;
    final titleColor =
        isDark ? AppColors.primaryTextDark : AppColors.primaryText;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Budget the hero against the height that is actually left, not screen
        // width alone. The circle's Stack is sized by its largest child — the
        // orbiting ring at diameter + 68 — so that ring has to be in the sum.
        //
        // The title block is text, so it grows with the reader's text scale;
        // the fixed spacers do not. Scale only the part that actually scales.
        final textScaler = MediaQuery.textScalerOf(context);
        final titleBlock = textScaler.scale(118);
        final chromeHeight = 6.0 + 56.0 + 12.0 + titleBlock + 18.0;
        final available = constraints.maxHeight - chromeHeight;
        final diameter = math.max(
          200.0,
          math.min(
            (constraints.maxWidth * 0.76).clamp(240.0, 325.0),
            available - 68,
          ),
        );

        final header = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // First child sits at the START edge — the right, in RTL.
              CircleIconButton(
                icon: Icons.menu_rounded,
                semanticLabel: 'فتح قائمة الإعدادات',
                onTap: onOpenDrawer,
                emphasised: true,
              ),
              Flexible(
                child: _BrowseAllPill(
                  onTap: onOpenAllHadiths,
                  titleColor: titleColor,
                ),
              ),
              // Fills the same 48dp slot as the leading button, so the pill
              // stays centred.
              JourneyRing(onTap: onOpenJourney),
            ],
          ),
        );

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              children: [
                const SizedBox(height: 6),
                header,
                const SizedBox(height: 12),
                _HeroTitle(titleColor: titleColor, isDark: isDark),
                const SizedBox(height: 18),
                _HeartbeatHadithCircle(
                  cardDiameter: diameter,
                  isDark: isDark,
                  palette: palette,
                  onTap: onHeartClick,
                ),
                SizedBox(
                  height: 12 + BottomNavigation.reservedHeight(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeroTitle extends StatelessWidget {
  const _HeroTitle({required this.titleColor, required this.isDark});

  final Color titleColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    // letterSpacing stays at 0 throughout: Arabic is a connected script and
    // tracking breaks the joins between glyphs.
    final headline = TextStyle(
      fontFamily: kSans,
      fontSize: 30,
      height: 1.25,
      fontWeight: FontWeight.w900,
      color: titleColor,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Semantics(
        header: true,
        label: 'هل سمعت كلام النبي صلى الله عليه وسلم اليوم؟',
        child: ExcludeSemantics(
          child: Column(
            children: [
              Text('هل سمعت', textAlign: TextAlign.center, style: headline),
              const SizedBox(height: 2),
              // Wrap rather than overflow when text is scaled up.
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text('كلام النبي', style: headline),
                  Text(
                    'ﷺ',
                    style: headline.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.goldTextDark
                          : const Color(0xFF3B5644),
                    ),
                  ),
                  Text('اليوم؟', style: headline),
                ],
              ),
              const SizedBox(height: 8),
              AssetHelper.assetOrFallback(
                assetPath: 'assets/images/golden_divider.png',
                width: 130,
                height: 18,
                fallback: Container(
                  width: 70,
                  height: 2,
                  color: const Color(0xFFD6BE88),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrowseAllPill extends StatelessWidget {
  const _BrowseAllPill({required this.onTap, required this.titleColor});

  final VoidCallback onTap;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return TapTarget(
      onTap: onTap,
      semanticLabel: 'تصفح الأربعين النووية',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: palette.cardBorder),
          boxShadow: AppElevation.card,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories_rounded,
              size: 16,
              color: palette.goldText,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'الأربعين النووية',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 12.5,
                  height: AppLeading.chrome,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The meditative heart circle: a gentle pulse, two counter-rotating rings and
/// an ambient breath, with tactile press feedback.
class _HeartbeatHadithCircle extends StatefulWidget {
  const _HeartbeatHadithCircle({
    required this.cardDiameter,
    required this.isDark,
    required this.palette,
    required this.onTap,
  });

  final double cardDiameter;
  final bool isDark;
  final BotanicalPalette palette;
  final VoidCallback onTap;

  @override
  State<_HeartbeatHadithCircle> createState() => _HeartbeatHadithCircleState();
}

class _HeartbeatHadithCircleState extends State<_HeartbeatHadithCircle>
    with TickerProviderStateMixin {
  late final AnimationController _heartbeat;
  late final AnimationController _outerOrbit;
  late final AnimationController _innerOrbit;
  late final AnimationController _ringsBreath;
  late final AnimationController _press;

  late final Animation<double> _heartbeatScale;
  late final Animation<double> _ringsScale;
  late final Animation<double> _ringsOpacity;
  late final Animation<double> _pressScale;

  bool _ambientRunning = false;

  @override
  void initState() {
    super.initState();

    // Rescheduling itself no longer happens here. It used to be a
    // fire-and-forget call in this widget's initState — a decorative heart
    // animation owning the app's notification window — which also meant it
    // ran exactly once per cold start and never on resume.
    // NotificationLifecycleRefresher (started from main.dart) owns it now.
    // What stays is the reliability tip, which genuinely needs a
    // BuildContext and a mounted screen to show itself on.
    final state = AppStateController();
    final anyReminderEnabled =
        state.morningReminderEnabled || state.eveningReminderEnabled;

    // A granted permission only means the OS *will* show a notification if
    // asked to — MIUI and several other OEMs (plus iOS Focus/Do Not
    // Disturb) can still keep it from ever appearing, with no way for the
    // app to detect or fix that.
    //
    // Deliberately not on the first run: this used to cover the hero with a
    // battery-settings sheet before a new reader had seen anything at all.
    // recordLaunchAndCheck() holds it back until they have come back a few
    // times, by which point a reminder has plausibly been due and failed —
    // which is when the advice means something. Switching a reminder on in
    // settings shows it immediately instead, since that is the reader asking.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!await NotificationReliabilityTip.recordLaunchAndCheck()) return;
      // The State's own mounted, not context.mounted: this is a State.context
      // being used after an await, and the two are not interchangeable.
      if (!mounted) return;
      NotificationReliabilityTip.maybeShow(
        context,
        anyReminderEnabled: anyReminderEnabled,
      );
    });

    _heartbeat = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _heartbeatScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.026)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.026, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 35,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 30),
    ]).animate(_heartbeat);

    _outerOrbit = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    );
    _innerOrbit = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
    _ringsBreath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );

    _ringsScale = Tween(begin: 0.98, end: 1.045).animate(
      CurvedAnimation(parent: _ringsBreath, curve: Curves.easeInOutCubic),
    );
    _ringsOpacity = Tween(begin: 0.45, end: 0.85).animate(
      CurvedAnimation(parent: _ringsBreath, curve: Curves.easeInOut),
    );

    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _pressScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.94)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.94, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 55,
      ),
    ]).animate(_press);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honour the reader's reduce-motion preference: hold the circle still
    // rather than looping four controllers forever.
    _syncAmbient(!MediaQuery.disableAnimationsOf(context));
  }

  void _syncAmbient(bool shouldRun) {
    if (shouldRun == _ambientRunning) return;
    _ambientRunning = shouldRun;

    for (final c in [_heartbeat, _outerOrbit, _innerOrbit]) {
      shouldRun ? c.repeat() : c.stop();
    }
    shouldRun ? _ringsBreath.repeat(reverse: true) : _ringsBreath.stop();
  }

  @override
  void dispose() {
    _heartbeat.dispose();
    _outerOrbit.dispose();
    _innerOrbit.dispose();
    _ringsBreath.dispose();
    _press.dispose();
    super.dispose();
  }

  void _handleTap() {
    // Navigate immediately. The press animation is feedback, not a gate — it
    // used to delay navigation by 220ms on the app's primary call to action.
    AppHaptics.tap();
    widget.onTap();
    _press.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.cardDiameter;

    return Semantics(
      button: true,
      label: 'افتح رسالة اليوم',
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: _handleTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: Listenable.merge([_heartbeatScale, _pressScale]),
            builder: (context, child) => Transform.scale(
              scale: _heartbeatScale.value * _pressScale.value,
              child: child,
            ),
            child: SizedBox(
              width: d + 68,
              height: d + 68,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _outerRing(d),
                  _innerRing(d),
                  _ambientGlow(d),
                  _faceCircle(d),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _outerRing(double d) {
    return AnimatedBuilder(
      animation: _ringsBreath,
      builder: (context, child) => Transform.scale(
        scale: _ringsScale.value,
        child: Opacity(opacity: _ringsOpacity.value, child: child),
      ),
      child: RotationTransition(
        turns: _outerOrbit,
        child: SizedBox(
          width: d + 68,
          height: d + 68,
          child: CustomPaint(
            painter: _OuterPatternedRingPainter(
              color: widget.isDark
                  ? const Color(0x70D1BE93)
                  : const Color(0x60D1BE93),
            ),
          ),
        ),
      ),
    );
  }

  Widget _innerRing(double d) {
    return AnimatedBuilder(
      animation: _ringsBreath,
      builder: (context, child) => Transform.scale(
        scale: 1.0 / _ringsScale.value,
        child: child,
      ),
      child: RotationTransition(
        turns: ReverseAnimation(_innerOrbit),
        child: Container(
          width: d + 38,
          height: d + 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.isDark
                  ? const Color(0x40D1BE93)
                  : const Color(0x45D1BE93),
              width: 1.3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _ambientGlow(double d) {
    return Container(
      width: d + 14,
      height: d + 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color:
            widget.isDark ? const Color(0x20D1BE93) : const Color(0x18D1BE93),
        boxShadow: [
          BoxShadow(
            color: widget.isDark
                ? const Color(0x35000000)
                : const Color(0x25B9A06A),
            blurRadius: 26,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }

  Widget _faceCircle(double d) {
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: widget.isDark
              ? const [
                  Color(0xFF26352C),
                  Color(0xFF1C2720),
                  Color(0xFF141D17),
                ]
              : const [
                  Color(0xFFFFFDFC),
                  Color(0xFFFAF5EB),
                  Color(0xFFF1E6D3),
                ],
        ),
        border: Border.all(color: const Color(0xFFD6BE88), width: 3.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x28B9A06A),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      // The circle is a fixed geometric element, so its contents cannot grow
      // past its bounds. scaleDown only shrinks when it has to — at normal
      // text sizes this is a no-op, and at 1.6x it keeps the disc intact
      // instead of overflowing.
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Hero(
                tag: 'heart_leaf_emblem_hero',
                child: AssetHelper.assetOrFallback(
                  assetPath: 'assets/images/heart_leaf_emblem.png',
                  width: 64,
                  height: 64,
                  fallback: const Icon(
                    Icons.favorite_rounded,
                    color: AppColors.primaryGreen,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'طيّب قلبك',
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 36,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                  color: widget.isDark
                      ? AppColors.primaryTextDark
                      : AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 4),
              AssetHelper.assetOrFallback(
                assetPath: 'assets/images/golden_divider.png',
                width: 88,
                height: 14,
                fallback: Container(
                  width: 50,
                  height: 1.5,
                  color: const Color(0xFFD6BE88),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                // Says what pressing does. The line here used to be
                // "لمسة قلبية بانتظارك الآن", which is brochure copy: it
                // promises a feeling and tells the reader nothing.
                'اضغط لقراءة رسالة اليوم',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 13.5,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                  color: widget.isDark
                      ? AppColors.goldTextDark
                      : const Color(0xFF3B5644),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Outer ring with eight celestial nodes.
class _OuterPatternedRingPainter extends CustomPainter {
  _OuterPatternedRingPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final ringPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..isAntiAlias = true;

    final dotPaint = Paint()
      ..color = color.withValues(alpha: color.a * 0.9)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawCircle(center, radius - 2, ringPaint);

    const nodes = 8;
    for (var i = 0; i < nodes; i++) {
      final angle = (i * 2 * math.pi) / nodes;
      canvas.drawCircle(
        Offset(
          center.dx + (radius - 2) * math.cos(angle),
          center.dy + (radius - 2) * math.sin(angle),
        ),
        2.6,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OuterPatternedRingPainter oldDelegate) =>
      oldDelegate.color != color;
}
