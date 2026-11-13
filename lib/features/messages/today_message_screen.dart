import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_motion.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/tap_target.dart';
import '../../data/services/daily_tip_service.dart';
import 'daily_message_card.dart';
import 'daily_message_screen.dart';

/// Today's message, in its own window over the home tab.
///
/// Pressing طيّب قلبك opens this and leaving it goes back to the emblem, so
/// home always has the emblem on it. Each press of the emblem brings the next
/// of today's messages until the day runs out, then keeps showing the last
/// one; رسالة أخرى inside the window moves on the same way. How far the
/// reader got is kept in DailyTipService, not on home.
///
/// No counter, and no indication of how many the day holds. The reader is
/// being given a message, not shown their position in a queue — a "١ / ٤"
/// turns a quiet daily habit into a checklist with three items outstanding.
/// "رسالة أخرى" simply stops being offered when the day is spent.
///
/// No bottom nav either, unlike the saved-message screen: today's window is
/// a moment away from home with one way out, and the message gets the room.
class TodayMessageScreen extends StatefulWidget {
  const TodayMessageScreen({
    super.key,
    required this.entries,
    required this.revealed,
  });

  /// The whole of today's set. Never empty: home does not open the window
  /// without one.
  final List<DailyMessageEntry> entries;

  /// How many of [entries] the reader has been given; the last of those is
  /// the one shown first.
  final int revealed;

  @override
  State<TodayMessageScreen> createState() => _TodayMessageScreenState();
}

class _TodayMessageScreenState extends State<TodayMessageScreen> {
  /// A stored count can run past the end if the admin lowered the day's size
  /// after the reader had gone further.
  late final int _openedOn = widget.revealed.clamp(1, widget.entries.length);
  late int _revealed = _openedOn;

  /// "رسالة أخرى" — the next of today's set, if the day carries more than
  /// one.
  void _revealNextMessage() {
    if (_revealed >= widget.entries.length) return;
    AppHaptics.tap();
    setState(() => _revealed++);
    DailyTipService().saveRevealedCount(_revealed);
  }

  @override
  Widget build(BuildContext context) {
    return AppScreen(
      child: Column(
        children: [
          const SizedBox(height: 6),
          const MessageWindowHeader(title: 'رسالة اليوم'),
          const SizedBox(height: 10),
          Expanded(
            child: _TodayMessage(
              entry: widget.entries[_revealed - 1],
              // Only the message the emblem flew to. "رسالة أخرى" cross-fades,
              // so two cards are briefly alive together, and both claiming
              // the tag would be two Heroes on one route — an assertion if
              // the reader leaves during the fade.
              heroTag: _revealed == _openedOn ? 'heart_leaf_emblem_hero' : null,
              hasMore: _revealed < widget.entries.length,
              onRevealNext: _revealNextMessage,
            ),
          ),
          SizedBox(height: 16 + MediaQuery.viewPaddingOf(context).bottom),
        ],
      ),
    );
  }
}

class _TodayMessage extends StatelessWidget {
  const _TodayMessage({
    required this.entry,
    required this.heroTag,
    required this.hasMore,
    required this.onRevealNext,
  });

  final DailyMessageEntry entry;
  final String? heroTag;
  final bool hasMore;
  final VoidCallback onRevealNext;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: AnimatedSwitcher(
        duration: context.motion(AppDurations.content),
        switchInCurve: AppDurations.curve,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        // The card is the switcher's child directly. Wrapping it in a Column
        // broke the fill: a Column hands its children *unbounded* height, so
        // the card's own Expanded had nothing to divide up.
        child: DailyMessageCard(
          key: ValueKey(
            '${entry.insight.sourceCollection}/${entry.insight.id}'
            '/${entry.insight.message.hashCode}',
          ),
          entry: entry,
          fillHeight: true,
          heroTag: heroTag,
          footer: hasMore
              ? _AnotherMessageButton(onTap: onRevealNext)
              : _TomorrowNote(palette: palette),
        ),
      ),
    );
  }
}

/// "رسالة أخرى" — built from the same parts as the toolbar right above it.
///
/// It used to be a solid green pill with a small leaf in a dark ring. Next to
/// the cream card and the cream, gold-ringed toolbar it was the one heavy
/// block on the screen, and the leaf said "this app" rather than "another".
/// Now it is a cream pill with the strong gold rim, green type for the
/// action, and a gold-ringed circle holding a turning arrow — the same
/// circle the toolbar's buttons use, with a glyph that reads as "another".
class _AnotherMessageButton extends StatelessWidget {
  const _AnotherMessageButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final green = Theme.of(context).colorScheme.primary;

    return TapTarget(
      onTap: onTap,
      semanticLabel: 'اعرض رسالة أخرى من رسائل اليوم',
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 20, 6),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: palette.cardBorderStrong, width: 1.3),
          boxShadow: AppElevation.card,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.surfaceSunken,
                border: Border.all(color: palette.ornamentGold, width: 1.2),
              ),
              child: Icon(
                Icons.autorenew_rounded,
                size: 19,
                color: palette.goldText,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'رسالة أخرى',
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 14.5,
                height: AppLeading.chrome,
                fontWeight: FontWeight.w800,
                color: green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TomorrowNote extends StatelessWidget {
  const _TomorrowNote({required this.palette});

  final BotanicalPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        // A pill, like the category and hadith chips on the card. Sitting on
        // the landscape illustration, plain muted text on its own would be
        // very close to unreadable.
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: palette.cardBorder, width: 1.1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.nightlight_round, size: 15, color: palette.goldText),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'نلقاك غداً بإذن الله',
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 12.5,
                height: AppLeading.chrome,
                fontWeight: FontWeight.w700,
                color: palette.goldText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
