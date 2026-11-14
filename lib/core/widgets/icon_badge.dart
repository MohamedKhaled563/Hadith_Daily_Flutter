import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Which wash an [IconBadge] sits on, and which ink its icon takes.
enum BadgeTone { gold, green, warm, quiet }

/// A round, tinted badge for the icon that opens a card, a section or a
/// figure, so every card on a page starts with the same mark.
///
/// Decorative: it is never announced. The text beside it says what it is.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    this.icon,
    this.child,
    this.tone = BadgeTone.gold,
    this.size = 40,
    this.palette,
  }) : assert(icon != null || child != null);

  final IconData? icon;

  /// Drawn instead of [icon], for a mark that is not an icon (a leaf).
  final Widget? child;
  final BadgeTone tone;
  final double size;

  /// The colours to draw with, when not the theme's: a poster is always
  /// light, whatever mode the reader is in.
  final BotanicalPalette? palette;

  @override
  Widget build(BuildContext context) {
    final palette = this.palette ?? context.palette;
    final (wash, ink) = toneColors(palette, tone);

    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.alphaBlend(
                  palette.parchmentTop.withValues(alpha: .5), wash),
              wash,
            ],
          ),
          border: Border.all(
            color: tone == BadgeTone.quiet
                ? palette.cardBorder
                : ink.withValues(alpha: .32),
            width: 1.2,
          ),
        ),
        child: child ?? Icon(icon, size: size * .5, color: ink),
      ),
    );
  }

  /// The wash and the ink for [tone], for anything that should match a badge.
  static (Color, Color) toneColors(BotanicalPalette palette, BadgeTone tone) =>
      switch (tone) {
        BadgeTone.gold => (palette.goldWash, palette.goldText),
        BadgeTone.green => (palette.successWash, palette.success),
        BadgeTone.warm => (palette.warmWash, palette.warmText),
        BadgeTone.quiet => (palette.surfaceSunken, palette.mutedText),
      };
}

/// The small round "onward" mark at the end of a card that opens a page.
/// chevron_left is forward in a right-to-left app.
class ForwardChevron extends StatelessWidget {
  const ForwardChevron({super.key, this.emphasised = false});

  /// Gold, for the card the reader should open next.
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ExcludeSemantics(
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: emphasised ? palette.goldWash : palette.surfaceSunken,
          border: Border.all(
            color: emphasised
                ? palette.ornamentGold.withValues(alpha: .6)
                : palette.cardBorder,
          ),
        ),
        child: Icon(
          Icons.chevron_left_rounded,
          size: 20,
          color: emphasised ? palette.goldText : palette.mutedText,
        ),
      ),
    );
  }
}
