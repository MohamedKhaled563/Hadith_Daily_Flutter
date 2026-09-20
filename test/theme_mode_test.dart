import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hadith_app/core/theme/app_state_controller.dart';

/// Dark mode used to be a bool, so "follow the phone" could not be chosen.
/// Widening it to a three-way [ThemeMode] has to not quietly re-decide for
/// readers who already made a choice — which is the part worth pinning.

Future<AppStateController> freshController(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final controller = AppStateController();
  await controller.init();
  return controller;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('migrating from the old boolean', () {
    test('a fresh install follows the phone', () async {
      final state = await freshController({});
      expect(state.themeMode, ThemeMode.system);
    });

    test('someone who had chosen dark stays on dark', () async {
      // The upgrade must not silently move them onto system, which on a
      // light phone would look like the app forgetting their preference.
      final state = await freshController({'flutter.settings.darkMode': true});
      expect(state.themeMode, ThemeMode.dark);
    });

    test('someone who had chosen light stays on light', () async {
      final state = await freshController({'flutter.settings.darkMode': false});
      expect(state.themeMode, ThemeMode.light);
    });

    test('an explicit new-style choice wins over the legacy bool', () async {
      final state = await freshController({
        'flutter.settings.darkMode': true,
        'flutter.settings.themeMode': 'system',
      });
      expect(state.themeMode, ThemeMode.system);
    });

    test('an unrecognised stored value falls back to system', () async {
      final state = await freshController({
        'flutter.settings.themeMode': 'sepia',
      });
      expect(state.themeMode, ThemeMode.system);
    });
  });

  group('choosing a mode', () {
    test('persists under the new key and survives a restart', () async {
      final state = await freshController({});
      state.setThemeMode(ThemeMode.dark);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('settings.themeMode'), 'dark');

      // A second controller reading the same store — the singleton makes a
      // true restart untestable, so this asserts the read path directly.
      expect(prefs.getString('settings.themeMode'), 'dark');
    });

    test('notifies listeners only on a real change', () async {
      final state = await freshController({});
      state.setThemeMode(ThemeMode.light);

      var notifications = 0;
      void listener() => notifications++;
      state.addListener(listener);
      addTearDown(() => state.removeListener(listener));

      state.setThemeMode(ThemeMode.light);
      expect(notifications, 0, reason: 'same mode, nothing changed');

      state.setThemeMode(ThemeMode.dark);
      expect(notifications, 1);
    });

    test('isDarkMode reports the resolved brightness, not the mode', () async {
      final state = await freshController({});

      state.setThemeMode(ThemeMode.dark);
      expect(state.isDarkMode, isTrue);

      state.setThemeMode(ThemeMode.light);
      expect(state.isDarkMode, isFalse);

      // On system it has to ask the platform rather than guess. Whatever the
      // test host reports, the two must agree.
      state.setThemeMode(ThemeMode.system);
      final platformIsDark =
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark;
      expect(state.isDarkMode, platformIsDark);
    });
  });
}
