import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/arabic_numerals.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/circle_icon_button.dart';
import '../../core/widgets/parchment_card.dart';
import '../../core/widgets/smooth_page_route.dart';
import '../../core/widgets/tap_target.dart';
import '../../data/models/hadith.dart';
import '../../data/repositories/hadith_repository.dart';
import 'hadith_detail_screen.dart';

class HadithListScreen extends StatefulWidget {
  const HadithListScreen({super.key});

  @override
  State<HadithListScreen> createState() => _HadithListScreenState();
}

class _HadithListScreenState extends State<HadithListScreen> {
  final HadithRepository _repo = HadithRepository();
  final TextEditingController _searchController = TextEditingController();

  bool _showOnlyFavorites = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    // Clear the field as well as the filter — previously only the filter reset,
    // leaving the typed text stranded in the box.
    _searchController.clear();
    setState(() => _searchQuery = '');
    FocusScope.of(context).unfocus();
  }

  List<Hadith> get _displayed {
    final query = _searchQuery.trim().toLowerCase();

    return _repo.getAll().where((h) {
      if (_showOnlyFavorites && !_repo.isHadithFavorite(h.number)) return false;
      if (query.isEmpty) return true;
      return h.title.toLowerCase().contains(query) ||
          h.text.toLowerCase().contains(query) ||
          h.number.toString().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final displayed = _displayed;

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
                const EmblemBadge(),
                // filter_alt rather than the bookmark glyph used per-item
                // below — the same icon for "filter the list" and "save this
                // hadith" on one screen read as if this saved the whole list.
                CircleIconButton(
                  icon: Icons.filter_alt_rounded,
                  semanticLabel: _showOnlyFavorites
                      ? 'عرض جميع الأحاديث'
                      : 'عرض المحفوظات فقط',
                  toggled: _showOnlyFavorites,
                  iconColor: _showOnlyFavorites ? palette.goldText : null,
                  onTap: () => setState(
                    () => _showOnlyFavorites = !_showOnlyFavorites,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          Semantics(
            header: true,
            child: Text(
              _showOnlyFavorites ? 'الأحاديث المحفوظة 🌿' : 'الأربعين النووية',
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _showOnlyFavorites
                  ? 'الأحاديث التي قمت بحفظها للمراجعة والتأمل'
                  : 'جامع جوامع الكلم وهدايات النبوة الشريفة',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall,
            ),
          ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsetsDirectional.only(start: 14, end: 4),
              decoration: BoxDecoration(
                color: palette.surfaceSunken,
                borderRadius: BorderRadius.circular(AppRadii.listItem),
                border: Border.all(color: palette.cardBorder, width: 1.2),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 20, color: palette.goldText),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      textInputAction: TextInputAction.search,
                      style: TextStyle(
                        fontFamily: kSans,
                        fontSize: 13.5,
                        color: palette.bodyText,
                      ),
                      decoration: InputDecoration(
                        hintText: 'ابحث برقم الحديث أو عنوانه أو كلماته...',
                        hintStyle: TextStyle(
                          fontFamily: kSans,
                          fontSize: 13,
                          color: palette.mutedText,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    TapTarget(
                      onTap: _clearSearch,
                      semanticLabel: 'مسح البحث',
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: palette.mutedText,
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          Expanded(
            child: displayed.isEmpty
                ? AppEmptyState(
                    icon: _showOnlyFavorites
                        ? Icons.bookmark_border_rounded
                        : Icons.search_off_rounded,
                    title: _showOnlyFavorites
                        ? 'لا توجد أحاديث محفوظة بعد'
                        : 'لم يتم العثور على نتائج',
                    subtitle: _showOnlyFavorites
                        ? 'اضغط على علامة المفضلة في أي حديث لتحفظه هنا وتصل إليه سريعاً.'
                        : 'جرّب كلمة أخرى، أو ابحث برقم الحديث من ١ إلى ٤٢.',
                    actionLabel: _searchQuery.isNotEmpty ? 'مسح البحث' : null,
                    onAction: _searchQuery.isNotEmpty ? _clearSearch : null,
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      20, 4, 20, 16 + MediaQuery.viewPaddingOf(context).bottom,
                    ),
                    itemCount: displayed.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final hadith = displayed[index];
                      return _HadithListCard(
                        hadith: hadith,
                        isFavorite: _repo.isHadithFavorite(hadith.number),
                        onToggleFavorite: () => setState(
                          () => _repo.toggleFavoriteHadith(hadith.number),
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            SmoothPageRoute(
                              child: HadithDetailScreen(hadith: hadith),
                            ),
                          );
                          if (mounted) setState(() {});
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _HadithListCard extends StatelessWidget {
  const _HadithListCard({
    required this.hadith,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final Hadith hadith;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ParchmentCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      showCornerOrnaments: false,
      showWatermark: false,
      onTap: onTap,
      semanticLabel: 'الحديث ${toArabicDigits(hadith.number)}: ${hadith.title}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEADBBE), Color(0xFFC7A566)],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                child: Text(
                  toArabicDigits(hadith.number),
                  style: const TextStyle(
                    fontFamily: kSans,
                    fontSize: 13,
                    height: AppLeading.chrome,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF26352C),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hadith.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 15,
                    height: AppLeading.chrome,
                    fontWeight: FontWeight.w700,
                    color: palette.bodyText,
                  ),
                ),
              ),
              // Now an actual control: previously a bare Icon, so there was no
              // way to unfavourite from the list at all.
              TapTarget(
                onTap: onToggleFavorite,
                semanticLabel: 'حفظ الحديث في المفضلة',
                toggled: isFavorite,
                child: Icon(
                  isFavorite
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: 22,
                  color: isFavorite
                      ? palette.goldText
                      : palette.mutedText,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            hadith.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.start,
            style: AppTextStyles.hadithText.copyWith(
              fontSize: 15,
              color: palette.mutedText,
            ),
          ),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  hadith.reference,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 11.5,
                    height: AppLeading.chrome,
                    fontWeight: FontWeight.w600,
                    color: palette.goldText,
                  ),
                ),
              ),
              // chevron_left points "forward" under RTL.
              Icon(
                Icons.chevron_left_rounded,
                size: 22,
                color: palette.mutedText,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

