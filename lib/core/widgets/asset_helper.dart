import 'package:flutter/material.dart';

class AssetHelper {
  // Try loading asset image, fallback to builder/icon gracefully
  static Widget assetOrFallback({
    required String assetPath,
    required double width,
    required double height,
    BoxFit fit = BoxFit.contain,
    Widget? fallback,
  }) {
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
