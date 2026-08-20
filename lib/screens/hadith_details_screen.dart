import 'package:flutter/material.dart';
import '../models/hadith.dart';
import '../services/favorites_service.dart';
import '../services/daily_habit_service.dart';
import '../widgets/share_template_picker.dart';
import '../widgets/hadith_card.dart';

class HadithDetailsScreen extends StatefulWidget {
  final Hadith hadith;
  const HadithDetailsScreen({super.key, required this.hadith});

  @override
  State<HadithDetailsScreen> createState() => _HadithDetailsScreenState();
}

class _HadithDetailsScreenState extends State<HadithDetailsScreen> {
  bool _isFavorite = false;
  bool _loadingFavorite = true;

  @override
  void initState() {
    super.initState();
    _loadFavorite();
    DailyHabitService.instance.markRead(hadithNumber: widget.hadith.number);
  }

  Future<void> _loadFavorite() async {
    final favorite = await FavoritesService.instance.isFavorite(widget.hadith.number);
    if (!mounted) return;
    setState(() {
      _isFavorite = favorite;
      _loadingFavorite = false;
    });
  }

  Future<void> _toggleFavorite() async {
    final next = await FavoritesService.instance.toggle(widget.hadith.number);
    if (!mounted) return;
    setState(() => _isFavorite = next);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(next ? 'تم حفظ الحديث في المحفوظات' : 'تمت إزالة الحديث من المحفوظات'),
        duration: const Duration(milliseconds: 1400),
      ),
    );
  }

  Future<void> _share() => showShareTemplatePicker(context, widget.hadith);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hadith = widget.hadith;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'رجوع',
        ),
        title: const Text('تفاصيل الحديث'),
        actions: [
          IconButton(
            onPressed: _loadingFavorite ? null : _toggleFavorite,
            icon: Icon(
              _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: _isFavorite ? theme.colorScheme.primary : null,
            ),
            tooltip: 'حفظ',
          ),
          IconButton(
            onPressed: _share,
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'مشاركة',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _IntroHeader(number: hadith.number, title: hadith.title),
            const SizedBox(height: 16),
            HadithCard(hadith: hadith, showNumber: false),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    label: _isFavorite ? 'محفوظ' : 'حفظ الحديث',
                    filled: _isFavorite,
                    onTap: _toggleFavorite,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.ios_share_rounded,
                    label: 'مشاركة',
                    onTap: _share,
                  ),
                ),
              ],
            ),
            if (hadith.explanation.isNotEmpty) ...[
              const SizedBox(height: 30),
              Text('افهم أكثر', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'شرح الحديث والفوائد المستفادة منه',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Text(hadith.explanation, style: theme.textTheme.bodyLarge?.copyWith(fontSize: 18)),
              ),
            ],
            const SizedBox(height: 26),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'خذ لحظة لفهم المعنى، ثم ارجع غدًا لحديث جديد.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroHeader extends StatelessWidget {
  final int number;
  final String title;

  const _IntroHeader({required this.number, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text('$number', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: filled ? theme.colorScheme.primary : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: filled ? Colors.transparent : theme.dividerColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: filled ? theme.colorScheme.onPrimary : theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: filled ? theme.colorScheme.onPrimary : theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
