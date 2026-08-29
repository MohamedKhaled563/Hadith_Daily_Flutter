import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import 'asset_helper.dart';
import 'tap_target.dart';

/// The app's standard 44×44 circular icon control — back arrows, menu,
/// bookmark toggles, copy/share actions in header rows.
///
/// Was copy-pasted privately into seven screens, and one copy had drifted to
/// 42×42, under the 44dp minimum every other copy enforces.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.toggled,
    this.iconColor,
    this.emphasised = false,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  /// Set for controls that flip between two states (bookmark, filter), so the
  /// state is announced rather than being conveyed by icon shape alone.
  final bool? toggled;
  final Color? iconColor;

  /// A slightly stronger border, for the one button per header that should
  /// read as the primary action (e.g. opening the drawer).
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return TapTarget(
      onTap: onTap,
      semanticLabel: semanticLabel,
      toggled: toggled,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: palette.surface,
          border: Border.all(
            color: emphasised ? palette.cardBorderStrong : palette.cardBorder,
            width: emphasised ? 1.4 : 1.2,
          ),
          boxShadow: AppElevation.card,
        ),
        child: Icon(icon, color: iconColor ?? palette.bodyText, size: 22),
      ),
    );
  }
}

/// The brand emblem badge used at the centre of most screen headers.
class EmblemBadge extends StatelessWidget {
  const EmblemBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: palette.surface,
        border: Border.all(color: palette.cardBorderStrong, width: 1.5),
        boxShadow: AppElevation.card,
      ),
      child: AssetHelper.assetOrFallback(
        assetPath: 'assets/images/heart_leaf_emblem.png',
        width: 36,
        height: 36,
        fallback: const Icon(
          Icons.favorite_rounded,
          color: AppColors.primaryGreen,
          size: 24,
        ),
      ),
    );
  }
}
