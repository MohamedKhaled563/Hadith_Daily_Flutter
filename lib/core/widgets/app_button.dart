import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_text_styles.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isSecondary = false,
    this.icon,
    this.expand = true,
  });

  final String text;

  /// Nullable on purpose. It used to be non-null, so a screen with no way to
  /// say "disabled" passed `() {}` while submitting — the button stayed fully
  /// lit and simply did nothing when tapped. Passing null lets
  /// [ElevatedButton] render its own disabled state, which is the whole
  /// point of the control.
  final VoidCallback? onPressed;
  final bool isSecondary;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final green = context.isDarkMode
        ? AppColors.primaryGreenDark
        : AppColors.primaryGreen;

    // The ink on a filled button comes from the scheme, not a white literal.
    // In dark mode the fill is the pale sage #6F9B7C, and white on it is
    // 3.16:1 — under AA, on every primary call to action in the app. The
    // scheme already declares the right answer (onPrimary is backgroundDark
    // there, 5.61:1); this just stops ignoring it.
    final button = ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSecondary ? palette.surface : green,
        foregroundColor: isSecondary ? green : scheme.onPrimary,
        elevation: 0,
        // 54 tall, comfortably above the 48dp minimum target.
        minimumSize: Size(expand ? double.infinity : 0, 54),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        textStyle: AppTextStyles.buttonText,
        shape: StadiumBorder(
          side: isSecondary
              ? BorderSide(color: green, width: 1)
              : BorderSide.none,
        ),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
