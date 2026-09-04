import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/bottom_navigation.dart';
import '../../core/widgets/asset_helper.dart';
import '../../core/widgets/circle_icon_button.dart';
import '../../core/widgets/app_loading_overlay.dart';
import '../../core/widgets/smooth_page_route.dart';
import '../../core/widgets/tap_target.dart';
import '../../core/theme/app_state_controller.dart';
import '../../data/repositories/hadith_repository.dart';
import '../../data/services/daily_tip_service.dart';
import '../../data/services/notification_scheduler.dart';
import '../messages/daily_message_screen.dart';
import '../hadith/hadith_list_screen.dart';
import '../community/community_screen.dart';
import '../share/add_message_screen.dart';
import '../favorites/favorites_screen.dart';
import '../profile/settings_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;
  final HadithRepository _repo = HadithRepository();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _loadingDailyTip = false;

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  void _goToTab(int index) => setState(() => _currentTabIndex = index);

  Future<void> _openDailyMessage() async {
    setState(() => _loadingDailyTip = true);
    final tip = await DailyTipService().getTodayTip();
    if (!mounted) return;
    setState(() => _loadingDailyTip = false);

    if (tip == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم يتم تحميل الرسائل بعد، حاول مجدداً')),
      );
      return;
    }

    final insight = tip.toInsight();
    final hadith = _repo.getByNumber(insight.hadithNumber);
    Navigator.push(
      context,
      SeamlessMessagePageRoute(
        child: DailyMessageScreen(
          insight: insight,
          hadith: hadith,
          onTabSelected: (index) {
            Navigator.pop(context);
            _goToTab(index);
          },
        ),
      ),
    );
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
            child: IndexedStack(
              index: _currentTabIndex,
              children: [
                // TickerMode pauses the home screen's ambient animations while
                // another tab is showing — IndexedStack does not do this for us.
                TickerMode(
                  enabled: _currentTabIndex == 0,
                  child: _HomeMainView(
                    onOpenDrawer: _openDrawer,
                    onOpenAllHadiths: () => Navigator.push(
                      context,
                      SmoothPageRoute(child: const HadithListScreen()),
                    ),
                    onHeartClick: _openDailyMessage,
                  ),
                ),
                FavoritesScreen(onOpenDrawer: _openDrawer),
                CommunityScreen(
                  onOpenDrawer: _openDrawer,
                  onSwitchToShareTab: () => _goToTab(3),
                ),
                AddMessageScreen(onPostCreated: () => _goToTab(2)),
              ],
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

class _HomeMainView extends StatelessWidget {
  const _HomeMainView({
    required this.onOpenDrawer,
    required this.onOpenAllHadiths,
    required this.onHeartClick,
  });

  final VoidCallback onOpenDrawer;
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

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              children: [
                const SizedBox(height: 6),
                Padding(
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
                      // Matches the leading button's width so the pill stays
                      // centred. Favorites already has its own bottom-nav tab —
                      // this header used to duplicate it with a second control.
                      const SizedBox(width: 44),
                    ],
                  ),
                ),
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

    // Fire-and-forget: refreshes the rolling notification window on every
    // app start (also re-run whenever a reminder setting changes, from the
    // settings drawer) — never blocks the home screen on a Firestore round
    // trip or a permission dialog.
    final state = AppStateController();
    if (state.morningReminderEnabled || state.eveningReminderEnabled) {
      NotificationScheduler.instance.reschedule(
        morningEnabled: state.morningReminderEnabled,
        morningTime: state.morningReminderTime,
        eveningEnabled: state.eveningReminderEnabled,
        eveningTime: state.eveningReminderTime,
      );
    }

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
                'لمسة قلبية بانتظارك الآن 🌿',
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
