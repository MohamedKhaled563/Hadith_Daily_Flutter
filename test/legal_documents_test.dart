import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hadith_app/core/legal/legal_documents.dart';
import 'package:hadith_app/core/theme/app_theme.dart';
import 'package:hadith_app/features/legal/legal_document_screen.dart';

/// Sign-up blocks on agreeing to these two documents, so "they exist and they
/// render" is a release requirement, not a nicety.

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
    home: child,
  );
}

void main() {
  group('documents have content', () {
    test('privacy policy is substantial and covers deletion', () {
      expect(LegalDocuments.privacy.trim(), isNotEmpty);
      expect(LegalDocuments.privacy.length, greaterThan(800));
      // Play's Data Deletion policy is the reason this section exists; if it
      // is ever edited away, this fails rather than the store review.
      expect(LegalDocuments.privacy, contains('حذف بياناتك'));
      expect(LegalDocuments.privacy, contains('حذف الحساب'));
    });

    test('terms are substantial', () {
      expect(LegalDocuments.terms.trim(), isNotEmpty);
      expect(LegalDocuments.terms.length, greaterThan(800));
    });

    test('neither document still carries a placeholder', () {
      for (final doc in [LegalDocuments.privacy, LegalDocuments.terms]) {
        expect(doc, isNot(contains('TODO')));
        expect(doc, isNot(contains('lorem')));
        expect(doc, isNot(contains('XXX')));
      }
    });
  });

  group('renders', () {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      final name = mode == ThemeMode.light ? 'light' : 'dark';

      testWidgets('privacy policy · $name', (tester) async {
        await tester.pumpWidget(
          _wrap(
            const LegalDocumentScreen(
              title: LegalDocuments.privacyTitle,
              body: LegalDocuments.privacy,
            ),
            mode: mode,
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text(LegalDocuments.privacyTitle), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('terms · $name', (tester) async {
        await tester.pumpWidget(
          _wrap(
            const LegalDocumentScreen(
              title: LegalDocuments.termsTitle,
              body: LegalDocuments.terms,
            ),
            mode: mode,
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text(LegalDocuments.termsTitle), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('headings and bold runs survive the tiny parser',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const LegalDocumentScreen(
            title: 'اختبار',
            body: '## عنوان\n\n**مقدمة.** نص عادي.\n\n• أول\n• ثاني',
          ),
        ),
      );
      await tester.pump();

      // The `## ` marker is consumed, not printed.
      expect(find.text('عنوان'), findsOneWidget);
      expect(find.textContaining('##'), findsNothing);
      // Bullets lose their marker too, and each becomes its own row.
      expect(find.text('أول'), findsOneWidget);
      expect(find.text('ثاني'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
