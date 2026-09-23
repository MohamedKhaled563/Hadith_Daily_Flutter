import 'package:integration_test/integration_test.dart';

import '../test/suites/daily_message_reveal_suite.dart';

/// On-device entry point — see integration_test/README.md for why the suites
/// are shared between a host and a device runner.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  dailyMessageRevealSuite();
}
