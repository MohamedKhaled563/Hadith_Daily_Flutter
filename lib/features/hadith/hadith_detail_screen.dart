import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    return Scaffold(
      body: AppBackground(
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
                      onTap: () {
                        if (Navigator.canPop(context)) Navigator.pop(context);
                      },
                    ),

                    // Center Emblem + Divider
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AssetHelper.assetOrFallback(
                          assetPath: 'assets/images/heart_leaf_emblem.png',
                          width: 38,
                          height: 38,
                          fallback: const Icon(
                            Icons.favorite_rounded,
                            color: AppColors.primaryGreen,
                            size: 26,
                          ),
                        ),
                        AssetHelper.assetOrFallback(
                          assetPath: 'assets/images/golden_divider.png',
                          width: 60,
                          height: 10,
                          fallback: const SizedBox(height: 2),
                        ),
                      ],
                    ),

                    // Copy Button (نسخ)
                    _buildCircleButton(
                      icon: Icons.copy_rounded,
                      onTap: () => _copyHadith(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Title Area
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Text(
                      hadith.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF26352C),
                        fontFamily: 'Tajawal',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'الحديث رقم ${_toArabic(hadith.number)} من الأربعين النووية',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF5A7061),
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Content Cards inside a smooth, unconstrained SingleChildScrollView for long Hadiths
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    children: [
                      // Card 1 — نص الحديث الشريف
                      _buildSectionCard(
                        title: 'نص الحديث الشريف',
                        icon: Icons.format_quote_rounded,
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hadith.text,
                              style: const TextStyle(
                                fontSize: 16,
                                height: 2.1,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF26352C),
                                fontFamily: 'Tajawal',
                              ),
                            ),
                            const SizedBox(height: 14),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFAF6EE),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0x60D1BE93),
                                  ),
                                ),
                                child: Text(
                                  hadith.reference,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF385240),
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
                        _buildSectionCard(
                          title: 'شرح الحديث وبيانه',
                          icon: Icons.menu_book_rounded,
                          content: Text(
                            hadith.explanation,
                            style: const TextStyle(
                              fontSize: 14.5,
                              height: 2.0,
                              color: Color(0xFF26352C),
                              fontFamily: 'Tajawal',
                            ),
                          ),
                        ),

                      if (hadith.explanation.isNotEmpty) const SizedBox(height: 14),

                      // Card 3 — الفوائد والعبر
                      if (hadith.keyLessons.isNotEmpty)
                        _buildSectionCard(
                          title: 'من فوائد الحديث وهداياته 🌿',
                          icon: Icons.spa_rounded,
                          backgroundColor: const Color(0xFFFAF6EE),
                          content: Column(
                            children: hadith.keyLessons.map((lesson) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '• ',
                                      style: TextStyle(
                                        color: Color(0xFF385240),
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        lesson,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          height: 1.8,
                                          color: Color(0xFF26352C),
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

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget content,
    Color backgroundColor = const Color(0xFFFFFDFC),
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
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF385240)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF385240),
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

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFF26352C),
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFFAF6EE),
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
        child: Icon(icon, size: 22, color: iconColor),
      ),
    );
  }
}
