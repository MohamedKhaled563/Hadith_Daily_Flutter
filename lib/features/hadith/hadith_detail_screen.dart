import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/asset_helper.dart';
import '../../data/models/hadith.dart';

class HadithDetailScreen extends StatelessWidget {
  final Hadith hadith;

  const HadithDetailScreen({
    super.key,
    required this.hadith,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Column(
          children: [
            const SizedBox(height: 12),

            // Top Bar matching شرح الحديث.png
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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

                  _buildCircleButton(
                    icon: Icons.share_outlined,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'تم نسخ الحديث والشرح للمشاركة',
                            textDirection: TextDirection.rtl,
                            style: TextStyle(fontFamily: 'Tajawal'),
                          ),
                          backgroundColor: AppColors.primaryGreen,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Title
            Text(
              hadith.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
                fontFamily: 'Tajawal',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'الحديث رقم ${_toArabic(hadith.number)} من الأربعين النووية',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.secondaryText,
                fontFamily: 'Tajawal',
              ),
            ),

            const SizedBox(height: 16),

            // Content Cards matching شرح الحديث.png
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  children: [
                    // Card 1 — نص الحديث
                    _buildSectionCard(
                      title: 'نص الحديث',
                      iconAsset: 'assets/images/flower_badge.svg',
                      fallbackIcon: Icons.format_quote,
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hadith.text,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 2.0,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryText,
                              fontFamily: 'Tajawal',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.secondaryCard,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                hadith.reference,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryGreen,
                                  fontFamily: 'Tajawal',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Card 2 — شرح الحديث
                    _buildSectionCard(
                      title: 'شرح الحديث',
                      iconAsset: 'assets/images/leaf_badge.svg',
                      fallbackIcon: Icons.menu_book,
                      content: Text(
                        hadith.explanation,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.9,
                          color: AppColors.primaryText,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Card 3 — الفوائد والعبر
                    if (hadith.keyLessons.isNotEmpty)
                      _buildSectionCard(
                        title: 'من فوائد الحديث 🌿',
                        iconAsset: 'assets/images/leaf_accent.svg',
                        fallbackIcon: Icons.spa,
                        backgroundColor: AppColors.secondaryCard,
                        content: Column(
                          children: hadith.keyLessons.map((lesson) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '• ',
                                    style: TextStyle(
                                      color: AppColors.primaryGreen,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      lesson,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        height: 1.7,
                                        color: AppColors.primaryText,
                                        fontFamily: 'Tajawal',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String iconAsset,
    required IconData fallbackIcon,
    required Widget content,
    Color backgroundColor = AppColors.card,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AssetHelper.assetOrFallback(
                assetPath: iconAsset,
                width: 22,
                height: 22,
                fallback: Icon(fallbackIcon, size: 18, color: AppColors.primaryGreen),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                  fontFamily: 'Tajawal',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          content,
        ],
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
