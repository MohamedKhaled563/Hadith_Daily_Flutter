import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'asset_helper.dart';

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

          // Harmonising tint that keeps the night scene serene.
          if (isDark)
            ExcludeSemantics(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.42),
                ),
              ),
            ),

          child,
        ],
      ),
    );
  }

  Widget _buildHomeImage(bool isDark) => _background(
    'assets/images/home_background.png',
    opacity: isDark ? 0.45 : 1.0,
  );

  Widget _buildInnerImage(bool isDark) => _background(
    'assets/images/background_empty.png',
    opacity: isDark ? 0.35 : 1.0,
  );

  Widget _background(String path, {required double opacity}) {
    return Image.asset(
      path,
      fit: BoxFit.cover,
      opacity: AlwaysStoppedAnimation(opacity),
      errorBuilder: (context, error, stackTrace) {
        return AssetHelper.assetOrFallback(
          assetPath: path.replaceAll('.png', '.svg'),
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
        child: SafeArea(bottom: false, child: child),
      ),
    );
  }
}
