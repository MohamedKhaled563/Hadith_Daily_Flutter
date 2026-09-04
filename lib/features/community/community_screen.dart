import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/share/share_sheet.dart';
import '../../core/widgets/bottom_navigation.dart';
import '../../core/theme/app_palette.dart';
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
import 'community_post_screen.dart';

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
  bool _sortByLikes = true;

  void _openAddMessage() => widget.onSwitchToShareTab?.call();

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
                const SizedBox(width: 44),

              const EmblemBadge(),

              // Balances the menu button so the emblem stays centred. Writing
              // a post already has a standing entry point — the bottom-nav
              // "شارك رسالة" tab — so this header does not need its own.
              const SizedBox(width: 44),
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
          onChanged: (value) => setState(() => _sortByLikes = value),
        ),

        const SizedBox(height: 12),

        Expanded(
          child: StreamBuilder<List<CommunityPost>>(
            stream: CommunityService().approvedMessages(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return AppEmptyState(
                  icon: Icons.wifi_off_rounded,
                  title: 'تعذّر تحميل المشاركات',
                  subtitle: 'تحقق من الاتصال بالإنترنت وحاول مرة أخرى.',
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final posts = List<CommunityPost>.from(snapshot.data!)
                ..sort(
                  _sortByLikes
                      ? (a, b) => b.likes.compareTo(a.likes)
                      : (a, b) => b.createdAt.compareTo(a.createdAt),
                );

              if (posts.isEmpty) {
                return AppEmptyState(
                  icon: Icons.forum_outlined,
                  title: 'لا توجد مشاركات بعد',
                  subtitle:
                      'كن أول من يشارك خاطرة أو تأملاً مربوطاً بحديث نبوي شريف، واجعلها سبباً في نشر الخير.',
                  actionLabel: 'شارك أول رسالة',
                  onAction: _openAddMessage,
                );
              }

              return Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      itemCount: posts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 18),
                      itemBuilder: (context, index) {
                        final post = posts[index];
                        return _CommunityPostCard(
                          post: post,
                          rank: index + 1,
                          onLikeToggle: () =>
                              CommunityService().toggleLike(post.id),
                          onTap: () => Navigator.push(
                            context,
                            SmoothPageRoute(
                              child: CommunityPostScreen(post: post),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // The empty state above already offers its own
                  // "شارك أول رسالة" action — this only shows once there's
                  // at least one approved post to scroll past.
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      6,
                      20,
                      6 + BottomNavigation.reservedHeight(context),
                    ),
                    child: _ShareCtaBanner(onTap: _openAddMessage),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SortToggle extends StatelessWidget {
  const _SortToggle({required this.sortByLikes, required this.onChanged});

  final bool sortByLikes;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    Widget option(String label, bool value) {
      final selected = sortByLikes == value;
      return TapTarget(
        onTap: () => onChanged(value),
        semanticLabel: label,
        selected: selected,
        minSize: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 13,
              height: AppLeading.chrome,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected ? palette.goldText : palette.mutedText,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(child: option('الأكثر إعجاباً', true)),
        Text('•', style: TextStyle(color: palette.mutedText, fontSize: 12)),
        option('الأحدث', false),
      ],
    );
  }
}

class _CommunityPostCard extends StatefulWidget {
  const _CommunityPostCard({
    required this.post,
    required this.rank,
    required this.onLikeToggle,
    required this.onTap,
  });

  final CommunityPost post;
  final int rank;
  final VoidCallback onLikeToggle;
  final VoidCallback onTap;

  @override
  State<_CommunityPostCard> createState() => _CommunityPostCardState();
}

class _CommunityPostCardState extends State<_CommunityPostCard> {
  final HadithRepository _repo = HadithRepository();

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
          Stack(
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
                child: LikeCounter(
                  likes: widget.post.likes,
                  isLiked: widget.post.isLiked,
                  onTap: widget.onLikeToggle,
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

class _ShareCtaBanner extends StatelessWidget {
  const _ShareCtaBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableSurface(
      onTap: onTap,
      semanticLabel: 'شارك رسالتك في مجتمع الحديث',
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [
              Color(0xFF1E3526),
              Color(0xFF2E4F3B),
              Color(0xFF1E3526),
            ],
          ),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: const Color(0xFFD6BE88), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E3526).withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.edit_note_rounded,
              color: Color(0xFFF0E6D2),
              size: 22,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'شارك رسالتك وكن سبباً في نشر الخير 🌿',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 14.5,
                  height: AppLeading.chrome,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFFFDFC),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
