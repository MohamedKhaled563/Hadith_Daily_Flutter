import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/asset_helper.dart';
import '../../data/models/hadith.dart';
import '../../data/repositories/hadith_repository.dart';
import 'hadith_detail_screen.dart';

class HadithListScreen extends StatefulWidget {
  const HadithListScreen({super.key});

  @override
  State<HadithListScreen> createState() => _HadithListScreenState();
}

class _HadithListScreenState extends State<HadithListScreen> {
  final HadithRepository _repo = HadithRepository();
  bool _showOnlyFavorites = false;
  final Set<int> _favorites = {};

  @override
  Widget build(BuildContext context) {
    final allHadiths = _repo.hadiths;
    final displayedHadiths = _showOnlyFavorites
        ? allHadiths.where((h) => _favorites.contains(h.number)).toList()
        : allHadiths;

    return Scaffold(
      body: AppBackground(
        child: Column(
          children: [
            const SizedBox(height: 12),

            // Top Header matching جميع الاحاديث.png
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  _buildCircleButton(
                    icon: Icons.chevron_right,
                    onTap: () => Navigator.pop(context),
                  ),

                  // Center Emblem + Divider
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AssetHelper.assetOrFallback(
                        assetPath: 'assets/images/heart_leaf_emblem.svg',
                        width: 44,
                        height: 44,
                        fallback: const Icon(
                          Icons.favorite_border,
                          color: AppColors.primaryGreen,
                          size: 28,
                        ),
                      ),
                      AssetHelper.assetOrFallback(
                        assetPath: 'assets/images/golden_divider.svg',
                        width: 60,
                        height: 10,
                        fallback: const SizedBox(height: 2),
                      ),
                    ],
                  ),

                  // Bookmark Filter button
                  _buildCircleButton(
                    icon: _showOnlyFavorites ? Icons.bookmark : Icons.bookmark_border,
                    iconColor: _showOnlyFavorites ? AppColors.gold : AppColors.primaryText,
                    onTap: () {
                      setState(() => _showOnlyFavorites = !_showOnlyFavorites);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Title Area
            Text(
              _showOnlyFavorites ? 'الأحاديث المحفوظة' : 'جميع الأحاديث',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
                fontFamily: 'Tajawal',
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'استكشف و اقرأ الأحاديث النبوية و شرحها',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.secondaryText,
                fontFamily: 'Tajawal',
              ),
            ),

            const SizedBox(height: 16),

            // Hadith List matching جميع الاحاديث.png
            Expanded(
              child: displayedHadiths.isEmpty
                  ? Center(
                      child: Text(
                        _showOnlyFavorites ? 'لا توجد أحاديث محفوظة' : 'لا توجد أحاديث',
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.secondaryText,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: displayedHadiths.length,
                      itemBuilder: (context, index) {
                        final hadith = displayedHadiths[index];
                        final isEven = index % 2 == 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: const Color(0x59D1BE93),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x05000000),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => HadithDetailScreen(
                                    hadith: hadith,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Right text in RTL
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'الحديث ${_toArabic(hadith.number)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.gold,
                                            fontFamily: 'Tajawal',
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          hadith.text,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            height: 1.6,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.primaryText,
                                            fontFamily: 'Tajawal',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Badge (Flower / Leaf) + Chevron
                                  AssetHelper.assetOrFallback(
                                    assetPath: isEven
                                        ? 'assets/images/flower_badge.svg'
                                        : 'assets/images/leaf_badge.svg',
                                    width: 38,
                                    height: 38,
                                    fallback: Container(
                                      width: 38,
                                      height: 38,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.secondaryCard,
                                      ),
                                      child: const Icon(
                                        Icons.spa,
                                        size: 18,
                                        color: AppColors.primaryGreen,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.chevron_left,
                                    size: 20,
                                    color: Color(0xFFAAA9A3),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _toArabic(int num) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return num.toString().split('').map((d) => arabicDigits[int.parse(d)]).join('');
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = AppColors.primaryText,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.card,
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0x66D1BE93),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(icon, size: 22, color: iconColor),
      ),
    );
  }
}
