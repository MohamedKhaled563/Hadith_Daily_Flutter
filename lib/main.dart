import 'package:flutter/material.dart';
import 'screens/app_shell.dart';
import 'screens/onboarding_screen.dart';
import 'services/app_preferences_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  final prefs = AppPreferencesService.instance;
  final onboardingComplete = await prefs.isOnboardingComplete();
  if (await prefs.isReminderEnabled()) {
    final time = await prefs.getReminderTime();
    await NotificationService.instance.scheduleDaily(hour: time.hour, minute: time.minute);
  }
  runApp(HadithApp(onboardingComplete: onboardingComplete));
}

class HadithApp extends StatefulWidget {
  final bool onboardingComplete;
  const HadithApp({super.key, required this.onboardingComplete});

  @override
  State<HadithApp> createState() => _HadithAppState();
}

class _HadithAppState extends State<HadithApp> {
  late bool _showOnboarding;

  @override
  void initState() {
    super.initState();
    _showOnboarding = !widget.onboardingComplete;
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final mode = await AppPreferencesService.instance.getThemeMode();
    if (!mounted) return;
    ThemeController.instance.set(mode);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance.mode,
      builder: (context, mode, _) => MaterialApp(
      title: 'حديثك اليوم',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
      locale: const Locale('ar'),
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: _showOnboarding ? OnboardingScreen(onDone: () => setState(() => _showOnboarding = false)) : const AppShell(),
    ),
    );
  }
}
