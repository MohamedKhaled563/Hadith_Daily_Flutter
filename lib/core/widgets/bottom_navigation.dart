import 'package:flutter/material.dart';

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
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      height: 76,
      decoration: BoxDecoration(
        color: const Color(0xFFFAF6EE),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: const Color(0x40D1BE93),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
          BoxShadow(
            color: Color(0x20FFFDFC),
            blurRadius: 4,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            // Left Section: المشاركة (Index 2)
            Expanded(
              child: _buildNavItem(
                icon: Icons.share_outlined,
                activeIcon: Icons.share_rounded,
                label: 'المشاركة',
                isSelected: currentIndex == 2,
                onTap: () => onTap(2),
              ),
            ),

            // Vertical Divider 1
            Container(
              height: 38,
              width: 1.2,
              color: const Color(0x30B9A06A),
            ),

            // Middle Section: جميع الأحاديث (Index 1) - Replaced "جميع المجتمع"
            Expanded(
              child: _buildNavItem(
                icon: Icons.menu_book_outlined,
                activeIcon: Icons.menu_book_rounded,
                label: 'جميع الأحاديث',
                isSelected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
            ),

            // Vertical Divider 2
            Container(
              height: 38,
              width: 1.2,
              color: const Color(0x30B9A06A),
            ),

            // Right Section: الرئيسية (Index 0)
            Expanded(
              child: _buildNavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'الرئيسية',
                isSelected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                width: widget.isSelected ? 48 : 42,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: widget.isSelected ? const Color(0xFFEBE3D3) : Colors.transparent,
                ),
                child: Icon(
                  widget.isSelected ? widget.activeIcon : widget.icon,
                  color: widget.isSelected ? const Color(0xFF26352C) : const Color(0xFF5A7061),
                  size: 24,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.w600,
                  color: widget.isSelected ? const Color(0xFF26352C) : const Color(0xFF5A7061),
                  fontFamily: 'Tajawal',
                ),
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
