import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_state_controller.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/asset_helper.dart';
import '../../core/widgets/smooth_page_route.dart';
import '../../data/models/insight.dart';
import '../../data/repositories/hadith_repository.dart';
import '../hadith/hadith_detail_screen.dart';

class CommunityPostScreen extends StatefulWidget {
  final CommunityPost post;

  const CommunityPostScreen({
    super.key,
    required this.post,
  });

  @override
  State<CommunityPostScreen> createState() => _CommunityPostScreenState();
}

class _CommunityPostScreenState extends State<CommunityPostScreen> {
  final HadithRepository _repo = HadithRepository();
  final AppStateController _state = AppStateController();

  @override
  Widget build(BuildContext context) {
    final hadith = _repo.getByNumber(widget.post.hadithNumber);
    final isDark = _state.isDarkMode;
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
                    // Right Back Button
                    _buildCircleButton(
                      icon: Icons.chevron_right_rounded,
                      isDark: isDark,
                      onTap: () {
                        if (Navigator.canPop(context)) Navigator.pop(context);
                      },
                    ),

                    // Title
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'مشاركة مجتمعية',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                        const SizedBox(height: 2),
                        AssetHelper.assetOrFallback(
                          assetPath: 'assets/images/golden_divider.png',
                          width: 60,
                          height: 8,
                          fallback: Container(
                            width: 35,
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

              const SizedBox(height: 16),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Luxury Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: isDark ? const Color(0xFF1F3025) : const Color(0xFFFFFDFC),
                          border: Border.all(
                            color: const Color(0xFFD6BE88),
                            width: 1.3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark ? const Color(0x50000000) : const Color(0x14B9A06A),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Author Row
                            Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDark ? const Color(0xFF2A3F31) : const Color(0xFFFAF5EB),
                                    border: Border.all(color: const Color(0x60D1BE93)),
                                  ),
                                  child: Center(
                                    child: AssetHelper.assetOrFallback(
                                      assetPath: 'assets/images/leaf_accent.png',
                                      width: 24,
                                      height: 24,
                                      fallback: const Icon(
                                        Icons.person_outline_rounded,
                                        color: AppColors.primaryGreen,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.post.authorName,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                        fontFamily: 'Tajawal',
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'متأمل في الحديث ${widget.post.hadithNumber}',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppColors.gold : const Color(0xFF8C6B1B),
                                        fontFamily: 'Tajawal',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Golden Divider
                            Center(
                              child: AssetHelper.assetOrFallback(
                                assetPath: 'assets/images/golden_divider.png',
                                width: 120,
                                height: 12,
                                fallback: Container(
                                  width: 80,
                                  height: 1.5,
                                  color: const Color(0xFFD6BE88),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Message Body
                            Text(
                              '« ${widget.post.message} »',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18.5,
                                height: 1.8,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                                fontFamily: 'Tajawal',
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Related Hadith Link
                            if (hadith != null)
                              InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    SmoothPageRoute(
                                      child: HadithDetailScreen(hadith: hadith),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF17241C) : const Color(0xFFFAF6EE),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0x60D1BE93)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.menu_book_rounded,
                                        size: 18,
                                        color: Color(0xFFC59B27),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'الحديث ${hadith.number}: ${hadith.title}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? AppColors.gold : const Color(0xFF385240),
                                            fontFamily: 'Tajawal',
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_left_rounded,
                                        size: 18,
                                        color: Color(0xFFC59B27),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Like Button Action
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _repo.togglePostLike(widget.post.id);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E2D23) : const Color(0xFFFAF6EE),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: const Color(0x60D1BE93)),
                            boxShadow: const [
                              BoxShadow(color: Color(0x0C000000), blurRadius: 10, offset: Offset(0, 3)),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.post.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                size: 22,
                                color: widget.post.isLiked ? const Color(0xFFC73E3E) : const Color(0xFF385240),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${widget.post.likes} إعجاب',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                  fontFamily: 'Tajawal',
                                ),
                              ),
                            ],
                          ),
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
