import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hadith_app/core/auth/sign_in_gate.dart';
import 'package:hadith_app/core/theme/app_state_controller.dart';
import 'package:hadith_app/core/theme/app_theme.dart';
import 'package:hadith_app/core/utils/notification_reliability_tip.dart';
import 'package:hadith_app/data/repositories/hadith_repository.dart';
import 'package:hadith_app/features/hadith/hadith_list_screen.dart';

/// Guest browsing: the app opens, and the three things that genuinely need an
/// identity are the only things that ask for one.

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    SharedPreferences.setMockInitialValues({});
    await HadithRepository().load();
  });

  group('reading needs no account', () {
    testWidgets('a guest can browse the hadith list and bookmark',
        (tester) async {
      expect(AppStateController().isLoggedIn, isFalse,
          reason: 'this suite runs as a guest');

      await tester.pumpWidget(_wrap(const HadithListScreen()));
      await tester.pump(const Duration(milliseconds: 400));

      // The list itself renders, with real bundled content.
      expect(find.text('الأربعين النووية'), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);

      // Bookmarks live in SharedPreferences, not Firestore, which is why a
      // guest can have them at all — toggling one must not throw.
      final repo = HadithRepository();
      final first = repo.getAll().first.number;
      final before = repo.isHadithFavorite(first);
      repo.toggleFavoriteHadith(first);
      expect(repo.isHadithFavorite(first), !before);
      repo.toggleFavoriteHadith(first);
      expect(repo.isHadithFavorite(first), before);
    });
  });

  group('the sign-in gate', () {
    testWidgets('prompts a guest, and does not run the action on dismiss',
        (tester) async {
      bool? outcome;

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  outcome = await requireSignIn(
                    context,
                    reason: 'سجّل الدخول ليبقى إعجابك محفوظاً',
                  );
                },
                child: const Text('like'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('like'));
      await tester.pumpAndSettle();

      // The sheet explains itself rather than just blocking.
      expect(find.text('يحتاج هذا إلى حساب'), findsOneWidget);
      expect(find.text('سجّل الدخول ليبقى إعجابك محفوظاً'), findsOneWidget);
      expect(find.text('تسجيل الدخول'), findsOneWidget);
      expect(find.text('إنشاء حساب جديد'), findsOneWidget);

      // Declining is a normal outcome, not an error.
      await tester.tap(find.text('ليس الآن'));
      await tester.pumpAndSettle();

      expect(outcome, isFalse);
      expect(find.text('يحتاج هذا إلى حساب'), findsNothing);
    });
  });

  group('the reliability tip stays off the first run', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('does not earn an auto-show until the third launch', () async {
      // It used to fire on the first frame of the first HomeScreen, covering
      // the hero with a battery-settings sheet before a new reader had seen
      // anything at all.
      expect(await NotificationReliabilityTip.recordLaunchAndCheck(), isFalse);
      expect(await NotificationReliabilityTip.recordLaunchAndCheck(), isFalse);
      expect(await NotificationReliabilityTip.recordLaunchAndCheck(), isTrue);
    });

    test('stops counting once it has been shown', () async {
      SharedPreferences.setMockInitialValues({
        'flutter.notificationReliabilityTip.shown': true,
      });
      for (var i = 0; i < 5; i++) {
        expect(
          await NotificationReliabilityTip.recordLaunchAndCheck(),
          isFalse,
          reason: 'already shown — never again, however many launches',
        );
      }
    });
  });
}
