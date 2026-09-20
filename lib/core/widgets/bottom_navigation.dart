import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';
import '../utils/app_motion.dart';
import 'tap_target.dart';

/// The bar's real on-screen height, measured after every layout rather than
/// assumed from constants. A hand-computed estimate (bar height + gaps +
/// `MediaQuery.viewPaddingOf(context).bottom`) used to be duplicated in every
/// screen that reserves space for this floating bar, and on at least one
/// Android version/emulator that estimate under-counted the real system
/// gesture-bar inset enough that content — e.g. the "إرسال الرسالة" button —
/// visually overlapped the bar instead of clearing it. Measuring the actual
/// rendered widget sidesteps the whole question of what a given OS/version
/// reports through which MediaQuery field, on Android or iOS alike.
final ValueNotifier<double> _measuredBottomNavHeight = ValueNotifier<double>(0);

/// Makes the real measured bar height available to every descendant that
/// calls [BottomNavigation.reservedHeight] via `InheritedNotifier`, so each
/// of those call sites — spread across several screens/routes — rebuilds
/// automatically if the real height ever changes (rotation, a future label
/// tweak, a different OS inset) instead of relying on a value baked in once.
class _BottomNavHeightScope extends InheritedNotifier<ValueNotifier<double>> {
  const _BottomNavHeightScope({required super.notifier, required super.child});
}

class BottomNavigation extends StatefulWidget {
  const BottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Height of the floating pill itself, used only as a same-frame fallback
  /// before the bar has had a chance to lay out and report its real size.
  static const barHeight = 72.0;
  static const _topGap = 4.0;
  static const _bottomGap = 14.0;

  /// Wrap a screen's body in this so its content reserves the bar's real
  /// height — every screen with its own [BottomNavigation] (whether a tab
  /// inside the home screen's IndexedStack or a separately pushed route)
  /// should wrap its body with this once, near the Scaffold.
  static Widget scope({required Widget child}) => _BottomNavHeightScope(
        notifier: _measuredBottomNavHeight,
        child: child,
      );

  /// Space the bar occupies over the content, including the device's own
  /// bottom inset. Scrollable content uses this as extra bottom padding so
  /// the last item clears the pill — the body now extends behind it.
  static double reservedHeight(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_BottomNavHeightScope>();
    final measured = scope?.notifier?.value ?? 0;
    if (measured > 0) return measured;
    // Fallback: no scope above this context (shouldn't normally happen once
    // every screen is wrapped), or the bar hasn't measured itself yet.
    return barHeight +
        _topGap +
        _bottomGap +
        MediaQuery.viewPaddingOf(context).bottom;
  }

  @override
  State<BottomNavigation> createState() => _BottomNavigationState();
}

class _BottomNavigationState extends State<BottomNavigation> {
  final _barKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _reportMeasuredHeight());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-measure on locale/text-scale/orientation changes, not just first
    // build — any of those can change the bar's real rendered height.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _reportMeasuredHeight());
  }

  void _reportMeasuredHeight() {
    final height = _barKey.currentContext?.size?.height;
    if (height != null &&
        height > 0 &&
        height != _measuredBottomNavHeight.value) {
      _measuredBottomNavHeight.value = height;
    }
  }

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
      // Shortened from the full "مجتمع الحديث": on 320dp-class screens the
      // 4-way-equal-width tab bar didn't have room for the longest of the
      // four labels and silently ellipsized it to "مجتمع الحد…".
      label: 'المجتمع',
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
      key: _barKey,
      padding: EdgeInsets.fromLTRB(
        16,
        BottomNavigation._topGap,
        16,
        BottomNavigation._bottomGap + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Container(
        height: BottomNavigation.barHeight,
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
            color:
                const Color(0xFFD6BE88).withValues(alpha: isDark ? 0.45 : 0.65),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.30),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: const Color(0xFFD6BE88)
                  .withValues(alpha: isDark ? 0.12 : 0.20),
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
                    isSelected: widget.currentIndex == i,
                    onTap: () {
                      // Only on an actual change — re-tapping the tab you are
                      // already on should not buzz.
                      if (widget.currentIndex != i) AppHaptics.selection();
                      widget.onTap(i);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Height reserved for the active dot whether or not it is showing.
///
/// The dot and its spacer used to be *added to* the column only when
/// selected — 6.5dp of extra height inside a centre-aligned 72dp box — so on
/// every tab change the newly selected icon and label jumped up 3.25dp and
/// the old one dropped back down. Reserving the space unconditionally is what
/// makes the selection animate instead of jolt.
const double _activeDotSlot = 6.5;

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
              // Always built, faded rather than inserted — an appearing halo
              // is what a selection should look like, not a flash.
              ExcludeSemantics(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: isSelected ? 1 : 0,
                    duration: context.motion(AppDurations.control),
                    curve: AppDurations.curve,
                    child: const _GoldenHalo(),
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The glyph swaps outline -> filled, so it cross-fades
                  // rather than popping.
                  AnimatedSwitcher(
                    duration: context.motion(AppDurations.control),
                    switchInCurve: AppDurations.curve,
                    child: Icon(
                      isSelected ? activeIcon : icon,
                      key: ValueKey(isSelected),
                      color: isSelected ? Colors.white : _inactive,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Flexible(
                    child: AnimatedDefaultTextStyle(
                      duration: context.motion(AppDurations.control),
                      curve: AppDurations.curve,
                      style: TextStyle(
                        fontFamily: kSans,
                        fontSize: 12.5,
                        height: AppLeading.chrome,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : _inactive,
                      ),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  // Reserved whether or not it shows — see _activeDotSlot.
                  SizedBox(
                    height: _activeDotSlot,
                    child: Center(
                      child: AnimatedScale(
                        scale: isSelected ? 1 : 0,
                        duration: context.motion(AppDurations.control),
                        curve: Curves.easeOutBack,
                        child: const _ActiveDot(),
                      ),
                    ),
                  ),
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
