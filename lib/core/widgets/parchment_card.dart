import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import 'asset_helper.dart';
import 'islamic_pattern_painter.dart';
import 'tap_target.dart';

/// The app's one parchment surface.
///
/// Replaces four near-identical implementations that had drifted to five
/// different corner radii and four different shadow recipes. All colour comes
/// from [BotanicalPalette], so it repaints correctly on a theme change.
class ParchmentCard extends StatelessWidget {
  const ParchmentCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(20),
    this.elevated = false,
    this.showBotanicals = false,
    this.showCornerOrnaments = true,
    this.showWatermark = true,
    this.semanticLabel,
    this.borderColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Hero treatment (three-layer shadow with gold rim) vs. resting list card.
  final bool elevated;

  final bool showBotanicals;
  final bool showCornerOrnaments;

  /// The geometric watermark needs room to read as texture. On a short list
  /// row it just looks like a stray box, so compact rows turn it off.
  final bool showWatermark;

  final String? semanticLabel;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = context.isDarkMode;
    const radius = AppRadii.card;

    final surface = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: elevated
              ? [
                  palette.parchmentTop,
                  palette.parchmentMid,
                  palette.parchmentBottom,
                ]
              : [palette.parchmentTop, palette.parchmentMid],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? palette.cardBorder,
          width: 1.4,
        ),
        boxShadow: elevated
            ? AppElevation.hero(isDark: isDark)
            : AppElevation.card,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            // Ornament layers: never announced, never hit-tested.
            Positioned.fill(
              child: ExcludeSemantics(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: showWatermark
                        ? IslamicWatermarkPainter(
                            color: palette.watermark,
                            strokeWidth: 1.15,
                          )
                        : null,
                    // One ornament per corner: the gold brackets and the
                    // botanical branches occupy the same two corners, and
                    // together they read as clutter.
                    foregroundPainter: showCornerOrnaments && !showBotanicals
                        ? CornerOrnamentPainter(color: palette.cornerOrnament)
                        : null,
                  ),
                ),
              ),
            ),

            if (showBotanicals) ..._botanicals(isDark),

            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );

    if (onTap == null) return surface;

    return PressableSurface(
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: surface,
    );
  }

  List<Widget> _botanicals(bool isDark) {
    // Physical corners, not directional ones. Each branch is drawn for a
    // specific corner, so the composition is fixed: mirroring them under RTL
    // (which AlignmentDirectional does) put the top-right branch at top-left
    // and left the leaves growing the wrong way.
    const opacity = 0.55;

    Widget branch({
      required String asset,
      double? top,
      double? bottom,
      double? left,
      double? right,
    }) {
      return Positioned(
        top: top,
        bottom: bottom,
        left: left,
        right: right,
        child: ExcludeSemantics(
          child: IgnorePointer(
            child: Opacity(
              opacity: isDark ? opacity * 0.6 : opacity,
              child: AssetHelper.assetOrFallback(
                assetPath: 'assets/images/$asset.png',
                width: 86,
                height: 96,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      );
    }

    // Inset rather than bled past the edge: the card clips to a 24px radius,
    // and anchoring at the corner sheared the leaves off along a flat line.
    // A small inset lets each branch sit whole inside the rounded corner.
    const inset = 6.0;

    return [
      branch(asset: 'botanical_top_right', top: inset, right: inset),
      branch(asset: 'botanical_bottom_left', bottom: inset, left: inset),
    ];
  }
}
