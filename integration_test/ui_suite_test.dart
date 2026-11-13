import 'dart:math' as math;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/core/share/share_service.dart';
import 'package:hadith_app/core/theme/app_theme.dart';
import 'package:hadith_app/core/widgets/bottom_navigation.dart';
import 'package:hadith_app/data/journey/board_service.dart';
import 'package:hadith_app/data/journey/journey_copy.dart';
import 'package:hadith_app/data/journey/journey_engine.dart';
import 'package:hadith_app/data/journey/journey_points.dart';
import 'package:hadith_app/data/journey/journey_repository.dart';
import 'package:hadith_app/data/journey/journey_store.dart';
import 'package:hadith_app/data/journey/reading_tracker.dart';
import 'package:hadith_app/data/journey/weekly_board.dart';
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
import 'package:hadith_app/features/journey/today_steps_screen.dart';
import 'package:hadith_app/features/journey/weekly_board_screen.dart';
import 'package:hadith_app/features/memorize/memo_list_screen.dart';
import 'package:hadith_app/features/memorize/memorize_screen.dart';
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

  const confirm = 'قرأت الحديث ونويت العمل به';

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

  /// Real time passing until [done] holds, or [seconds] are up: a pushed
  /// or popped page on a busy device can take longer than a fixed wait.
  Future<void> until(
    WidgetTester tester,
    bool Function() done, {
    int seconds = 5,
  }) async {
    final deadline = DateTime.now().add(Duration(seconds: seconds));
    while (!done() && DateTime.now().isBefore(deadline)) {
      await wait(tester, 100);
    }
    await wait(tester, 200);
  }

  bool shows(Finder finder) => finder.evaluate().isNotEmpty;

  Finder tab(String label) => find.descendant(
        of: find.byType(BottomNavigation),
        matching: find.text(label),
      );

  Future<void> openJourney(WidgetTester tester,
      {bool accessible = false}) async {
    await tester.pumpWidget(app(const HomeScreen(), accessible: accessible));
    await wait(tester);
    await tester.tap(tab('رحلتي'));
    await wait(tester);
  }

  /// رحلتي, then its «خطوات اليوم» button, onto the day's steps.
  Future<void> openSteps(WidgetTester tester) async {
    await openJourney(tester);
    final button = find.text('خطوات اليوم');
    await tester.ensureVisible(button);
    await wait(tester, 300);
    await tester.tap(button);
    await until(
        tester,
        () =>
            shows(find.text(JourneyCopy.stepsAllDone)) ||
            shows(find.text(JourneyCopy.stepsDayCounted)) ||
            shows(find.text(JourneyCopy.stepsHowToCount)));
    expect(find.byType(TodayStepsScreen), findsOneWidget);
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

  /// Presses «قرأت الحديث ونويت العمل به» on the hadith page. Ready at once
  /// with accessibleNavigation, as for a screen reader; otherwise only after
  /// the page has had its time.
  Future<void> confirmReading(WidgetTester tester) async {
    final button = find.text(confirm);
    await tester.scrollUntilVisible(
      button,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(button);
    await wait(tester, 300);
    await tester.tap(button);
    await wait(tester, 900);
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
      expect(find.text('ابدأ برسالة اليوم'), findsOneWidget);
      expect(find.text('٠ / ٣'), findsOneWidget);
      expect(find.byIcon(Icons.ios_share_rounded), findsNothing);

      await tester.ensureVisible(find.text('خطوات اليوم'));
      await wait(tester, 300);
      await tester.tap(find.text('خطوات اليوم'));
      await until(tester, () => shows(find.text(JourneyCopy.stepsHowToCount)));
      expect(find.text(JourneyCopy.stepsHowToCount), findsOneWidget);
      expect(find.text('اقرأ رسالة اليوم'), findsOneWidget);
      expect(find.text('اقرأ حديث «الأعمال بالنيات»'), findsOneWidget);
      expect(find.text('اكتب رسالتك'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
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
      // Until it is there, not a fixed time: a busy machine's first frames
      // can take seconds.
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while (find.byType(HadithDetailScreen).evaluate().isEmpty &&
          DateTime.now().isBefore(deadline)) {
        await wait(tester, 200);
      }

      final opened =
          tester.widget<HadithDetailScreen>(find.byType(HadithDetailScreen));
      expect(opened.hadith.number, 7);
    });

    testWidgets("sees a leaf in the ring, which opens the day's steps",
        (tester) async {
      await tester.pumpWidget(app(const HomeScreen()));
      await wait(tester);

      expect(find.byType(JourneyRing), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(JourneyRing),
          matching: find.byIcon(Icons.eco_rounded),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byType(JourneyRing));
      await until(tester, () => shows(find.text(JourneyCopy.stepsHowToCount)));
      expect(find.byType(TodayStepsScreen), findsOneWidget);
      expect(find.text(JourneyCopy.stepsHowToCount), findsOneWidget);

      Navigator.of(tester.element(find.byType(TodayStepsScreen))).pop();
      await until(tester, () => !shows(find.byType(TodayStepsScreen)));
      expect(find.byType(TodayStepsScreen), findsNothing);
    });

    testWidgets('the ring counts the steps, one to three', (tester) async {
      await tester.pumpWidget(app(const HomeScreen()));
      await wait(tester);
      Finder ringSays(String digit) => find.descendant(
            of: find.byType(JourneyRing),
            matching: find.text(digit),
          );

      journey.recordMessageRead('m', hadithNumber: 1);
      await wait(tester, 900);
      expect(ringSays('١'), findsOneWidget);

      finished([1]);
      await wait(tester, 900);
      expect(ringSays('٢'), findsOneWidget);

      journey.recordWrote();
      await wait(tester, 900);
      expect(ringSays('٣'), findsOneWidget);

      await tester.tap(find.byType(JourneyRing));
      await until(tester, () => shows(find.text(JourneyCopy.stepsAllDone)));
      expect(find.text(JourneyCopy.stepsAllDone), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));
    });

    testWidgets('a hadith opened from the steps comes back to them',
        (tester) async {
      await openSteps(tester);
      await tester.tap(find.text('اقرأ حديث «الأعمال بالنيات»'));
      await until(tester, () => shows(find.byType(HadithDetailScreen)));
      expect(find.byType(HadithDetailScreen), findsOneWidget);

      Navigator.of(tester.element(find.byType(HadithDetailScreen))).pop();
      await until(tester, () => !shows(find.byType(HadithDetailScreen)));
      expect(find.byType(TodayStepsScreen), findsOneWidget);
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

      // Pressed too early, the confirmation does nothing.
      await tester.scrollUntilVisible(
        find.text(confirm),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(confirm), warnIfMissed: false);
      await wait(tester, 300);
      expect(journey.data.progressOf(11).isComplete, isFalse,
          reason: 'the reader\'s word alone is not enough');

      // Reading the page: the hadith, then its short explanation.
      final pageTime = ReadingRule.neededForSections(
        ReadingRule.pageSections(hadith),
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
      // At the top first, as a reader starts; down to the summary only once
      // the hadith has had its time, so it is not scrolled away unread.
      final started = DateTime.now();
      final deadline = started.add(pageTime * 3);
      var scrolledDown = false;
      while (journey.data.progressOf(11).textOn == null &&
          DateTime.now().isBefore(deadline)) {
        await wait(tester, 1000);
        if (!scrolledDown &&
            DateTime.now().isAfter(started.add(pageTime * 1.2)) &&
            find.text(hadith.shortExplanation).evaluate().isNotEmpty) {
          scrolledDown = true;
          await tester.ensureVisible(find.text(hadith.shortExplanation));
        }
      }
      expect(journey.data.progressOf(11).textOn, isNotNull,
          reason: 'the time spent turns the leaf green');
      expect(journey.data.progressOf(11).isComplete, isFalse,
          reason: 'the time alone is not enough either');

      await confirmReading(tester);

      expect(find.text('اكتمل حديث «${hadith.title}»'), findsOneWidget);
      expect(find.text('١ من ٤٢ حديثاً'), findsOneWidget);
      expect(find.text('سجّل الدخول لتبقى شجرتك معك'), findsOneWidget);
      expect(journey.data.progressOf(11).isComplete, isTrue);
      expect(journey.data.days[journey.today]!.seconds, greaterThan(0));
      expect(journey.streak.current, 1);
    });

    testWidgets('an ordinary hadith offers neither the next one nor sharing',
        (tester) async {
      await openJourney(tester, accessible: true);
      await tapLeaf(tester, 12);
      await confirmReading(tester);

      expect(find.text('اكتب رسالة من هذا الحديث'), findsOneWidget);
      expect(find.text('الحديث التالي'), findsNothing);
      expect(find.text('مشاركة'), findsNothing);
    });

    testWidgets('the sheet leads on to writing about that hadith',
        (tester) async {
      await openJourney(tester, accessible: true);
      await tapLeaf(tester, 12);
      await confirmReading(tester);

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
      await openSteps(tester);

      expect(find.text('أتممت حديث اليوم'), findsOneWidget);
      expect(find.textContaining('التالي'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.text(JourneyCopy.stepsDayCounted), findsOneWidget);
    });

    testWidgets('the writing step opens with the hadith just read',
        (tester) async {
      finished([7]);
      await openSteps(tester);

      await tester.tap(find.text('اكتب رسالتك'));
      await wait(tester, 1000);

      expect(find.text('شارك رسالتك'), findsOneWidget);
      expect(find.textContaining(hadiths.getByNumber(7)!.title), findsWidgets);
    });
  });

  group('milestones', () {
    Future<void> finishLast(WidgetTester tester, int number) async {
      await openJourney(tester, accessible: true);
      await tapLeaf(tester, number);
      await confirmReading(tester);
    }

    testWidgets('the fifth hadith gets its message', (tester) async {
      finished([1, 2, 3, 4]);
      await finishLast(tester, 5);
      expect(find.text('🌱 بداية جميلة!'), findsOneWidget);
      expect(find.text('مشاركة'), findsOneWidget);
      expect(find.text('الحديث التالي'), findsNothing);
    });

    testWidgets('the tenth gets its message', (tester) async {
      finished([for (var n = 1; n <= 9; n++) n]);
      await finishLast(tester, 10);
      expect(find.text('🌿 خطواتك تصنع أثراً!'), findsOneWidget);
    });

    testWidgets('the last hadith ends the Forty, with nothing after it',
        (tester) async {
      finished([for (var n = 1; n <= 41; n++) n]);
      await finishLast(tester, 42);

      expect(find.text('✨ أتممت الرحلة!'), findsOneWidget);
      expect(find.text('٤٢ من ٤٢ حديثاً'), findsOneWidget);
      expect(find.text('الحديث التالي'), findsNothing);
      expect(journey.nextHadithNumber, isNull);
    });

    testWidgets('a milestone does not repeat on a re-read', (tester) async {
      finished([1, 2, 3, 4, 5]);
      await finishLast(tester, 5);
      expect(find.text('🌱 بداية جميلة!'), findsNothing);
      expect(find.text('أتممت قراءته مرة أخرى'), findsOneWidget);
      expect(find.text('مشاركة'), findsNothing);
    });
  });

  group('sharing', () {
    testWidgets('a milestone can be previewed in both shapes and copied',
        (tester) async {
      // Sharing is offered only at a milestone, so this reads the fifth.
      finished([1, 2, 3, 4]);
      await openJourney(tester, accessible: true);
      await tapLeaf(tester, 5);
      await confirmReading(tester);

      await tester.tap(find.text('مشاركة'));
      await wait(tester, 900);

      expect(find.byType(MilestonePoster), findsOneWidget);
      expect(
        tester.widget<MilestonePoster>(find.byType(MilestonePoster)).format,
        PosterFormat.feed,
      );
      expect(find.text('إظهار اسمي'), findsNothing,
          reason: 'a guest has no name to show');

      await tester.tap(find.text('حالة'));
      await wait(tester, 400);
      expect(
        tester.widget<MilestonePoster>(find.byType(MilestonePoster)).format,
        PosterFormat.story,
      );

      await tester.tap(find.text('نسخ النص'));
      await wait(tester);
      expect(
          copied, startsWith('🌱 بداية جميلة!\nأتممت قراءة أول خمسة أحاديث!'));
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
      await wait(tester);
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
      await wait(tester);
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

      // Before any record, one line rather than eight dashes.
      await scrollTo(tester, find.textContaining('أرقامك تظهر هنا'));
      expect(find.text('أرقامك'), findsOneWidget);
      expect(find.text(JourneyRecord.weekWrote.label), findsNothing);
    });

    testWidgets('records are tiles once there are any', (tester) async {
      finished([1]);
      await openJourney(tester);

      await scrollTo(tester, find.text(JourneyRecord.weekWrote.label));
      for (final record in JourneyRecord.values) {
        expect(find.text(record.label), findsOneWidget);
      }
      expect(find.text('—'), findsWidgets, reason: 'records not yet set');
      expect(find.textContaining('أرقامك تظهر هنا'), findsNothing);
    });

    testWidgets('a key under the tree says what each leaf means',
        (tester) async {
      finished([1, 2]);
      journey.learnPart(1, totalParts: 1);
      await openJourney(tester);

      // Three kinds of leaf: 1 is memorized, 2 is read, the rest are not.
      for (final label in ['قرأته', 'لم يُقرأ بعد', 'في حفظك']) {
        expect(find.text(label), findsOneWidget, reason: label);
        expect(
          find.descendant(
            of: find
                .ancestor(of: find.text(label), matching: find.byType(Row))
                .first,
            matching: find.byType(LeafSwatch),
          ),
          findsOneWidget,
          reason: 'a leaf beside «$label»',
        );
      }
    });

    testWidgets('the key shows only the leaves the tree has', (tester) async {
      await openJourney(tester);

      expect(find.text('لم يُقرأ بعد'), findsOneWidget);
      expect(find.text('قرأته'), findsNothing);
      expect(find.text('في حفظك'), findsNothing);
    });

    testWidgets('the day\'s next step is the one picked out', (tester) async {
      journey.recordMessageRead('m', hadithNumber: 1);
      await openJourney(tester);

      await scrollTo(tester, find.text('خطوات اليوم'));
      expect(find.text('١ / ٣'), findsOneWidget);
      expect(find.text('بقيت خطوتان'), findsOneWidget);
      await openSteps(tester);
      // The message is done: no chevron on it, one on each step to do.
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('اقرأ رسالة اليوم'),
            matching: find.byType(Row),
          ),
          matching: find.byIcon(Icons.chevron_left_rounded),
        ),
        findsNothing,
      );
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
      await until(tester, () => copied != null);
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
      await wait(tester);
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
      await confirmReading(tester);

      final shown = [
        for (final record in JourneyRecord.values)
          if (find.text(record.brokenLine).evaluate().isNotEmpty) record,
      ];
      expect(shown, hasLength(1));
      expect(shown.single, isNot(JourneyRecord.streak));
    });
  });

  group('the weekly board', () {
    final board = WeeklyBoardService();
    late InMemoryBoardStore boardStore;

    setUp(() async {
      boardStore = InMemoryBoardStore();
      await board.debugReset(
        store: boardStore,
        displayName: () => 'سارة',
        settle: const Duration(milliseconds: 50),
      );
      board.start();
    });

    tearDown(board.debugReset);

    Future<void> openBoard(WidgetTester tester) async {
      await tester.pumpWidget(
        app(const WeeklyBoardScreen(displayName: 'سارة')),
      );
      await wait(tester, 900);
    }

    testWidgets('the journey leads to it, and says when none is published',
        (tester) async {
      await openJourney(tester);
      await tester.scrollUntilVisible(
        find.text('لوحة الأسبوع'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await wait(tester, 300);
      await tester.tap(find.text('لوحة الأسبوع'));
      await wait(tester, 1200);

      expect(find.byType(WeeklyBoardScreen), findsOneWidget);
      expect(find.text(JourneyCopy.boardNotYet), findsOneWidget);
      expect(find.text(JourneyCopy.boardSignInReason), findsOneWidget,
          reason: 'a guest is asked to sign in, not shown a switch');
      expect(find.byType(Switch), findsNothing);
    });

    testWidgets('a published board shows both lists', (tester) async {
      boardStore.board = WeeklyBoard(
        week: boardWeekOf('2026-11-07'),
        points: const [
          BoardRow(name: 'فاعل خير', value: 345),
          BoardRow(name: 'نور', value: 300),
        ],
        sharing: const [BoardRow(name: 'نور', value: 2)],
      );
      await openBoard(tester);

      expect(find.text('أسبوع ٧ – ١٣ نوفمبر'), findsOneWidget);
      expect(find.text('٣٤٥'), findsOneWidget);
      expect(find.text('فاعل خير'), findsOneWidget);

      await tester.tap(find.text('المشاركة'));
      await wait(tester, 400);
      expect(find.text('رسالتان'), findsOneWidget);
      expect(find.text('٣٤٥'), findsNothing);
    });

    testWidgets('the reader joins, picks a name, and leaves', (tester) async {
      journey.setUser('reader-a');
      await wait(tester, 300);
      await openBoard(tester);

      expect(find.text(JourneyCopy.boardOff), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

      await tester.tap(find.byType(Switch));
      await wait(tester, 400);
      expect(board.membership.value?.name, kAnonymousName,
          reason: 'on, but anonymous until the reader picks their name');
      expect(find.text(JourneyCopy.boardOn), findsOneWidget);
      expect(boardStore.scores['reader-a']?.name, kAnonymousName);

      await tester.tap(find.text('باسمي: سارة'));
      await wait(tester, 400);
      expect(boardStore.scores['reader-a']?.name, 'سارة');

      await tester.tap(find.byType(Switch));
      await wait(tester, 400);
      expect(boardStore.scores, isEmpty);
      expect(find.text(JourneyCopy.boardOff), findsOneWidget);
    });

    testWidgets('the reader sees their own points, never a rank',
        (tester) async {
      finished([1, 2]);
      await openBoard(tester);

      expect(find.text('نقاطك هذا الأسبوع'), findsOneWidget);
      expect(find.text('٢٠'), findsOneWidget);
      expect(find.textContaining('مركز'), findsNothing);
    });
  });

  group('memorizing', () {
    /// Taps [label], bringing it on screen first.
    Future<void> press(WidgetTester tester, String label) async {
      final target = find.text(label).last;
      await tester.ensureVisible(target);
      await wait(tester, 200);
      await tester.tap(target);
      await wait(tester);
    }

    Finder blanks() => find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == 'كلمة مخفية، المس لإظهارها',
        );

    Future<void> throughReading(WidgetTester tester) async {
      for (var i = 0; i < 40; i++) {
        if (find.text('أخفِ بعض الكلمات').evaluate().isNotEmpty) break;
        await press(tester, 'الجملة التالية');
      }
      await press(tester, 'أخفِ بعض الكلمات');
    }

    testWidgets('a short hadith is learned in three steps', (tester) async {
      finished([13]);
      final hadith = hadiths.getByNumber(13)!;
      await tester.pumpWidget(app(MemorizeScreen(hadith: hadith)));
      await wait(tester);

      expect(find.text('اقرأ'), findsOneWidget);
      expect(find.textContaining('أَنَسِ بْنِ مَالِكٍ'), findsOneWidget,
          reason: 'the narrator is read first');
      await throughReading(tester);
      expect(blanks(), findsWidgets, reason: 'one word in three hidden');
      await press(tester, 'أخفِ أكثر');
      await press(tester, 'سمّعه كاملاً');
      expect(find.text('حفظته'), findsNothing,
          reason: 'the text is shown before the reader answers');
      await press(tester, 'أظهر النص');
      expect(find.text('رواه'), findsOneWidget,
          reason: 'the source is recited with it');
      expect(find.text('البخاري'), findsOneWidget);
      await press(tester, 'حفظته');
      await wait(tester, 600);

      expect(find.text('أول حديث في حفظك'), findsOneWidget);
      await press(tester, 'تم');
      await wait(tester, 600);
      expect(journey.data.memoOf(13).isMemorized, isTrue);
      expect(journey.data.memoOf(13).due, dayKeyPlus(journey.today, 1));
    });

    testWidgets('a hidden word comes back when touched', (tester) async {
      finished([1]);
      await tester.pumpWidget(
        app(MemorizeScreen(hadith: hadiths.getByNumber(1)!)),
      );
      await wait(tester);
      await throughReading(tester);

      final before = blanks().evaluate().length;
      await tester.tap(blanks().first);
      await wait(tester, 300);
      expect(blanks().evaluate().length, before - 1);
    });

    testWidgets('«ليس بعد» goes back a step and records nothing',
        (tester) async {
      finished([13]);
      await tester.pumpWidget(
        app(MemorizeScreen(hadith: hadiths.getByNumber(13)!)),
      );
      await wait(tester);
      await throughReading(tester);
      await press(tester, 'أخفِ أكثر');
      await press(tester, 'سمّعه كاملاً');
      await press(tester, 'أظهر النص');
      await press(tester, 'ليس بعد');

      expect(find.text('أخفِ أكثر'), findsOneWidget);
      expect(journey.data.memo, isEmpty);
    });

    testWidgets('a long hadith is one part a session', (tester) async {
      finished([2]);
      await tester.pumpWidget(
        app(MemorizeScreen(hadith: hadiths.getByNumber(2)!)),
      );
      await wait(tester);

      expect(find.text('الجزء ١ من ٣'), findsOneWidget);
      expect(find.textContaining('عُمَرَ بن الخطاب'), findsOneWidget,
          reason: 'the narrator opens the first part');
      await throughReading(tester);
      await press(tester, 'أخفِ أكثر');
      await press(tester, 'سمّعه كاملاً');
      await press(tester, 'أظهر النص');
      expect(find.text('رواه'), findsNothing,
          reason: 'the source closes the last part, not the first');
      await press(tester, 'حفظته');
      await wait(tester, 600);

      expect(find.text('حفظت الجزء ١ من ٣'), findsOneWidget);
      expect(journey.data.memoOf(2).isLearning, isTrue);
      expect(journey.data.memoOf(2).parts, 1);
    });

    testWidgets('a due review is recorded, and says when the next one is',
        (tester) async {
      var now = DateTime(2026, 11, 7, 12);
      await journey.debugReset(store: store, clock: () => now);
      journey.learnPart(13, totalParts: 1);
      now = DateTime(2026, 11, 8, 12);

      await tester.pumpWidget(
        app(ReviewScreen(hadith: hadiths.getByNumber(13)!)),
      );
      await wait(tester);
      expect(find.textContaining('مراجعة حرة'), findsNothing);
      await press(tester, 'أظهر النص');
      await press(tester, 'تذكرته');

      expect(
        find.text(JourneyCopy.reviewed(remembered: true, days: 3)),
        findsOneWidget,
      );
      expect(journey.data.memoOf(13).box, 1);
    });

    testWidgets('an early review is practice', (tester) async {
      journey.learnPart(13, totalParts: 1);
      await tester.pumpWidget(
        app(ReviewScreen(hadith: hadiths.getByNumber(13)!)),
      );
      await wait(tester);

      expect(find.text('ليست مستحقة اليوم، فهذه مراجعة حرة'), findsOneWidget);
      await press(tester, 'أظهر النص');
      await press(tester, 'نسيت بعضه');
      expect(find.textContaining('مراجعة حرة، لم تُسجَّل'), findsOneWidget);
      expect(journey.data.memoOf(13).misses, 0);
    });

    testWidgets('a read hadith offers to be memorized from its page',
        (tester) async {
      finished([13]);
      await tester.pumpWidget(
        app(HadithDetailScreen(hadith: hadiths.getByNumber(13)!)),
      );
      await wait(tester);

      await tester.scrollUntilVisible(
        find.text('احفظ هذا الحديث'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('يُحفظ في جلسة واحدة.'), findsOneWidget);
      await press(tester, 'احفظ هذا الحديث');
      await wait(tester, 600);
      expect(find.byType(MemorizeScreen), findsOneWidget);
    });

    testWidgets('an unread hadith does not offer it yet', (tester) async {
      await tester.pumpWidget(
        app(HadithDetailScreen(hadith: hadiths.getByNumber(14)!)),
      );
      await wait(tester);
      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -3000),
      );
      await wait(tester, 300);
      expect(find.text('احفظ هذا الحديث'), findsNothing);
    });

    testWidgets('the completion sheet offers to memorize what was just read',
        (tester) async {
      await openJourney(tester, accessible: true);
      await tapLeaf(tester, 12);
      await confirmReading(tester);

      await press(tester, 'احفظ هذا الحديث');
      await wait(tester, 800);
      expect(find.byType(MemorizeScreen), findsOneWidget);
    });

    testWidgets('the journey suggests where to start, then what is due',
        (tester) async {
      var now = DateTime(2026, 11, 7, 12);
      await journey.debugReset(store: store, clock: () => now);
      finished([2, 13]);
      await openJourney(tester);

      final shortest = hadiths.getByNumber(13)!.title;
      await tester.scrollUntilVisible(
        find.text('ابدأ بحفظ «$shortest»'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      // The page it opens starts from the same hadith.
      // Clear of the floating tab bar before tapping.
      await Scrollable.ensureVisible(
        tester.element(find.byType(MemoEntry)),
        alignment: .4,
      );
      await wait(tester, 400);
      await tester.tap(find.text('ابدأ بحفظ «$shortest»'));
      await wait(tester, 800);
      expect(find.text('لم تحفظ حديثاً بعد'), findsOneWidget);
      expect(find.text(shortest), findsOneWidget);
      expect(find.text('ابدأ حفظه'), findsOneWidget);
      Navigator.of(tester.element(find.byType(MemoListScreen))).pop();
      await wait(tester, 800);

      journey.learnPart(13, totalParts: 1);
      now = DateTime(2026, 11, 8, 12);
      journey.recordMessageRead('m', hadithNumber: 1);
      await wait(tester, 600);
      await tester.scrollUntilVisible(
        find.text('موعد مراجعة «$shortest» اليوم'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('في حفظك ١'), findsWidgets);

      // Today's review on top; once done, its card says so.
      await Scrollable.ensureVisible(
        tester.element(find.byType(MemoEntry)),
        alignment: .4,
      );
      await wait(tester, 400);
      await tester.tap(find.text('موعد مراجعة «$shortest» اليوم'));
      await wait(tester, 800);
      expect(find.text('مراجعة اليوم'), findsOneWidget);
      expect(find.text('راجعه الآن'), findsOneWidget);
      expect(find.text('كل ما تحفظه (١)'), findsOneWidget);
      journey.review(13, remembered: true);
      await wait(tester, 800);
      expect(find.text('راجعه الآن'), findsNothing);
      expect(find.text('أتممت مراجعة اليوم.'), findsOneWidget);
      expect(find.textContaining('راجعته اليوم. نعود إليه'), findsOneWidget);
      Navigator.of(tester.element(find.byType(MemoListScreen))).pop();
      await wait(tester, 800);

      // Back up to the tree, which the list let go of further down.
      await tester.scrollUntilVisible(
        find.byType(JourneyTree),
        -200,
        scrollable: find.byType(Scrollable).last,
      );
      final painter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((p) => p.painter)
          .whereType<JourneyTreePainter>()
          .single;
      expect(painter.memorized, {13}, reason: 'its leaf has the dot');
    });

    testWidgets('a review reminder opens that review', (tester) async {
      journey.learnPart(13, totalParts: 1);
      await tester.pumpWidget(app(const HomeScreen()));
      await wait(tester);

      NotificationScheduler.hadithTapped.value =
          HadithReminderTap(13, review: true);
      await wait(tester, 1500);

      final opened = tester.widget<ReviewScreen>(find.byType(ReviewScreen));
      expect(opened.hadith.number, 13);
    });

    testWidgets('the board\'s memorization list shows names, no numbers',
        (tester) async {
      final boardStore = InMemoryBoardStore()
        ..board = WeeklyBoard(
          week: boardWeekOf('2026-11-07'),
          points: const [BoardRow(name: 'سارة', value: 300)],
          sharing: const [],
          memo: const [
            BoardRow(name: 'نور', value: 0),
            BoardRow(name: 'فاعل خير', value: 0),
          ],
        );
      await WeeklyBoardService().debugReset(
        store: boardStore,
        displayName: () => null,
      );
      addTearDown(() => WeeklyBoardService().debugReset());
      await tester.pumpWidget(app(const WeeklyBoardScreen(displayName: '')));
      await wait(tester, 900);

      await tester.tap(find.text('الحفظ'));
      await wait(tester, 400);
      expect(find.text('نور'), findsOneWidget);
      expect(find.text('فاعل خير'), findsOneWidget);
      // A rank and a name, and nothing after it.
      Finder row(String label) => find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == label,
          );
      expect(row('١، نور'), findsOneWidget);
      expect(row('٢، فاعل خير'), findsOneWidget);
      expect(find.textContaining('بلا أعداد'), findsOneWidget);
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

    testWidgets('a finished hadith can be read and confirmed again',
        (tester) async {
      finished([16]);
      await tester.pumpWidget(
        app(
          HadithDetailScreen(hadith: hadiths.getByNumber(16)!),
          accessible: true,
        ),
      );
      await wait(tester);

      await confirmReading(tester);
      expect(find.text('أتممت قراءته مرة أخرى'), findsOneWidget);
      expect(journey.data.progressOf(16).reads, 2);
    });

    testWidgets('the full explanation is one tap away, and optional',
        (tester) async {
      await tester.pumpWidget(
        app(HadithDetailScreen(hadith: hadiths.getByNumber(16)!)),
      );
      await wait(tester);

      final teaser = find.text('قراءة الشرح كاملاً');
      await tester.scrollUntilVisible(
        teaser,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await wait(tester, 200);
      await tester.tap(teaser.last);
      await wait(tester, 800);

      expect(find.byType(HadithExplanationScreen), findsOneWidget);
      expect(find.text(confirm), findsNothing);
      expect(journey.data.progressOf(16).isComplete, isFalse);
    });

    testWidgets('favourites are a tap away and the tree comes back',
        (tester) async {
      await openJourney(tester);

      await tester.tap(find.text('المفضلة'));
      await wait(tester);
      expect(find.byType(FavoritesScreen), findsOneWidget);

      await tester.tap(
        find
            .descendant(
              of: find.byType(JourneyScreen),
              matching: find.text('رحلتي'),
            )
            .at(1),
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
      expect(find.text('٨ أيام'), findsWidgets,
          reason: 'a figure says its unit');
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

      testWidgets('the whole tree fits, and its leaves open: ${size.key}',
          (tester) async {
        await tester.pumpWidget(app(const HomeScreen(), size: size.value));
        await wait(tester);
        await tester.tap(tab('رحلتي'));
        await wait(tester);

        final tree = tester.getRect(find.byType(JourneyTree));
        final screen = tester.getRect(find.byType(HomeScreen));
        expect(tree.left, greaterThanOrEqualTo(screen.left));
        expect(tree.right, lessThanOrEqualTo(screen.right));
        expect(tree.bottom, lessThan(screen.bottom),
            reason: 'on the first screen');
        expect(tree.width, greaterThan(size.value.width * .78),
            reason: 'the tree takes nearly the whole width');

        // The first leaf, the top of the count and the last: the right, the
        // top and the left of the tree.
        for (final number in [1, 22, 42]) {
          await tapLeaf(tester, number);
          expect(
            find.text(hadiths.getByNumber(number)!.title),
            findsOneWidget,
            reason: 'leaf $number at ${size.key}',
          );
          Navigator.of(tester.element(find.byType(HadithDetailScreen))).pop();
          await wait(tester, 700);
        }
      });
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
        endsWith('قرأته'),
      );
      expect(
        labels.where((l) => l.startsWith('الحديث ٢:')).single,
        endsWith('لم يُقرأ بعد'),
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
