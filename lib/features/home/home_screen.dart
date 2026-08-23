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
            onOpenCommunity: () {
              setState(() => _currentTabIndex = 1);
            },
            onHeartClick: () {
              final insight = _repo.getRandomInsight();
              final hadith = _repo.getByNumber(insight.hadithNumber);
              Navigator.push(
                context,
                SmoothPageRoute(
                  child: DailyMessageScreen(
                    insight: insight,
                    hadith: hadith,
                  ),
                ),
              );
            },
          ),

          // Tab 1: Community Posts ("جميع المجتمع")
          CommunityScreen(
            onSwitchToShareTab: () {
              setState(() => _currentTabIndex = 2);
            },
          ),

          // Tab 2: Share / Add Message ("المشاركة")
          AddMessageScreen(
            onPostCreated: () {
              setState(() => _currentTabIndex = 1); // Switch to community to see the new post
            },
          ),
        ],
      ),

      // Persistent Unified Bottom Navigation Bar that never jumps or shifts
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
  final VoidCallback onOpenCommunity;
  final VoidCallback onHeartClick;

  const _HomeMainView({
    required this.onOpenDrawer,
    required this.onOpenAllHadiths,
    required this.onOpenCommunity,
    required this.onHeartClick,
  });

  @override
  Widget build(BuildContext context) {
    final state = AppStateController();
    final isDark = state.isDarkMode;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final cardDiameter = (screenWidth * 0.78).clamp(280.0, 330.0);

    final titleColor = isDark ? AppColors.primaryTextDark : const Color(0xFF26352C);

    return AppBackground(
      showBottomLandscape: true,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 6),

            // Top Header: Left = All Hadiths Menu, Right = Greeting + Profile Avatar (Opens Settings / Auth)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left (in LTR context or Right in RTL): Drawer / Settings button
                  _HeaderIconButton(
                    icon: Icons.menu_rounded,
                    tooltip: 'الإعدادات والملف الشخصي',
                    isDark: isDark,
                    onPressed: onOpenDrawer,
                  ),

                  // Center: Browse all Hadiths Pill
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: onOpenAllHadiths,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardDark : const Color(0xFFFAF6EE),
                        borderRadius: BorderRadius.circular(16),
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

                  // Right: Profile Avatar
                  _HeaderProfileAvatar(
                    isDark: isDark,
                    onTap: onOpenDrawer,
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

            // Main Interactive Realistic Heartbeat "طيّب قلبك" Circle
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

/// Dynamic Living Heartbeat Circle with Rhythmic Lub-Dub Pulse & Orbiting Ambient Rings
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
  late AnimationController _heartbeatController;
  late Animation<double> _heartbeatAnimation;

  late AnimationController _orbitController;
  late AnimationController _clickController;
  late Animation<double> _clickScaleAnimation;

  bool _isHovered = false;

  @override
  void initState() {
    super.initState();

    // Authentic Heartbeat Cycle (Lub-Dub rhythmic pulse: thump-thump ... rest)
    _heartbeatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _heartbeatAnimation = TweenSequence<double>([
      // First Systolic Thump (Lub)
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.055)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 14,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.055, end: 1.015)
            .chain(CurveTween(curve: Curves.easeInOutQuad)),
        weight: 10,
      ),
      // Second Stronger Systolic Thump (Dub)
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.015, end: 1.075)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 16,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.075, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 22,
      ),
      // Resting Diastole period
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 38,
      ),
    ]).animate(_heartbeatController);

    // Orbiting slow background halo rotation
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();

    // Tactile Click animation
    _clickController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    _clickScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.92)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.92, end: 1.04)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 55,
      ),
    ]).animate(_clickController);
  }

  @override
  void dispose() {
    _heartbeatController.dispose();
    _orbitController.dispose();
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
            _orbitController,
            _clickScaleAnimation,
          ]),
          builder: (context, child) {
            double totalScale = _heartbeatAnimation.value * _clickScaleAnimation.value;
            if (_isHovered) totalScale *= 1.025;

            return Transform.scale(
              scale: totalScale,
              child: child,
            );
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Moving Outer Orbiting Dashed Ring 1
              RotationTransition(
                turns: _orbitController,
                child: Container(
                  width: widget.cardDiameter + 68,
                  height: widget.cardDiameter + 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0x30D1BE93),
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              // Moving Reverse Orbiting Dotted Ring 2
              RotationTransition(
                turns: ReverseAnimation(_orbitController),
                child: Container(
                  width: widget.cardDiameter + 42,
                  height: widget.cardDiameter + 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0x45D1BE93),
                      width: 1.2,
                    ),
                  ),
                ),
              ),

              // Glowing Ambient Golden Wave Aura
              AnimatedBuilder(
                animation: _heartbeatAnimation,
                builder: (context, child) {
                  return Container(
                    width: widget.cardDiameter + 24 * _heartbeatAnimation.value,
                    height: widget.cardDiameter + 24 * _heartbeatAnimation.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0x22D1BE93),
                      boxShadow: [
                        BoxShadow(
                          color: _isHovered
                              ? const Color(0x60E0CEB0)
                              : const Color(0x35E0CEB0),
                          blurRadius: 40 * _heartbeatAnimation.value,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Main Heart Face Circle
              Container(
                width: widget.cardDiameter,
                height: widget.cardDiameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: widget.isDark
                        ? [
                            const Color(0xFF26352C),
                            const Color(0xFF1C2720),
                            const Color(0xFF141D17),
                          ]
                        : [
                            const Color(0xFFFFFDFC),
                            const Color(0xFFFAF5EB),
                            const Color(0xFFF1E6D3),
                          ],
                  ),
                  border: Border.all(
                    color: _isHovered
                        ? const Color(0xFFE2CB96)
                        : const Color(0xFFD6BE88),
                    width: 3.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x35B9A06A),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Top Emblem: Heart with Leaf
                    AssetHelper.assetOrFallback(
                      assetPath: 'assets/images/heart_leaf_emblem.png',
                      width: 64,
                      height: 64,
                      fallback: const Icon(
                        Icons.favorite_rounded,
                        color: Color(0xFF385240),
                        size: 44,
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

                    // Spiritual, Elegant & Concise Subtitle
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'انقر لتهدأ روحك بنور النبوة 🌿',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                          color: widget.isDark ? AppColors.gold : const Color(0xFF3B5644),
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

class _HeaderIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool isDark;
  final VoidCallback onPressed;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.isDark,
    required this.onPressed,
  });

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<_HeaderIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onPressed();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.88 : 1.0,
          duration: const Duration(milliseconds: 140),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: widget.isDark ? AppColors.cardDark : const Color(0xFFFAF6EE),
              border: Border.all(color: const Color(0x60D1BE93)),
              boxShadow: const [
                BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
            child: Icon(
              widget.icon,
              color: widget.isDark ? AppColors.primaryTextDark : const Color(0xFF26352C),
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderProfileAvatar extends StatefulWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _HeaderProfileAvatar({
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_HeaderProfileAvatar> createState() => _HeaderProfileAvatarState();
}

class _HeaderProfileAvatarState extends State<_HeaderProfileAvatar> {
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
              color: widget.isDark ? AppColors.softCreamDark : const Color(0xFFFBF8F2),
              border: Border.all(
                color: const Color(0xFFD6BE88),
                width: 1.6,
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
              Icons.person_outline_rounded,
              color: widget.isDark ? AppColors.gold : const Color(0xFF385240),
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
