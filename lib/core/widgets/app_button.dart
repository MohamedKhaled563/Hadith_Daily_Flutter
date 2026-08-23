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
  final VoidCallback onPressed;
  final bool isSecondary;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final green = context.isDarkMode
        ? AppColors.primaryGreenDark
        : AppColors.primaryGreen;

    final button = ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSecondary ? palette.surface : green,
        foregroundColor: isSecondary ? green : Colors.white,
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
