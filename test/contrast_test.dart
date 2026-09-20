import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hadith_app/core/theme/app_colors.dart';
import 'package:hadith_app/core/theme/app_palette.dart';
import 'package:hadith_app/core/theme/app_theme.dart';

/// Guards the colour pairs an audit found below WCAG AA.
///
/// The tokens that already carried a documented ratio in their doc comment all
/// passed; the ones that failed were the ones nobody had measured, and every
/// dark-mode failure was a light-mode value carried across unchanged. These
/// assertions exist so that stays fixed — a token nudged for looks that drops
/// a pair under 4.5:1 fails here rather than shipping.

/// WCAG 2.1 relative luminance.
double _luminance(Color c) {
  double channel(double v) {
    v = v; // already 0..1 in Flutter's component accessors
    return v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG 2.1 contrast ratio. Both colours must be opaque.
double contrast(Color fg, Color bg) {
  final a = _luminance(fg);
  final b = _luminance(bg);
  final hi = math.max(a, b);
  final lo = math.min(a, b);
  return (hi + 0.05) / (lo + 0.05);
}

/// Composites [fg] at its own alpha over an opaque [bg].
Color flatten(Color fg, Color bg) {
  final a = fg.a;
  return Color.fromARGB(
    255,
    ((fg.r * a + bg.r * (1 - a)) * 255).round(),
    ((fg.g * a + bg.g * (1 - a)) * 255).round(),
    ((fg.b * a + bg.b * (1 - a)) * 255).round(),
  );
}

/// AA for body text at the sizes this app uses (13–20px, under 18.66px bold).
const _aa = 4.5;

void expectAA(String what, Color fg, Color bg) {
  final ratio = contrast(fg, bg);
  expect(
    ratio,
    greaterThanOrEqualTo(_aa),
    reason: '$what is ${ratio.toStringAsFixed(2)}:1, needs $_aa:1',
  );
}

void main() {
  group('muted text clears AA on every surface it lands on', () {
    // Was #5A7061: fine on the scaffold ground (4.84:1), but 4.20:1 on the
    // card mid stop and 3.93:1 on the card bottom — and it is the colour of
    // every caption, card subtitle and hadith preview line in the app.
    const lightSurfaces = <String, Color>{
      'parchmentTop': Color(0xFFF2ECE0),
      'parchmentMid': Color(0xFFEBE3D4),
      'parchmentBottom': Color(0xFFE5DCCB),
      'surface': Color(0xFFFAF6EE),
      'surfaceSunken': Color(0xFFEFE8DC),
      'scaffold': AppColors.background,
      'card': AppColors.card,
    };

    lightSurfaces.forEach((name, bg) {
      test('light · on $name', () {
        expectAA('mutedText on $name', BotanicalPalette.light.mutedText, bg);
      });
    });

    const darkSurfaces = <String, Color>{
      'parchmentTop': Color(0xFF24362B),
      'parchmentMid': Color(0xFF1B2A20),
      'parchmentBottom': Color(0xFF152219),
      'surface': Color(0xFF1C2620),
      'surfaceSunken': Color(0xFF1E2D23),
      'scaffold': AppColors.backgroundDark,
    };

    darkSurfaces.forEach((name, bg) {
      test('dark · on $name', () {
        expectAA('mutedText on $name', BotanicalPalette.dark.mutedText, bg);
      });
    });
  });

  group('semantic roles are legible on their own wash', () {
    for (final entry in {
      'light': BotanicalPalette.light,
      'dark': BotanicalPalette.dark,
    }.entries) {
      final mode = entry.key;
      final p = entry.value;

      test('$mode · success', () => expectAA('success', p.success, p.successWash));
      test('$mode · warning', () => expectAA('warning', p.warning, p.warningWash));
      test('$mode · danger', () => expectAA('danger', p.danger, p.dangerWash));
    }
  });

  group('primary button ink', () {
    // White on primaryGreenDark was 3.16:1 — every primary call to action in
    // the app, in dark mode. The scheme already declared the right answer.
    test('light', () {
      final scheme = AppTheme.light.colorScheme;
      expectAA('onPrimary on primary', scheme.onPrimary, scheme.primary);
    });

    test('dark', () {
      final scheme = AppTheme.dark.colorScheme;
      expectAA('onPrimary on primary', scheme.onPrimary, scheme.primary);
    });
  });

  group('gold text stays readable', () {
    test('light · on parchment bottom', () {
      expectAA(
        'goldText',
        BotanicalPalette.light.goldText,
        const Color(0xFFE5DCCB),
      );
    });

    test('dark · on parchment top', () {
      expectAA(
        'goldText',
        BotanicalPalette.dark.goldText,
        const Color(0xFF24362B),
      );
    });
  });

  group('body text stays readable', () {
    test('light', () {
      expectAA(
        'bodyText',
        BotanicalPalette.light.bodyText,
        const Color(0xFFE5DCCB),
      );
    });

    test('dark', () {
      expectAA(
        'bodyText',
        BotanicalPalette.dark.bodyText,
        const Color(0xFF152219),
      );
    });
  });

  group('splash quote chip, composited over the ground behind it', () {
    // The chip is a translucent surface, so what matters is the colour it
    // actually resolves to. In dark mode it used to be a cream panel with
    // dark green text dropped unchanged onto a night scene: 4.07:1.

    // 99th-percentile luminance of the two grounds the chip can sit on, taken
    // from the shipped artwork (see tool/make_night_backgrounds.py).
    const nightGround = Color(0xFF232B1D);
    const dayGround = Color(0xFFF4EFE6);

    test('light', () {
      final chip = flatten(
        BotanicalPalette.light.surface.withValues(alpha: 0.92),
        dayGround,
      );
      expectAA('quote text on chip', BotanicalPalette.light.bodyText, chip);
    });

    test('dark', () {
      final chip = flatten(
        BotanicalPalette.dark.surface.withValues(alpha: 0.92),
        nightGround,
      );
      expectAA('quote text on chip', BotanicalPalette.dark.bodyText, chip);
    });
  });

  test('flatten composites alpha the way the renderer does', () {
    // Sanity check on the helper itself, so a broken helper cannot make the
    // assertions above pass vacuously. 0x80 is 128/255, so black at that alpha
    // over white lands on 127 — one below the midpoint, not on it.
    expect(
      flatten(const Color(0x80000000), const Color(0xFFFFFFFF)),
      const Color(0xFF7F7F7F),
    );
  });
}
