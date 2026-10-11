import 'dart:math' as math;

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
class LikeCounter extends StatefulWidget {
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
  State<LikeCounter> createState() => _LikeCounterState();
}

class _LikeCounterState extends State<LikeCounter>
    with SingleTickerProviderStateMixin {
  /// Drives the pop and the burst together. Only runs on the tap that turns
  /// a like *on* — un-liking is a quiet state change, not a celebration.
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  void _handleTap() {
    AppHaptics.toggle();
    if (!widget.isLiked && !context.reduceMotion) _pop.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    // The sunset accent rather than the danger red: a like is warmth, not an
    // error. The icon takes [warm] (3:1 on the wash, the graphics threshold);
    // the 12.5px count takes [warmText], which clears 4.5:1 on the wash.
    final likedIcon = palette.warm;
    final likedText = palette.warmText;

    return TapTarget(
      onTap: _handleTap,
      semanticLabel: 'إعجاب — ${widget.likes} إعجاباً',
      toggled: widget.isLiked,
      child: AnimatedContainer(
        duration: context.motion(AppDurations.control),
        curve: AppDurations.curve,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: widget.isLiked ? palette.warmWash : palette.surface,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: widget.isLiked
                ? likedIcon.withValues(alpha: 0.6)
                : palette.cardBorder,
            width: 1.1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pop,
              builder: (context, child) {
                final t = _pop.value;
                // 1 → 1.35 → 1 with a little overshoot on the way back.
                final scale = _pop.isAnimating
                    ? 1 +
                        0.35 *
                            math.sin(math.pi *
                                Curves.easeOut.transform(t.clamp(0.0, 1.0)))
                    : 1.0;
                return CustomPaint(
                  painter: _BurstPainter(progress: t, color: likedIcon),
                  child: Transform.scale(scale: scale, child: child),
                );
              },
              child: Icon(
                widget.isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: 18,
                color: widget.isLiked ? likedIcon : palette.mutedText,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              toArabicDigits(widget.likes),
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 12.5,
                height: AppLeading.chrome,
                fontWeight: FontWeight.w700,
                color: widget.isLiked ? likedText : palette.bodyText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Eight dots that fly out of the heart and fade. Painted outside the icon's
/// box on purpose — the pill does not clip, so the burst can overlap it.
class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final t = Curves.easeOut.transform(progress);
    final center = size.center(Offset.zero);
    final paint = Paint()..color = color.withValues(alpha: 1 - progress);
    final distance = 6 + 14 * t;
    final radius = 2.4 * (1 - t * 0.6);
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * distance,
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) =>
      old.progress != progress || old.color != color;
}
