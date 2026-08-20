import 'package:flutter/material.dart';
import '../models/hadith.dart';
import '../theme/app_theme.dart';

class HadithCard extends StatelessWidget {
  final Hadith hadith;
  final bool compact;
  final bool showNumber;

  const HadithCard({
    super.key,
    required this.hadith,
    this.compact = false,
    this.showNumber = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, compact ? 22 : 26, 24, compact ? 22 : 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: isDark ? AppColors.darkCardGradient : AppColors.cardGradient,
        ),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.white,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.055),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  showNumber ? 'حديث رقم ${hadith.number}' : 'حديث اليوم',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.auto_awesome_outlined,
                size: 18,
                color: theme.colorScheme.secondary,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            hadith.title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            hadith.text,
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
            maxLines: compact ? 7 : null,
            overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
          ),
          if (hadith.source != null) ...[
            const SizedBox(height: 22),
            Center(
              child: Container(
                width: 46,
                height: 1,
                color: isDark ? Colors.white24 : AppColors.divider,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              hadith.source!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? AppColors.darkInk.withValues(alpha: 0.66) : AppColors.inkSoft,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
