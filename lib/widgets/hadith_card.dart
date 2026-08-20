import 'package:flutter/material.dart';
import '../models/hadith.dart';
import '../theme/app_theme.dart';

/// The main content card shown on Home and used as the shareable image.
/// Wrap this in a RepaintBoundary where you need to capture it as a PNG.
class HadithCard extends StatelessWidget {
  final Hadith hadith;
  final bool compact;

  const HadithCard({
    super.key,
    required this.hadith,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: compact ? 28 : 36,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: isDark
              ? [AppColors.darkSurface, AppColors.darkBackground]
              : AppColors.cardGradient,
        ),
        border: Border.all(
          color: isDark ? Colors.white10 : AppColors.divider,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // small ornamental mark instead of a generic quote icon
          Icon(
            Icons.auto_awesome,
            size: 20,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(height: 18),
          Text(
            hadith.title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            hadith.text,
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
            maxLines: compact ? 8 : null,
            overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
          ),
          if (hadith.source != null) ...[
            const SizedBox(height: 22),
            Container(height: 1, width: 48, color: theme.dividerColor),
            const SizedBox(height: 14),
            Text(
              hadith.source!,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
