import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_motion.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/asset_helper.dart';
import '../../core/widgets/smooth_page_route.dart';
import '../../data/repositories/hadith_repository.dart';
import '../../data/services/daily_tip_service.dart';
import '../../data/services/notification_scheduler.dart';
import '../home/home_screen.dart';
import '../messages/daily_message_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _heartPulseController;
  late Animation<double> _heartPulseAnimation;

  late AnimationController _haloRotateController;
  late AnimationController _quoteFadeController;

  int _currentQuoteIndex = 0;
  Timer? _quoteTimer;
  Timer? _autoAdvanceTimer;

  // Started immediately, and *awaited* (briefly) in _navigateToHome rather
  // than read as a field that may or may not have been filled in yet — a
  // cold start from tapping a reminder notification never fires
  // NotificationScheduler.notificationTapped (that's only for a live tap
  // while the app is already running), so this is the only path for it.
  //
  // It used to assign into a plain field and hope: on wifi the fetch beat
  // the 2.8s timer comfortably, but on a cold cellular start — or any
  // tap-to-skip, which can land 300ms in — the field was still null and the
  // tap silently dropped the reader on Home with no message at all. Holding
  // the future instead lets the navigation wait the short remainder out.
  //
  // Resolves to today's actual daily/community messages (DailyTipService) —
  // the same content the home screen's heart button opens — never the
  // reminder pool's own generic notification text.
  Future<List<DailyMessageEntry>>? _launchEntries;

  /// How long _navigateToHome is willing to hold the splash open waiting for
  /// the message behind a notification tap. Long enough to cover a slow
  /// fetch, short enough that a genuinely broken network still lands the
  /// reader on Home promptly.
  static const _launchEntriesTimeout = Duration(seconds: 3);

  // Both the 2.8s timer and the tap-to-skip gesture call _navigateToHome,
  // and `mounted` stays true throughout pushReplacement's transition — so a
  // quick double tap could push two HomeScreens (and, with a notification
  // tap, two message screens on top).
  bool _navigated = false;

  final List<String> _inspirationalQuotes = [
    'أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ',
    'طِبْ نفساً واستبشر بنور النبوة',
    'الكلمة الطيبة صدقة ونور في القلب',
    'إن مع العسر يسراً، فاستبشر خيراً',
  ];

  @override
  void initState() {
    super.initState();

    _launchEntries = _resolveLaunchEntries();

    // Rhythmic Heartbeat pulse (Lub-Dub organic curve). Started in
    // didChangeDependencies rather than here — whether it should run at all
    // depends on MediaQuery, which is not available yet in initState.
    _heartPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _heartPulseAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 1.03)
            .chain(CurveTween(curve: Curves.easeInOutQuad)),
        weight: 12,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.03, end: 1.20)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.20, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 30, // Resting diastole
      ),
    ]).animate(_heartPulseController);

    // Halo Rotation
    _haloRotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );

    // Quote Fade In/Out
    _quoteFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    // One quote, chosen at random, held for the whole splash.
    //
    // It used to cycle every 2.2s inside a 2.8s window, so the reader got one
    // quote, a 600ms cross-fade, and 0.6s of a second quote before the screen
    // was replaced — which reads as a glitch, not a rotation. The four quotes
    // still earn their place: which one you get varies between launches.
    _currentQuoteIndex = math.Random().nextInt(_inspirationalQuotes.length);

    // Auto-navigate after 2.8 seconds. Held so it can be cancelled when the
    // reader taps to skip, or the screen is disposed first.
    _autoAdvanceTimer = Timer(
      const Duration(milliseconds: 2800),
      _navigateToHome,
    );
  }

  /// Today's messages if this launch came from tapping a reminder, or an
  /// empty list otherwise. Never throws: a platform-channel hiccup or an
  /// offline tip fetch should skip the deep link, not block the splash.
  Future<List<DailyMessageEntry>> _resolveLaunchEntries() async {
    try {
      final launched =
          await NotificationScheduler.instance.wasLaunchedByNotification();
      if (!launched) return const [];
      final tips = await DailyTipService().getTodayTips();
      if (tips.isEmpty) return const [];
      final repo = HadithRepository();
      return [
        for (final tip in tips)
          DailyMessageEntry(
            insight: tip.toInsight(),
            hadith: repo.getByNumber(tip.hadithNumber),
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _navigateToHome() async {
    if (!mounted || _navigated) return;
    _navigated = true;
    _quoteTimer?.cancel();
    _autoAdvanceTimer?.cancel();

    // Give a still-in-flight notification lookup the short remainder of its
    // budget before deciding there's nothing to deep-link to. Resolves
    // immediately in the overwhelmingly common case (no notification tap, or
    // the fetch already finished during the 2.8s splash).
    final entries = await (_launchEntries
            ?.timeout(_launchEntriesTimeout, onTimeout: () => const [])
            .catchError((_) => const <DailyMessageEntry>[]) ??
        Future.value(const <DailyMessageEntry>[]));
    if (!mounted) return;

    // Always Home. The app used to send anyone without an account to the
    // login screen from here, so a new install's first experience was a form
    // — before a single hadith. Nothing a reader browses needs an identity:
    // the hadiths, the daily messages and the approved community posts are
    // all public-read, and bookmarks live on the device. Signing in is asked
    // for at the three points that genuinely need it (see requireSignIn).
    Navigator.pushReplacement(
      context,
      appPageRoute(child: const HomeScreen()),
    );

    // Cold-started by tapping a reminder: land on Home first (above) so the
    // back button behaves normally, then stack the tapped message on top of
    // it — same two calls as the live-tap listener in main.dart, just
    // sequenced instead of racing a Navigator that doesn't exist yet.
    if (entries.isNotEmpty) {
      Navigator.push(
        context,
        appMessageRoute(child: DailyMessageScreen.forDay(entries: entries),
        ),
      );
    }
  }

  bool _ambientStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honour the reader's reduce-motion preference: hold the emblem still
    // rather than looping two controllers behind a screen that is about to
    // be replaced anyway. The quote still fades in, since that is a single
    // 600ms transition rather than ambient motion.
    if (_ambientStarted || context.reduceMotion) return;
    _ambientStarted = true;
    _heartPulseController.repeat();
    _haloRotateController.repeat();
  }

  @override
  void dispose() {
    _heartPulseController.dispose();
    _haloRotateController.dispose();
    _quoteFadeController.dispose();
    _quoteTimer?.cancel();
    _autoAdvanceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // This screen used to hardcode nine light-mode literals, so in dark mode
    // the app name rendered at 1.54:1 and the tagline at 1.57:1 - the first
    // thing every reader sees, effectively invisible. Everything below now
    // comes from the theme like the rest of the app.
    final palette = context.palette;
    final isDark = context.isDarkMode;

    return Scaffold(
      body: GestureDetector(
        onTap: _navigateToHome,
        child: AppBackground(
          showBottomLandscape: true,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // The emblem (halo/glow/inner-circle stack) is the one block
                // that can shrink without losing meaning, so it absorbs the
                // squeeze on short screens (small phones in landscape, or a
                // small-height portrait phone) instead of overflowing.
                // Everything else below is a fixed budget of text + spacing
                // that this estimates so the shrink only kicks in when the
                // screen genuinely can't fit the full-size design.
                final textScaler = MediaQuery.textScalerOf(context);
                final nonEmblemHeight = 32 +
                    textScaler.scale(34 * 1.25) +
                    8 +
                    18 +
                    10 +
                    textScaler.scale(15 * 1.3) +
                    24 +
                    (24 + textScaler.scale(14 * 1.5 * 2)) +
                    20 +
                    8;
                final available = constraints.maxHeight - nonEmblemHeight;
                final emblemSize = available.clamp(120.0, 220.0);
                final scale = emblemSize / 220.0;

                final leftover =
                    (constraints.maxHeight - nonEmblemHeight - emblemSize)
                        .clamp(0.0, double.infinity);

                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: leftover * 2 / 5),

                        // Center Pulsating Emblem with Moving Auras
                        Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Rotating ambient dashed/dotted ring
                              RotationTransition(
                                turns: _haloRotateController,
                                child: Container(
                                  width: emblemSize,
                                  height: emblemSize,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0x35D1BE93),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),

                              // Outer breathing golden glow
                              AnimatedBuilder(
                                animation: _heartPulseAnimation,
                                builder: (context, child) {
                                  final size = 180 *
                                      scale *
                                      _heartPulseAnimation.value;
                                  return Container(
                                    width: size,
                                    height: size,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      // A 12.5% gold fill reads as a soft
                                      // bloom over parchment, but as a flat
                                      // opaque grey disc over the night
                                      // ground. On dark the blur does the
                                      // work and the fill nearly disappears.
                                      color: Color(
                                        isDark ? 0x0CD1BE93 : 0x20D1BE93,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(
                                            isDark ? 0x1FE0CEB0 : 0x30E0CEB0,
                                          ),
                                          blurRadius:
                                              36 * _heartPulseAnimation.value,
                                          spreadRadius: 8,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),

                              // Inner Emblem with Heartbeat
                              ScaleTransition(
                                scale: _heartPulseAnimation,
                                child: Container(
                                  width: 130 * scale,
                                  height: 130 * scale,
                                  padding: EdgeInsets.all(22 * scale),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    // A cream disc on a night scene reads as
                                    // a blown-out white blob; in dark mode the
                                    // disc takes the same parchment the cards
                                    // use and the gold rim carries the shape.
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: isDark
                                          ? [
                                              palette.parchmentTop,
                                              palette.parchmentMid,
                                              palette.parchmentBottom,
                                            ]
                                          : const [
                                              Color(0xFFFFFDFC),
                                              Color(0xFFFAF5EB),
                                              Color(0xFFF1E6D3),
                                            ],
                                    ),
                                    border: Border.all(
                                      color: palette.cardBorderStrong,
                                      width: 3.5,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x35B9A06A),
                                        blurRadius: 24,
                                        offset: Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: AssetHelper.assetOrFallback(
                                    assetPath:
                                        'assets/images/heart_leaf_emblem.png',
                                    width: 80 * scale,
                                    height: 80 * scale,
                                    fallback: Icon(
                                      Icons.favorite_rounded,
                                      color: isDark
                                          ? AppColors.primaryGreenDark
                                          : AppColors.primaryGreen,
                                      size: 58 * scale,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // App Name
                        Text(
                          'طيّب قلبك',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: palette.bodyText,
                            fontFamily: kSans,
                            // Arabic is a connected script - negative tracking
                            // breaks the joins between glyphs. Every other
                            // style in the app leaves this at zero on purpose
                            // (see AppTextStyles); this one had drifted.
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Golden Divider Flourish
                        AssetHelper.assetOrFallback(
                          assetPath: 'assets/images/golden_divider.png',
                          width: 120,
                          height: 18,
                          fallback: Container(
                            width: 70,
                            height: 2,
                            color: palette.cardBorderStrong,
                          ),
                        ),
                        const SizedBox(height: 10),

                        Text(
                          'أحاديث نبوية وهدايات قلبية',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: palette.mutedText,
                            fontFamily: kSans,
                          ),
                        ),

                        SizedBox(height: 24 + leftover * 3 / 5),

                        // Dynamic Inspirational Quote Container
                        FadeTransition(
                          opacity: _quoteFadeController,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 32),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: palette.surface.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: palette.cardBorder),
                            ),
                            child: Text(
                              _inspirationalQuotes[_currentQuoteIndex],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: palette.bodyText,
                                fontFamily: kSans,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Subtle Loading Dots / Tap to continue
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _Dot(color: palette.ornamentGold, size: 6),
                            const SizedBox(width: 8),
                            _Dot(color: palette.goldText, size: 8),
                            const SizedBox(width: 8),
                            _Dot(color: palette.ornamentGold, size: 6),
                          ],
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// One of the three resting dots under the quote. Extracted only so the three
/// call sites cannot drift apart again.
class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
