import 'package:flutter_test/flutter_test.dart';

import '../suites/daily_message_reveal_suite.dart';

/// Host entry point — see the doc on [dailyMessageRevealSuite].
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  dailyMessageRevealSuite();
}
