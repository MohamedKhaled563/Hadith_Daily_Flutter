import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';

/// One bottom-sheet launcher for the app.
///
/// Both previous sheets hand-rolled a Container with a grab handle and
/// hardcoded their colours.
///
/// `useSafeArea` does not keep the bottom clear: Flutter's sheet wraps its
/// content in `SafeArea(bottom: false)`. The bottom is handled here, by
/// [sheetBottomGap], so a sheet's last button stays above the system
/// navigation bar (QA PT-017: «إرسال الاقتراح» was half hidden under it).
///
/// It is now actually botanical, which the name always claimed: the parchment
/// gradient and the gold rim the rest of the app uses, rather than a flat
/// `colorScheme.surface` rectangle. The app had three unrelated surface
/// languages — ParchmentCard everywhere, GlassPanel on the auth screens, and
/// this — so which one a reader got depended on where they happened to be.
/// Parchment is the one that carries the identity and was already everywhere,
/// so it wins.
Future<T?> showBotanicalSheet<T>({
  required BuildContext context,
  required String title,
  String? subtitle,
  required Widget child,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    // Keeps content clear of the status bar, any notch and the sides. Not the
    // bottom; see [sheetBottomGap].
    useSafeArea: true,
    builder: (sheetContext) {
      final palette = sheetContext.palette;
      final textTheme = Theme.of(sheetContext).textTheme;

      return Padding(
        // Lifts the sheet above the keyboard when it contains fields.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [palette.parchmentTop, palette.parchmentMid],
            ),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadii.sheet),
            ),
            // Uniform on purpose: Flutter refuses a per-side colour on a
            // border that also has a radius, and the sheet is top-rounded.
            // Same hairline the parchment cards carry, which is the point.
            border: Border.all(color: palette.cardBorder, width: 1.2),
          ),
          child: SingleChildScrollView(
            // The parchment still runs under the navigation bar; only the
            // content is lifted above it.
            padding: EdgeInsets.fromLTRB(
                24, 12, 24, sheetBottomGap(sheetContext, 24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Material's own showDragHandle would draw this, but it
                // paints on the sheet's background colour — which is
                // transparent here so the parchment can show through — so it
                // lands as a grab handle on nothing. Hand-drawn stays;
                // announcing it is what was actually missing.
                Semantics(
                  label: 'اسحب للإغلاق',
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: palette.cardBorderStrong,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 20),
                child,
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// The space under a bottom sheet's content: [gap], plus the system
/// navigation bar when the keyboard is closed.
///
/// `MediaQuery.paddingOf` is the bar's height less whatever the keyboard
/// already covers, so a sheet lifted by `viewInsets` does not get the bar's
/// height a second time.
double sheetBottomGap(BuildContext context, double gap) =>
    gap + MediaQuery.paddingOf(context).bottom;
