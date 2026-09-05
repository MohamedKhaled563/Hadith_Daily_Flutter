import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/insight.dart';
import 'notification_data_source.dart';

/// Outcome of a [NotificationScheduler.reschedule] call — lets callers (and
/// tests) tell "nothing to schedule" apart from "tried and failed", which
/// the previous fire-and-forget version couldn't distinguish.
@immutable
class NotificationScheduleResult {
  const NotificationScheduleResult({
    required this.scheduledCount,
    required this.usedExactAlarms,
    this.error,
  });

  final int scheduledCount;
  final bool usedExactAlarms;
  final Object? error;

  bool get succeeded => error == null;
}

/// Schedules the morning/evening reminder notifications from
/// notificationMessages — entirely on-device, no server push (Spark plan,
/// see the roadmap). Two independent picks feed this:
///
///   - `settings/notificationMode` ('manual' | 'random', moderator/admin
///     controlled from the dashboard) decides HOW a day's message is
///     chosen.
///   - manual: every device computes the same index — `daysSinceEpoch %
///     pool.length` into the pool sorted by `order` — so everyone sees the
///     same message on the same calendar day with zero shared state.
///   - random: each device seeds its own `Random` once (persisted locally)
///     and mixes that seed with the date, so the same device always picks
///     the same message for a given future date (stable across repeated
///     rescheduling) while different devices likely diverge — acceptable
///     per-device personalisation that still needs no server component.
///
/// Notifications are scheduled `_daysAhead` days out at a time and
/// refreshed on every app start (and whenever the reminder settings
/// change), which is what keeps the rolling window populated without any
/// background execution beyond what the OS already does for a scheduled
/// local notification.
///
/// On Android 12+ an *inexact* alarm (the previous, only mode this class
/// used) is not delivered at its requested time — the OS batches it into a
/// maintenance window that can be minutes to hours later depending on the
/// app's standby bucket, which is why a reminder set "one minute from now"
/// can appear to never fire. [reschedule] now asks for the exact-alarm
/// permission and uses `exactAllowWhileIdle` whenever it has been granted,
/// falling back to the inexact mode only when it hasn't.
class NotificationScheduler {
  NotificationScheduler._internal({
    FlutterLocalNotificationsPlugin? plugin,
    NotificationDataSource? dataSource,
  })  : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _dataSource = dataSource ?? FirestoreNotificationDataSource();

  static final NotificationScheduler instance = NotificationScheduler._internal();
  factory NotificationScheduler() => instance;

  /// Test-only seam: build an isolated instance with fakes instead of the
  /// real plugin/Firestore, so unit tests never touch a platform channel or
  /// a live project.
  @visibleForTesting
  factory NotificationScheduler.test({
    required FlutterLocalNotificationsPlugin plugin,
    required NotificationDataSource dataSource,
  }) =>
      NotificationScheduler._internal(plugin: plugin, dataSource: dataSource);

  static const _daysAhead = 14;
  static const _randomSeedKey = 'notificationScheduler.randomSeed';
  static const _cachedPoolKey = 'notificationScheduler.cachedPool';

  final FlutterLocalNotificationsPlugin _plugin;
  final NotificationDataSource _dataSource;
  Future<void>? _initFuture;

  /// The tapped notification's message text (its `payload`, set from
  /// [_scheduleOne]'s `body`) — set whenever the reader taps a reminder
  /// while the app is running (foreground or backgrounded). A cold start
  /// from a terminated state instead goes through
  /// [consumeLaunchPayload], which SplashScreen checks once at launch.
  static final ValueNotifier<String?> tappedMessage =
      ValueNotifier<String?>(null);

  static void _onNotificationResponse(NotificationResponse response) {
    tappedMessage.value = response.payload;
  }

  // requestPermission() and reschedule() can both fire in close succession
  // (e.g. toggling a reminder switch right after app start) — without
  // memoising the in-flight Future, each call would race to invoke
  // _plugin.initialize() a second time on the same platform channel. If
  // init fails, drop the cached Future so the next call retries instead of
  // replaying the same failure forever.
  Future<void> _ensureInitialized() {
    final future = _initFuture ??= _doInitialize();
    future.catchError((_) => _initFuture = null);
    return future;
  }

  Future<void> _doInitialize() async {
    tz_data.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Falls back to whatever the timezone package defaults to (UTC) —
      // reminder times would be off, but scheduling still works rather
      // than crashing outright.
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
  }

  /// Resolves a tapped notification's payload (a `notificationMessages` doc
  /// id — see [_scheduleOne]) back to the message it actually showed, or
  /// null if [id] is empty or the doc is missing/unreadable (e.g. deleted
  /// since the reminder was scheduled). `notificationMessages` docs have no
  /// hadith association, so this always comes back with `hadithNumber: 0`;
  /// callers pass `hadith: null` to whatever screen displays it.
  Future<Insight?> resolveTappedMessage(String? id) async {
    if (id == null || id.isEmpty) return null;
    final data = await _dataSource.loadMessageById(id);
    final text = (data?['text'] as String?)?.trim();
    if (text == null || text.isEmpty) return null;
    return Insight(hadithNumber: 0, arabic: text, english: '', category: 'رسالة تذكير');
  }

  /// Whether the app was launched by tapping a reminder while fully
  /// terminated — returns that notification's payload (a notificationMessages
  /// doc id) if so, checked once at startup since a cold start never fires
  /// [_onNotificationResponse]. Safe to call before [_ensureInitialized]:
  /// this reads native launch state directly, no plugin init required.
  Future<String?> consumeLaunchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      return details?.notificationResponse?.payload;
    }
    return null;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// Android 13+/iOS need an explicit runtime grant before any notification
  /// can show, and Android 12+ separately gates *exact* alarms behind their
  /// own grant — call this once, e.g. the first time a reminder is enabled.
  /// Returns whether the notification permission itself was granted; exact
  /// alarms are best-effort (checked again in [reschedule]) since some
  /// OEMs/OS versions don't support requesting them at all.
  Future<bool> requestPermission() async {
    await _ensureInitialized();
    final android = _android;
    if (android != null) {
      final granted = await android.requestNotificationsPermission() ?? false;
      await android.requestExactAlarmsPermission();
      return granted;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return true;
  }

  /// Cancels everything this scheduler previously queued and lays down a
  /// fresh `_daysAhead`-day window from today, honouring which of the two
  /// slots are enabled and at what time. Safe to call as often as needed —
  /// e.g. on every app start and every time a reminder setting changes.
  ///
  /// Never throws: a Firestore/plugin failure is reported through the
  /// returned [NotificationScheduleResult] instead, so a transient offline
  /// error can't silently leave the user with zero scheduled reminders and
  /// no indication why.
  Future<NotificationScheduleResult> reschedule({
    required bool morningEnabled,
    required TimeOfDay morningTime,
    required bool eveningEnabled,
    required TimeOfDay eveningTime,
  }) async {
    try {
      await _ensureInitialized();
      await _plugin.cancelAll();

      if (!morningEnabled && !eveningEnabled) {
        return const NotificationScheduleResult(
          scheduledCount: 0,
          usedExactAlarms: false,
        );
      }

      final pool = await _loadPool();
      if (pool.isEmpty) {
        return const NotificationScheduleResult(
          scheduledCount: 0,
          usedExactAlarms: false,
        );
      }

      final mode = await _dataSource.loadMode();
      final seed = await _deviceSeed();
      final now = tz.TZDateTime.now(tz.local);
      final useExact = (await _android?.canScheduleExactNotifications()) ??
          false;
      final scheduleMode = useExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      var scheduledCount = 0;
      for (var offset = 0; offset < _daysAhead; offset++) {
        final day = tz.TZDateTime(tz.local, now.year, now.month, now.day)
            .add(Duration(days: offset));
        final message = pickMessageForDay(pool, day, mode, seed);

        if (morningEnabled) {
          final scheduled = await _scheduleOne(
            id: offset * 2,
            day: day,
            time: morningTime,
            title: 'رسالة الصباح 🌅',
            body: message.text,
            payload: message.id,
            now: now,
            scheduleMode: scheduleMode,
          );
          if (scheduled) scheduledCount++;
        }
        if (eveningEnabled) {
          final scheduled = await _scheduleOne(
            id: offset * 2 + 1,
            day: day,
            time: eveningTime,
            title: 'تأمل المساء 🌙',
            body: message.text,
            payload: message.id,
            now: now,
            scheduleMode: scheduleMode,
          );
          if (scheduled) scheduledCount++;
        }
      }

      return NotificationScheduleResult(
        scheduledCount: scheduledCount,
        usedExactAlarms: useExact,
      );
    } catch (error) {
      return NotificationScheduleResult(
        scheduledCount: 0,
        usedExactAlarms: false,
        error: error,
      );
    }
  }

  Future<bool> _scheduleOne({
    required int id,
    required tz.TZDateTime day,
    required TimeOfDay time,
    required String title,
    required String body,
    required String payload,
    required tz.TZDateTime now,
    required AndroidScheduleMode scheduleMode,
  }) async {
    final scheduled = resolveScheduledTime(day, time);
    if (isInPast(scheduled, now)) return false;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_reminders',
        'تذكيرات يومية',
        channelDescription: 'تذكير برسالة الصباح وتأمل المساء',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      details,
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      // The notificationMessages doc id — tapping the reminder resolves this
      // back to that exact doc (see SplashScreen/main.dart) so the reader
      // lands on the message that was actually shown, instead of just the
      // home screen. Not the text itself: several distinct docs can share
      // identical text, and text isn't a stable/lookup-able key anyway.
      payload: payload,
    );
    return true;
  }

  /// The reader thinks of reminders as a fully on-device feature (see the
  /// class doc) — a scheduled alarm does live entirely on the phone — but
  /// the message *content* is admin-curated in Firestore, so refreshing it
  /// still needs a network round trip every time this runs (app start,
  /// every reminder-setting change). Rather than let a momentary offline
  /// blip fail the whole reschedule with a "check your internet" error,
  /// this falls back to the last successfully fetched pool — cached
  /// locally — so a flaky connection degrades to "today's messages might
  /// be a little stale" instead of "reminders stopped working."
  Future<List<PoolMessage>> _loadPool() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final docs = await _dataSource.loadActiveMessages();
      final pool = buildPool(docs);
      if (pool.isNotEmpty) {
        await prefs.setString(
          _cachedPoolKey,
          jsonEncode(pool
              .map((m) => {'id': m.id, 'text': m.text, 'order': m.order})
              .toList()),
        );
      }
      return pool;
    } catch (_) {
      final cached = prefs.getString(_cachedPoolKey);
      if (cached == null) rethrow;
      final decoded = jsonDecode(cached) as List;
      return decoded
          .map((e) => PoolMessage(
                id: (e as Map)['id'] as String? ?? '',
                text: e['text'] as String? ?? '',
                order: (e['order'] as num?)?.toInt() ?? 0,
              ))
          .toList();
    }
  }

  /// How many notifications are currently queued — used to confirm
  /// scheduling actually worked (tool/verify_rules.py-style manual check,
  /// no automated test harness for platform channels in this project).
  Future<int> pendingCount() async {
    await _ensureInitialized();
    return (await _plugin.pendingNotificationRequests()).length;
  }

  Future<int> _deviceSeed() async {
    final prefs = await SharedPreferences.getInstance();
    var seed = prefs.getInt(_randomSeedKey);
    if (seed == null) {
      seed = Random().nextInt(1 << 31);
      await prefs.setInt(_randomSeedKey, seed);
    }
    return seed;
  }
}

@immutable
class PoolMessage {
  const PoolMessage({required this.id, required this.text, required this.order});
  final String id;
  final String text;
  final int order;
}

/// Filters out inactive/blank-text docs and sorts by `order` — pulled out
/// of the Firestore call so it can be unit tested with plain maps.
List<PoolMessage> buildPool(List<Map<String, dynamic>> docs) {
  final pool = docs
      .map((data) => PoolMessage(
            id: data['id'] as String? ?? '',
            text: (data['text'] as String?)?.trim() ?? '',
            order: (data['order'] as num?)?.toInt() ?? 0,
          ))
      .where((m) => m.text.isNotEmpty)
      .toList()
    ..sort((a, b) => a.order.compareTo(b.order));
  return pool;
}

/// The exact instant a reminder for [day] at [time] should fire, in the
/// same timezone location as [day] — pulled out so tests can construct one
/// without going through the platform timezone plugin.
tz.TZDateTime resolveScheduledTime(tz.TZDateTime day, TimeOfDay time) {
  return tz.TZDateTime(
    day.location,
    day.year,
    day.month,
    day.day,
    time.hour,
    time.minute,
  );
}

/// Whether [scheduled] has already passed [now] — a reminder in this state
/// is skipped rather than fired immediately/in the past. This is the exact
/// boundary check involved when a reminder set for "one minute from now"
/// does or doesn't go out.
bool isInPast(tz.TZDateTime scheduled, tz.TZDateTime now) =>
    scheduled.isBefore(now);

/// Which pool message a given calendar day resolves to under 'manual' or
/// 'random' mode — pulled out of the class so it can be unit tested without
/// any platform/Firestore dependency.
PoolMessage pickMessageForDay(
  List<PoolMessage> pool,
  tz.TZDateTime day,
  String mode,
  int deviceSeed,
) {
  final daysSinceEpoch = day.millisecondsSinceEpoch ~/ (1000 * 60 * 60 * 24);
  if (mode == 'manual') {
    return pool[daysSinceEpoch % pool.length];
  }
  final random = Random(deviceSeed ^ daysSinceEpoch);
  return pool[random.nextInt(pool.length)];
}
