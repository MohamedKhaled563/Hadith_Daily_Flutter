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
import 'package:hadith_app/data/services/favorites_store.dart';
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
    testWidgets('a guest can browse the hadith list, but not bookmark',
        (tester) async {
      expect(AppStateController().isLoggedIn, isFalse,
          reason: 'this suite runs as a guest');

      await tester.pumpWidget(_wrap(const HadithListScreen()));
      await tester.pump(const Duration(milliseconds: 400));

      // The list itself renders, with real bundled content.
      expect(find.text('الأربعين النووية'), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);

      // Favourites belong to an account, so a guest starts with none — no
      // seeded "starter" favourites — and the repository refuses to add one
      // (the UI puts requireSignIn in front of every bookmark control).
      final repo = HadithRepository();
      repo.debugOverrideFavorites(
        store: InMemoryFavoritesStore(),
        currentUid: () => null,
      );
      expect(repo.getFavoriteHadiths(), isEmpty);
      expect(repo.getFavoriteInsights(), isEmpty);
      expect(
        () => repo.toggleFavoriteHadith(repo.getAll().first.number),
        throwsStateError,
      );
      expect(repo.getFavoriteHadiths(), isEmpty);
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
