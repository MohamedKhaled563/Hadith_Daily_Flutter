import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hadith_app/core/theme/app_state_controller.dart';
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

  setUp(() {
    AppStateController().logout();
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

  testWidgets('a signed-in reader goes straight to home', (tester) async {
    AppStateController().signIn(username: 'admin', password: 'admin');

    await tester.pumpWidget(const HadithApp());
    await tester.pump(_pastSplash);
    await tester.pump(_pastSplash);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  group('placeholder sign-in', () {
    test('accepts the demo credentials and names the reader', () {
      final state = AppStateController()..logout();

      expect(state.signIn(username: 'admin', password: 'admin'), isTrue);
      expect(state.isLoggedIn, isTrue);
      expect(state.userName, 'محمد');
    });

    test('tolerates surrounding whitespace in the username', () {
      final state = AppStateController()..logout();

      expect(state.signIn(username: '  admin ', password: 'admin'), isTrue);
    });

    test('rejects anything else and stays signed out', () {
      final state = AppStateController()..logout();

      for (final (username, password) in const [
        ('admin', 'wrong'),
        ('wrong', 'admin'),
        ('', ''),
        ('Admin', 'admin'), // username is case-sensitive
        ('admin', 'Admin'), // password is case-sensitive
      ]) {
        expect(
          state.signIn(username: username, password: password),
          isFalse,
          reason: 'should reject "$username" / "$password"',
        );
        expect(state.isLoggedIn, isFalse);
      }
    });
  });

  testWidgets('wrong credentials show an error and do not navigate',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ar'),
        home: LoginScreen(),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'admin');
    await tester.enterText(find.byType(TextField).last, 'nope');
    await tester.pump();

    await tester.tap(find.text('دخول'));
    await tester.pump(); // submitting
    await tester.pump(const Duration(seconds: 1)); // past the fake round-trip

    expect(find.text('اسم المستخدم أو كلمة المرور غير صحيحة'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(AppStateController().isLoggedIn, isFalse);
  });
}
