import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/core/theme/app_state_controller.dart';
import 'package:hadith_app/data/journey/journey_engine.dart';
import 'package:hadith_app/data/journey/journey_models.dart';
import 'package:hadith_app/data/journey/journey_repository.dart';
import 'package:hadith_app/data/journey/journey_store.dart';
import 'package:hadith_app/data/repositories/hadith_repository.dart';
import 'package:hadith_app/data/services/journey_reminders.dart';
import 'package:hadith_app/data/services/notification_data_source.dart';
import 'package:hadith_app/data/services/notification_lifecycle_refresher.dart';
import 'package:hadith_app/data/services/notification_planner.dart';
import 'package:hadith_app/data/services/notification_scheduler.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Pool implements NotificationDataSource {
  @override
  Future<List<Map<String, dynamic>>> loadActiveMessages() async => const [
        {'id': 'a', 'text': 'رسالة من القائمة', 'order': 0, 'active': true},
        {'id': 'b', 'text': 'رسالة أخرى', 'order': 1, 'active': true},
      ];

  @override
  Future<int?> loadPoolVersion() async => 0;

  @override
  Future<Map<String, dynamic>> loadSchedule() async => const {};
}

/// Smart reminders through the real notification plugin, so what is checked
/// is what Android actually has queued. The journey runs on an in-memory
/// store, so nothing here reaches Firebase.
///
///     flutter test integration_test/smart_reminders_test.dart -d <device>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final plugin = FlutterLocalNotificationsPlugin();
  final state = AppStateController();
  late NotificationScheduler scheduler;
  late NotificationLifecycleRefresher refresher;
  late InMemoryJourneyStore store;

  const morningId = 0;
  const tonightId = 1;
  const tomorrowEveningId = 3;

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 1200));

  Future<Map<int, PendingNotificationRequest>> pending() async => {
        for (final request in await plugin.pendingNotificationRequests())
          request.id: request,
      };

  /// A reader who read on each of the last [days] days, and not yet today.
  Future<void> readerWithStreak(int days) async {
    final today = journeyDayKey(DateTime.now());
    for (var ago = 1; ago <= days; ago++) {
      await store.record(
        'reader',
        JourneyEvent(dayKey: dayKeyPlus(today, -ago), messageId: 'm$ago'),
      );
    }
    JourneyRepository().setUser('reader');
    await settle();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await HadithRepository().load();
    await plugin.cancelAll();

    store = InMemoryJourneyStore();
    await JourneyRepository().debugReset(store: store);

    state
      ..toggleMorningReminder(true)
      ..toggleEveningReminder(true)
      ..setMorningReminderTime(const TimeOfDay(hour: 23, minute: 57))
      ..setEveningReminderTime(const TimeOfDay(hour: 23, minute: 58));

    scheduler = NotificationScheduler.test(plugin: plugin, dataSource: _Pool())
      ..planner = JourneyReminders.plan;
    refresher = NotificationLifecycleRefresher(
      scheduler: scheduler,
      state: state,
      planSettle: const Duration(milliseconds: 50),
    );
  });

  tearDown(() async {
    refresher.dispose();
    await plugin.cancelAll();
    await JourneyRepository().debugReset();
  });

  testWidgets('a reader on a streak gets their own words, queued for real',
      (tester) async {
    await readerWithStreak(3);
    refresher.start();
    await settle();

    final queued = await pending();
    expect(queued, hasLength(28));
    expect(queued[morningId]?.title, 'حديث اليوم');
    expect(queued[morningId]?.payload, hadithPayload(1));
    expect(queued[tonightId]?.title, 'لم نقرأ اليوم بعد');
    expect(queued[tonightId]?.body, '٣ أيام متتالية. حديث قصير قبل النوم؟');
  });

  testWidgets('reading today takes back tonight\'s streak line at once',
      (tester) async {
    await readerWithStreak(3);
    refresher.start();
    await settle();

    JourneyRepository().recordMessageRead('today', hadithNumber: 5);
    await settle();

    final queued = await pending();
    expect(queued[tonightId]?.title, 'تأمل المساء');
    expect(queued[tonightId]?.body, isNot(contains('متتالية')));
    expect(queued[tomorrowEveningId]?.body, startsWith('٤ أيام متتالية'));
  });

  testWidgets('finishing a hadith moves the morning on to the next one',
      (tester) async {
    await readerWithStreak(1);
    refresher.start();
    await settle();
    expect((await pending())[morningId]?.payload, hadithPayload(1));

    JourneyRepository().recordFullRead(1, seconds: 90);
    await settle();

    final tomorrowMorning = (await pending())[2];
    expect(tomorrowMorning?.title, 'حديث اليوم');
    expect(tomorrowMorning?.payload, hadithPayload(2));
  });

  testWidgets('signing out leaves nothing that names the reader\'s reading',
      (tester) async {
    await readerWithStreak(3);
    refresher.start();
    await settle();
    expect(
      (await pending()).values.any((r) => r.title == 'لم نقرأ اليوم بعد'),
      isTrue,
    );

    JourneyRepository().setUser(null);
    await settle();

    final queued = await pending();
    expect(queued, hasLength(28));
    expect(
      queued.values.every(
        (r) => r.title == 'رسالة الصباح' || r.title == 'تأمل المساء',
      ),
      isTrue,
    );
    expect(queued.values.any((r) => hadithOfPayload(r.payload) != null), isFalse);
  });

  testWidgets('a guest\'s reading stays out of the reminders', (tester) async {
    JourneyRepository().recordMessageRead('m', hadithNumber: 1);
    await settle();
    refresher.start();
    await settle();

    final queued = await pending();
    expect(queued.values.any((r) => hadithOfPayload(r.payload) != null), isFalse);
  });

}
