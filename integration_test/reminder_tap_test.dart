import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/data/services/notification_data_source.dart';
import 'package:hadith_app/data/services/notification_planner.dart';
import 'package:hadith_app/data/services/notification_scheduler.dart';
import 'package:integration_test/integration_test.dart';

class _NoPool implements NotificationDataSource {
  @override
  Future<List<Map<String, dynamic>>> loadActiveMessages() async => const [];

  @override
  Future<int?> loadPoolVersion() async => 0;

  @override
  Future<Map<String, dynamic>> loadSchedule() async => const {};
}

/// The one step mocks cannot cover: a real notification in the real shade,
/// tapped, reaching the app with its payload. Something outside the app has
/// to do the tapping, so this waits for it:
///
///     flutter test integration_test/reminder_tap_test.dart -d <device>
///     adb shell pm grant com.prodktstudio.tayebqalbak android.permission.POST_NOTIFICATIONS
///     adb shell cmd statusbar expand-notifications
///     (then tap «حديث اليوم»)
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a tapped notification reaches the app with its hadith',
      (tester) async {
    final plugin = FlutterLocalNotificationsPlugin();
    final scheduler =
        NotificationScheduler.test(plugin: plugin, dataSource: _NoPool());
    await scheduler.pendingCount();

    // Granted from outside too: a system dialog would wait here forever.
    final waiting = Stopwatch()..start();
    while (!await scheduler.hasPermission()) {
      expect(waiting.elapsed, lessThan(const Duration(seconds: 60)));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    final tapped = NotificationScheduler.hadithTapped.value;
    await plugin.show(
      77,
      'حديث اليوم',
      '«لا تغضب»، دقيقتان تقريباً.',
      NotificationScheduler.progressDetails,
      payload: hadithPayload(16),
    );

    final channels = await plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.getNotificationChannels() ??
        const [];
    expect(channels.map((c) => c.id), contains('reading_journey'));

    final clock = Stopwatch()..start();
    while (identical(NotificationScheduler.hadithTapped.value, tapped)) {
      expect(
        clock.elapsed,
        lessThan(const Duration(seconds: 90)),
        reason: 'nothing tapped the notification',
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }

    expect(NotificationScheduler.hadithTapped.value?.number, 16);
    await plugin.cancelAll();
  });
}
