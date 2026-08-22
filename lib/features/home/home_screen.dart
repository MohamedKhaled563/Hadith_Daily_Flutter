import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/bottom_navigation.dart';
import '../../core/widgets/asset_helper.dart';
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
    if (_currentTabIndex == 1) {
      return Scaffold(
        body: const CommunityScreen(),
        bottomNavigationBar: BottomNavigation(
          currentIndex: _currentTabIndex,
          onTap: (index) => setState(() => _currentTabIndex = index),
        ),
      );
    }

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

    // Card diameter: Large and responsive, occupying ~82% of screen width
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
                    IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HadithListScreen(),
                          ),
                        );
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      icon: const Icon(
                        Icons.menu,
                        color: Color(0xFF26352C),
                        size: 28,
                      ),
                      tooltip: 'جميع الأحاديث',
                    ),

                    // Right: Greeting Text + Leaf + Large Profile Icon
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.eco_rounded,
                          size: 18,
                          color: Color(0xFF5A7A62),
                        ),
                        const SizedBox(width: 4),
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
                        Container(
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
                    assetPath: 'assets/images/golden_divider.svg',
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

            // Main Large Multi-Layered Circular Card "طيّب قلبك"
            GestureDetector(
              onTap: () {
                final insight = _repo.getRandomInsight();
                final hadith = _repo.getByNumber(insight.hadithNumber);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DailyMessageScreen(
                      insight: insight,
                      hadith: hadith,
                    ),
                  ),
                );
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Layer 1: Outermost Ambient Glow
                  Container(
                    width: cardDiameter + 38,
                    height: cardDiameter + 38,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0x35FAF4E8),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x30E0CEB0),
                          blurRadius: 36,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                  ),

                  // Layer 2: Translucent Ring
                  Container(
                    width: cardDiameter + 16,
                    height: cardDiameter + 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0x45FAF5EC),
                      border: Border.all(
                        color: const Color(0x65D4BE92),
                        width: 1.5,
                      ),
                    ),
                  ),

                  // Layer 3: Main Gold Border and Card Face
                  Container(
                    width: cardDiameter,
                    height: cardDiameter,
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
                          blurRadius: 28,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Top Emblem: Heart with Leaf and Dot
                        AssetHelper.assetOrFallback(
                          assetPath: 'assets/images/heart_leaf_emblem.svg',
                          width: 66,
                          height: 66,
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
                          assetPath: 'assets/images/golden_divider.svg',
                          width: 85,
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
