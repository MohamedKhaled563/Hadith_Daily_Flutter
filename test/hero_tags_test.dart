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
import 'package:shared_preferences/shared_preferences.dart';

/// `heart_leaf_emblem_hero` is shared between the home emblem, the login
/// screen and the message card. Two live Heroes holding one tag in the same
/// subtree is an assertion failure — a crash, not a glitch — so the rule is
/// that at most one widget in the tree may carry it at a time.
///
/// This used to guard a specific way of breaking that: the day's messages
/// lived in a pager, and mid-swipe two pages were alive at once, both
/// claiming the tag. That pager is gone — today's message is inline on the
/// home tab — so the collision it guarded cannot recur. What replaces it is
/// the rule itself, checked on the two places that still render the card.

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

  testWidgets('a single message screen keeps the shared tag, so the flight '
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

    // This is how home renders it: the card *replaces* the emblem on the same
    // tab rather than arriving from it, so claiming the emblem's tag there
    // would put two Heroes with one tag in a single subtree the moment
    // anything else on that route claimed it too.
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
}
