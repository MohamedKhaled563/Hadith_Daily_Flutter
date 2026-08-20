import 'package:flutter/material.dart';
import '../../data/hadith_repository.dart';
import '../../models/hadith.dart';
import '../../services/daily_hadith_service.dart';
import '../../services/favorites_service.dart';
import '../../services/share_service.dart';
import '../theme/app_theme.dart';
import '../widgets/hadith_card.dart';
import 'hadith_details_screen.dart';
import 'favorites_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Hadith> _hadiths = [];
  bool _loading = true;
  int _currentIndex = 0;
  final Set<int> _favoriteNumbers = {};

  @override
  void initState() {
    super.initState();
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
  }

  Hadith get _current => _hadiths[_currentIndex];

  Future<void> _toggleFavorite() async {
    final nowFav = await FavoritesService.instance.toggle(_current.number);
    setState(() {
      if (nowFav) {
        _favoriteNumbers.add(_current.number);
      } else {
        _favoriteNumbers.remove(_current.number);
      }
    });
  }

  Future<void> _share() async {
    await ShareService.shareWidgetAsImage(
      widget: SizedBox(width: 360, child: HadithCard(hadith: _current)),
      fileName: 'hadith_${_current.number}',
      text: _current.text,
    );
  }

  void _openMeaning() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HadithDetailsScreen(hadith: _current)),
    );
  }

  /// "Another message" — like the reference app, picks a different
  /// random hadith to show right now (separate from "today's" fixed pick).
  void _showAnother() {
    setState(() {
      final next = (_currentIndex + 1 + (_hadiths.length > 1 ? 0 : 0)) % _hadiths.length;
      _currentIndex = next == _currentIndex && _hadiths.length > 1
          ? (next + 1) % _hadiths.length
          : next;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {},
        ),
        title: const Text('رسالة اليوم'),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FavoritesScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Text(
                'رسالة يومية من أحاديث الأربعين النووية\nتلامس قلبك وترافق يومك',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: _openMeaning,
                child: HadithCard(hadith: _current),
              ),
              const SizedBox(height: 28),
              _ActionRow(
                isFavorite: _favoriteNumbers.contains(_current.number),
                onFavorite: _toggleFavorite,
                onShare: _share,
                onMeaning: _openMeaning,
                onAnother: _showAnother,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onShare;
  final VoidCallback onMeaning;
  final VoidCallback onAnother;

  const _ActionRow({
    required this.isFavorite,
    required this.onFavorite,
    required this.onShare,
    required this.onMeaning,
    required this.onAnother,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ActionItem(
          icon: isFavorite ? Icons.favorite : Icons.favorite_border,
          label: 'احفظ',
          active: isFavorite,
          onTap: onFavorite,
        ),
        _ActionItem(icon: Icons.ios_share_outlined, label: 'شارك', onTap: onShare),
        _ActionItem(icon: Icons.menu_book_outlined, label: 'اعرف المعنى', onTap: onMeaning),
        _ActionItem(icon: Icons.refresh, label: 'رسالة أخرى', onTap: onAnother),
      ],
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = active ? AppColors.heart : theme.colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(label, style: theme.textTheme.labelLarge?.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
