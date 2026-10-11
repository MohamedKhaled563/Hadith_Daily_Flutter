import 'package:flutter/material.dart';

class AppColors {
  // Light Palette (Warm Paper & Deep Emerald & Brushed Gold)
  /// One step deeper than the old #F8F3EA, so the lighter parchment cards
  /// have a ground to stand on instead of sinking into it.
  static const background = Color(0xFFF1E9DA);
  static const card = Color(0xFFFFFDFC);
  static const secondaryCard = Color(0xFFF4EEE3);
  static const softCream = Color(0xFFFAF6EE);
  static const cardBorder = Color(0x66D1BE93);

  /// A real emerald rather than the old grey-olive #385240, which read as
  /// muted next to everything else. White on it is 6.44:1.
  static const primaryGreen = Color(0xFF1F6B4A);
  static const secondaryGreen = Color(0xFF5A7061);
  static const darkEmerald = Color(0xFF1E2E24);

  /// Ornamental gold — borders, rings, dividers, decorative icons.
  /// Never use for text on a light surface: 2.13:1 on parchment (WCAG AA needs 4.5:1).
  static const gold = Color(0xFFD9A521);
  static const goldLight = Color(0xFFF0D88E);
  static const goldBorder = Color(0xFFD6BE88);

  /// Text-safe gold for light surfaces — 5.18:1 on parchment #EFE8DC.
  static const goldText = Color(0xFF7A5B0E);

  /// Text-safe gold for dark surfaces — 7.59:1 on the dark parchment top.
  static const goldTextDark = Color(0xFFE6BE55);

  /// Warm accent, taken from the sunset in the home artwork. For likes,
  /// streaks and "new" badges only — never a second brand colour.
  /// 3.03:1 on [BotanicalPalette.warmWash], so it is for icons, not text.
  static const warm = Color(0xFFD2643A);

  static const primaryText = Color(0xFF26352C);

  /// Raised from #5A7061, which cleared AA on the scaffold ground (4.84:1) but
  /// failed on every parchment surface it actually landed on — 4.20:1 on card
  /// mid, 3.93:1 on card bottom. This clears AA on all of them: 5.18:1 at the
  /// worst (parchment bottom #E5DCCB), 6.95:1 on card #FFFDFC.
  static const secondaryText = Color(0xFF4A5D52);

  /// Raised from #9E9D97 (2.52:1). Clears AA on every surface it lands on:
  /// 5.41:1 on cream #FAF6EE, 4.79:1 on search #EFE8DC, 5.75:1 on card #FFFDFC.
  static const placeholder = Color(0xFF67655F);
  static const divider = Color(0x33D1BE93);

  // Dark Palette (Spiritual Midnight Olive / Obsidian Emerald & Brushed Brass)
  static const backgroundDark = Color(0xFF0F1813);
  static const cardDark = Color(0xFF1C2620);
  static const secondaryCardDark = Color(0xFF162019);
  static const softCreamDark = Color(0xFF223028);
  static const cardBorderDark = Color(0x40D1BE93);

  /// Clearer than the old dusty #6F9B7C: 6.03:1 on cardDark.
  static const primaryGreenDark = Color(0xFF4FB385);
  static const secondaryGreenDark = Color(0xFF9EBCAB);

  static const primaryTextDark = Color(0xFFF0EBE1);
  static const secondaryTextDark = Color(0xFFB5C0B8);
  static const dividerDark = Color(0x2BD1BE93);
}

/// Radii scale. One value per role, so the same concept never renders at five
/// different roundings across five files.
class AppRadii {
  static const listItem = 20.0;
  static const card = 24.0;
  static const sheet = 28.0;
  static const pill = 999.0;
}

/// Elevation scale. `card` is the resting list treatment; `hero` is the
/// three-layer parchment treatment (ambient ground, directional drop, gold rim).
class AppElevation {
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  static List<BoxShadow> hero({required bool isDark}) => [
        BoxShadow(
          color: isDark ? const Color(0x8C000000) : const Color(0x291B3322),
          blurRadius: 26,
          offset: const Offset(0, 10),
          spreadRadius: -2,
        ),
        BoxShadow(
          color: isDark ? const Color(0x40000000) : const Color(0x10000000),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color:
              const Color(0xFFD6BE88).withValues(alpha: isDark ? 0.12 : 0.25),
          blurRadius: 12,
          offset: const Offset(0, -1),
          spreadRadius: 0.5,
        ),
      ];
}
