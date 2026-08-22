import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

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
                activeIcon: Icons.share,
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

            // Middle Section: جميع المجتمع (Index 1)
            Expanded(
              child: _buildNavItem(
                icon: Icons.people_alt_outlined,
                activeIcon: Icons.people_alt_rounded,
                label: 'جميع المجتمع',
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: isSelected ? const Color(0xFFEBE3D3) : Colors.transparent,
            ),
            child: Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? const Color(0xFF26352C) : const Color(0xFF5A7061),
              size: 24,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? const Color(0xFF26352C) : const Color(0xFF5A7061),
              fontFamily: 'Tajawal',
            ),
          ),
        ],
      ),
    );
  }
}
