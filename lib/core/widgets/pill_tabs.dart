import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_text_styles.dart';
import '../utils/app_motion.dart';
import 'tap_target.dart';

/// A row of choices in one rounded track, the chosen one on a raised pill
/// that slides to it. One look for every switch between views of a page
/// (رحلتي / المفضلة, the board's lists), where each used to draw its own.
class PillTabs<T> extends StatelessWidget {
  const PillTabs({
    super.key,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onSelected,
    this.height = 38,
  });

  final List<T> values;
  final String Function(T) labelOf;
  final T selected;
  final ValueChanged<T> onSelected;
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final count = values.length;
    final index = values.indexOf(selected);
    final duration = context.motion(AppDurations.control);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: palette.cardBorder),
      ),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            // The raised pill, sliding under the chosen label.
            AnimatedAlign(
              duration: duration,
              curve: AppDurations.curve,
              alignment: AlignmentDirectional(
                count == 1 ? 0 : -1 + 2 * index / (count - 1),
                0,
              ),
              child: FractionallySizedBox(
                widthFactor: 1 / count,
                heightFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: palette.parchmentTop,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    border: Border.all(
                      color: palette.ornamentGold.withValues(alpha: .55),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: palette.ornamentGold.withValues(alpha: .22),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (final value in values)
                  Expanded(
                    child: TapTarget(
                      onTap: () {
                        if (value == selected) return;
                        AppHaptics.selection();
                        onSelected(value);
                      },
                      semanticLabel: labelOf(value),
                      selected: value == selected,
                      pressScale: 1,
                      minSize: height,
                      child: SizedBox(
                        height: height,
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: duration,
                            style: TextStyle(
                              fontFamily: kSans,
                              fontSize: 14,
                              height: 1.1,
                              fontWeight: value == selected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: value == selected
                                  ? palette.goldText
                                  : palette.mutedText,
                            ),
                            child: Text(
                              labelOf(value),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
