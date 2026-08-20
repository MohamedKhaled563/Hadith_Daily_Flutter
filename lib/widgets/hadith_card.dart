import 'package:flutter/material.dart';
import '../../models/hadith.dart';
import '../theme/app_theme.dart';

/// Visual match for the reference mockup's card:
/// - soft cream-to-mint gradient, generous rounded corners
/// - small quote-mark glyph top-center
/// - hadith text, bold, centered
/// - thin divider + "من حديث: <short label>" footer line
/// - small heart glyph at the very bottom (decorative, not the action button)
class HadithCard extends StatelessWidget {
  final Hadith hadith;
  final bool compact;

  const HadithCard({super.key, required this.hadith, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 26, vertical: compact ? 30 : 40),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [AppColors.darkCard, AppColors.darkBackground]
              : [AppColors.cardTop, AppColors.cardBottom],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '”',
            style: TextStyle(
              fontSize: 46,
              height: 0.4,
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.primary.withOpacity(0.35),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            hadith.text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
            maxLines: compact ? 7 : null,
            overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
          ),
          const SizedBox(height: 22),
          if (hadith.source != null || hadith.title.isNotEmpty) ...[
            Container(
              width: 40,
              height: 1.2,
              color: theme.dividerColor,
            ),
            const SizedBox(height: 12),
            Text(
              'من حديث: ${_shortLabel(hadith)}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
          ],
          Icon(Icons.favorite, size: 16, color: AppColors.heart.withOpacity(0.7)),
        ],
      ),
    );
  }

  /// A short, one-line label for the footer — first few words of the
  /// hadith text, matching the reference's "من حديث: إنما الأعمال بالنيات" style.
  String _shortLabel(Hadith hadith) {
    final words = hadith.text.replaceAll('"', '').split(' ');
    final short = words.take(5).join(' ');
    return words.length > 5 ? '$short...' : short;
  }
}
