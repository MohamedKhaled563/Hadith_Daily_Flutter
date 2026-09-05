import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';
import 'tap_target.dart';

class BottomNavigation extends StatelessWidget {
  const BottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Height of the floating pill itself.
  static const barHeight = 72.0;
  static const _topGap = 4.0;
  static const _bottomGap = 14.0;

  /// Space the bar occupies over the content, including the device's own
  /// bottom inset. Scrollable content uses this as extra bottom padding so the
  /// last item clears the pill — the body now extends behind it.
  static double reservedHeight(BuildContext context) =>
      barHeight +
      _topGap +
      _bottomGap +
      MediaQuery.viewPaddingOf(context).bottom;

  static const _items = <({IconData icon, IconData activeIcon, String label})>[
    (
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'الرئيسية',
    ),
    (
      icon: Icons.bookmark_border_rounded,
      activeIcon: Icons.bookmark_rounded,
      label: 'المفضلة',
    ),
    (
      icon: Icons.forum_outlined,
      activeIcon: Icons.forum_rounded,
      label: 'مجتمع الحديث',
    ),
    (
      icon: Icons.edit_note_rounded,
      activeIcon: Icons.edit_note_rounded,
      label: 'شارك رسالة',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // No background of its own: the scaffold body now extends behind the bar,
    // so the botanical scene shows through around the floating pill.
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        _topGap,
        16,
        _bottomGap + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Container(
        height: barHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF1D2B21), const Color(0xFF141F18)]
                : [const Color(0xFF2C4334), const Color(0xFF1E3024)],
          ),
          borderRadius: BorderRadius.circular(36),
          border: Border.all(
            color: const Color(0xFFD6BE88).withValues(alpha: isDark ? 0.45 : 0.65),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.30),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: const Color(0xFFD6BE88).withValues(alpha: isDark ? 0.12 : 0.20),
              blurRadius: 10,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          // No explicit Directionality here: the app is already RTL via
          // MaterialApp.locale, and pinning it implied the ambient direction
          // could not be trusted.
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _NavItem(
                    icon: _items[i].icon,
                    activeIcon: _items[i].activeIcon,
                    label: _items[i].label,
                    isSelected: currentIndex == i,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  static const _inactive = Color(0xFFB0C4B8);

  @override
  Widget build(BuildContext context) {
    return TapTarget(
      onTap: onTap,
      semanticLabel: label,
      selected: isSelected,
      minSize: 56,
      // Nav labels are compact chrome, not reading content, and this pill's
      // height is fixed — left unscaled so a large accessibility text-size
      // setting can't push the label/active-dot past the 72dp box (Stack
      // clips silently there instead of overflowing, i.e. the label would
      // just go missing rather than error).
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: SizedBox(
        height: 72,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isSelected)
              const ExcludeSemantics(
                child: IgnorePointer(child: _GoldenHalo()),
              ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected ? Colors.white : _inactive,
                  size: 24,
                ),
                const SizedBox(height: 3),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 12.5,
                      height: AppLeading.chrome,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected ? Colors.white : _inactive,
                    ),
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(height: 2),
                  const _ActiveDot(),
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

class _GoldenHalo extends StatelessWidget {
  const _GoldenHalo();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        width: 68,
        height: 48,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            radius: 0.85,
            colors: [
              const Color(0xFFE8D49E).withValues(alpha: 0.55),
              const Color(0xFFC59B27).withValues(alpha: 0.25),
              Colors.transparent,
            ],
          ),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(30),
          ),
        ),
      ),
    );
  }
}

class _ActiveDot extends StatelessWidget {
  const _ActiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4.5,
      height: 4.5,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFE8D49E),
        boxShadow: [BoxShadow(color: Color(0xFFE8D49E), blurRadius: 4)],
      ),
    );
  }
}
