import 'package:flutter/material.dart';

import '../../core/theme/app_state_controller.dart';
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
class NotificationLifecycleRefresher with WidgetsBindingObserver {
  NotificationLifecycleRefresher({
    NotificationScheduler? scheduler,
    AppStateController? state,
    DateTime Function()? clock,
    this.minRefreshInterval = const Duration(hours: 6),
  })  : _scheduler = scheduler ?? NotificationScheduler.instance,
        _state = state ?? AppStateController(),
        _clock = clock ?? DateTime.now;

  final NotificationScheduler _scheduler;
  final AppStateController _state;
  final DateTime Function() _clock;

  /// How long a refresh stays "fresh enough" that a resume is ignored.
  final Duration minRefreshInterval;

  DateTime? _lastRefreshAt;

  /// The last refresh's outcome, for callers that want to surface a problem
  /// (the settings drawer reads the equivalent from its own direct call).
  NotificationScheduleResult? get lastResult => _lastResult;
  NotificationScheduleResult? _lastResult;

  /// Registers for lifecycle callbacks and performs the initial refresh.
  /// Call once, from app start.
  void start() {
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    if (!_state.morningReminderEnabled && !_state.eveningReminderEnabled) {
      // Nothing to top up. Not marked as refreshed, so the first resume
      // after switching a reminder back on is not throttled away.
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
      // A failed run is not a refresh — let the next resume retry rather
      // than sitting out the whole throttle window on a transient error.
      _lastRefreshAt = null;
    }
    return result;
  }
}
