import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hadith_app/core/theme/app_theme.dart';
import 'package:hadith_app/data/models/insight.dart';
import 'package:hadith_app/data/services/moderation_service.dart';
import 'package:hadith_app/features/community/report_sheet.dart';

/// The reader-facing half of guideline 1.2. Filing a report is a Firestore
/// write and cannot run here, but everything up to that point can: the reasons
/// on offer, the refusal to submit a blank one, and blocking — which is local,
/// and is the remedy a reader reaches for when they do not want to explain
/// themselves at all.

// Not const: CommunityPost stamps createdAt with DateTime.now().
CommunityPost get _post => CommunityPost(
      id: 'post-1',
      authorName: 'أميرة',
      message: 'الصبر ضياء.',
      hadithNumber: 3,
    );

Widget _host(ThemeMode mode) => MaterialApp(
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
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showReportSheet(context, _post),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

/// The default 800x600 test surface is a landscape tablet; the sheet is a
/// portrait-phone control, and on that surface its lower half — the block
/// button and the cancel row — sits off the bottom of the render tree.
Future<void> _phoneSized(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _openSheet(WidgetTester tester,
    {ThemeMode mode = ThemeMode.light}) async {
  await _phoneSized(tester);
  await tester.pumpWidget(_host(mode));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  late ModerationService moderation;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    moderation = ModerationService();
    await moderation.load();
  });


  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('every reason is offered, and both remedies — $mode',
        (tester) async {
      await _openSheet(tester, mode: mode);

      for (final reason in ReportReason.values) {
        expect(find.text(reason.label), findsOneWidget,
            reason: 'reason "${reason.key}" is missing');
      }
      expect(find.text('إرسال البلاغ'), findsOneWidget);
      expect(find.text('إخفاء مشاركات هذا الكاتب'), findsOneWidget);
    });
  }

  testWidgets('submitting without a reason asks for one instead of filing it',
      (tester) async {
    await _openSheet(tester);

    await tester.tap(find.text('إرسال البلاغ'));
    await tester.pumpAndSettle();

    expect(find.text('اختر سبب الإبلاغ'), findsOneWidget);
    // Still open: a report with no reason is nothing a moderator can act on,
    // so the sheet must not close as though something happened.
    expect(find.text('الإبلاغ عن المشاركة'), findsOneWidget);
  });

  testWidgets('blocking hides the author and says so to the caller',
      (tester) async {
    late ModerationOutcome outcome;
    await _phoneSized(tester);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async =>
                    outcome = await showReportSheet(context, _post),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('إخفاء مشاركات هذا الكاتب'));
    await tester.pumpAndSettle();

    expect(outcome, ModerationOutcome.blocked);
    expect(moderation.isBlocked('أميرة'), isTrue,
        reason: 'the feed filters on exactly this');
  });

  testWidgets('dismissing the sheet does nothing at all', (tester) async {
    await _openSheet(tester);

    // The sheet is taller than a short phone, so its last row is reached by
    // scrolling — the same thing a reader does, and the reason this is not a
    // bare tap().
    await tester.ensureVisible(find.text('إلغاء'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();

    expect(find.text('الإبلاغ عن المشاركة'), findsNothing,
        reason: 'the sheet has to actually close, or this test proves nothing');
    expect(moderation.blockedAuthors, isEmpty);
  });

  testWidgets('a blocked author can be unblocked again', (tester) async {
    await moderation.setBlocked('أميرة', true);
    await _phoneSized(tester);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showBlockedAuthorsSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('أميرة'), findsOneWidget);
    await tester.tap(find.text('إظهار'));
    await tester.pumpAndSettle();

    expect(moderation.isBlocked('أميرة'), isFalse);
    expect(find.text('لم تُخفِ أحداً بعد.'), findsOneWidget);
  });
}
