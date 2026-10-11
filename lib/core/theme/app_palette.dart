import 'package:flutter/material.dart';

/// The botanical surface palette, delivered through [Theme] so that every
/// dependent rebuilds automatically when the theme changes.
///
/// This replaces the previous pattern of reading `AppStateController().isDarkMode`
/// imperatively inside `build()`, which left already-pushed routes rendering the
/// old palette after a theme toggle.
@immutable
class BotanicalPalette extends ThemeExtension<BotanicalPalette> {
  const BotanicalPalette({
    required this.parchmentTop,
    required this.parchmentMid,
    required this.parchmentBottom,
    required this.cardBorder,
    required this.cardBorderStrong,
    required this.surface,
    required this.surfaceSunken,
    required this.goldText,
    required this.bodyText,
    required this.mutedText,
    required this.ornamentGold,
    required this.watermark,
    required this.cornerOrnament,
    required this.success,
    required this.successWash,
    required this.warning,
    required this.warningWash,
    required this.danger,
    required this.dangerWash,
    required this.warm,
    required this.warmText,
    required this.warmWash,
  });

  /// Parchment card gradient, top → bottom.
  final Color parchmentTop;
  final Color parchmentMid;
  final Color parchmentBottom;

  final Color cardBorder;
  final Color cardBorderStrong;

  /// Raised chrome: pills, circular icon buttons, inputs.
  final Color surface;

  /// Recessed chrome: search fields, segmented backgrounds.
  final Color surfaceSunken;

  /// Gold that is safe to read. See [AppColors.gold] for the ornamental one.
  final Color goldText;

  final Color bodyText;
  final Color mutedText;

  /// Ornamental gold — rings, dividers, decorative icons. Never text.
  final Color ornamentGold;

  final Color watermark;
  final Color cornerOrnament;

  /// Semantic roles. The app had none: success, failure and "in review" were
  /// all either the brand green or a literal buried in one widget, which is
  /// why a failed like arrived on the same green snackbar as a successful
  /// copy. Each `*Wash` is the tinted surface its partner is legible on —
  /// every pair clears WCAG AA in both themes.
  final Color success;
  final Color successWash;
  final Color warning;
  final Color warningWash;
  final Color danger;
  final Color dangerWash;

  /// The sunset accent: likes, streaks, "new" badges. [warm] is for icons
  /// and fills (3:1 on every surface), [warmText] for text on [warmWash].
  final Color warm;
  final Color warmText;
  final Color warmWash;

  static const light = BotanicalPalette(
    // Lighter than the page now (L* 99 → 95 over a 93 ground). The old card
    // was darker than the scaffold, so it read as sunk rather than raised.
    parchmentTop: Color(0xFFFFFCF5),
    parchmentMid: Color(0xFFFAF4E8),
    parchmentBottom: Color(0xFFF6EDDC),
    cardBorder: Color(0x9ED9A521),
    cardBorderStrong: Color(0xFFD9B45A),
    surface: Color(0xFFFAF6EE),
    surfaceSunken: Color(0xFFEFE8DC),
    goldText: Color(0xFF7A5B0E),
    bodyText: Color(0xFF243329),
    mutedText: Color(0xFF4A5D52),
    ornamentGold: Color(0xFFD9A521),
    watermark: Color(0x1CB89F70),
    cornerOrnament: Color(0x77B89F70),
    success: Color(0xFF1F6B43),
    successWash: Color(0xFFDCE9DD),
    warning: Color(0xFF7A5411),
    warningWash: Color(0xFFF0E4C8),
    danger: Color(0xFF96291F),
    dangerWash: Color(0xFFF3DDD7),
    warm: Color(0xFFD2643A),
    warmText: Color(0xFFA9481F),
    warmWash: Color(0xFFFBE3D3),
  );

  static const dark = BotanicalPalette(
    parchmentTop: Color(0xFF1F3328),
    parchmentMid: Color(0xFF192B21),
    parchmentBottom: Color(0xFF14231A),
    cardBorder: Color(0x80E6BE55),
    cardBorderStrong: Color(0xFFE6BE55),
    surface: Color(0xFF1C2620),
    surfaceSunken: Color(0xFF1E2D23),
    goldText: Color(0xFFE6BE55),
    bodyText: Color(0xFFF7F5EE),
    mutedText: Color(0xFFB9C6BD),
    ornamentGold: Color(0xFFE6BE55),
    watermark: Color(0x18D1BE93),
    cornerOrnament: Color(0x55D1BE93),
    success: Color(0xFF8FD3AB),
    successWash: Color(0xFF1F3329),
    warning: Color(0xFFE8C173),
    warningWash: Color(0xFF35301C),
    danger: Color(0xFFF2948B),
    dangerWash: Color(0xFF351F1C),
    warm: Color(0xFFF0A07A),
    warmText: Color(0xFFF0A07A),
    warmWash: Color(0xFF3A2A20),
  );

  /// Convenience accessor so call sites read as
  /// `context.palette.bodyText` rather than the full extension lookup.
  static BotanicalPalette of(BuildContext context) =>
      Theme.of(context).extension<BotanicalPalette>() ?? light;

  @override
  BotanicalPalette copyWith({
    Color? parchmentTop,
    Color? parchmentMid,
    Color? parchmentBottom,
    Color? cardBorder,
    Color? cardBorderStrong,
    Color? surface,
    Color? surfaceSunken,
    Color? goldText,
    Color? bodyText,
    Color? mutedText,
    Color? ornamentGold,
    Color? watermark,
    Color? cornerOrnament,
    Color? success,
    Color? successWash,
    Color? warning,
    Color? warningWash,
    Color? danger,
    Color? dangerWash,
    Color? warm,
    Color? warmText,
    Color? warmWash,
  }) {
    return BotanicalPalette(
      parchmentTop: parchmentTop ?? this.parchmentTop,
      parchmentMid: parchmentMid ?? this.parchmentMid,
      parchmentBottom: parchmentBottom ?? this.parchmentBottom,
      cardBorder: cardBorder ?? this.cardBorder,
      cardBorderStrong: cardBorderStrong ?? this.cardBorderStrong,
      surface: surface ?? this.surface,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      goldText: goldText ?? this.goldText,
      bodyText: bodyText ?? this.bodyText,
      mutedText: mutedText ?? this.mutedText,
      ornamentGold: ornamentGold ?? this.ornamentGold,
      watermark: watermark ?? this.watermark,
      cornerOrnament: cornerOrnament ?? this.cornerOrnament,
      success: success ?? this.success,
      successWash: successWash ?? this.successWash,
      warning: warning ?? this.warning,
      warningWash: warningWash ?? this.warningWash,
      danger: danger ?? this.danger,
      dangerWash: dangerWash ?? this.dangerWash,
      warm: warm ?? this.warm,
      warmText: warmText ?? this.warmText,
      warmWash: warmWash ?? this.warmWash,
    );
  }

  @override
  BotanicalPalette lerp(BotanicalPalette? other, double t) {
    if (other == null) return this;
    return BotanicalPalette(
      parchmentTop: Color.lerp(parchmentTop, other.parchmentTop, t)!,
      parchmentMid: Color.lerp(parchmentMid, other.parchmentMid, t)!,
      parchmentBottom: Color.lerp(parchmentBottom, other.parchmentBottom, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      cardBorderStrong:
          Color.lerp(cardBorderStrong, other.cardBorderStrong, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      goldText: Color.lerp(goldText, other.goldText, t)!,
      bodyText: Color.lerp(bodyText, other.bodyText, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      ornamentGold: Color.lerp(ornamentGold, other.ornamentGold, t)!,
      watermark: Color.lerp(watermark, other.watermark, t)!,
      cornerOrnament: Color.lerp(cornerOrnament, other.cornerOrnament, t)!,
      success: Color.lerp(success, other.success, t)!,
      successWash: Color.lerp(successWash, other.successWash, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningWash: Color.lerp(warningWash, other.warningWash, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerWash: Color.lerp(dangerWash, other.dangerWash, t)!,
      warm: Color.lerp(warm, other.warm, t)!,
      warmText: Color.lerp(warmText, other.warmText, t)!,
      warmWash: Color.lerp(warmWash, other.warmWash, t)!,
    );
  }
}

extension BotanicalPaletteContext on BuildContext {
  BotanicalPalette get palette => BotanicalPalette.of(this);

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
