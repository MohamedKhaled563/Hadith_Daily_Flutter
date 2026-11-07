import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/widgets/tap_target.dart';
import '../../data/journey/journey_engine.dart';
import '../../data/journey/journey_repository.dart';

/// The day at a glance on the home header: three arcs for the day's three
/// steps — the message, its hadith, and writing one's own — around the
/// streak. Sits outside the message on purpose. The message itself carries no
/// counter, so reading it stays a quiet moment; this is where progress lives.
class JourneyRing extends StatelessWidget {
  const JourneyRing({super.key, required this.onTap});

  final VoidCallback onTap;

  static const _size = 44.0;

  String _describe(DaySteps steps, int streak) =>
      'رحلتي: ${toArabicDigits(steps.done)} من ٣ خطوات اليوم، '
      'السلسلة ${toArabicDigits(streak)}';

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final repo = JourneyRepository();

    return AnimatedBuilder(
      animation: repo.listenable,
      builder: (context, _) {
        final steps = repo.todaySteps;
        final streak = repo.streak.current;

        return TapTarget(
          onTap: onTap,
          semanticLabel: _describe(steps, streak),
          child: SizedBox.square(
            dimension: _size,
            child: CustomPaint(
              painter: _RingPainter(
                steps: steps,
                track: palette.surfaceSunken,
                ground: palette.surface,
                message: palette.warm,
                hadith: palette.ornamentGold,
                wrote: context.isDarkMode
                    ? AppColors.primaryGreenDark
                    : AppColors.primaryGreen,
              ),
              child: Center(
                // The Arabic zero is a dot, which reads as a speck here, so a
                // reader with no streak yet sees a leaf instead.
                child: streak == 0
                    ? Icon(
                        Icons.eco_rounded,
                        size: 18,
                        color: palette.ornamentGold,
                      )
                    : Text(
                        toArabicDigits(streak),
                        maxLines: 1,
                        textScaler: TextScaler.noScaling,
                        style: TextStyle(
                          fontFamily: kSans,
                          fontSize: streak > 99 ? 11 : 13,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          color: palette.warmText,
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.steps,
    required this.track,
    required this.ground,
    required this.message,
    required this.hadith,
    required this.wrote,
  });

  final DaySteps steps;
  final Color track;
  final Color ground;
  final Color message;
  final Color hadith;
  final Color wrote;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 4.5;
    const gap = .22;
    const sweep = 2 * math.pi / 3;

    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - stroke / 2;
    canvas.drawCircle(centre, radius, Paint()..color = ground);

    final rect = Rect.fromCircle(center: centre, radius: radius);
    final arcs = [
      (steps.message, message),
      (steps.hadith, hadith),
      (steps.wrote, wrote),
    ];
    for (var i = 0; i < arcs.length; i++) {
      final (done, colour) = arcs[i];
      canvas.drawArc(
        rect,
        -math.pi / 2 + i * sweep + gap / 2,
        sweep - gap,
        false,
        Paint()
          ..color = done ? colour : track
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.steps.done != steps.done ||
      oldDelegate.steps.message != steps.message ||
      oldDelegate.steps.hadith != steps.hadith ||
      oldDelegate.steps.wrote != steps.wrote ||
      oldDelegate.track != track ||
      oldDelegate.ground != ground;
}
