import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_links.dart';
import '../../core/auth/sign_in_gate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/share/share_sheet.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_motion.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/widgets/asset_helper.dart';
import '../../core/widgets/bottom_navigation.dart';
import '../../core/widgets/circle_icon_button.dart';
import '../../core/widgets/like_counter.dart';
import '../../core/widgets/parchment_card.dart';
import '../../core/widgets/smooth_page_route.dart';
import '../../core/widgets/tap_target.dart';
import '../../data/models/hadith.dart';
import '../../data/models/insight.dart';
import '../../data/repositories/hadith_repository.dart';
import '../../data/services/daily_tip_service.dart';
import '../../data/services/message_like_service.dart';
import '../hadith/hadith_detail_screen.dart';

/// One card in a day's set: the message plus the hadith it hangs off, if
/// that hadith resolved locally.
@immutable
class DailyMessageEntry {
  const DailyMessageEntry({required this.insight, this.hadith});

  final Insight insight;
  final Hadith? hadith;
}

/// The full-screen message card.
///
/// A day can carry several messages (see DailyTipService and
/// `settings/dailyMessageConfig.messagesPerDay`). Those used to sit in a
/// horizontal pager, so opening the day handed the reader a swipeable stack
/// and the whole set at once. It now works the way a tip-of-the-day app
/// does: one message, and an explicit "رسالة أخرى" to ask for the next, up
/// to the day's limit — after which the day closes off with a note to come
/// back tomorrow rather than silently having nothing more to swipe to.
///
/// Reading one at a time is the point. A set of five swiped through in ten
/// seconds is five messages skimmed; the same five asked for one by one are
/// five messages each of which the reader chose to see.
///
/// [DailyMessageScreen.new] (a single message, from favourites) keeps none
/// of that: one card, no reveal control, no day framing.
class DailyMessageScreen extends StatefulWidget {
  DailyMessageScreen({
    super.key,
    required Insight insight,
    Hadith? hadith,
    this.onTabSelected,
  })  : entries = [DailyMessageEntry(insight: insight, hadith: hadith)],
        initialRevealed = 1,
        isDaySet = false;

  /// [initialRevealed] is how many of [entries] the reader has already opened
  /// today (DailyTipService.revealedCount). Passed in rather than read here
  /// so the correct card is on screen for the very first frame — loading it
  /// inside would show message one and then jump, under the Hero flight in
  /// from the home screen's emblem.
  const DailyMessageScreen.forDay({
    super.key,
    required this.entries,
    this.initialRevealed = 1,
    this.onTabSelected,
  })  : isDaySet = true;

  final List<DailyMessageEntry> entries;
  final int initialRevealed;

  /// Whether this is today's set (reveal one at a time, show the day's
  /// progress and its ending) or a single message opened on its own.
  final bool isDaySet;

  final ValueChanged<int>? onTabSelected;

  @override
  State<DailyMessageScreen> createState() => _DailyMessageScreenState();
}

class _DailyMessageScreenState extends State<DailyMessageScreen> {
  /// How many of the day's messages have been revealed, 1-based. The card on
  /// screen is always the most recently revealed one.
  late int _revealed = widget.initialRevealed.clamp(1, widget.entries.length);

  @override
  void didUpdateWidget(covariant DailyMessageScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rebuilt in place with different data — a longer set because the admin
    // raised messagesPerDay mid-session, or a later resume point. Take the
    // furthest of the two and re-clamp: progress within a session must never
    // run backwards, and a set that shrank must not leave the index past its
    // last message.
    final resumed = widget.initialRevealed;
    _revealed = (_revealed > resumed ? _revealed : resumed)
        .clamp(1, widget.entries.length);
  }

  bool get _showsDayControls => widget.isDaySet && widget.entries.length > 1;
  bool get _dayComplete => _revealed >= widget.entries.length;
  int get _remaining => widget.entries.length - _revealed;

  void _revealNext() {
    if (_dayComplete) return;
    AppHaptics.selection();
    setState(() => _revealed++);
    // Fire and forget: losing this write costs the reader a repeat of a
    // message they already saw, which is not worth blocking the reveal on.
    DailyTipService().saveRevealedCount(_revealed);
  }

  /// The share tab in the home shell's IndexedStack — home, favourites,
  /// community, share.
  static const _shareTabIndex = 3;

  /// Only offered when this screen was opened from the home shell, which is
  /// the only caller that can actually switch tabs. A notification deep link
  /// pushes this route with no tab handler, and a button that quietly did
  /// nothing would be worse than no button.
  VoidCallback? get _onShareOwnMessage => widget.onTabSelected == null
      ? null
      : () => widget.onTabSelected!(_shareTabIndex);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppScreen(
      bottomNavigationBar: BottomNavigation(
        // Not 0. This is a pushed route, not the Home tab, and lighting Home
        // up told the reader something untrue about where they were — then
        // popped instead of navigating when they acted on it. -1 selects
        // nothing, which is the honest answer.
        currentIndex: -1,
        onTap: (index) {
          if (widget.onTabSelected != null) {
            widget.onTabSelected!(index);
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
                          _showsDayControls ? 'رسائل اليوم' : 'رسالة اليوم',
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
                // bookmark action now lives on the card itself, alongside
                // copy and share.
                const SizedBox(width: CircleIconButton.slot),
              ],
            ),
          ),
          if (_showsDayControls)
            _RevealProgress(
              total: widget.entries.length,
              revealed: _revealed,
            ),
          const SizedBox(height: 6),
          // The card owns its own scroll: a short message centres in the
          // space left, a long one scrolls. The day's footer (reveal button
          // or closing note) rides inside that same scroll view rather than
          // being pinned below it, so a long message plus a footer stays
          // reachable instead of the footer covering the last lines.
          Expanded(
            child: AnimatedSwitcher(
              duration: context.motion(AppDurations.content),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              // Fade with a small rise — the new message *arrives*, it does
              // not slide in from the side. A horizontal slide would say
              // "you moved along a row", which is exactly the swipeable
              // stack this screen replaced.
              transitionBuilder: (child, animation) {
                final curved = CurvedAnimation(
                  parent: animation,
                  curve: AppDurations.curve,
                );
                return FadeTransition(
                  opacity: curved,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, 0.04),
                      end: Offset.zero,
                    ).animate(curved),
                    child: child,
                  ),
                );
              },
              child: _MessagePage(
                key: ValueKey(
                  '${_currentEntry.insight.sourceCollection}/'
                  '${_currentEntry.insight.id}#${_revealed - 1}',
                ),
                entry: _currentEntry,
                pageIndex: _revealed - 1,
                footer: _buildFooter(),
                // The closing panel is taller than the reveal button and the
                // card above it is already most of the screen, so on a phone
                // it lands below the fold. Rather than leave the reader to
                // discover it by scrolling, the page brings it up itself
                // once the day is done.
                revealFooterOnOpen: _showsDayControls && _dayComplete,
              ),
            ),
          ),
        ],
      ),
    );
  }

  DailyMessageEntry get _currentEntry => widget.entries[_revealed - 1];

  Widget? _buildFooter() {
    if (!_showsDayControls) return null;
    if (!_dayComplete) {
      return _RevealMoreFooter(remaining: _remaining, onReveal: _revealNext);
    }
    return _DayCompleteFooter(
      total: widget.entries.length,
      onShareOwnMessage: _onShareOwnMessage,
    );
  }
}

/// "بقيت لك رسالتان اليوم" and friends. Arabic counts a pair differently
/// from both one and many, and 3–10 take the plural noun, so this is three
/// forms rather than the usual two.
String remainingMessagesLabel(int remaining) {
  if (remaining <= 0) return 'لم يتبقَّ شيء لليوم';
  if (remaining == 1) return 'بقيت لك رسالة واحدة اليوم';
  if (remaining == 2) return 'بقيت لك رسالتان اليوم';
  return 'بقيت لك ${toArabicDigits(remaining)} رسائل اليوم';
}

/// How far into the day's set the reader has come, drawn as a strand of
/// beads on a thread rather than the usual row of pager dots.
///
/// The form is doing work: pager dots say "there are five panels, you are on
/// the second, swipe for the rest" — which is the browsing model this screen
/// deliberately left behind. A strand that fills bead by bead says "you have
/// taken two, three remain", which is what is actually true here, and it
/// carries a quiet echo of a misbaha without dressing anything up as one.
class _RevealProgress extends StatelessWidget {
  const _RevealProgress({required this.total, required this.revealed});

  final int total;
  final int revealed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final duration = context.motion(AppDurations.control);

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Semantics(
        label: 'قرأت $revealed من $total رسائل اليوم',
        child: ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < total; i++) ...[
                if (i > 0)
                  // The thread between beads, lit only as far as the reader
                  // has come.
                  AnimatedContainer(
                    duration: duration,
                    curve: AppDurations.curve,
                    width: 12,
                    height: 1,
                    color: i < revealed
                        ? palette.ornamentGold
                        : palette.cardBorder,
                  ),
                _Bead(
                  filled: i < revealed,
                  isCurrent: i == revealed - 1,
                  duration: duration,
                ),
              ],
              const SizedBox(width: 12),
              Text(
                '${toArabicDigits(revealed)} / ${toArabicDigits(total)}',
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 12,
                  height: AppLeading.chrome,
                  fontWeight: FontWeight.w700,
                  color: palette.goldText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bead extends StatelessWidget {
  const _Bead({
    required this.filled,
    required this.isCurrent,
    required this.duration,
  });

  final bool filled;
  final bool isCurrent;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final size = isCurrent ? 11.0 : 7.0;

    return AnimatedContainer(
      duration: duration,
      curve: AppDurations.curve,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? palette.goldText : Colors.transparent,
        border: Border.all(
          color: filled ? palette.goldText : palette.cardBorder,
          width: 1.2,
        ),
        // Only the bead just taken carries a halo, so the eye lands on where
        // the reader is without the whole strand glowing.
        boxShadow: isCurrent && filled
            ? [
                BoxShadow(
                  color: palette.ornamentGold.withValues(alpha: 0.55),
                  blurRadius: 7,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}

/// The day's invitation to go on: one more message, and how many are left.
///
/// The button gives a short halo pulse as it arrives and then rests. It is
/// deliberately *finite*: a glow that breathes forever stops being an
/// invitation and becomes wallpaper, it keeps a ticker running for as long
/// as the screen is open, and it means the screen never reaches a settled
/// state — which is also what an infinite pulse did to the first version of
/// this widget's tests.
class _RevealMoreFooter extends StatefulWidget {
  const _RevealMoreFooter({required this.remaining, required this.onReveal});

  final int remaining;
  final VoidCallback onReveal;

  @override
  State<_RevealMoreFooter> createState() => _RevealMoreFooterState();
}

class _RevealMoreFooterState extends State<_RevealMoreFooter>
    with SingleTickerProviderStateMixin {
  static const _pulseCount = 2;

  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  bool _breathStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_breathStarted || context.reduceMotion) return;
    _breathStarted = true;
    _playPulse();
  }

  Future<void> _playPulse() async {
    try {
      for (var i = 0; i < _pulseCount; i++) {
        await _breath.forward().orCancel;
        await _breath.reverse().orCancel;
      }
    } on TickerCanceled {
      // The reader moved on mid-pulse; nothing to finish.
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return _FooterEntrance(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _HairlineOrnament(),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _breath,
            builder: (context, child) => Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.pill),
                boxShadow: [
                  BoxShadow(
                    color: palette.ornamentGold.withValues(
                      alpha: 0.10 + 0.14 * _breath.value,
                    ),
                    blurRadius: 16 + 8 * _breath.value,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: child,
            ),
            child: AppButton(
              text: 'رسالة أخرى',
              icon: Icons.auto_awesome_rounded,
              expand: false,
              onPressed: widget.onReveal,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            remainingMessagesLabel(widget.remaining),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 12.5,
              height: AppLeading.chrome,
              fontWeight: FontWeight.w600,
              color: palette.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}

/// The end of the day's set: the reader has taken everything today had.
///
/// Framed as a closing rather than an absence — the crescent says "come back
/// tomorrow" in a single glyph, and the one action offered turns a reader
/// who has run out into someone who writes the next one.
class _DayCompleteFooter extends StatelessWidget {
  const _DayCompleteFooter({
    required this.total,
    required this.onShareOwnMessage,
  });

  final int total;
  final VoidCallback? onShareOwnMessage;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return _FooterEntrance(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _HairlineOrnament(),
          const SizedBox(height: 18),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.surface,
              border: Border.all(color: palette.cardBorderStrong, width: 1.4),
            ),
            child: Icon(
              Icons.nightlight_round,
              size: 22,
              color: palette.goldText,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'انتهت رسائل اليوم',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 16,
              height: AppLeading.chrome,
              fontWeight: FontWeight.w900,
              color: palette.bodyText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'قرأت ${toArabicDigits(total)} من رسائل اليوم.\n'
            'عُد غداً — في انتظارك رسائل جديدة بإذن الله.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 13,
              height: AppLeading.body,
              fontWeight: FontWeight.w600,
              color: palette.mutedText,
            ),
          ),
          if (onShareOwnMessage != null) ...[
            const SizedBox(height: 18),
            AppButton(
              text: 'شارك رسالة من عندك',
              icon: Icons.edit_note_rounded,
              isSecondary: true,
              expand: false,
              onPressed: onShareOwnMessage,
            ),
          ],
        ],
      ),
    );
  }
}

/// One fade-and-rise as a footer first appears, on its own parchment ground.
///
/// The panel is not decoration. The day's controls sit below the card, over
/// the screen's landscape illustration, and the caption under the button is
/// small muted text — on that background it was very nearly unreadable.
/// Giving the block a surface of its own both fixes the contrast and groups
/// the button with the line that explains it, instead of leaving two loose
/// elements floating over a photograph.
class _FooterEntrance extends StatelessWidget {
  const _FooterEntrance({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: context.motion(AppDurations.content),
      curve: AppDurations.curve,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 10 * (1 - t)), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
        decoration: BoxDecoration(
          // Not fully opaque: the landscape still shows through enough that
          // the panel reads as resting on the scene rather than punched out
          // of it.
          color: palette.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: palette.cardBorder),
          boxShadow: AppElevation.card,
        ),
        child: child,
      ),
    );
  }
}

/// A slim gold hairline that tapers at both ends — the divider used between
/// the message and the day's controls. Lighter than the full golden_divider
/// ornament the card itself uses, so the card stays the loudest thing.
class _HairlineOrnament extends StatelessWidget {
  const _HairlineOrnament();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SizedBox(
      width: 120,
      height: 9,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, palette.ornamentGold],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Transform.rotate(
            angle: 0.785398, // 45°, so the square reads as a small lozenge
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: palette.goldText,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [palette.ornamentGold, Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single message in the day's set: the card itself plus its own toolbar.
/// Bookmark state is per-message, which is why this is its own stateful
/// widget rather than something the screen tracks centrally.
class _MessagePage extends StatefulWidget {
  const _MessagePage({
    super.key,
    required this.entry,
    required this.pageIndex,
    this.footer,
    this.revealFooterOnOpen = false,
  });

  final DailyMessageEntry entry;

  /// Only page 0 carries the shared Hero tag; see [_MessagePageState._heroTag].
  final int pageIndex;

  /// The day's controls, shown under this message's toolbar. Inside the
  /// card's own scroll view rather than pinned to the screen, so a long
  /// message and its footer stay reachable together.
  final Widget? footer;

  /// Scroll the footer into view shortly after this page appears. Used for
  /// the day's closing panel, which is too tall to share a phone screen with
  /// a full message card.
  final bool revealFooterOnOpen;

  @override
  State<_MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<_MessagePage> {
  final HadithRepository _repo = HadithRepository();

  /// `heart_leaf_emblem_hero` is shared with the home circle and the login
  /// screen, and every page of this pager was using it too. Mid-swipe two
  /// pages are alive at once, so two Heroes held one tag in one route
  /// subtree — an assertion failure, and a crash rather than a glitch, if a
  /// route transition began inside that window.
  ///
  /// Page 0 keeps the shared tag because it is the page on screen when this
  /// route is pushed, so the flight from home still matches. Every other page
  /// gets its own, which is enough: two Heroes never share a tag again.
  String get _heroTag => widget.pageIndex == 0
      ? 'heart_leaf_emblem_hero'
      : 'heart_leaf_emblem_hero#${widget.pageIndex}';

  late bool _isBookmarked;

  final ScrollController _scrollController = ScrollController();

  Insight get _insight => widget.entry.insight;
  Hadith? get _hadith => widget.entry.hadith;

  @override
  void initState() {
    super.initState();
    _isBookmarked = _repo.isInsightFavorite(_insight);
    if (widget.revealFooterOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _bringFooterIntoView());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Holds on the message for a beat first — the reader should register the
  /// last message of the day before the screen tells them it was the last.
  Future<void> _bringFooterIntoView() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted || !_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) return; // Already all on screen; nothing to bring up.
    await _scrollController.animateTo(
      max,
      duration: context.motion(const Duration(milliseconds: 560)),
      curve: AppDurations.curve,
    );
  }

  String get _shareText {
    final link = AppLinks.storeLink;
    return '« ${_insight.message} »\n\n'
        'المرتبط بـ: ${_hadith?.title ??'حديث نبوي شريف'}\n'
        'من تطبيق: طيّب قلبك - هدي النبوة'
        '${link == null ? '' : '\n$link'}';
  }

  void _copyMessageText() {
    Clipboard.setData(ClipboardData(text: _shareText));
    showAppSnack(context, 'تم نسخ نص الرسالة', tone: SnackTone.success);
  }

  void _toggleBookmark() {
    AppHaptics.toggle();
    setState(() {
      _isBookmarked = !_isBookmarked;
      _repo.toggleFavoriteInsight(_insight);
    });

    showAppSnack(
      context,
      _isBookmarked ? 'تم حفظ الرسالة في المفضلة' : 'تمت الإزالة من المفضلة',
      tone: _isBookmarked ? SnackTone.success : SnackTone.neutral,
      action: _isBookmarked ? null : undoAction(context, _toggleBookmark),
    );
  }

  void _showSharePreview() {
    showShareSheet(
      context: context,
      message: _insight.message,
      hadithTitle: _hadith?.title,
      hadithNumber: _hadith == null ? null : toArabicDigits(_hadith!.number),
      category: _insight.category,
    );
  }

  Widget get _toolbar => _insight.isLikeable
      ? _LiveMessageToolbar(
          insight: _insight,
          isBookmarked: _isBookmarked,
          onBookmark: _toggleBookmark,
          onShare: _showSharePreview,
          onCopy: _copyMessageText,
        )
      : _MessageToolbar(
          isBookmarked: _isBookmarked,
          likes: null,
          isLiked: false,
          onBookmark: _toggleBookmark,
          onShare: _showSharePreview,
          onCopy: _copyMessageText,
          onLike: null,
        );

  @override
  Widget build(BuildContext context) {
    final navReserved = BottomNavigation.reservedHeight(context);

    // The toolbar belongs to the card, not to the bottom of the screen.
    //
    // It used to be a fixed sibling below the scroll area, which kept its
    // position stable across a swipe but put it ~90px above the nav bar and
    // ~200px below the card — same pill, same radius, same elevation as the
    // nav bar, at nav-bar distance from it. Proximity did the grouping, and
    // it grouped the wrong two things: the reader saw one double-decker
    // navigation bar, and a large void above the message.
    //
    // Card and toolbar now centre together as one block, so the controls read
    // as belonging to the message they act on and the leftover space is
    // shared evenly above and below instead of pooling at the top. The cost
    // is the trade that was made deliberately before: the toolbar's vertical
    // position now shifts a little between messages of different lengths.
    return LayoutBuilder(
      builder: (context, constraints) {
        final vertical = 16 + navReserved;

        return SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(20, 8, 20, 8 + navReserved),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - vertical).clamp(
                0,
                double.infinity,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCard(),
                  const SizedBox(height: 14),
                  _toolbar,
                  if (widget.footer != null) ...[
                    const SizedBox(height: 22),
                    widget.footer!,
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard() {
    final palette = context.palette;

    return ParchmentCard(
      elevated: true,
      showBotanicals: true,
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Hero(
            tag: _heroTag,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.surface,
                border: Border.all(
                  color: palette.cardBorderStrong,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: AssetHelper.assetOrFallback(
                  assetPath: 'assets/images/heart_leaf_emblem.png',
                  width: 34,
                  height: 34,
                  fallback: const Icon(
                    Icons.favorite_rounded,
                    color: AppColors.primaryGreen,
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: palette.cardBorder, width: 1.1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AssetHelper.assetOrFallback(
                  assetPath: 'assets/images/leaf_accent.png',
                  width: 14,
                  height: 14,
                  fallback: Icon(
                    Icons.eco_rounded,
                    size: 14,
                    color: palette.goldText,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _insight.category,
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 12.5,
                    height: AppLeading.chrome,
                    fontWeight: FontWeight.w700,
                    color: palette.goldText,
                  ),
                ),
              ],
            ),
          ),
          const _GoldDivider(),
          Text(
            '« ${_insight.message} »',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 20,
              height: AppLeading.scripture,
              fontWeight: FontWeight.w800,
              color: palette.bodyText,
            ),
          ),
          const _GoldDivider(),
          const SizedBox(height: 2),
          if (_hadith != null) ...[
            _HadithLinkPill(
              hadith: _hadith!,
              onTap: () => Navigator.push(
                context,
                appPageRoute(child: HadithDetailScreen(hadith: _hadith!)),
              ),
            ),
            const SizedBox(height: 18),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 20, height: 1, color: palette.cardBorder),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'طيّب قلبك • هدي النبوة',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 12,
                    height: AppLeading.chrome,
                    fontWeight: FontWeight.w700,
                    color: palette.goldText,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(width: 20, height: 1, color: palette.cardBorder),
            ],
          ),
        ],
      ),
    );
  }
}

/// Streams the live like count + this device's own like status from
/// [MessageLikeService] and feeds them into [_MessageToolbar] — split out
/// from it so a non-likeable insight (see [Insight.isLikeable]) never has to
/// touch Firestore at all.
class _LiveMessageToolbar extends StatefulWidget {
  const _LiveMessageToolbar({
    required this.insight,
    required this.isBookmarked,
    required this.onBookmark,
    required this.onShare,
    required this.onCopy,
  });

  final Insight insight;
  final bool isBookmarked;
  final VoidCallback onBookmark;
  final VoidCallback onShare;
  final VoidCallback onCopy;

  @override
  State<_LiveMessageToolbar> createState() => _LiveMessageToolbarState();
}

class _LiveMessageToolbarState extends State<_LiveMessageToolbar> {
  final _likeService = MessageLikeService();

  // Optimistic "have I liked this": MessageLikeService.toggleLike runs a
  // Firestore transaction, and unlike a plain set/update, a transaction's
  // write is never applied to the local cache ahead of the server — the
  // likeStatus()/likeCount() streams below sit frozen until the round trip
  // completes. Without this override the heart would visibly do nothing
  // for however long that takes. Cleared once the live stream confirms the
  // same value, so a like from another device still always wins.
  bool? _optimisticLiked;
  bool _isToggling = false;

  Future<void> _handleLike(bool serverLiked) async {
    if (_isToggling) return;
    // Liking is one of the three things that needs to know who you are — the
    // like doc is keyed by uid so it follows the reader between devices.
    if (!await requireSignIn(
      context,
      reason: 'سجّل الدخول ليبقى إعجابك محفوظاً على كل أجهزتك',
    )) {
      return;
    }
    if (!mounted) return;
    final next = !(_optimisticLiked ?? serverLiked);
    setState(() {
      _optimisticLiked = next;
      _isToggling = true;
    });
    try {
      await _likeService.toggleLike(
        widget.insight.sourceCollection,
        widget.insight.id,
      );
    } catch (_) {
      if (mounted) {
        setState(() => _optimisticLiked = null);
        showAppSnack(
          context,
          'تعذّر تسجيل الإعجاب، حاول مجدداً',
          tone: SnackTone.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _likeService.likeCount(
        widget.insight.sourceCollection,
        widget.insight.id,
      ),
      builder: (context, likeCountSnap) {
        return StreamBuilder<bool>(
          stream: _likeService.likeStatus(
            widget.insight.sourceCollection,
            widget.insight.id,
          ),
          builder: (context, likedSnap) {
            final serverLiked = likedSnap.data ?? false;
            if (_optimisticLiked != null && _optimisticLiked == serverLiked) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _optimisticLiked == serverLiked) {
                  setState(() => _optimisticLiked = null);
                }
              });
            }
            final isLiked = _optimisticLiked ?? serverLiked;
            final serverCount = likeCountSnap.data ?? 0;
            final displayedLikes =
                serverCount +
                (_optimisticLiked != null && _optimisticLiked != serverLiked
                    ? (_optimisticLiked! ? 1 : -1)
                    : 0);

            return _MessageToolbar(
              isBookmarked: widget.isBookmarked,
              likes: displayedLikes,
              isLiked: isLiked,
              onBookmark: widget.onBookmark,
              onShare: widget.onShare,
              onCopy: widget.onCopy,
              onLike: () => _handleLike(serverLiked),
            );
          },
        );
      },
    );
  }
}

/// A floating toolbar below the message card: the like counter on the right
/// (omitted when [likes] is null — the insight has nothing to like against,
/// see [Insight.isLikeable]), bookmark/share/copy grouped on the left,
/// separated by a hairline divider.
class _MessageToolbar extends StatelessWidget {
  const _MessageToolbar({
    required this.isBookmarked,
    required this.likes,
    required this.isLiked,
    required this.onBookmark,
    required this.onShare,
    required this.onCopy,
    required this.onLike,
  });

  final bool isBookmarked;
  final int? likes;
  final bool isLiked;
  final VoidCallback onBookmark;
  final VoidCallback onShare;
  final VoidCallback onCopy;
  final VoidCallback? onLike;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: palette.cardBorder),
        boxShadow: AppElevation.card,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // First child sits at the START edge — the right, in RTL — which
          // is where the like counter belongs.
          if (likes != null && onLike != null) ...[
            LikeCounter(likes: likes!, isLiked: isLiked, onTap: onLike!),
            const SizedBox(width: 14),
            Container(width: 1, height: 22, color: palette.cardBorder),
            const SizedBox(width: 14),
          ],
          _CardActionIcon(
            icon: isBookmarked
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            semanticLabel: 'حفظ الرسالة في المفضلة',
            toggled: isBookmarked,
            onTap: onBookmark,
          ),
          const SizedBox(width: 10),
          _CardActionIcon(
            icon: Icons.ios_share_rounded,
            semanticLabel: 'مشاركة البطاقة كصورة',
            onTap: onShare,
          ),
          const SizedBox(width: 10),
          _CardActionIcon(
            icon: Icons.copy_rounded,
            semanticLabel: 'نسخ نص الرسالة',
            onTap: onCopy,
          ),
        ],
      ),
    );
  }
}

/// A small round icon action clustered on the message toolbar — copy, share,
/// bookmark, all together rather than split between the card and the screen
/// header.
class _CardActionIcon extends StatelessWidget {
  const _CardActionIcon({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.toggled = false,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;
  final bool toggled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return TapTarget(
      onTap: onTap,
      semanticLabel: semanticLabel,
      toggled: toggled,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: toggled ? palette.surfaceSunken : palette.surface,
          border: Border.all(
            color: toggled ? palette.cardBorderStrong : palette.cardBorder,
            width: 1.1,
          ),
        ),
        child: Icon(icon, size: 17, color: palette.goldText),
      ),
    );
  }
}

class _GoldDivider extends StatelessWidget {
  const _GoldDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: AssetHelper.assetOrFallback(
        assetPath: 'assets/images/golden_divider.png',
        width: 120,
        height: 15,
        fallback: Container(
          width: 80,
          height: 1.5,
          color: const Color(0xFFD6BE88),
        ),
      ),
    );
  }
}

class _HadithLinkPill extends StatelessWidget {
  const _HadithLinkPill({required this.hadith, required this.onTap});

  final Hadith hadith;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return TapTarget(
      onTap: onTap,
      semanticLabel:
          'افتح الحديث ${toArabicDigits(hadith.number)}: ${hadith.title}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: palette.cardBorder, width: 1.1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories_rounded,
              size: 15,
              color: palette.goldText,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                'الحديث ${toArabicDigits(hadith.number)}: ${hadith.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}
