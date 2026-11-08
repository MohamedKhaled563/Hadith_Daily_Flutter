import 'package:integration_test/integration_test.dart';

import '../test/suites/memo_suite.dart';

/// Device entry point — see the doc on [memoSuite].
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  memoSuite();
}
