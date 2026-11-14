import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import 'asset_helper.dart';
import 'glass_panel.dart';
import 'islamic_pattern_painter.dart';
import 'tap_target.dart';

/// The app's one card surface: parchment, as frosted glass.
///
/// Replaces four near-identical implementations that had drifted to five
/// different corner radii and four different shadow recipes. All colour comes
/// from [BotanicalPalette], so it repaints correctly on a theme change. How
/// see-through it is lives in [GlassFill], where contrast_test can hold it.
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
    final shape = BorderRadius.circular(AppRadii.card);
    final top = isDark ? GlassFill.darkTop : GlassFill.lightTop;
    final bottom = isDark ? GlassFill.darkBottom : GlassFill.lightBottom;

    // Parchment, turned to frosted glass: the scene behind shows through as
    // a soft wash of colour, the edge catches the light along the top, and
    // the shadow stays outside, where it cannot cloud the fill.
    final surface = CustomPaint(
      painter: OutsideShadowPainter(
        shadows:
            elevated ? AppElevation.hero(isDark: isDark) : AppElevation.card,
        borderRadius: shape,
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: Frost(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: elevated
                    ? [
                        palette.parchmentTop.withValues(alpha: top),
                        palette.parchmentMid.withValues(alpha: bottom + .02),
                        palette.parchmentBottom.withValues(alpha: bottom),
                      ]
                    : [
                        palette.parchmentTop.withValues(alpha: top),
                        palette.parchmentMid.withValues(alpha: bottom),
                      ],
              ),
              borderRadius: shape,
              border: GradientBoxBorder(
                gradient: borderColor == null
                    ? glassEdge(context, strong: elevated)
                    : glassEdgeIn(borderColor!),
                width: borderColor == null ? 1.3 : 1.6,
              ),
            ),
            child: _layers(context, palette, isDark),
          ),
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

  Widget _layers(BuildContext context, BotanicalPalette palette, bool isDark) {
    return Stack(
      children: [
        // The light on the glass: a soft sheen just inside the top edge.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 64,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    palette.parchmentTop.withValues(alpha: isDark ? .10 : .55),
                    palette.parchmentTop.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
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
