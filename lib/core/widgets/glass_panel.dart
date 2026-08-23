import 'dart:ui';

import 'package:flutter/material.dart';
import '../theme/app_palette.dart';

/// Frosted glass surface used by the auth screens.
///
/// Deliberately not a [ParchmentCard]: parchment, geometric watermark and
/// botanical branches are the app's language for *scripture*, and reusing them
/// on a credentials form gives it the same weight as a hadith. An opaque slab
/// also flattens the landscape it sits on.
///
/// Glass solves both — it blurs and lightens what is behind it instead of
/// hiding it, so the scene continues through the form. Three details keep it
/// from looking cheap:
///
///  * the fill is a vertical gradient, not a flat wash, so the surface has a
///    direction of light rather than sitting dead-on;
///  * the border is brighter along the top-left and fades toward the
///    bottom-right, which is how a real bevel catches light;
///  * a soft specular highlight sits just inside the top edge.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(22, 28, 22, 26),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final radius = BorderRadius.circular(32);

    // Tinted toward the app's cream rather than neutral white, so the glass
    // stays warm against the landscape. Kept light enough that the scene
    // genuinely reads through it — the blur, not the fill, is what protects
    // legibility.
    final tintTop = isDark
        ? const Color(0xFF1C2620).withValues(alpha: 0.58)
        : const Color(0xFFFDFBF6).withValues(alpha: 0.60);
    final tintBottom = isDark
        ? const Color(0xFF131A15).withValues(alpha: 0.46)
        : const Color(0xFFF6EFE2).withValues(alpha: 0.44);

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.50)
                : const Color(0xFF1B3322).withValues(alpha: 0.18),
            blurRadius: 44,
            offset: const Offset(0, 20),
            spreadRadius: -14,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          // Heavier blur compensates for the lighter fill: the scene stays
          // present as colour and shape without competing with the text.
          filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [tintTop, tintBottom],
              ),
              borderRadius: radius,
              border: GradientBoxBorder(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          Colors.white.withValues(alpha: 0.24),
                          Colors.white.withValues(alpha: 0.05),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.95),
                          const Color(0xFFD6BE88).withValues(alpha: 0.35),
                        ],
                ),
                width: 1.2,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 96,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(
                              alpha: isDark ? 0.07 : 0.42,
                            ),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(padding: padding, child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A [BoxBorder] that paints with a gradient. Flutter's [Border] only takes a
/// flat colour, which cannot describe a bevel catching light on one side.
class GradientBoxBorder extends BoxBorder {
  const GradientBoxBorder({required this.gradient, this.width = 1.0});

  final Gradient gradient;
  final double width;

  @override
  BorderSide get bottom => BorderSide.none;

  @override
  BorderSide get top => BorderSide.none;

  @override
  bool get isUniform => true;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    BoxShape shape = BoxShape.rectangle,
    BorderRadius? borderRadius,
    TextDirection? textDirection,
  }) {
    final paint = Paint()
      ..strokeWidth = width
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final inner = rect.deflate(width / 2);
    if (borderRadius != null) {
      canvas.drawRRect(borderRadius.toRRect(inner), paint);
    } else {
      canvas.drawRect(inner, paint);
    }
  }

  @override
  ShapeBorder scale(double t) =>
      GradientBoxBorder(gradient: gradient, width: width * t);
}

/// Translucent input shell for use inside a [GlassPanel]. An opaque field would
/// sit on the glass as a patch instead of belonging to it.
class GlassField extends StatelessWidget {
  const GlassField({
    super.key,
    required this.child,
    this.leading,
    this.trailing,
  });

  final Widget child;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsetsDirectional.only(start: 14, end: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.70),
          width: 1.1,
        ),
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 10)],
          Expanded(child: child),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
