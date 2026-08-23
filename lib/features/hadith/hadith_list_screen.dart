import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_state_controller.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/asset_helper.dart';
import '../../core/widgets/islamic_pattern_painter.dart';
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
  final AppStateController _state = AppStateController();
  bool _showOnlyFavorites = false;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final isDark = _state.isDarkMode;
    final allHadiths = _repo.getAll();
    final displayedHadiths = allHadiths.where((h) {
      if (_showOnlyFavorites && !h.isFavorite) return false;
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return h.title.toLowerCase().contains(query) ||
            h.text.toLowerCase().contains(query) ||
            h.number.toString().contains(query);
      }
      return true;
    }).toList();

    final titleColor = isDark ? AppColors.primaryTextDark : const Color(0xFF26352C);
    final subTextColor = isDark ? AppColors.secondaryTextDark : const Color(0xFF5A7061);

    return Scaffold(
      body: AppBackground(
        showBottomLandscape: true,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const SizedBox(height: 8),

              // Top Bar (Left Back Button, Center Emblem, Right Bookmark Filter)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Right Back Button (Matches design language)
                    _buildAnimatedCircleButton(
                      icon: Icons.chevron_right_rounded,
                      isDark: isDark,
                      onTap: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      },
                    ),

                    // Center Emblem with circular copper/gold ring
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

                    // Favorites Filter Button
                    _buildAnimatedCircleButton(
                      icon: _showOnlyFavorites ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      iconColor: _showOnlyFavorites
                          ? const Color(0xFFC59B27)
                          : (isDark ? AppColors.primaryTextDark : const Color(0xFF26352C)),
                      isDark: isDark,
                      onTap: () {
                        setState(() => _showOnlyFavorites = !_showOnlyFavorites);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Titles
              Text(
                _showOnlyFavorites ? 'الأحاديث المحفوظة 🌿' : 'الأربعين النووية',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                  fontFamily: 'Tajawal',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _showOnlyFavorites
                    ? 'الأحاديث التي قمت بحفظها للمراجعة والتأمل'
                    : 'جامع جوامع الكلم وهدايات النبوة الشريفة',
                style: TextStyle(
                  fontSize: 13,
                  color: subTextColor,
                  fontFamily: 'Tajawal',
                ),
              ),

              const SizedBox(height: 12),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2D23) : const Color(0xFFEFE8DC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? const Color(0x50D1BE93) : const Color(0x75D1BE93),
                      width: 1.2,
                    ),
                    boxShadow: const [
                      BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: isDark ? AppColors.gold : const Color(0xFF5A7061),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 13.5,
                            color: titleColor,
                          ),
                          decoration: InputDecoration(
                            hintText: 'ابحث برقم الحديث أو عنوانه أو كلماته...',
                            hintStyle: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 13,
                              color: isDark ? Colors.white38 : const Color(0xFF8C8A84),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () => setState(() => _searchQuery = ''),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: subTextColor,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Hadith List with Islamic Parchment Cards
              Expanded(
                child: displayedHadiths.isEmpty
                    ? Center(
                        child: Text(
                          _showOnlyFavorites
                              ? 'لا توجد أحاديث محفوظة في المفضلة بعد 🌿'
                              : 'لم يتم العثور على نتائج مطابقة للبحث',
                          style: TextStyle(
                            fontSize: 14,
                            color: subTextColor,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                        itemCount: displayedHadiths.length,
                        itemBuilder: (context, index) {
                          final hadith = displayedHadiths[index];
                          return _HadithParchmentCardItem(
                            hadith: hadith,
                            isDark: isDark,
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
      ),
    );
  }

  Widget _buildAnimatedCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    Color? iconColor,
  }) {
    return _AnimatedHadithIconButton(
      icon: icon,
      iconColor: iconColor ?? (isDark ? AppColors.primaryTextDark : const Color(0xFF26352C)),
      isDark: isDark,
      onTap: onTap,
    );
  }
}

/// Authentic Islamic Parchment Card with Watermark & Rich Typography
class _HadithParchmentCardItem extends StatefulWidget {
  final Hadith hadith;
  final bool isDark;
  final VoidCallback onTap;

  const _HadithParchmentCardItem({
    required this.hadith,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_HadithParchmentCardItem> createState() => _HadithParchmentCardItemState();
}

class _HadithParchmentCardItemState extends State<_HadithParchmentCardItem> {
  bool _isHovered = false;
  bool _isPressed = false;

  String _toArabic(int number) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return number.toString().split('').map((d) => arabicDigits[int.parse(d)]).join();
  }

  @override
  Widget build(BuildContext context) {
    // Exact warm parchment tones from reference design
    final bgGradientColors = widget.isDark
        ? [
            const Color(0xFF23342A),
            const Color(0xFF1B2A20),
          ]
        : [
            const Color(0xFFEFE8DC),
            const Color(0xFFECE4D7),
          ];

    final textColor = widget.isDark ? AppColors.primaryTextDark : const Color(0xFF26352C);
    final snippetColor = widget.isDark ? const Color(0xFFC2D4C6) : const Color(0xFF4A5F52);
    final borderColor = widget.isDark ? const Color(0x60D1BE93) : const Color(0x75D1BE93);

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
          scale: _isPressed ? 0.975 : (_isHovered ? 1.012 : 1.0),
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: bgGradientColors,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _isHovered ? const Color(0xFFD6BE88) : borderColor,
                width: _isHovered ? 1.5 : 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isHovered
                      ? (widget.isDark ? const Color(0x50000000) : const Color(0x203B5644))
                      : (widget.isDark ? const Color(0x28000000) : const Color(0x0E000000)),
                  blurRadius: _isHovered ? 16 : 8,
                  offset: Offset(0, _isHovered ? 5 : 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  // Embossed Islamic Geometric Arabesque Watermark in the background
                  Positioned.fill(
                    child: CustomPaint(
                      painter: IslamicWatermarkPainter(
                        color: widget.isDark
                            ? const Color(0x1AD1BE93)
                            : const Color(0x28B89F70),
                        strokeWidth: 1.1,
                      ),
                    ),
                  ),

                  // Card Content
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Row: Number Tag on Right, Favorite Heart on Left (RTL Layout)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Left: Chevron Indicator
                            Icon(
                              Icons.chevron_left_rounded,
                              size: 22,
                              color: _isHovered
                                  ? (widget.isDark ? AppColors.gold : const Color(0xFF385240))
                                  : (widget.isDark ? const Color(0xFF8E9990) : const Color(0xFF857E70)),
                            ),

                            // Right: Hadith Title + Number Badge
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.hadith.title,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                    fontFamily: 'Tajawal',
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Number Badge Ring
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFEADBBE),
                                        Color(0xFFC7A566),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.8),
                                      width: 1.0,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x18000000),
                                        blurRadius: 4,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    _toArabic(widget.hadith.number),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF26352C),
                                      fontFamily: 'Tajawal',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Body Text snippet with authentic phrasing
                        Text(
                          widget.hadith.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.7,
                            fontWeight: FontWeight.w500,
                            color: snippetColor,
                            fontFamily: 'Tajawal',
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Bottom Row: "مرتبط بالحديث رقم X" & Bookmark
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (widget.hadith.isFavorite)
                              const Icon(
                                Icons.bookmark_rounded,
                                size: 16,
                                color: Color(0xFFC59B27),
                              )
                            else
                              const SizedBox(width: 16),

                            Text(
                              'الحديث رقم ${_toArabic(widget.hadith.number)} من الأربعين النووية',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: widget.isDark ? AppColors.gold : const Color(0xFF7A8D80),
                                fontFamily: 'Tajawal',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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

class _AnimatedHadithIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;
  final bool isDark;

  const _AnimatedHadithIconButton({
    required this.icon,
    required this.onTap,
    required this.iconColor,
    required this.isDark,
  });

  @override
  State<_AnimatedHadithIconButton> createState() => _AnimatedHadithIconButtonState();
}

class _AnimatedHadithIconButtonState extends State<_AnimatedHadithIconButton> {
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
              color: widget.isDark ? AppColors.cardDark : const Color(0xFFFAF6EE),
              border: Border.all(
                color: const Color(0x66D1BE93),
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2)),
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
