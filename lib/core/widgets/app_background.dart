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
          // 1. Background Base Warm Tone
          const ColoredBox(
            color: AppColors.background,
          ),

          // 2. Full-Screen Natural Landscape PNG (Home Screen)
          if (showBottomLandscape)
            Positioned.fill(
              child: IgnorePointer(
                child: _buildHomeImage(),
              ),
            ),

          // 3. Inner Screens Background
          if (!showBottomLandscape)
            Positioned.fill(
              child: IgnorePointer(
                child: _buildInnerImage(),
              ),
            ),

          // 4. Safe Area Content
          SafeArea(
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildHomeImage() {
    // Supports standard naming and Windows double-extension (.png.png)
    return Image.asset(
      'assets/images/home_background.png',
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          'assets/images/home_background.png.png',
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
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

  Widget _buildInnerImage() {
    return Image.asset(
      'assets/images/background_empty.png',
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          'assets/images/background_empty.png.png',
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
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
