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
import '../../data/repositories/hadith_repository.dart';
import '../favorites/favorites_screen.dart';
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

class _DailyMessageScreenState extends State<DailyMessageScreen>
    with SingleTickerProviderStateMixin {
  final AppStateController _state = AppStateController();
  final HadithRepository _repo = HadithRepository();
  bool _isLiked = false;
  int _likesCount = 48;
  late bool _isBookmarked;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _isBookmarked = _repo.isInsightFavorite(widget.insight.message);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

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

  void _toggleBookmark() {
    setState(() {
      _isBookmarked = !_isBookmarked;
      _repo.toggleFavoriteInsight(widget.insight.message);
    });
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
  }

  void _openFavorites() {
    if (widget.onTabSelected != null) {
      widget.onTabSelected!(1);
    } else {
      Navigator.push(
        context,
        SmoothPageRoute(
          child: const FavoritesScreen(),
        ),
      );
    }
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
                    // Right Back Button (in RTL)
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

                    // Left Bookmark Button (in RTL)
                    _buildAnimatedCircleButton(
                      icon: _isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      iconColor: _isBookmarked ? const Color(0xFFC59B27) : (isDark ? AppColors.primaryTextDark : const Color(0xFF26352C)),
                      isDark: isDark,
                      onTap: _toggleBookmark,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              // Main Quote Card - Vertically Centered in Screen
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 16,
                        ),
                        child: Center(
                          child: AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return _buildParchmentMessageCard(isDark);
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),

      // Unified 4-Item Luxury Bottom Bar (الرئيسية • المفضلة • مشاركة • نسخ الرسالة)
      bottomNavigationBar: _buildMessageBottomBar(isDark),
    );
  }

  /// The Luxury Parchment Card with multi-layer depth, golden glow and rich botanical accents
  Widget _buildParchmentMessageCard(bool isDark) {
    final pulse = _pulseAnimation.value;

    // Exact warm parchment tones with subtle luxury gradient
    final bgGradientColors = isDark
        ? [
            const Color(0xFF24362B),
            const Color(0xFF1B2A20),
            const Color(0xFF152219),
          ]
        : [
            const Color(0xFFF2ECE0),
            const Color(0xFFEBE3D4),
            const Color(0xFFE5DCcb),
          ];

    final textColor = isDark ? const Color(0xFFF7F5EE) : const Color(0xFF243329);
    final borderColor = isDark
        ? Color.lerp(const Color(0x70D1BE93), const Color(0xA0D1BE93), pulse)!
        : Color.lerp(const Color(0x90D1BE93), const Color(0xD0D1BE93), pulse)!;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: bgGradientColors,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: borderColor,
          width: 1.4,
        ),
        boxShadow: [
          // 1. Ambient deep ground shadow (rich umber/forest tint)
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.55)
                : const Color(0xFF1B3322).withOpacity(0.16 + (0.04 * pulse)),
            blurRadius: 26 + (6 * pulse),
            offset: const Offset(0, 10),
            spreadRadius: -2,
          ),
          // 2. Crisp tactile directional drop shadow
          BoxShadow(
            color: isDark ? const Color(0x40000000) : const Color(0x10000000),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          // 3. Specular Gold Rim Light (Breathes gently)
          BoxShadow(
            color: const Color(0xFFD6BE88).withOpacity(isDark ? 0.12 + (0.08 * pulse) : 0.25 + (0.12 * pulse)),
            blurRadius: 12 + (4 * pulse),
            offset: const Offset(0, -1),
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            // 1. Subtle & Authentic Islamic geometric watermark in center
            Positioned.fill(
              child: CustomPaint(
                painter: IslamicWatermarkPainter(
                  color: isDark
                      ? const Color(0x1CD1BE93)
                      : const Color(0x28B89F70),
                  strokeWidth: 1.15,
                ),
              ),
            ),

            // 2. Corner Ornament Painter for crisp luxury gold brackets
            Positioned.fill(
              child: CustomPaint(
                painter: _CornerOrnamentPainter(
                  color: isDark
                      ? const Color(0x55D1BE93)
                      : const Color(0x77B89F70),
                ),
              ),
            ),

            // 3. Botanical Top-Right Watercolor Branch Asset
            Positioned(
              top: -6,
              right: -6,
              child: IgnorePointer(
                child: Opacity(
                  opacity: isDark ? 0.40 : 0.65,
                  child: AssetHelper.assetOrFallback(
                    assetPath: 'assets/images/botanical_top_right.png',
                    width: 105,
                    height: 125,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

            // 4. Botanical Bottom-Left Watercolor Branch Asset
            Positioned(
              bottom: -6,
              left: -6,
              child: IgnorePointer(
                child: Opacity(
                  opacity: isDark ? 0.40 : 0.65,
                  child: AssetHelper.assetOrFallback(
                    assetPath: 'assets/images/botanical_bottom_left.png',
                    width: 105,
                    height: 125,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

            // 5. Card Inner Content
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Header Row with Like Counter on the Left (in RTL layout)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Left: Interactive Like Heart Counter
                      _buildHeartLikeCounter(isDark),

                      // Center: Heart-Leaf Emblem Circular Avatar with Gold Rim
                      Hero(
                        tag: 'heart_leaf_emblem_hero',
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? const Color(0xFF1B2B20) : const Color(0xFFFAF5EB),
                            border: Border.all(
                              color: const Color(0xFFD6BE88),
                              width: 1.4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFD6BE88).withOpacity(0.25 + (0.15 * pulse)),
                                blurRadius: 10 + (4 * pulse),
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: AssetHelper.assetOrFallback(
                              assetPath: 'assets/images/heart_leaf_emblem.png',
                              width: 32,
                              height: 32,
                              fallback: const Icon(
                                Icons.favorite_rounded,
                                color: AppColors.primaryGreen,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Right: Balance spacer
                      const SizedBox(width: 48),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Category Tag Pill ("رسالة اليوم 🌿" or Category)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2B3F32) : const Color(0xFFFAF6EE),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0x70D1BE93),
                        width: 1.1,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
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
                            size: 14,
                            color: Color(0xFF385240),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.insight.category,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.gold : const Color(0xFF385240),
                            fontFamily: 'Tajawal',
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Top Golden Divider
                  AssetHelper.assetOrFallback(
                    assetPath: 'assets/images/golden_divider.png',
                    width: 120,
                    height: 15,
                    fallback: Container(
                      width: 80,
                      height: 1.5,
                      color: const Color(0xFFD6BE88),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // The Central Message / Quote with Refined Typography
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      '« ${widget.insight.message} »',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        height: 1.85,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        fontFamily: 'Tajawal',
                        letterSpacing: -0.2,
                        shadows: [
                          if (!isDark)
                            const Shadow(
                              color: Color(0x15000000),
                              blurRadius: 1,
                              offset: Offset(0, 1),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Bottom Golden Divider
                  AssetHelper.assetOrFallback(
                    assetPath: 'assets/images/golden_divider.png',
                    width: 120,
                    height: 15,
                    fallback: Container(
                      width: 80,
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
                        width: 20,
                        height: 1,
                        color: const Color(0x70D1BE93),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '🌿 طيّب قلبك • هدي النبوة',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.gold : const Color(0xFF5A7562),
                          fontFamily: 'Tajawal',
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 20,
                        height: 1,
                        color: const Color(0x70D1BE93),
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
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5.5),
          decoration: BoxDecoration(
            color: isDark
                ? (_isLiked ? const Color(0xFF382323) : const Color(0xFF1B2B20))
                : (_isLiked ? const Color(0xFFFDE8E8) : const Color(0xFFFAF6EE)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isLiked ? const Color(0xFFC73E3E).withOpacity(0.6) : const Color(0x70D1BE93),
              width: 1.1,
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
                scale: _isLiked ? 1.2 : 1.0,
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

  /// Unified 4-Item Luxury Bottom Navigation Bar: الرئيسية • المفضلة • مشاركة • نسخ الرسالة
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

              // 2. المفضلة (Favorites)
              Expanded(
                child: _buildBottomBarItem(
                  icon: Icons.bookmark_border_rounded,
                  label: 'المفضلة',
                  onTap: _openFavorites,
                ),
              ),

              // 3. مشاركة (Share)
              Expanded(
                child: _buildBottomBarItem(
                  icon: Icons.share_rounded,
                  label: 'مشاركة',
                  onTap: () => _showSharePreviewDialog(isDark),
                ),
              ),

              // 4. نسخ الرسالة (Copy Text)
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

/// Painter for traditional subtle gold corner brackets inside the card
class _CornerOrnamentPainter extends CustomPainter {
  final Color color;

  _CornerOrnamentPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    const double inset = 12.0;
    const double length = 16.0;

    // Top-Left
    canvas.drawLine(const Offset(inset, inset + length), const Offset(inset, inset), paint);
    canvas.drawLine(const Offset(inset, inset), const Offset(inset + length, inset), paint);

    // Top-Right
    canvas.drawLine(Offset(size.width - inset - length, inset), Offset(size.width - inset, inset), paint);
    canvas.drawLine(Offset(size.width - inset, inset), Offset(size.width - inset, inset + length), paint);

    // Bottom-Left
    canvas.drawLine(Offset(inset, size.height - inset - length), Offset(inset, size.height - inset), paint);
    canvas.drawLine(Offset(inset, size.height - inset), Offset(inset + length, size.height - inset), paint);

    // Bottom-Right
    canvas.drawLine(Offset(size.width - inset - length, size.height - inset), Offset(size.width - inset, size.height - inset), paint);
    canvas.drawLine(Offset(size.width - inset, size.height - inset - length), Offset(size.width - inset, size.height - inset), paint);
  }

  @override
  bool shouldRepaint(covariant _CornerOrnamentPainter oldDelegate) =>
      oldDelegate.color != color;
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
                  fontSize: 12,
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
