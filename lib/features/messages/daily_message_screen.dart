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
  bool _isLiked = false;
  int _likesCount = 48;

  @override
  void initState() {
    super.initState();
    _isBookmarked = _repo.isInsightFavorite(widget.insight.message);
  }

  String get _shareText =>
      '« ${widget.insight.message} »\n\n'
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
      _repo.toggleFavoriteInsight(widget.insight.message);
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
      hadithNumber: widget.hadith == null
          ? null
          : toArabicDigits(widget.hadith!.number),
      category: widget.insight.category,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
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
                _CircleIconButton(
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

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CircleIconButton(
                      icon: Icons.share_rounded,
                      semanticLabel: 'مشاركة الرسالة',
                      onTap: _showSharePreview,
                    ),
                    const SizedBox(width: 4),
                    _CircleIconButton(
                      icon: _isBookmarked
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      semanticLabel: 'حفظ الرسالة في المفضلة',
                      toggled: _isBookmarked,
                      iconColor: _isBookmarked ? palette.goldText : null,
                      onTap: _toggleBookmark,
                    ),
                  ],
                ),
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
                      minHeight: constraints.maxHeight - 16,
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

    return ParchmentCard(
      elevated: true,
      showBotanicals: true,
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _LikeCounter(
                likes: _likesCount,
                isLiked: _isLiked,
                onTap: () => setState(() {
                  _isLiked = !_isLiked;
                  _likesCount += _isLiked ? 1 : -1;
                }),
              ),

              Hero(
                tag: 'heart_leaf_emblem_hero',
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.surface,
                    border: Border.all(
                      color: palette.cardBorderStrong,
                      width: 1.4,
                    ),
                  ),
                  child: Center(
                    child: AssetHelper.assetOrFallback(
                      assetPath: 'assets/images/heart_leaf_emblem.png',
                      width: 32,
                      height: 32,
                      fallback: const Icon(
                        Icons.favorite_rounded,
                        color: AppColors.primaryGreen,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),

              TapTarget(
                onTap: _copyMessageText,
                semanticLabel: 'نسخ نص الرسالة',
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.surface,
                    border: Border.all(color: palette.cardBorder, width: 1.1),
                  ),
                  child: Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: palette.goldText,
                  ),
                ),
              ),
            ],
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

          _ShareCallToAction(onTap: _showSharePreview),

          const SizedBox(height: 16),

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

class _LikeCounter extends StatelessWidget {
  const _LikeCounter({
    required this.likes,
    required this.isLiked,
    required this.onTap,
  });

  final int likes;
  final bool isLiked;
  final VoidCallback onTap;

  static const _liked = Color(0xFFC73E3E);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = context.isDarkMode;

    return TapTarget(
      onTap: onTap,
      semanticLabel: 'إعجاب — ${likes} إعجاباً',
      toggled: isLiked,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isLiked
              ? (isDark ? const Color(0xFF382323) : const Color(0xFFFDE8E8))
              : palette.surface,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: isLiked ? _liked.withValues(alpha: 0.6) : palette.cardBorder,
            width: 1.1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isLiked ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutBack,
              child: Icon(
                isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: 19,
                color: isLiked ? _liked : palette.mutedText,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              toArabicDigits(likes),
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 13,
                height: AppLeading.chrome,
                fontWeight: FontWeight.w700,
                color: isLiked ? _liked : palette.bodyText,
              ),
            ),
          ],
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
      semanticLabel: 'افتح الحديث ${toArabicDigits(hadith.number)}: ${hadith.title}',
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

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.toggled,
    this.iconColor,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;
  final bool? toggled;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return TapTarget(
      onTap: onTap,
      semanticLabel: semanticLabel,
      toggled: toggled,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: palette.surface,
          border: Border.all(color: palette.cardBorder),
          boxShadow: AppElevation.card,
        ),
        child: Icon(icon, color: iconColor ?? palette.bodyText, size: 22),
      ),
    );
  }
}

/// The share action on the card face. The icon in the top bar is easy to miss,
/// and sharing a message onward is the whole point of the daily card.
class _ShareCallToAction extends StatelessWidget {
  const _ShareCallToAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableSurface(
      onTap: onTap,
      semanticLabel: 'مشاركة البطاقة كصورة',
      child: Container(
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [Color(0xFF1E3526), Color(0xFF2E4F3B), Color(0xFF1E3526)],
          ),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: const Color(0xFFD6BE88), width: 1.3),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E3526).withValues(alpha: 0.30),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.ios_share_rounded, size: 19, color: Color(0xFFF0E6D2)),
            SizedBox(width: 9),
            Text(
              'شارك البطاقة',
              style: TextStyle(
                fontFamily: kSans,
                fontSize: 14,
                height: AppLeading.chrome,
                fontWeight: FontWeight.w700,
                color: Color(0xFFFFFDFC),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
