import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_state_controller.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/bottom_navigation.dart';
import '../../core/widgets/asset_helper.dart';
import '../../core/widgets/smooth_page_route.dart';
import '../../data/repositories/hadith_repository.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const SettingsDrawer(),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          // Tab 0: Home Main Screen
          _HomeMainView(
            onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
            onOpenAllHadiths: () {
              Navigator.push(
                context,
                SmoothPageRoute(
                  child: const HadithListScreen(),
                ),
              );
            },
            onOpenFavorites: () {
              setState(() => _currentTabIndex = 1);
            },
            onOpenCommunity: () {
              setState(() => _currentTabIndex = 2);
            },
            onHeartClick: () {
              final insight = _repo.getRandomInsight();
              final hadith = _repo.getByNumber(insight.hadithNumber);
              Navigator.push(
                context,
                SeamlessMessagePageRoute(
                  child: DailyMessageScreen(
                    insight: insight,
                    hadith: hadith,
                    onTabSelected: (index) {
                      Navigator.pop(context);
                      setState(() => _currentTabIndex = index);
                    },
                  ),
                ),
              );
            },
          ),

          // Tab 1: Favorites / Bookmarked messages ("المفضلة")
          FavoritesScreen(
            isRootTab: true,
            onTabSelected: (index) => setState(() => _currentTabIndex = index),
          ),

          // Tab 2: Community Posts ("المشاركات")
          CommunityScreen(
            onSwitchToShareTab: () {
              setState(() => _currentTabIndex = 3);
            },
          ),

          // Tab 3: Share / Add Message ("اكتب رسالة")
          AddMessageScreen(
            onPostCreated: () {
              setState(() => _currentTabIndex = 2); // Switch to community to see the new post
            },
          ),
        ],
      ),

      // Persistent Unified Bottom Navigation Bar (4 tabs)
      bottomNavigationBar: BottomNavigation(
        currentIndex: _currentTabIndex,
        onTap: (index) => setState(() => _currentTabIndex = index),
      ),
    );
  }
}

class _HomeMainView extends StatelessWidget {
  final VoidCallback onOpenDrawer;
  final VoidCallback onOpenAllHadiths;
  final VoidCallback onOpenFavorites;
  final VoidCallback onOpenCommunity;
  final VoidCallback onHeartClick;

  const _HomeMainView({
    required this.onOpenDrawer,
    required this.onOpenAllHadiths,
    required this.onOpenFavorites,
    required this.onOpenCommunity,
    required this.onHeartClick,
  });

  @override
  Widget build(BuildContext context) {
    final state = AppStateController();
    final isDark = state.isDarkMode;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final cardDiameter = (screenWidth * 0.76).clamp(275.0, 325.0);

    final titleColor = isDark ? AppColors.primaryTextDark : const Color(0xFF26352C);

    return AppBackground(
      showBottomLandscape: true,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 6),

            // Top Header: Right Menu Button + Center Pill for All Hadiths + Left Favorites Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Top-Right in RTL: Options Menu Button (with menu icon)
                  _HeaderMenuButton(
                    isDark: isDark,
                    onTap: onOpenDrawer,
                  ),

                  // Center: Browse all Hadiths Pill
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: onOpenAllHadiths,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardDark : const Color(0xFFFAF6EE),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0x60D1BE93),
                        ),
                        boxShadow: const [
                          BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_stories_rounded,
                            size: 16,
                            color: isDark ? AppColors.gold : const Color(0xFF385240),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'الأربعين النووية',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: titleColor,
                              fontFamily: 'Tajawal',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Top-Left in RTL: Favorites / Bookmarks Button
                  _HeaderFavoritesButton(
                    isDark: isDark,
                    onTap: onOpenFavorites,
                  ),
                ],
              ),
            ),

            SizedBox(height: (screenHeight * 0.015).clamp(6.0, 18.0)),

            // Hero Title: هل سمعت كلام النبي ﷺ اليوم؟
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Text(
                    'هل سمعت',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: titleColor,
                      fontFamily: 'Tajawal',
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        'كلام النبي',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: titleColor,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ﷺ',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.gold : const Color(0xFF3B5644),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'اليوم؟',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: titleColor,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Gold & Leaf Flourish Divider
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

            SizedBox(height: (screenHeight * 0.02).clamp(10.0, 24.0)),

            // Main Interactive Meditative Heart Circle with Distinct Hover & Organic Ambient Rings
            _HeartbeatHadithCircle(
              cardDiameter: cardDiameter,
              isDark: isDark,
              onTap: onHeartClick,
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}

/// Dynamic Living Heartbeat Circle with Meditative Balanced Pulse, Distinct Hover Glow & Independent Multi-Layer Rings
class _HeartbeatHadithCircle extends StatefulWidget {
  final double cardDiameter;
  final bool isDark;
  final VoidCallback onTap;

  const _HeartbeatHadithCircle({
    required this.cardDiameter,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_HeartbeatHadithCircle> createState() => _HeartbeatHadithCircleState();
}

class _HeartbeatHadithCircleState extends State<_HeartbeatHadithCircle>
    with TickerProviderStateMixin {
  // 1. Serene Spiritual Heart Pulse (Gentle & Balanced)
  late AnimationController _heartbeatController;
  late Animation<double> _heartbeatAnimation;

  // 2. Multi-speed Independent Orbiting Rings
  late AnimationController _outerOrbitController;
  late AnimationController _innerOrbitController;

  // 3. Independent Fluid Breathing Waves for Surrounding Halos
  late AnimationController _ringsBreathController;
  late Animation<double> _ringsScaleAnimation;
  late Animation<double> _ringsOpacityAnimation;

  // 4. Click Tactile Feedback
  late AnimationController _clickController;
  late Animation<double> _clickScaleAnimation;

  bool _isHovered = false;

  @override
  void initState() {
    super.initState();

    // Balanced Serene Pulse (Soothing 2.8s cycle, peak only 1.026 - calm & natural)
    _heartbeatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();

    _heartbeatAnimation = TweenSequence<double>([
      // Soft gentle expansion
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.026)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 35,
      ),
      // Gentle calm exhale
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.026, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 35,
      ),
      // Peaceful resting pause
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 30,
      ),
    ]).animate(_heartbeatController);

    // Independent Ring 1: Slow majestic clockwise rotation (28 seconds)
    _outerOrbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    )..repeat();

    // Independent Ring 2: Counter-clockwise harmonic rotation (20 seconds)
    _innerOrbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Independent Rings Organic Breathing (4.2 seconds cycle, independent of center)
    _ringsBreathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat(reverse: true);

    _ringsScaleAnimation = Tween<double>(begin: 0.98, end: 1.045).animate(
      CurvedAnimation(parent: _ringsBreathController, curve: Curves.easeInOutCubic),
    );

    _ringsOpacityAnimation = Tween<double>(begin: 0.45, end: 0.85).animate(
      CurvedAnimation(parent: _ringsBreathController, curve: Curves.easeInOut),
    );

    // Tactile Click Animation
    _clickController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    _clickScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.94)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.94, end: 1.03)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 55,
      ),
    ]).animate(_clickController);
  }

  @override
  void dispose() {
    _heartbeatController.dispose();
    _outerOrbitController.dispose();
    _innerOrbitController.dispose();
    _ringsBreathController.dispose();
    _clickController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _clickController.forward(from: 0.0).then((_) {
      _clickController.reverse();
      widget.onTap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _heartbeatAnimation,
            _outerOrbitController,
            _innerOrbitController,
            _ringsBreathController,
            _clickScaleAnimation,
          ]),
          builder: (context, child) {
            // Combine natural gentle pulse + click feedback
            final baseScale = _heartbeatAnimation.value * _clickScaleAnimation.value;

            return AnimatedScale(
              scale: _isHovered ? baseScale * 1.048 : baseScale,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: child,
            );
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Layer A: Outer Independent Orbiting Geometric Ring with 8-Point Islamic Nodes
              AnimatedBuilder(
                animation: _ringsBreathController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _ringsScaleAnimation.value,
                    child: Opacity(
                      opacity: _ringsOpacityAnimation.value,
                      child: child,
                    ),
                  );
                },
                child: RotationTransition(
                  turns: _outerOrbitController,
                  child: SizedBox(
                    width: widget.cardDiameter + 68,
                    height: widget.cardDiameter + 68,
                    child: CustomPaint(
                      painter: _OuterPatternedRingPainter(
                        color: widget.isDark
                            ? const Color(0x70D1BE93)
                            : const Color(0x60D1BE93),
                      ),
                    ),
                  ),
                ),
              ),

              // Layer B: Inner Counter-Rotating Delicate Dashed Ring
              AnimatedBuilder(
                animation: _ringsBreathController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 / _ringsScaleAnimation.value,
                    child: child,
                  );
                },
                child: RotationTransition(
                  turns: ReverseAnimation(_innerOrbitController),
                  child: Container(
                    width: widget.cardDiameter + 38,
                    height: widget.cardDiameter + 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isHovered
                            ? const Color(0xFFD6BE88).withOpacity(0.7)
                            : (widget.isDark
                                ? const Color(0x40D1BE93)
                                : const Color(0x45D1BE93)),
                        width: _isHovered ? 1.8 : 1.3,
                      ),
                    ),
                  ),
                ),
              ),

              // Layer C: Radiant Ambient Golden Glow (Becomes highly vibrant on Hover)
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                width: widget.cardDiameter + (_isHovered ? 26 : 14),
                height: widget.cardDiameter + (_isHovered ? 26 : 14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isHovered
                      ? const Color(0x45E5C378)
                      : (widget.isDark
                          ? const Color(0x20D1BE93)
                          : const Color(0x18D1BE93)),
                  boxShadow: [
                    BoxShadow(
                      color: _isHovered
                          ? const Color(0x70E6CCA0)
                          : (widget.isDark
                              ? const Color(0x35000000)
                              : const Color(0x25B9A06A)),
                      blurRadius: _isHovered ? 48 : 26,
                      spreadRadius: _isHovered ? 8 : 2,
                    ),
                  ],
                ),
              ),

              // Layer D: Main Heart Face Circle
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: widget.cardDiameter,
                height: widget.cardDiameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: widget.isDark
                        ? [
                            _isHovered ? const Color(0xFF2E3F35) : const Color(0xFF26352C),
                            const Color(0xFF1C2720),
                            const Color(0xFF141D17),
                          ]
                        : [
                            _isHovered ? const Color(0xFFFFFFFF) : const Color(0xFFFFFDFC),
                            _isHovered ? const Color(0xFFFDF8EE) : const Color(0xFFFAF5EB),
                            _isHovered ? const Color(0xFFF5EAD7) : const Color(0xFFF1E6D3),
                          ],
                  ),
                  border: Border.all(
                    color: _isHovered
                        ? const Color(0xFFF3DEAE)
                        : const Color(0xFFD6BE88),
                    width: _isHovered ? 4.0 : 3.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _isHovered
                          ? const Color(0x55B9A06A)
                          : const Color(0x28B9A06A),
                      blurRadius: _isHovered ? 34 : 22,
                      offset: Offset(0, _isHovered ? 12 : 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Top Emblem: Heart with Leaf
                    AnimatedScale(
                      scale: _isHovered ? 1.08 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Hero(
                        tag: 'heart_leaf_emblem_hero',
                        child: AssetHelper.assetOrFallback(
                          assetPath: 'assets/images/heart_leaf_emblem.png',
                          width: 64,
                          height: 64,
                          fallback: const Icon(
                            Icons.favorite_rounded,
                            color: Color(0xFF385240),
                            size: 44,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Title: طيّب قلبك
                    Text(
                      'طيّب قلبك',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: widget.isDark ? AppColors.primaryTextDark : const Color(0xFF26352C),
                        fontFamily: 'Tajawal',
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Mini Golden Divider
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

                    // Spiritual & Inviting Subtitle
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        _isHovered ? '✨ اضغط الآن لحديث اليوم ✨' : 'انقر لتهدأ روحك بنور النبوة 🌿',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                          color: _isHovered
                              ? (widget.isDark ? Colors.white : const Color(0xFF26352C))
                              : (widget.isDark ? AppColors.gold : const Color(0xFF3B5644)),
                          fontFamily: 'Tajawal',
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
    );
  }
}

/// Custom Painter for the Outer Islamic Patterned Ring with 8-Point Star Nodes
class _OuterPatternedRingPainter extends CustomPainter {
  final Color color;

  _OuterPatternedRingPainter({required this.color});

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
      ..color = color.withOpacity(0.9)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Draw base outer circle
    canvas.drawCircle(center, radius - 2, ringPaint);

    // Draw 8 celestial decorative nodes
    const int nodes = 8;
    for (int i = 0; i < nodes; i++) {
      final angle = (i * 2 * math.pi) / nodes;
      final nodePos = Offset(
        center.dx + (radius - 2) * math.cos(angle),
        center.dy + (radius - 2) * math.sin(angle),
      );
      canvas.drawCircle(nodePos, 2.6, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _OuterPatternedRingPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _HeaderMenuButton extends StatefulWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _HeaderMenuButton({
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_HeaderMenuButton> createState() => _HeaderMenuButtonState();
}

class _HeaderMenuButtonState extends State<_HeaderMenuButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.90 : 1.0,
          duration: const Duration(milliseconds: 140),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.isDark ? AppColors.cardDark : const Color(0xFFFAF6EE),
              border: Border.all(
                color: const Color(0xFFD6BE88),
                width: 1.4,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x10000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.menu_rounded,
              color: widget.isDark ? AppColors.gold : const Color(0xFF385240),
              size: 23,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderFavoritesButton extends StatefulWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _HeaderFavoritesButton({
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_HeaderFavoritesButton> createState() => _HeaderFavoritesButtonState();
}

class _HeaderFavoritesButtonState extends State<_HeaderFavoritesButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.90 : 1.0,
          duration: const Duration(milliseconds: 140),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.isDark ? AppColors.cardDark : const Color(0xFFFAF6EE),
              border: Border.all(
                color: const Color(0x70D1BE93),
                width: 1.2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.bookmark_border_rounded,
              color: widget.isDark ? AppColors.gold : const Color(0xFF385240),
              size: 21,
            ),
          ),
        ),
      ),
    );
  }
}
