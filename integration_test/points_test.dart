import 'package:integration_test/integration_test.dart';

import '../test/suites/points_suite.dart';

/// Device entry point — see the doc on [pointsSuite].
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  pointsSuite();
}
