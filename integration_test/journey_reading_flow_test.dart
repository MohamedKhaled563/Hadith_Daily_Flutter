import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/core/theme/app_theme.dart';
import 'package:hadith_app/core/widgets/app_button.dart';
import 'package:hadith_app/data/journey/journey_repository.dart';
import 'package:hadith_app/data/journey/journey_store.dart';
import 'package:hadith_app/data/journey/reading_tracker.dart';
import 'package:hadith_app/data/models/hadith.dart';
import 'package:hadith_app/data/models/insight.dart';
import 'package:hadith_app/data/repositories/hadith_repository.dart';
import 'package:hadith_app/features/hadith/hadith_detail_screen.dart';
import 'package:hadith_app/features/hadith/hadith_explanation_screen.dart';
import 'package:hadith_app/features/journey/journey_tree.dart';
import 'package:hadith_app/features/messages/daily_message_card.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The hadith page on a real device, against the real clock: the rule that
/// matters is about seconds passing, which no fake clock can vouch for.
///
/// A hadith counts when its text and short explanation have had their time
/// on screen and the reader presses «قرأت الحديث ونويت العمل به». Either one
/// alone is not enough.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const confirm = 'قرأت الحديث ونويت العمل به';

  late Hadith hadith;

  Widget wrap(Widget home, {bool accessible = false}) => MaterialApp(
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
        home: home,
      );

  Future<void> show(WidgetTester tester, {bool accessible = false}) async {
    await tester.pumpWidget(
      wrap(HadithDetailScreen(hadith: hadith), accessible: accessible),
    );
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

  bool ready(WidgetTester tester) {
    final button = find.widgetWithText(AppButton, confirm);
    return button.evaluate().isNotEmpty &&
        tester.widget<AppButton>(button).onPressed != null;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await HadithRepository().load();
    await JourneyRepository().debugReset(store: InMemoryJourneyStore());
    hadith = HadithRepository().getByNumber(11)!;
  });

  testWidgets('scrolling straight to the end does not count as reading',
      (tester) async {
    await show(tester);
    await scrollToEnd(tester);
    await wait(tester, const Duration(seconds: 1));
    await tester.ensureVisible(find.widgetWithText(AppButton, confirm));
    await tester.pump();

    expect(ready(tester), isFalse);
    expect(find.textContaining('يكتمل الخيط مع قراءتك'), findsOneWidget);
    expect(JourneyRepository().data.completeCount, 0);
    expect(JourneyRepository().data.progressOf(hadith.number).textOn, isNull);
  });

  testWidgets(
      'the time turns the leaf green, and only the reader\'s word turns it '
      'gold', (tester) async {
    final tracker = ReadingTracker.sections(ReadingRule.pageSections(hadith));
    var needed = Duration.zero;
    for (var i = 0; i < tracker.length; i++) {
      needed += tracker.neededAt(i);
    }

    await show(tester);
    // Halfway through, it must still be waiting.
    await wait(tester, needed * .5);
    expect(ready(tester), isFalse);

    // The rest of the time, keeping whatever is still waiting on screen.
    final end = DateTime.now().add(needed * 1.5);
    while (DateTime.now().isBefore(end) && !ready(tester)) {
      await wait(tester, const Duration(seconds: 1));
      if (find.text(hadith.shortExplanation).evaluate().isNotEmpty &&
          JourneyRepository().data.progressOf(hadith.number).textOn == null) {
        await tester.ensureVisible(find.text(hadith.shortExplanation));
        await tester.pump();
      }
    }

    final progress = JourneyRepository().data.progressOf(hadith.number);
    expect(progress.textOn, isNotNull, reason: 'green once the time is spent');
    expect(progress.isComplete, isFalse, reason: 'gold needs the reader');

    await tester.ensureVisible(find.widgetWithText(AppButton, confirm));
    await tester.pump();
    expect(ready(tester), isTrue);
    await tester.tap(find.text(confirm));
    await wait(tester, const Duration(seconds: 1));

    final data = JourneyRepository().data;
    expect(data.progressOf(hadith.number).isComplete, isTrue);
    expect(find.textContaining(hadith.title), findsWidgets);
    expect(find.text('اكتب رسالة من هذا الحديث'), findsOneWidget);
    expect(find.text('الحديث التالي'), findsNothing);
    expect(data.days.values.single.seconds, greaterThan(0));
  });

  testWidgets('a screen reader can confirm without waiting', (tester) async {
    await show(tester, accessible: true);
    await tester.ensureVisible(find.widgetWithText(AppButton, confirm));
    await tester.pump();
    expect(ready(tester), isTrue);
  });

  testWidgets('the full explanation is there to read, and asks nothing',
      (tester) async {
    await tester.pumpWidget(wrap(HadithExplanationScreen(hadith: hadith)));
    await wait(tester, const Duration(seconds: 2));

    expect(find.byType(AppButton), findsNothing);
    for (final paragraph in ReadingRule.paragraphs(hadith.explanation)) {
      expect(find.text(paragraph), findsOneWidget);
    }
    expect(JourneyRepository().data.completeCount, 0);
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
