import 'package:integration_test/integration_test.dart';

import '../test/suites/board_suite.dart';

/// Device entry point — see the doc on [boardSuite].
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  boardSuite();
}
