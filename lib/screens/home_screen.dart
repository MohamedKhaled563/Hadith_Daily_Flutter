import 'package:flutter/material.dart';
import '../data/hadith_repository.dart';
import '../models/hadith.dart';
import '../services/daily_hadith_service.dart';
import '../services/favorites_service.dart';
import '../services/share_service.dart';
import '../widgets/hadith_card.dart';
import 'hadith_details_screen.dart';
import 'favorites_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final PageController _pageController;
  List<Hadith> _hadiths = [];
  bool _loading = true;
  int _currentIndex = 0;
  final Set<int> _favoriteNumbers = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _init();
  }

  Future<void> _init() async {
    final all = await HadithRepository.instance.loadAll();
    final today = await DailyHadithService.getForToday();
    final favorites = await FavoritesService.instance.getAll();
    final startIndex = all.indexWhere((h) => h.number == today.number);

    setState(() {
      _hadiths = all;
      _currentIndex = startIndex >= 0 ? startIndex : 0;
      _favoriteNumbers
        ..clear()
        ..addAll(favorites);
      _loading = false;
    });

    // Jump to today's hadith once the PageView has laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentIndex);
      }
    });
  }

  Future<void> _toggleFavorite(Hadith hadith) async {
    final nowFav = await FavoritesService.instance.toggle(hadith.number);
    setState(() {
      if (nowFav) {
        _favoriteNumbers.add(hadith.number);
      } else {
        _favoriteNumbers.remove(hadith.number);
      }
    });
  }

  Future<void> _share(Hadith hadith) async {
    await ShareService.shareWidgetAsImage(
      widget: SizedBox(
        width: 360,
        child: HadithCard(hadith: hadith),
      ),
      fileName: 'hadith_${hadith.number}',
      text: '${hadith.title} — ${hadith.text}',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('الأربعون النووية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border),
            tooltip: 'المفضلة',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FavoritesScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Text(
                '${_currentIndex + 1} / ${_hadiths.length}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _hadiths.length,
                onPageChanged: (i) => setState(() => _currentIndex = i),
                itemBuilder: (context, index) {
                  final hadith = _hadiths[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SingleChildScrollView(
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => HadithDetailsScreen(hadith: hadith),
                          ),
                        ),
                        child: HadithCard(hadith: hadith),
                      ),
                    ),
                  );
                },
              ),
            ),
            _ActionBar(
              isFavorite:
                  _favoriteNumbers.contains(_hadiths[_currentIndex].number),
              onFavorite: () => _toggleFavorite(_hadiths[_currentIndex]),
              onShare: () => _share(_hadiths[_currentIndex]),
              onMeaning: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      HadithDetailsScreen(hadith: _hadiths[_currentIndex]),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onShare;
  final VoidCallback onMeaning;

  const _ActionBar({
    required this.isFavorite,
    required this.onFavorite,
    required this.onShare,
    required this.onMeaning,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionButton(
            icon: isFavorite ? Icons.favorite : Icons.favorite_border,
            label: 'احفظ',
            active: isFavorite,
            onTap: onFavorite,
          ),
          _ActionButton(
            icon: Icons.ios_share,
            label: 'شارك',
            onTap: onShare,
          ),
          _ActionButton(
            icon: Icons.menu_book_outlined,
            label: 'الشرح',
            onTap: onMeaning,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        active ? theme.colorScheme.secondary : theme.colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
