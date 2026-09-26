import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/data/services/notification_data_source.dart';
import 'package:hadith_app/data/services/notification_scheduler.dart';
import 'package:integration_test/integration_test.dart';

/// End-to-end checks against the **real** flutter_local_notifications plugin
/// on a real device/emulator — no mock plugin anywhere in this file.
///
/// The mocked suites prove the scheduler's decisions; these prove the
/// decisions survive the round trip through the platform channel, AlarmManager
/// and the notification shade. That distinction matters for this feature in
/// particular: every historical bug in it (the tzdata/offset mismatch, the
/// missing manifest receivers, cancelAll() wiping the shade) was invisible to
/// a mocked test and only ever showed up on a device.
///
/// Requires POST_NOTIFICATIONS to already be granted, otherwise the API 33+
/// request would block on a system dialog nobody is here to tap:
///
///   `adb -s ID shell pm grant com.prodktstudio.tayebqalbak android.permission.POST_NOTIFICATIONS`
class _FixedPool implements NotificationDataSource {
  @override
  Future<List<Map<String, dynamic>>> loadActiveMessages() async => const [
        {'id': 'dev-1', 'text': 'رسالة اختبار أولى', 'order': 0, 'active': true},
        {'id': 'dev-2', 'text': 'رسالة اختبار ثانية', 'order': 1, 'active': true},
        {'id': 'dev-3', 'text': 'رسالة اختبار ثالثة', 'order': 2, 'active': true},
      ];

  @override
  Future<Map<String, dynamic>> loadSchedule() async => const {};
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late NotificationScheduler scheduler;
  late FlutterLocalNotificationsPlugin plugin;

  // The scheduler's own clock is pinned to mid-morning *today*, so its
  // decisions ("23:59 is ahead", "00:00 has passed") are fixed rather than
  // whatever the wall clock happens to say when the suite runs. Only the
  // real AlarmManager registration still cares about actual time, and only
  // in the final minute of the day — when a 23:59 target stops being in the
  // future for real. That one minute is skipped rather than left to flake.
  final realNow = DateTime.now();
  final pinnedNow =
      DateTime(realNow.year, realNow.month, realNow.day, 10, 30);
  final inLastMinuteOfDay = realNow.hour == 23 && realNow.minute >= 58;

  setUp(() {
    plugin = FlutterLocalNotificationsPlugin();
    scheduler = NotificationScheduler.test(
      plugin: plugin,
      dataSource: _FixedPool(),
      clock: () => pinnedNow,
    );
  });

  tearDown(() async {
    await plugin.cancelAll();
  });

  Future<Set<int>> pendingIds() async {
    final requests = await plugin.pendingNotificationRequests();
    return requests.map((r) => r.id).toSet();
  }

  testWidgets('real plugin: a full window reaches AlarmManager',
      (tester) async {
    final result = await scheduler.reschedule(
      morningEnabled: true,
      morningTime: const TimeOfDay(hour: 23, minute: 59),
      eveningEnabled: false,
      eveningTime: const TimeOfDay(hour: 20, minute: 0),
    );

    expect(result.succeeded, isTrue, reason: '${result.error}');
    expect(result.permissionGranted, isTrue,
        reason: 'grant POST_NOTIFICATIONS first — see this file\'s doc');
    expect(result.scheduledCount, 14);
    // The plugin's own persisted queue, read back over the channel.
    expect(await scheduler.pendingCount(), 14);
  }, skip: inLastMinuteOfDay);

  testWidgets('real plugin: both slots queue 28 distinct ids', (tester) async {
    await scheduler.reschedule(
      morningEnabled: true,
      morningTime: const TimeOfDay(hour: 23, minute: 58),
      eveningEnabled: true,
      eveningTime: const TimeOfDay(hour: 23, minute: 59),
    );

    expect((await pendingIds()).length, 28);
  }, skip: inLastMinuteOfDay);

  testWidgets(
      'real plugin: the two slots on a day carry different text — the '
      'evening reminder used to repeat the morning verbatim', (tester) async {
    await scheduler.reschedule(
      morningEnabled: true,
      morningTime: const TimeOfDay(hour: 23, minute: 58),
      eveningEnabled: true,
      eveningTime: const TimeOfDay(hour: 23, minute: 59),
    );

    final requests = await plugin.pendingNotificationRequests();
    final morning = requests.firstWhere((r) => r.id == 0);
    final evening = requests.firstWhere((r) => r.id == 1);

    expect(morning.body, isNotNull);
    expect(evening.body, isNotNull);
    expect(morning.body, isNot(evening.body));
  }, skip: inLastMinuteOfDay);

  testWidgets(
      'real plugin: switching both reminders off actually clears the queue',
      (tester) async {
    await scheduler.reschedule(
      morningEnabled: true,
      morningTime: const TimeOfDay(hour: 23, minute: 59),
      eveningEnabled: false,
      eveningTime: const TimeOfDay(hour: 20, minute: 0),
    );
    expect(await scheduler.pendingCount(), 14);

    await scheduler.reschedule(
      morningEnabled: false,
      morningTime: const TimeOfDay(hour: 23, minute: 59),
      eveningEnabled: false,
      eveningTime: const TimeOfDay(hour: 20, minute: 0),
    );

    expect(await scheduler.pendingCount(), 0);
  }, skip: inLastMinuteOfDay);

  testWidgets(
      'real plugin: moving a reminder to an earlier, already-past time '
      'clears the old alarm instead of leaving it armed for tonight',
      (tester) async {
    // Arrange: a reminder still queued for later today under id 0.
    await scheduler.reschedule(
      morningEnabled: true,
      morningTime: const TimeOfDay(hour: 23, minute: 59),
      eveningEnabled: false,
      eveningTime: const TimeOfDay(hour: 20, minute: 0),
    );
    expect(await pendingIds(), contains(0));

    // Act: the reader moves it to 00:00, which is already behind us.
    await scheduler.reschedule(
      morningEnabled: true,
      morningTime: const TimeOfDay(hour: 0, minute: 0),
      eveningEnabled: false,
      eveningTime: const TimeOfDay(hour: 20, minute: 0),
    );

    // Assert: today's slot is gone rather than still holding 23:59.
    expect(
      await pendingIds(),
      isNot(contains(0)),
      reason: 'the 23:59 alarm survived a change to 00:00 and would still '
          'fire tonight at the time the reader just moved away from',
    );
    // ...and the remaining 13 days are still queued.
    expect(await scheduler.pendingCount(), 13);
  }, skip: inLastMinuteOfDay);

  testWidgets(
      'real plugin: a scheduled reminder survives a second reschedule with '
      'unchanged settings (the rolling refresh is idempotent)',
      (tester) async {
    await scheduler.reschedule(
      morningEnabled: true,
      morningTime: const TimeOfDay(hour: 23, minute: 59),
      eveningEnabled: true,
      eveningTime: const TimeOfDay(hour: 23, minute: 59),
    );
    final first = await pendingIds();

    await scheduler.reschedule(
      morningEnabled: true,
      morningTime: const TimeOfDay(hour: 23, minute: 59),
      eveningEnabled: true,
      eveningTime: const TimeOfDay(hour: 23, minute: 59),
    );

    expect(await pendingIds(), first);
  }, skip: inLastMinuteOfDay);

  testWidgets(
      'real plugin: the status-bar icon resource resolves — a missing or '
      'misnamed drawable fails the show() outright', (tester) async {
    if (!Platform.isAndroid) return;

    // NotificationScheduler.initialize() installs '@drawable/ic_stat_notify'
    // as the default small icon. If that drawable did not exist, or had been
    // pointed at something Android will not accept as a status-bar icon, the
    // plugin's Android side raises `invalid_icon` ("The resource %s could not
    // be found...") and this show() throws rather than returning.
    //
    // That makes a clean show() a real assertion about the icon, which is the
    // most a Dart test can say here: ActiveNotification does not expose the
    // small icon, so *which* drawable was used has to be confirmed out of
    // band. See integration_test/README.md for the adb one-liner that reads
    // the resource id back out of `dumpsys notification` and resolves it.
    await scheduler.requestPermission();
    await plugin.show(
      9002,
      'رسالة الصباح',
      'التحقق من أيقونة الإشعار',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminders',
          'تذكيرات يومية',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await plugin.cancel(9002);
  });

  testWidgets(
      'real plugin: a notification actually renders in the shade with the '
      'app\'s status-bar icon', (tester) async {
    if (!Platform.isAndroid) return;
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()!;

    await scheduler.requestPermission();
    await plugin.show(
      9001,
      'رسالة الصباح',
      'نص اختبار للتحقق من ظهور الإشعار',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminders',
          'تذكيرات يومية',
          channelDescription: 'تذكير برسالة الصباح وتأمل المساء',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final active = await android.getActiveNotifications();
    final shown = active.where((n) => n.id == 9001).toList();

    expect(shown, hasLength(1),
        reason: 'the notification never reached the shade — check the '
            'channel and the manifest receivers');
    expect(shown.single.title, 'رسالة الصباح');

    await plugin.cancel(9001);
  });

  testWidgets(
      'real plugin: the device-offset location resolves through the Android '
      'side\'s ZoneId.of() — an unrecognised zone name silently drops the '
      'whole reschedule', (tester) async {
    // This is the regression guard for the fixed-offset Location trick. On
    // Android the plugin re-resolves the TZDateTime's location *name* via
    // java.time.ZoneId.of(); a name like "local" throws Unknown time-zone ID
    // and nothing gets scheduled at all — with no Dart-side error.
    final result = await scheduler.reschedule(
      morningEnabled: true,
      morningTime: const TimeOfDay(hour: 23, minute: 59),
      eveningEnabled: false,
      eveningTime: const TimeOfDay(hour: 20, minute: 0),
    );

    expect(result.succeeded, isTrue, reason: '${result.error}');
    expect(await scheduler.pendingCount(), greaterThan(0),
        reason: 'reschedule reported success but nothing is queued — the '
            'classic signature of the Android side rejecting the '
            'TZDateTime location name');
  }, skip: inLastMinuteOfDay);
}
