import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/asset_helper.dart';
import '../../core/widgets/smooth_page_route.dart';
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
              // Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button
                  _buildAnimatedCircleButton(
                    icon: Icons.chevron_right,
                    onTap: () => Navigator.pop(context),
                  ),

                  // Center Emblem
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

                  // Bookmark Button
                  _buildAnimatedCircleButton(
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

              // The Main Quote Card
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
                        // Category / Tag
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.softCream,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0x40D1BE93),
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
                                  Icons.eco,
                                  size: 13,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.insight.category,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryGreen,
                                  fontFamily: 'Tajawal',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Message Text in quotes
                        Text(
                          '«${widget.insight.message}»',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            height: 1.7,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryText,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Golden Divider
                        AssetHelper.assetOrFallback(
                          assetPath: 'assets/images/golden_divider.png',
                          width: 100,
                          height: 14,
                          fallback: Container(
                            width: 60,
                            height: 1.5,
                            color: AppColors.gold,
                          ),
                        ),

                        if (widget.hadith != null) ...[
                          const SizedBox(height: 24),
                          _HadithDetailPillButton(
                            title: widget.hadith!.title,
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
                        assetPath: 'assets/images/botanical_top_right.png',
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
                        assetPath: 'assets/images/botanical_bottom_left.png',
                        width: 60,
                        height: 60,
                        fallback: const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Floating 4-Action Bar (مشاركة - حفظ - نسخ - تذكير)
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
                    _buildActionItem(
                      icon: Icons.send_outlined,
                      label: 'مشاركة',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'تم نسخ الرسالة لمشاركتها',
                              textDirection: TextDirection.rtl,
                              style: TextStyle(fontFamily: 'Tajawal'),
                            ),
                            backgroundColor: AppColors.primaryGreen,
                          ),
                        );
                      },
                    ),
                    _buildActionDivider(),
                    _buildActionItem(
                      icon: _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      label: 'حفظ',
                      isSelected: _isBookmarked,
                      onTap: () {
                        setState(() => _isBookmarked = !_isBookmarked);
                      },
                    ),
                    _buildActionDivider(),
                    _buildActionItem(
                      icon: Icons.copy_rounded,
                      label: 'نسخ',
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: widget.insight.message));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'تم نسخ نص الرسالة',
                              textDirection: TextDirection.rtl,
                              style: TextStyle(fontFamily: 'Tajawal'),
                            ),
                            backgroundColor: AppColors.primaryGreen,
                          ),
                        );
                      },
                    ),
                    _buildActionDivider(),
                    _buildActionItem(
                      icon: _reminderSet ? Icons.notifications_active : Icons.notifications_none,
                      label: 'تذكير',
                      isSelected: _reminderSet,
                      onTap: () {
                        setState(() => _reminderSet = !_reminderSet);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _reminderSet ? 'تم تفعيل التذكير اليومي بهذه الرسالة' : 'تم إلغاء التذكير',
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

  Widget _buildActionDivider() {
    return Container(
      width: 1,
      height: 28,
      color: const Color(0x33D1BE93),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return _AnimatedActionItem(
      icon: icon,
      label: label,
      isSelected: isSelected,
      onTap: onTap,
    );
  }

  Widget _buildAnimatedCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = AppColors.primaryText,
  }) {
    return _AnimatedMessageTopButton(
      icon: icon,
      iconColor: iconColor,
      onTap: onTap,
    );
  }
}

class _HadithDetailPillButton extends StatefulWidget {
  final String title;
  final VoidCallback onTap;

  const _HadithDetailPillButton({
    required this.title,
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
          scale: _isPressed ? 0.94 : (_isHovered ? 1.03 : 1.0),
          duration: const Duration(milliseconds: 140),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: _isHovered ? const Color(0xFFEBE3D3) : AppColors.secondaryCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isHovered ? AppColors.gold : const Color(0x59D1BE93),
              ),
              boxShadow: [
                if (_isHovered)
                  const BoxShadow(
                    color: Color(0x153B5644),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'شرح الحديث (${widget.title})',
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
      ),
    );
  }
}

class _AnimatedActionItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _AnimatedActionItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_AnimatedActionItem> createState() => _AnimatedActionItemState();
}

class _AnimatedActionItemState extends State<_AnimatedActionItem> {
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                color: widget.isSelected ? AppColors.gold : AppColors.primaryGreen,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.normal,
                  color: widget.isSelected ? AppColors.gold : AppColors.primaryGreen,
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

  const _AnimatedMessageTopButton({
    required this.icon,
    required this.onTap,
    required this.iconColor,
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
          scale: _isPressed ? 0.88 : 1.0,
          duration: const Duration(milliseconds: 140),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.secondaryCard,
              border: Border.all(
                color: const Color(0x66D1BE93),
              ),
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
