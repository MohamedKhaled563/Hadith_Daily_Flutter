import 'package:flutter/material.dart';
import '../data/hadith_repository.dart';
import '../models/hadith.dart';
import '../services/daily_hadith_service.dart';
import '../services/daily_habit_service.dart';
import '../services/favorites_service.dart';
import '../widgets/share_template_picker.dart';
import '../widgets/hadith_card.dart';
import 'hadith_details_screen.dart';

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
  int _streak = 0;
  bool _justMarkedToday = false;
  List<bool> _weekStatus = List<bool>.filled(7, false);
  final Set<int> _favoriteNumbers = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.93);
    _init();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final all = await HadithRepository.instance.loadAll();
    final today = await DailyHadithService.getForToday();
    final favorites = await FavoritesService.instance.getAll();
    final habit = DailyHabitService.instance;
    final streak = await habit.getCurrentStreak();
    final week = await habit.getLast7DaysStatus();
    final startIndex = all.indexWhere((h) => h.number == today.number);
    final alreadyRead = await habit.hasReadToday();

    if (!mounted) return;
    setState(() {
      _hadiths = all;
      _currentIndex = startIndex >= 0 ? startIndex : 0;
      _favoriteNumbers
        ..clear()
        ..addAll(favorites);
      _streak = streak;
      _weekStatus = week;
      _justMarkedToday = alreadyRead;
      _loading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentIndex);
      }
    });
  }

  Future<void> _toggleFavorite(Hadith hadith) async {
    final nowFav = await FavoritesService.instance.toggle(hadith.number);
    if (!mounted) return;
    setState(() {
      if (nowFav) {
        _favoriteNumbers.add(hadith.number);
      } else {
        _favoriteNumbers.remove(hadith.number);
      }
    });
  }

  Future<void> _openDetails(Hadith hadith) async {
    await DailyHabitService.instance.markRead(hadithNumber: hadith.number);
    if (!mounted) return;
    final streak = await DailyHabitService.instance.getCurrentStreak();
    final week = await DailyHabitService.instance.getLast7DaysStatus();
    if (!mounted) return;
    setState(() {
      _streak = streak;
      _weekStatus = week;
      _justMarkedToday = true;
    });
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HadithDetailsScreen(hadith: hadith)),
    );
  }

  Future<void> _share(Hadith hadith) => showShareTemplatePicker(context, hadith);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final currentHadith = _hadiths[_currentIndex];
    final dateLabel = _arabicDate(DateTime.now());

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _init,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('حديثك اليوم', style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Text(dateLabel, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
                _StreakBadge(streak: _streak),
              ],
            ),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _justMarkedToday
                  ? Container(
                      key: const ValueKey('read'),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: .07),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: .10)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 17, color: theme.colorScheme.primary),
                          const SizedBox(width: 7),
                          Expanded(child: Text('قرأته اليوم. ربنا يرزقك العمل به 🌿', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary))),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('empty')),
            ),
            Row(
              children: [
                Text('${_toArabicDigits(_currentIndex + 1)} / ${_toArabicDigits(_hadiths.length)}', style: theme.textTheme.labelMedium),
                const Spacer(),
                Icon(Icons.swipe_rounded, size: 14, color: theme.textTheme.labelMedium?.color),
                const SizedBox(width: 5),
                Text('اسحب لاستكشاف المزيد', style: theme.textTheme.labelMedium),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 405,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _hadiths.length,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (context, index) {
                  final hadith = _hadiths[index];
                  final isSelected = index == _currentIndex;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      scale: isSelected ? 1 : .97,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 220),
                        opacity: isSelected ? 1 : .80,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _openDetails(hadith),
                          child: HadithCard(hadith: hadith, showNumber: false),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            _HomeActions(
              isFavorite: _favoriteNumbers.contains(currentHadith.number),
              onFavorite: () => _toggleFavorite(currentHadith),
              onShare: () => _share(currentHadith),
              onMeaning: () => _openDetails(currentHadith),
            ),
            const SizedBox(height: 12),
            _JourneyCard(streak: _streak, weekStatus: _weekStatus),
            const SizedBox(height: 12),
            Center(
              child: Text('خذ لحظة لفهم المعنى، ثم عد غدًا لحديث جديد.', style: theme.textTheme.labelMedium, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }

  static String _arabicDate(DateTime date) {
    const weekdays = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    const months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    return '${weekdays[date.weekday - 1]}، ${_toArabicDigits(date.day)} ${months[date.month - 1]}';
  }

  static String _toArabicDigits(int value) {
    const western = '0123456789';
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    return value.toString().split('').map((digit) => arabic[western.indexOf(digit)]).join();
  }
}

class _StreakBadge extends StatelessWidget {
  final int streak;
  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 5),
          Text(_arabic, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(width: 3),
          Text('يوم', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
        ],
      ),
    );
  }

  String get _arabic {
    const digits = '٠١٢٣٤٥٦٧٨٩';
    return streak.toString().split('').map((d) => digits[int.parse(d)]).join();
  }
}

class _HomeActions extends StatelessWidget {
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onShare;
  final VoidCallback onMeaning;

  const _HomeActions({required this.isFavorite, required this.onFavorite, required this.onShare, required this.onMeaning});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 2),
      child: Row(
        children: [
          Expanded(child: _ActionChip(icon: isFavorite ? Icons.favorite : Icons.favorite_border, label: isFavorite ? 'محفوظ' : 'حفظ', active: isFavorite, onTap: onFavorite)),
          const SizedBox(width: 10),
          Expanded(child: _ActionChip(icon: Icons.ios_share_outlined, label: 'مشاركة', onTap: onShare)),
          const SizedBox(width: 10),
          Expanded(child: _ActionChip(icon: Icons.menu_book_outlined, label: 'الشرح', filled: true, onTap: onMeaning)),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool filled;
  final VoidCallback onTap;

  const _ActionChip({required this.icon, required this.label, required this.onTap, this.active = false, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Material(
      color: filled || active ? primary.withValues(alpha: 0.10) : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: filled || active ? primary.withValues(alpha: 0.12) : theme.dividerColor)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: active ? Colors.red.shade700 : primary),
              const SizedBox(width: 7),
              Text(label, style: theme.textTheme.labelLarge?.copyWith(color: primary)),
            ],
          ),
        ),
      ),
    );
  }
}


class _JourneyCard extends StatelessWidget {
  final int streak;
  final List<bool> weekStatus;
  const _JourneyCard({required this.streak, required this.weekStatus});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const labels = ['س', 'ح', 'ن', 'ث', 'ر', 'خ', 'ج'];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('رحلتك هذا الأسبوع', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  streak > 0 ? 'مستمر بقالك ${_arabic(streak)} يوم — كمل' : 'ابدأ يومك بحديث واحد',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Row(
            children: List.generate(7, (i) {
              final filled = i < weekStatus.length && weekStatus[i];
              return Padding(
                padding: EdgeInsets.only(right: i == 6 ? 0 : 5),
                child: Column(
                  children: [
                    Text(labels[i], style: theme.textTheme.labelSmall),
                    const SizedBox(height: 5),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: filled ? theme.colorScheme.primary : theme.colorScheme.primary.withValues(alpha: .08),
                        shape: BoxShape.circle,
                      ),
                      child: filled ? Icon(Icons.check_rounded, size: 14, color: theme.colorScheme.onPrimary) : null,
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  static String _arabic(int value) {
    const western = '0123456789';
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    return value.toString().split('').map((d) => arabic[western.indexOf(d)]).join();
  }
}
