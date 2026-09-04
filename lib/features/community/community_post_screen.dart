import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/share/share_sheet.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/asset_helper.dart';
import '../../core/widgets/circle_icon_button.dart';
import '../../core/widgets/like_counter.dart';
import '../../core/widgets/parchment_card.dart';
import '../../core/widgets/smooth_page_route.dart';
import '../../core/widgets/tap_target.dart';
import '../../data/models/insight.dart';
import '../../data/repositories/hadith_repository.dart';
import '../../data/services/community_service.dart';
import '../hadith/hadith_detail_screen.dart';

class CommunityPostScreen extends StatefulWidget {
  const CommunityPostScreen({super.key, required this.post});

  final CommunityPost post;

  @override
  State<CommunityPostScreen> createState() => _CommunityPostScreenState();
}

class _CommunityPostScreenState extends State<CommunityPostScreen> {
  final HadithRepository _repo = HadithRepository();

  // Optimistic: this screen gets a static [CommunityPost] snapshot from
  // whoever navigated here, not a live query, so the count needs its own
  // local state to feel instant rather than waiting on the round trip.
  // "Have I liked this" itself comes from a live per-user stream so it's
  // always the real answer, even across devices.
  late int _likeCount = widget.post.likes;

  void _toggleLike(bool currentlyLiked) {
    setState(() {
      _likeCount += currentlyLiked ? -1 : 1;
    });
    CommunityService().toggleLike(widget.post.id);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final hadith = _repo.getByNumber(widget.post.hadithNumber);

    return AppScreen(
      child: Column(
        children: [
          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
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
                          'مشاركة مجتمعية',
                          style: textTheme.titleMedium?.copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: 2),
                        AssetHelper.assetOrFallback(
                          assetPath: 'assets/images/golden_divider.png',
                          width: 60,
                          height: 8,
                          fallback: Container(
                            width: 35,
                            height: 1.5,
                            color: const Color(0xFFD6BE88),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                CircleIconButton(
                  icon: Icons.ios_share_rounded,
                  semanticLabel: 'مشاركة المشاركة كصورة',
                  onTap: () => showShareSheet(
                    context: context,
                    message: widget.post.message,
                    hadithTitle: hadith?.title,
                    hadithNumber: toArabicDigits(widget.post.hadithNumber),
                    attribution: widget.post.authorName,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                20, 0, 20, 24 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              children: [
                ParchmentCard(
                  elevated: true,
                  showBotanicals: true,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: palette.surface,
                              border: Border.all(color: palette.cardBorder),
                            ),
                            child: Text(
                              firstInitial(widget.post.authorName),
                              style: TextStyle(
                                fontFamily: kSans,
                                fontSize: 18,
                                height: AppLeading.chrome,
                                fontWeight: FontWeight.w700,
                                color: palette.goldText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.post.authorName,
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'متأمل في الحديث '
                                  '${toArabicDigits(widget.post.hadithNumber)}',
                                  style: TextStyle(
                                    fontFamily: kSans,
                                    fontSize: 12.5,
                                    height: AppLeading.chrome,
                                    fontWeight: FontWeight.w600,
                                    color: palette.goldText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      Center(
                        child: AssetHelper.assetOrFallback(
                          assetPath: 'assets/images/golden_divider.png',
                          width: 120,
                          height: 12,
                          fallback: Container(
                            width: 80,
                            height: 1.5,
                            color: const Color(0xFFD6BE88),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Text(
                        '« ${widget.post.message} »',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: kSans,
                          fontSize: 18.5,
                          height: AppLeading.body,
                          fontWeight: FontWeight.w600,
                          color: palette.bodyText,
                        ),
                      ),

                      if (hadith != null) ...[
                        const SizedBox(height: 24),
                        TapTarget(
                          onTap: () => Navigator.push(
                            context,
                            SmoothPageRoute(
                              child: HadithDetailScreen(hadith: hadith),
                            ),
                          ),
                          semanticLabel:
                              'افتح الحديث ${toArabicDigits(hadith.number)}: ${hadith.title}',
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: palette.surface,
                              borderRadius: BorderRadius.circular(
                                AppRadii.listItem,
                              ),
                              border: Border.all(color: palette.cardBorder),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.menu_book_rounded,
                                  size: 18,
                                  color: palette.goldText,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'الحديث ${toArabicDigits(hadith.number)}: '
                                    '${hadith.title}',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: kSans,
                                      fontSize: 13,
                                      height: AppLeading.chrome,
                                      fontWeight: FontWeight.w700,
                                      color: palette.goldText,
                                    ),
                                  ),
                                ),
                                // Points "forward" under RTL.
                                Icon(
                                  Icons.chevron_left_rounded,
                                  size: 18,
                                  color: palette.goldText,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Center(
                  child: StreamBuilder<bool>(
                    stream: CommunityService().likeStatus(widget.post.id),
                    builder: (context, snapshot) {
                      final isLiked = snapshot.data ?? false;
                      return LikeCounter(
                        likes: _likeCount,
                        isLiked: isLiked,
                        onTap: () => _toggleLike(isLiked),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
