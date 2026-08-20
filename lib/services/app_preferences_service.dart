import 'package:shared_preferences/shared_preferences.dart';

class AppPreferencesService {
  AppPreferencesService._();
  static final instance = AppPreferencesService._();

  static const _onboardingKey = 'onboarding_complete';
  static const _reminderEnabledKey = 'reminder_enabled';
  static const _reminderHourKey = 'reminder_hour';
  static const _reminderMinuteKey = 'reminder_minute';
  static const _themeModeKey = 'theme_mode';
  static const _shareStyleKey = 'share_style';
  static const _firstLaunchKey = 'first_launch_complete';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<bool> isOnboardingComplete() async =>
      (await _prefs).getBool(_onboardingKey) ?? false;

  Future<void> setOnboardingComplete(bool value) async =>
      (await _prefs).setBool(_onboardingKey, value);

  Future<bool> isReminderEnabled() async =>
      (await _prefs).getBool(_reminderEnabledKey) ?? false;

  Future<void> setReminderEnabled(bool value) async =>
      (await _prefs).setBool(_reminderEnabledKey, value);

  Future<({int hour, int minute})> getReminderTime() async {
    final prefs = await _prefs;
    return (
      hour: prefs.getInt(_reminderHourKey) ?? 9,
      minute: prefs.getInt(_reminderMinuteKey) ?? 0,
    );
  }

  Future<void> setReminderTime(int hour, int minute) async {
    final prefs = await _prefs;
    await prefs.setInt(_reminderHourKey, hour);
    await prefs.setInt(_reminderMinuteKey, minute);
  }

  Future<String> getThemeMode() async =>
      (await _prefs).getString(_themeModeKey) ?? 'system';

  Future<void> setThemeMode(String value) async =>
      (await _prefs).setString(_themeModeKey, value);

  Future<String> getShareStyle() async =>
      (await _prefs).getString(_shareStyleKey) ?? 'cream';

  Future<void> setShareStyle(String value) async =>
      (await _prefs).setString(_shareStyleKey, value);

  Future<bool> isFirstLaunchComplete() async =>
      (await _prefs).getBool(_firstLaunchKey) ?? false;

  Future<void> setFirstLaunchComplete(bool value) async =>
      (await _prefs).setBool(_firstLaunchKey, value);
}
