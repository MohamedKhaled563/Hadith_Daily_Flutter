import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/core/crash_reporter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => CrashReporter.setEnabled(true));

  group('CrashReporter', () {
    test('is on until the reader says otherwise', () {
      expect(CrashReporter.enabled, isTrue);
    });

    test('remembers a reader who switched it off', () async {
      await CrashReporter.setEnabled(false);

      expect(CrashReporter.enabled, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('settings.crashReportsEnabled'), isFalse);
    });

    test('reads that choice back at startup', () async {
      // init() installs the app-wide error hooks.
      final flutterError = FlutterError.onError;
      final platformError = PlatformDispatcher.instance.onError;
      addTearDown(() {
        FlutterError.onError = flutterError;
        PlatformDispatcher.instance.onError = platformError;
      });
      SharedPreferences.setMockInitialValues({
        'settings.crashReportsEnabled': false,
      });

      await CrashReporter.init();

      expect(CrashReporter.enabled, isFalse);
    });

    test('a report never throws, even with no Crashlytics to answer', () {
      expect(
        () => CrashReporter.recordError(
          StateError('example'),
          StackTrace.current,
          reason: 'a test label',
        ),
        returnsNormally,
      );
      expect(
        () => CrashReporter.recordError(null, null, reason: 'nothing to send'),
        returnsNormally,
      );
    });
  });
}
