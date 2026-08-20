import 'package:flutter/material.dart';
import '../data/hadith_repository.dart';
import '../models/hadith.dart';
import '../services/favorites_service.dart';
import 'hadith_details_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Hadith> _favorites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await HadithRepository.instance.loadAll();
    final favNumbers = await FavoritesService.instance.getAll();
    if (!mounted) return;
    setState(() {
      _favorites = all.where((h) => favNumbers.contains(h.number)).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
          children: [
            Text('المحفوظات', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              _favorites.isEmpty ? 'احتفظ بالأحاديث التي تريد الرجوع إليها لاحقًا.' : '${_arabicDigits(_favorites.length)} أحاديث محفوظة',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 22),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_favorites.isEmpty)
              const _EmptyFavorites()
            else
              ..._favorites.map((hadith) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _FavoriteCard(
                      hadith: hadith,
                      onOpen: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => HadithDetailsScreen(hadith: hadith)),
                        );
                        _load();
                      },
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  final Hadith hadith;
  final VoidCallback onOpen;

  const _FavoriteCard({required this.hadith, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.09),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(_arabicDigits(hadith.number), style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hadith.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 7),
                    Text(
                      hadith.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.favorite_rounded, size: 15, color: theme.colorScheme.primary),
                        const SizedBox(width: 5),
                        Text('محفوظ', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
                        const Spacer(),
                        const Icon(Icons.chevron_left_rounded, size: 20),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


String _arabicDigits(int value) {
  const western = '0123456789';
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  return value.toString().split('').map((d) => arabic[western.indexOf(d)]).join();
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 70),
      child: Column(
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.09),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.favorite_border_rounded, size: 42, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 22),
          Text('لسه مفيش أحاديث محفوظة', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'لما تلاقي حديث تحب ترجع له، احفظه من علامة القلب وهيظهر هنا.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
