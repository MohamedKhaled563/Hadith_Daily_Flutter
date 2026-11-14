import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/core/auth/auth_service.dart';
import 'package:hadith_app/core/theme/app_theme.dart';
import 'package:hadith_app/data/journey/board_service.dart';
import 'package:hadith_app/data/journey/journey_engine.dart';
import 'package:hadith_app/data/journey/journey_repository.dart';
import 'package:hadith_app/data/repositories/hadith_repository.dart';
import 'package:hadith_app/data/services/account_deletion_service.dart';
import 'package:hadith_app/data/services/community_service.dart';
import 'package:hadith_app/data/services/submission_approval_watcher.dart';
import 'package:hadith_app/features/dashboard/pending_queue_page.dart';
import 'package:hadith_app/features/dashboard/weekly_board_page.dart';
import 'package:hadith_app/features/hadith/hadith_detail_screen.dart';
import 'package:hadith_app/features/journey/weekly_board_screen.dart';
import 'package:hadith_app/features/memorize/memorize_screen.dart';
import 'package:hadith_app/firebase_options.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/confirm_email.dart';

/// One reader, end to end, through the real screens, the real services,
/// the real firestore.rules and the dashboard's own pages, against the
/// local Firebase emulators — never the live project.
///
///     firebase emulators:exec --only firestore,auth --project demo-journey \
///       "flutter test integration_test/e2e_test.dart -d <device>"
///
/// The steps run in order and build on each other: a guest reads and
/// memorizes, signs up and keeps it, writes a message, a moderator approves
/// it on the dashboard, the approval reaches the reader and counts, the
/// reader joins the weekly board, the moderator publishes it, the reader
/// sees it, reviews the next day, and finally deletes the account, after
/// which nothing of theirs is left.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const host = '10.0.2.2';
  final stamp = DateTime.now().microsecondsSinceEpoch % 1000000;
  final readerEmail = 'e2e-reader-$stamp@example.test';
  final moderatorEmail = 'e2e-moderator-$stamp@example.test';
  const password = 'test-only-password';
  final readerName = 'قارئ $stamp';
  final message = 'رسالة الاختبار $stamp: الإيمان أن تحب لأخيك ما تحب لنفسك';

  final journey = JourneyRepository();
  final board = WeeklyBoardService();
  final hadiths = HadithRepository();
  late FirebaseFirestore db;

  var dayOffset = 0;
  DateTime now() => DateTime.now().add(Duration(days: dayOffset));

  late String readerUid;
  late int readerWeekTotal;
  late String messageId;
  late SubmissionApprovalWatcher watcher;
  final announced = <String>[];

  Widget app(Widget home, {bool accessible = false}) => MaterialApp(
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

  /// Real time passing, with frames.
  Future<void> wait(WidgetTester tester, [int ms = 500]) async {
    final end = DateTime.now().add(Duration(milliseconds: ms));
    while (DateTime.now().isBefore(end)) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
  }

  /// Waits for [condition], checking every half second, up to [seconds].
  Future<void> until(
    WidgetTester tester,
    Future<bool> Function() condition, {
    int seconds = 15,
    required String what,
  }) async {
    final end = DateTime.now().add(Duration(seconds: seconds));
    while (DateTime.now().isBefore(end)) {
      if (await tester.runAsync(condition) ?? false) return;
      await wait(tester);
    }
    fail('timed out waiting for $what');
  }

  Future<void> press(WidgetTester tester, String label) async {
    final target = find.text(label).last;
    await tester.ensureVisible(target);
    await wait(tester, 200);
    await tester.tap(target);
    await wait(tester, 600);
  }

  /// A nested map or list read back from a document, typed.
  Map<String, dynamic> at(Object? map, String key) =>
      ((map! as Map)[key] as Map).cast<String, dynamic>();
  Map<String, dynamic> first(Object? list) =>
      ((list! as List).first as Map).cast<String, dynamic>();

  Future<Map<String, dynamic>?> doc(WidgetTester tester, String path) async =>
      (await tester.runAsync(() => db.doc(path).get()))?.data();

  /// The emulator's own admin access, which skips the rules: for making a
  /// moderator, and for checking that a deletion left nothing behind. Only
  /// the emulator accepts it.
  Future<int> admin(String method, String path, [Object? body]) async {
    final client = HttpClient();
    try {
      final project = db.app.options.projectId;
      final request = await client.openUrl(
        method,
        Uri.parse(
          'http://$host:8080/v1/projects/$project/databases/(default)/'
          'documents/$path',
        ),
      );
      request.headers.set('Authorization', 'Bearer owner');
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close();
      await response.drain<void>();
      return response.statusCode;
    } finally {
      client.close();
    }
  }

  Future<void> signIn(WidgetTester tester, String email) async {
    await tester.runAsync(() async {
      await FirebaseAuth.instance.signOut();
      await AuthService.instance
          .signInWithEmail(email: email, password: password);
    });
    journey.setUser(FirebaseAuth.instance.currentUser!.uid);
    await until(tester, () async => journey.accountLoaded, what: 'journey');
  }

  setUpAll(() async {
    final options = DefaultFirebaseOptions.currentPlatform;
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: options.apiKey,
        appId: options.appId,
        messagingSenderId: options.messagingSenderId,
        projectId: 'demo-journey',
      ),
    );
    db = FirebaseFirestore.instance;
    db.useFirestoreEmulator(host, 8080);
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    await FirebaseAuth.instance.signOut();
    SharedPreferences.setMockInitialValues({});
    await hadiths.load();
    // The real Firestore stores, on the emulator: no store override.
    await journey.debugReset(clock: now);
    journey.setUser(null);
    await board.debugReset(
      displayName: () => FirebaseAuth.instance.currentUser?.displayName,
      settle: const Duration(milliseconds: 300),
    );
    board.start();
  });

  testWidgets('1. a guest reads a hadith, confirms it, and memorizes it',
      (tester) async {
    journey.recordMessageRead('e2e-message', hadithNumber: 13);
    await tester.pumpWidget(
      app(
        HadithDetailScreen(hadith: hadiths.getByNumber(13)!),
        accessible: true,
      ),
    );
    await wait(tester);

    await tester.scrollUntilVisible(
      find.text('قرأت الحديث ونويت العمل به'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await press(tester, 'قرأت الحديث ونويت العمل به');
    await press(tester, 'احفظ هذا الحديث');
    expect(find.byType(MemorizeScreen), findsOneWidget);

    for (var i = 0; i < 20; i++) {
      if (find.text('أخفِ بعض الكلمات').evaluate().isNotEmpty) break;
      await press(tester, 'الجملة التالية');
    }
    await press(tester, 'أخفِ بعض الكلمات');
    await press(tester, 'أخفِ أكثر');
    await press(tester, 'سمّعه كاملاً');
    await press(tester, 'أظهر النص');
    await press(tester, 'حفظته');
    await press(tester, 'تم');

    expect(journey.isGuest, isTrue);
    expect(journey.data.progressOf(13).isComplete, isTrue);
    expect(journey.data.memoOf(13).isMemorized, isTrue);
  });

  testWidgets('2. signing up keeps the guest reading, in the database',
      (tester) async {
    await tester.runAsync(() async {
      await AuthService.instance.signUpWithEmail(
        email: readerEmail,
        password: password,
        displayName: readerName,
      );
      await confirmEmailInEmulator(host);
    });
    readerUid = FirebaseAuth.instance.currentUser!.uid;
    journey.setUser(readerUid);

    final state = 'users/$readerUid/journey/state';
    await until(
      tester,
      () async => (await db.doc(state).get()).data()?['memo'] != null,
      what: 'the guest journey in the account',
    );
    final saved = (await doc(tester, state))!;
    expect(at(saved['hadith'], '13')['full'], isNotNull);
    expect(at(saved['memo'], '13')['box'], 0);

    final year = (await doc(tester,
        'users/$readerUid/journeyYears/${journey.today.substring(0, 4)}'))!;
    final today = (year['days'] as Map)[journey.today] as Map;
    expect(today['m'], contains('e2e-message'));
    expect(today['h'], contains(13));
    expect(today['mz'], contains(13));
    expect(
        await tester.runAsync(SharedPreferences.getInstance).then(
              (prefs) => prefs!.getKeys().where((k) => k.contains('journey')),
            ),
        isEmpty,
        reason: 'the guest copy is cleared once it moved');
  });

  testWidgets('3. the reader writes a message from the hadith', (tester) async {
    await tester.runAsync(
      () => CommunityService().submit(
        hadithNumber: 13,
        message: message,
        authorName: readerName,
      ),
    );
    journey.recordWrote();

    final mine = await tester.runAsync(
      () => db
          .collection('communityMessages')
          .where('authorUid', isEqualTo: readerUid)
          .get(),
    );
    expect(mine!.docs, hasLength(1));
    messageId = mine.docs.single.id;
    expect(mine.docs.single.data()['status'], 'pending');
    expect(DaySteps.of(journey.data, journey.today).done, 3);

    // The reader's app is running: its watcher has looked once already.
    watcher = SubmissionApprovalWatcher(
      notify: (approved) async => announced.addAll(approved.map((s) => s.id)),
      notifyReach: () async {},
    )..start();
    // Its first look at this account only records what is approved so far,
    // so later approvals are news. Wait until that baseline is saved.
    await until(
      tester,
      () async {
        await watcher.check();
        final prefs = await SharedPreferences.getInstance();
        return prefs.getStringList('submissionApprovals.seen.$readerUid') !=
            null;
      },
      what: "the watcher's first look",
    );
    expect(announced, isEmpty);
  });

  testWidgets('4. a moderator approves it on the dashboard', (tester) async {
    // As the app's auth listener does on every account change.
    journey.setUser(null);
    await tester.runAsync(() async {
      await FirebaseAuth.instance.signOut();
      await AuthService.instance.signUpWithEmail(
        email: moderatorEmail,
        password: password,
        displayName: 'مشرف $stamp',
      );
      await confirmEmailInEmulator(host);
    });
    final moderator = FirebaseAuth.instance.currentUser!.uid;
    expect(
      await tester.runAsync(
        () => admin('PATCH', 'users/$moderator?updateMask.fieldPaths=role', {
          'fields': {
            'role': {'stringValue': 'moderator'},
          },
        }),
      ),
      200,
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PendingQueuePage())),
    );
    await wait(tester, 2000);
    expect(find.text(message), findsOneWidget);
    expect(find.text('موافقة'), findsOneWidget);
    await press(tester, 'موافقة');

    await until(
      tester,
      () async =>
          (await db.doc('communityMessages/$messageId').get())
              .data()?['status'] ==
          'approved',
      what: 'the approval',
    );
    final approved = (await doc(tester, 'communityMessages/$messageId'))!;
    expect(approved['reviewedAt'], isA<Timestamp>());
    expect(approved['reviewedBy'], moderator);
  });

  testWidgets('5. the approval reaches the reader and is worth 15',
      (tester) async {
    await signIn(tester, readerEmail);
    final before = journey.thisWeekPoints.total;

    // The watcher follows the account change itself and checks one at a
    // time, so an explicit check can join one still looking at the
    // moderator's account. Check until the reader's turn has come.
    await until(
      tester,
      () async {
        await watcher.check();
        return announced.contains(messageId);
      },
      what: 'the approval notification',
    );

    expect(announced, [messageId]);
    expect(journey.approvedOn, contains(journey.today));
    expect(journey.thisWeekPoints.approved, 15);
    expect(journey.thisWeekPoints.total, before + 15);
    watcher.dispose();
  });

  testWidgets('6. the reader joins the board, and the points sync',
      (tester) async {
    expect(board.join(nickname: readerName), isTrue);

    final expected = journey.thisWeekPoints.device;
    await until(
      tester,
      () async =>
          (await db.doc('scores/$readerUid').get()).data()?['device'] ==
          expected,
      what: 'the board entry',
    );
    final entry = (await doc(tester, 'scores/$readerUid'))!;
    expect(entry['name'], readerName);
    expect(entry['memo'], 15);
    expect(entry.containsKey('approved'), isFalse,
        reason: 'approvals are counted by the dashboard, not sent');
    readerWeekTotal = journey.thisWeekPoints.total;
  });

  testWidgets('7. the moderator publishes the week from the dashboard',
      (tester) async {
    journey.setUser(null);
    await tester.runAsync(() async {
      await FirebaseAuth.instance.signOut();
      await AuthService.instance
          .signInWithEmail(email: moderatorEmail, password: password);
    });

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WeeklyBoardPage())),
    );
    await wait(tester, 2500);
    expect(find.text(readerName), findsOneWidget);

    await press(tester, 'نشر اللوحة');
    expect(find.text('نشر لوحة الأسبوع'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'نشر'));
    await wait(tester, 1500);

    await until(
      tester,
      () async =>
          (await db.doc('settings/weeklyBoard').get()).data()?['points'] !=
          null,
      what: 'the published board',
    );
    final published = (await doc(tester, 'settings/weeklyBoard'))!;
    expect(first(published['points'])['name'], readerName);
    expect(first(published['points'])['value'], readerWeekTotal);
    expect(first(published['sharing'])['value'], 1);
    expect(first(published['memo'])['name'], readerName);
    expect(published.toString(), isNot(contains(readerUid)),
        reason: 'the published board holds no uid');
  });

  testWidgets('8. the reader sees the published board', (tester) async {
    await signIn(tester, readerEmail);
    await tester.pumpWidget(
      app(WeeklyBoardScreen(displayName: readerName)),
    );
    await wait(tester, 2500);

    expect(find.text(readerName), findsOneWidget);
    await press(tester, 'المشاركة');
    expect(find.text('رسالة واحدة'), findsOneWidget);
    await press(tester, 'الحفظ');
    expect(find.text(readerName), findsOneWidget);
  });

  testWidgets('9. the next day, the review is due and is recorded',
      (tester) async {
    dayOffset = 1;
    expect(journey.dueReviews, [13]);

    await tester.pumpWidget(
      app(ReviewScreen(hadith: hadiths.getByNumber(13)!)),
    );
    await wait(tester);
    await press(tester, 'أظهر النص');
    await press(tester, 'تذكرته');

    final state = 'users/$readerUid/journey/state';
    await until(
      tester,
      () async {
        final memo = (await db.doc(state).get()).data()?['memo'];
        return memo != null && at(memo, '13')['box'] == 1;
      },
      what: 'the review in the database',
    );
    final memo = ((await doc(tester, state))!['memo'] as Map)['13'] as Map;
    expect(memo['due'], dayKeyPlus(journey.today, 3));
    final year = (await doc(
      tester,
      'users/$readerUid/journeyYears/${journey.today.substring(0, 4)}',
    ))!;
    expect(((year['days'] as Map)[journey.today] as Map)['r'], contains(13));
  });

  testWidgets('10. deleting the account leaves nothing of the reader',
      (tester) async {
    final steps = <String>[];
    await tester.runAsync(
      () => AccountDeletionService().deleteAccount(onProgress: steps.add),
    );
    expect(steps, isNotEmpty);
    journey.setUser(null);

    final nameKey = AuthService.instance.normalizeDisplayName(readerName);
    for (final path in [
      'users/$readerUid/journey/state',
      'users/$readerUid/journeyYears/${journey.today.substring(0, 4)}',
      'scores/$readerUid',
      'communityMessages/$messageId',
      'users/$readerUid',
      'usernames/$nameKey',
    ]) {
      expect(
        await tester.runAsync(() => admin('GET', path)),
        404,
        reason: '$path should be gone',
      );
    }

    // runAsync swallows a throw, so the failure is caught inside it.
    final refused = await tester.runAsync(() async {
      try {
        await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: readerEmail, password: password);
        return false;
      } on FirebaseAuthException {
        return true;
      }
    });
    expect(refused, isTrue, reason: 'the account itself is gone');
  });
}
