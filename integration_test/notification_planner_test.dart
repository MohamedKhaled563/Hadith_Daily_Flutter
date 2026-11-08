import 'package:integration_test/integration_test.dart';

import '../test/suites/notification_planner_suite.dart';

/// Device entry point — see the doc on [notificationPlannerSuite].
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  notificationPlannerSuite();
}
