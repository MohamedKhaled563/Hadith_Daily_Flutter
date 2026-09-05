import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/data/services/notification_data_source.dart';
import 'package:hadith_app/data/services/notification_scheduler.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class _MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

class _MockAndroidPlugin extends Mock
    implements AndroidFlutterLocalNotificationsPlugin {}

/// In-memory stand-in for Firestore — lets tests control the pool/mode
/// directly, and simulate a read failure, without a network dependency.
class _FakeDataSource implements NotificationDataSource {
  _FakeDataSource({
    this.messages = const [],
    this.mode = 'random',
    this.messagesError,
  });

  List<Map<String, dynamic>> messages;
  String mode;
  Object? messagesError;

  @override
  Future<List<Map<String, dynamic>>> loadActiveMessages() async {
    if (messagesError != null) throw messagesError!;
    return messages;
  }

  @override
  Future<String> loadMode() async => mode;

  @override
  Future<Map<String, dynamic>?> loadMessageById(String id) async {
    return messages.cast<Map<String, dynamic>?>().firstWhere(
          (m) => m?['id'] == id,
          orElse: () => null,
        );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();

  setUpAll(() {
    registerFallbackValue(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ));
    registerFallbackValue(const NotificationDetails());
    registerFallbackValue(tz.TZDateTime.now(tz.UTC));
    registerFallbackValue(AndroidScheduleMode.inexactAllowWhileIdle);
    registerFallbackValue(UILocalNotificationDateInterpretation.absoluteTime);
  });

  late _MockPlugin plugin;
  late _MockAndroidPlugin androidPlugin;

  /// Wires the mock plugin with the "happy path" stubs every reschedule()
  /// call needs, then lets each test override the specific behaviour (exact
  /// alarm availability, permission grants, ...) it cares about.
  void stubPluginDefaults({bool canScheduleExact = true}) {
    when(() => plugin.initialize(
          any(),
          onDidReceiveNotificationResponse:
              any(named: 'onDidReceiveNotificationResponse'),
        )).thenAnswer((_) async => true);
    when(() => plugin.cancelAll()).thenAnswer((_) async {});
    when(() => plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()).thenReturn(androidPlugin);
    when(() => plugin.zonedSchedule(
          any(),
          any(),
          any(),
          any(),
          any(),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          uiLocalNotificationDateInterpretation:
              any(named: 'uiLocalNotificationDateInterpretation'),
          payload: any(named: 'payload'),
        )).thenAnswer((_) async {});
    when(() => plugin.pendingNotificationRequests())
        .thenAnswer((_) async => <PendingNotificationRequest>[]);
    when(() => androidPlugin.requestNotificationsPermission())
        .thenAnswer((_) async => true);
    when(() => androidPlugin.requestExactAlarmsPermission())
        .thenAnswer((_) async => true);
    when(() => androidPlugin.canScheduleExactNotifications())
        .thenAnswer((_) async => canScheduleExact);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    plugin = _MockPlugin();
    androidPlugin = _MockAndroidPlugin();
    stubPluginDefaults();
  });

  const activePool = [
    {'text': 'رسالة أولى', 'order': 2, 'active': true},
    {'text': 'رسالة ثانية', 'order': 1, 'active': true},
  ];

  group('buildPool', () {
    test('sorts by order and drops blank/whitespace-only text', () {
      final pool = buildPool([
        {'text': '  ', 'order': 0},
        {'text': 'ثانية', 'order': 2},
        {'text': 'أولى', 'order': 1},
      ]);

      expect(pool.map((m) => m.text).toList(), ['أولى', 'ثانية']);
    });

    test('treats a missing order as 0 rather than throwing', () {
      final pool = buildPool([
        {'text': 'بدون ترتيب'},
      ]);

      expect(pool, hasLength(1));
      expect(pool.single.order, 0);
    });

    test('returns an empty pool for an empty input', () {
      expect(buildPool(const []), isEmpty);
    });
  });

  group('pickMessageForDay', () {
    final pool = buildPool(activePool); // ['رسالة ثانية', 'رسالة أولى']
    final day = tz.TZDateTime.utc(2026, 1, 15);

    test('manual mode is deterministic and ignores the device seed', () {
      final a = pickMessageForDay(pool, day, 'manual', 111);
      final b = pickMessageForDay(pool, day, 'manual', 999);

      expect(a, b);
    });

    test('manual mode picks by daysSinceEpoch, not insertion order', () {
      final daysSinceEpoch = day.millisecondsSinceEpoch ~/ 86400000;
      final expected = pool[daysSinceEpoch % pool.length];

      expect(pickMessageForDay(pool, day, 'manual', 0), same(expected));
    });

    test('random mode is stable for the same device seed and day', () {
      final a = pickMessageForDay(pool, day, 'random', 42);
      final b = pickMessageForDay(pool, day, 'random', 42);

      expect(a, b);
    });

    test('random mode can diverge for a different device seed', () {
      // Not a mathematical guarantee for every seed pair, but true for this
      // pinned pool/day/seed combination — pins the "different devices can
      // see different picks" behaviour the design relies on.
      final a = pickMessageForDay(pool, day, 'random', 1);
      final b = pickMessageForDay(pool, day, 'random', 2);

      expect(a == b, isFalse);
    });
  });

  group('resolveScheduledTime / isInPast', () {
    test('reproduces the reported bug window: set for one minute ahead', () {
      final now = tz.TZDateTime(tz.UTC, 2026, 9, 5, 11, 53);
      final day = tz.TZDateTime(tz.UTC, 2026, 9, 5);
      final scheduled =
          resolveScheduledTime(day, const TimeOfDay(hour: 11, minute: 54));

      expect(isInPast(scheduled, now), isFalse,
          reason: '11:54 is one minute after 11:53 and must still be '
              'scheduleable');
    });

    test('a time already passed today is treated as in the past', () {
      final now = tz.TZDateTime(tz.UTC, 2026, 9, 5, 11, 55);
      final day = tz.TZDateTime(tz.UTC, 2026, 9, 5);
      final scheduled =
          resolveScheduledTime(day, const TimeOfDay(hour: 11, minute: 54));

      expect(isInPast(scheduled, now), isTrue);
    });
  });

  group('NotificationScheduler.reschedule', () {
    test('schedules nothing and succeeds when both reminders are disabled',
        () async {
      final scheduler = NotificationScheduler.test(
        plugin: plugin,
        dataSource: _FakeDataSource(messages: activePool),
      );

      final result = await scheduler.reschedule(
        morningEnabled: false,
        morningTime: const TimeOfDay(hour: 8, minute: 0),
        eveningEnabled: false,
        eveningTime: const TimeOfDay(hour: 20, minute: 0),
      );

      expect(result.succeeded, isTrue);
      expect(result.scheduledCount, 0);
      verifyNever(() => plugin.zonedSchedule(any(), any(), any(), any(),
          any(),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          uiLocalNotificationDateInterpretation:
              any(named: 'uiLocalNotificationDateInterpretation')));
    });

    test('always clears the previous schedule before laying a new one',
        () async {
      final scheduler = NotificationScheduler.test(
        plugin: plugin,
        dataSource: _FakeDataSource(messages: activePool),
      );

      await scheduler.reschedule(
        morningEnabled: false,
        morningTime: const TimeOfDay(hour: 8, minute: 0),
        eveningEnabled: false,
        eveningTime: const TimeOfDay(hour: 20, minute: 0),
      );

      verify(() => plugin.cancelAll()).called(1);
    });

    test('schedules nothing when the message pool is empty', () async {
      final scheduler = NotificationScheduler.test(
        plugin: plugin,
        dataSource: _FakeDataSource(messages: const []),
      );

      final result = await scheduler.reschedule(
        morningEnabled: true,
        morningTime: const TimeOfDay(hour: 8, minute: 0),
        eveningEnabled: false,
        eveningTime: const TimeOfDay(hour: 20, minute: 0),
      );

      expect(result.succeeded, isTrue);
      expect(result.scheduledCount, 0);
    });

    test(
        'falls back to the bundled pool instead of failing when the data '
        'source errors and nothing is cached yet (a first-ever launch with '
        'no connectivity at all) — reminders are meant to feel fully '
        'on-device, so this schedules something generic rather than '
        'reporting "check your internet" for a feature that was never '
        'supposed to depend on the network', () async {
      final scheduler = NotificationScheduler.test(
        plugin: plugin,
        dataSource: _FakeDataSource(
          messagesError: Exception('offline, no cached Firestore data'),
        ),
      );

      final result = await scheduler.reschedule(
        morningEnabled: true,
        morningTime: const TimeOfDay(hour: 23, minute: 59),
        eveningEnabled: false,
        eveningTime: const TimeOfDay(hour: 20, minute: 0),
      );

      expect(result.succeeded, isTrue);
      expect(result.error, isNull);
      expect(result.scheduledCount, greaterThan(0));
    });

    test(
        'skips today when the requested time already passed, but still '
        'queues the remaining days ahead', () async {
      final scheduler = NotificationScheduler.test(
        plugin: plugin,
        dataSource: _FakeDataSource(messages: activePool, mode: 'manual'),
      );

      // Midnight has unconditionally already passed by the time this test
      // runs "today", so offset 0 (today) must be skipped.
      final result = await scheduler.reschedule(
        morningEnabled: true,
        morningTime: const TimeOfDay(hour: 0, minute: 0),
        eveningEnabled: false,
        eveningTime: const TimeOfDay(hour: 20, minute: 0),
      );

      expect(result.succeeded, isTrue);
      expect(result.scheduledCount, 13); // 14 days ahead minus today
    });

    test('schedules today too when the requested time is still ahead',
        () async {
      final scheduler = NotificationScheduler.test(
        plugin: plugin,
        dataSource: _FakeDataSource(messages: activePool, mode: 'manual'),
      );

      // 23:59 is still ahead of "now" for the entire test run (unless it
      // happens to execute at 23:59 itself).
      final result = await scheduler.reschedule(
        morningEnabled: true,
        morningTime: const TimeOfDay(hour: 23, minute: 59),
        eveningEnabled: false,
        eveningTime: const TimeOfDay(hour: 20, minute: 0),
      );

      expect(result.scheduledCount, 14);
    });

    test('morning and evening both enabled schedule twice as many entries',
        () async {
      final scheduler = NotificationScheduler.test(
        plugin: plugin,
        dataSource: _FakeDataSource(messages: activePool, mode: 'manual'),
      );

      final result = await scheduler.reschedule(
        morningEnabled: true,
        morningTime: const TimeOfDay(hour: 23, minute: 58),
        eveningEnabled: true,
        eveningTime: const TimeOfDay(hour: 23, minute: 59),
      );

      expect(result.scheduledCount, 28);
    });

    test(
        'uses exact alarms when the OS reports them available — the fix for '
        'reminders being silently delayed/dropped', () async {
      stubPluginDefaults(canScheduleExact: true);
      final scheduler = NotificationScheduler.test(
        plugin: plugin,
        dataSource: _FakeDataSource(messages: activePool),
      );

      final result = await scheduler.reschedule(
        morningEnabled: true,
        morningTime: const TimeOfDay(hour: 23, minute: 59),
        eveningEnabled: false,
        eveningTime: const TimeOfDay(hour: 20, minute: 0),
      );

      expect(result.usedExactAlarms, isTrue);
      final captured = verify(() => plugin.zonedSchedule(
            any(),
            any(),
            any(),
            any(),
            any(),
            androidScheduleMode: captureAny(named: 'androidScheduleMode'),
            uiLocalNotificationDateInterpretation:
                any(named: 'uiLocalNotificationDateInterpretation'),
            payload: any(named: 'payload'),
          )).captured;
      expect(captured, isNotEmpty);
      expect(captured, everyElement(AndroidScheduleMode.exactAllowWhileIdle));
    });

    test(
        'falls back to inexact alarms when exact-alarm permission is not '
        'available', () async {
      stubPluginDefaults(canScheduleExact: false);
      final scheduler = NotificationScheduler.test(
        plugin: plugin,
        dataSource: _FakeDataSource(messages: activePool),
      );

      final result = await scheduler.reschedule(
        morningEnabled: true,
        morningTime: const TimeOfDay(hour: 23, minute: 59),
        eveningEnabled: false,
        eveningTime: const TimeOfDay(hour: 20, minute: 0),
      );

      expect(result.usedExactAlarms, isFalse);
      final captured = verify(() => plugin.zonedSchedule(
            any(),
            any(),
            any(),
            any(),
            any(),
            androidScheduleMode: captureAny(named: 'androidScheduleMode'),
            uiLocalNotificationDateInterpretation:
                any(named: 'uiLocalNotificationDateInterpretation'),
            payload: any(named: 'payload'),
          )).captured;
      expect(
          captured, everyElement(AndroidScheduleMode.inexactAllowWhileIdle));
    });

    test('the device seed is generated once and reused on later calls',
        () async {
      final scheduler = NotificationScheduler.test(
        plugin: plugin,
        dataSource: _FakeDataSource(messages: activePool, mode: 'random'),
      );

      await scheduler.reschedule(
        morningEnabled: true,
        morningTime: const TimeOfDay(hour: 8, minute: 0),
        eveningEnabled: false,
        eveningTime: const TimeOfDay(hour: 20, minute: 0),
      );
      final prefs = await SharedPreferences.getInstance();
      final firstSeed = prefs.getInt('notificationScheduler.randomSeed');
      expect(firstSeed, isNotNull);

      await scheduler.reschedule(
        morningEnabled: true,
        morningTime: const TimeOfDay(hour: 8, minute: 0),
        eveningEnabled: false,
        eveningTime: const TimeOfDay(hour: 20, minute: 0),
      );
      final secondSeed = prefs.getInt('notificationScheduler.randomSeed');

      expect(secondSeed, firstSeed);
    });
  });

  group('NotificationScheduler.requestPermission', () {
    test('requests both the notification and exact-alarm permissions',
        () async {
      final scheduler = NotificationScheduler.test(
        plugin: plugin,
        dataSource: _FakeDataSource(messages: activePool),
      );

      final granted = await scheduler.requestPermission();

      expect(granted, isTrue);
      verify(() => androidPlugin.requestNotificationsPermission()).called(1);
      verify(() => androidPlugin.requestExactAlarmsPermission()).called(1);
    });

    test('reports ungranted when the notification permission is denied',
        () async {
      when(() => androidPlugin.requestNotificationsPermission())
          .thenAnswer((_) async => false);
      final scheduler = NotificationScheduler.test(
        plugin: plugin,
        dataSource: _FakeDataSource(messages: activePool),
      );

      expect(await scheduler.requestPermission(), isFalse);
    });
  });
}
