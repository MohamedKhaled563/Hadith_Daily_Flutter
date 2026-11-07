import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/journey/journey_models.dart';
import '../../data/journey/journey_repository.dart';
import '../../data/repositories/hadith_repository.dart';
import '../auth/auth_service.dart';

class AppStateController extends ChangeNotifier {
  static final AppStateController _instance = AppStateController._internal();
  factory AppStateController() => _instance;
  AppStateController._internal();

  /// Legacy key: a bool, from when the app only knew light and dark. Read
  /// once at startup to carry an existing reader's choice over, then never
  /// written again — see [_keyThemeMode].
  static const _keyDarkMode = 'settings.darkMode';

  /// 'light' | 'dark' | 'system'.
  static const _keyThemeMode = 'settings.themeMode';
  static const _keyFontSizeScale = 'settings.fontSizeScale';
  static const _keyMorningReminderEnabled = 'settings.morningReminderEnabled';
  static const _keyMorningReminderHour = 'settings.morningReminderHour';
  static const _keyMorningReminderMinute = 'settings.morningReminderMinute';
  static const _keyEveningReminderEnabled = 'settings.eveningReminderEnabled';
  static const _keyEveningReminderHour = 'settings.eveningReminderHour';
  static const _keyEveningReminderMinute = 'settings.eveningReminderMinute';

  SharedPreferences? _prefs;

  /// Loads persisted settings from disk. Must run before the settings are
  /// first read — call once in main() before runApp.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;

    _themeMode = _readThemeMode(prefs);
    _fontSizeScale = prefs.getDouble(_keyFontSizeScale) ?? _fontSizeScale;
    _morningReminderEnabled =
        prefs.getBool(_keyMorningReminderEnabled) ?? _morningReminderEnabled;
    _eveningReminderEnabled =
        prefs.getBool(_keyEveningReminderEnabled) ?? _eveningReminderEnabled;

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

    JourneyRepository().listenable.addListener(syncRemindersWithAccount);
    _applyUser(AuthService.instance.currentUser);
    AuthService.instance.authStateChanges.listen(_applyUser);

    notifyListeners();
  }

  // ------------------------------------------------------------- theme ----

  /// Dark mode used to be a bool, so "follow the phone" was unreachable — the
  /// app either overrode the reader's system setting or matched it by luck.
  /// It is also what forced the Android launch window to be branded rather
  /// than themed: `values-night/` tracks the *system* setting, so an app
  /// carrying its own independent choice can never line up with it. Offering
  /// system is the honest fix for both.
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  /// Whether the app is *currently* rendering dark.
  ///
  /// Only meaningful for code with no [BuildContext] — anything inside the
  /// widget tree should ask `context.isDarkMode`, which reads the theme that
  /// actually resolved rather than second-guessing the platform here.
  bool get isDarkMode => switch (_themeMode) {
        ThemeMode.dark => true,
        ThemeMode.light => false,
        ThemeMode.system =>
          PlatformDispatcher.instance.platformBrightness == Brightness.dark,
      };

  static ThemeMode _readThemeMode(SharedPreferences prefs) {
    final stored = prefs.getString(_keyThemeMode);
    if (stored != null) {
      return switch (stored) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    }
    // No explicit choice recorded. Carry over the old bool if there is one —
    // someone who had chosen dark should not be silently moved onto system on
    // upgrade — and default a fresh install to following the phone.
    final legacy = prefs.getBool(_keyDarkMode);
    if (legacy == null) return ThemeMode.system;
    return legacy ? ThemeMode.dark : ThemeMode.light;
  }

  void setThemeMode(ThemeMode mode) {
    if (mode == _themeMode) return;
    _themeMode = mode;
    _prefs?.setString(_keyThemeMode, mode.name);
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
    // Favourites belong to the account: load this one's, or clear them.
    HadithRepository().setUser(user?.uid);
    // So does the reading journey.
    JourneyRepository().setUser(user?.uid);
    notifyListeners();
  }

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

  // There were `soundEnabled`/`vibrationEnabled` flags here, persisted on
  // every launch and read by nothing: no settings tile ever exposed them and
  // the notification details never consulted them — the same "state existed
  // but nothing consumed it" gap the reading-size control had. Deliberately
  // deleted rather than wired up: an Android notification channel fixes its
  // sound and vibration at creation time, so honouring a later toggle needs
  // a fresh channel id per combination, which is a feature decision rather
  // than something to smuggle in behind a dead field.

  /// The two reminders as the account stores them.
  ReminderPrefs get reminderPrefs => ReminderPrefs(
        morningOn: _morningReminderEnabled,
        morning: _formatTime(_morningReminderTime),
        eveningOn: _eveningReminderEnabled,
        evening: _formatTime(_eveningReminderTime),
      );

  static String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  static TimeOfDay? _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// The account's reminders win, which is what lets a new phone start with
  /// the reader's own times. An account with none yet takes this phone's.
  @visibleForTesting
  void syncRemindersWithAccount() {
    final journey = JourneyRepository();
    if (!journey.accountLoaded) return;
    final account = journey.data.prefs;
    if (account == null) {
      journey.saveReminderPrefs(reminderPrefs);
      return;
    }
    if (account == reminderPrefs) return;

    final morning = _parseTime(account.morning);
    final evening = _parseTime(account.evening);
    if (morning == null || evening == null) return;
    _storeMorningReminder(account.morningOn, morning);
    _storeEveningReminder(account.eveningOn, evening);
    notifyListeners();
  }

  void _storeMorningReminder(bool enabled, TimeOfDay time) {
    _morningReminderEnabled = enabled;
    _morningReminderTime = time;
    _prefs?.setBool(_keyMorningReminderEnabled, enabled);
    _prefs?.setInt(_keyMorningReminderHour, time.hour);
    _prefs?.setInt(_keyMorningReminderMinute, time.minute);
  }

  void _storeEveningReminder(bool enabled, TimeOfDay time) {
    _eveningReminderEnabled = enabled;
    _eveningReminderTime = time;
    _prefs?.setBool(_keyEveningReminderEnabled, enabled);
    _prefs?.setInt(_keyEveningReminderHour, time.hour);
    _prefs?.setInt(_keyEveningReminderMinute, time.minute);
  }

  void _remindersChanged() {
    JourneyRepository().saveReminderPrefs(reminderPrefs);
    notifyListeners();
  }

  void toggleMorningReminder(bool value) {
    _storeMorningReminder(value, _morningReminderTime);
    _remindersChanged();
  }

  void setMorningReminderTime(TimeOfDay time) {
    _storeMorningReminder(_morningReminderEnabled, time);
    _remindersChanged();
  }

  void toggleEveningReminder(bool value) {
    _storeEveningReminder(value, _eveningReminderTime);
    _remindersChanged();
  }

  void setEveningReminderTime(TimeOfDay time) {
    _storeEveningReminder(_eveningReminderEnabled, time);
    _remindersChanged();
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
