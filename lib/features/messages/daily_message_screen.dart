import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_state_controller.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/asset_helper.dart';
import '../../core/widgets/bottom_navigation.dart';
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
  bool _reminderSet = false;

  void _handleTabClick(int index) {
    if (widget.onTabSelected != null) {
      widget.onTabSelected!(index);
    } else {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
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

              // Main Masterpiece Quote Card & Attached Actions
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Column(
                    children: [
                      // The Luxury Islamic Identity Card
                      _buildLuxuryMessageCard(isDark),

                      const SizedBox(height: 16),

                      // Card Actions Toolbar (Like, Share, Copy, Reminder)
                      _buildCardActionsBar(isDark),

                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // Unified Global Bottom Navigation Bar (Same as HomeScreen)
      bottomNavigationBar: BottomNavigation(
        currentIndex: 0,
        onTap: _handleTabClick,
      ),
    );
  }

  /// Luxury Shareable Spiritual Message Card with Islamic Framing & Brand Identity
  Widget _buildLuxuryMessageCard(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  const Color(0xFF23352A),
                  const Color(0xFF1B2920),
                  const Color(0xFF152219),
                ]
              : [
                  const Color(0xFFFFFDFC),
                  const Color(0xFFFCF8F0),
                  const Color(0xFFF7EFE1),
                ],
        ),
        border: Border.all(
          color: const Color(0xFFD6BE88),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x50000000) : const Color(0x18B9A06A),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFFD6BE88).withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 4-Corner Islamic Decorative Geometric Ornaments
          Positioned(
            top: 6,
            right: 6,
            child: _IslamicCornerOrnament(color: const Color(0xFFD6BE88), rotation: 0),
          ),
          Positioned(
            top: 6,
            left: 6,
            child: _IslamicCornerOrnament(color: const Color(0xFFD6BE88), rotation: math.pi / 2),
          ),
          Positioned(
            bottom: 6,
            left: 6,
            child: _IslamicCornerOrnament(color: const Color(0xFFD6BE88), rotation: math.pi),
          ),
          Positioned(
            bottom: 6,
            right: 6,
            child: _IslamicCornerOrnament(color: const Color(0xFFD6BE88), rotation: 3 * math.pi / 2),
          ),

          // Inner Content
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Badge: Heart Leaf Emblem with Glow
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? const Color(0xFF1B2B20) : const Color(0xFFFAF5EB),
                    border: Border.all(
                      color: const Color(0xFFD6BE88),
                      width: 1.3,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x10B9A06A),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Hero(
                      tag: 'heart_leaf_emblem_hero',
                      child: AssetHelper.assetOrFallback(
                        assetPath: 'assets/images/heart_leaf_emblem.png',
                        width: 34,
                        height: 34,
                        fallback: const Icon(
                          Icons.favorite_rounded,
                          color: AppColors.primaryGreen,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Category Tag Pill
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
                        width: 14,
                        height: 14,
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

                // Top Golden Flourish
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

                // The Central Message / Quote with Elegant Arabic Typography
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      '« ${widget.insight.message} »',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19.5,
                        height: 1.8,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFF7F5EE) : const Color(0xFF1E2E24),
                        fontFamily: 'Tajawal',
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Bottom Golden Flourish
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

                // Authentic App Brand Watermark (Makes the card stunning when screenshotted/shared)
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
    );
  }

  /// Interactive Actions Toolbar attached right under the card
  Widget _buildCardActionsBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2D23) : const Color(0xFFFAF6EE),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0x66D1BE93),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 1. Like with Animated Count
          _buildActionItem(
            icon: _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            label: '$_likesCount',
            isSelected: _isLiked,
            selectedColor: const Color(0xFFC73E3E),
            isDark: isDark,
            onTap: () {
              setState(() {
                _isLiked = !_isLiked;
                _likesCount += _isLiked ? 1 : -1;
              });
            },
          ),
          _buildActionDivider(),

          // 2. Share Card
          _buildActionItem(
            icon: Icons.share_rounded,
            label: 'مشاركة',
            isDark: isDark,
            onTap: () => _showSharePreviewDialog(isDark),
          ),
          _buildActionDivider(),

          // 3. Copy Text
          _buildActionItem(
            icon: Icons.copy_rounded,
            label: 'نسخ النص',
            isDark: isDark,
            onTap: _copyMessageText,
          ),
          _buildActionDivider(),

          // 4. Reminder
          _buildActionItem(
            icon: _reminderSet ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
            label: 'تذكير',
            isSelected: _reminderSet,
            selectedColor: const Color(0xFFC59B27),
            isDark: isDark,
            onTap: () {
              setState(() => _reminderSet = !_reminderSet);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _reminderSet ? 'تم تفعيل التذكير اليومي بهذه الرسالة ✨' : 'تم إلغاء التذكير',
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
    );
  }

  Widget _buildActionDivider() {
    return Container(
      width: 1,
      height: 24,
      color: const Color(0x33D1BE93),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    bool isSelected = false,
    Color selectedColor = const Color(0xFFC59B27),
  }) {
    return _AnimatedActionItem(
      icon: icon,
      label: label,
      isSelected: isSelected,
      selectedColor: selectedColor,
      isDark: isDark,
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

/// Custom 4-Corner Islamic Corner Ornament Painter
class _IslamicCornerOrnament extends StatelessWidget {
  final Color color;
  final double rotation;

  const _IslamicCornerOrnament({required this.color, required this.rotation});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotation,
      child: SizedBox(
        width: 24,
        height: 24,
        child: CustomPaint(
          painter: _CornerPainter(color: color),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;

  _CornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    final path = Path();
    // Top-Right flourish path
    path.moveTo(0, 2);
    path.lineTo(size.width - 6, 2);
    path.quadraticBezierTo(size.width - 2, 2, size.width - 2, 6);
    path.lineTo(size.width - 2, size.height);

    canvas.drawPath(path, paint);

    // Inner miniature flourish dot
    final dotPaint = Paint()
      ..color = color.withOpacity(0.9)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width - 7, 7), 1.8, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter oldDelegate) => oldDelegate.color != color;
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

class _AnimatedActionItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color selectedColor;
  final bool isDark;
  final VoidCallback onTap;

  const _AnimatedActionItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.selectedColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_AnimatedActionItem> createState() => _AnimatedActionItemState();
}

class _AnimatedActionItemState extends State<_AnimatedActionItem> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final defaultColor = widget.isDark ? AppColors.primaryTextDark : const Color(0xFF385240);
    final activeColor = widget.isSelected ? widget.selectedColor : (_isHovered ? AppColors.gold : defaultColor);

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
          scale: _isPressed ? 0.88 : (_isHovered ? 1.06 : 1.0),
          duration: const Duration(milliseconds: 140),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                color: activeColor,
                size: 21,
              ),
              const SizedBox(height: 3),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.w600,
                  color: activeColor,
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
