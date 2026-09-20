import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hadith_app/core/theme/app_theme.dart';
import 'package:hadith_app/data/models/insight.dart';
import 'package:hadith_app/data/repositories/hadith_repository.dart';
import 'package:hadith_app/features/messages/daily_message_screen.dart';

/// Two Heroes sharing one tag in one route subtree is an assertion failure,
/// not a glitch — so this is a latent crash rather than a cosmetic bug. Every
/// page of the daily-message pager carried `heart_leaf_emblem_hero`, and
/// mid-swipe two pages are alive at once.
///
/// Page 0 keeps the shared tag on purpose: it is the page on screen when the
/// route is pushed, so the flight from the home circle still matches.

DailyMessageEntry _entry(int n) => DailyMessageEntry(
      insight: Insight(
        hadithNumber: n,
        arabic: 'رسالة رقم $n',
        english: '',
        category: 'تأمّل',
        id: 'tip-$n',
        sourceCollection: 'dailyMessages',
      ),
      hadith: null,
    );

Widget _host(List<DailyMessageEntry> entries) => MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: DailyMessageScreen.forDay(entries: entries),
    );

List<Object> _tags(WidgetTester tester) =>
    tester.widgetList<Hero>(find.byType(Hero)).map((h) => h.tag).toList();

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Each page builds a live toolbar that reaches for Firestore the moment
    // it mounts, which is the whole reason two pages alive at once matters.
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await HadithRepository().load();
  });

  testWidgets('no two Heroes share a tag mid-swipe', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_host([_entry(1), _entry(2), _entry(3)]));
    await tester.pump(const Duration(milliseconds: 400));

    expect(_tags(tester), ['heart_leaf_emblem_hero'],
        reason: 'at rest only the visible page is built');

    // Drag part-way and stop: this is the window the collision lived in —
    // two pages alive, neither settled. Positive x, because the pager is
    // RTL: dragging towards the right is what reveals the *next* message.
    final gesture = await tester.startGesture(const Offset(200, 450));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(120, 0));
    await tester.pump();

    final tags = _tags(tester);
    expect(tags.length, greaterThan(1),
        reason: 'if only one page is alive this test proves nothing');
    expect(
      tags.toSet().length,
      tags.length,
      reason: 'duplicate Hero tags in one subtree: $tags',
    );

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('page 0 keeps the shared tag, so the flight still matches',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_host([_entry(1)]));
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      _tags(tester),
      contains('heart_leaf_emblem_hero'),
      reason: 'the home circle and the login screen fly to exactly this tag',
    );
  });

  testWidgets('the pager still pages after the physics change', (tester) async {
    // `physics` went from a hardcoded BouncingScrollPhysics to null so
    // PageView supplies PageScrollPhysics over the platform's own behaviour.
    // That is the default every PageView uses, but it is worth proving the
    // snap survived rather than assuming it.
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_host([_entry(1), _entry(2), _entry(3)]));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('« رسالة رقم 1 »'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(300, 0), 1200);
    await tester.pumpAndSettle();

    expect(find.text('« رسالة رقم 2 »'), findsOneWidget,
        reason: 'the fling has to settle on the next page, not spring back');
    expect(find.text('« رسالة رقم 1 »'), findsNothing);
  });
}
