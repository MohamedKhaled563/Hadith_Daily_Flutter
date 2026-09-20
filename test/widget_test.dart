import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hadith_app/data/repositories/hadith_repository.dart';
import 'package:hadith_app/features/auth/login_screen.dart';
import 'package:hadith_app/features/home/home_screen.dart';
import 'package:hadith_app/features/splash/splash_screen.dart';
import 'package:hadith_app/main.dart';

/// Long enough to clear the splash screen's 2.8s auto-advance timer and the
/// route transition that follows it.
const _pastSplash = Duration(seconds: 4);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // A signed-out reader now lands on Home, which keeps every tab mounted
    // (IndexedStack), so CommunityScreen reaches for FirebaseFirestore as
    // soon as it builds. Before guest browsing this file never got that far.
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    SharedPreferences.setMockInitialValues({});
    await HadithRepository().load();
  });

  testWidgets('boots to the splash screen', (tester) async {
    await tester.pumpWidget(const HadithApp());

    expect(find.byType(HadithApp), findsOneWidget);
    expect(find.byType(SplashScreen), findsOneWidget);

    // Let the splash timers run out so none are left pending.
    await tester.pump(_pastSplash);
    await tester.pump(_pastSplash);
  });

  testWidgets('a signed-out reader lands on Home, not a login form',
      (tester) async {
    // The app used to route straight to the login screen from the splash, so
    // a new install's first experience was a form before a single hadith.
    // Nothing a reader browses needs an identity — see requireSignIn for the
    // three places that do.
    await tester.pumpWidget(const HadithApp());
    await tester.pump(_pastSplash);
    await tester.pump(_pastSplash);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('empty credentials show a validation error and do not navigate',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ar'),
        home: LoginScreen(),
      ),
    );

    await tester.tap(find.text('دخول'));
    await tester.pump();

    expect(find.text('أدخل البريد الإلكتروني وكلمة المرور'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });
}
