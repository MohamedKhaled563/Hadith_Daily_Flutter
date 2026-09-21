import 'package:integration_test/integration_test.dart';

import '../test/suites/notification_scheduler_suite.dart';

/// On-device entry point for the notification suite:
///
///   `flutter test integration_test/notification_scheduler_test.dart -d <id>`
///
/// Same body as the host run, executed inside a real app process against the
/// real SharedPreferences store and the real bundled timezone database. This
/// is the only path available on the current development machine (its
/// Application Control policy blocks flutter_tester.exe), and it is the more
/// faithful one for a feature built almost entirely on platform channels.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  notificationSchedulerSuite();
}
