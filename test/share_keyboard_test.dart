import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hadith_app/core/theme/app_theme.dart';
import 'package:hadith_app/data/repositories/hadith_repository.dart';
import 'package:hadith_app/core/widgets/bottom_navigation.dart';
import 'package:hadith_app/features/share/add_message_screen.dart';

/// Where the share tab's submit button lands as the keyboard comes and goes.
///
/// It sat under the floating nav bar whenever a field held focus without the
/// keyboard actually insetting anything — a floating or split keyboard, or one
/// the reader dismissed with the back gesture while the field stayed focused.
/// These pin the two regimes the host Scaffold actually lays out, so the
/// screen can't go back to inferring the keyboard from focus.

const _size = Size(390, 844);

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

/// The submit button pinned below the share form.
final _submitButton = find.descendant(
  of: find.byType(AddMessageScreen),
  matching: find.byType(ElevatedButton),
);

/// The share tab inside a stand-in for its real host: HomeScreen's Scaffold,
/// with the same `extendBody` + floating nav bar that decide where the button
/// can sit. Driving HomeScreen itself would only add an IndexedStack that
/// keeps the other three tabs' buttons in the tree.
Future<void> _pumpShareTab(WidgetTester tester) async {
  tester.view.physicalSize = _size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _wrap(
      Scaffold(
        extendBody: true,
        body: SafeArea(
          bottom: false,
          child: BottomNavigation.scope(child: const AddMessageScreen()),
        ),
        bottomNavigationBar: BottomNavigation(currentIndex: 3, onTap: (_) {}),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 400));
}

/// Puts a field in focus, which is what the screen used to mistake for the
/// keyboard being up. Focus alone must not move the button.
Future<void> _focusMessageField(WidgetTester tester) async {
  await tester.tap(find.byType(TextField).last);
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _setKeyboard(WidgetTester tester, double logicalHeight) async {
  tester.view.viewInsets = FakeViewPadding(bottom: logicalHeight);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    SharedPreferences.setMockInitialValues({});
    await HadithRepository().load();
  });

  testWidgets('submit button clears the nav bar with no keyboard', (
    tester,
  ) async {
    await _pumpShareTab(tester);

    // The nav bar floats over the body (extendBody), so the button has to stop
    // short of the window's bottom edge rather than run under the bar.
    final bottom = tester.getRect(_submitButton).bottom;
    expect(bottom, lessThan(_size.height - 60));
  });

  testWidgets('submit button rides above a keyboard taller than the bar', (
    tester,
  ) async {
    await _pumpShareTab(tester);
    await _setKeyboard(tester, 400);

    // Once the keyboard is taller than the nav bar the Scaffold stops the body
    // at the keyboard's top edge and hides the bar behind it, so the button
    // sits just above the keyboard — no reserved band of background art.
    final bottom = tester.getRect(_submitButton).bottom;
    expect(bottom, lessThanOrEqualTo(_size.height - 400));
    expect(bottom, greaterThan(_size.height - 400 - 40));
  });

  testWidgets('submit button returns to its resting spot after the keyboard '
      'closes', (tester) async {
    await _pumpShareTab(tester);
    final resting = tester.getRect(_submitButton);

    await _focusMessageField(tester);
    await _setKeyboard(tester, 400);
    expect(tester.getRect(_submitButton), isNot(resting));

    // The reported bug: dismissing the keyboard leaves the field focused, and
    // the old focus-based guess kept the button pinned to the bottom, under
    // the nav bar. It has to come all the way back.
    await _setKeyboard(tester, 0);
    expect(tester.getRect(_submitButton), resting);
  });

  testWidgets('a keyboard shorter than the nav bar still leaves it clear', (
    tester,
  ) async {
    await _pumpShareTab(tester);
    final resting = tester.getRect(_submitButton);

    // A floating/split keyboard insets nothing while the field it is typing
    // into is focused, and anything shorter than the bar leaves the bar as the
    // taller obstruction — the button must not drop either way.
    await _focusMessageField(tester);
    expect(tester.getRect(_submitButton), resting);
    await _setKeyboard(tester, 20);
    expect(tester.getRect(_submitButton), resting);
  });
}
