import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import 'glass_panel.dart';
import 'islamic_pattern_painter.dart';
import 'tap_target.dart';

/// The one card that stands apart from the rest: the weekly board.
///
/// A certificate under a double gold frame, with a gold glow. In dark mode
/// it is deep emerald, and what sits inside is drawn with the dark palette.
/// In light mode it is warm gold leaf, drawn with the light palette, so it
/// still stands apart from the glass cards without a dark slab on a light
/// page.
class HonorCard extends StatelessWidget {
  const HonorCard({
    super.key,
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final EdgeInsetsGeometry padding;

  /// The theme everything on the card is drawn with, built once.
  static final ThemeData _inside = AppTheme.dark;

  /// The emerald, lit from the top left.
  static const _top = Color(0xFF2A4A37);
  static const _bottom = Color(0xFF13211A);

  /// The gold leaf of light mode, lit from the top left. Public so
  /// contrast_test can hold the text on it to AA.
  static const lightColors = [
    Color(0xFFFFFAEB),
    Color(0xFFF8EBC4),
    Color(0xFFF2DFAA),
  ];

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(AppRadii.card);
    final dark = Theme.of(context).brightness == Brightness.dark;

    final surface = CustomPaint(
      painter: OutsideShadowPainter(
        borderRadius: shape,
        shadows: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: dark ? .30 : .38),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Color(dark ? 0x401B3322 : 0x26574008),
            blurRadius: 22,
            offset: const Offset(0, 10),
            spreadRadius: -4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? const [_top, AppColors.darkEmerald, _bottom]
                  : lightColors,
            ),
            borderRadius: shape,
            border: const GradientBoxBorder(
              width: 1.6,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.goldLight,
                  AppColors.gold,
                  Color(0xFF9C7618),
                ],
              ),
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ExcludeSemantics(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: IslamicWatermarkPainter(
                        color: AppColors.gold.withValues(
                          alpha: dark ? .12 : .16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // A second, finer frame just inside the first.
              Positioned.fill(
                child: IgnorePointer(
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadii.card - 5),
                        border: Border.all(
                          color: AppColors.gold.withValues(
                            alpha: dark ? .28 : .5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 56,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          dark
                              ? AppColors.goldLight.withValues(alpha: .12)
                              : AppColors.card.withValues(alpha: .6),
                          AppColors.goldLight.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: padding,
                child: dark ? Theme(data: _inside, child: child) : child,
              ),
            ],
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
}

/// A gold medal with a dark mark on it: the board's badge.
class HonorMedal extends StatelessWidget {
  const HonorMedal({super.key, required this.icon, this.size = 46});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            center: Alignment(-.35, -.45),
            colors: [AppColors.goldLight, AppColors.gold, Color(0xFFB0841A)],
            stops: [0, .6, 1],
          ),
          border: Border.all(color: const Color(0xFF8A6713), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: .45),
              blurRadius: 12,
            ),
          ],
        ),
        child: Icon(icon, size: size * .52, color: AppColors.darkEmerald),
      ),
    );
  }
}

/// The board's own button: gold, filled, unlike every outlined button
/// elsewhere, because sharing the board is the one thing it invites.
class HonorButton extends StatelessWidget {
  const HonorButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TapTarget(
      onTap: onTap,
      semanticLabel: label,
      pressScale: AppPress.cardScale,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.goldLight, AppColors.gold],
          ),
          border: Border.all(color: const Color(0xFF9C7618), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: .40),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: AppColors.darkEmerald),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: kSans,
                  fontSize: 15.5,
                  height: AppLeading.chrome,
                  fontWeight: FontWeight.w800,
                  color: AppColors.darkEmerald,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
