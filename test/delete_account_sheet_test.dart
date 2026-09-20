import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hadith_app/core/theme/app_theme.dart';
import 'package:hadith_app/data/services/account_deletion_service.dart';
import 'package:hadith_app/features/profile/delete_account_sheet.dart';

/// The typed-confirmation gate is the only thing standing in front of the one
/// irreversible action in the app, and it is the one part of the delete flow
/// that can be exercised without actually deleting an account.

Widget _wrap(Widget child, {ThemeMode mode = ThemeMode.light}) {
  return MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: mode,
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

/// The destructive button, found by its label rather than its type so the test
/// fails loudly if the label changes without the test being reconsidered.
Finder get _deleteButton => find.widgetWithText(
      ElevatedButton,
      'حذف حسابي نهائياً',
    );

bool _enabled(WidgetTester tester) =>
    tester.widget<ElevatedButton>(_deleteButton).onPressed != null;

void main() {
  testWidgets('the destructive button is disabled until the word is typed',
      (tester) async {
    var confirmCalls = 0;

    await tester.pumpWidget(
      _wrap(
        DeleteAccountForm(
          method: ReauthMethod.password,
          onConfirm: (password, onProgress) async => confirmCalls++,
        ),
      ),
    );
    await tester.pump();

    expect(_deleteButton, findsOneWidget);
    expect(_enabled(tester), isFalse, reason: 'disabled on an empty field');

    // A near miss must not open the gate.
    await tester.enterText(find.byType(TextField).first, 'حذ');
    await tester.pump();
    expect(_enabled(tester), isFalse, reason: 'disabled on a partial word');

    // Nor should some other word.
    await tester.enterText(find.byType(TextField).first, 'نعم');
    await tester.pump();
    expect(_enabled(tester), isFalse, reason: 'disabled on the wrong word');

    await tester.enterText(find.byType(TextField).first, 'حذف');
    await tester.pump();
    expect(_enabled(tester), isTrue, reason: 'enabled on the exact word');

    // Surrounding whitespace is forgiven — the field is trimmed.
    await tester.enterText(find.byType(TextField).first, '  حذف  ');
    await tester.pump();
    expect(_enabled(tester), isTrue, reason: 'enabled on a trimmed match');

    expect(confirmCalls, 0, reason: 'nothing runs until the button is tapped');
  });

  testWidgets('a password account is asked for a password', (tester) async {
    await tester.pumpWidget(
      _wrap(
        DeleteAccountForm(
          method: ReauthMethod.password,
          onConfirm: (password, onProgress) async {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('كلمة المرور'), findsOneWidget);
    // The confirmation field and the password field.
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('a Google account is not asked for a password', (tester) async {
    await tester.pumpWidget(
      _wrap(
        DeleteAccountForm(
          method: ReauthMethod.google,
          onConfirm: (password, onProgress) async {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('كلمة المرور'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('Google'), findsOneWidget);
  });

  testWidgets('the sheet says what will be deleted', (tester) async {
    await tester.pumpWidget(
      _wrap(
        DeleteAccountForm(
          method: ReauthMethod.password,
          onConfirm: (password, onProgress) async {},
        ),
      ),
    );
    await tester.pump();

    // Hard deletion was chosen over anonymising, so the sheet has to be
    // explicit that community posts go too.
    expect(find.text('كل رسائلك المنشورة في المجتمع'), findsOneWidget);
    expect(find.text('كل إعجاباتك'), findsOneWidget);
    expect(find.text('حسابك وبريدك واسمك المعروض'), findsOneWidget);
  });

  testWidgets('renders in dark mode without exploding', (tester) async {
    await tester.pumpWidget(
      _wrap(
        DeleteAccountForm(
          method: ReauthMethod.password,
          onConfirm: (password, onProgress) async {},
        ),
        mode: ThemeMode.dark,
      ),
    );
    await tester.pump();

    expect(_deleteButton, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
