import 'package:flutter/material.dart';
import '../../core/auth/sign_in_gate.dart';
import '../../core/utils/app_motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/share/share_sheet.dart';
import '../../core/widgets/bottom_navigation.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/asset_helper.dart';
import '../../core/widgets/circle_icon_button.dart';
import '../../core/widgets/like_counter.dart';
import '../../core/widgets/parchment_card.dart';
import '../../core/widgets/smooth_page_route.dart';
import '../../core/widgets/tap_target.dart';
import '../../data/models/hadith.dart';
import '../../data/models/insight.dart';
import '../../data/repositories/hadith_repository.dart';
import '../../data/services/community_service.dart';
import '../../data/services/moderation_service.dart';
import 'community_post_screen.dart';
import 'report_sheet.dart';

/// A tab inside [HomeScreen]'s IndexedStack — the host supplies the Scaffold,
/// the drawer and the background, so none are created here.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({
    super.key,
    this.onSwitchToShareTab,
    this.onOpenDrawer,
  });

  final VoidCallback? onSwitchToShareTab;
  final VoidCallback? onOpenDrawer;

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _moderation = ModerationService();

  bool _sortByLikes = true;

  /// Grows when the reader asks for more. Reset on a sort change, because the
  /// order changing makes "the next ten" mean something different.
  int _limit = CommunityService.pageSize;

  /// The block list is read here but changed elsewhere — the post screen, and
  /// the settings drawer two screens away. Listening is what makes unhiding a
  /// writer from the drawer actually bring their posts back.
  @override
  void initState() {
    super.initState();
    _moderation.addListener(_onBlockListChanged);
  }

  @override
  void dispose() {
    _moderation.removeListener(_onBlockListChanged);
    super.dispose();
  }

  void _onBlockListChanged() {
    if (mounted) setState(() {});
  }

  /// The gesture every reader tries on a feed, which did nothing here at all.
  ///
  /// What it can honestly do is bounded by the feed being a live stream: new
  /// posts already arrive without asking. So this goes to the server rather
  /// than the cache, which makes the one case that matters — a stale feed
  /// behind a dead connection — say so instead of silently sitting there.
  Future<void> _refresh() async {
    AppHaptics.tap();
    try {
      await CommunityService().refresh(byLikes: _sortByLikes);
    } catch (_) {
      if (!mounted) return;
      showAppSnack(
        context,
        'تعذّر التحديث، تحقق من اتصالك بالإنترنت',
        tone: SnackTone.danger,
      );
    }
  }

  void _openAddMessage() => widget.onSwitchToShareTab?.call();

  void _setSort(bool byLikes) {
    if (byLikes == _sortByLikes) return;
    setState(() {
      _sortByLikes = byLikes;
      _limit = CommunityService.pageSize;
    });
  }

  void _showMore() {
    AppHaptics.tap();
    setState(() => _limit += CommunityService.pageSize);
  }

  /// The post screen can come back saying the reader just blocked its author.
  /// The rebuild is the listener's job — this only has to say what happened,
  /// which the screen that closed itself is no longer around to say.
  Future<void> _openPost(CommunityPost post) async {
    final result = await Navigator.push(
      context,
      appPageRoute(child: CommunityPostScreen(post: post)),
    );
    if (!mounted || result != kAuthorBlocked) return;
    showAppSnack(
      context,
      'لن تظهر لك مشاركات هذا الكاتب على هذا الجهاز',
      tone: SnackTone.neutral,
    );
  }

  /// Makes a state that is not a list still answer the pull gesture.
  ///
  /// An empty state is a `Center`, which does not scroll, so the drag never
  /// reaches a [RefreshIndicator] above it. Giving it a scrollable that is
  /// forced to accept the drag and sized to the viewport keeps the state
  /// centred and makes the gesture work — which matters most exactly here,
  /// since "couldn't load" is the screen a reader most wants to retry.
  Widget _refreshable(Widget child) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: context.palette.goldText,
      backgroundColor: context.palette.surface,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        const SizedBox(height: 8),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // First child sits at the START edge — the right, in RTL.
              if (widget.onOpenDrawer != null)
                CircleIconButton(
                  icon: Icons.menu_rounded,
                  semanticLabel: 'فتح قائمة الإعدادات',
                  onTap: widget.onOpenDrawer!,
                )
              else
                const SizedBox(width: CircleIconButton.slot),

              const EmblemBadge(),

              // Balances the menu button so the emblem stays centred. Writing
              // a post already has a standing entry point — the bottom-nav
              // "شارك رسالة" tab — so this header does not need its own.
              const SizedBox(width: CircleIconButton.slot),
            ],
          ),
        ),

        const SizedBox(height: 10),

        Semantics(
          header: true,
          child: Text('مجتمع الحديث', style: textTheme.headlineMedium),
        ),
        const SizedBox(height: 6),

        _SortToggle(
          sortByLikes: _sortByLikes,
          onChanged: _setSort,
        ),

        const SizedBox(height: 12),

        Expanded(
          child: StreamBuilder<List<CommunityPost>>(
            stream: CommunityService().approvedMessages(
              limit: _limit,
              byLikes: _sortByLikes,
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                // Refreshable, because "try again" with nothing to try it
                // with is the same defect as a message with no way out of it.
                return _refreshable(
                  AppEmptyState(
                    icon: Icons.wifi_off_rounded,
                    title: 'تعذّر تحميل المشاركات',
                    subtitle: 'اسحب للأسفل للمحاولة مرة أخرى، بعد التحقق من '
                        'اتصالك بالإنترنت.',
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              // Ordering and bounding both happen on the server now, so
              // what arrives is already the page to draw.
              final fetched = snapshot.data!;
              // Measured before hiding anyone: "is there another page" is a
              // fact about the query, not about this reader's block list, and
              // filtering first would make the button vanish the moment a
              // blocked author happened to sit in the page.
              final canShowMore = fetched.length >= _limit;

              final posts = fetched
                  .where((p) => !_moderation.isBlocked(p.authorName))
                  .toList();

              if (posts.isEmpty) {
                return _refreshable(
                  fetched.isEmpty
                    ? AppEmptyState(
                        icon: Icons.forum_outlined,
                        title: 'لا توجد مشاركات بعد',
                        subtitle:
                            'كن أول من يشارك خاطرة أو تأملاً مربوطاً بحديث نبوي شريف، واجعلها سبباً في نشر الخير.',
                        actionLabel: 'شارك أول رسالة',
                        onAction: _openAddMessage,
                      )
                    : AppEmptyState(
                        icon: Icons.visibility_off_outlined,
                        title: 'كل المشاركات هنا من كُتّاب أخفيتهم',
                        subtitle:
                            'يمكنك إظهارهم مرة أخرى من الإعدادات، أو تشارك أنت خاطرة جديدة.',
                        actionLabel: 'شارك رسالة',
                        onAction: _openAddMessage,
                      ),
                );
              }

              // One plain vertical list, every post the same size — no
              // separate horizontal "featured" strip singling out the top
              // few, which duplicated posts between two different card
              // styles and made the list feel like it jumped around.
              // Sharing already has a standing entry point — the bottom-nav
              // "شارك رسالة" tab — so this list doesn't need its own second
              // call to action.
              return RefreshIndicator(
                onRefresh: _refresh,
                color: context.palette.goldText,
                backgroundColor: context.palette.surface,
                child: ListView.separated(
                  // Without this a feed shorter than the screen does not
                  // scroll at all, so the pull never reaches the indicator
                  // above — which is exactly the state a new or filtered feed
                  // is in. AlwaysScrollable only forces the list to accept the
                  // drag; the feel still comes from the platform's
                  // ScrollBehavior, so this does not bring back the hardcoded
                  // iOS bounce that was removed everywhere else.
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    20,
                    4,
                    20,
                    12 + BottomNavigation.reservedHeight(context),
                  ),
                  // One extra slot for the "show more" button, when there is
                  // plausibly more to show.
                  itemCount: posts.length + (canShowMore ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 18),
                  itemBuilder: (context, index) {
                    if (index == posts.length) {
                      return _ShowMoreButton(onTap: _showMore);
                    }
                    final post = posts[index];
                    return _CommunityPostCard(
                      post: post,
                      rank: index + 1,
                      onTap: () => _openPost(post),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Asks for the next page.
///
/// A plain button rather than infinite scroll on purpose: this is a feed of
/// reflections to sit with, not one to fall down, and an endless list quietly
/// invites the opposite.
class _ShowMoreButton extends StatelessWidget {
  const _ShowMoreButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Center(
      child: TapTarget(
        onTap: onTap,
        semanticLabel: 'عرض المزيد من المشاركات',
        pressScale: AppPress.cardScale,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: palette.cardBorder, width: 1.2),
            boxShadow: AppElevation.card,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: palette.goldText,
              ),
              const SizedBox(width: 8),
              Text(
                'عرض المزيد',
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 13,
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

/// The likes/recency sort control.
///
/// Drawn as a sunken track with a raised pill over the selected half. The
/// previous version — two words either side of a bullet — read as a subtitle,
/// and users reported not realising it could be tapped at all. The track
/// outline, the lifted pill and the leading icons are what now say "control"
/// instead of "caption".
class _SortToggle extends StatelessWidget {
  const _SortToggle({required this.sortByLikes, required this.onChanged});

  final bool sortByLikes;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    Widget option(String label, IconData icon, bool value) {
      final selected = sortByLikes == value;
      return Flexible(
        child: TapTarget(
          onTap: () => onChanged(value),
          semanticLabel: label,
          selected: selected,
          minSize: 44,
          // The pill is the whole target, so there is no dead border around
          // the thing that looks tappable.
          pressScale: AppPress.cardScale,
          child: AnimatedContainer(
            duration: AppPress.duration,
            curve: AppPress.curve,
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: selected ? palette.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(
                color: selected ? palette.cardBorderStrong : Colors.transparent,
                width: 1.2,
              ),
              boxShadow: selected ? AppElevation.card : const [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: selected ? palette.goldText : palette.mutedText,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: kSans,
                      fontSize: 13,
                      height: AppLeading.chrome,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: selected ? palette.goldText : palette.mutedText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: palette.surfaceSunken,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: palette.cardBorder, width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                option('الأكثر إعجاباً', Icons.favorite_rounded, true),
                option('الأحدث', Icons.schedule_rounded, false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommunityPostCard extends StatefulWidget {
  const _CommunityPostCard({
    required this.post,
    required this.rank,
    required this.onTap,
  });

  final CommunityPost post;
  final int rank;
  final VoidCallback onTap;

  @override
  State<_CommunityPostCard> createState() => _CommunityPostCardState();
}

class _CommunityPostCardState extends State<_CommunityPostCard> {
  final HadithRepository _repo = HadithRepository();
  final _service = CommunityService();

  // See _LiveMessageToolbar in daily_message_screen.dart for why this
  // optimistic override exists: toggleLike is a Firestore transaction,
  // which never gets an instant local-cache echo, so the likeStatus()
  // stream below would otherwise sit frozen for the whole round trip.
  bool? _optimisticLiked;
  bool _isToggling = false;

  Future<void> _handleLike(bool serverLiked) async {
    if (_isToggling) return;
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
      await _service.toggleLike(widget.post.id);
    } catch (_) {
      if (mounted) {
        setState(() => _optimisticLiked = null);
        showAppSnack(
          context,
          'تعذّر تسجيل الإعجاب، تحقق من اتصالك بالإنترنت',
          tone: SnackTone.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hadith = _repo.getByNumber(widget.post.hadithNumber);

    return ParchmentCard(
      elevated: true,
      showBotanicals: true,
      onTap: widget.onTap,
      semanticLabel: 'مشاركة بقلم ${widget.post.authorName}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            // Full card width so centerStart/centerEnd resolve against the
            // whole row rather than against the bounding box of whichever
            // child (often the like counter, at a large text scale or a
            // large like count) happens to be widest — otherwise the avatar
            // and the like counter can visually collide instead of sitting
            // side by side.
            width: double.infinity,
            child: Stack(
            alignment: Alignment.center,
            children: [
              // Centred regardless of the side widths — a spaceBetween Row
              // here used to shift the avatar off-centre whenever the like
              // counter's variable width didn't match the share icon's.
              _AuthorAvatar(
                rank: widget.rank,
                authorName: widget.post.authorName,
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: StreamBuilder<bool>(
                  stream: _service.likeStatus(widget.post.id),
                  builder: (context, snapshot) {
                    final serverLiked = snapshot.data ?? false;
                    if (_optimisticLiked != null &&
                        _optimisticLiked == serverLiked) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _optimisticLiked == serverLiked) {
                          setState(() => _optimisticLiked = null);
                        }
                      });
                    }
                    final isLiked = _optimisticLiked ?? serverLiked;
                    final displayedLikes =
                        widget.post.likes +
                        (_optimisticLiked != null &&
                                _optimisticLiked != serverLiked
                            ? (_optimisticLiked! ? 1 : -1)
                            : 0);
                    return LikeCounter(
                      likes: displayedLikes,
                      isLiked: isLiked,
                      onTap: () => _handleLike(serverLiked),
                    );
                  },
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TapTarget(
                  onTap: () => showShareSheet(
                    context: context,
                    message: widget.post.message,
                    hadithTitle: hadith?.title,
                    hadithNumber: toArabicDigits(widget.post.hadithNumber),
                    attribution: widget.post.authorName,
                  ),
                  semanticLabel: 'مشاركة المشاركة كصورة',
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: palette.surface,
                      border: Border.all(color: palette.cardBorder, width: 1.1),
                    ),
                    child: Icon(
                      Icons.ios_share_rounded,
                      size: 17,
                      color: palette.goldText,
                    ),
                  ),
                ),
              ),
            ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.post.authorName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 15,
              height: AppLeading.chrome,
              fontWeight: FontWeight.w700,
              color: palette.bodyText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'متأمل في الحديث الشريف ${toArabicDigits(widget.post.hadithNumber)}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 12,
              height: AppLeading.chrome,
              fontWeight: FontWeight.w600,
              color: palette.goldText,
            ),
          ),
          const _GoldDivider(),
          Text(
            '« ${widget.post.message} »',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 16,
              height: AppLeading.body,
              fontWeight: FontWeight.w700,
              color: palette.bodyText,
            ),
          ),
          const _GoldDivider(),
          if (hadith != null) ...[
            _HadithLinkPill(hadith: hadith),
            const SizedBox(height: 14),
          ],
          const _BrandSignature(label: '🌿 طيّب قلبك • مشاركات المجتمع'),
        ],
      ),
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({required this.rank, required this.authorName});

  final int rank;
  final String authorName;

  static const _avatarColors = [
    Color(0xFF4F6E5B),
    Color(0xFF7A5B0E),
    Color(0xFF6A4F7B),
    Color(0xFF3F5D7B),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final initial = firstInitial(authorName);
    final color = _avatarColors[(rank - 1) % _avatarColors.length];

    return ExcludeSemantics(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.surface,
              border: Border.all(color: palette.cardBorderStrong, width: 1.4),
            ),
            child: Text(
              initial,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 18,
                height: AppLeading.chrome,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          // A small chip clipped to the avatar's lower-right, overlapping just
          // enough to read as attached to it. Circular for single digits,
          // widening to a short pill for two.
          Positioned(
            bottom: -4,
            right: -4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF7A5B0E),
                borderRadius: BorderRadius.circular(11),
                // Ring in the card colour so the chip reads as sitting on top
                // of the avatar rather than merging into its rim.
                border: Border.all(color: palette.parchmentTop, width: 2),
              ),
              child: Text(
                toArabicDigits(rank),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: kSans,
                  fontSize: 10,
                  height: 1.0,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HadithLinkPill extends StatelessWidget {
  const _HadithLinkPill({required this.hadith});

  final Hadith hadith;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: palette.cardBorder, width: 1.1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_stories_rounded, size: 14, color: palette.goldText),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'الحديث ${toArabicDigits(hadith.number)}: ${hadith.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 12,
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

class _GoldDivider extends StatelessWidget {
  const _GoldDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: AssetHelper.assetOrFallback(
        assetPath: 'assets/images/golden_divider.png',
        width: 110,
        height: 14,
        fallback: Container(
          width: 60,
          height: 1.5,
          color: const Color(0xFFD6BE88),
        ),
      ),
    );
  }
}

class _BrandSignature extends StatelessWidget {
  const _BrandSignature({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 16, height: 1, color: palette.cardBorder),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 11.5,
              height: AppLeading.chrome,
              fontWeight: FontWeight.w700,
              color: palette.goldText,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(width: 16, height: 1, color: palette.cardBorder),
      ],
    );
  }
}

