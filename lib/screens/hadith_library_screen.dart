import 'package:flutter/material.dart';
import '../data/hadith_repository.dart';
import '../models/hadith.dart';
import '../services/daily_habit_service.dart';
import 'hadith_details_screen.dart';

class HadithLibraryScreen extends StatefulWidget {
  const HadithLibraryScreen({super.key});

  @override
  State<HadithLibraryScreen> createState() => _HadithLibraryScreenState();
}

class _HadithLibraryScreenState extends State<HadithLibraryScreen> {
  final _searchController = TextEditingController();
  List<Hadith> _all = [];
  List<Hadith> _filtered = [];
  List<Hadith> _recent = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filter);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final hadiths = await HadithRepository.instance.loadAll();
    final historyNumbers = await DailyHabitService.instance.getHistoryNumbers();
    final byNumber = {for (final h in hadiths) h.number: h};
    final recent = historyNumbers.map((n) => byNumber[n]).whereType<Hadith>().toList();
    if (!mounted) return;
    setState(() {
      _all = hadiths;
      _filtered = hadiths;
      _recent = recent;
      _loading = false;
    });
  }

  void _filter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? _all
          : _all.where((h) {
              return h.title.toLowerCase().contains(query) ||
                  h.text.toLowerCase().contains(query) ||
                  (h.source?.toLowerCase().contains(query) ?? false);
            }).toList();
    });
  }

  void _open(Hadith hadith) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => HadithDetailsScreen(hadith: hadith)))
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());

    final searching = _searchController.text.trim().isNotEmpty;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Text('الأحاديث', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text('الأربعون النووية', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'ابحث في الأحاديث...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: searching
                    ? IconButton(
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.close_rounded),
                      )
                    : null,
              ),
            ),
            if (!searching && _recent.isNotEmpty) ...[
              const SizedBox(height: 22),
              _SectionHeading(
                title: 'آخر ما قرأت',
                trailing: 'عرض ${_recent.length}',
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 116,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  itemCount: _recent.length.clamp(0, 6).toInt(),
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, index) {
                    final hadith = _recent[index];
                    return _RecentCard(hadith: hadith, onTap: () => _open(hadith));
                  },
                ),
              ),
            ],
            const SizedBox(height: 22),
            _SectionHeading(
              title: searching ? 'نتائج البحث' : 'جميع الأحاديث',
              trailing: '${_arabicDigits(_filtered.length)} حديث',
            ),
            const SizedBox(height: 10),
            if (_filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 50),
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded, size: 42, color: theme.colorScheme.primary.withValues(alpha: .55)),
                    const SizedBox(height: 12),
                    Text('لا توجد أحاديث مطابقة', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('جرّب كلمة مختلفة أو جزءًا من نص الحديث.', style: theme.textTheme.bodyMedium),
                  ],
                ),
              )
            else
              ..._filtered.map((hadith) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _LibraryTile(hadith: hadith, onTap: () => _open(hadith)),
                  )),
          ],
        ),
      ),
    );
  }

  static String _arabicDigits(int value) {
    const western = '0123456789';
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    return value.toString().split('').map((d) => arabic[western.indexOf(d)]).join();
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String trailing;
  const _SectionHeading({required this.title, required this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
        Text(trailing, style: theme.textTheme.labelMedium),
      ],
    );
  }
}

class _RecentCard extends StatelessWidget {
  final Hadith hadith;
  final VoidCallback onTap;
  const _RecentCard({required this.hadith, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primary.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: 220,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('حديث ${_arabic(hadith.number)}', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
                const SizedBox(height: 7),
                Text(hadith.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                const SizedBox(height: 5),
                Expanded(child: Text(hadith.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _arabic(int value) {
    const western = '0123456789';
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    return value.toString().split('').map((d) => arabic[western.indexOf(d)]).join();
  }
}

class _LibraryTile extends StatelessWidget {
  final Hadith hadith;
  final VoidCallback onTap;
  const _LibraryTile({required this.hadith, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: .10),
                  shape: BoxShape.circle,
                ),
                child: Text('${hadith.number}', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hadith.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(hadith.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                    if (hadith.source != null) ...[
                      const SizedBox(height: 8),
                      Text(hadith.source!, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelMedium),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_left_rounded, color: theme.textTheme.bodyMedium?.color),
            ],
          ),
        ),
      ),
    );
  }
}
