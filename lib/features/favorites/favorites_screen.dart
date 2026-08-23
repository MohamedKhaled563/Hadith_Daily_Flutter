import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_state_controller.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/asset_helper.dart';
import '../../core/widgets/islamic_pattern_painter.dart';
import '../../core/widgets/smooth_page_route.dart';
import '../../data/models/hadith.dart';
import '../../data/models/insight.dart';
import '../../data/repositories/hadith_repository.dart';
import '../hadith/hadith_detail_screen.dart';
import '../messages/daily_message_screen.dart';

class FavoritesScreen extends StatefulWidget {
  final bool isRootTab;
  final Function(int)? onTabSelected;

  const FavoritesScreen({
    super.key,
    this.isRootTab = false,
    this.onTabSelected,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final HadithRepository _repo = HadithRepository();
  final AppStateController _state = AppStateController();
  int _selectedCategory = 0; // 0: رسائل اليوم, 1: الأحاديث الشريفة

  void _copyText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'تم نسخ النص بنجاح 🌿',
          textDirection: TextDirection.rtl,
          style: TextStyle(fontFamily: 'Tajawal'),
        ),
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _state.isDarkMode;
    final textColor = isDark ? AppColors.primaryTextDark : const Color(0xFF26352C);
    final subTextColor = isDark ? AppColors.secondaryTextDark : const Color(0xFF5A7061);

    final favoriteInsights = _repo.getFavoriteInsights();
    final favoriteHadiths = _repo.getFavoriteHadiths();

    return Scaffold(
      body: AppBackground(
        showBottomLandscape: true,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const SizedBox(height: 6),

              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button if pushed, or decorative icon
                    if (Navigator.canPop(context) && !widget.isRootTab)
                      _buildCircleButton(
                        icon: Icons.chevron_right_rounded,
                        isDark: isDark,
                        onTap: () => Navigator.pop(context),
                      )
                    else
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? AppColors.cardDark : const Color(0xFFFAF6EE),
                          border: Border.all(color: const Color(0x60D1BE93)),
                        ),
                        child: Center(
                          child: AssetHelper.assetOrFallback(
                            assetPath: 'assets/images/leaf_accent.png',
                            width: 22,
                            height: 22,
                            fallback: const Icon(
                              Icons.bookmark_rounded,
                              color: Color(0xFFC59B27),
                              size: 20,
                            ),
                          ),
                        ),
                      ),

                    // Title
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'المفضلة والمحفوظات',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                        const SizedBox(height: 2),
                        AssetHelper.assetOrFallback(
                          assetPath: 'assets/images/golden_divider.png',
                          width: 80,
                          height: 10,
                          fallback: Container(
                            width: 40,
                            height: 1.5,
                            color: const Color(0xFFD6BE88),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(width: 44),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Category Switcher Pills
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2F23) : const Color(0xFFECE4D5),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: const Color(0x60D1BE93)),
                  ),
                  child: Row(
                    children: [
                      // Tab 0: رسائل اليوم
                      Expanded(
                        child: _buildCategoryTab(
                          title: 'رسائل اليوم (${favoriteInsights.length})',
                          icon: Icons.auto_awesome_rounded,
                          isSelected: _selectedCategory == 0,
                          isDark: isDark,
                          onTap: () => setState(() => _selectedCategory = 0),
                        ),
                      ),
                      // Tab 1: الأحاديث
                      Expanded(
                        child: _buildCategoryTab(
                          title: 'الأحاديث (${favoriteHadiths.length})',
                          icon: Icons.menu_book_rounded,
                          isSelected: _selectedCategory == 1,
                          isDark: isDark,
                          onTap: () => setState(() => _selectedCategory = 1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // List of Favorite Items
              Expanded(
                child: _selectedCategory == 0
                    ? _buildInsightsList(favoriteInsights, isDark, textColor, subTextColor)
                    : _buildHadithsList(favoriteHadiths, isDark, textColor, subTextColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTab({
    required String title,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF2E4535) : const Color(0xFFFFFDFC))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? (isDark ? AppColors.gold : const Color(0xFF385240))
                  : (isDark ? AppColors.secondaryTextDark : const Color(0xFF7A8D80)),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? (isDark ? AppColors.primaryTextDark : const Color(0xFF26352C))
                    : (isDark ? AppColors.secondaryTextDark : const Color(0xFF7A8D80)),
                fontFamily: 'Tajawal',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsList(
    List<Insight> items,
    bool isDark,
    Color textColor,
    Color subTextColor,
  ) {
    if (items.isEmpty) {
      return _buildEmptyState(
        title: 'لا توجد رسائل محفوظة بعد',
        subtitle: 'اضغط على أيقونة الإشارة المرجعية 🔖 أعلى أي رسالة يومية لحفظها في قائمتك المفضلة للرجوع إليها دائماً.',
        isDark: isDark,
        textColor: textColor,
        subTextColor: subTextColor,
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final insight = items[index];
        final hadith = _repo.getByNumber(insight.hadithNumber);

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF23342A), const Color(0xFF1B2A20)]
                  : [const Color(0xFFEFE8DC), const Color(0xFFECE4D7)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0x60D1BE93) : const Color(0x80D1BE93),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? const Color(0x40000000) : const Color(0x153B5644),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // Subtle Islamic watermark
                Positioned.fill(
                  child: CustomPaint(
                    painter: IslamicWatermarkPainter(
                      color: isDark ? const Color(0x14D1BE93) : const Color(0x20B89F70),
                      strokeWidth: 1.0,
                    ),
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Category pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2B3F32) : const Color(0xFFFAF6EE),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0x60D1BE93)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.eco_rounded, size: 12, color: Color(0xFF385240)),
                                const SizedBox(width: 4),
                                Text(
                                  insight.category,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.gold : const Color(0xFF385240),
                                    fontFamily: 'Tajawal',
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Unsave / Remove Button
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _repo.toggleFavoriteInsight(insight.message);
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تمت الإزالة من المحفوظات', textDirection: TextDirection.rtl, style: TextStyle(fontFamily: 'Tajawal')),
                                  duration: Duration(seconds: 1),
                                  backgroundColor: Color(0xFF5A7061),
                                ),
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.bookmark_remove_rounded,
                                size: 20,
                                color: Color(0xFFC73E3E),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Quote Body
                      Text(
                        '« ${insight.message} »',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.7,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          fontFamily: 'Tajawal',
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Bottom actions & related hadith
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Related Hadith link
                          if (hadith != null)
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  SmoothPageRoute(
                                    child: HadithDetailScreen(hadith: hadith),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1B2B20) : const Color(0xFFFAF5EB),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0x50D1BE93)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.menu_book_rounded, size: 13, color: Color(0xFFC59B27)),
                                    const SizedBox(width: 5),
                                    Text(
                                      'الحديث ${hadith.number}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? AppColors.gold : const Color(0xFF385240),
                                        fontFamily: 'Tajawal',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Action icons (View in card, Copy)
                          Row(
                            children: [
                              // View full card
                              IconButton(
                                icon: const Icon(Icons.fullscreen_rounded, size: 20),
                                color: const Color(0xFF385240),
                                tooltip: 'عرض في بطاقة رسالة اليوم',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    SeamlessMessagePageRoute(
                                      child: DailyMessageScreen(
                                        insight: insight,
                                        hadith: hadith,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              // Copy
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                color: const Color(0xFF385240),
                                tooltip: 'نسخ الرسالة',
                                onPressed: () => _copyText(
                                  '« ${insight.message} »\n— طيّب قلبك 🌿',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHadithsList(
    List<Hadith> items,
    bool isDark,
    Color textColor,
    Color subTextColor,
  ) {
    if (items.isEmpty) {
      return _buildEmptyState(
        title: 'لا توجد أحاديث محفوظة بعد',
        subtitle: 'تصفح قائمة الأربعين النووية واضغط على علامة المفضلة لأي حديث لتحفظه هنا وتصل إليه سريعاً.',
        isDark: isDark,
        textColor: textColor,
        subTextColor: subTextColor,
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final hadith = items[index];

        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              SmoothPageRoute(
                child: HadithDetailScreen(hadith: hadith),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : const Color(0xFFFFFDFC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFD6BE88), width: 1.1),
              boxShadow: [
                BoxShadow(
                  color: isDark ? const Color(0x40000000) : const Color(0x103B5644),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Hadith Number Emblem
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? const Color(0xFF2A3F31) : const Color(0xFFFAF5EB),
                    border: Border.all(color: const Color(0xFFD6BE88)),
                  ),
                  child: Center(
                    child: Text(
                      '${hadith.number}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC59B27),
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 14),

                // Title & Reference
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hadith.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hadith.reference,
                        style: TextStyle(
                          fontSize: 12,
                          color: subTextColor,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ],
                  ),
                ),

                // Remove bookmark button
                IconButton(
                  icon: const Icon(Icons.bookmark_remove_rounded, color: Color(0xFFC73E3E)),
                  onPressed: () {
                    setState(() {
                      _repo.toggleFavoriteHadith(hadith.number);
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required String title,
    required String subtitle,
    required bool isDark,
    required Color textColor,
    required Color subTextColor,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFF233529) : const Color(0xFFFAF5EB),
                border: Border.all(color: const Color(0x80D1BE93), width: 1.3),
              ),
              child: Center(
                child: AssetHelper.assetOrFallback(
                  assetPath: 'assets/images/heart_leaf_emblem.png',
                  width: 44,
                  height: 44,
                  fallback: const Icon(
                    Icons.bookmark_border_rounded,
                    color: Color(0xFFC59B27),
                    size: 36,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: textColor,
                fontFamily: 'Tajawal',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: subTextColor,
                fontFamily: 'Tajawal',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? AppColors.cardDark : const Color(0xFFFAF6EE),
          border: Border.all(color: const Color(0x60D1BE93)),
          boxShadow: const [
            BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Icon(
          icon,
          size: 22,
          color: isDark ? AppColors.primaryTextDark : const Color(0xFF26352C),
        ),
      ),
    );
  }
}
