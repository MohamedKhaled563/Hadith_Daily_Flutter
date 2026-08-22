import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/bottom_navigation.dart';
import '../../core/widgets/asset_helper.dart';
import '../../core/widgets/smooth_page_route.dart';
import '../../data/repositories/hadith_repository.dart';
import '../messages/daily_message_screen.dart';
import '../hadith/hadith_list_screen.dart';
import '../community/community_screen.dart';
import '../share/add_message_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;
  final HadithRepository _repo = HadithRepository();

  @override
  Widget build(BuildContext context) {
    // Index 1: جميع الأحاديث
    if (_currentTabIndex == 1) {
      return Scaffold(
        body: const HadithListScreen(),
        bottomNavigationBar: BottomNavigation(
          currentIndex: _currentTabIndex,
          onTap: (index) => setState(() => _currentTabIndex = index),
        ),
      );
    }

    // Index 2: المشاركة
    if (_currentTabIndex == 2) {
      return Scaffold(
        body: const AddMessageScreen(),
        bottomNavigationBar: BottomNavigation(
          currentIndex: _currentTabIndex,
          onTap: (index) => setState(() => _currentTabIndex = index),
        ),
      );
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Card diameter: Large and responsive, occupying ~80% of screen width
    final cardDiameter = (screenWidth * 0.80).clamp(290.0, 340.0);

    return Scaffold(
      body: AppBackground(
        showBottomLandscape: true,
        child: Column(
          children: [
            const SizedBox(height: 8),

            // Top Header: Left = Hamburger, Right = Greeting + Large Profile
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left: Hamburger Menu (Opens All Hadiths list)
                    _HeaderIconButton(
                      icon: Icons.menu,
                      tooltip: 'جميع الأحاديث',
                      onPressed: () {
                        Navigator.push(
                          context,
                          SmoothPageRoute(
                            child: const HadithListScreen(),
                          ),
                        );
                      },
                    ),

                    // Right: Greeting Text + Leaf + Large Profile Icon
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AssetHelper.assetOrFallback(
                          assetPath: 'assets/images/leaf_accent.png',
                          width: 20,
                          height: 20,
                          fallback: const Icon(
                            Icons.eco_rounded,
                            size: 18,
                            color: Color(0xFF5A7A62),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'أهلاً أميرة',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF26352C),
                            fontFamily: 'Tajawal',
                          ),
                        ),
                        const SizedBox(width: 10),
                        _HeaderProfileAvatar(
                          onTap: () {
                            Navigator.push(
                              context,
                              SmoothPageRoute(
                                child: const CommunityScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: (screenHeight * 0.02).clamp(8.0, 20.0)),

            // Hero Title: هل سمعت كلام النبي ﷺ اليوم؟
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const Text(
                    'هل سمعت',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF26352C),
                      fontFamily: 'Tajawal',
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: const [
                      Text(
                        'كلام النبي',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF26352C),
                          fontFamily: 'Tajawal',
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'ﷺ',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3B5644),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'اليوم؟',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF26352C),
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Gold & Leaf Flourish Divider
                  AssetHelper.assetOrFallback(
                    assetPath: 'assets/images/golden_divider.png',
                    width: 140,
                    height: 22,
                    fallback: Container(
                      width: 80,
                      height: 2,
                      color: const Color(0xFFD6BE88),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: (screenHeight * 0.02).clamp(10.0, 22.0)),

            // Main Interactive Circular Card "طيّب قلبك" with Smooth Organic Breathing & Hover/Click Physics
            _InteractiveHadithCircle(
              cardDiameter: cardDiameter,
              onTap: () {
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

            const Spacer(),

            // Floating Bottom Navigation
            BottomNavigation(
              currentIndex: _currentTabIndex,
              onTap: (index) => setState(() => _currentTabIndex = index),
            ),
          ],
        ),
      ),
    );
  }
}

/// Interactive Circular Card with Subtle Ambient Breathing Pulse, Hover Elevation & Tactile Tap Feedback
class _InteractiveHadithCircle extends StatefulWidget {
  final double cardDiameter;
  final VoidCallback onTap;

  const _InteractiveHadithCircle({
    required this.cardDiameter,
    required this.onTap,
  });

  @override
  State<_InteractiveHadithCircle> createState() => _InteractiveHadithCircleState();
}

class _InteractiveHadithCircleState extends State<_InteractiveHadithCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    // Gentle, peaceful breathing animation (6-second cycle for spiritual tranquility)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.035).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOutSine,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            // Combine organic breathing with user interaction (hover & press)
            double scale = _pulseAnimation.value;
            if (_isHovered) scale *= 1.025;
            if (_isPressed) scale *= 0.95;

            return Transform.scale(
              scale: scale,
              child: child,
            );
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Layer 1: Outermost Soft Golden Ambient Aura
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: widget.cardDiameter + (_isHovered ? 48 : 38),
                height: widget.cardDiameter + (_isHovered ? 48 : 38),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0x35FAF4E8),
                  boxShadow: [
                    BoxShadow(
                      color: _isHovered
                          ? const Color(0x55E0CEB0)
                          : const Color(0x30E0CEB0),
                      blurRadius: _isHovered ? 44 : 36,
                      spreadRadius: _isHovered ? 10 : 6,
                    ),
                  ],
                ),
              ),

              // Layer 2: Translucent Glass Ring with Subtle Border
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: widget.cardDiameter + 16,
                height: widget.cardDiameter + 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isHovered
                      ? const Color(0x65FAF5EC)
                      : const Color(0x45FAF5EC),
                  border: Border.all(
                    color: _isHovered
                        ? const Color(0x95D4BE92)
                        : const Color(0x65D4BE92),
                    width: _isHovered ? 2.0 : 1.5,
                  ),
                ),
              ),

              // Layer 3: Main Gold Border and Card Face
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: widget.cardDiameter,
                height: widget.cardDiameter,
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
                    color: _isHovered
                        ? const Color(0xFFE2CB96)
                        : const Color(0xFFD6BE88),
                    width: _isHovered ? 4.0 : 3.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _isHovered
                          ? const Color(0x45B9A06A)
                          : const Color(0x35B9A06A),
                      blurRadius: _isHovered ? 36 : 28,
                      offset: Offset(0, _isHovered ? 14 : 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Top Emblem: Heart with Leaf and Dot
                    AssetHelper.assetOrFallback(
                      assetPath: 'assets/images/heart_leaf_emblem.png',
                      width: 68,
                      height: 68,
                      fallback: const Icon(
                        Icons.favorite_border,
                        color: Color(0xFF385240),
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Title: طيّب قلبك
                    const Text(
                      'طيّب قلبك',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF26352C),
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
                      fallback: const SizedBox(height: 6),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle: اضغط لاختيار رسالة عشوائية مربوطة بحديث
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'اضغط لاختيار رسالة عشوائية\nمربوطة بحديث',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3B5644),
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
  final VoidCallback onPressed;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
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
              color: _isPressed ? const Color(0x20000000) : Colors.transparent,
            ),
            child: Icon(
              widget.icon,
              color: const Color(0xFF26352C),
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderProfileAvatar extends StatefulWidget {
  final VoidCallback onTap;

  const _HeaderProfileAvatar({required this.onTap});

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
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFBF8F2),
              border: Border.all(
                color: const Color(0xFF63836B),
                width: 1.8,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x10000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              color: Color(0xFF385240),
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}
