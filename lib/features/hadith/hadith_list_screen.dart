import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/asset_helper.dart';
import '../../core/widgets/smooth_page_route.dart';
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

  @override
  Widget build(BuildContext context) {
    final allHadiths = _repo.getAll();
    final displayedHadiths = _showOnlyFavorites
        ? allHadiths.where((h) => h.isFavorite).toList()
        : allHadiths;

    return Scaffold(
      body: AppBackground(
        child: Column(
          children: [
            const SizedBox(height: 12),

            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildAnimatedCircleButton(
                    icon: Icons.chevron_right,
                    onTap: () => Navigator.pop(context),
                  ),

                  // Center Emblem + Divider
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AssetHelper.assetOrFallback(
                        assetPath: 'assets/images/heart_leaf_emblem.png',
                        width: 44,
                        height: 44,
                        fallback: const Icon(
                          Icons.favorite_border,
                          color: AppColors.primaryGreen,
                          size: 28,
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

                  // Bookmark Filter button
                  _buildAnimatedCircleButton(
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

            // Hadith List
            Expanded(
              child: displayedHadiths.isEmpty
                  ? Center(
                      child: Text(
                        _showOnlyFavorites ? 'لا توجد أحاديث محفوظة' : 'لا توجد أحاديث',
                        style: const TextStyle(
                          fontSize: 16,
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

                        return _HadithCardItem(
                          hadith: hadith,
                          isEven: isEven,
                          index: index,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              SmoothPageRoute(
                                child: HadithDetailScreen(
                                  hadith: hadith,
                                ),
                              ),
                            );
                            setState(() {});
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = AppColors.primaryText,
  }) {
    return _AnimatedIconButton(
      icon: icon,
      iconColor: iconColor,
      onTap: onTap,
    );
  }
}

class _HadithCardItem extends StatefulWidget {
  final Hadith hadith;
  final bool isEven;
  final int index;
  final VoidCallback onTap;

  const _HadithCardItem({
    required this.hadith,
    required this.isEven,
    required this.index,
    required this.onTap,
  });

  @override
  State<_HadithCardItem> createState() => _HadithCardItemState();
}

class _HadithCardItemState extends State<_HadithCardItem> {
  bool _isHovered = false;
  bool _isPressed = false;

  String _toArabic(int number) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return number.toString().split('').map((d) => arabicDigits[int.parse(d)]).join();
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
        child: AnimatedScale(
          scale: _isPressed ? 0.97 : (_isHovered ? 1.015 : 1.0),
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _isHovered
                    ? AppColors.gold.withOpacity(0.7)
                    : AppColors.cardBorder.withOpacity(0.6),
                width: _isHovered ? 1.4 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isHovered
                      ? const Color(0x183B5644)
                      : const Color(0x0C000000),
                  blurRadius: _isHovered ? 16 : 8,
                  offset: Offset(0, _isHovered ? 4 : 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الحديث ${_toArabic(widget.hadith.number)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.gold,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.hadith.text,
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

                  // Badge
                  AssetHelper.assetOrFallback(
                    assetPath: widget.isEven
                        ? 'assets/images/flower_badge.png'
                        : 'assets/images/leaf_badge.png',
                    width: 38,
                    height: 38,
                    fallback: Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.softCream,
                      ),
                      child: const Icon(
                        Icons.eco_outlined,
                        size: 20,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  const Icon(
                    Icons.chevron_left,
                    color: AppColors.secondaryText,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;

  const _AnimatedIconButton({
    required this.icon,
    required this.onTap,
    this.iconColor = AppColors.primaryText,
  });

  @override
  State<_AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<_AnimatedIconButton> {
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
          scale: _isPressed ? 0.88 : 1.0,
          duration: const Duration(milliseconds: 140),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.85),
              border: Border.all(
                color: AppColors.cardBorder.withOpacity(0.5),
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              widget.icon,
              color: widget.iconColor,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
