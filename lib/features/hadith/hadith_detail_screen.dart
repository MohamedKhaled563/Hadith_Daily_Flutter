import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_state_controller.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/asset_helper.dart';
import '../../core/widgets/islamic_pattern_painter.dart';
import '../../data/models/hadith.dart';

class HadithDetailScreen extends StatelessWidget {
  final Hadith hadith;

  const HadithDetailScreen({
    super.key,
    required this.hadith,
  });

  String _toArabic(int num) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return num.toString().split('').map((d) => arabicDigits[int.parse(d)]).join('');
  }

  void _copyHadith(BuildContext context) {
    final buffer = StringBuffer();
    buffer.writeln('« ${hadith.title} »');
    buffer.writeln('الحديث رقم ${hadith.number} من الأربعين النووية\n');
    buffer.writeln('نص الحديث:');
    buffer.writeln(hadith.text);
    buffer.writeln('\nالمصدر: ${hadith.reference}');
    if (hadith.explanation.isNotEmpty) {
      buffer.writeln('\nالشرح:');
      buffer.writeln(hadith.explanation);
    }
    if (hadith.keyLessons.isNotEmpty) {
      buffer.writeln('\nمن فوائد الحديث:');
      for (final lesson in hadith.keyLessons) {
        buffer.writeln('• $lesson');
      }
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'تم نسخ نص الحديث وشرحه بالكامل 🌿',
          textDirection: TextDirection.rtl,
          style: TextStyle(fontFamily: 'Tajawal'),
        ),
        backgroundColor: AppColors.primaryGreen,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppStateController().isDarkMode;
    final textColor = isDark ? AppColors.primaryTextDark : const Color(0xFF26352C);
    final subTextColor = isDark ? AppColors.secondaryTextDark : const Color(0xFF5A7061);

    return Scaffold(
      body: AppBackground(
        showBottomLandscape: true,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const SizedBox(height: 8),

              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back Button
                    _buildCircleButton(
                      icon: Icons.chevron_right_rounded,
                      isDark: isDark,
                      onTap: () {
                        if (Navigator.canPop(context)) Navigator.pop(context);
                      },
                    ),

                    // Center Emblem with Ring
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? AppColors.softCreamDark : const Color(0xFFFAF6EE),
                        border: Border.all(
                          color: const Color(0xFFD6BE88),
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(color: Color(0x0E000000), blurRadius: 8, offset: Offset(0, 2)),
                        ],
                      ),
                      child: AssetHelper.assetOrFallback(
                        assetPath: 'assets/images/heart_leaf_emblem.png',
                        width: 36,
                        height: 36,
                        fallback: const Icon(
                          Icons.favorite_rounded,
                          color: AppColors.primaryGreen,
                          size: 24,
                        ),
                      ),
                    ),

                    // Copy Button (نسخ)
                    _buildCircleButton(
                      icon: Icons.copy_rounded,
                      isDark: isDark,
                      onTap: () => _copyHadith(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Title Area
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Text(
                      hadith.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'الحديث رقم ${_toArabic(hadith.number)} من الأربعين النووية',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.gold : const Color(0xFF5A7061),
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Content Cards inside a smooth SingleChildScrollView
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Column(
                    children: [
                      // Card 1 — نص الحديث الشريف (Islamic Parchment Card with Watermark)
                      _buildIslamicParchmentCard(
                        isDark: isDark,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.format_quote_rounded, size: 22, color: Color(0xFFC7A566)),
                                const SizedBox(width: 8),
                                Text(
                                  'نص الحديث الشريف',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.gold : const Color(0xFF385240),
                                    fontFamily: 'Tajawal',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              hadith.text,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 16,
                                height: 2.1,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                                fontFamily: 'Tajawal',
                              ),
                            ),
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E2D23) : const Color(0xFFFAF6EE),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0x60D1BE93),
                                  ),
                                ),
                                child: Text(
                                  hadith.reference,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.gold : const Color(0xFF385240),
                                    fontFamily: 'Tajawal',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Card 2 — شرح الحديث وبيانه
                      if (hadith.explanation.isNotEmpty)
                        _buildIslamicParchmentCard(
                          isDark: isDark,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.menu_book_rounded, size: 20, color: Color(0xFFC7A566)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'شرح الحديث وبيانه',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppColors.gold : const Color(0xFF385240),
                                      fontFamily: 'Tajawal',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                hadith.explanation,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  height: 2.0,
                                  color: textColor,
                                  fontFamily: 'Tajawal',
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (hadith.explanation.isNotEmpty) const SizedBox(height: 14),

                      // Card 3 — الفوائد والعبر
                      if (hadith.keyLessons.isNotEmpty)
                        _buildIslamicParchmentCard(
                          isDark: isDark,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.spa_rounded, size: 20, color: Color(0xFFC7A566)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'من فوائد الحديث وهداياته 🌿',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppColors.gold : const Color(0xFF385240),
                                      fontFamily: 'Tajawal',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Column(
                                children: hadith.keyLessons.map((lesson) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '• ',
                                          style: TextStyle(
                                            color: isDark ? AppColors.gold : const Color(0xFF385240),
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            lesson,
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              height: 1.8,
                                              color: textColor,
                                              fontFamily: 'Tajawal',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIslamicParchmentCard({
    required Widget child,
    required bool isDark,
  }) {
    final bgGradientColors = isDark
        ? [
            const Color(0xFF23342A),
            const Color(0xFF1B2A20),
          ]
        : [
            const Color(0xFFEFE8DC),
            const Color(0xFFECE4D7),
          ];

    final borderColor = isDark ? const Color(0x60D1BE93) : const Color(0x75D1BE93);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: bgGradientColors,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: borderColor,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x30000000) : const Color(0x10000000),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Islamic Watermark
            Positioned.fill(
              child: CustomPaint(
                painter: IslamicWatermarkPainter(
                  color: isDark ? const Color(0x18D1BE93) : const Color(0x28B89F70),
                  strokeWidth: 1.1,
                ),
              ),
            ),

            // Inner Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    Color? iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF23342A) : const Color(0xFFFAF6EE),
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0x66D1BE93),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 6,
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 22,
          color: iconColor ?? (isDark ? AppColors.primaryTextDark : const Color(0xFF26352C)),
        ),
      ),
    );
  }
}
