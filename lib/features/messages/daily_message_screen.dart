import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/asset_helper.dart';
import '../../data/models/hadith.dart';
import '../../data/models/insight.dart';
import '../hadith/hadith_detail_screen.dart';

class DailyMessageScreen extends StatefulWidget {
  final Insight insight;
  final Hadith? hadith;

  const DailyMessageScreen({
    super.key,
    required this.insight,
    this.hadith,
  });

  @override
  State<DailyMessageScreen> createState() => _DailyMessageScreenState();
}

class _DailyMessageScreenState extends State<DailyMessageScreen> {
  bool _isBookmarked = false;
  bool _reminderSet = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        showBottomLandscape: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            children: [
              // Top Bar matching الرسالة.png
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button
                  _buildCircleButton(
                    icon: Icons.chevron_right,
                    onTap: () => Navigator.pop(context),
                  ),

                  // Center Emblem
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

                  // Bookmark Button
                  _buildCircleButton(
                    icon: _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    iconColor: _isBookmarked ? AppColors.gold : AppColors.primaryText,
                    onTap: () {
                      setState(() => _isBookmarked = !_isBookmarked);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _isBookmarked ? 'تم حفظ الرسالة' : 'تمت الإزالة من المحفوظات',
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(fontFamily: 'Tajawal'),
                          ),
                          duration: const Duration(seconds: 2),
                          backgroundColor: AppColors.primaryGreen,
                        ),
                      );
                    },
                  ),
                ],
              ),

              const Spacer(),

              // The Main Quote Card matching الرسالة.png
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 34),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: const Color(0x66D1BE93),
                        width: 1.2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Quotation Mark
                        const Text(
                          '”',
                          style: TextStyle(
                            fontSize: 44,
                            height: 0.8,
                            color: AppColors.gold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Arabic Message
                        Text(
                          widget.insight.arabic,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            height: 2.0,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryText,
                            fontFamily: 'Tajawal',
                          ),
                        ),

                        if (widget.insight.english.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          Container(
                            width: 36,
                            height: 1.2,
                            color: const Color(0x66D1BE93),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            widget.insight.english,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.6,
                              color: AppColors.secondaryText,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],

                        if (widget.hadith != null) ...[
                          const SizedBox(height: 24),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => HadithDetailScreen(
                                    hadith: widget.hadith!,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.secondaryCard,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0x59D1BE93),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'شرح الحديث (${widget.hadith!.title})',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryGreen,
                                      fontFamily: 'Tajawal',
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.arrow_back,
                                    size: 13,
                                    color: AppColors.primaryGreen,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Top-Right & Bottom-Left Botanical Decorative Badges
                  Positioned(
                    top: 8,
                    right: 8,
                    width: 60,
                    height: 60,
                    child: IgnorePointer(
                      child: AssetHelper.assetOrFallback(
                        assetPath: 'assets/images/botanical_top_right.svg',
                        width: 60,
                        height: 60,
                        fallback: const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    width: 60,
                    height: 60,
                    child: IgnorePointer(
                      child: AssetHelper.assetOrFallback(
                        assetPath: 'assets/images/botanical_bottom_left.svg',
                        width: 60,
                        height: 60,
                        fallback: const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Floating 4-Action Bar matching الرسالة.png (مشاركة - حفظ - نسخ - تذكير)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.secondaryCard,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0x66D1BE93),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0F000000),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildBottomAction(
                      icon: Icons.share_outlined,
                      label: 'مشاركة',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'تم تجهيز الرسالة للمشاركة',
                              textDirection: TextDirection.rtl,
                              style: TextStyle(fontFamily: 'Tajawal'),
                            ),
                            backgroundColor: AppColors.primaryGreen,
                          ),
                        );
                      },
                    ),
                    _buildDivider(),
                    _buildBottomAction(
                      icon: _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      label: 'حفظ',
                      color: _isBookmarked ? AppColors.gold : AppColors.primaryText,
                      onTap: () {
                        setState(() => _isBookmarked = !_isBookmarked);
                      },
                    ),
                    _buildDivider(),
                    _buildBottomAction(
                      icon: Icons.copy,
                      label: 'نسخ',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'تم نسخ نص الرسالة إلى الحافظة',
                              textDirection: TextDirection.rtl,
                              style: TextStyle(fontFamily: 'Tajawal'),
                            ),
                            backgroundColor: AppColors.primaryGreen,
                          ),
                        );
                      },
                    ),
                    _buildDivider(),
                    _buildBottomAction(
                      icon: _reminderSet ? Icons.notifications_active : Icons.notifications_none,
                      label: _reminderSet ? 'مفعل' : 'تذكير',
                      color: _reminderSet ? AppColors.primaryGreen : AppColors.primaryText,
                      onTap: () {
                        setState(() => _reminderSet = !_reminderSet);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _reminderSet ? 'تم تفعيل التذكير اليومي' : 'تم إلغاء التذكير',
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(fontFamily: 'Tajawal'),
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
            ],
          ),
        ),
      ),
    );
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

  Widget _buildBottomAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = AppColors.primaryText,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
              fontFamily: 'Tajawal',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 24,
      color: const Color(0x4DD1BE93),
    );
  }
}
