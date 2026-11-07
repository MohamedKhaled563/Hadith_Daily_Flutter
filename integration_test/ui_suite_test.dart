import 'dart:math' as math;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/core/share/share_service.dart';
import 'package:hadith_app/core/theme/app_theme.dart';
import 'package:hadith_app/core/widgets/bottom_navigation.dart';
import 'package:hadith_app/data/journey/journey_engine.dart';
import 'package:hadith_app/data/journey/journey_points.dart';
import 'package:hadith_app/data/journey/journey_repository.dart';
import 'package:hadith_app/data/journey/journey_store.dart';
import 'package:hadith_app/data/journey/reading_tracker.dart';
import 'package:hadith_app/data/repositories/hadith_repository.dart';
import 'package:hadith_app/data/services/favorites_store.dart';
import 'package:hadith_app/data/services/notification_scheduler.dart';
import 'package:hadith_app/features/favorites/favorites_screen.dart';
import 'package:hadith_app/features/hadith/hadith_detail_screen.dart';
import 'package:hadith_app/features/hadith/hadith_explanation_screen.dart';
import 'package:hadith_app/features/hadith/hadith_list_screen.dart';
import 'package:hadith_app/features/home/home_screen.dart';
import 'package:hadith_app/features/journey/journey_posters.dart';
import 'package:hadith_app/features/journey/journey_ring.dart';
import 'package:hadith_app/features/journey/journey_screen.dart';
import 'package:hadith_app/features/journey/journey_tree.dart';
import 'package:hadith_app/firebase_options.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The journey as a reader meets it: real taps and scrolls on real screens,
/// on a device, as a guest. Firebase points at a demo project, so a run can
/// never touch the live one.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final hadiths = HadithRepository();
  final journey = JourneyRepository();
  late InMemoryJourneyStore store;
  String? copied;

  const finish = 'أتممت القراءة';
  const carryOn = 'أكمل من حيث توقفت';

  Widget app(
    Widget home, {
    bool accessible = false,
    bool dark = false,
    Size? size,
    double textScale = 1,
  }) =>
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          final data = MediaQuery.of(context).copyWith(
            accessibleNavigation: accessible,
            disableAnimations: true,
            textScaler: TextScaler.linear(textScale),
            size: size,
          );
          final content = MediaQuery(data: data, child: child!);
          if (size == null) return content;
          return Center(
            child: SizedBox.fromSize(
              size: size,
              child: ClipRect(child: content),
            ),
          );
        },
        home: home,
      );

  /// Real time passing, with frames, so timers and routes both move.
  Future<void> wait(WidgetTester tester, [int ms = 500]) async {
    final end = DateTime.now().add(Duration(milliseconds: ms));
    while (DateTime.now().isBefore(end)) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
  }

  Finder tab(String label) => find.descendant(
        of: find.byType(BottomNavigation),
        matching: find.text(label),
      );

  Future<void> openJourney(WidgetTester tester, {bool accessible = false}) async {
    await tester.pumpWidget(app(const HomeScreen(), accessible: accessible));
    await wait(tester);
    await tester.tap(tab('رحلتي'));
    await wait(tester);
  }

  Future<void> tapLeaf(WidgetTester tester, int number) async {
    final box = tester.renderObject<RenderBox>(find.byType(JourneyTree));
    final scale = math.min(
      box.size.width / TreeLayout.width,
      box.size.height / TreeLayout.height,
    );
    final leaf =
        TreeLayout.instance.leaves.firstWhere((l) => l.number == number);
    await tester.tapAt(box.localToGlobal(leaf.centre * scale));
    await wait(tester, 800);
  }

  /// Marks hadiths finished the way a reading would, without the wait.
  void finished(Iterable<int> numbers) {
    for (final number in numbers) {
      journey.recordFullRead(number, seconds: 60);
    }
  }

  Future<void> openExplanation(
    WidgetTester tester, {
    String label = 'قراءة الشرح كاملاً',
  }) async {
    final teaser = find.text(label);
    await tester.scrollUntilVisible(
      teaser,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await wait(tester, 200);
    await tester.tap(teaser.last);
    await wait(tester, 800);
    expect(find.byType(HadithExplanationScreen), findsOneWidget);
  }

  Future<void> scrollToFinish(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await tester.pump();
    }
    await wait(tester, 300);
  }

  setUpAll(() async {
    final options = DefaultFirebaseOptions.currentPlatform;
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: options.apiKey,
        appId: options.appId,
        messagingSenderId: options.messagingSenderId,
        projectId: 'demo-ui-suite',
      ),
    );
    SharedPreferences.setMockInitialValues({});
    await hadiths.load();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = InMemoryJourneyStore();
    await journey.debugReset(store: store);
    hadiths.debugOverrideFavorites(
      store: InMemoryFavoritesStore(),
      currentUid: () => null,
    );
    copied = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('a new reader', () {
    testWidgets('sees an empty tree, open steps and nothing to share',
        (tester) async {
      await openJourney(tester);

      expect(find.byType(JourneyTree), findsOneWidget);
      expect(find.textContaining('كل ورقة هنا حديث'), findsOneWidget);
      expect(find.text('اقرأ رسالة اليوم'), findsOneWidget);
      expect(find.text('اقرأ حديث «الأعمال بالنيات»'), findsOneWidget);
      expect(find.byIcon(Icons.ios_share_rounded), findsNothing);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    });

    testWidgets('a tapped reminder about a hadith opens that hadith',
        (tester) async {
      await tester.pumpWidget(app(const HomeScreen()));
      await wait(tester);
      await tester.tap(tab('رحلتي'));
      await wait(tester);

      NotificationScheduler.hadithTapped.value = HadithReminderTap(16);
      final deadline = DateTime.now().add(const Duration(seconds: 5));
      while (find.byType(HadithDetailScreen).evaluate().isEmpty &&
          DateTime.now().isBefore(deadline)) {
        await wait(tester, 200);
      }

      final opened =
          tester.widget<HadithDetailScreen>(find.byType(HadithDetailScreen));
      expect(opened.hadith.number, 16);

      Navigator.of(tester.element(find.byType(HadithDetailScreen))).pop();
      await wait(tester, 1500);
      expect(find.byType(HadithDetailScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('a reminder that started the app lands on its hadith',
        (tester) async {
      await tester.pumpWidget(app(const HomeScreen(openHadithOnStart: 7)));
      await wait(tester);

      final opened =
          tester.widget<HadithDetailScreen>(find.byType(HadithDetailScreen));
      expect(opened.hadith.number, 7);
    });

    testWidgets('sees a leaf in the ring, which opens the journey',
        (tester) async {
      await tester.pumpWidget(app(const HomeScreen()));
      await wait(tester);

      expect(find.byType(JourneyRing), findsOneWidget);
      await tester.tap(find.byType(JourneyRing));
      await wait(tester);
      expect(find.byType(JourneyScreen), findsOneWidget);
      expect(find.textContaining('كل ورقة هنا حديث'), findsOneWidget);
    });
  });

  group('the daily loop', () {
    testWidgets('a whole reading, in real time, from leaf to gold leaf',
        (tester) async {
      await openJourney(tester);

      await tapLeaf(tester, 11);
      final hadith = hadiths.getByNumber(11)!;
      expect(find.byType(HadithDetailScreen), findsOneWidget);
      expect(find.text(hadith.title), findsOneWidget);

      // The page alone is the green stage, once it has had its time.
      final pageTime = ReadingRule.neededForSections([
        ReadingRule.wordCount('${hadith.isnad} ${hadith.text}'),
        ReadingRule.wordCount(hadith.shortExplanation),
      ]);
      await wait(tester, pageTime.inMilliseconds + 1000);
      expect(journey.data.progressOf(11).textOn, isNotNull);
      expect(journey.data.progressOf(11).isComplete, isFalse);

      await openExplanation(tester);
      await scrollToFinish(tester);
      expect(find.text(carryOn), findsOneWidget,
          reason: 'racing to the end must not finish it');

      // Reading, from wherever the button sends the reader back to.
      final deadline = DateTime.now().add(const Duration(seconds: 45));
      while (find.text(finish).evaluate().isEmpty &&
          DateTime.now().isBefore(deadline)) {
        if (find.text(carryOn).evaluate().isNotEmpty) {
          await tester.tap(find.text(carryOn));
        }
        await wait(tester, 2000);
      }
      await scrollToFinish(tester);
      expect(find.text(finish), findsOneWidget);

      await tester.tap(find.text(finish));
      await wait(tester, 900);

      expect(find.text('اكتمل حديث «${hadith.title}»'), findsOneWidget);
      expect(find.text('١ من ٤٢ حديثاً'), findsOneWidget);
      expect(find.text('سجّل الدخول لتبقى شجرتك معك'), findsOneWidget);
      expect(journey.data.progressOf(11).isComplete, isTrue);
      expect(journey.data.days[journey.today]!.seconds, greaterThan(0));
      expect(journey.streak.current, 1);
    });

    testWidgets('the sheet leads on to the next hadith', (tester) async {
      await openJourney(tester, accessible: true);
      await tapLeaf(tester, 12);
      await openExplanation(tester);
      await scrollToFinish(tester);
      await tester.tap(find.text(finish));
      await wait(tester, 900);

      await tester.tap(find.text('الحديث التالي'));
      await wait(tester, 1000);

      expect(find.byType(HadithDetailScreen), findsOneWidget);
      expect(
        find.text(hadiths.getByNumber(journey.nextHadithNumber!)!.title),
        findsOneWidget,
      );
      expect(find.byType(HadithExplanationScreen), findsNothing);
    });

    testWidgets('the sheet leads on to writing about that hadith',
        (tester) async {
      await openJourney(tester, accessible: true);
      await tapLeaf(tester, 12);
      await openExplanation(tester);
      await scrollToFinish(tester);
      await tester.tap(find.text(finish));
      await wait(tester, 900);

      await tester.tap(find.text('اكتب رسالة من هذا الحديث'));
      await wait(tester, 1000);

      expect(find.text('شارك رسالتك'), findsOneWidget);
      expect(
        find.textContaining(hadiths.getByNumber(12)!.title),
        findsWidgets,
      );
    });

    testWidgets('after reading, the steps name what is next', (tester) async {
      finished([1]);
      await openJourney(tester);

      await tester.scrollUntilVisible(
        find.textContaining('أتممت حديث اليوم'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.textContaining('التالي'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('the writing step opens with the hadith just read',
        (tester) async {
      finished([7]);
      await openJourney(tester);

      await tester.scrollUntilVisible(
        find.text('اكتب رسالتك'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      // Clear of the floating tab bar, as a reader would scroll it.
      await tester.drag(
        find.byType(Scrollable).last,
        const Offset(0, -260),
      );
      await wait(tester, 300);
      await tester.tap(find.text('اكتب رسالتك'));
      await wait(tester, 1000);

      expect(find.text('شارك رسالتك'), findsOneWidget);
      expect(find.textContaining(hadiths.getByNumber(7)!.title), findsWidgets);
    });
  });

  group('milestones', () {
    Future<void> finishLast(
      WidgetTester tester,
      int number, {
      String teaser = 'قراءة الشرح كاملاً',
    }) async {
      await openJourney(tester, accessible: true);
      await tapLeaf(tester, number);
      await openExplanation(tester, label: teaser);
      await scrollToFinish(tester);
      await tester.tap(find.text(finish));
      await wait(tester, 900);
    }

    testWidgets('the fifth hadith gets its message', (tester) async {
      finished([1, 2, 3, 4]);
      await finishLast(tester, 5);
      expect(find.text('صارت خمسة'), findsOneWidget);
    });

    testWidgets('the tenth uses the title just read', (tester) async {
      finished([for (var n = 1; n <= 9; n++) n]);
      await finishLast(tester, 10);
      expect(find.text('عشرة أحاديث، ما شاء الله'), findsOneWidget);
      expect(find.textContaining(hadiths.getByNumber(10)!.title), findsWidgets);
    });

    testWidgets('the last hadith ends the Forty, with nothing after it',
        (tester) async {
      finished([for (var n = 1; n <= 41; n++) n]);
      await finishLast(tester, 42);

      expect(find.text('ختمت الأربعين النووية'), findsOneWidget);
      expect(find.text('٤٢ من ٤٢ حديثاً'), findsOneWidget);
      expect(find.text('الحديث التالي'), findsNothing);
      expect(journey.nextHadithNumber, isNull);
    });

    testWidgets('a milestone does not repeat on a re-read', (tester) async {
      finished([1, 2, 3, 4, 5]);
      await finishLast(tester, 5, teaser: 'قراءة الشرح مرة أخرى');
      expect(find.text('صارت خمسة'), findsNothing);
      expect(find.text('أتممت قراءته مرة أخرى'), findsOneWidget);
    });
  });

  group('sharing', () {
    testWidgets('a finished hadith can be previewed in both shapes and copied',
        (tester) async {
      await openJourney(tester, accessible: true);
      await tapLeaf(tester, 12);
      await openExplanation(tester);
      await scrollToFinish(tester);
      await tester.tap(find.text(finish));
      await wait(tester, 900);

      await tester.tap(find.text('مشاركة'));
      await wait(tester, 900);

      expect(find.byType(HadithPoster), findsOneWidget);
      expect(
        tester.widget<HadithPoster>(find.byType(HadithPoster)).format,
        PosterFormat.feed,
      );
      expect(find.text('إظهار اسمي'), findsNothing,
          reason: 'a guest has no name to show');

      await tester.tap(find.text('حالة'));
      await wait(tester, 400);
      expect(
        tester.widget<HadithPoster>(find.byType(HadithPoster)).format,
        PosterFormat.story,
      );

      await tester.tap(find.text('نسخ النص'));
      await wait(tester, 500);
      expect(copied, contains(hadiths.getByNumber(12)!.title));
      await wait(tester, 4500);
    });

    testWidgets('the tree can be shared once it has a leaf', (tester) async {
      finished([1, 2, 3]);
      await openJourney(tester);

      await tester.tap(find.byIcon(Icons.ios_share_rounded).first);
      await wait(tester, 900);
      expect(find.byType(TreePoster), findsOneWidget);
      expect(find.text('٣ من ٤٢ حديثاً'), findsWidgets);

      await tester.tap(find.text('نسخ النص'));
      await wait(tester, 500);
      expect(copied, contains('قرأت ٣ من ٤٢ حديثاً'));
      await wait(tester, 4500);
    });
  });

  group('sending', () {
    const channel = MethodChannel('dev.fluttercommunity.plus/share');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    testWidgets('hands the phone the rendered image and the caption',
        (tester) async {
      Map<dynamic, dynamic>? sent;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        sent = call.arguments as Map<dynamic, dynamic>;
        return 'dev.fluttercommunity.plus/share/unavailable';
      });

      finished([1, 2, 3]);
      await openJourney(tester);
      await tester.tap(find.byIcon(Icons.ios_share_rounded).first);
      await wait(tester, 900);

      await tester.tap(find.text('مشاركة الصورة'));
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (sent == null && DateTime.now().isBefore(deadline)) {
        await wait(tester, 200);
      }

      expect(sent, isNotNull, reason: 'nothing reached the share sheet');
      expect(sent!['text'], contains('قرأت ٣ من ٤٢ حديثاً'));
      final files = sent!['paths'] as List<dynamic>;
      expect(files.single, endsWith('.png'));
      await wait(tester, 500);
    });
  });

  group('points, records and the harvest', () {
    const channel = MethodChannel('dev.fluttercommunity.plus/share');

    tearDown(() {
      ShareService.onShared = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    Future<void> scrollTo(WidgetTester tester, Finder target) async {
      await tester.scrollUntilVisible(
        target,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await wait(tester, 300);
    }

    testWidgets('a new reader has no points and no records yet',
        (tester) async {
      await openJourney(tester);

      await scrollTo(tester, find.text('نقاطك هذا الأسبوع'));
      expect(find.text('الماضي ٠'), findsOneWidget);
      expect(find.text('شارك حصاد أسبوعك'), findsNothing);

      await scrollTo(tester, find.text(JourneyRecord.weekWrote.label));
      expect(find.text('أرقامك'), findsOneWidget);
      for (final record in JourneyRecord.values) {
        expect(find.text(record.label), findsOneWidget);
      }
      expect(find.text('—'), findsWidgets);
    });

    testWidgets('a week of reading shows its points and records',
        (tester) async {
      final now = DateTime(2026, 11, 14, 12);
      await journey.debugReset(store: store, clock: () => now);
      journey.recordMessageRead('a', hadithNumber: 1);
      journey.recordMessageRead('b', hadithNumber: 2);
      journey.recordFullRead(1, seconds: 300);
      // What a screen reader is told, read from the widget that says it.
      Finder said(String label) => find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == label,
          );

      await openJourney(tester);
      await scrollTo(tester, find.text('نقاطك هذا الأسبوع'));
      // Two messages and a hadith: 2 + 2 + 10.
      expect(
        said('نقاطك هذا الأسبوع ١٤، والأسبوع الماضي ٠'),
        findsOneWidget,
      );
      expect(find.text('شارك حصاد أسبوعك'), findsOneWidget);

      await scrollTo(tester, find.text(JourneyRecord.weekWrote.label));
      expect(
        said('${JourneyRecord.dayMinutes.label}: ٥ دقائق'),
        findsOneWidget,
      );
      expect(
        said('${JourneyRecord.weekWrote.label}: —'),
        findsOneWidget,
      );
    });

    testWidgets('the harvest of the week can be previewed and copied',
        (tester) async {
      finished([1]);
      await openJourney(tester);

      await scrollTo(tester, find.text('شارك حصاد أسبوعك'));
      await tester.tap(find.text('شارك حصاد أسبوعك'));
      await wait(tester, 900);
      expect(find.byType(HarvestPoster), findsOneWidget);

      await tester.tap(find.text('نسخ النص'));
      await wait(tester, 500);
      expect(copied, startsWith('هذا الأسبوع: يوم واحد'));
      await wait(tester, 4500);
    });

    testWidgets('a card that leaves the app counts as a share', (tester) async {
      ShareService.onShared = journey.recordShared;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        channel,
        (call) async => 'dev.fluttercommunity.plus/share/unavailable',
      );

      finished([1, 2, 3]);
      final before = journey.thisWeekPoints.total;
      await openJourney(tester);
      await tester.tap(find.byIcon(Icons.ios_share_rounded).first);
      await wait(tester, 900);
      await tester.tap(find.text('مشاركة الصورة'));
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while ((journey.data.days[journey.today]?.shared ?? 0) == 0 &&
          DateTime.now().isBefore(deadline)) {
        await wait(tester, 200);
      }

      expect(journey.data.days[journey.today]!.shared, 1);
      expect(journey.thisWeekPoints.total, before + PointRules.share);
      await wait(tester, 500);
    });

    testWidgets('a card the reader backs out of does not count',
        (tester) async {
      ShareService.onShared = journey.recordShared;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => '');

      finished([1]);
      await openJourney(tester);
      await tester.tap(find.byIcon(Icons.ios_share_rounded).first);
      await wait(tester, 900);
      await tester.tap(find.text('مشاركة الصورة'));
      await wait(tester, 3000);

      expect(journey.data.days[journey.today]?.shared ?? 0, 0);
    });

    testWidgets('a tapped harvest closes what is open and shows the journey',
        (tester) async {
      await tester.pumpWidget(app(const HomeScreen()));
      await wait(tester);
      Navigator.of(tester.element(find.byType(HomeScreen))).push(
        MaterialPageRoute<void>(
          builder: (_) => HadithDetailScreen(hadith: hadiths.getByNumber(3)!),
        ),
      );
      await wait(tester, 900);
      expect(find.byType(HadithDetailScreen), findsOneWidget);

      NotificationScheduler.harvestTapped.value++;
      await wait(tester, 1500);

      expect(find.byType(HadithDetailScreen), findsNothing);
      expect(find.byType(JourneyTree).hitTestable(), findsOneWidget);
    });

    testWidgets('a harvest that started the app lands on the journey',
        (tester) async {
      await tester.pumpWidget(app(const HomeScreen(openJourneyOnStart: true)));
      await wait(tester);

      expect(find.byType(JourneyTree).hitTestable(), findsOneWidget);
    });

    testWidgets('the sheet names the record a reading beat', (tester) async {
      var now = DateTime(2026, 11, 7, 12);
      await journey.debugReset(store: store, clock: () => now);
      journey.recordFullRead(1, seconds: 60);
      now = DateTime(2026, 11, 14, 12);
      journey.recordFullRead(2, seconds: 60);

      await openJourney(tester, accessible: true);
      await tapLeaf(tester, 3);
      await openExplanation(tester);
      await scrollToFinish(tester);
      await tester.tap(find.text(finish));
      await wait(tester, 900);

      final shown = [
        for (final record in JourneyRecord.values)
          if (find.text(record.brokenLine).evaluate().isNotEmpty) record,
      ];
      expect(shown, hasLength(1));
      expect(shown.single, isNot(JourneyRecord.streak));
    });
  });

  group('the journey around the app', () {
    testWidgets('the hadith list marks what was read', (tester) async {
      finished([1]);
      await tester.pumpWidget(app(const HadithListScreen()));
      await wait(tester, 900);

      await tester.scrollUntilVisible(
        find.text('الأعمال بالنيات'),
        150,
        scrollable: find.byType(Scrollable).last,
      );
      await wait(tester, 300);
      expect(find.byIcon(Icons.eco_rounded), findsOneWidget);
    });

    testWidgets('a finished hadith offers its explanation again',
        (tester) async {
      finished([16]);
      await tester.pumpWidget(
        app(HadithDetailScreen(hadith: hadiths.getByNumber(16)!)),
      );
      await wait(tester);

      await tester.scrollUntilVisible(
        find.text('قراءة الشرح مرة أخرى'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('قراءة الشرح كاملاً'), findsNothing);
    });

    testWidgets('favourites are a tap away and the tree comes back',
        (tester) async {
      await openJourney(tester);

      await tester.tap(find.text('المفضلة'));
      await wait(tester);
      expect(find.byType(FavoritesScreen), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(JourneyScreen),
          matching: find.text('رحلتي'),
        ).at(1),
      );
      await wait(tester);
      expect(find.byType(JourneyTree).hitTestable(), findsOneWidget);
    });

    testWidgets('a restart keeps a guest journey on the phone', (tester) async {
      finished([1, 2]);
      await wait(tester, 300);

      await journey.debugReset(store: store);
      await wait(tester, 300);
      await openJourney(tester);

      expect(find.text('٢ من ٤٢ حديثاً'), findsOneWidget);
    });

    testWidgets('a streak over several days shows on the journey',
        (tester) async {
      var now = DateTime(2026, 11, 2, 12);
      await journey.debugReset(store: store, clock: () => now);
      for (var day = 0; day < 8; day++) {
        now = DateTime(2026, 11, 2 + day, 12);
        journey.recordMessageRead('m$day', hadithNumber: 1);
      }
      expect(journey.streak.current, 8);
      expect(journey.streak.graceBanked, 1);

      await openJourney(tester);
      await tester.scrollUntilVisible(
        find.text('سلسلتك الآن'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('٨'), findsWidgets);
      expect(find.text('أيام سماح'), findsOneWidget);
    });

    testWidgets('sign-in moves a guest tree, and two accounts stay apart',
        (tester) async {
      finished([1]);
      await wait(tester, 300);
      await openJourney(tester);
      expect(find.text('١ من ٤٢ حديثاً'), findsOneWidget);

      journey.setUser('reader-a');
      await wait(tester, 400);
      expect(find.text('١ من ٤٢ حديثاً'), findsOneWidget,
          reason: 'the reading joined the account');

      journey.setUser('reader-b');
      await wait(tester, 400);
      expect(find.textContaining('كل ورقة هنا حديث'), findsOneWidget);

      journey.setUser('reader-a');
      await wait(tester, 400);
      expect(find.text('١ من ٤٢ حديثاً'), findsOneWidget);

      journey.setUser(null);
      await wait(tester, 400);
      expect(find.textContaining('كل ورقة هنا حديث'), findsOneWidget);
    });
  });

  group('every screen, everywhere', () {
    const sizes = {
      'small 320x568': Size(320, 568),
      'common 360x640': Size(360, 640),
      'large 412x844': Size(412, 844),
    };

    for (final size in sizes.entries) {
      for (final dark in [false, true]) {
        for (final textScale in [1.0, 1.3]) {
          final label = '${size.key}, ${dark ? 'dark' : 'light'}, '
              'text ×$textScale';

          testWidgets('the journey lays out: $label', (tester) async {
            finished([1, 2, 3]);
            await tester.pumpWidget(app(
              const HomeScreen(),
              size: size.value,
              dark: dark,
              textScale: textScale,
            ));
            await wait(tester, 300);
            expect(tester.takeException(), isNull, reason: 'home: $label');

            await tester.tap(tab('رحلتي'));
            await wait(tester, 300);
            for (var i = 0; i < 6; i++) {
              await tester.drag(
                find.byType(ListView).first,
                const Offset(0, -350),
              );
              await tester.pump();
            }
            await wait(tester, 200);
            expect(tester.takeException(), isNull, reason: 'journey: $label');

            await tester.pumpWidget(app(
              HadithExplanationScreen(hadith: hadiths.getByNumber(2)!),
              size: size.value,
              dark: dark,
              textScale: textScale,
            ));
            await wait(tester, 300);
            expect(tester.takeException(), isNull, reason: 'reading: $label');
          });
        }
      }
    }
  });

  group('accessibility', () {
    testWidgets('every leaf and the ring can be heard', (tester) async {
      final semantics = tester.ensureSemantics();
      finished([1]);
      await tester.pumpWidget(app(const HomeScreen()));
      await wait(tester);

      // Read from what a screen reader walks through, because the tree's
      // leaves are drawn and no widget finder can see them.
      List<String> heard() => tester.semantics
          .simulatedAccessibilityTraversal()
          .map((node) => node.getSemanticsData().label)
          .toList();

      expect(
        heard().any((label) => label.contains('من ٣ خطوات اليوم')),
        isTrue,
      );

      await tester.tap(tab('رحلتي'));
      await wait(tester);

      final labels = heard();
      expect(labels.where((l) => l.startsWith('الحديث ')), hasLength(42));
      expect(
        labels.where((l) => l.startsWith('الحديث ١:')).single,
        endsWith('مكتمل'),
      );
      expect(
        labels.where((l) => l.startsWith('الحديث ٢:')).single,
        endsWith('خطوة اليوم'),
      );
      expect(
        labels.where((l) => l.startsWith('الحديث ٤٢:')).single,
        endsWith('لم يُقرأ بعد'),
      );
      semantics.dispose();
    });

    testWidgets('the day boundary used by the screens is the reading day',
        (tester) async {
      expect(journey.today, journeyDayKey(DateTime.now()));
    });
  });
}
