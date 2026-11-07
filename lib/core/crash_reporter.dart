import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Crash and error reports, through Firebase Crashlytics.
///
/// What a report carries: the stack trace, the app version, the device model
/// and OS version — what Crashlytics collects on its own. What it never
/// carries: a uid, an email, a display name, or any text the reader wrote.
/// Nothing here calls `setUserIdentifier` or `setCustomKey`, and the
/// `reason` strings passed to [recordError] are fixed English labels, never
/// interpolated with user data. Keep it that way — the privacy policy
/// (lib/core/legal/legal_documents.dart) promises exactly this much.
///
/// Off in debug builds, so a developer's own red screens never reach the
/// console, and off whenever the reader has switched it off in settings.
///
/// Cost to the app: the native SDK writes a report to disk when something
/// goes wrong and sends it on the next launch, in the background. Nothing
/// here is awaited before the first frame beyond one SharedPreferences read,
/// which runs alongside main()'s other startup loads.
class CrashReporter {
  const CrashReporter._();

  static const _keyEnabled = 'settings.crashReportsEnabled';

  static bool _enabled = true;

  /// The reader's choice. On by default; the settings switch reads this.
  static bool get enabled => _enabled;

  /// Whether a report should actually leave the device right now.
  static bool get _active => _enabled && !kDebugMode;

  /// Installs the error hooks and applies the stored choice. Call once in
  /// main(), after Firebase.initializeApp.
  ///
  /// The hooks go in before the first await, so a failure in the startup
  /// loads running alongside this one is still caught — those reach
  /// [PlatformDispatcher.onError] as an uncaught error from main().
  static Future<void> init() async {
    FlutterError.onError = (details) {
      // Keep the usual console output; Crashlytics is in addition to it.
      FlutterError.presentError(details);
      // A framework error (a build or layout throw) shows an error widget
      // and the app carries on, so it is recorded as non-fatal.
      if (_active) {
        unawaited(FirebaseCrashlytics.instance.recordFlutterError(details));
      }
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      if (_active) {
        unawaited(
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true),
        );
      }
      // false in debug keeps Flutter's own uncaught-error printing.
      return !kDebugMode;
    };

    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_keyEnabled) ?? true;
    await _apply();
  }

  /// The settings switch.
  static Future<void> setEnabled(bool value) async {
    if (value == _enabled) return;
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, value);
    await _apply();
    // Switching off also drops anything already waiting to be sent: a
    // reader who says no should not have yesterday's crash go out anyway.
    if (!value) {
      await _guard(() => FirebaseCrashlytics.instance.deleteUnsentReports());
    }
  }

  /// A handled error worth knowing about — something the app recovered from
  /// but that should not be happening. [reason] is a fixed label shown in
  /// the Crashlytics console; never put user data in it.
  static void recordError(
    Object? error,
    StackTrace? stack, {
    required String reason,
  }) {
    if (!_active || error == null) return;
    unawaited(_guard(() => FirebaseCrashlytics.instance
        .recordError(error, stack ?? StackTrace.current, reason: reason)));
  }

  /// The native SDK keeps this flag across launches, so a reader who opted
  /// out stays opted out even for a crash before Dart has started.
  static Future<void> _apply() => _guard(() => FirebaseCrashlytics.instance
      .setCrashlyticsCollectionEnabled(_active));

  /// Reporting must never be the thing that breaks the app — nor a widget
  /// test, where there is no Crashlytics plugin to answer.
  static Future<void> _guard(Future<void> Function() call) async {
    try {
      await call();
    } catch (error) {
      debugPrint('CrashReporter: $error');
    }
  }
}
