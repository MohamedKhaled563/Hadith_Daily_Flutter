import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_motion.dart';
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

  /// Typing rebuilt the whole list on every keystroke. Fine over 42 bundled
  /// hadiths, wrong the moment the corpus grows, and it also means the
  /// result count flickers while the reader is mid-word.
  Timer? _searchDebounce;

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _searchQuery = value);
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    // Clear the field as well as the filter — previously only the filter reset,
    // leaving the typed text stranded in the box.
    _searchDebounce?.cancel();
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
              padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
              // A pill, not a 20px rounded rectangle. It used to be the
              // card's own shape, fill and hairline — and in dark mode
              // surfaceSunken and the card gradient sit within a few points
              // of each other — so the one control on this screen that wants
              // to be typed in looked like the things below it that want to
              // be read. The pill is already this app's shape for a control
              // (the sort toggle, the category pills); the cards keep 20px.
              decoration: BoxDecoration(
                color: palette.surfaceSunken,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(
                  color: palette.cardBorderStrong,
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 20, color: palette.goldText),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      textInputAction: TextInputAction.search,
                      // The keyboard's search key used to dismiss and do
                      // nothing; now it commits immediately rather than
                      // waiting out the debounce.
                      onSubmitted: (value) {
                        _searchDebounce?.cancel();
                        setState(() => _searchQuery = value);
                        FocusScope.of(context).unfocus();
                      },
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

          if (_searchQuery.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              displayed.isEmpty
                  ? 'لا نتائج'
                  : '${toArabicDigits(displayed.length)} من '
                      '${toArabicDigits(_repo.getAll().length)}',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(color: palette.goldText),
            ),
          ],

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
                    actionIcon: Icons.refresh_rounded,
                  )
                : ListView.separated(
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
                            appPageRoute(
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
                  // The badge itself is a fixed gold seal in both themes,
                  // deliberately. Its rim is not: a white ring separates the
                  // seal from parchment, but on a night card the seal is
                  // already the brightest thing there and a white rim reads
                  // as a halo around it rather than an edge to it.
                  border: Border.all(
                    color: context.isDarkMode
                        ? palette.cardBorderStrong
                        : Colors.white.withValues(alpha: 0.8),
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
                onTap: () {
                  AppHaptics.toggle();
                  onToggleFavorite();
                },
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
              // Prefer who extracted/collected the hadith (المخرج) when the
              // workbook has one — it's more specific to this hadith than
              // the generic "من الأربعين النووية" fallback `hadith.reference`
              // carries when no explicit source/reference was given.
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hadith.mukhrij.isNotEmpty) ...[
                      Icon(
                        Icons.menu_book_rounded,
                        size: 13,
                        color: palette.goldText,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        hadith.mukhrij.isNotEmpty
                            ? hadith.mukhrij
                            : hadith.reference,
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
                  ],
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

