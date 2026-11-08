import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/core/legal/legal_documents.dart';
import 'package:hadith_app/core/share/share_card.dart';
import 'package:hadith_app/core/share/share_service.dart';
import 'package:hadith_app/core/share/share_sheet.dart';
import 'package:hadith_app/core/theme/app_state_controller.dart';
import 'package:hadith_app/core/theme/app_theme.dart';
import 'package:hadith_app/core/widgets/bottom_navigation.dart';
import 'package:hadith_app/data/journey/journey_repository.dart';
import 'package:hadith_app/data/journey/journey_store.dart';
import 'package:hadith_app/data/journey/reading_tracker.dart';
import 'package:hadith_app/data/models/insight.dart';
import 'package:hadith_app/data/repositories/hadith_repository.dart';
import 'package:hadith_app/data/services/favorites_store.dart';
import 'package:hadith_app/features/favorites/favorites_screen.dart';
import 'package:hadith_app/features/hadith/hadith_detail_screen.dart';
import 'package:hadith_app/features/hadith/hadith_explanation_screen.dart';
import 'package:hadith_app/features/hadith/hadith_list_screen.dart';
import 'package:hadith_app/features/home/home_screen.dart';
import 'package:hadith_app/features/journey/journey_links.dart';
import 'package:hadith_app/features/messages/daily_message_card.dart';
import 'package:hadith_app/features/messages/daily_message_screen.dart';
import 'package:hadith_app/features/profile/settings_drawer.dart';
import 'package:hadith_app/features/share/add_message_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Everything the app did before the reading journey, checked after it.
///
/// Runs from both entry points. [onDevice] only decides two things: the
/// checks that read files from the repository need the host, and the real
/// render of a [ShareCard] needs a real GPU.
void regressionSuite({
  required bool onDevice,
  required Future<void> Function() initFirebase,
}) {
  Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: child,
      );

  Future<void> settle(WidgetTester tester, [int frames = 8]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  final tabBar = find.byType(BottomNavigation);
  Finder tab(String label) =>
      find.descendant(of: tabBar, matching: find.text(label));

  String? copied;

  setUpAll(() async {
    await initFirebase();
    SharedPreferences.setMockInitialValues({});
    await HadithRepository().load();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await JourneyRepository().debugReset(store: InMemoryJourneyStore());
    HadithRepository().debugOverrideFavorites(
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

  group('content', () {
    test('all 42 hadiths load, each with everything a screen needs', () {
      final hadiths = HadithRepository().hadiths;
      expect(hadiths, hasLength(42));
      expect(
        hadiths.map((h) => h.number),
        List.generate(42, (i) => i + 1),
      );
      for (final hadith in hadiths) {
        expect(hadith.title, isNotEmpty, reason: 'title of ${hadith.number}');
        expect(hadith.text, isNotEmpty, reason: 'text of ${hadith.number}');
        expect(hadith.shortExplanation, isNotEmpty);
        expect(hadith.explanation, isNotEmpty);
      }
    });

    test("Nawawi's introduction and biography still load", () {
      expect(HadithRepository().introSections, hasLength(2));
    });

    test('a guest starts with no favourites, and cannot add one', () {
      final repo = HadithRepository();
      expect(repo.getFavoriteHadiths(), isEmpty);
      expect(() => repo.toggleFavoriteHadith(1), throwsStateError);
    });

    test('favourites still belong to the account', () async {
      final repo = HadithRepository();
      final store = InMemoryFavoritesStore();
      repo.debugOverrideFavorites(store: store, currentUid: () => 'a');
      repo.toggleFavoriteHadith(5);
      await pumpEventQueue();
      expect(repo.isHadithFavorite(5), isTrue);

      repo.debugOverrideFavorites(store: store, currentUid: () => 'b');
      await pumpEventQueue();
      expect(repo.isHadithFavorite(5), isFalse);
    });

    test('app settings keep working', () {
      final state = AppStateController();
      final before = state.fontSizeScale;
      state.setFontSizeScale(1.15);
      expect(state.fontSizeLabel, 'متوسط');
      state.setFontSizeScale(before);
    });
  });

  group('home shell', () {
    testWidgets('keeps four tabs in the same order', (tester) async {
      await tester.pumpWidget(wrap(const HomeScreen()));
      await settle(tester);

      for (final label in ['الرئيسية', 'رحلتي', 'المجتمع', 'شارك رسالة']) {
        expect(tab(label), findsOneWidget, reason: label);
      }
      final xs = ['الرئيسية', 'رحلتي', 'المجتمع', 'شارك رسالة']
          .map((label) => tester.getCenter(tab(label)).dx)
          .toList();
      expect(xs, xs.toList()..sort((a, b) => b.compareTo(a)),
          reason: 'first tab on the right, in RTL');
    });

    testWidgets('the emblem and the Forty pill are still on Home',
        (tester) async {
      await tester.pumpWidget(wrap(const HomeScreen()));
      await settle(tester);

      expect(find.text('طيّب قلبك'), findsWidgets);
      await tester.tap(find.text('الأربعين النووية'));
      await settle(tester, 12);
      expect(find.byType(HadithListScreen), findsOneWidget);
    });

    testWidgets('every tab still opens its screen', (tester) async {
      await tester.pumpWidget(wrap(const HomeScreen()));
      await settle(tester);

      await tester.tap(tab('شارك رسالة'));
      await settle(tester);
      expect(find.text('شارك رسالتك'), findsOneWidget);

      await tester.tap(tab('المجتمع'));
      await settle(tester);
      expect(find.text('مجتمع الحديث'), findsWidgets);

      await tester.tap(tab('الرئيسية'));
      await settle(tester);
      expect(find.text('الأربعين النووية'), findsOneWidget);
    });

    testWidgets('the settings drawer still opens from Home', (tester) async {
      await tester.pumpWidget(wrap(const HomeScreen()));
      await settle(tester);

      await tester.tap(find.byIcon(Icons.menu_rounded).first);
      await settle(tester, 10);
      expect(find.byType(SettingsDrawer), findsOneWidget);
    });
  });

  group('favourites after the move', () {
    testWidgets('are one tap inside رحلتي', (tester) async {
      await tester.pumpWidget(wrap(const HomeScreen()));
      await settle(tester);

      await tester.tap(tab('رحلتي'));
      await settle(tester);
      await tester.tap(find.text('المفضلة'));
      await settle(tester);

      expect(find.byType(FavoritesScreen), findsOneWidget);
      expect(find.text('المفضلة والمحفوظات'), findsNothing,
          reason: 'the journey tab supplies the header');
    });

    testWidgets('still bring their own header on their own', (tester) async {
      await tester.pumpWidget(wrap(const Scaffold(body: FavoritesScreen())));
      await settle(tester);
      expect(find.text('المفضلة والمحفوظات'), findsOneWidget);
    });
  });

  group('reading', () {
    testWidgets('the list shows the hadiths and search narrows them',
        (tester) async {
      await tester.pumpWidget(wrap(const HadithListScreen()));
      await settle(tester, 12);
      expect(find.text('الأعمال بالنيات'), findsWidgets);

      await tester.enterText(find.byType(TextField).first, 'لا تغضب');
      await settle(tester, 6);
      expect(find.text('لا تغضب'), findsWidgets);
      expect(find.text('الأعمال بالنيات'), findsNothing);
    });

    testWidgets('a hadith page shows its text, summary and explanation',
        (tester) async {
      final hadith = HadithRepository().getByNumber(16)!;
      await tester.pumpWidget(wrap(HadithDetailScreen(hadith: hadith)));
      await settle(tester, 12);

      expect(find.text(hadith.title), findsOneWidget);
      expect(find.text(hadith.text), findsOneWidget);
      expect(find.text('خلاصة الشرح'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('قراءة الشرح كاملاً'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('قراءة الشرح كاملاً'), findsWidgets);
    });

    testWidgets('bookmarking asks a guest to sign in', (tester) async {
      final hadith = HadithRepository().getByNumber(16)!;
      await tester.pumpWidget(wrap(HadithDetailScreen(hadith: hadith)));
      await settle(tester);

      await tester.tap(find.byIcon(Icons.bookmark_border_rounded));
      await settle(tester, 10);
      expect(find.text('يحتاج هذا إلى حساب'), findsOneWidget);
    });

    testWidgets('copying a hadith still copies its full text', (tester) async {
      final hadith = HadithRepository().getByNumber(16)!;
      await tester.pumpWidget(wrap(HadithDetailScreen(hadith: hadith)));
      await settle(tester);

      await tester.tap(find.byIcon(Icons.copy_rounded));
      await settle(tester, 4);
      expect(copied, contains(hadith.title));
      expect(copied, contains(hadith.text));
      expect(copied, contains(hadith.explanation));
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('the teaser still opens the full explanation', (tester) async {
      final hadith = HadithRepository().getByNumber(16)!;
      await tester.pumpWidget(wrap(HadithDetailScreen(hadith: hadith)));
      await settle(tester);

      final teaser = find.text('قراءة الشرح كاملاً');
      await tester.scrollUntilVisible(
        teaser,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await settle(tester, 3);
      await tester.tap(teaser.last);
      await settle(tester, 12);
      expect(find.byType(HadithExplanationScreen), findsOneWidget);
    });

    testWidgets('no paragraph of any explanation is lost', (tester) async {
      for (final number in [2, 34, 11]) {
        final hadith = HadithRepository().getByNumber(number)!;
        await tester.pumpWidget(
          wrap(HadithExplanationScreen(key: ValueKey(number), hadith: hadith)),
        );
        await settle(tester, 3);
        for (final paragraph in ReadingRule.paragraphs(hadith.explanation)) {
          expect(find.text(paragraph), findsOneWidget);
        }
      }
    });
  });

  group('messages', () {
    const insight = Insight(
      hadithNumber: 16,
      arabic: 'ابدأ يومك بنية طيبة.',
      english: '',
      id: 'msg-regression',
    );
    final entry = DailyMessageEntry(
      insight: insight,
      hadith: HadithRepository().getByNumber(16),
    );

    Widget card(Widget child) =>
        wrap(Scaffold(body: SingleChildScrollView(child: child)));

    testWidgets('a message shows without its trailing full stop',
        (tester) async {
      await tester.pumpWidget(card(DailyMessageCard(entry: entry)));
      await settle(tester);
      expect(find.textContaining('ابدأ يومك بنية طيبة'), findsOneWidget);
      expect(find.textContaining('طيبة.'), findsNothing);
    });

    testWidgets('the footer the home tab passes still shows', (tester) async {
      await tester.pumpWidget(
        card(DailyMessageCard(entry: entry, footer: const Text('رسالة أخرى'))),
      );
      await settle(tester);
      expect(find.text('رسالة أخرى'), findsOneWidget);
    });

    testWidgets('the card still links to its hadith', (tester) async {
      final hadith = HadithRepository().getByNumber(16)!;
      final entry = DailyMessageEntry(insight: insight, hadith: hadith);
      await tester.pumpWidget(card(DailyMessageCard(entry: entry)));
      await settle(tester);

      await tester.tap(find.textContaining(hadith.title).first);
      await settle(tester, 12);
      expect(find.byType(HadithDetailScreen), findsOneWidget);
    });

    testWidgets('a saved message reopened still shows, and counts for nothing',
        (tester) async {
      await tester.pumpWidget(wrap(const DailyMessageScreen(insight: insight)));
      await settle(tester, 12);
      expect(find.textContaining('ابدأ يومك بنية طيبة'), findsOneWidget);

      await tester.pump(DailyMessageCard.readDelay * 2);
      expect(JourneyRepository().todaySteps.message, isFalse);
    });
  });

  group('sharing a message', () {
    testWidgets('the old share sheet still previews and copies',
        (tester) async {
      await tester.pumpWidget(wrap(Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showShareSheet(
              context: context,
              message: 'رسالة للمشاركة',
              hadithTitle: 'لا تغضب',
              hadithNumber: '١٦',
            ),
            child: const Text('افتح'),
          ),
        ),
      )));
      await tester.tap(find.text('افتح'));
      await settle(tester, 12);

      expect(find.byType(ShareCard), findsOneWidget);
      expect(find.text('مشاركة الصورة'), findsOneWidget);

      await tester.tap(find.text('نسخ النص'));
      await settle(tester, 6);
      expect(copied, contains('رسالة للمشاركة'));
      expect(copied, contains('لا تغضب'));
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('a message card still renders at 1080×1350', (tester) async {
      late BuildContext host;
      await tester.pumpWidget(wrap(Builder(
        builder: (context) {
          host = context;
          return const SizedBox.shrink();
        },
      )));

      final bytes = await tester.runAsync(() => ShareService.renderPoster(
            context: host,
            poster: const ShareCard(message: 'رسالة للمشاركة'),
            size: const Size(ShareCard.width, ShareCard.height),
          ));
      expect(bytes, isNotNull);
      expect(bytes!.length, greaterThan(10000));

      // A PNG's first chunk carries its size, big-endian, at byte 16.
      int at(int offset) => ByteData.sublistView(bytes).getUint32(offset);
      expect(at(16), 1080);
      expect(at(20), 1350);
    }, skip: !onDevice);
  });

  group('writing a message', () {
    Widget form() => wrap(const Scaffold(body: AddMessageScreen()));

    testWidgets('a guest is asked to sign in when sending', (tester) async {
      await tester.pumpWidget(form());
      await settle(tester);

      final send = find.text('إرسال الرسالة');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await settle(tester, 10);
      expect(find.text('يحتاج هذا إلى حساب'), findsOneWidget);
    });

    testWidgets('a link from a finished hadith selects that hadith',
        (tester) async {
      final hadith = HadithRepository().getByNumber(16)!;
      await tester.pumpWidget(form());
      await settle(tester);

      JourneyLinks.openWriting(hadith);
      await settle(tester);
      expect(find.textContaining(hadith.title), findsWidgets);
    });
  });

  group('privacy and security', () {
    test('the privacy policy tells readers about their journey', () {
      const policy = LegalDocuments.privacy;
      expect(policy, contains('رحلتك'));
      expect(policy, contains('ورحلتك في القراءة'),
          reason: 'the deletion section has to mention it too');
      expect(policy, isNot(contains('ولا سجل تصفحك.')),
          reason: 'a reading log makes the old sentence untrue');
    });

    if (onDevice) return;

    String read(String path) => File(path).readAsStringSync();

    test('the hosted policy says the same thing as the app', () {
      final page = read('web/privacy-policy.html');
      expect(page, contains('رحلتك'));
      expect(page, contains('سجل تصفحك خارج التطبيق'));
      expect(read('web/delete-account.html'), contains('رحلتك في القراءة'));
    });

    test('deleting an account removes the journey before the profile', () {
      final source = read('lib/data/services/account_deletion_service.dart');
      final journey = source.indexOf("collection('journey')");
      final years = source.indexOf("collection('journeyYears')");
      final favourites = source.indexOf("collection('favorites')");
      final profile = source.indexOf('await _deleteProfileAndUsername(user)');

      expect(journey, greaterThan(favourites));
      expect(years, greaterThan(journey));
      expect(profile, greaterThan(years));
    });

    test('deleting an account removes the weekly board entry too', () {
      final source = read('lib/data/services/account_deletion_service.dart');
      final years = source.indexOf("collection('journeyYears')");
      final scores = source.indexOf("collection('scores').doc(uid).delete()");
      final profile = source.indexOf('await _deleteProfileAndUsername(user)');

      expect(scores, greaterThan(years));
      expect(profile, greaterThan(scores));
    });

    test('the policy says the board is optional and what it publishes', () {
      expect(
          read('web/privacy-policy.html'), contains('لوحة الأسبوع (اختيارية)'));
      expect(
          read('web/delete-account.html'), contains('نقاطك في لوحة الأسبوع'));
    });

    test('the rules keep every older path and still end denying the rest', () {
      final rules = read('firestore.rules');
      for (final path in [
        'match /users/{uid}',
        'match /favorites/{favoriteId}',
        'match /journey/{docId}',
        'match /journeyYears/{year}',
        'match /communityMessages/{messageId}',
        'match /settings/{settingId}',
        'match /notificationMessages/{messageId}',
        'match /scores/{uid}',
        'function validWeeklyBoard()',
      ]) {
        expect(rules, contains(path));
      }
      final last = rules.lastIndexOf('match /{document=**}');
      expect(last, greaterThan(rules.indexOf('match /journeyYears/{year}')));
      expect(rules.substring(last), contains('allow read, write: if false'));
    });

    test('the journey indexes file stays valid JSON', () {
      final indexes =
          jsonDecode(read('firestore.indexes.json')) as Map<String, dynamic>;
      expect(indexes['indexes'], isNotEmpty);
      expect(indexes['fieldOverrides'], hasLength(3));
    });

    test('Play is told about the journey data', () {
      expect(
        read('docs/play-console-answers.md'),
        contains('users/{uid}/journey'),
      );
    });
  });
}
