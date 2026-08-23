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

  // Auth / Profile state (Ready for future Auth)
  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  String _userName = 'عبد الله بن محمد';
  String get userName => _userName;

  String _userEmail = 'abdullah@example.com';
  String get userEmail => _userEmail;

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

  // Font Size Settings (1.0 = Regular, 1.15 = Medium, 1.3 = Large)
  double _fontSizeScale = 1.0;
  double get fontSizeScale => _fontSizeScale;

  void setFontSizeScale(double scale) {
    _fontSizeScale = scale;
    notifyListeners();
  }
}
