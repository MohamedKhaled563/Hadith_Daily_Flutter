import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_state_controller.dart';
import 'asset_helper.dart';

class AppBackground extends StatelessWidget {
  final Widget child;
  final bool showBottomLandscape;

  const AppBackground({
    super.key,
    required this.child,
    this.showBottomLandscape = false,
  });

  @override
  Widget build(BuildContext context) {
    final state = AppStateController();

    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final isDark = state.isDarkMode;
        final bgColor = isDark ? AppColors.backgroundDark : AppColors.background;

        return Scaffold(
          backgroundColor: bgColor,
          body: Stack(
            children: [
              // 1. Background Base Tone
              ColoredBox(
                color: bgColor,
                child: const SizedBox.expand(),
              ),

              // 2. Full-Screen Natural Landscape PNG (Home Screen)
              if (showBottomLandscape)
                Positioned.fill(
                  child: IgnorePointer(
                    child: _buildHomeImage(isDark),
                  ),
                ),

              // 3. Inner Screens Background
              if (!showBottomLandscape)
                Positioned.fill(
                  child: IgnorePointer(
                    child: _buildInnerImage(isDark),
                  ),
                ),

              // 4. Subtle Dark Mode Harmonizing Tint (keeps the night serene & balanced)
              if (isDark)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: Colors.black.withOpacity(0.42),
                    ),
                  ),
                ),

              // 5. Safe Area Content
              SafeArea(
                child: child,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHomeImage(bool isDark) {
    // Supports standard naming and Windows double-extension (.png.png)
    return Image.asset(
      'assets/images/home_background.png',
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      opacity: AlwaysStoppedAnimation(isDark ? 0.45 : 1.0),
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          'assets/images/home_background.png.png',
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          opacity: AlwaysStoppedAnimation(isDark ? 0.45 : 1.0),
          errorBuilder: (context, error, stackTrace) {
            return AssetHelper.assetOrFallback(
              assetPath: 'assets/images/sunset_landscape.svg',
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              fallback: const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }

  Widget _buildInnerImage(bool isDark) {
    return Image.asset(
      'assets/images/background_empty.png',
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      opacity: AlwaysStoppedAnimation(isDark ? 0.35 : 1.0),
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          'assets/images/background_empty.png.png',
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          opacity: AlwaysStoppedAnimation(isDark ? 0.35 : 1.0),
          errorBuilder: (context, error, stackTrace) {
            return Stack(
              children: [
                Positioned(
                  bottom: 0,
                  left: 0,
                  width: 140,
                  height: 180,
                  child: AssetHelper.assetOrFallback(
                    assetPath: 'assets/images/botanical_bottom_left.svg',
                    width: 140,
                    height: 180,
                    fit: BoxFit.contain,
                    fallback: const SizedBox.shrink(),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  width: 120,
                  height: 150,
                  child: AssetHelper.assetOrFallback(
                    assetPath: 'assets/images/botanical_top_right.svg',
                    width: 120,
                    height: 150,
                    fit: BoxFit.contain,
                    fallback: const SizedBox.shrink(),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
