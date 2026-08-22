import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background Base Color
          const ColoredBox(
            color: AppColors.background,
          ),

          // Full-Screen / High-Composition Sunset Landscape (for Home Screen)
          if (showBottomLandscape)
            Positioned.fill(
              child: IgnorePointer(
                child: AssetHelper.assetOrFallback(
                  assetPath: 'assets/images/sunset_landscape.svg',
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  fallback: const SizedBox.shrink(),
                ),
              ),
            ),

          // Gentle bottom botanical foliage for inner screens when landscape is off
          if (!showBottomLandscape) ...[
            Positioned(
              bottom: 0,
              left: 0,
              width: 140,
              height: 180,
              child: IgnorePointer(
                child: AssetHelper.assetOrFallback(
                  assetPath: 'assets/images/botanical_bottom_left.svg',
                  width: 140,
                  height: 180,
                  fit: BoxFit.contain,
                  fallback: const SizedBox.shrink(),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              width: 120,
              height: 150,
              child: IgnorePointer(
                child: AssetHelper.assetOrFallback(
                  assetPath: 'assets/images/botanical_top_right.svg',
                  width: 120,
                  height: 150,
                  fit: BoxFit.contain,
                  fallback: const SizedBox.shrink(),
                ),
              ),
            ),
          ],

          // Safe Area Content
          SafeArea(
            child: child,
          ),
        ],
      ),
    );
  }
}
