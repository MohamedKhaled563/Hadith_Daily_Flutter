import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_state_controller.dart';

class BottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final state = AppStateController();
    final isDark = state.isDarkMode;

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
              // 1. الرئيسية (Home - Index 0)
              Expanded(
                child: _buildNavItem(
                  index: 0,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'الرئيسية',
                  isSelected: currentIndex == 0,
                  onTap: () => onTap(0),
                ),
              ),

              // 2. المشاركات (Community / Posts - Index 1)
              Expanded(
                child: _buildNavItem(
                  index: 1,
                  icon: Icons.forum_outlined,
                  activeIcon: Icons.forum_rounded,
                  label: 'المشاركات',
                  isSelected: currentIndex == 1,
                  onTap: () => onTap(1),
                ),
              ),

              // 3. اكتب رسالة (Share / Add message - Index 2)
              Expanded(
                child: _buildNavItem(
                  index: 2,
                  icon: Icons.edit_note_rounded,
                  activeIcon: Icons.edit_note_rounded,
                  label: 'اكتب رسالة',
                  isSelected: currentIndex == 2,
                  onTap: () => onTap(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return _AnimatedNavItem(
      icon: icon,
      activeIcon: activeIcon,
      label: label,
      isSelected: isSelected,
      onTap: onTap,
    );
  }
}

class _AnimatedNavItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _AnimatedNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_AnimatedNavItem> createState() => _AnimatedNavItemState();
}

class _AnimatedNavItemState extends State<_AnimatedNavItem> {
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
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _isPressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Golden Halo arch behind active tab
              if (widget.isSelected)
                Positioned(
                  top: 0,
                  child: Container(
                    width: 68,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFE8D49E).withOpacity(0.55),
                          const Color(0xFFC59B27).withOpacity(0.25),
                          Colors.transparent,
                        ],
                        radius: 0.85,
                      ),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
                    ),
                  ),
                ),

              // Tab Icon and Label
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.isSelected ? widget.activeIcon : widget.icon,
                    color: widget.isSelected ? Colors.white : const Color(0xFFB0C4B8),
                    size: 24,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.w500,
                      color: widget.isSelected ? Colors.white : const Color(0xFFB0C4B8),
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  if (widget.isSelected) ...[
                    const SizedBox(height: 2),
                    Container(
                      width: 4.5,
                      height: 4.5,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFE8D49E),
                        boxShadow: [
                          BoxShadow(color: Color(0xFFE8D49E), blurRadius: 4),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
