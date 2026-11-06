import 'package:firebase_core/firebase_core.dart';
import 'package:hadith_app/firebase_options.dart';
import 'package:integration_test/integration_test.dart';

import '../test/suites/regression_suite.dart';

/// On-device entry point. Firebase points at a demo project, so a run can
/// never read or write the live one.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  regressionSuite(
    onDevice: true,
    initFirebase: () async {
      final options = DefaultFirebaseOptions.currentPlatform;
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: options.apiKey,
          appId: options.appId,
          messagingSenderId: options.messagingSenderId,
          projectId: 'demo-regression',
        ),
      );
    },
  );
}
