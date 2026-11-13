import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/core/theme/app_theme.dart';
import 'package:hadith_app/core/widgets/bottom_navigation.dart';
import 'package:hadith_app/data/models/insight.dart';
import 'package:hadith_app/data/repositories/hadith_repository.dart';
import 'package:hadith_app/data/services/daily_tip_service.dart';
import 'package:hadith_app/data/services/notification_scheduler.dart';
import 'package:hadith_app/features/home/home_screen.dart';
import 'package:hadith_app/features/messages/daily_message_screen.dart';
import 'package:hadith_app/features/messages/today_message_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Covers how the day's message is given out.
///
/// The shape here is the point, and it has changed several times. It was a
/// horizontal pager over the whole set, then a pushed screen with a reveal
/// button and a progress strand, then inline on the home tab in the emblem's
/// place. It is now a window: press the emblem, today's message opens over
/// home with no counter anywhere, and leaving it returns to **the emblem,
/// which home never loses**. Each press of the emblem brings the next of
/// today's messages until the day runs out, then keeps showing the last one.
/// A reminder tap lands on the message already reached, without spending a
/// new one.
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
  bool pressEmblem = false,
}) async {
  // Pin the day's size so a live Firestore read cannot top the seeded day up
  // and turn a finished day back into an unfinished one.
  DailyTipService.debugMessagesPerDay = count;
  SharedPreferences.setMockInitialValues(seed);
  await DailyTipService().getTodayTips();
  await tester.pumpWidget(_host(const HomeScreen()));
  if (pressEmblem) {
    await _settle(tester, until: find.textContaining('هل سمعت'));
    await tester.tap(find.textContaining('طيّب قلبك').first);
  }
  await _settle(tester, until: until);
}

/// Leaves the window by its back button and waits for the transition to end.
Future<void> _closeWindow(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.chevron_right_rounded));
  await _settle(tester, until: find.textContaining('هل سمعت'));
  await _settle(tester);
}

void dailyMessageRevealSuite() {
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    // load() now clears the pre-account favourites key from
    // SharedPreferences, so the plugin needs its mock before it runs.
    SharedPreferences.setMockInitialValues({});
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

    test('a new day starts closed again, whatever yesterday reached', () async {
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

    testWidgets('opens the message in its own window, leaving home as it was',
        (tester) async {
      await _pumpHome(tester, 3, _seededDay(3),
          until: find.textContaining('هل سمعت'));

      await tester.tap(find.textContaining('طيّب قلبك').first);
      await _settle(tester, until: find.textContaining('رسالة رقم 1'));
      await _settle(tester);

      expect(find.textContaining('رسالة رقم 1'), findsOneWidget);
      expect(find.byType(TodayMessageScreen), findsOneWidget);
      // Covered, not replaced: the emblem is still there underneath.
      expect(find.textContaining('هل سمعت'), findsNothing);
      expect(
          find.textContaining('هل سمعت', skipOffstage: false), findsOneWidget);
    });

    testWidgets('leaving the window returns to the emblem', (tester) async {
      await _pumpHome(tester, 3, _seededDay(3),
          pressEmblem: true, until: find.textContaining('رسالة رقم 1'));
      await _settle(tester);

      await _closeWindow(tester);

      expect(find.byType(TodayMessageScreen), findsNothing);
      expect(find.textContaining('هل سمعت'), findsOneWidget);
      expect(find.textContaining('طيّب قلبك'), findsWidgets);
    });

    testWidgets('the system back button leaves the window too', (tester) async {
      await _pumpHome(tester, 3, _seededDay(3),
          pressEmblem: true, until: find.textContaining('رسالة رقم 1'));
      await _settle(tester);

      await tester.binding.handlePopRoute();
      await _settle(tester, until: find.textContaining('هل سمعت'));
      await _settle(tester);

      expect(find.byType(TodayMessageScreen), findsNothing);
      expect(find.textContaining('هل سمعت'), findsOneWidget);
    });

    testWidgets('each press of the emblem brings a new message, to the limit',
        (tester) async {
      await _pumpHome(tester, 3, _seededDay(3),
          until: find.textContaining('هل سمعت'));

      Future<void> pressAndExpect(int number) async {
        await tester.tap(find.textContaining('طيّب قلبك').first);
        await _settle(tester, until: find.textContaining('رسالة رقم $number'));
        await _settle(tester);
        expect(find.byType(TodayMessageScreen), findsOneWidget);
        for (var other = 1; other <= 3; other++) {
          expect(find.textContaining('رسالة رقم $other'),
              other == number ? findsOneWidget : findsNothing);
        }
      }

      await pressAndExpect(1);
      expect(find.text('رسالة أخرى'), findsOneWidget);
      await _closeWindow(tester);

      await pressAndExpect(2);
      await _closeWindow(tester);

      await pressAndExpect(3);
      expect(find.text('نلقاك غداً بإذن الله'), findsOneWidget);
      await _closeWindow(tester);

      // The day is spent: the last message again, not a fourth or a first.
      await pressAndExpect(3);
      expect(find.text('رسالة أخرى'), findsNothing);
      expect(find.text('نلقاك غداً بإذن الله'), findsOneWidget);
      expect(await DailyTipService().revealedCount(), 3);
    });

    testWidgets('رسالة أخرى and the emblem share one place in the day',
        (tester) async {
      await _pumpHome(tester, 3, _seededDay(3),
          pressEmblem: true, until: find.text('رسالة أخرى'));
      await _settle(tester);

      await tester.tap(find.text('رسالة أخرى'));
      await _settle(tester, until: find.textContaining('رسالة رقم 2'));
      await _settle(tester);

      await _closeWindow(tester);
      await tester.tap(find.textContaining('طيّب قلبك').first);
      await _settle(tester, until: find.textContaining('رسالة رقم 3'));
      await _settle(tester);

      expect(find.textContaining('رسالة رقم 3'), findsOneWidget);
      expect(find.textContaining('رسالة رقم 2'), findsNothing);
      expect(await DailyTipService().revealedCount(), 3);
    });

    testWidgets('a double tap opens one window', (tester) async {
      await _pumpHome(tester, 3, _seededDay(3),
          until: find.textContaining('هل سمعت'));

      final emblem = find.textContaining('طيّب قلبك').first;
      await tester.tap(emblem);
      await tester.tap(emblem, warnIfMissed: false);
      await _settle(tester, until: find.textContaining('رسالة رقم 1'));
      await _settle(tester);

      expect(find.byType(TodayMessageScreen), findsOneWidget);
      await _closeWindow(tester);
      expect(
          find.byType(TodayMessageScreen, skipOffstage: false), findsNothing);
    });

    testWidgets('a hidden home tab takes no part in Hero flights',
        (tester) async {
      await _pumpHome(tester, 3, _seededDay(3),
          until: find.textContaining('هل سمعت'));

      HeroMode modeOverEmblem() => tester.widget<HeroMode>(
            find
                .ancestor(
                  of: find.byWidgetPredicate(
                    (w) => w is Hero && w.tag == 'heart_leaf_emblem_hero',
                    skipOffstage: false,
                  ),
                  matching: find.byType(HeroMode, skipOffstage: false),
                )
                .first,
          );

      expect(modeOverEmblem().enabled, isTrue);

      // Favourites: opening a saved message from here must not fly an emblem
      // in from the tab behind it.
      tester.widget<BottomNavigation>(find.byType(BottomNavigation)).onTap(1);
      await _settle(tester);

      expect(modeOverEmblem().enabled, isFalse);
    });

    testWidgets('never shows a counter', (tester) async {
      await _pumpHome(tester, 4, _seededDay(4, revealed: 2),
          pressEmblem: true, until: find.textContaining('رسالة رقم 3'));

      // The reader is being given a message, not shown a position in a queue.
      expect(find.textContaining('رسالة رقم 3'), findsOneWidget);
      expect(find.text('٢ / ٤'), findsNothing);
      expect(find.text('٣ / ٤'), findsNothing);
      expect(find.textContaining(' / '), findsNothing);
    });
  });

  group('home — the rest of the day', () {
    testWidgets('a restart shows the emblem again', (tester) async {
      // Opened earlier today and the app was closed since.
      await _pumpHome(tester, 3, _seededDay(3, revealed: 2),
          until: find.textContaining('هل سمعت'));

      expect(find.textContaining('هل سمعت'), findsOneWidget);
      expect(find.textContaining('رسالة رقم'), findsNothing);
    });

    testWidgets('pressing it after a restart moves on to the next message',
        (tester) async {
      await _pumpHome(tester, 3, _seededDay(3, revealed: 1),
          pressEmblem: true, until: find.textContaining('رسالة رقم 2'));
      await _settle(tester);

      expect(find.textContaining('رسالة رقم 2'), findsOneWidget);
      expect(find.textContaining('رسالة رقم 1'), findsNothing);
      expect(find.text('رسالة أخرى'), findsOneWidget);
      expect(await DailyTipService().revealedCount(), 2);
    });

    // A reminder lands on the message already reached rather than spending a
    // new one: a reader tapping it twice has not asked for anything new.
    testWidgets('a reminder tap lands straight on the message', (tester) async {
      DailyTipService.debugMessagesPerDay = 3;
      SharedPreferences.setMockInitialValues(_seededDay(3, revealed: 2));
      await DailyTipService().getTodayTips();
      await tester
          .pumpWidget(_host(const HomeScreen(openMessageOnStart: true)));
      await _settle(tester, until: find.textContaining('رسالة رقم 2'));
      await _settle(tester);

      expect(find.textContaining('رسالة رقم 2'), findsOneWidget);
      expect(find.textContaining('هل سمعت'), findsNothing);

      // And leaving it lands on the emblem like any other opening.
      await _closeWindow(tester);
      expect(find.textContaining('هل سمعت'), findsOneWidget);
    });

    testWidgets('a reminder tapped in the running app opens one window',
        (tester) async {
      await _pumpHome(tester, 3, _seededDay(3, revealed: 2),
          until: find.textContaining('هل سمعت'));

      NotificationScheduler.notificationTapped.value++;
      await _settle(tester, until: find.textContaining('رسالة رقم 2'));
      await _settle(tester);
      expect(find.byType(TodayMessageScreen), findsOneWidget);

      // A second tap with the window already open must not stack another.
      NotificationScheduler.notificationTapped.value++;
      await _settle(tester);
      await _settle(tester);
      expect(
          find.byType(TodayMessageScreen, skipOffstage: false), findsOneWidget);
    });

    testWidgets('offers another message while the day has more',
        (tester) async {
      await _pumpHome(tester, 3, _seededDay(3),
          pressEmblem: true, until: find.text('رسالة أخرى'));

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
          pressEmblem: true, until: find.text('نلقاك غداً بإذن الله'));

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
          pressEmblem: true, until: find.text('نلقاك غداً بإذن الله'));

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
