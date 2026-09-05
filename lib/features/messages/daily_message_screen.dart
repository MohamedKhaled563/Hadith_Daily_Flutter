import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../hadith/hadith_detail_screen.dart';

class DailyMessageScreen extends StatefulWidget {
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
  State<DailyMessageScreen> createState() => _DailyMessageScreenState();
}

class _DailyMessageScreenState extends State<DailyMessageScreen> {
  final HadithRepository _repo = HadithRepository();

  late bool _isBookmarked;

  @override
  void initState() {
    super.initState();
    _isBookmarked = _repo.isInsightFavorite(widget.insight);
  }

  String get _shareText => '« ${widget.insight.message} »\n\n'
      '📌 المرتبط بـ: ${widget.hadith?.title ?? 'حديث نبوي شريف'}\n'
      '🌿 من تطبيق: طيّب قلبك - هدي النبوة';

  void _copyMessageText() {
    Clipboard.setData(ClipboardData(text: _shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ نص الرسالة بنجاح 🌿')),
    );
  }

  void _toggleBookmark() {
    setState(() {
      _isBookmarked = !_isBookmarked;
      _repo.toggleFavoriteInsight(widget.insight);
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
      message: widget.insight.message,
      hadithTitle: widget.hadith?.title,
      hadithNumber:
          widget.hadith == null ? null : toArabicDigits(widget.hadith!.number),
      category: widget.insight.category,
    );
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
                          'رسالة اليوم',
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
          const SizedBox(height: 6),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    20,
                    8,
                    20,
                    8 + BottomNavigation.reservedHeight(context),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - 16).clamp(
                        0,
                        double.infinity,
                      ),
                    ),
                    child: Center(child: _buildMessageCard()),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard() {
    final palette = context.palette;

    // The action toolbar lives below the card as its own floating pill,
    // rather than squeezed into a header row inside the card — that gives
    // every action room to breathe. The heart emblem stays inside the card,
    // at the top, where it reads as the card's own mark rather than a
    // separate element floating above the message.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ParchmentCard(
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                      widget.insight.category,
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
                '« ${widget.insight.message} »',
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
              if (widget.hadith != null) ...[
                _HadithLinkPill(
                  hadith: widget.hadith!,
                  onTap: () => Navigator.push(
                    context,
                    SmoothPageRoute(
                      child: HadithDetailScreen(hadith: widget.hadith!),
                    ),
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
        ),
        const SizedBox(height: 16),
        _MessageToolbar(
          isBookmarked: _isBookmarked,
          likes: _repo.insightLikeCount(widget.insight),
          isLiked: _repo.isInsightLiked(widget.insight),
          onBookmark: _toggleBookmark,
          onShare: _showSharePreview,
          onCopy: _copyMessageText,
          onLike: () => setState(
            () => _repo.toggleInsightLike(widget.insight),
          ),
        ),
      ],
    );
  }
}

/// A floating toolbar below the message card: the like counter on the right,
/// bookmark/share/copy grouped on the left, separated by a hairline divider.
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
  final int likes;
  final bool isLiked;
  final VoidCallback onBookmark;
  final VoidCallback onShare;
  final VoidCallback onCopy;
  final VoidCallback onLike;

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
          // Backed by the repository, keyed by message text — not a
          // hardcoded number that used to reset every time this card was
          // reopened.
          LikeCounter(likes: likes, isLiked: isLiked, onTap: onLike),
          const SizedBox(width: 14),
          Container(width: 1, height: 22, color: palette.cardBorder),
          const SizedBox(width: 14),
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
