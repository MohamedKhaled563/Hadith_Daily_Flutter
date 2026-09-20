import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_text_styles.dart';
import '../utils/app_motion.dart';

/// What a message is telling the reader.
enum SnackTone {
  /// Something worked: saved, copied, sent.
  success,

  /// Something needs their attention but nothing broke.
  warning,

  /// Something failed.
  danger,

  /// Plain information with no outcome attached.
  neutral,
}

/// One way to show a transient message, with its tone carried in its colour.
///
/// Every snackbar in the app used to come out of `snackBarTheme`, which is a
/// single background colour — the brand green in light mode. So
/// «تم نسخ نص الرسالة بنجاح» and «تعذّر تسجيل الإعجاب، حاول مجدداً» arrived on
/// identical green surfaces, and a failure looked exactly like a success. The
/// semantic roles to fix that already exist on [BotanicalPalette]; this is
/// what puts them to use.
///
/// Prefer this over `ScaffoldMessenger.of(context).showSnackBar` directly.
void showAppSnack(
  BuildContext context,
  String message, {
  SnackTone tone = SnackTone.neutral,

  /// An action the reader can take about what just happened — most usefully
  /// an undo for something that removed their content.
  SnackBarAction? action,
  Duration? duration,
}) {
  final palette = context.palette;

  final (Color background, Color foreground, IconData? icon) = switch (tone) {
    SnackTone.success => (
        palette.successWash,
        palette.success,
        Icons.check_circle_outline_rounded,
      ),
    SnackTone.warning => (
        palette.warningWash,
        palette.warning,
        Icons.error_outline_rounded,
      ),
    SnackTone.danger => (
        palette.dangerWash,
        palette.danger,
        Icons.cancel_outlined,
      ),
    SnackTone.neutral => (palette.surface, palette.bodyText, null),
  };

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: background,
        duration: duration ?? const Duration(seconds: 3),
        // Overrides the theme's own shape/behaviour so a toned snack can't
        // half-inherit the old green one.
        behavior: SnackBarBehavior.floating,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.listItem),
          side: BorderSide(
            color: tone == SnackTone.neutral
                ? palette.cardBorder
                : foreground.withValues(alpha: 0.35),
          ),
        ),
        action: action,
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 14,
                  height: AppLeading.body,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}

/// An undo action in the app's own colours.
///
/// Removing a bookmark used to fire a one-second snackbar with nothing on it:
/// the item was gone and the only way back was to find it again.
SnackBarAction undoAction(BuildContext context, VoidCallback onUndo) {
  return SnackBarAction(
    label: 'تراجع',
    textColor: context.palette.goldText,
    onPressed: () {
      AppHaptics.toggle();
      onUndo();
    },
  );
}
