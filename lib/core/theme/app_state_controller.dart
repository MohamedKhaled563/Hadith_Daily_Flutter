import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  //
  // PLACEHOLDER AUTHENTICATION — NOT SECURE, NOT REAL.
  //
  // Credentials are hardcoded in the client so the UI can be built and
  // demonstrated before the backend exists. Anyone can read them by
  // decompiling the app. Before this ships to real users, `signIn` must call a
  // real auth service and this constant pair must be deleted.
  static const _demoUsername = 'admin';
  static const _demoPassword = 'admin';
  static const _demoDisplayName = 'محمد';
  static const _demoEmail = 'admin@tayyibqalbak.app';

  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  String _userName = _demoDisplayName;
  String get userName => _userName;

  String _userEmail = _demoEmail;
  String get userEmail => _userEmail;

  /// Placeholder sign-in. Returns true when the demo credentials match.
  bool signIn({required String username, required String password}) {
    if (username.trim() != _demoUsername || password != _demoPassword) {
      return false;
    }

    _userName = _demoDisplayName;
    _userEmail = _demoEmail;
    _isLoggedIn = true;
    notifyListeners();
    return true;
  }

  int _savedHadithsCount = 5;
  int get savedHadithsCount => _savedHadithsCount;

  int _myContributionsCount = 2;
  int get myContributionsCount => _myContributionsCount;

  void login(String name, String email) {
    _userName = name.isNotEmpty ? name : 'عبد الله بن محمد';
    _userEmail = email.isNotEmpty ? email : 'user@example.com';
    _isLoggedIn = true;
    notifyListeners();
  }

  void logout() {
    _isLoggedIn = false;
    _userName = 'زائر كريم';
    _userEmail = '';
    notifyListeners();
  }

  /// Demo credentials, surfaced so the login screen can show the hint while
  /// this is still a placeholder. Remove alongside [signIn].
  static String get demoHint =>
      'اسم المستخدم: $_demoUsername • كلمة المرور: $_demoPassword';

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
