import 'package:flutter/material.dart';

import '../../core/auth/sign_in_gate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_motion.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/widgets/asset_helper.dart';
import '../../core/widgets/bottom_navigation.dart';
import '../../core/widgets/circle_icon_button.dart';
import '../../core/widgets/glass_panel.dart';
import '../../core/widgets/honor_card.dart';
import '../../core/widgets/icon_badge.dart';
import '../../core/widgets/parchment_card.dart';
import '../../core/widgets/pill_tabs.dart';
import '../../core/widgets/smooth_page_route.dart';
import '../../data/journey/journey_copy.dart';
import '../../data/journey/journey_repository.dart';
import '../../data/repositories/hadith_repository.dart';
import '../favorites/favorites_screen.dart';
import '../hadith/hadith_detail_screen.dart';
import '../memorize/memo_list_screen.dart';
import 'journey_numbers.dart';
import 'journey_share_sheet.dart';
import 'journey_tree.dart';
import 'today_steps_screen.dart';
import 'weekly_board_screen.dart';

/// A tab inside [HomeScreen]'s IndexedStack — the host supplies the Scaffold
/// and the background.
///
/// Everything that is the reader's own lives here: the journey, and the
/// favourites as a second section. A fifth tab would not fit a 320dp screen.
class JourneyScreen extends StatefulWidget {
  const JourneyScreen({
    super.key,
    required this.onOpenDrawer,
    required this.onOpenMessage,
  });

  final VoidCallback onOpenDrawer;

  /// Takes the reader to today's message.
  final VoidCallback onOpenMessage;

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  int _section = 0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleIconButton(
                icon: Icons.menu_rounded,
                semanticLabel: 'فتح قائمة الإعدادات',
                onTap: widget.onOpenDrawer,
              ),
              Flexible(
                child: Semantics(
                  header: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'رحلتي',
                        textAlign: TextAlign.center,
                        style: textTheme.titleMedium?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      AssetHelper.assetOrFallback(
                        assetPath: 'assets/images/golden_divider.png',
                        width: 80,
                        height: 10,
                        fallback: Container(
                          width: 40,
                          height: 1.5,
                          color: context.palette.cardBorderStrong,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // The tree is only worth sending once it has a leaf on it.
              AnimatedBuilder(
                animation: JourneyRepository().listenable,
                builder: (context, _) =>
                    _section == 0 && JourneyRepository().data.completeCount > 0
                        ? CircleIconButton(
                            icon: Icons.ios_share_rounded,
                            semanticLabel: 'مشاركة شجرتي',
                            onTap: () => shareTree(context),
                          )
                        : const SizedBox(width: CircleIconButton.slot),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _SectionTabs(
            selected: _section,
            onSelected: (section) => setState(() => _section = section),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: IndexedStack(
            index: _section,
            children: [
              // The tree stops swaying while the favourites are showing.
              TickerMode(
                enabled: _section == 0,
                child: _JourneyBody(onOpenMessage: widget.onOpenMessage),
              ),
              const FavoritesScreen(showHeader: false),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  static const _labels = ['رحلتي', 'المفضلة'];

  @override
  Widget build(BuildContext context) => PillTabs<int>(
        values: const [0, 1],
        labelOf: (i) => _labels[i],
        selected: selected,
        onSelected: onSelected,
        height: 36,
      );
}

class _JourneyBody extends StatelessWidget {
  const _JourneyBody({required this.onOpenMessage});

  final VoidCallback onOpenMessage;

  void _openHadith(BuildContext context, int number) {
    final hadith = HadithRepository().getByNumber(number);
    if (hadith == null) return;
    AppHaptics.tap();
    Navigator.push(
      context,
      appPageRoute(child: HadithDetailScreen(hadith: hadith)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final journey = JourneyRepository();
    final hadiths = HadithRepository();

    return AnimatedBuilder(
      animation: journey.listenable,
      builder: (context, _) {
        final data = journey.data;
        final steps = journey.todaySteps;
        final streak = journey.streak;
        final narrow = MediaQuery.sizeOf(context).width < 380;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            2,
            20,
            16 + BottomNavigation.reservedHeight(context),
          ),
          children: [
            ParchmentCard(
              elevated: true,
              // On a narrow phone the tree takes the card's full width, so
              // its leaves and numbers are drawn as large as they can be.
              padding: EdgeInsets.fromLTRB(
                narrow ? 4 : 14,
                12,
                narrow ? 4 : 14,
                16,
              ),
              child: Column(
                children: [
                  // About two fifths of the screen: the hero, without
                  // pushing the day's steps below the fold.
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * .42,
                    ),
                    // As tall as the tree, not as the room it may have.
                    child: Center(
                      heightFactor: 1,
                      child: JourneyTree(
                        data: data,
                        account: journey.uid,
                        today: journey.today,
                        ready: journey.loaded,
                        titleOf: (number) =>
                            hadiths.getByNumber(number)?.title ?? '',
                        onLeafTap: (number) => _openHadith(context, number),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _TreeSummary(
                    read: data.completeCount,
                    memorized: data.memorizedCount,
                    streak: streak.current,
                  ),
                  const SizedBox(height: 10),
                  _LeafKey(looks: leafLooks(data).values.toSet()),
                  if (journey.isGuest && !data.isEmpty) ...[
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => requireSignIn(
                        context,
                        reason: JourneyCopy.signInReason,
                      ),
                      child: const Text('سجّل الدخول لتبقى شجرتك معك'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            TodayStepsButton(
              steps: steps,
              onTap: () => Navigator.push(
                context,
                TodayStepsScreen.route(onOpenMessage: onOpenMessage),
              ),
            ),
            const SizedBox(height: 12),
            // Given the data, not const: a const card with nothing passed in
            // is never rebuilt when the journey changes.
            MemoEntry(data: data, today: journey.today),
            const SizedBox(height: 12),
            JourneyNumbers(
              streak: streak,
              bestThisWeek: journey.bestThisWeek,
              weekPoints: journey.thisWeekPoints.total,
              allPoints: journey.allPoints,
              memorized: data.memorizedCount,
              canShare: journey.weeks.thisWeek > 0,
              canShareJourney: journey.allPoints > 0 || streak.best > 0,
            ),
            const SizedBox(height: 12),
            const _BoardEntry(),
          ],
        );
      },
    );
  }
}

/// The way in to the weekly board. The one card on the page drawn apart
/// from the rest: a double gold frame on gold leaf, or emerald in dark
/// mode, as the board itself is.
class _BoardEntry extends StatelessWidget {
  const _BoardEntry();

  @override
  Widget build(BuildContext context) {
    return HonorCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      semanticLabel: 'لوحة الأسبوع، اختيارية، وتُنشر كل جمعة',
      onTap: () {
        AppHaptics.tap();
        Navigator.push(
          context,
          appPageRoute(child: const WeeklyBoardScreen()),
        );
      },
      child: Builder(
        // Read the palette inside the card: in dark mode it is the card's own.
        builder: (context) {
          final palette = context.palette;

          return ExcludeSemantics(
            child: Row(
              children: [
                const HonorMedal(icon: Icons.emoji_events_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const EntryTitle('لوحة الأسبوع'),
                      const SizedBox(height: 2),
                      Text(
                        'اختيارية، وتُنشر كل جمعة',
                        style: TextStyle(
                          fontFamily: kSans,
                          fontSize: 13,
                          height: AppLeading.chrome,
                          color: palette.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const ForwardChevron(emphasised: true),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The title on a card that opens a page of its own.
class EntryTitle extends StatelessWidget {
  const EntryTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: kSans,
        fontSize: 16.5,
        height: AppLeading.chrome,
        fontWeight: FontWeight.w800,
        color: context.palette.bodyText,
      ),
    );
  }
}

/// The facts under the tree, in a line of small pills.
class _TreeSummary extends StatelessWidget {
  const _TreeSummary({
    required this.read,
    required this.memorized,
    required this.streak,
  });

  final int read;
  final int memorized;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (read == 0 && memorized == 0) {
      return Text(
        'كل ورقة هنا حديث. ابدأ برسالة اليوم، وستنمو شجرتك مع قراءتك.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: kSans,
          fontSize: 13.5,
          height: AppLeading.body,
          fontWeight: FontWeight.w500,
          color: palette.mutedText,
        ),
      );
    }

    Widget pill(String text, {required bool strong, Widget? mark}) => Container(
          padding:
              EdgeInsetsDirectional.fromSTEB(mark == null ? 11 : 8, 5, 11, 5),
          decoration: glassTile(
            context,
            radius: AppRadii.pill,
            tint: strong ? palette.goldWash : null,
            edge: strong ? palette.ornamentGold : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (mark != null) ...[mark, const SizedBox(width: 5)],
              Text(
                text,
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: strong ? 14.5 : 13,
                  height: AppLeading.chrome,
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w700,
                  color: palette.goldText,
                ),
              ),
            ],
          ),
        );

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        pill('${toArabicDigits(read)} من ٤٢ حديثاً', strong: true),
        if (memorized > 0)
          pill('حفظت ${toArabicDigits(memorized)}', strong: false),
        if (streak > 0)
          pill(
            'استمرارية ${arabicDayCount(streak)}',
            strong: false,
            mark: Icon(
              Icons.local_fire_department_rounded,
              size: 16,
              color: palette.warm,
            ),
          ),
      ],
    );
  }
}

/// What each leaf means, for the kinds of leaf this tree has right now.
class _LeafKey extends StatelessWidget {
  const _LeafKey({required this.looks});

  final Set<LeafLook> looks;

  static const _labels = {
    LeafLook.complete: 'قرأته',
    LeafLook.memorized: 'حفظته',
    LeafLook.empty: 'لم يُقرأ بعد',
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    Widget entry(LeafLook look, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LeafSwatch(look),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 12,
                height: AppLeading.chrome,
                fontWeight: FontWeight.w600,
                color: palette.mutedText,
              ),
            ),
          ],
        );

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final MapEntry(key: look, value: label) in _labels.entries)
          if (looks.contains(look)) entry(look, label),
      ],
    );
  }
}
