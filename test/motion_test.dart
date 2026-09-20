import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hadith_app/core/theme/app_theme.dart';
import 'package:hadith_app/core/utils/app_motion.dart';
import 'package:hadith_app/core/widgets/bottom_navigation.dart';
import 'package:hadith_app/data/repositories/hadith_repository.dart';
import 'package:hadith_app/features/splash/splash_screen.dart';

/// Motion: the nav bar should not jolt, and a reader who asked their phone to
/// stop animating should be listened to.

Widget _wrap(Widget child, {bool reduceMotion = false}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: MaterialApp(
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
    ),
  );
}

/// Vertical centre of a nav label, which is what moved when the active dot
/// was inserted into and removed from the column.
double _labelCentre(WidgetTester tester, String label) =>
    tester.getCenter(find.text(label)).dy;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    SharedPreferences.setMockInitialValues({});
    await HadithRepository().load();
  });

  group('the nav bar does not jolt on selection', () {
    testWidgets('a label sits at the same height selected or not',
        (tester) async {
      // The active dot and its spacer used to be *added to* the column only
      // when selected — 6.5dp of extra height in a centre-aligned box — so
      // every tab change shifted the icon and label of both the old and the
      // new selection. Reserving the slot is what makes it animate instead.
      await tester.pumpWidget(
        _wrap(
          Scaffold(
            bottomNavigationBar: BottomNavigation(
              currentIndex: 0,
              onTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final selectedHome = _labelCentre(tester, 'الرئيسية');
      final unselectedSaved = _labelCentre(tester, 'المفضلة');

      await tester.pumpWidget(
        _wrap(
          Scaffold(
            bottomNavigationBar: BottomNavigation(
              currentIndex: 1,
              onTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final unselectedHome = _labelCentre(tester, 'الرئيسية');
      final selectedSaved = _labelCentre(tester, 'المفضلة');

      expect(
        selectedHome,
        moreOrLessEquals(unselectedHome, epsilon: 0.01),
        reason: 'Home label must not move when it loses selection',
      );
      expect(
        unselectedSaved,
        moreOrLessEquals(selectedSaved, epsilon: 0.01),
        reason: 'Saved label must not move when it gains selection',
      );
    });
  });

  group('reduce motion', () {
    testWidgets('collapses durations to zero', (tester) async {
      late BuildContext reduced;
      late BuildContext normal;

      await tester.pumpWidget(
        _wrap(Builder(builder: (c) {
          reduced = c;
          return const SizedBox();
        }), reduceMotion: true),
      );
      expect(reduced.reduceMotion, isTrue);
      expect(reduced.motion(AppDurations.control), Duration.zero);

      await tester.pumpWidget(
        _wrap(Builder(builder: (c) {
          normal = c;
          return const SizedBox();
        })),
      );
      expect(normal.reduceMotion, isFalse);
      expect(normal.motion(AppDurations.control), AppDurations.control);
    });

    testWidgets('holds the splash emblem still', (tester) async {
      // The splash ran a 1.4s heartbeat and a 12s halo rotation on repeat,
      // regardless of the reader's preference. Two assertions rather than
      // one, because "no frames scheduled" is only meaningful if the same
      // check can see frames when motion is allowed.
      await tester.pumpWidget(_wrap(const SplashScreen(), reduceMotion: true));
      // Long enough for the quote's one-shot 600ms fade to finish; after
      // that nothing on this screen should still be asking for frames.
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        tester.binding.hasScheduledFrame,
        isFalse,
        reason: 'nothing should be looping under reduce-motion',
      );

      // Let the splash's own timers expire so none are left pending.
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('the same check sees motion when it is allowed',
        (tester) async {
      await tester.pumpWidget(_wrap(const SplashScreen()));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        tester.binding.hasScheduledFrame,
        isTrue,
        reason: 'the emblem loops normally, so the assertion above is real',
      );

      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
