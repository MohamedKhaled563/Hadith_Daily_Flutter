import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/crash_reporter.dart';
import '../../core/theme/app_state_controller.dart';
import '../journey/journey_repository.dart';
import 'journey_reminders.dart';
import 'notification_scheduler.dart';

/// Keeps the rolling reminder window topped up for as long as the app is
/// alive, not just for as long as a cold start ago.
///
/// [NotificationScheduler] lays out a fixed 14-day window and relies on
/// being re-run to push that window forward. Until this existed the only
/// thing that re-ran it was `_HeartbeatHadithCircleState.initState` — a
/// decorative widget on the home screen — which fires exactly once per
/// **cold start**. A phone that keeps the app resident for a fortnight (the
/// norm on iOS, and common enough on Android) therefore ran off the end of
/// its own window and went quiet, with nothing in the app able to tell.
///
/// The same gap made the fixed-offset scheduling in
/// [NotificationScheduler.reschedule] worse than it needed to be: a DST
/// transition inside the window shifts every alarm past it by the offset
/// delta, and a cold start was the only thing that could heal it.
///
/// Refreshing on every single resume would be wasteful — the work is ~56
/// platform calls plus a Firestore read — so [minRefreshInterval] throttles
/// it to something that still comfortably outpaces a 14-day window.
///
/// Reminders also speak about what the reader has done, so a reading that
/// changes their words re-lays the window at once, without waiting for a
/// resume: finishing today's hadith has to take back tonight's streak line.
class NotificationLifecycleRefresher with WidgetsBindingObserver {
  NotificationLifecycleRefresher({
    NotificationScheduler? scheduler,
    AppStateController? state,
    DateTime Function()? clock,
    this.minRefreshInterval = const Duration(hours: 6),
    Listenable? planChanges,
    String Function()? planKey,
    String? Function()? currentUser,
    this.planSettle = const Duration(seconds: 2),
  })  : _scheduler = scheduler ?? NotificationScheduler.instance,
        _state = state ?? AppStateController(),
        _clock = clock ?? DateTime.now,
        _planChanges = planChanges ??
            Listenable.merge([
              JourneyRepository().listenable,
              state ?? AppStateController(),
            ]),
        _planKey = planKey ?? JourneyReminders.planKey,
        _currentUser = currentUser ?? (() => JourneyRepository().uid);

  final NotificationScheduler _scheduler;
  final AppStateController _state;
  final DateTime Function() _clock;

  /// How long a refresh stays "fresh enough" that a resume is ignored.
  final Duration minRefreshInterval;

  /// How long to let a burst of changes settle before re-laying the window.
  /// A sign-in brings the reader's data in several steps.
  final Duration planSettle;

  final Listenable _planChanges;
  final String Function() _planKey;
  final String? Function() _currentUser;

  DateTime? _lastRefreshAt;
  String? _lastPlanKey;
  String? _lastUser;
  bool _clearPending = false;
  Timer? _replan;

  /// The last refresh's outcome, for callers that want to surface a problem
  /// (the settings drawer reads the equivalent from its own direct call).
  NotificationScheduleResult? get lastResult => _lastResult;
  NotificationScheduleResult? _lastResult;

  /// Registers for lifecycle callbacks and performs the initial refresh.
  /// Call once, from app start.
  void start() {
    WidgetsBinding.instance.addObserver(this);
    _lastPlanKey = _planKey();
    _lastUser = _currentUser();
    _planChanges.addListener(_onPlanChanged);
    refresh();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _planChanges.removeListener(_onPlanChanged);
    _replan?.cancel();
  }

  void _onPlanChanged() {
    final key = _planKey();
    if (key == _lastPlanKey) return;
    _lastPlanKey = key;

    final user = _currentUser();
    if (_lastUser != null && user != _lastUser) _clearPending = true;
    _lastUser = user;

    _replan?.cancel();
    _replan = Timer(planSettle, () {
      unawaited(_replanNow());
    });
  }

  Future<void> _replanNow() async {
    if (_clearPending) {
      _clearPending = false;
      try {
        await _scheduler.clearAll();
      } catch (error) {
        debugPrint('NotificationLifecycleRefresher: $error');
      }
    }
    await refresh(force: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    refresh();
  }

  /// Whether enough time has passed since the last refresh to do another.
  /// Exposed (with [markRefreshed]) so the throttle is testable without
  /// touching a platform channel.
  @visibleForTesting
  bool shouldRefresh(DateTime now) {
    final last = _lastRefreshAt;
    if (last == null) return true;
    return now.difference(last) >= minRefreshInterval;
  }

  @visibleForTesting
  void markRefreshed(DateTime now) => _lastRefreshAt = now;

  /// Re-lays the window if the throttle allows it. [force] bypasses the
  /// throttle, for the one caller that is a direct reader action.
  ///
  /// Deliberately returns a Future the callers may ignore: this must never
  /// block a frame, and a failure is reported through [lastResult] rather
  /// than thrown ([NotificationScheduler.reschedule] never throws).
  Future<NotificationScheduleResult?> refresh({bool force = false}) async {
    final now = _clock();
    if (!force && !shouldRefresh(now)) return null;
    if (!force &&
        !_state.morningReminderEnabled &&
        !_state.eveningReminderEnabled) {
      // Nothing to top up. Not marked as refreshed, so the first resume
      // after switching a reminder back on is not throttled away. A forced
      // run still goes through: reminders switched off on another phone reach
      // this one as a change of plan, and their alarms have to come off.
      return null;
    }

    markRefreshed(now);
    final result = await _scheduler.reschedule(
      morningEnabled: _state.morningReminderEnabled,
      morningTime: _state.morningReminderTime,
      eveningEnabled: _state.eveningReminderEnabled,
      eveningTime: _state.eveningReminderTime,
    );
    _lastResult = result;
    if (!result.succeeded) {
      debugPrint('NotificationLifecycleRefresher: ${result.error}');
      CrashReporter.recordError(result.error, null,
          reason: 'reminder reschedule failed on resume');
      // A failed run is not a refresh — let the next resume retry rather
      // than sitting out the whole throttle window on a transient error.
      _lastRefreshAt = null;
    }
    return result;
  }
}
