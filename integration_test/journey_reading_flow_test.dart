import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/core/theme/app_theme.dart';
import 'package:hadith_app/data/journey/journey_repository.dart';
import 'package:hadith_app/data/journey/journey_store.dart';
import 'package:hadith_app/data/journey/reading_tracker.dart';
import 'package:hadith_app/data/models/hadith.dart';
import 'package:hadith_app/data/models/insight.dart';
import 'package:hadith_app/data/repositories/hadith_repository.dart';
import 'package:hadith_app/features/hadith/hadith_explanation_screen.dart';
import 'package:hadith_app/features/journey/journey_tree.dart';
import 'package:hadith_app/features/messages/daily_message_card.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The reading screen on a real device, against the real clock: the rule that
/// matters is about seconds passing, which no fake clock can vouch for.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const finish = 'أتممت القراءة';
  const carryOn = 'أكمل من حيث توقفت';

  late Hadith hadith;

  Future<void> show(WidgetTester tester, {bool accessible = false}) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          accessibleNavigation: accessible,
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: HadithExplanationScreen(hadith: hadith),
    ));
    await tester.pump();
  }

  /// Lets real seconds pass with the screen ticking.
  Future<void> wait(WidgetTester tester, Duration duration) async {
    final end = DateTime.now().add(duration);
    while (DateTime.now().isBefore(end)) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
    }
  }

  Future<void> scrollToEnd(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();
    }
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await HadithRepository().load();
    await JourneyRepository().debugReset(store: InMemoryJourneyStore());
    // The shortest explanation, so the test waits as little as a reader would.
    hadith = HadithRepository().getByNumber(11)!;
  });

  testWidgets('scrolling straight to the end does not count as reading',
      (tester) async {
    await show(tester);
    await scrollToEnd(tester);
    await wait(tester, const Duration(seconds: 1));

    expect(find.text(carryOn), findsOneWidget);
    expect(find.text(finish), findsNothing);
    expect(JourneyRepository().data.completeCount, 0);
  });

  testWidgets('staying with each paragraph completes the hadith',
      (tester) async {
    final words = ReadingRule.paragraphs(hadith.explanation)
        .map(ReadingRule.wordCount)
        .toList();
    final needed = words.fold(
      Duration.zero,
      (total, count) => total + ReadingRule.neededFor(count),
    );

    await show(tester);
    // Halfway through, it must still be waiting.
    await wait(tester, needed * .5);
    await scrollToEnd(tester);
    expect(find.text(finish), findsNothing);

    // Back at the top, the rest of the time, paragraph by paragraph.
    final end = DateTime.now().add(needed * 1.2);
    while (DateTime.now().isBefore(end) && find.text(finish).evaluate().isEmpty) {
      await wait(tester, const Duration(seconds: 1));
      await tester.drag(find.byType(ListView), const Offset(0, 90));
      await tester.pump();
      if (find.text(carryOn).evaluate().isNotEmpty) {
        await tester.ensureVisible(find.text(carryOn));
        await tester.tap(find.text(carryOn));
        await tester.pump();
      }
    }

    await scrollToEnd(tester);
    expect(find.text(finish), findsOneWidget);
    await tester.tap(find.text(finish));
    await wait(tester, const Duration(seconds: 1));

    final data = JourneyRepository().data;
    expect(data.progressOf(hadith.number).isComplete, isTrue);
    expect(find.textContaining(hadith.title), findsWidgets);
    expect(find.text('اكتب رسالة من هذا الحديث'), findsOneWidget);
    expect(find.text('الحديث التالي'), findsOneWidget);
    expect(data.days.values.single.seconds, greaterThan(0));
  });

  testWidgets('a screen reader can finish without waiting', (tester) async {
    await show(tester, accessible: true);
    await scrollToEnd(tester);
    expect(find.text(finish), findsOneWidget);
  });

  Future<void> showMessage(WidgetTester tester, Widget card) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: SingleChildScrollView(child: card)),
    ));
    await tester.pump();
  }

  const insight = Insight(
    hadithNumber: 13,
    arabic: 'ابدأ يومك بنية طيبة',
    english: '',
    id: 'msg-test',
  );

  testWidgets("staying with today's message fills the day's first step",
      (tester) async {
    await showMessage(
      tester,
      const DailyMessageCard(entry: DailyMessageEntry(insight: insight)),
    );
    await wait(tester, const Duration(seconds: 2));
    expect(JourneyRepository().todaySteps.message, isFalse,
        reason: 'a glance is not a read');

    await wait(tester, DailyMessageCard.readDelay);
    final journey = JourneyRepository();
    expect(journey.todaySteps.message, isTrue);
    expect(journey.streak.current, 1);
    expect(journey.nextHadithNumber, 13,
        reason: "today's hadith is the one behind the message");
  });

  testWidgets('a saved message reopened does not count', (tester) async {
    await showMessage(
      tester,
      const DailyMessageCard(
        entry: DailyMessageEntry(insight: insight),
        countsAsRead: false,
      ),
    );
    await wait(tester, DailyMessageCard.readDelay * 1.5);
    expect(JourneyRepository().todaySteps.message, isFalse);
  });

  test('every leaf can be tapped, and no two share a spot', () {
    const size = Size(TreeLayout.width, TreeLayout.height);
    final leaves = TreeLayout.instance.leaves;
    expect(leaves, hasLength(42));
    for (final leaf in leaves) {
      expect(JourneyTreePainter.hitLeaf(leaf.centre, size), leaf.number);
      expect(leaf.centre.dx, inInclusiveRange(0, TreeLayout.width));
      expect(leaf.centre.dy, inInclusiveRange(0, TreeLayout.height));
    }
  });
}
