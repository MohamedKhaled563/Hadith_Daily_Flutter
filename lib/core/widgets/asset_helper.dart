import 'package:flutter/material.dart';
import 'app_decorations.dart';

class AssetHelper {
  static Widget assetOrFallback({
    required String assetPath,
    required double width,
    required double height,
    BoxFit fit = BoxFit.contain,
    Widget? fallback,
  }) {
    // If the path refers to SVGs/images that have built-in high fidelity painters
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
    if (assetPath.contains('sunset_landscape')) {
      return AppDecorations.sunsetLandscape(height: height);
    }

    // Default image loader
    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return fallback ?? SizedBox(width: width, height: height);
      },
    );
  }
}
