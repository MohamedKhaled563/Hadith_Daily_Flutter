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
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
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

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const SizedBox(height: 8),

              // Top Navigation Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Safe Back Button (never crashes)
                    _buildAnimatedCircleButton(
                      icon: Icons.chevron_right_rounded,
                      onTap: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
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

                    // Favorites Filter Button
                    _buildAnimatedCircleButton(
                      icon: _showOnlyFavorites ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      iconColor: _showOnlyFavorites ? const Color(0xFFC59B27) : const Color(0xFF26352C),
                      onTap: () {
                        setState(() => _showOnlyFavorites = !_showOnlyFavorites);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Title Header
              Text(
                _showOnlyFavorites ? 'الأحاديث المحفوظة 🌿' : 'جميع الأحاديث النبوية',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF26352C),
                  fontFamily: 'Tajawal',
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'استكشف الأحاديث الشريفة وشروحها وهداياتها',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF5A7061),
                  fontFamily: 'Tajawal',
                ),
              ),

              const SizedBox(height: 12),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF6EE),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0x60D1BE93),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, size: 20, color: Color(0xFF5A7061)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Color(0xFF26352C)),
                          decoration: const InputDecoration(
                            hintText: 'ابحث برقم الحديث أو موضوعه...',
                            hintStyle: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 13,
                              color: Color(0xFF9E9D97),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () => setState(() => _searchQuery = ''),
                          child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF5A7061)),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Hadith List
              Expanded(
                child: displayedHadiths.isEmpty
                    ? Center(
                        child: Text(
                          _showOnlyFavorites ? 'لا توجد أحاديث محفوظة في المفضلة' : 'لم يتم العثور على نتائج للبحث',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF5A7061),
                            fontFamily: 'Tajawal',
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        itemCount: displayedHadiths.length,
                        itemBuilder: (context, index) {
                          final hadith = displayedHadiths[index];
                          return _HadithCardItem(
                            hadith: hadith,
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
    Color iconColor = const Color(0xFF26352C),
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
  final VoidCallback onTap;

  const _HadithCardItem({
    required this.hadith,
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
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDFC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isHovered
                    ? const Color(0xFFD6BE88)
                    : const Color(0x59D1BE93),
                width: _isHovered ? 1.4 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isHovered
                      ? const Color(0x183B5644)
                      : const Color(0x0A000000),
                  blurRadius: _isHovered ? 14 : 8,
                  offset: Offset(0, _isHovered ? 4 : 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Number Ring Badge
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF6EE),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFD6BE88),
                        width: 1.4,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _toArabic(widget.hadith.number),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF385240),
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  // Title and snippet
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.hadith.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF26352C),
                            fontFamily: 'Tajawal',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.hadith.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.6,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF5A7061),
                            fontFamily: 'Tajawal',
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Left Chevron indicator
                  const Icon(
                    Icons.chevron_left_rounded,
                    color: Color(0xFF8E9990),
                    size: 22,
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
    this.iconColor = const Color(0xFF26352C),
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
              color: const Color(0xFFFAF6EE),
              border: Border.all(
                color: const Color(0x66D1BE93),
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
