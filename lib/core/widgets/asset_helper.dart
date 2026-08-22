import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';
import 'app_decorations.dart';

class AssetHelper {
  /// Loads a PNG or SVG image with graceful fallback to programmatic vector art
  static Widget assetOrFallback({
    required String assetPath,
    required double width,
    required double height,
    BoxFit fit = BoxFit.contain,
    Widget? fallback,
  }) {
    if (assetPath.endsWith('.svg')) {
      return SvgPicture.asset(
        assetPath,
        width: width,
        height: height,
        fit: fit,
        placeholderBuilder: (BuildContext context) =>
            fallback ?? _getFallbackWidget(assetPath, width, height),
      );
    }

    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return fallback ?? _getFallbackWidget(assetPath, width, height);
      },
    );
  }

  static Widget _getFallbackWidget(String assetPath, double width, double height) {
    if (assetPath.contains('heart_leaf_emblem')) {
      return AppDecorations.heartLeafEmblem(size: width);
    }
    if (assetPath.contains('golden_divider')) {
      return AppDecorations.goldenDivider(width: width, height: height);
    }
    if (assetPath.contains('flower_badge')) {
      return AppDecorations.flowerBadge(size: width);
    }
    if (assetPath.contains('leaf_badge')) {
      return AppDecorations.leafBadge(size: width);
    }
    if (assetPath.contains('botanical_top_right')) {
      return AppDecorations.botanicalTopRight(width: width, height: height);
    }
    if (assetPath.contains('botanical_bottom_left')) {
      return AppDecorations.botanicalBottomLeft(width: width, height: height);
    }
    if (assetPath.contains('sunset_landscape') || assetPath.contains('home_background')) {
      return AppDecorations.sunsetLandscape(height: height);
    }
    return SizedBox(width: width, height: height);
  }
}
