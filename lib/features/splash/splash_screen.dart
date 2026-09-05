import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/asset_helper.dart';
import '../../core/widgets/smooth_page_route.dart';
import '../../core/theme/app_state_controller.dart';
import '../../data/models/insight.dart';
import '../../data/services/notification_scheduler.dart';
import '../auth/login_screen.dart';
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

  // Started immediately so it's very likely already resolved by the time
  // _navigateToHome runs (2.8s later, or sooner on a tap-to-skip) — a cold
  // start from tapping a reminder notification never fires
  // NotificationScheduler.tappedMessage (that's only for a live tap while
  // the app is already running), so this is checked separately, once.
  Insight? _pendingNotificationInsight;

  final List<String> _inspirationalQuotes = [
    'أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ 🌿',
    'طِبْ نفساً واستبشر بنور النبوة ✨',
    'الكلمة الطيبة صدقة ونور في القلب 🕊️',
    'إن مع العسر يسراً، فاستبشر خيراً 🤍',
  ];

  @override
  void initState() {
    super.initState();

    NotificationScheduler.instance
        .consumeLaunchPayload()
        .then((id) => NotificationScheduler.instance.resolveTappedMessage(id))
        .then((insight) {
      _pendingNotificationInsight = insight;
    }).catchError((_) {
      // Best-effort: a platform-channel hiccup here should never block
      // showing the splash screen, just skip the notification deep link.
    });

    // Rhythmic Heartbeat pulse (Lub-Dub organic curve)
    _heartPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

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
    )..repeat();

    // Quote Fade In/Out
    _quoteFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    // Cycle quotes
    _quoteTimer = Timer.periodic(const Duration(milliseconds: 2200), (timer) {
      if (mounted) {
        _quoteFadeController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _currentQuoteIndex =
                  (_currentQuoteIndex + 1) % _inspirationalQuotes.length;
            });
            _quoteFadeController.forward();
          }
        });
      }
    });

    // Auto-navigate after 2.8 seconds. Held so it can be cancelled when the
    // reader taps to skip, or the screen is disposed first.
    _autoAdvanceTimer = Timer(
      const Duration(milliseconds: 2800),
      _navigateToHome,
    );
  }

  void _navigateToHome() {
    if (!mounted) return;
    _quoteTimer?.cancel();
    _autoAdvanceTimer?.cancel();

    // Straight to Home for a signed-in reader, or the login page otherwise.
    final state = AppStateController();
    final Widget destination =
        state.isLoggedIn ? const HomeScreen() : const LoginScreen();
    Navigator.pushReplacement(
      context,
      SmoothPageRoute(child: destination),
    );

    // Cold-started by tapping a reminder: land on Home first (above) so the
    // back button behaves normally, then stack the tapped message on top of
    // it — same two calls as the live-tap listener in main.dart, just
    // sequenced instead of racing a Navigator that doesn't exist yet.
    final insight = _pendingNotificationInsight;
    if (state.isLoggedIn && insight != null) {
      Navigator.push(
        context,
        SeamlessMessagePageRoute(
          child: DailyMessageScreen(insight: insight, hadith: null),
        ),
      );
    }
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
                                      color: const Color(0x20D1BE93),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0x30E0CEB0),
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
                                    gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFFFFFDFC),
                                        Color(0xFFFAF5EB),
                                        Color(0xFFF1E6D3),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: const Color(0xFFD6BE88),
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
                                      color: AppColors.primaryGreen,
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
                        const Text(
                          'طيّب قلبك',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF26352C),
                            fontFamily: kSans,
                            letterSpacing: -0.5,
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
                            color: const Color(0xFFD6BE88),
                          ),
                        ),
                        const SizedBox(height: 10),

                        const Text(
                          'أحاديث نبوية وهدايات قلبية',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF5A7061),
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
                              color: const Color(0x99FAF6EE),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0x40D1BE93),
                              ),
                            ),
                            child: Text(
                              _inspirationalQuotes[_currentQuoteIndex],
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF385240),
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
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF94815B),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF385240),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF94815B),
                              ),
                            ),
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
