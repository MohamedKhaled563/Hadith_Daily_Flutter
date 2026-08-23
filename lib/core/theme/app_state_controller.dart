import 'package:flutter/material.dart';

class AppStateController extends ChangeNotifier {
  static final AppStateController _instance = AppStateController._internal();
  factory AppStateController() => _instance;
  AppStateController._internal();

  // Theme state
  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
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
  static String get demoHint => 'اسم المستخدم: $_demoUsername • كلمة المرور: $_demoPassword';

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
    notifyListeners();
  }

  void setMorningReminderTime(TimeOfDay time) {
    _morningReminderTime = time;
    notifyListeners();
  }

  void toggleEveningReminder(bool value) {
    _eveningReminderEnabled = value;
    notifyListeners();
  }

  void setEveningReminderTime(TimeOfDay time) {
    _eveningReminderTime = time;
    notifyListeners();
  }

  void toggleSound(bool value) {
    _soundEnabled = value;
    notifyListeners();
  }

  void toggleVibration(bool value) {
    _vibrationEnabled = value;
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
    notifyListeners();
  }
}
