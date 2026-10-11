import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/app_motion.dart';
import 'asset_helper.dart';
import 'bottom_navigation.dart';

/// Paints the botanical ground behind a screen's content.
///
/// This is a decoration widget, not page chrome — it deliberately provides
/// neither a [Scaffold] nor a [SafeArea]. Previously it supplied both, which
/// meant every screen nested a second Scaffold inside it and SnackBars attached
/// to the inner one, rendering them underneath the floating bottom nav bar.
/// The host screen owns its Scaffold; use [AppScreen] for route-level screens.
class AppBackground extends StatelessWidget {
  const AppBackground({
    super.key,
    required this.child,
    this.showBottomLandscape = false,
  });

  final Widget child;
  final bool showBottomLandscape;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.backgroundDark : AppColors.background;

    return DecoratedBox(
      decoration: BoxDecoration(color: bgColor),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Decorative artwork: out of the hit-test tree and out of the
          // semantics tree, so it never intercepts taps or gets announced.
          ExcludeSemantics(
            child: IgnorePointer(
              child: showBottomLandscape
                  ? _buildHomeImage(isDark)
                  : _buildInnerImage(isDark),
            ),
          ),

          if (showBottomLandscape)
            ExcludeSemantics(
              child: IgnorePointer(child: _SkyTint(isDark: isDark)),
            ),

          child,
        ],
      ),
    );
  }

  /// Dark mode used to paint the *daytime* painting at 45% opacity over
  /// [AppColors.backgroundDark] and then lay a 42% black scrim on top. Because
  /// the top two thirds of that artwork is near-white cream, the composite
  /// landed around #4A4F47 — a desaturated mid-grey, lighter than the parchment
  /// cards sitting on it, so every card read as a hole punched in the page
  /// rather than a surface raised off it.
  ///
  /// These are proper night variants instead: the same painting, luminance
  /// remapped into the app's dark range (see tool/make_night_backgrounds.py),
  /// drawn at full opacity with no scrim. The ground now sits below the cards
  /// everywhere — 99th-percentile ground luminance 0.023 against the card's
  /// 0.032 — and the scene keeps its emerald rather than going grey.
  /// WebP rather than PNG. These are full-bleed soft watercolours, which is
  /// the case WebP compresses best: the same pixels went from 1471 KB to
  /// 74 KB and 1007 KB to 12 KB, with no visible difference at 1:1.
  ///
  /// They are NOT higher resolution, and that is a separate, unfixed problem:
  /// the source art in art-originals/ is only 853x1844, so on a 1080p phone
  /// BoxFit.cover still upscales it. Nothing here can add detail that was
  /// never rendered — that needs the artwork re-exported at source.
  Widget _buildHomeImage(bool isDark) => _background(
        isDark
            ? 'assets/images/home_background_night.webp'
            : 'assets/images/home_background.webp',
      );

  Widget _buildInnerImage(bool isDark) => _background(
        isDark
            ? 'assets/images/background_empty_night.webp'
            : 'assets/images/background_empty.webp',
      );

  Widget _background(String path) {
    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return AssetHelper.assetOrFallback(
          assetPath: path.replaceAll(RegExp(r'\.(png|webp)$'), '.svg'),
          fit: BoxFit.cover,
          fallback: const SizedBox.shrink(),
        );
      },
    );
  }
}

/// A route-level screen: exactly one [Scaffold], the botanical background, and
/// one [SafeArea]. Screens that live inside a parent's `IndexedStack` should
/// NOT use this — the host already provides the Scaffold and background.
class AppScreen extends StatelessWidget {
  const AppScreen({
    super.key,
    required this.child,
    this.showBottomLandscape = true,
    this.bottomNavigationBar,
    this.drawer,
    this.scaffoldKey,
    this.resizeToAvoidBottomInset = true,
  });

  final Widget child;
  final bool showBottomLandscape;
  final Widget? bottomNavigationBar;
  final Widget? drawer;
  final GlobalKey<ScaffoldState>? scaffoldKey;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      drawer: drawer,
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      // The body runs the full height of the screen, behind the floating nav
      // bar, so the botanical scene is never cut off above it.
      extendBody: true,
      extendBodyBehindAppBar: true,
      bottomNavigationBar: bottomNavigationBar,
      body: AppBackground(
        showBottomLandscape: showBottomLandscape,
        // Wrapping in the bar's scope here, once, means every screen built
        // with a bottomNavigationBar automatically reserves the bar's real
        // measured height (see BottomNavigation.reservedHeight) instead of
        // each screen needing to remember to wrap itself.
        child: SafeArea(
          bottom: false,
          child: bottomNavigationBar == null
              ? child
              : BottomNavigation.scope(child: child),
        ),
      ),
    );
  }
}

/// Tints the sky of the landscape to the hour: lavender and peach at dawn,
/// a fresh green by day, coral at sunset, a deep blue in the evening. The
/// painting itself never changes; this is a wash over its empty upper half,
/// fading out well before the hills, so the scene feels like *now*.
///
/// It used to read the clock only at build, trusting the home screen to
/// rebuild often enough. It doesn't: an app opened at three was still showing
/// the daytime green at ten past four. So the tint now keeps its own clock —
/// a timer to the top of the next hour, and a fresh look whenever the app
/// comes back to the foreground (timers do not run while it is suspended).
class _SkyTint extends StatefulWidget {
  const _SkyTint({required this.isDark});

  final bool isDark;

  @override
  State<_SkyTint> createState() => _SkyTintState();
}

class _SkyTintState extends State<_SkyTint> with WidgetsBindingObserver {
  late int _hour = DateTime.now().hour;
  Timer? _nextHour;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleNextHour();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nextHour?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _scheduleNextHour() {
    _nextHour?.cancel();
    final now = DateTime.now();
    final topOfNextHour = DateTime(now.year, now.month, now.day, now.hour + 1);
    // A second past the hour, so the clock has certainly turned over.
    _nextHour = Timer(
      topOfNextHour.difference(now) + const Duration(seconds: 1),
      _refresh,
    );
  }

  void _refresh() {
    if (!mounted) return;
    final hour = DateTime.now().hour;
    if (hour != _hour) setState(() => _hour = hour);
    _scheduleNextHour();
  }

  static List<Color> _colorsFor(int hour, bool isDark) {
    if (isDark) {
      return const [Color(0xB314402E), Color(0x40143A2A), Color(0x00000000)];
    }
    if (hour >= 4 && hour < 7) {
      // Dawn — around Fajr.
      return const [Color(0x8CB0AAD6), Color(0x73F3C4AF), Color(0x00F3C4AF)];
    }
    if (hour >= 7 && hour < 16) {
      return const [Color(0x8CA6D6BE), Color(0x59D6ECDE), Color(0x00D6ECDE)];
    }
    if (hour >= 16 && hour < 19) {
      // Sunset — around Maghrib, matching the sun already in the painting.
      return const [Color(0x8CE78B60), Color(0x73F6C596), Color(0x00F6C596)];
    }
    return const [Color(0x8C7E8CC2), Color(0x59C9C3E3), Color(0x00C9C3E3)];
  }

  @override
  Widget build(BuildContext context) {
    // Animated, so a period change while the reader is looking is a slow
    // shift of light rather than a cut.
    return AnimatedContainer(
      duration: context.motion(const Duration(milliseconds: 1600)),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _colorsFor(_hour, widget.isDark),
          stops: const [0.0, 0.32, 0.6],
        ),
      ),
    );
  }
}
