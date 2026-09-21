import 'package:integration_test/integration_test.dart';

import '../test/suites/notification_lifecycle_suite.dart';

/// On-device entry point — see integration_test/notification_scheduler_test.dart
/// for why the suites are shared between a host and a device runner.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  notificationLifecycleSuite();
}
