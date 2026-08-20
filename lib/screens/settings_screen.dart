import 'package:flutter/material.dart';
import '../services/app_preferences_service.dart';
import '../services/notification_service.dart';
import '../theme/theme_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  String _themeMode = 'system';
  String _shareStyle = 'cream';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = AppPreferencesService.instance;
    final time = await prefs.getReminderTime();
    final enabled = await prefs.isReminderEnabled();
    if (!mounted) return;
    setState(() {
      _reminderEnabled = enabled;
      _reminderTime = TimeOfDay(hour: time.hour, minute: time.minute);
    });
    _themeMode = await prefs.getThemeMode();
    _shareStyle = await prefs.getShareStyle();
    if (mounted) setState(() {});
  }

  Future<void> _setReminder(bool value) async {
    final prefs = AppPreferencesService.instance;
    if (value) {
      final granted = await NotificationService.instance.requestPermission();
      if (!granted) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اسمح بالإشعارات من إعدادات الجهاز أولًا.')));
        return;
      }
      await NotificationService.instance.scheduleDaily(hour: _reminderTime.hour, minute: _reminderTime.minute);
    } else {
      await NotificationService.instance.cancelDaily();
    }
    await prefs.setReminderEnabled(value);
    if (mounted) setState(() => _reminderEnabled = value);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _reminderTime);
    if (picked == null) return;
    setState(() => _reminderTime = picked);
    await AppPreferencesService.instance.setReminderTime(picked.hour, picked.minute);
    if (_reminderEnabled) {
      await NotificationService.instance.scheduleDaily(hour: picked.hour, minute: picked.minute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
        children: [
          Text('الإعدادات', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text('خلي التجربة على مزاجك، من غير ما نزحمها.', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 24),
          const _SectionTitle(title: 'التذكير اليومي'),
          _SettingTile(icon: Icons.notifications_active_outlined, title: 'حديثك اليومي', subtitle: _reminderEnabled ? 'يومياً الساعة ${_reminderTime.format(context)}' : 'موقوف حالياً', trailing: Switch(value: _reminderEnabled, onChanged: _setReminder)),
          if (_reminderEnabled) _SettingTile(icon: Icons.schedule_rounded, title: 'وقت التذكير', subtitle: 'اختار الوقت الأنسب لك', trailing: Text(_reminderTime.format(context), style: theme.textTheme.titleMedium), onTap: _pickTime),
          const SizedBox(height: 14),
          const _SectionTitle(title: 'المظهر'),
          _SettingTile(icon: Icons.palette_outlined, title: 'المظهر', subtitle: _themeLabel, trailing: const Icon(Icons.chevron_left_rounded), onTap: _pickTheme),
          const SizedBox(height: 14),
          const _SectionTitle(title: 'المشاركة'),
          _SettingTile(icon: Icons.ios_share_rounded, title: 'التصميم الافتراضي', subtitle: _shareStyleLabel, trailing: const Icon(Icons.chevron_left_rounded), onTap: _pickShareStyle),
          const SizedBox(height: 14),
          const _SectionTitle(title: 'عن التطبيق'),
          const _SettingTile(icon: Icons.menu_book_outlined, title: 'الأربعون النووية', subtitle: 'قراءة يومية هادئة مع شرح ومشاركة.', trailing: Icon(Icons.chevron_left_rounded)),
          const _SettingTile(icon: Icons.info_outline_rounded, title: 'Hadith Daily', subtitle: 'نسخة أولية من تجربة التطبيق', trailing: Icon(Icons.chevron_left_rounded)),
        ],
      ),
    );
  }

  String get _themeLabel => switch (_themeMode) { 'light' => 'فاتح', 'dark' => 'داكن', _ => 'حسب الجهاز' };
  String get _shareStyleLabel => switch (_shareStyle) { 'forest' => 'الأخضر الهادئ', 'midnight' => 'المساء', _ => 'الورق الكريمي' };

  Future<void> _pickTheme() async {
    final value = await showModalBottomSheet<String>(context: context, showDragHandle: true, builder: (context) => Column(mainAxisSize: MainAxisSize.min, children: ['system', 'light', 'dark'].map((v) => ListTile(title: Text(switch (v) { 'light' => 'فاتح', 'dark' => 'داكن', _ => 'حسب الجهاز' }), trailing: _themeMode == v ? const Icon(Icons.check) : null, onTap: () => Navigator.pop(context, v))).toList()));
    if (value == null) return;
    await AppPreferencesService.instance.setThemeMode(value);
    ThemeController.instance.set(value);
    if (mounted) setState(() => _themeMode = value);
  }

  Future<void> _pickShareStyle() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _shareChoice(context, 'cream', 'الورق الكريمي'),
            _shareChoice(context, 'forest', 'الأخضر الهادئ'),
            _shareChoice(context, 'midnight', 'المساء'),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (value == null) return;
    await AppPreferencesService.instance.setShareStyle(value);
    if (mounted) setState(() => _shareStyle = value);
  }

  Widget _shareChoice(BuildContext context, String value, String label) {
    return ListTile(
      title: Text(label),
      trailing: _shareStyle == value ? Icon(Icons.check_rounded, color: Theme.of(context).colorScheme.primary) : null,
      onTap: () => Navigator.pop(context, value),
    );
  }
}

class _SectionTitle extends StatelessWidget { final String title; const _SectionTitle({required this.title}); @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6), child: Text(title, style: Theme.of(context).textTheme.labelLarge)); }

class _SettingTile extends StatelessWidget {
  final IconData icon; final String title; final String subtitle; final Widget trailing; final VoidCallback? onTap;
  const _SettingTile({required this.icon, required this.title, required this.subtitle, required this.trailing, this.onTap});
  @override Widget build(BuildContext context) { final theme = Theme.of(context); return Container(margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: theme.dividerColor)), child: ListTile(onTap: onTap, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: theme.colorScheme.primary, size: 20)), title: Text(title, style: theme.textTheme.titleMedium), subtitle: Text(subtitle, style: theme.textTheme.bodyMedium), trailing: trailing)); }
}
