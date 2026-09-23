import 'package:flutter/material.dart';

import '../../core/widgets/app_background.dart';
import '../../core/widgets/asset_helper.dart';
import '../../core/widgets/bottom_navigation.dart';
import '../../core/widgets/circle_icon_button.dart';
import '../../data/models/hadith.dart';
import '../../data/models/insight.dart';
import 'daily_message_card.dart';

export 'daily_message_card.dart' show DailyMessageEntry;

/// One message, full screen, with its own back button.
///
/// This used to be where the *day* lived — first as a swipeable pager over
/// the whole set, then as a reveal flow with a progress strand. Neither
/// belongs on a pushed route any more: today's message now lives inline on
/// the home tab and stays there once opened, the way a tip-of-the-day app
/// works, so opening the day never navigates anywhere.
///
/// What is left is the case that genuinely is a single message on its own —
/// opening a bookmarked one from favourites.
class DailyMessageScreen extends StatelessWidget {
  const DailyMessageScreen({
    super.key,
    required this.insight,
    this.hadith,
    this.onTabSelected,
  });

  final Insight insight;
  final Hadith? hadith;
  final ValueChanged<int>? onTabSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final navReserved = BottomNavigation.reservedHeight(context);

    return AppScreen(
      bottomNavigationBar: BottomNavigation(
        // Not 0. This is a pushed route, not the Home tab, and lighting Home
        // up told the reader something untrue about where they were — then
        // popped instead of navigating when they acted on it. -1 selects
        // nothing, which is the honest answer.
        currentIndex: -1,
        onTap: (index) {
          if (onTabSelected != null) {
            onTabSelected!(index);
          } else {
            Navigator.maybePop(context);
          }
        },
      ),
      child: Column(
        children: [
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleIconButton(
                  icon: Icons.chevron_right_rounded,
                  semanticLabel: 'رجوع',
                  onTap: () => Navigator.maybePop(context),
                ),
                Flexible(
                  child: Semantics(
                    header: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'رسالة',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        AssetHelper.assetOrFallback(
                          assetPath: 'assets/images/golden_divider.png',
                          width: 70,
                          height: 10,
                          fallback: Container(
                            width: 40,
                            height: 1.5,
                            color: const Color(0xFFD6BE88),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Balances the back button so the title stays centred. The
                // bookmark action lives on the card itself, alongside copy
                // and share.
                const SizedBox(width: CircleIconButton.slot),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 8 + navReserved),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - 16 - navReserved)
                          .clamp(0, double.infinity),
                    ),
                    child: Center(
                      child: DailyMessageCard(
                        entry: DailyMessageEntry(
                          insight: insight,
                          hadith: hadith,
                        ),
                        heroTag: 'heart_leaf_emblem_hero',
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
