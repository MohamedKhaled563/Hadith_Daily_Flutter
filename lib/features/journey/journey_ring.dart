import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_motion.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/widgets/tap_target.dart';
import '../../data/journey/journey_repository.dart';

/// The day's steps at a glance on the home header: how many of the three
/// are done, counted in the middle and filled round the ring. Sits outside
/// the message on purpose. The message itself carries no counter, so
/// reading it stays a quiet moment; this is where progress lives. Tapping it
/// opens the day's steps.
class JourneyRing extends StatelessWidget {
  const JourneyRing({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final repo = JourneyRepository();

    return AnimatedBuilder(
      animation: repo.listenable,
      builder: (context, _) {
        final done = repo.todaySteps.done;
        return TapTarget(
          onTap: onTap,
          semanticLabel: StepsRing.describe(done),
          child: StepsRing(done: done),
        );
      },
    );
  }
}

/// A ring of three arcs for the day's three steps. Done steps fill it in
/// gold, one arc after another, with the count in the middle; all three
/// turn it green. The count, not which step: a reader asks "how far am I
/// today", and the page behind it says which.
class StepsRing extends StatelessWidget {
  const StepsRing({super.key, required this.done, this.size = 44});

  /// Steps done today, 0 to 3.
  final int done;
  final double size;

  static const total = 3;

  /// What a screen reader says for the ring.
  static String describe(int done) =>
      '${toArabicDigits(done)} من ٣ خطوات اليوم';

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dark = context.isDarkMode;
    final green = dark ? AppColors.primaryGreenDark : AppColors.primaryGreen;
    final complete = done >= total;
    final stroke = math.max(4.0, size * .1);

    // Its own size whatever the parent offers: a list or a stretched column
    // would otherwise pull the circle into an oval.
    return ExcludeSemantics(
      child: Align(
        widthFactor: 1,
        heightFactor: 1,
        child: SizedBox.square(
          dimension: size,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: done.clamp(0, total).toDouble()),
            duration: context.motion(const Duration(milliseconds: 700)),
            curve: Curves.easeOutCubic,
            builder: (context, progress, _) => CustomPaint(
              size: Size.square(size),
              painter: _RingPainter(
                progress: progress,
                stroke: stroke,
                track: palette.surfaceSunken,
                ground: complete
                    ? Color.alphaBlend(
                        green.withValues(alpha: dark ? .22 : .12),
                        palette.surface,
                      )
                    : palette.surface,
                goldFrom: dark ? AppColors.gold : AppColors.goldLight,
                goldTo: dark ? AppColors.goldLight : AppColors.gold,
                green: green,
              ),
              child: SizedBox.square(
                dimension: size,
                child: Center(
                  // The Arabic zero is a dot, which reads as a speck here, so a
                  // day with nothing done yet shows a leaf instead.
                  child: done == 0
                      ? Icon(
                          Icons.eco_rounded,
                          size: size * .4,
                          color: palette.ornamentGold,
                        )
                      : Text(
                          toArabicDigits(done.clamp(0, total)),
                          maxLines: 1,
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontFamily: kSans,
                            fontSize: size * .34,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            color: complete ? green : palette.goldText,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.stroke,
    required this.track,
    required this.ground,
    required this.goldFrom,
    required this.goldTo,
    required this.green,
  });

  /// Steps done, eased: 1.5 is the first arc full and the second half way.
  final double progress;
  final double stroke;
  final Color track;
  final Color ground;
  final Color goldFrom;
  final Color goldTo;
  final Color green;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = .3;
    const sweep = 2 * math.pi / StepsRing.total;

    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - stroke / 2;
    canvas.drawCircle(centre, radius, Paint()..color = ground);

    final rect = Rect.fromCircle(center: centre, radius: radius);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    // Gold while the day is under way, deepening round the ring; green,
    // blended in over the last step, once it is whole.
    final greenness = (progress - (StepsRing.total - 1)).clamp(0.0, 1.0);
    final fill = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: 3 * math.pi / 2,
      colors: [
        Color.lerp(goldFrom, green, greenness)!,
        Color.lerp(goldTo, green, greenness)!,
      ],
      transform: const GradientRotation(-math.pi / 2),
    ).createShader(rect);

    for (var i = 0; i < StepsRing.total; i++) {
      final start = -math.pi / 2 + i * sweep + gap / 2;
      const length = sweep - gap;
      canvas.drawArc(rect, start, length, false, line..color = track);
      final filled = (progress - i).clamp(0.0, 1.0);
      if (filled > 0) {
        canvas.drawArc(
          rect,
          start,
          length * filled,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = stroke
            ..shader = fill,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.stroke != stroke ||
      oldDelegate.track != track ||
      oldDelegate.ground != ground ||
      oldDelegate.goldFrom != goldFrom ||
      oldDelegate.goldTo != goldTo ||
      oldDelegate.green != green;
}
