import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'suites/regression_suite.dart';

/// Host entry point — see the doc on [regressionSuite].
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  regressionSuite(
    onDevice: false,
    initFirebase: () async {
      setupFirebaseCoreMocks();
      await Firebase.initializeApp();
    },
  );
}
