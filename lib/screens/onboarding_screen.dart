import 'package:flutter/material.dart';
import '../services/app_preferences_service.dart';
import '../services/notification_service.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;
  TimeOfDay _reminder = const TimeOfDay(hour: 9, minute: 0);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await AppPreferencesService.instance.setOnboardingComplete(true);
    if (mounted) widget.onDone();
  }

  Future<void> _enableReminder() async {
    final granted = await NotificationService.instance.requestPermission();
    if (granted) {
      await NotificationService.instance.scheduleDaily(hour: _reminder.hour, minute: _reminder.minute);
      await AppPreferencesService.instance.setReminderEnabled(true);
      await AppPreferencesService.instance.setReminderTime(_reminder.hour, _reminder.minute);
    }
    await _finish();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(onPressed: _finish, child: const Text('تخطي')),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (v) => setState(() => _page = v),
                children: [
                  _pageView(context, Icons.menu_book_rounded, 'كل يوم حديث', 'دقيقة واحدة مع حديث من الأربعين النووية.'),
                  _pageView(context, Icons.favorite_rounded, 'احفظ ما يلامس قلبك', 'احتفظ بالأحاديث التي تحب الرجوع إليها في أي وقت.'),
                  _reminderPage(context),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _page ? 24 : 7,
                height: 7,
                decoration: BoxDecoration(color: i == _page ? theme.colorScheme.primary : theme.dividerColor, borderRadius: BorderRadius.circular(99)),
              )),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _page == 2 ? _enableReminder : () => _controller.nextPage(duration: const Duration(milliseconds: 260), curve: Curves.easeOut),
                  child: Text(_page == 2 ? 'ابدأ يومك' : 'التالي'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pageView(BuildContext context, IconData icon, String title, String body) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 34),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 110, height: 110, decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, size: 50, color: theme.colorScheme.primary)),
          const SizedBox(height: 36),
          Text(title, style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(body, style: theme.textTheme.bodyLarge?.copyWith(fontSize: 17), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _reminderPage(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_active_rounded, size: 54, color: theme.colorScheme.secondary),
          const SizedBox(height: 30),
          Text('ولا تنسَ حديثك اليومي', style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text('اختار وقتًا بسيطًا نفتكرك فيه بحديث اليوم.', style: theme.textTheme.bodyLarge?.copyWith(fontSize: 17), textAlign: TextAlign.center),
          const SizedBox(height: 26),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showTimePicker(context: context, initialTime: _reminder);
              if (picked != null) setState(() => _reminder = picked);
            },
            icon: const Icon(Icons.schedule_rounded),
            label: Text(_reminder.format(context)),
          ),
        ],
      ),
    );
  }
}
