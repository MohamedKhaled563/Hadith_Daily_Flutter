import 'package:flutter_test/flutter_test.dart';

import '../../suites/notification_lifecycle_suite.dart';

/// Host entry point — see the doc on [notificationLifecycleSuite].
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  notificationLifecycleSuite();
}
