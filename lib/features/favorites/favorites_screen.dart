import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/bottom_navigation.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/asset_helper.dart';
import '../../core/widgets/circle_icon_button.dart';
import '../../core/widgets/parchment_card.dart';
import '../../core/widgets/smooth_page_route.dart';
import '../../core/widgets/tap_target.dart';
import '../../data/models/hadith.dart';
import '../../data/models/insight.dart';
import '../../data/repositories/hadith_repository.dart';
import '../hadith/hadith_detail_screen.dart';
import '../messages/daily_message_screen.dart';

/// A tab inside [HomeScreen]'s IndexedStack — the host supplies the Scaffold
/// and the background.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key, this.onOpenDrawer});

  final VoidCallback? onOpenDrawer;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final HadithRepository _repo = HadithRepository();
  int _selectedCategory = 0;

  void _copyText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ النص بنجاح 🌿')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    final favoriteInsights = _repo.getFavoriteInsights();
    final favoriteHadiths = _repo.getFavoriteHadiths();

    return Column(
      children: [
        const SizedBox(height: 6),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (widget.onOpenDrawer != null)
                CircleIconButton(
                  icon: Icons.menu_rounded,
                  semanticLabel: 'فتح قائمة الإعدادات',
                  onTap: widget.onOpenDrawer!,
                )
              else
                const SizedBox(width: 48),

              Flexible(
                child: Semantics(
                  header: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'المفضلة والمحفوظات',
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
                          color: const Color(0xFFD6BE88),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 48),
            ],
          ),
        ),

        const SizedBox(height: 12),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: palette.surfaceSunken,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: palette.cardBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _CategoryTab(
                    title: 'رسائل اليوم (${toArabicDigits(favoriteInsights.length)})',
                    icon: Icons.auto_awesome_rounded,
                    isSelected: _selectedCategory == 0,
                    onTap: () => setState(() => _selectedCategory = 0),
                  ),
                ),
                Expanded(
                  child: _CategoryTab(
                    title: 'الأحاديث (${toArabicDigits(favoriteHadiths.length)})',
                    icon: Icons.menu_book_rounded,
                    isSelected: _selectedCategory == 1,
                    onTap: () => setState(() => _selectedCategory = 1),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        Expanded(
          child: _selectedCategory == 0
              ? _buildInsightsList(favoriteInsights)
              : _buildHadithsList(favoriteHadiths),
        ),
      ],
    );
  }

  Widget _buildInsightsList(List<Insight> items) {
    if (items.isEmpty) {
      return const AppEmptyState(
        title: 'لا توجد رسائل محفوظة بعد',
        subtitle:
            'اضغط على أيقونة الإشارة المرجعية أعلى أي رسالة يومية لحفظها في قائمتك المفضلة للرجوع إليها دائماً.',
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        20, 4, 20, 30 + BottomNavigation.reservedHeight(context),
      ),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final insight = items[index];
        final hadith = _repo.getByNumber(insight.hadithNumber);
        final palette = context.palette;

        return ParchmentCard(
          padding: const EdgeInsets.all(18),
          showCornerOrnaments: false,
          showWatermark: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CategoryPill(label: insight.category),
                  TapTarget(
                    onTap: () {
                      setState(
                        () => _repo.toggleFavoriteInsight(insight.message),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تمت الإزالة من المحفوظات'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    semanticLabel: 'إزالة الرسالة من المحفوظات',
                    toggled: true,
                    // Unsaving is reversible and low-stakes — the app's usual
                    // gold, not the red reserved for destructive actions like
                    // signing out.
                    child: Icon(
                      Icons.bookmark_remove_rounded,
                      size: 22,
                      color: palette.goldText,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Text(
                '« ${insight.message} »',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 16,
                  height: AppLeading.body,
                  fontWeight: FontWeight.w700,
                  color: palette.bodyText,
                ),
              ),

              const SizedBox(height: 14),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (hadith != null)
                    TapTarget(
                      onTap: () => Navigator.push(
                        context,
                        SmoothPageRoute(
                          child: HadithDetailScreen(hadith: hadith),
                        ),
                      ),
                      semanticLabel: 'افتح الحديث ${toArabicDigits(hadith.number)}',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          border: Border.all(color: palette.cardBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.menu_book_rounded,
                              size: 13,
                              color: palette.goldText,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'الحديث ${toArabicDigits(hadith.number)}',
                              style: TextStyle(
                                fontFamily: kSans,
                                fontSize: 11.5,
                                height: AppLeading.chrome,
                                fontWeight: FontWeight.w700,
                                color: palette.goldText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),

                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TapTarget(
                        onTap: () => Navigator.push(
                          context,
                          SeamlessMessagePageRoute(
                            child: DailyMessageScreen(
                              insight: insight,
                              hadith: hadith,
                            ),
                          ),
                        ),
                        semanticLabel: 'عرض في بطاقة رسالة اليوم',
                        child: Icon(
                          Icons.fullscreen_rounded,
                          size: 20,
                          color: palette.goldText,
                        ),
                      ),
                      TapTarget(
                        onTap: () => _copyText(
                          '« ${insight.message} »\n— طيّب قلبك 🌿',
                        ),
                        semanticLabel: 'نسخ الرسالة',
                        child: Icon(
                          Icons.copy_rounded,
                          size: 18,
                          color: palette.goldText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHadithsList(List<Hadith> items) {
    if (items.isEmpty) {
      return const AppEmptyState(
        icon: Icons.menu_book_rounded,
        title: 'لا توجد أحاديث محفوظة بعد',
        subtitle:
            'تصفح قائمة الأربعين النووية واضغط على علامة المفضلة لأي حديث لتحفظه هنا وتصل إليه سريعاً.',
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        20, 4, 20, 30 + BottomNavigation.reservedHeight(context),
      ),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final hadith = items[index];
        final palette = context.palette;

        return ParchmentCard(
          padding: const EdgeInsets.all(16),
          showCornerOrnaments: false,
          showWatermark: false,
          onTap: () => Navigator.push(
            context,
            SmoothPageRoute(child: HadithDetailScreen(hadith: hadith)),
          ),
          semanticLabel: 'الحديث ${toArabicDigits(hadith.number)}: ${hadith.title}',
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.surface,
                  border: Border.all(color: palette.cardBorderStrong),
                ),
                child: Text(
                  toArabicDigits(hadith.number),
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 16,
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
                      hadith.title,
                      style: TextStyle(
                        fontFamily: kSans,
                        fontSize: 15,
                        height: AppLeading.chrome,
                        fontWeight: FontWeight.w700,
                        color: palette.bodyText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hadith.reference,
                      style: TextStyle(
                        fontFamily: kSans,
                        fontSize: 12,
                        height: AppLeading.chrome,
                        color: palette.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              TapTarget(
                onTap: () => setState(
                  () => _repo.toggleFavoriteHadith(hadith.number),
                ),
                semanticLabel: 'إزالة الحديث من المفضلة',
                toggled: true,
                child: const Icon(
                  Icons.bookmark_remove_rounded,
                  size: 22,
                  color: Color(0xFFB3261E),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return TapTarget(
      onTap: onTap,
      semanticLabel: title,
      selected: isSelected,
      minSize: 44,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? palette.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          boxShadow: isSelected ? AppElevation.card : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? palette.goldText : palette.mutedText,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: kSans,
                  fontSize: 13,
                  height: AppLeading.chrome,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? palette.bodyText : palette.mutedText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: palette.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.eco_rounded, size: 12, color: palette.goldText),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: kSans,
              fontSize: 11,
              height: AppLeading.chrome,
              fontWeight: FontWeight.w700,
              color: palette.goldText,
            ),
          ),
        ],
      ),
    );
  }
}

