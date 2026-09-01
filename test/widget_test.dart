import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  testWidgets('a signed-out reader lands on the login screen', (tester) async {
    await tester.pumpWidget(const HadithApp());
    await tester.pump(_pastSplash);
    await tester.pump(_pastSplash);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
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
