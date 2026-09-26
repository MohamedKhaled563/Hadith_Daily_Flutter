import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/data/services/notification_data_source.dart';
import 'package:hadith_app/data/services/notification_scheduler.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// The notification suite lives here rather than directly in a `_test.dart`
/// file so the *same* body can run from two entry points:
///
///   * `test/data/services/notification_scheduler_test.dart` — the ordinary
///     host run (`flutter test`), for CI and any machine where that works.
///   * `integration_test/notification_scheduler_test.dart` — the same tests
///     inside a real app process on a real device/emulator
///     (`flutter test integration_test/... -d <id>`).
///
/// The second entry point is not a nicety here: this development machine's
/// Application Control policy refuses to launch `flutter_tester.exe`, so the
/// host run cannot execute at all. It is also the stronger signal for a
/// feature that is mostly platform-channel work — the device run exercises
/// the real SharedPreferences store and the real timezone database.
class _MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

class _MockAndroidPlugin extends Mock
    implements AndroidFlutterLocalNotificationsPlugin {}

/// In-memory stand-in for Firestore — lets tests control the pool
/// directly, and simulate a read failure, without a network dependency.
class _FakeDataSource implements NotificationDataSource {
  _FakeDataSource({
    this.messages = const [],
    this.messagesError,
  });

  List<Map<String, dynamic>> messages;
  Object? messagesError;

  /// When set, [loadActiveMessages] blocks on it. Lets a test park one `reschedule()`
  /// mid-flight — deterministically, at a known point — and run a second one
  /// to completion behind it, which is how the concurrent-reschedule race is
  /// reproduced without depending on timing.
  Completer<void>? messagesGate;

  @override
  Future<List<Map<String, dynamic>>> loadActiveMessages() async {
    final gate = messagesGate;
    if (gate != null) await gate.future;
    if (messagesError != null) throw messagesError!;
    return messages;
  }
}

void notificationSchedulerSuite() {
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
  void stubPluginDefaults({
    bool canScheduleExact = true,
    List<PendingNotificationRequest> pending = const [],
  }) {
    when(() => plugin.initialize(
          any(),
          onDidReceiveNotificationResponse:
              any(named: 'onDidReceiveNotificationResponse'),
        )).thenAnswer((_) async => true);
    when(() => plugin.cancel(any(), tag: any(named: 'tag')))
        .thenAnswer((_) async {});
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
        .thenAnswer((_) async => pending);
    when(() => androidPlugin.requestNotificationsPermission())
        .thenAnswer((_) async => true);
    when(() => androidPlugin.requestExactAlarmsPermission())
        .thenAnswer((_) async => true);
    when(() => androidPlugin.canScheduleExactNotifications())
        .thenAnswer((_) async => canScheduleExact);
  }

  /// Asserts how many notifications actually reached the platform. Split on
  /// [count] because mocktail's `verify()` throws outright when nothing
  /// matched, rather than reporting a count of zero.
  void expectZonedScheduleCount(int count, {String? reason}) {
    if (count == 0) {
      verifyNever(() => plugin.zonedSchedule(
            any(),
            any(),
            any(),
            any(),
            any(),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            uiLocalNotificationDateInterpretation:
                any(named: 'uiLocalNotificationDateInterpretation'),
            payload: any(named: 'payload'),
          ));
      return;
    }
    verify(() => plugin.zonedSchedule(
          any(),
          any(),
          any(),
          any(),
          any(),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          uiLocalNotificationDateInterpretation:
              any(named: 'uiLocalNotificationDateInterpretation'),
          payload: any(named: 'payload'),
        )).called(count);
  }

  /// What every scheduler built here believes "now" is: a fixed mid-morning
  /// instant, so "23:59 is still ahead" and "00:00 has already passed" are
  /// facts rather than things that happen to be true most of the day. These
  /// assertions used to ride the real wall clock and would have quietly
  /// changed meaning — or failed — on a late-night run.
  final pinnedNow = DateTime(2026, 9, 21, 10, 30);
  DateTime clock() => pinnedNow;

  NotificationScheduler schedulerWith(NotificationDataSource dataSource) =>
      NotificationScheduler.test(
        plugin: plugin,
        dataSource: dataSource,
        clock: clock,
      );

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

    test('is stable for the same device seed and day', () {
      final a = pickMessageForDay(pool, day, 42);
      final b = pickMessageForDay(pool, day, 42);

      expect(a, b);
    });

    test('can diverge for a different device seed', () {
      // Not a mathematical guarantee for every seed pair, but true for this
      // pinned pool/day/seed combination — pins the "different devices can
      // see different picks" behaviour the design relies on.
      final a = pickMessageForDay(pool, day, 1);
      final b = pickMessageForDay(pool, day, 2);

      expect(a == b, isFalse);
    });

    test('the evening never repeats the morning while the pool allows it', () {
      for (var seed = 0; seed < 200; seed++) {
        expect(
          pickMessageForDay(pool, day, seed, slot: 1),
          isNot(same(pickMessageForDay(pool, day, seed, slot: 0))),
          reason: 'seed $seed',
        );
      }
    });

    test('a one-message pool serves both slots', () {
      final single = pool.take(1).toList();

      expect(pickMessageForDay(single, day, 7, slot: 0), same(single.first));
      expect(pickMessageForDay(single, day, 7, slot: 1), same(single.first));
    });

    test('ignores the time-of-day component of the given day', () {
      final midnight = DateTime(2026, 1, 15);
      final lateEvening = DateTime(2026, 1, 15, 23, 30);

      expect(
        pickMessageForDay(pool, midnight, 5),
        same(pickMessageForDay(pool, lateEvening, 5)),
      );
    });
  });

  group('resolveScheduledTime / isInPast', () {
    // Deliberately plain (non-UTC, non-TZDateTime) DateTimes: reschedule()
    // now does all of its local-time arithmetic this way on purpose — see
    // its doc comment — specifically to stay correct even when the
    // `timezone` package's bundled offset table for the device's zone is
    // wrong (as it was for Africa/Cairo, the bug these two tests are named
    // after). Mixing in a UTC TZDateTime here would silently reintroduce
    // exactly that class of bug into the test itself on any machine whose
    // local offset isn't zero.
    test('reproduces the reported bug window: set for one minute ahead', () {
      final now = DateTime(2026, 9, 5, 11, 53);
      final day = DateTime(2026, 9, 5);
      final scheduled =
          resolveScheduledTime(day, const TimeOfDay(hour: 11, minute: 54));

      expect(isInPast(scheduled, now), isFalse,
          reason: '11:54 is one minute after 11:53 and must still be '
              'scheduleable');
    });

    test('a time already passed today is treated as in the past', () {
      final now = DateTime(2026, 9, 5, 11, 55);
      final day = DateTime(2026, 9, 5);
      final scheduled =
          resolveScheduledTime(day, const TimeOfDay(hour: 11, minute: 54));

      expect(isInPast(scheduled, now), isTrue);
    });
  });

  group('NotificationScheduler.reschedule', () {
    test('schedules nothing and succeeds when both reminders are disabled',
        () async {
      final scheduler = schedulerWith(_FakeDataSource(messages: activePool));

      final result = await scheduler.reschedule(
        morningEnabled: false,
        morningTime: const TimeOfDay(hour: 8, minute: 0),
        eveningEnabled: false,
        eveningTime: const TimeOfDay(hour: 20, minute: 0),
      );

      expect(result.succeeded, isTrue);
      expect(result.scheduledCount, 0);
      expectZonedScheduleCount(0);
    });

    test(
        'clears every future slot (but never a past one) when both '
        'reminders are disabled — using per-id cancel rather than '
        'cancelAll(), which would also dismiss whatever is currently '
        'showing in the notification shade', () async {
      final scheduler = schedulerWith(_FakeDataSource(messages: activePool));

      await scheduler.reschedule(
        morningEnabled: false,
        morningTime: const TimeOfDay(hour: 8, minute: 0),
        eveningEnabled: false,
        eveningTime: const TimeOfDay(hour: 20, minute: 0),
      );

      // 14 days ahead, two slots/day = up to 28 cancels; at least the 13
      // guaranteed-future days' worth (today's own two slots may or may not
      // have already passed depending on wall-clock time when this runs).
      verify(() => plugin.cancel(any(), tag: any(named: 'tag')))
          .called(greaterThanOrEqualTo(26));
      expectZonedScheduleCount(0);
    });

    test(
        'falls back to the bundled pool when the live fetch succeeds but '
        'comes back empty — this used to schedule nothing at all, so '
        'deactivating every message from the dashboard silently stopped '
        "every reader's reminders with succeeded: true and no signal",
        () async {
      final scheduler = schedulerWith(_FakeDataSource(messages: const []));

      final result = await scheduler.reschedule(
        morningEnabled: true,
        morningTime: const TimeOfDay(hour: 23, minute: 59),
        eveningEnabled: false,
        eveningTime: const TimeOfDay(hour: 20, minute: 0),
      );

      expect(result.succeeded, isTrue);
      expect(result.scheduledCount, 14);
    });

    // ---- Bug 2 -----------------------------------------------------------
    test(
        'still clears every future slot when the pool is empty — switching '
        'reminders off must take effect even if nothing can be scheduled, '
        'or the reader turns them off and keeps getting yesterday\'s queue',
        () async {
      final scheduler = schedulerWith(_FakeDataSource(messages: const []));

      final result = await scheduler.reschedule(
        morningEnabled: false,
        morningTime: const TimeOfDay(hour: 8, minute: 0),
        eveningEnabled: false,
        eveningTime: const TimeOfDay(hour: 20, minute: 0),
      );

      expect(result.succeeded, isTrue);
      verify(() => plugin.cancel(any(), tag: any(named: 'tag')))
          .called(greaterThanOrEqualTo(26));
    });

    test(
        'falls back to the bundled pool instead of failing when the data '
        'source errors and nothing is cached yet (a first-ever launch with '
        'no connectivity at all) — reminders are meant to feel fully '
        'on-device, so this schedules something generic rather than '
        'reporting "check your internet" for a feature that was never '
        'supposed to depend on the network', () async {
      final scheduler = schedulerWith(_FakeDataSource(
          messagesError: Exception('offline, no cached Firestore data')),
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

    // ---- Bug 8 -----------------------------------------------------------
    test(
        'falls back to the bundled pool when the cached pool is corrupt — a '
        'truncated SharedPreferences value used to throw straight past the '
        'fallback and surface as "تعذّر جدولة التذكيرات: FormatException"',
        () async {
      SharedPreferences.setMockInitialValues({
        'notificationScheduler.cachedPool': '[{"id":"a","text":"ب"',
      });
      final scheduler = schedulerWith(_FakeDataSource(messagesError: Exception('offline')));

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

    test('reads the cached pool back when the live fetch fails', () async {
      final scheduler = schedulerWith(_FakeDataSource(messages: activePool));

      // Populate the cache from a successful run...
      await scheduler.reschedule(
        morningEnabled: true,
        morningTime: const TimeOfDay(hour: 23, minute: 59),
        eveningEnabled: false,
        eveningTime: const TimeOfDay(hour: 20, minute: 0),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('notificationScheduler.cachedPool'), isNotNull);

      // ...then fail the live fetch and confirm the cache carried it.
      final offline = schedulerWith(_FakeDataSource(messagesError: Exception('offline')));
      final result = await offline.reschedule(
        morningEnabled: true,
        morningTime: const TimeOfDay(hour: 23, minute: 59),
        eveningEnabled: false,
        eveningTime: const TimeOfDay(hour: 20, minute: 0),
      );

      expect(result.succeeded, isTrue);
      expect(result.scheduledCount, 14);
    });

    test(
        'skips today when the requested time already passed, but still '
        'queues the remaining days ahead', () async {
      final scheduler = schedulerWith(_FakeDataSource(messages: activePool));

      // Midnight is behind the pinned clock (10:30), so offset 0 (today)
      // must be skipped.
      final result = await scheduler.reschedule(
        morningEnabled: true,
        morningTime: const TimeOfDay(hour: 0, minute: 0),
        eveningEnabled: false,
        eveningTime: const TimeOfDay(hour: 20, minute: 0),
      );

      expect(result.succeeded, isTrue);
      expect(result.scheduledCount, 13); // 14 days ahead minus today
      // id 0 is today's morning slot (offset 0 * 2) — its time (midnight)
      // is already past AND nothing is pending under that id, so it must be
      // left completely untouched: no cancel, no reschedule. This is what
      // stops a reminder that already fired (and may still be sitting in
      // the shade) from being wiped out by the very next reschedule() call,
      // e.g. when the reader opens the app to check whether it arrived.
      verifyNever(() => plugin.cancel(0, tag: any(named: 'tag')));
    });

    // ---- Bug 1 -----------------------------------------------------------
    test(
        'cancels a still-pending alarm for today even when the newly chosen '
        'time has already passed — moving a reminder earlier must not leave '
        'the old, later alarm armed for tonight', () async {
      // Simulates "morning was 21:00 (still queued as id 0), reader moves it
      // to 07:00 at 09:00". The new time is in the past, but id 0 is still
      // *pending*, which by definition means it has not fired yet — so it is
      // a stale alarm to clear, not a delivered notification to protect.
      stubPluginDefaults(pending: const [
        PendingNotificationRequest(0, 'رسالة الصباح', 'قديم', 'p'),
      ]);
      final scheduler = schedulerWith(_FakeDataSource(messages: activePool));

      await scheduler.reschedule(
        morningEnabled: true,
        morningTime: const TimeOfDay(hour: 0, minute: 0), // already past
        eveningEnabled: false,
        eveningTime: const TimeOfDay(hour: 20, minute: 0),
      );

      verify(() => plugin.cancel(0, tag: any(named: 'tag'))).called(1);
    });

    test(
        'a past slot with nothing pending is still left alone — an already '
        'delivered reminder stays in the shade', () async {
      stubPluginDefaults(pending: const [
        PendingNotificationRequest(2, 'غداً', 'نص', 'p'),
      ]);
      final scheduler = schedulerWith(_FakeDataSource(messages: activePool));

      await scheduler.reschedule(
        morningEnabled: true,
        morningTime: const TimeOfDay(hour: 0, minute: 0),
        eveningEnabled: false,
        eveningTime: const TimeOfDay(hour: 20, minute: 0),
      );

      verifyNever(() => plugin.cancel(0, tag: any(named: 'tag')));
    });

    test('schedules today too when the requested time is still ahead',
        () async {
      final scheduler = schedulerWith(_FakeDataSource(messages: activePool));

      // 23:59 is ahead of the pinned clock (10:30), so today counts too.
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
      final scheduler = schedulerWith(_FakeDataSource(messages: activePool));

      final result = await scheduler.reschedule(
        morningEnabled: true,
        morningTime: const TimeOfDay(hour: 23, minute: 58),
        eveningEnabled: true,
        eveningTime: const TimeOfDay(hour: 23, minute: 59),
      );

      expect(result.scheduledCount, 28);
    });

    // ---- Design observation: morning/evening shared one body -------------
    test('the morning and evening slots carry different text on a given day',
        () async {
      final scheduler = schedulerWith(_FakeDataSource(messages: activePool));

      await scheduler.reschedule(
        morningEnabled: true,
        morningTime: const TimeOfDay(hour: 23, minute: 58),
        eveningEnabled: true,
        eveningTime: const TimeOfDay(hour: 23, minute: 59),
      );

      final bodies = verify(() => plugin.zonedSchedule(
            captureAny(),
            any(),
            captureAny(),
            any(),
            any(),
            androidScheduleMode: any(named: 'androidScheduleMode'),
            uiLocalNotificationDateInterpretation:
                any(named: 'uiLocalNotificationDateInterpretation'),
            payload: any(named: 'payload'),
          )).captured;

      // captured comes back flat: [id0, body0, id1, body1, ...]
      final byId = <int, String>{};
      for (var i = 0; i < bodies.length; i += 2) {
        byId[bodies[i] as int] = bodies[i + 1] as String;
      }

      expect(byId[0], isNotNull);
      expect(byId[1], isNotNull);
      expect(byId[0], isNot(byId[1]),
          reason: "today's evening reminder repeated the morning's text "
              'verbatim');
    });

    test(
        'uses exact alarms when the OS reports them available — the fix for '
        'reminders being silently delayed/dropped', () async {
      stubPluginDefaults(canScheduleExact: true);
      final scheduler = schedulerWith(_FakeDataSource(messages: activePool));

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
      final scheduler = schedulerWith(_FakeDataSource(messages: activePool));

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
      final scheduler = schedulerWith(_FakeDataSource(messages: activePool));

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

    // ---- Bug 5 -----------------------------------------------------------
    test(
        'reports the notification permission back to the caller, so a denied '
        'grant cannot be presented as a healthy 28-notification schedule',
        () async {
      when(() => androidPlugin.requestNotificationsPermission())
          .thenAnswer((_) async => false);
      final scheduler = schedulerWith(_FakeDataSource(messages: activePool));

      final result = await scheduler.reschedule(
        morningEnabled: true,
        morningTime: const TimeOfDay(hour: 23, minute: 59),
        eveningEnabled: false,
        eveningTime: const TimeOfDay(hour: 20, minute: 0),
      );

      expect(result.permissionGranted, isFalse,
          reason: 'the OS will never show any of these, and the caller has '
              'no other way to find out');
    });

    test('reports a granted permission when the OS allows notifications',
        () async {
      final scheduler = schedulerWith(_FakeDataSource(messages: activePool));

      final result = await scheduler.reschedule(
        morningEnabled: true,
        morningTime: const TimeOfDay(hour: 23, minute: 59),
        eveningEnabled: false,
        eveningTime: const TimeOfDay(hour: 20, minute: 0),
      );

      expect(result.permissionGranted, isTrue);
    });

    // ---- Bug 3 -----------------------------------------------------------
    test(
        'a reschedule superseded by a newer one does not write its stale '
        'settings to the platform — turning a reminder off while the '
        'start-up reschedule is still in flight must stay off', () async {
      final dataSource =
          _FakeDataSource(messages: activePool);
      final scheduler = schedulerWith(dataSource);

      // Park run A right before it starts laying out its window.
      final gate = Completer<void>();
      dataSource.messagesGate = gate;
      final runA = scheduler.reschedule(
        morningEnabled: true,
        morningTime: const TimeOfDay(hour: 23, minute: 59),
        eveningEnabled: true,
        eveningTime: const TimeOfDay(hour: 23, minute: 59),
      );

      // Let A actually reach the gate before B starts.
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // B is the reader switching both reminders off. It runs to completion.
      dataSource.messagesGate = null;
      final resultB = await scheduler.reschedule(
        morningEnabled: false,
        morningTime: const TimeOfDay(hour: 23, minute: 59),
        eveningEnabled: false,
        eveningTime: const TimeOfDay(hour: 23, minute: 59),
      );

      gate.complete();
      final resultA = await runA;

      expect(resultB.succeeded, isTrue);
      expect(resultA.superseded, isTrue);
      // Run A was started with both reminders on and finished last — without
      // a guard it re-arms 28 notifications the reader just switched off.
      expectZonedScheduleCount(0);
    });

    test('a lone reschedule is never reported as superseded', () async {
      final scheduler = schedulerWith(_FakeDataSource(messages: activePool));

      final result = await scheduler.reschedule(
        morningEnabled: true,
        morningTime: const TimeOfDay(hour: 23, minute: 59),
        eveningEnabled: false,
        eveningTime: const TimeOfDay(hour: 20, minute: 0),
      );

      expect(result.superseded, isFalse);
      expect(result.scheduledCount, 14);
    });
  });

  group('NotificationScheduler.requestPermission', () {
    test(
        'requests the notification permission, and never the exact-alarm one',
        () async {
      final scheduler = schedulerWith(_FakeDataSource(messages: activePool));

      final granted = await scheduler.requestPermission();

      expect(granted, isTrue);
      verify(() => androidPlugin.requestNotificationsPermission()).called(1);
      // The app no longer declares SCHEDULE_EXACT_ALARM — Google Play
      // restricts it to alarm-clock/timer/calendar apps, and asking for a
      // permission the manifest doesn't declare is exactly what a policy
      // review looks for. Scheduling still checks
      // canScheduleExactNotifications() and falls back to inexact, which is
      // covered by the reschedule tests above.
      verifyNever(() => androidPlugin.requestExactAlarmsPermission());
    });

    test('reports ungranted when the notification permission is denied',
        () async {
      when(() => androidPlugin.requestNotificationsPermission())
          .thenAnswer((_) async => false);
      final scheduler = schedulerWith(_FakeDataSource(messages: activePool));

      expect(await scheduler.requestPermission(), isFalse);
    });
  });

  // ---- Bug 6 -------------------------------------------------------------
  group('iOS initialization settings', () {
    test(
        'never requests notification permission from initialize() — on iOS '
        'that fires the system prompt on the first frame of Home, before a '
        'new reader has seen anything', () {
      const settings = NotificationScheduler.darwinInitSettings;

      expect(settings.requestAlertPermission, isFalse);
      expect(settings.requestSoundPermission, isFalse);
      expect(settings.requestBadgePermission, isFalse);
    });
  });
}
