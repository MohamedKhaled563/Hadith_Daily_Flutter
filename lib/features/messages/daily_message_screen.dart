import 'dart:math' as math;
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
import '../hadith/hadith_detail_screen.dart';

class DailyMessageScreen extends StatefulWidget {
  final Insight insight;
  final Hadith? hadith;
  final Function(int)? onTabSelected;

  const DailyMessageScreen({
    super.key,
    required this.insight,
    this.hadith,
    this.onTabSelected,
  });

  @override
  State<DailyMessageScreen> createState() => _DailyMessageScreenState();
}

class _DailyMessageScreenState extends State<DailyMessageScreen> {
  final AppStateController _state = AppStateController();
  bool _isLiked = false;
  int _likesCount = 48;
  bool _isBookmarked = false;

  String _toArabicDigits(int number) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return number.toString().split('').map((d) => arabicDigits[int.parse(d)]).join();
  }

  void _copyMessageText() {
    final textToCopy = '« ${widget.insight.message} »\n\n'
        '📌 المرتبط بـ: ${widget.hadith?.title ?? 'حديث نبوي شريف'}\n'
        '🌿 من تطبيق: طيّب قلبك - هدي النبوة';
    Clipboard.setData(ClipboardData(text: textToCopy));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'تم نسخ نص الرسالة بنجاح 🌿',
          textDirection: TextDirection.rtl,
          style: TextStyle(fontFamily: 'Tajawal'),
        ),
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  void _showSharePreviewDialog(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : const Color(0xFFFFFDFC),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: const Color(0x60D1BE93)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD6BE88),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'مشاركة بطاقة اليوم 🌿',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.primaryTextDark : const Color(0xFF26352C),
                  fontFamily: 'Tajawal',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'تم تجهيز الرسالة بصياغة أنيقة مع هوية تطبيق "طيّب قلبك"',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.secondaryTextDark : const Color(0xFF5A7061),
                  fontFamily: 'Tajawal',
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1B2B20) : const Color(0xFFFAF5EB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x40D1BE93)),
                ),
                child: Text(
                  '« ${widget.insight.message} »\n\n— طيّب قلبك 🌿',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: isDark ? AppColors.primaryTextDark : const Color(0xFF26352C),
                    fontFamily: 'Tajawal',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _copyMessageText();
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text(
                    'نسخ النص ومشاركته الآن',
                    style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF385240),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _state.isDarkMode;
    final titleColor = isDark ? AppColors.primaryTextDark : const Color(0xFF26352C);

    return Scaffold(
      body: AppBackground(
        showBottomLandscape: true,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const SizedBox(height: 6),

              // Top Bar with Back & Bookmark Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Right Back Button
                    _buildAnimatedCircleButton(
                      icon: Icons.chevron_right_rounded,
                      isDark: isDark,
                      onTap: () {
                        if (Navigator.canPop(context)) Navigator.pop(context);
                      },
                    ),

                    // Center Brand Heading
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'رسالة اليوم',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: titleColor,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                        const SizedBox(height: 2),
                        AssetHelper.assetOrFallback(
                          assetPath: 'assets/images/golden_divider.png',
                          width: 70,
                          height: 10,
                          fallback: Container(
                            width: 40,
                            height: 1.5,
                            color: const Color(0xFFD6BE88),
                          ),
                        ),
                      ],
                    ),

                    // Left Bookmark Button
                    _buildAnimatedCircleButton(
                      icon: _isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      iconColor: _isBookmarked ? const Color(0xFFC59B27) : (isDark ? AppColors.primaryTextDark : const Color(0xFF26352C)),
                      isDark: isDark,
                      onTap: () {
                        setState(() => _isBookmarked = !_isBookmarked);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _isBookmarked ? 'تم حفظ الرسالة في المفضلة 🌿' : 'تمت الإزالة من المفضلة',
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
              ),

              const SizedBox(height: 10),

              // Main Quote Card in Single View
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Column(
                    children: [
                      // The Luxury Parchment Card with Watermark, Botanicals & Like Counter
                      _buildParchmentMessageCard(isDark),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // Unified 3-Item Luxury Bottom Bar (الرئيسية • مشاركة • نسخ الرسالة)
      bottomNavigationBar: _buildMessageBottomBar(isDark),
    );
  }

  /// The Luxury Parchment Card modeled after community cards
  Widget _buildParchmentMessageCard(bool isDark) {
    // Exact warm parchment tones from reference screenshot & community cards
    final bgGradientColors = isDark
        ? [
            const Color(0xFF23342A),
            const Color(0xFF1B2A20),
          ]
        : [
            const Color(0xFFEFE8DC),
            const Color(0xFFECE4D7),
          ];

    final textColor = isDark ? const Color(0xFFF7F5EE) : const Color(0xFF26352C);
    final borderColor = isDark ? const Color(0x60D1BE93) : const Color(0x80D1BE93);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: bgGradientColors,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: borderColor,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x50000000) : const Color(0x153B5644),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
          BoxShadow(
            color: const Color(0xFFD6BE88).withOpacity(isDark ? 0.08 : 0.2),
            blurRadius: 8,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // 1. Subtle & Authentic Islamic geometric watermark in center (Matches screenshot aesthetic!)
            Positioned.fill(
              child: CustomPaint(
                painter: IslamicWatermarkPainter(
                  color: isDark
                      ? const Color(0x1CD1BE93)
                      : const Color(0x2BB89F70),
                  strokeWidth: 1.15,
                ),
              ),
            ),

            // 2. Botanical Top-Right Watercolor Branch Asset
            Positioned(
              top: -6,
              right: -6,
              child: IgnorePointer(
                child: Opacity(
                  opacity: isDark ? 0.35 : 0.55,
                  child: AssetHelper.assetOrFallback(
                    assetPath: 'assets/images/botanical_top_right.png',
                    width: 100,
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

            // 3. Botanical Bottom-Left Watercolor Branch Asset
            Positioned(
              bottom: -6,
              left: -6,
              child: IgnorePointer(
                child: Opacity(
                  opacity: isDark ? 0.35 : 0.55,
                  child: AssetHelper.assetOrFallback(
                    assetPath: 'assets/images/botanical_bottom_left.png',
                    width: 100,
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

            // 4. Card Inner Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Header Row with Like Counter on the Left (in RTL layout)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Left: Interactive Like Heart Counter (Exact matching community card style)
                      _buildHeartLikeCounter(isDark),

                      // Center: Heart-Leaf Emblem Circular Avatar
                      Hero(
                        tag: 'heart_leaf_emblem_hero',
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? const Color(0xFF1B2B20) : const Color(0xFFFAF5EB),
                            border: Border.all(
                              color: const Color(0xFFD6BE88),
                              width: 1.2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x10B9A06A),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: AssetHelper.assetOrFallback(
                              assetPath: 'assets/images/heart_leaf_emblem.png',
                              width: 30,
                              height: 30,
                              fallback: const Icon(
                                Icons.favorite_rounded,
                                color: AppColors.primaryGreen,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Right Placeholder to balance center alignment (width equals like button)
                      const SizedBox(width: 48),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Category Tag Pill ("رسالة اليوم 🌿" or Category)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2B3F32) : const Color(0xFFFAF6EE),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0x60D1BE93),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AssetHelper.assetOrFallback(
                          assetPath: 'assets/images/leaf_accent.png',
                          width: 13,
                          height: 13,
                          fallback: const Icon(
                            Icons.eco_rounded,
                            size: 13,
                            color: Color(0xFF385240),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          widget.insight.category,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.gold : const Color(0xFF385240),
                            fontFamily: 'Tajawal',
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Top Golden Divider
                  AssetHelper.assetOrFallback(
                    assetPath: 'assets/images/golden_divider.png',
                    width: 110,
                    height: 14,
                    fallback: Container(
                      width: 70,
                      height: 1.5,
                      color: const Color(0xFFD6BE88),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // The Central Message / Quote with Refined Typography
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '« ${widget.insight.message} »',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        height: 1.8,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        fontFamily: 'Tajawal',
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Bottom Golden Divider
                  AssetHelper.assetOrFallback(
                    assetPath: 'assets/images/golden_divider.png',
                    width: 110,
                    height: 14,
                    fallback: Container(
                      width: 70,
                      height: 1.5,
                      color: const Color(0xFFD6BE88),
                    ),
                  ),

                  // Associated Hadith Link Button (if available)
                  if (widget.hadith != null) ...[
                    const SizedBox(height: 16),
                    _HadithDetailPillButton(
                      hadithNumber: widget.hadith!.number,
                      title: widget.hadith!.title,
                      isDark: isDark,
                      onTap: () {
                        Navigator.push(
                          context,
                          SmoothPageRoute(
                            child: HadithDetailScreen(
                              hadith: widget.hadith!,
                            ),
                          ),
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 18),

                  // Authentic App Brand Watermark Signature
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 16,
                        height: 1,
                        color: const Color(0x60D1BE93),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '🌿 طيّب قلبك • هدي النبوة',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.gold : const Color(0xFF6E8675),
                          fontFamily: 'Tajawal',
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 16,
                        height: 1,
                        color: const Color(0x60D1BE93),
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
  }

  /// Interactive Heart Like Counter inside the Card
  Widget _buildHeartLikeCounter(bool isDark) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isLiked = !_isLiked;
            _likesCount += _isLiked ? 1 : -1;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isDark
                ? (_isLiked ? const Color(0xFF382323) : const Color(0xFF1B2B20))
                : (_isLiked ? const Color(0xFFFDE8E8) : const Color(0xFFFAF6EE)),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _isLiked ? const Color(0xFFC73E3E).withOpacity(0.5) : const Color(0x60D1BE93),
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: _isLiked ? 1.18 : 1.0,
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutBack,
                child: Icon(
                  _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  size: 19,
                  color: _isLiked ? const Color(0xFFC73E3E) : const Color(0xFF6B726C),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                _toArabicDigits(_likesCount),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _isLiked ? const Color(0xFFC73E3E) : (isDark ? AppColors.primaryTextDark : const Color(0xFF385240)),
                  fontFamily: 'Tajawal',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Unified 3-Item Luxury Bottom Navigation Bar: الرئيسية • مشاركة • نسخ الرسالة
  Widget _buildMessageBottomBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      height: 74,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF1B2B20), const Color(0xFF121D16)]
              : [const Color(0xFF2C4334), const Color(0xFF1E3024)],
        ),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(
          color: const Color(0xFFD6BE88).withOpacity(isDark ? 0.45 : 0.65),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: const Color(0xFFD6BE88).withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            children: [
              // 1. الرئيسية (Home)
              Expanded(
                child: _buildBottomBarItem(
                  icon: Icons.home_outlined,
                  label: 'الرئيسية',
                  onTap: () {
                    if (widget.onTabSelected != null) {
                      widget.onTabSelected!(0);
                    } else if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),

              // 2. مشاركة (Share)
              Expanded(
                child: _buildBottomBarItem(
                  icon: Icons.share_rounded,
                  label: 'مشاركة',
                  onTap: () => _showSharePreviewDialog(isDark),
                ),
              ),

              // 3. نسخ الرسالة (Copy Text)
              Expanded(
                child: _buildBottomBarItem(
                  icon: Icons.copy_rounded,
                  label: 'نسخ الرسالة',
                  onTap: _copyMessageText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBarItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return _MessageBottomBarItem(
      icon: icon,
      label: label,
      onTap: onTap,
    );
  }

  Widget _buildAnimatedCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    Color? iconColor,
  }) {
    return _AnimatedMessageTopButton(
      icon: icon,
      iconColor: iconColor ?? (isDark ? AppColors.primaryTextDark : const Color(0xFF26352C)),
      isDark: isDark,
      onTap: onTap,
    );
  }
}

class _MessageBottomBarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MessageBottomBarItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_MessageBottomBarItem> createState() => _MessageBottomBarItemState();
}

class _MessageBottomBarItemState extends State<_MessageBottomBarItem> {
  bool _isPressed = false;
  bool _isHovered = false;

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
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _isPressed ? 0.92 : (_isHovered ? 1.05 : 1.0),
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                color: _isHovered ? const Color(0xFFE8D49E) : const Color(0xFFF0E6D2),
                size: 23,
              ),
              const SizedBox(height: 3),
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _isHovered ? const Color(0xFFE8D49E) : const Color(0xFFF0E6D2),
                  fontFamily: 'Tajawal',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HadithDetailPillButton extends StatefulWidget {
  final int hadithNumber;
  final String title;
  final bool isDark;
  final VoidCallback onTap;

  const _HadithDetailPillButton({
    required this.hadithNumber,
    required this.title,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_HadithDetailPillButton> createState() => _HadithDetailPillButtonState();
}

class _HadithDetailPillButtonState extends State<_HadithDetailPillButton> {
  bool _isHovered = false;
  bool _isPressed = false;

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
          scale: _isPressed ? 0.95 : (_isHovered ? 1.025 : 1.0),
          duration: const Duration(milliseconds: 140),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _isHovered
                  ? (widget.isDark ? const Color(0xFF334B3B) : const Color(0xFFEBE2D0))
                  : (widget.isDark ? const Color(0xFF283B2E) : const Color(0xFFFAF5EB)),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isHovered ? const Color(0xFFD6BE88) : const Color(0x70D1BE93),
                width: _isHovered ? 1.4 : 1.1,
              ),
              boxShadow: [
                if (_isHovered)
                  const BoxShadow(
                    color: Color(0x153B5644),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_stories_rounded,
                  size: 15,
                  color: widget.isDark ? AppColors.gold : const Color(0xFF385240),
                ),
                const SizedBox(width: 7),
                Text(
                  'الحديث ${widget.hadithNumber}: ${widget.title}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: widget.isDark ? AppColors.primaryTextDark : const Color(0xFF385240),
                    fontFamily: 'Tajawal',
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.arrow_back_rounded,
                  size: 14,
                  color: widget.isDark ? AppColors.gold : const Color(0xFF385240),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedMessageTopButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;
  final bool isDark;

  const _AnimatedMessageTopButton({
    required this.icon,
    required this.onTap,
    required this.iconColor,
    required this.isDark,
  });

  @override
  State<_AnimatedMessageTopButton> createState() => _AnimatedMessageTopButtonState();
}

class _AnimatedMessageTopButtonState extends State<_AnimatedMessageTopButton> {
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
          scale: _isPressed ? 0.90 : 1.0,
          duration: const Duration(milliseconds: 140),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.isDark ? AppColors.cardDark : const Color(0xFFFAF6EE),
              border: Border.all(
                color: const Color(0x66D1BE93),
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
