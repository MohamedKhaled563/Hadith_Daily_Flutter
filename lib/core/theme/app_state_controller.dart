import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_service.dart';

class AppStateController extends ChangeNotifier {
  static final AppStateController _instance = AppStateController._internal();
  factory AppStateController() => _instance;
  AppStateController._internal();

  static const _keyDarkMode = 'settings.darkMode';
  static const _keyFontSizeScale = 'settings.fontSizeScale';
  static const _keyMorningReminderEnabled = 'settings.morningReminderEnabled';
  static const _keyMorningReminderHour = 'settings.morningReminderHour';
  static const _keyMorningReminderMinute = 'settings.morningReminderMinute';
  static const _keyEveningReminderEnabled = 'settings.eveningReminderEnabled';
  static const _keyEveningReminderHour = 'settings.eveningReminderHour';
  static const _keyEveningReminderMinute = 'settings.eveningReminderMinute';
  static const _keySoundEnabled = 'settings.soundEnabled';
  static const _keyVibrationEnabled = 'settings.vibrationEnabled';

  SharedPreferences? _prefs;

  /// Loads persisted settings from disk. Must run before the settings are
  /// first read — call once in main() before runApp.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;

    _themeMode = (prefs.getBool(_keyDarkMode) ?? false)
        ? ThemeMode.dark
        : ThemeMode.light;
    _fontSizeScale = prefs.getDouble(_keyFontSizeScale) ?? _fontSizeScale;
    _morningReminderEnabled =
        prefs.getBool(_keyMorningReminderEnabled) ?? _morningReminderEnabled;
    _eveningReminderEnabled =
        prefs.getBool(_keyEveningReminderEnabled) ?? _eveningReminderEnabled;
    _soundEnabled = prefs.getBool(_keySoundEnabled) ?? _soundEnabled;
    _vibrationEnabled =
        prefs.getBool(_keyVibrationEnabled) ?? _vibrationEnabled;

    final morningHour = prefs.getInt(_keyMorningReminderHour);
    final morningMinute = prefs.getInt(_keyMorningReminderMinute);
    if (morningHour != null && morningMinute != null) {
      _morningReminderTime =
          TimeOfDay(hour: morningHour, minute: morningMinute);
    }

    final eveningHour = prefs.getInt(_keyEveningReminderHour);
    final eveningMinute = prefs.getInt(_keyEveningReminderMinute);
    if (eveningHour != null && eveningMinute != null) {
      _eveningReminderTime =
          TimeOfDay(hour: eveningHour, minute: eveningMinute);
    }

    _applyUser(AuthService.instance.currentUser);
    AuthService.instance.authStateChanges.listen(_applyUser);

    notifyListeners();
  }

  // Theme state
  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme() => setThemeMode(
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light,
      );

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _prefs?.setBool(_keyDarkMode, mode == ThemeMode.dark);
    notifyListeners();
  }

  // ---------------------------------------------------------------- auth ----

  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  String _userName = 'زائر كريم';
  String get userName => _userName;

  String _userEmail = '';
  String get userEmail => _userEmail;

  /// Mirrors FirebaseAuth's current user into the local fields the rest of
  /// the app reads, so screens keep using the same `isLoggedIn`/`userName`/
  /// `userEmail` surface regardless of how the user actually signed in.
  void _applyUser(User? user) {
    if (user == null) {
      _isLoggedIn = false;
      _userName = 'زائر كريم';
      _userEmail = '';
    } else {
      _isLoggedIn = true;
      _userName = user.displayName?.isNotEmpty == true
          ? user.displayName!
          : (user.email ?? 'زائر كريم');
      _userEmail = user.email ?? '';
    }
    notifyListeners();
  }

  int _savedHadithsCount = 5;
  int get savedHadithsCount => _savedHadithsCount;

  int _myContributionsCount = 2;
  int get myContributionsCount => _myContributionsCount;

  void logout() {
    // Fire-and-forget: the authStateChanges listener applies the signed-out
    // state as soon as Firebase confirms it.
    AuthService.instance.signOut();
  }

  void updateProfileName(String newName) {
    if (newName.isNotEmpty) {
      _userName = newName;
      notifyListeners();
    }
  }

  // Notification & Reminder Settings
  bool _morningReminderEnabled = true;
  bool get morningReminderEnabled => _morningReminderEnabled;

  TimeOfDay _morningReminderTime = const TimeOfDay(hour: 8, minute: 30);
  TimeOfDay get morningReminderTime => _morningReminderTime;

  bool _eveningReminderEnabled = true;
  bool get eveningReminderEnabled => _eveningReminderEnabled;

  TimeOfDay _eveningReminderTime = const TimeOfDay(hour: 20, minute: 0);
  TimeOfDay get eveningReminderTime => _eveningReminderTime;

  bool _soundEnabled = true;
  bool get soundEnabled => _soundEnabled;

  bool _vibrationEnabled = true;
  bool get vibrationEnabled => _vibrationEnabled;

  void toggleMorningReminder(bool value) {
    _morningReminderEnabled = value;
    _prefs?.setBool(_keyMorningReminderEnabled, value);
    notifyListeners();
  }

  void setMorningReminderTime(TimeOfDay time) {
    _morningReminderTime = time;
    _prefs?.setInt(_keyMorningReminderHour, time.hour);
    _prefs?.setInt(_keyMorningReminderMinute, time.minute);
    notifyListeners();
  }

  void toggleEveningReminder(bool value) {
    _eveningReminderEnabled = value;
    _prefs?.setBool(_keyEveningReminderEnabled, value);
    notifyListeners();
  }

  void setEveningReminderTime(TimeOfDay time) {
    _eveningReminderTime = time;
    _prefs?.setInt(_keyEveningReminderHour, time.hour);
    _prefs?.setInt(_keyEveningReminderMinute, time.minute);
    notifyListeners();
  }

  void toggleSound(bool value) {
    _soundEnabled = value;
    _prefs?.setBool(_keySoundEnabled, value);
    notifyListeners();
  }

  void toggleVibration(bool value) {
    _vibrationEnabled = value;
    _prefs?.setBool(_keyVibrationEnabled, value);
    notifyListeners();
  }

  // Reading size. Applied in MaterialApp.builder on top of the reader's OS
  // text-size setting, then clamped — see main.dart.
  static const fontSizeSteps = <String, double>{
    'عادي': 1.0,
    'متوسط': 1.15,
    'كبير': 1.3,
  };

  double _fontSizeScale = 1.0;
  double get fontSizeScale => _fontSizeScale;

  String get fontSizeLabel => fontSizeSteps.entries
      .firstWhere(
        (e) => (e.value - _fontSizeScale).abs() < 0.001,
        orElse: () => fontSizeSteps.entries.first,
      )
      .key;

  void setFontSizeScale(double scale) {
    if (_fontSizeScale == scale) return;
    _fontSizeScale = scale;
    _prefs?.setDouble(_keyFontSizeScale, scale);
    notifyListeners();
  }
}
