import 'package:flutter_test/flutter_test.dart';

import '../../suites/notification_scheduler_suite.dart';

/// Host entry point for the notification suite (`flutter test`). The suite
/// body itself lives in test/suites/ so the identical tests can also run on
/// a real device — see integration_test/notification_scheduler_test.dart and
/// the doc comment on [notificationSchedulerSuite].
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  notificationSchedulerSuite();
}
