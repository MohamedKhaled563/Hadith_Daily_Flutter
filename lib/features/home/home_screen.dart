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

    return Scaffold(
      body: AppBackground(
        showBottomLandscape: true,
        child: Column(
          children: [
            const SizedBox(height: 12),

            // Top Header Area with Menu on Right & User Greeting on Left (RTL)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Menu / All Hadiths Icon Button
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HadithListScreen(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.menu,
                      color: AppColors.primaryText,
                      size: 26,
                    ),
                    tooltip: 'القائمة',
                  ),

                  // Greeting & Profile Icon
                  Row(
                    children: [
                      const Text(
                        'أهلاً أميرة',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryText,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.card,
                          border: Border.all(
                            color: AppColors.primaryGreen.withOpacity(0.4),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.person_outline,
                          color: AppColors.primaryGreen,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(flex: 2),

            // Question: هل سمعت كلام النبي ﷺ اليوم؟
            Column(
              children: [
                const Text(
                  'هل سمعت',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryText,
                    fontFamily: 'Tajawal',
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'كلام النبي',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'ﷺ',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'اليوم؟',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Gold flourish divider
                AssetHelper.assetOrFallback(
                  assetPath: 'assets/images/golden_divider.svg',
                  width: 100,
                  height: 16,
                  fallback: Container(
                    width: 60,
                    height: 2,
                    color: AppColors.gold.withOpacity(0.5),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Central Interactive Plate "طيّب قلبك" (matching home.png & home page.png)
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
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFFFDFC),
                      Color(0xFFF9F5EC),
                      Color(0xFFF1E8D9),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFB9A06A).withOpacity(0.28),
                      blurRadius: 36,
                      offset: const Offset(0, 14),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFFD1BE93),
                    width: 3.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Emblem Top
                    AssetHelper.assetOrFallback(
                      assetPath: 'assets/images/heart_leaf_emblem.svg',
                      width: 56,
                      height: 56,
                      fallback: const Icon(
                        Icons.favorite_border,
                        color: AppColors.primaryGreen,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Calligraphy Title
                    const Text(
                      'طيّب قلبك',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryText,
                        fontFamily: 'Tajawal',
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Mini Divider
                    AssetHelper.assetOrFallback(
                      assetPath: 'assets/images/golden_divider.svg',
                      width: 70,
                      height: 12,
                      fallback: const SizedBox(height: 4),
                    ),
                    const SizedBox(height: 4),

                    // Subtitle
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'اضغط لاختبار رسالة عشوائية مربوطة بحديث',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryGreen,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(flex: 3),

            // Bottom Navigation Bar
            BottomNavigation(
              currentIndex: _currentTabIndex,
              onTap: (index) => setState(() => _currentTabIndex = index),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
