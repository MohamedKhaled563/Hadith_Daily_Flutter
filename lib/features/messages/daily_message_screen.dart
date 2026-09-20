import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_links.dart';
import '../../core/auth/sign_in_gate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/share/share_sheet.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/widgets/app_background.dart';
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

/// The full-screen message card. A day can now carry several messages (see
/// DailyTipService and `settings/dailyMessageConfig.messagesPerDay`), so the
/// card lives inside a horizontal pager — swipe right-to-left in RTL to move
/// through the day. With a single entry the pager is inert and the screen
/// looks exactly as it always did, which is what the favourites list and the
/// notification deep links rely on.
class DailyMessageScreen extends StatefulWidget {
  DailyMessageScreen({
    super.key,
    required Insight insight,
    Hadith? hadith,
    this.onTabSelected,
  }) : entries = [DailyMessageEntry(insight: insight, hadith: hadith)];

  const DailyMessageScreen.forDay({
    super.key,
    required this.entries,
    this.onTabSelected,
  });

  final List<DailyMessageEntry> entries;
  final ValueChanged<int>? onTabSelected;

  @override
  State<DailyMessageScreen> createState() => _DailyMessageScreenState();
}

class _DailyMessageScreenState extends State<DailyMessageScreen> {
  late final PageController _pageController = PageController();
  int _index = 0;

  bool get _isMultiple => widget.entries.length > 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppScreen(
      bottomNavigationBar: BottomNavigation(
        currentIndex: 0,
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
                          _isMultiple ? 'رسائل اليوم' : 'رسالة اليوم',
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
                const SizedBox(width: 44),
              ],
            ),
          ),
          if (_isMultiple)
            _PageIndicator(count: widget.entries.length, index: _index),
          const SizedBox(height: 6),
          // Each page owns the same two-part layout the screen used to have
          // directly: the card scrolls/centers on its own — a short message
          // centers vertically in the remaining space, a long one scrolls —
          // while the toolbar is a fixed sibling below it, so its position
          // never shifts with how tall any given message happens to be. That
          // also means swiping carries each message's own toolbar (its own
          // like count and bookmark state) along with it.
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: _isMultiple
                  ? const BouncingScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              itemCount: widget.entries.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => _MessagePage(
                key: ValueKey(
                  '${widget.entries[i].insight.sourceCollection}/'
                  '${widget.entries[i].insight.id}#$i',
                ),
                entry: widget.entries[i],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Which message of the day is showing — dots plus an Arabic-numeral
/// counter, since a set can run to ten and ten dots alone stop being
/// countable at a glance.
class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Semantics(
        label: 'الرسالة ${index + 1} من $count',
        child: ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < count; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == index ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == index ? palette.goldText : palette.cardBorder,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                ),
              const SizedBox(width: 10),
              Text(
                '${toArabicDigits(index + 1)} / ${toArabicDigits(count)}',
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

/// A single message in the day's set: the card itself plus its own toolbar.
/// Bookmark state is per-message, which is why this is its own stateful
/// widget rather than something the screen tracks centrally.
class _MessagePage extends StatefulWidget {
  const _MessagePage({super.key, required this.entry});

  final DailyMessageEntry entry;

  @override
  State<_MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<_MessagePage> {
  final HadithRepository _repo = HadithRepository();

  late bool _isBookmarked;

  Insight get _insight => widget.entry.insight;
  Hadith? get _hadith => widget.entry.hadith;

  @override
  void initState() {
    super.initState();
    _isBookmarked = _repo.isInsightFavorite(_insight);
  }

  String get _shareText {
    final link = AppLinks.storeLink;
    return '« ${_insight.message} »\n\n'
        '📌 المرتبط بـ: ${_hadith?.title ?? 'حديث نبوي شريف'}\n'
        '🌿 من تطبيق: طيّب قلبك - هدي النبوة'
        '${link == null ? '' : '\n$link'}';
  }

  void _copyMessageText() {
    Clipboard.setData(ClipboardData(text: _shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ نص الرسالة بنجاح 🌿')),
    );
  }

  void _toggleBookmark() {
    setState(() {
      _isBookmarked = !_isBookmarked;
      _repo.toggleFavoriteInsight(_insight);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isBookmarked
              ? 'تم حفظ الرسالة في المفضلة 🌿'
              : 'تمت الإزالة من المفضلة',
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 16).clamp(
                      0,
                      double.infinity,
                    ),
                  ),
                  child: Center(child: _buildCard()),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            8 + BottomNavigation.reservedHeight(context),
          ),
          child: _insight.isLikeable
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
                ),
        ),
      ],
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
            tag: 'heart_leaf_emblem_hero',
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
                SmoothPageRoute(child: HadithDetailScreen(hadith: _hadith!)),
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
                  '🌿 طيّب قلبك • هدي النبوة',
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر تسجيل الإعجاب، حاول مجدداً')),
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
