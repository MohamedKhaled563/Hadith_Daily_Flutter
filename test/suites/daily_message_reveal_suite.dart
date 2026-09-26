import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/core/theme/app_theme.dart';
import 'package:hadith_app/data/models/insight.dart';
import 'package:hadith_app/data/repositories/hadith_repository.dart';
import 'package:hadith_app/data/services/daily_tip_service.dart';
import 'package:hadith_app/features/home/home_screen.dart';
import 'package:hadith_app/features/messages/daily_message_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Covers how the day's message is given out.
///
/// The shape here is the point, and it has changed twice. It was a
/// horizontal pager over the whole set, then a pushed screen with a reveal
/// button and a progress strand. It is now what a tip-of-the-day app does:
/// press the emblem once, the message takes its place **on the home tab**,
/// and it stays there for the rest of the day — across restarts — with no
/// counter anywhere and no second screen to navigate to.
///
/// These tests pin that, because every one of those properties was got wrong
/// at least once.

String _todayString() {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}

/// Seeds a day's set straight into the cache DailyTipService reads, so the
/// home screen has a known set of messages.
Map<String, Object> _seededDay(int count, {int? revealed}) {
  final date = _todayString();
  return {
    'dailyTip.messagesPerDay': count,
    'dailyTip.pickedOnDate': date,
    'dailyTip.todaySet': jsonEncode([
      for (var i = 1; i <= count; i++)
        {
          'id': 'seed-$i',
          'source': 'dailyMessages',
          'text': 'رسالة رقم $i',
          'hadithNumber': 1,
          'category': 'تأمّل',
        },
    ]),
    if (revealed != null) ...{
      'dailyTip.revealedOnDate': date,
      'dailyTip.revealedCount': revealed,
    },
  };
}

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

/// Pumps until [until] matches, or a generous budget runs out.
///
/// `pumpAndSettle` is unusable here: home runs ambient animations that never
/// stop. Waiting on a condition rather than a fixed number of frames,
/// because what is being waited for includes real async work.
Future<void> _settle(WidgetTester tester, {Finder? until}) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (until != null && until.evaluate().isNotEmpty) return;
  }
}

/// Seeds the day, then pumps home with it.
///
/// The `getTodayTips()` call before pumping is not redundant. Resolving the
/// day asks Firestore how many messages it carries, which on a networked
/// device is a real round trip of unpredictable length; doing it here means
/// the set is already settled and cached before home asks for it, instead of
/// each test racing that call. Skipping this made four of these tests fail
/// on a phone while passing everywhere else.
Future<void> _pumpHome(
  WidgetTester tester,
  int count,
  Map<String, Object> seed, {
  Finder? until,
}) async {
  // Pin the day's size so a live Firestore read cannot top the seeded day up
  // and turn a finished day back into an unfinished one.
  DailyTipService.debugMessagesPerDay = count;
  SharedPreferences.setMockInitialValues(seed);
  await DailyTipService().getTodayTips();
  await tester.pumpWidget(_host(const HomeScreen()));
  await _settle(tester, until: until);
}

void dailyMessageRevealSuite() {
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    await HadithRepository().load();
  });

  group('DailyTipService — how much of today has been opened', () {
    test('starts at zero: the emblem has not been pressed yet', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await DailyTipService().revealedCount(), 0);
    });

    test('ensureOpenedToday opens it, and is idempotent', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await DailyTipService().ensureOpenedToday(), 1);
      expect(await DailyTipService().revealedCount(), 1);

      // A second reminder tap must not advance past a message unread.
      expect(await DailyTipService().ensureOpenedToday(), 1);
      expect(await DailyTipService().revealedCount(), 1);
    });

    test('remembers how far the reader got, across a restart', () async {
      SharedPreferences.setMockInitialValues({});
      await DailyTipService().saveRevealedCount(3);
      expect(await DailyTipService().revealedCount(), 3);
    });

    test('never runs backwards within a day', () async {
      SharedPreferences.setMockInitialValues({});
      await DailyTipService().saveRevealedCount(3);
      await DailyTipService().saveRevealedCount(1);
      expect(await DailyTipService().revealedCount(), 3);
    });

    test('a new day starts closed again, whatever yesterday reached',
        () async {
      SharedPreferences.setMockInitialValues({
        'dailyTip.revealedOnDate': '2020-01-01',
        'dailyTip.revealedCount': 5,
      });
      expect(await DailyTipService().revealedCount(), 0,
          reason: 'the emblem is waiting to be pressed again');
    });
  });

  group('home — pressing the emblem', () {
    testWidgets('shows the emblem while today has not been opened',
        (tester) async {
      await _pumpHome(tester, 3, _seededDay(3),
          until: find.textContaining('هل سمعت'));

      expect(find.textContaining('هل سمعت'), findsOneWidget);
      expect(find.textContaining('رسالة رقم'), findsNothing);
    });

    testWidgets('puts the message in the emblem\'s place, without navigating',
        (tester) async {
      await _pumpHome(tester, 3, _seededDay(3),
          until: find.textContaining('هل سمعت'));

      await tester.tap(find.textContaining('طيّب قلبك').first);
      await _settle(tester, until: find.textContaining('رسالة رقم 1'));

      expect(find.textContaining('رسالة رقم 1'), findsOneWidget);
      // The hero question is gone: the message replaced it on the same tab.
      expect(find.textContaining('هل سمعت'), findsNothing);
      // And nothing was pushed — home is still the only route.
      expect(find.byType(DailyMessageScreen), findsNothing);
    });

    testWidgets('never shows a counter', (tester) async {
      await _pumpHome(tester, 4, _seededDay(4, revealed: 2),
          until: find.textContaining('رسالة رقم 2'));

      // The reader is being given a message, not shown a position in a queue.
      expect(find.text('١ / ٤'), findsNothing);
      expect(find.text('٢ / ٤'), findsNothing);
      expect(find.textContaining(' / '), findsNothing);
    });
  });

  group('home — the rest of the day', () {
    testWidgets('comes back to the message, not the emblem', (tester) async {
      // Opened earlier today and the app was closed since.
      await _pumpHome(tester, 3, _seededDay(3, revealed: 2),
          until: find.textContaining('رسالة رقم 2'));

      expect(find.textContaining('رسالة رقم 2'), findsOneWidget);
      expect(find.textContaining('هل سمعت'), findsNothing);
    });

    testWidgets('offers another message while the day has more',
        (tester) async {
      await _pumpHome(tester, 3, _seededDay(3, revealed: 1),
          until: find.text('رسالة أخرى'));

      expect(find.text('رسالة أخرى'), findsOneWidget);

      await tester.tap(find.text('رسالة أخرى'));
      // The card cross-fades, so the outgoing message is briefly still in the
      // tree alongside the incoming one. Wait for the swap to *finish* before
      // asserting the old one is gone, rather than the instant the new one
      // appears.
      await _settle(tester, until: find.textContaining('رسالة رقم 2'));
      await _settle(tester);

      expect(find.textContaining('رسالة رقم 2'), findsOneWidget);
      expect(find.textContaining('رسالة رقم 1'), findsNothing);
    });

    testWidgets(
        'closes the day with the last message rather than a panel of its own',
        (tester) async {
      await _pumpHome(tester, 2, _seededDay(2, revealed: 2),
          until: find.text('نلقاك غداً بإذن الله'));

      expect(find.text('رسالة أخرى'), findsNothing);
      expect(find.text('نلقاك غداً بإذن الله'), findsOneWidget);
      // Shown *with* the message, not instead of it.
      expect(find.textContaining('رسالة رقم 2'), findsOneWidget);
    });

    testWidgets('a one-message day closes as soon as it is opened',
        (tester) async {
      await _pumpHome(tester, 1, _seededDay(1),
          until: find.textContaining('هل سمعت'));

      await tester.tap(find.textContaining('طيّب قلبك').first);
      await _settle(tester, until: find.text('نلقاك غداً بإذن الله'));

      expect(find.textContaining('رسالة رقم 1'), findsOneWidget);
      expect(find.text('رسالة أخرى'), findsNothing);
      expect(find.text('نلقاك غداً بإذن الله'), findsOneWidget);
    });

    testWidgets('a stored position past the end still lands on a real message',
        (tester) async {
      // messagesPerDay lowered after the reader had already gone further.
      await _pumpHome(tester, 2, _seededDay(2, revealed: 9),
          until: find.text('نلقاك غداً بإذن الله'));

      expect(find.textContaining('رسالة رقم 2'), findsOneWidget);
      expect(find.text('نلقاك غداً بإذن الله'), findsOneWidget);
    });
  });

  group('DailyMessageScreen — a single saved message', () {
    testWidgets('carries none of the day framing', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(_host(
        const DailyMessageScreen(
          insight: Insight(
            hadithNumber: 1,
            arabic: 'رسالة محفوظة',
            english: '',
            category: 'تأمّل',
          ),
        ),
      ));
      await _settle(tester, until: find.textContaining('رسالة محفوظة'));

      expect(find.textContaining('رسالة محفوظة'), findsOneWidget);
      expect(find.text('رسالة أخرى'), findsNothing);
      expect(find.text('نلقاك غداً بإذن الله'), findsNothing);
    });
  });
}
