import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'app_decorations.dart';

class AssetHelper {
  /// Loads a PNG (preferred) or SVG image, falling back to programmatic vector
  /// art when neither is bundled.
  ///
  /// Decorative by definition — every result is wrapped in [ExcludeSemantics]
  /// so ornament never reaches a screen reader.
  static Widget assetOrFallback({
    required String assetPath,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    Widget? fallback,
  }) {
    return ExcludeSemantics(
      child: _resolve(
        assetPath: assetPath,
        width: width,
        height: height,
        fit: fit,
        fallback: fallback,
      ),
    );
  }

  static Widget _resolve({
    required String assetPath,
    double? width,
    double? height,
    required BoxFit fit,
    Widget? fallback,
  }) {
    final isSvg = assetPath.endsWith('.svg');
    final rasterPath = isSvg ? assetPath.replaceAll('.svg', '.png') : assetPath;
    final vectorPath = isSvg ? assetPath : assetPath.replaceAll('.png', '.svg');

    return Image.asset(
      rasterPath,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return SvgPicture.asset(
          vectorPath,
          width: width,
          height: height,
          fit: fit,
          placeholderBuilder: (context) =>
              fallback ?? _getFallbackWidget(assetPath, width, height),
        );
      },
    );
  }

  static Widget _getFallbackWidget(String assetPath, double? w, double? h) {
    final width = w ?? 48;
    final height = h ?? 48;

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
    if (assetPath.contains('sunset_landscape') ||
        assetPath.contains('home_background')) {
      return AppDecorations.sunsetLandscape(height: height);
    }
    return SizedBox(width: w, height: h);
  }
}
