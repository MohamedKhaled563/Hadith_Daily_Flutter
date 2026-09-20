import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../utils/app_motion.dart';
import '../theme/app_text_styles.dart';
import '../utils/arabic_numerals.dart';
import 'tap_target.dart';

/// The heart-and-count chip used wherever a reader can like something —
/// insights, community posts, both the feed card and the detail screen.
///
/// Was reimplemented identically in two screens; a like button on a third
/// screen used a visually unrelated pill for the same action.
class LikeCounter extends StatelessWidget {
  const LikeCounter({
    super.key,
    required this.likes,
    required this.isLiked,
    required this.onTap,
  });

  final int likes;
  final bool isLiked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    // Was a single #C73E3E in both themes on a hand-picked wash: 4.27:1 in
    // light and 2.92:1 in dark, both under AA for a 12.5px count. The danger
    // role carries a value per theme — 6.13:1 and 6.88:1 on its own wash.
    final liked = palette.danger;

    return TapTarget(
      onTap: () {
        AppHaptics.toggle();
        onTap();
      },
      semanticLabel: 'إعجاب — $likes إعجاباً',
      toggled: isLiked,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isLiked ? palette.dangerWash : palette.surface,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: isLiked ? liked.withValues(alpha: 0.6) : palette.cardBorder,
            width: 1.1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isLiked ? 1.2 : 1.0,
              duration: context.motion(const Duration(milliseconds: 160)),
              curve: Curves.easeOutBack,
              child: Icon(
                isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: 18,
                color: isLiked ? liked : palette.mutedText,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              toArabicDigits(likes),
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 12.5,
                height: AppLeading.chrome,
                fontWeight: FontWeight.w700,
                color: isLiked ? liked : palette.bodyText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
