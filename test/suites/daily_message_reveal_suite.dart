import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/core/theme/app_theme.dart';
import 'package:hadith_app/data/models/insight.dart';
import 'package:hadith_app/features/messages/daily_message_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Covers the message screen's reveal model: one message at a time, an
/// explicit ask for the next, and a closing state once the day is spent.
///
/// The screen used to be a horizontal pager, so opening the day handed over
/// the whole set at once and "finished" was indistinguishable from "stopped
/// swiping". These tests pin the behaviour that replaced it.
///
/// Every insight here is built with an empty id, which makes
/// [Insight.isLikeable] false and keeps the toolbar off Firestore — the
/// screen can then be pumped without a backend.
Insight _insight(String text) => Insight(
      hadithNumber: 1,
      arabic: text,
      english: '',
      category: 'تأمّل',
      id: '',
      sourceCollection: '',
    );

List<DailyMessageEntry> _entries(int count) => [
      for (var i = 1; i <= count; i++)
        DailyMessageEntry(insight: _insight('رسالة رقم $i')),
    ];

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    );

void dailyMessageRevealSuite() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('remainingMessagesLabel', () {
    test('uses the dual form for two, which Arabic counts separately', () {
      expect(remainingMessagesLabel(2), contains('رسالتان'));
    });

    test('uses the singular for one', () {
      expect(remainingMessagesLabel(1), contains('رسالة واحدة'));
    });

    test('uses the plural noun and an Arabic numeral from three up', () {
      final label = remainingMessagesLabel(4);
      expect(label, contains('رسائل'));
      expect(label, contains('٤'));
    });

    test('never promises anything once nothing is left', () {
      expect(remainingMessagesLabel(0), isNot(contains('بقيت')));
    });
  });

  group('DailyMessageScreen.forDay', () {
    testWidgets('opens on one message, not the whole set', (tester) async {
      await tester.pumpWidget(_host(
        DailyMessageScreen.forDay(entries: _entries(3)),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('رسالة رقم ١'), findsNothing);
      // The card renders the message wrapped in guillemets.
      expect(find.textContaining('رسالة رقم 1'), findsOneWidget);
      expect(find.textContaining('رسالة رقم 2'), findsNothing);
      expect(find.textContaining('رسالة رقم 3'), findsNothing);
    });

    testWidgets('offers the next message rather than a swipe', (tester) async {
      await tester.pumpWidget(_host(
        DailyMessageScreen.forDay(entries: _entries(3)),
      ));
      await tester.pumpAndSettle();

      expect(find.text('رسالة أخرى'), findsOneWidget);
      expect(find.text('١ / ٣'), findsOneWidget);
      expect(find.text(remainingMessagesLabel(2)), findsOneWidget);
    });

    testWidgets('reveals the next message on request', (tester) async {
      await tester.pumpWidget(_host(
        DailyMessageScreen.forDay(entries: _entries(3)),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('رسالة أخرى'));
      await tester.pumpAndSettle();

      expect(find.textContaining('رسالة رقم 2'), findsOneWidget);
      expect(find.textContaining('رسالة رقم 1'), findsNothing);
      expect(find.text('٢ / ٣'), findsOneWidget);
    });

    testWidgets(
        'closes the day off once the last message is taken, instead of '
        'simply running out of things to swipe to', (tester) async {
      await tester.pumpWidget(_host(
        DailyMessageScreen.forDay(entries: _entries(2)),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('رسالة أخرى'));
      await tester.pumpAndSettle();

      expect(find.text('رسالة أخرى'), findsNothing);
      expect(find.text('انتهت رسائل اليوم'), findsOneWidget);
      expect(find.textContaining('عُد غداً'), findsOneWidget);
    });

    testWidgets('resumes where the reader left off today', (tester) async {
      await tester.pumpWidget(_host(
        DailyMessageScreen.forDay(entries: _entries(4), initialRevealed: 3),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('رسالة رقم 3'), findsOneWidget);
      expect(find.text('٣ / ٤'), findsOneWidget);
    });

    testWidgets(
        'a resumed position past the end still lands on a real message',
        (tester) async {
      // messagesPerDay lowered in the dashboard after the reader had already
      // gone further than the new limit.
      await tester.pumpWidget(_host(
        DailyMessageScreen.forDay(entries: _entries(2), initialRevealed: 9),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('رسالة رقم 2'), findsOneWidget);
      expect(find.text('انتهت رسائل اليوم'), findsOneWidget);
    });

    testWidgets('a one-message day shows no day controls at all',
        (tester) async {
      await tester.pumpWidget(_host(
        DailyMessageScreen.forDay(entries: _entries(1)),
      ));
      await tester.pumpAndSettle();

      expect(find.text('رسالة أخرى'), findsNothing);
      expect(find.text('انتهت رسائل اليوم'), findsNothing);
      expect(find.text('رسالة اليوم'), findsOneWidget);
    });

    // Deliberately rebuilds the same widget type in place rather than using
    // distinct keys, so it also covers didUpdateWidget: Flutter reuses the
    // State across these pumps, and an earlier version kept the first pump's
    // position for all three.
    testWidgets('offers writing one only when tabs can actually be switched',
        (tester) async {
      await tester.pumpWidget(_host(
        DailyMessageScreen.forDay(entries: _entries(1), initialRevealed: 1),
      ));
      await tester.pumpAndSettle();
      // Single message: no footer, so nothing to offer.
      expect(find.text('شارك رسالة من عندك'), findsNothing);

      // A deep link pushes this route with no tab handler, so the share CTA
      // must stay hidden rather than becoming a button that does nothing.
      await tester.pumpWidget(_host(
        DailyMessageScreen.forDay(entries: _entries(2), initialRevealed: 2),
      ));
      await tester.pumpAndSettle();
      expect(find.text('انتهت رسائل اليوم'), findsOneWidget);
      expect(find.text('شارك رسالة من عندك'), findsNothing);

      var tapped = -1;
      await tester.pumpWidget(_host(
        DailyMessageScreen.forDay(
          entries: _entries(2),
          initialRevealed: 2,
          onTabSelected: (i) => tapped = i,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('شارك رسالة من عندك'), findsOneWidget);

      await tester.tap(find.text('شارك رسالة من عندك'));
      await tester.pumpAndSettle();
      expect(tapped, 3, reason: 'the share tab in the home shell');
    });
  });

  group('DailyMessageScreen (single message, e.g. from favourites)', () {
    testWidgets('carries none of the day framing', (tester) async {
      await tester.pumpWidget(_host(
        DailyMessageScreen(insight: _insight('رسالة محفوظة')),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('رسالة محفوظة'), findsOneWidget);
      expect(find.text('رسالة اليوم'), findsOneWidget);
      expect(find.text('رسالة أخرى'), findsNothing);
      expect(find.text('انتهت رسائل اليوم'), findsNothing);
    });
  });
}
