import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/core/theme/app_theme.dart';
import 'package:hadith_app/data/models/insight.dart';
import 'package:hadith_app/data/repositories/hadith_repository.dart';
import 'package:hadith_app/features/messages/daily_message_card.dart';
import 'package:hadith_app/features/messages/daily_message_screen.dart';
import 'package:hadith_app/features/messages/today_message_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `heart_leaf_emblem_hero` is shared between the home emblem, the login
/// screen and the message card. Two live Heroes holding one tag in the same
/// subtree is an assertion failure — a crash, not a glitch — so the rule is
/// that at most one widget in the tree may carry it at a time.
///
/// This used to guard a specific way of breaking that: the day's messages
/// lived in a pager, and mid-swipe two pages were alive at once, both
/// claiming the tag. That pager is gone, but today's window has the same
/// shape for a moment: "رسالة أخرى" cross-fades, so two cards are alive at
/// once. Only the message the window opened on may hold the tag.

const _sharedTag = 'heart_leaf_emblem_hero';

Insight _insight(String text) => Insight(
      hadithNumber: 1,
      arabic: text,
      english: '',
      category: 'تأمّل',
      id: 'tip-1',
      sourceCollection: 'dailyMessages',
    );

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

List<Object> _tags(WidgetTester tester) =>
    tester.widgetList<Hero>(find.byType(Hero)).map((h) => h.tag).toList();

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // The card builds a live toolbar that reaches for Firestore as it mounts.
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await HadithRepository().load();
  });

  testWidgets(
      'a single message screen keeps the shared tag, so the flight '
      'from the home emblem still matches', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_host(
      DailyMessageScreen(insight: _insight('رسالة محفوظة')),
    ));
    await tester.pump(const Duration(milliseconds: 400));

    final tags = _tags(tester);
    expect(tags, contains(_sharedTag),
        reason: 'the home circle and the login screen fly to exactly this tag');
    expect(tags.where((t) => t == _sharedTag), hasLength(1));
  });

  testWidgets('the card claims no tag where it is not a flight destination',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_host(
      Scaffold(
        body: SingleChildScrollView(
          child: DailyMessageCard(
            entry: DailyMessageEntry(insight: _insight('رسالة اليوم')),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400));

    expect(_tags(tester), isNot(contains(_sharedTag)));
  });

  testWidgets('today\'s window never holds the tag twice, even mid cross-fade',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_host(
      TodayMessageScreen(
        entries: [
          DailyMessageEntry(insight: _insight('الرسالة الأولى')),
          DailyMessageEntry(insight: _insight('الرسالة الثانية')),
        ],
        revealed: 1,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 400));

    expect(_tags(tester).where((t) => t == _sharedTag), hasLength(1),
        reason: 'the emblem flies to the message the window opens on');

    await tester.tap(find.text('رسالة أخرى'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Control: if only one card were alive this would prove nothing.
    expect(find.byType(DailyMessageCard), findsNWidgets(2));
    expect(_tags(tester).where((t) => t == _sharedTag), hasLength(1));
  });
}
