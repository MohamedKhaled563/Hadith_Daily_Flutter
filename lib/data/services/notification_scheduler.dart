import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

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
class NotificationScheduler {
  NotificationScheduler._internal();
  static final NotificationScheduler instance = NotificationScheduler._internal();
  factory NotificationScheduler() => instance;

  static const _daysAhead = 14;
  static const _randomSeedKey = 'notificationScheduler.randomSeed';

  final _plugin = FlutterLocalNotificationsPlugin();
  final _db = FirebaseFirestore.instance;
  bool _tzReady = false;

  Future<void> _ensureInitialized() async {
    if (_tzReady) return;

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
    );

    _tzReady = true;
  }

  /// Android 13+/iOS need an explicit runtime grant before any notification
  /// can show — call this once, e.g. the first time a reminder is enabled.
  Future<bool> requestPermission() async {
    await _ensureInitialized();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
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
  Future<void> reschedule({
    required bool morningEnabled,
    required TimeOfDay morningTime,
    required bool eveningEnabled,
    required TimeOfDay eveningTime,
  }) async {
    await _ensureInitialized();
    await _plugin.cancelAll();

    if (!morningEnabled && !eveningEnabled) return;

    final pool = await _loadPool();
    if (pool.isEmpty) return;

    final mode = await _mode();
    final seed = await _deviceSeed();
    final now = tz.TZDateTime.now(tz.local);

    for (var offset = 0; offset < _daysAhead; offset++) {
      final day = tz.TZDateTime(tz.local, now.year, now.month, now.day)
          .add(Duration(days: offset));
      final message = _pickForDay(pool, day, mode, seed);

      if (morningEnabled) {
        await _scheduleOne(
          id: offset * 2,
          day: day,
          time: morningTime,
          title: 'رسالة الصباح 🌅',
          body: message,
          now: now,
        );
      }
      if (eveningEnabled) {
        await _scheduleOne(
          id: offset * 2 + 1,
          day: day,
          time: eveningTime,
          title: 'تأمل المساء 🌙',
          body: message,
          now: now,
        );
      }
    }
  }

  Future<void> _scheduleOne({
    required int id,
    required tz.TZDateTime day,
    required TimeOfDay time,
    required String title,
    required String body,
    required tz.TZDateTime now,
  }) async {
    final scheduled = tz.TZDateTime(
      tz.local,
      day.year,
      day.month,
      day.day,
      time.hour,
      time.minute,
    );
    if (scheduled.isBefore(now)) return;

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
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<List<_PoolMessage>> _loadPool() async {
    final snapshot = await _db
        .collection('notificationMessages')
        .where('active', isEqualTo: true)
        .get();
    final pool = snapshot.docs
        .map((doc) => _PoolMessage(
              text: (doc.data()['text'] as String?)?.trim() ?? '',
              order: (doc.data()['order'] as num?)?.toInt() ?? 0,
            ))
        .where((m) => m.text.isNotEmpty)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return pool;
  }

  Future<String> _mode() async {
    try {
      final doc = await _db.collection('settings').doc('notificationMode').get();
      return doc.data()?['mode'] == 'manual' ? 'manual' : 'random';
    } catch (_) {
      return 'random';
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

  String _pickForDay(
    List<_PoolMessage> pool,
    tz.TZDateTime day,
    String mode,
    int deviceSeed,
  ) {
    final daysSinceEpoch = day.millisecondsSinceEpoch ~/ (1000 * 60 * 60 * 24);
    if (mode == 'manual') {
      return pool[daysSinceEpoch % pool.length].text;
    }
    final random = Random(deviceSeed ^ daysSinceEpoch);
    return pool[random.nextInt(pool.length)].text;
  }
}

class _PoolMessage {
  const _PoolMessage({required this.text, required this.order});
  final String text;
  final int order;
}
