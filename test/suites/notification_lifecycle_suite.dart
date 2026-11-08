import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/core/theme/app_state_controller.dart';
import 'package:hadith_app/data/journey/journey_models.dart';
import 'package:hadith_app/data/journey/journey_repository.dart';
import 'package:hadith_app/data/journey/journey_store.dart';
import 'package:hadith_app/data/services/notification_data_source.dart';
import 'package:hadith_app/data/services/notification_lifecycle_refresher.dart';
import 'package:hadith_app/data/services/notification_scheduler.dart';
import 'package:hadith_app/features/dashboard/notification_messages_page.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class _MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

class _MockAndroidPlugin extends Mock
    implements AndroidFlutterLocalNotificationsPlugin {}

class _FakeDataSource implements NotificationDataSource {
  _FakeDataSource({this.messages = const []});

  final List<Map<String, dynamic>> messages;

  @override
  Future<List<Map<String, dynamic>>> loadActiveMessages() async => messages;

  @override
  Future<int?> loadPoolVersion() async => 0;

  @override
  Future<Map<String, dynamic>> loadSchedule() async => const {};
}

/// Covers the pieces added around the scheduler rather than inside it: the
/// resume-driven window refresh, and the dashboard's mirror of the
/// firestore.rules length cap. Runs from both the host and device entry
/// points, same as the scheduler suite.
void notificationLifecycleSuite() {
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
  late NotificationScheduler scheduler;
  late AppStateController state;

  const pool = [
    {'text': 'رسالة أولى', 'order': 0, 'active': true},
    {'text': 'رسالة ثانية', 'order': 1, 'active': true},
  ];

  // Counted in the stub rather than read back with verify(): mocktail's
  // verify() *consumes* the calls it matched, so asking twice reports zero
  // the second time — which silently turns "did this schedule again?" into
  // an assertion that always looks like "no".
  late int scheduleCalls;
  late int clearCalls;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    plugin = _MockPlugin();
    androidPlugin = _MockAndroidPlugin();
    scheduleCalls = 0;
    clearCalls = 0;

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
        )).thenAnswer((_) async {
      scheduleCalls++;
    });
    when(() => plugin.pendingNotificationRequests())
        .thenAnswer((_) async => <PendingNotificationRequest>[]);
    when(() => plugin.cancelAll()).thenAnswer((_) async {
      clearCalls++;
    });
    when(() => androidPlugin.requestNotificationsPermission())
        .thenAnswer((_) async => true);
    when(() => androidPlugin.areNotificationsEnabled())
        .thenAnswer((_) async => true);
    when(() => androidPlugin.canScheduleExactNotifications())
        .thenAnswer((_) async => false);

    scheduler = NotificationScheduler.test(
      plugin: plugin,
      dataSource: _FakeDataSource(messages: pool),
    );

    // AppStateController is a singleton, so put the reminder flags back to
    // a known state rather than inheriting whatever a previous test left.
    state = AppStateController();
    state.toggleMorningReminder(true);
    state.toggleEveningReminder(false);
    state.setMorningReminderTime(const TimeOfDay(hour: 23, minute: 59));
  });

  group('NotificationLifecycleRefresher', () {
    test('lays out the window on the first refresh', () async {
      final refresher = NotificationLifecycleRefresher(
        scheduler: scheduler,
        state: state,
      );

      final result = await refresher.refresh();

      expect(result, isNotNull);
      expect(result!.succeeded, isTrue);
      expect(result.scheduledCount, 14);
    });

    test('does nothing when both reminders are off', () async {
      state.toggleMorningReminder(false);
      state.toggleEveningReminder(false);
      final refresher = NotificationLifecycleRefresher(
        scheduler: scheduler,
        state: state,
      );

      expect(await refresher.refresh(), isNull);
      expect(scheduleCalls, 0);
    });

    test(
        'a second refresh inside the throttle window is skipped — a resume '
        'must not cost ~56 platform calls plus a Firestore read every time',
        () async {
      var now = DateTime(2026, 3, 1, 9);
      final refresher = NotificationLifecycleRefresher(
        scheduler: scheduler,
        state: state,
        clock: () => now,
      );

      expect(await refresher.refresh(), isNotNull);
      final afterFirst = scheduleCalls;

      now = now.add(const Duration(hours: 1));
      expect(await refresher.refresh(), isNull);
      expect(scheduleCalls, afterFirst);
    });

    test('refreshes again once the throttle window has elapsed', () async {
      var now = DateTime(2026, 3, 1, 9);
      final refresher = NotificationLifecycleRefresher(
        scheduler: scheduler,
        state: state,
        clock: () => now,
      );

      await refresher.refresh();
      now = now.add(const Duration(hours: 7));

      expect(await refresher.refresh(), isNotNull);
    });

    test('force bypasses the throttle', () async {
      final now = DateTime(2026, 3, 1, 9);
      final refresher = NotificationLifecycleRefresher(
        scheduler: scheduler,
        state: state,
        clock: () => now,
      );

      await refresher.refresh();
      expect(await refresher.refresh(), isNull);
      expect(await refresher.refresh(force: true), isNotNull);
    });

    test(
        'a resume refreshes the window — the gap that let a long-resident '
        'app run off the end of its own 14-day window and go quiet', () async {
      var now = DateTime(2026, 3, 1, 9);
      final refresher = NotificationLifecycleRefresher(
        scheduler: scheduler,
        state: state,
        clock: () => now,
      );
      await refresher.refresh();
      final afterStart = scheduleCalls;

      now = now.add(const Duration(days: 3));
      refresher.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);

      expect(scheduleCalls, greaterThan(afterStart));
    });

    test('a non-resumed lifecycle state does not refresh', () async {
      final refresher = NotificationLifecycleRefresher(
        scheduler: scheduler,
        state: state,
      );

      refresher.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(Duration.zero);

      expect(scheduleCalls, 0);
    });

    test('a failed refresh does not consume the throttle window', () async {
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
          )).thenThrow(Exception('platform channel down'));
      final now = DateTime(2026, 3, 1, 9);
      final refresher = NotificationLifecycleRefresher(
        scheduler: scheduler,
        state: state,
        clock: () => now,
      );

      final first = await refresher.refresh();
      expect(first!.succeeded, isFalse);

      // Same instant, so only the cleared timestamp can allow this through.
      expect(await refresher.refresh(), isNotNull);
    });
  });

  group('when the reader\'s reading changes the reminders', () {
    late ChangeNotifier changes;
    late String key;
    String? user;

    NotificationLifecycleRefresher started() {
      WidgetsFlutterBinding.ensureInitialized();
      final refresher = NotificationLifecycleRefresher(
        scheduler: scheduler,
        state: state,
        planChanges: changes,
        planKey: () => key,
        currentUser: () => user,
        planSettle: const Duration(milliseconds: 5),
      )..start();
      addTearDown(refresher.dispose);
      return refresher;
    }

    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 60));

    void change(String nextKey, {String? nextUser}) {
      key = nextKey;
      user = nextUser;
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      changes.notifyListeners();
    }

    setUp(() {
      changes = ChangeNotifier();
      key = 'before';
      user = 'reader';
    });

    test('re-lays the window at once, ignoring the resume throttle', () async {
      started();
      await settle();
      final afterStart = scheduleCalls;

      change('after', nextUser: 'reader');
      await settle();

      expect(scheduleCalls, greaterThan(afterStart));
    });

    test('a change that leaves the words alone costs nothing', () async {
      started();
      await settle();
      final afterStart = scheduleCalls;

      change('before', nextUser: 'reader');
      await settle();

      expect(scheduleCalls, afterStart);
    });

    test('a burst of changes re-lays the window once', () async {
      started();
      await settle();
      final afterStart = scheduleCalls;

      change('one', nextUser: 'reader');
      change('two', nextUser: 'reader');
      change('three', nextUser: 'reader');
      await settle();

      expect(scheduleCalls, afterStart + 14);
    });

    test('signing out clears the shade before re-laying the window', () async {
      started();
      await settle();

      change('guest');
      await settle();

      expect(clearCalls, 1, reason: 'a shown reminder names their reading');
    });

    test('signing in clears nothing', () async {
      user = null;
      started();
      await settle();

      change('signed-in', nextUser: 'reader');
      await settle();

      expect(clearCalls, 0);
    });

    test('reminders switched off elsewhere still come off this phone',
        () async {
      started();
      await settle();
      state.toggleMorningReminder(false);
      state.toggleEveningReminder(false);

      change('both-off', nextUser: 'reader');
      await settle();

      verify(() => plugin.cancel(any(), tag: any(named: 'tag')))
          .called(greaterThan(0));
    });
  });

  group('reminder settings on the account', () {
    late InMemoryJourneyStore store;

    Future<void> signedInTo(ReminderPrefs? saved) async {
      store = InMemoryJourneyStore();
      if (saved != null) await store.savePrefs('reader', saved);
      await JourneyRepository().debugReset(store: store);
      JourneyRepository().setUser('reader');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      state.syncRemindersWithAccount();
    }

    tearDown(() => JourneyRepository().debugReset());

    test('an account with none takes this phone\'s', () async {
      await signedInTo(null);

      expect(store.dataOf('reader').prefs, state.reminderPrefs);
    });

    test('the account\'s settings reach a new phone', () async {
      await signedInTo(const ReminderPrefs(
        morningOn: false,
        morning: '06:15',
        eveningOn: true,
        evening: '21:45',
      ));

      expect(state.morningReminderEnabled, isFalse);
      expect(state.morningReminderTime, const TimeOfDay(hour: 6, minute: 15));
      expect(state.eveningReminderEnabled, isTrue);
      expect(state.eveningReminderTime, const TimeOfDay(hour: 21, minute: 45));
    });

    test('a change on the phone is saved to the account', () async {
      await signedInTo(null);

      state.setEveningReminderTime(const TimeOfDay(hour: 22, minute: 5));

      expect(store.dataOf('reader').prefs?.evening, '22:05');
    });

    test('a guest\'s settings stay on the phone', () async {
      store = InMemoryJourneyStore();
      await JourneyRepository().debugReset(store: store);

      state.setEveningReminderTime(const TimeOfDay(hour: 22, minute: 5));

      expect(store.dataOf('reader').prefs, isNull);
    });

    test('settings that cannot be read are left alone', () async {
      state.setMorningReminderTime(const TimeOfDay(hour: 7, minute: 0));
      await signedInTo(const ReminderPrefs(
        morningOn: true,
        morning: 'not a time',
        eveningOn: true,
        evening: '21:45',
      ));

      expect(state.morningReminderTime, const TimeOfDay(hour: 7, minute: 0));
    });

    test('half a setting is not one to adopt', () {
      expect(ReminderPrefs.fromJson({'morningOn': true}), isNull);
      expect(ReminderPrefs.fromJson(null), isNull);
    });

    test('a reading keeps the settings', () {
      const prefs = ReminderPrefs(
        morningOn: true,
        morning: '08:30',
        eveningOn: true,
        evening: '20:00',
      );
      final data = JourneyData.empty.withPrefs(prefs).apply(
            const JourneyEvent(dayKey: '2026-11-07', messageId: 'm'),
          );

      expect(data.prefs, prefs);
    });
  });

  group('validateNotificationText', () {
    test('accepts an ordinary message', () {
      expect(validateNotificationText('رسالة قصيرة'), isNull);
    });

    test('rejects blank and whitespace-only text', () {
      expect(validateNotificationText(''), isNotNull);
      expect(validateNotificationText('   '), isNotNull);
    });

    test('accepts text exactly at the rules cap', () {
      expect(
        validateNotificationText('ب' * kNotificationTextMaxLength),
        isNull,
      );
    });

    test(
        'rejects text past the rules cap, which would otherwise fail the '
        'write with PERMISSION_DENIED and no UI feedback at all', () {
      final problem =
          validateNotificationText('ب' * (kNotificationTextMaxLength + 1));

      expect(problem, isNotNull);
      expect(problem, contains('${kNotificationTextMaxLength + 1}'));
    });

    test('measures the trimmed length, matching what actually gets written',
        () {
      final padded = '  ${'ب' * kNotificationTextMaxLength}  ';

      expect(validateNotificationText(padded), isNull);
    });
  });
}
