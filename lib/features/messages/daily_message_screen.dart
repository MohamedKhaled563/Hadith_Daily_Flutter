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
  bool _isLiked = false;
  int _likesCount = 42;
  bool _isBookmarked = false;
  bool _reminderSet = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        showBottomLandscape: true,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
            child: Column(
              children: [
                // Top Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back Button
                    _buildAnimatedCircleButton(
                      icon: Icons.chevron_right_rounded,
                      onTap: () {
                        if (Navigator.canPop(context)) Navigator.pop(context);
                      },
                    ),

                    // Center Emblem
                    AssetHelper.assetOrFallback(
                      assetPath: 'assets/images/heart_leaf_emblem.png',
                      width: 42,
                      height: 42,
                      fallback: const Icon(
                        Icons.favorite_rounded,
                        color: AppColors.primaryGreen,
                        size: 28,
                      ),
                    ),

                    // Bookmark Button
                    _buildAnimatedCircleButton(
                      icon: _isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      iconColor: _isBookmarked ? const Color(0xFFC59B27) : const Color(0xFF26352C),
                      onTap: () {
                        setState(() => _isBookmarked = !_isBookmarked);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _isBookmarked ? 'تم حفظ الرسالة في المحفوظات 🌿' : 'تمت الإزالة من المحفوظات',
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
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFDFC),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: const Color(0x66D1BE93),
                          width: 1.2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0E000000),
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
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF6EE),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0x50D1BE93),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AssetHelper.assetOrFallback(
                                  assetPath: 'assets/images/leaf_accent.png',
                                  width: 15,
                                  height: 15,
                                  fallback: const Icon(
                                    Icons.eco_rounded,
                                    size: 13,
                                    color: Color(0xFF385240),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  widget.insight.category,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF385240),
                                    fontFamily: 'Tajawal',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Message Text in quotes
                          Text(
                            '« ${widget.insight.message} »',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 19,
                              height: 1.75,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF26352C),
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
                              color: const Color(0xFFD6BE88),
                            ),
                          ),

                          if (widget.hadith != null) ...[
                            const SizedBox(height: 22),
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
                  ],
                ),

                const Spacer(),

                // Floating 4-Action Bar (إعجاب ❤️ - مشاركة - نسخ - تذكير)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF6EE),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0x66D1BE93),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0E000000),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Like (Heart)
                      _buildActionItem(
                        icon: _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        label: '$_likesCount',
                        isSelected: _isLiked,
                        selectedColor: const Color(0xFFC73E3E),
                        onTap: () {
                          setState(() {
                            _isLiked = !_isLiked;
                            _likesCount += _isLiked ? 1 : -1;
                          });
                        },
                      ),
                      _buildActionDivider(),

                      // Share
                      _buildActionItem(
                        icon: Icons.send_outlined,
                        label: 'مشاركة',
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: '« ${widget.insight.message} »\n\n— من تطبيق طيّب قلبك'));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'تم نسخ نص الرسالة لمشاركتها 🌿',
                                textDirection: TextDirection.rtl,
                                style: TextStyle(fontFamily: 'Tajawal'),
                              ),
                              backgroundColor: AppColors.primaryGreen,
                            ),
                          );
                        },
                      ),
                      _buildActionDivider(),

                      // Copy
                      _buildActionItem(
                        icon: Icons.copy_rounded,
                        label: 'نسخ',
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: widget.insight.message));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'تم نسخ نص الرسالة بنجاح',
                                textDirection: TextDirection.rtl,
                                style: TextStyle(fontFamily: 'Tajawal'),
                              ),
                              backgroundColor: AppColors.primaryGreen,
                            ),
                          );
                        },
                      ),
                      _buildActionDivider(),

                      // Reminder
                      _buildActionItem(
                        icon: _reminderSet ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                        label: 'تذكير',
                        isSelected: _reminderSet,
                        selectedColor: const Color(0xFFC59B27),
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
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionDivider() {
    return Container(
      width: 1,
      height: 26,
      color: const Color(0x33D1BE93),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isSelected = false,
    Color selectedColor = const Color(0xFFC59B27),
  }) {
    return _AnimatedActionItem(
      icon: icon,
      label: label,
      isSelected: isSelected,
      selectedColor: selectedColor,
      onTap: onTap,
    );
  }

  Widget _buildAnimatedCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = const Color(0xFF26352C),
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
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            decoration: BoxDecoration(
              color: _isHovered ? const Color(0xFFEBE3D3) : const Color(0xFFFAF6EE),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isHovered ? const Color(0xFFC59B27) : const Color(0x60D1BE93),
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
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF385240),
                    fontFamily: 'Tajawal',
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_back_rounded,
                  size: 14,
                  color: Color(0xFF385240),
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
  final VoidCallback onTap;

  const _AnimatedActionItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.selectedColor,
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
                color: widget.isSelected ? widget.selectedColor : const Color(0xFF385240),
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.w600,
                  color: widget.isSelected ? widget.selectedColor : const Color(0xFF385240),
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
              color: const Color(0xFFFAF6EE),
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
