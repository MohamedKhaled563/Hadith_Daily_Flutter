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
import 'package:hadith_app/data/journey/journey_copy.dart';
import 'package:hadith_app/data/journey/journey_engine.dart';
import 'package:hadith_app/data/journey/journey_points.dart';
import 'package:hadith_app/data/journey/journey_repository.dart';
import 'package:hadith_app/data/journey/weekly_board.dart';
import 'package:hadith_app/data/repositories/hadith_repository.dart';
import 'package:hadith_app/data/services/account_deletion_service.dart';
import 'package:hadith_app/features/dashboard/weekly_board_page.dart';
import 'package:hadith_app/features/journey/journey_numbers.dart';
import 'package:hadith_app/features/journey/today_steps_screen.dart';
import 'package:hadith_app/features/journey/weekly_board_screen.dart';
import 'package:hadith_app/features/memorize/memo_list_screen.dart';
import 'package:hadith_app/firebase_options.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// رحلتي end to end, for several readers on one phone, through the real
/// services, the real screens and the real firestore.rules, against the
/// local Firebase emulators — never the live project.
///
///     firebase emulators:exec --only firestore,auth --project demo-journey \
///       "flutter test integration_test/ruhlati_e2e_test.dart -d <device>"
///
/// Three readers and a moderator, in order, each step building on the last:
///
///  1. three readers sign up, each starting with nothing;
///  2. نور reads three days running, memorizes and reviews, and the database
///     holds every day of it;
///  3. نور's numbers, steps and memorizing come back from the database after
///     a fresh start, and say what the days were;
///  4. أبو أحمد, on the same phone, sees only his own journey;
///  5. the rules keep each reader's journey to themselves;
///  6. each reader joins the board under a nickname, and the rules hold the
///     line on names, points and other readers' entries;
///  7. the moderator publishes the week, and each reader sees it;
///  8. a reader renames from the board screen, and the database follows;
///  9. leaving takes a reader off; deleting سارة leaves nothing of her.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const host = '10.0.2.2';
  const password = 'test-only-password';
  final stamp = DateTime.now().microsecondsSinceEpoch % 1000000;

  /// The three readers: account name, email, and the nickname they pick.
  final noor = (
    account: 'نور $stamp',
    email: 'ruhlati-noor-$stamp@example.test',
    nick: 'نور',
  );
  final abuAhmad = (
    account: 'أبو أحمد $stamp',
    email: 'ruhlati-abu-$stamp@example.test',
    nick: 'أبو أحمد',
  );
  final sara = (
    account: 'سارة $stamp',
    email: 'ruhlati-sara-$stamp@example.test',
    nick: 'سارة',
  );
  final moderatorEmail = 'ruhlati-mod-$stamp@example.test';
  final uids = <String, String>{};

  final journey = JourneyRepository();
  final board = WeeklyBoardService();
  final hadiths = HadithRepository();
  late FirebaseFirestore db;

  var dayOffset = 0;
  DateTime now() => DateTime.now().add(Duration(days: dayOffset));

  Widget app(Widget home) => MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(body: home),
      );

  Future<void> wait(WidgetTester tester, [int ms = 500]) async {
    final end = DateTime.now().add(Duration(milliseconds: ms));
    while (DateTime.now().isBefore(end)) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
  }

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

  Future<Map<String, dynamic>?> doc(WidgetTester tester, String path) async =>
      (await tester.runAsync(() => db.doc(path).get()))?.data();

  /// What a screen reader is told, read from the widget that says it.
  Finder said(String label) => find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == label,
      );

  /// The emulator's own admin access, which skips the rules. Only the
  /// emulator accepts it.
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

  /// Whether the rules refused [action], run as whoever is signed in.
  Future<bool> refused(
    WidgetTester tester,
    Future<void> Function() action,
  ) async =>
      await tester.runAsync(() async {
        try {
          await action();
          return false;
        } on FirebaseException catch (error) {
          return error.code == 'permission-denied';
        }
      }) ??
      false;

  /// As the app's auth listener does: the account changes, and the journey
  /// and the board follow it.
  Future<void> signIn(WidgetTester tester, String email) async {
    journey.setUser(null);
    await tester.runAsync(() async {
      await FirebaseAuth.instance.signOut();
      await AuthService.instance
          .signInWithEmail(email: email, password: password);
    });
    journey.setUser(FirebaseAuth.instance.currentUser!.uid);
    await until(tester, () async => journey.accountLoaded, what: 'journey');
    await wait(tester, 600);
  }

  String year() => journey.today.substring(0, 4);

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

  testWidgets('1. three readers sign up, each starting with nothing',
      (tester) async {
    for (final reader in [noor, abuAhmad, sara]) {
      journey.setUser(null);
      await tester.runAsync(() async {
        await FirebaseAuth.instance.signOut();
        await AuthService.instance.signUpWithEmail(
          email: reader.email,
          password: password,
          displayName: reader.account,
        );
      });
      final uid = FirebaseAuth.instance.currentUser!.uid;
      uids[reader.nick] = uid;
      journey.setUser(uid);
      await until(tester, () async => journey.accountLoaded, what: 'journey');

      expect(journey.data.isEmpty, isTrue, reason: reader.nick);
      expect(journey.todaySteps.done, 0);
      expect(journey.allPoints, 0);
      expect(board.membership.value, isNull, reason: 'off the board');
    }
    expect(uids.values.toSet(), hasLength(3));
  });

  testWidgets('2. نور reads three days running, memorizes and reviews',
      (tester) async {
    await signIn(tester, noor.email);

    // Two days ago: the message, its hadith, and memorizing it.
    dayOffset = -2;
    journey.recordMessageRead('m-noor-1', hadithNumber: 1);
    journey.recordFullRead(1, seconds: 240);
    journey.learnPart(1, totalParts: 1);
    final first = journey.today;
    // Real days are hours apart, so each one's writes have reached the
    // server before the next day's begin. Writes sent milliseconds apart
    // can reach the emulator out of order.
    await tester.runAsync(db.waitForPendingWrites);
    // Yesterday: the review falls due, and is done; another hadith.
    dayOffset = -1;
    expect(journey.dueReviews, [1]);
    expect(journey.review(1, remembered: true).counted, isTrue);
    journey.recordMessageRead('m-noor-2', hadithNumber: 2);
    journey.recordFullRead(2, seconds: 180);
    await tester.runAsync(db.waitForPendingWrites);
    // Today: the message and a hadith, two steps of three.
    dayOffset = 0;
    journey.recordMessageRead('m-noor-3', hadithNumber: 3);
    journey.recordFullRead(3, seconds: 200);

    final uid = uids[noor.nick]!;
    await until(
      tester,
      () async {
        final days = (await db.doc('users/$uid/journeyYears/${year()}').get())
            .data()?['days'] as Map?;
        return days != null && days.length >= 3;
      },
      what: 'three days in the database',
    );
    final days =
        (await doc(tester, 'users/$uid/journeyYears/${year()}'))!['days']
            as Map;
    expect((days[first] as Map)['mz'], contains(1), reason: 'memorized');
    expect((days[dayKeyPlus(first, 1)] as Map)['r'], contains(1),
        reason: 'reviewed');
    expect((days[journey.today] as Map)['h'], contains(3));
    // The review moved it a box up, and the database has the new schedule.
    await until(
      tester,
      () async {
        final memo = (await db.doc('users/$uid/journey/state').get())
            .data()?['memo'] as Map?;
        return (memo?['1'] as Map?)?['box'] == 1;
      },
      what: 'the review in the database',
    );

    // Day one 2 + 10 + 15, day two 3 + 2 + 10, today 2 + 10.
    expect(journey.allPoints, 27 + 15 + 12);
    expect(journey.streak.current, 3);
    expect(journey.todaySteps.done, 2);
    final weekStart = weekStartKey(journey.today);
    expect(
      journey.thisWeekPoints.total,
      [
        if (first.compareTo(weekStart) >= 0) 27,
        if (dayKeyPlus(first, 1).compareTo(weekStart) >= 0) 15,
        12,
      ].fold<int>(0, (a, b) => a + b),
    );
    expect(journey.bestThisWeek, inInclusiveRange(1, 3));
  });

  testWidgets('3. after a fresh start, نور sees her days on every screen',
      (tester) async {
    // As a cold start: nothing kept in memory, all of it from the database.
    final uid = uids[noor.nick]!;
    await journey.debugReset(clock: now);
    journey.setUser(uid);
    await until(tester, () async => journey.accountLoaded, what: 'journey');
    expect(journey.allPoints, 54);

    await tester.pumpWidget(
      app(
        ListView(
          children: [
            JourneyNumbers(
              streak: journey.streak,
              bestThisWeek: journey.bestThisWeek,
              weekPoints: journey.thisWeekPoints.total,
              allPoints: journey.allPoints,
              memorized: journey.data.memorizedCount,
              canShare: true,
            ),
          ],
        ),
      ),
    );
    await wait(tester, 800);
    expect(said('الاستمرارية: ٣ أيام'), findsOneWidget);
    expect(said('أفضل استمرارية: ٣ أيام'), findsWidgets);
    expect(said('كل نقاطك: ٥٤ نقطة'), findsOneWidget);
    expect(said('حفظت: ١ / ٤٢ حديثاً'), findsOneWidget);

    await tester.pumpWidget(
      app(TodayStepsScreen(onOpenMessage: () {})),
    );
    await wait(tester, 800);
    expect(find.text(JourneyCopy.stepsDayCounted), findsOneWidget);
    expect(find.text('اكتب رسالتك'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));

    await tester.pumpWidget(app(const MemoListScreen()));
    await wait(tester, 800);
    expect(find.text('حفظت حديثاً واحداً'), findsOneWidget);
    expect(find.text(hadiths.getByNumber(1)!.title), findsOneWidget);
    // Reviewed yesterday, so not due today: it waits in the list.
    expect(find.text('دوره اليوم'), findsNothing);
    expect(find.textContaining('المراجعة القادمة'), findsOneWidget);
  });

  testWidgets('4. أبو أحمد, on the same phone, sees only his own journey',
      (tester) async {
    await signIn(tester, abuAhmad.email);

    expect(journey.uid, uids[abuAhmad.nick]);
    expect(journey.data.isEmpty, isTrue, reason: "none of نور's days");
    expect(journey.allPoints, 0);
    expect(journey.todaySteps.done, 0);

    journey.recordMessageRead('m-abu-1', hadithNumber: 5);
    final uid = uids[abuAhmad.nick]!;
    await until(
      tester,
      () async =>
          (await db.doc('users/$uid/journeyYears/${year()}').get()).exists,
      what: "أبو أحمد's day",
    );
    expect(journey.todaySteps.done, 1);
    expect(journey.allPoints, PointRules.message);

    // نور's record is as she left it.
    final noorUid = uids[noor.nick]!;
    final noorDays = await tester
        .runAsync(() => admin('GET', 'users/$noorUid/journeyYears/${year()}'));
    expect(noorDays, 200);
  });

  testWidgets("5. the rules keep each reader's journey to themselves",
      (tester) async {
    // Signed in as أبو أحمد.
    final noorUid = uids[noor.nick]!;
    expect(
      await refused(tester, () => db.doc('users/$noorUid/journey/state').get()),
      isTrue,
      reason: "reading نور's journey",
    );
    expect(
      await refused(
        tester,
        () => db.doc('users/$noorUid/journeyYears/${year()}').set(
          {'days': <String, dynamic>{}},
          SetOptions(merge: true),
        ),
      ),
      isTrue,
      reason: "writing نور's days",
    );
    expect(
      await refused(tester, () => db.doc('scores/$noorUid').get()),
      isTrue,
      reason: "reading نور's board entry",
    );
  });

  testWidgets('6. each reader joins the board under a nickname',
      (tester) async {
    for (final reader in [noor, abuAhmad, sara]) {
      await signIn(tester, reader.email);
      if (reader == sara) journey.recordFullRead(7, seconds: 120);

      // The app turns down a nickname that passes for staff.
      expect(board.join(nickname: 'المشرف'), isFalse);
      expect(board.join(nickname: reader.nick), isTrue);
      final uid = uids[reader.nick]!;
      await until(
        tester,
        () async =>
            (await db.doc('scores/$uid').get()).data()?['name'] == reader.nick,
        what: "${reader.nick}'s entry",
      );
      final entry = (await doc(tester, 'scores/$uid'))!;
      expect(entry['device'], journey.thisWeekPoints.device);
      expect(entry['name'], isNot(kAnonymousName));
    }

    // Signed in as سارة: the rules turn down what the app would not send.
    final saraUid = uids[sara.nick]!;
    final noorUid = uids[noor.nick]!;
    final week = (await doc(tester, 'scores/$saraUid'))!['week'] as int;
    Map<String, dynamic> entry({String? name, int device = 10}) => {
          'week': week,
          'device': device,
          'name': name ?? 'سارة',
          'updatedAt': FieldValue.serverTimestamp(),
        };
    expect(
      await refused(tester, () => db.doc('scores/$noorUid').set(entry())),
      isTrue,
      reason: "writing نور's entry",
    );
    expect(
      await refused(
        tester,
        () => db.doc('scores/$saraUid').set(entry(name: 'ا' * 41)),
      ),
      isTrue,
      reason: 'a name longer than forty',
    );
    expect(
      await refused(
        tester,
        () => db.doc('scores/$saraUid').set(entry(device: 301)),
      ),
      isTrue,
      reason: 'more than a week can earn',
    );
    expect(
      await refused(
        tester,
        () => db.doc('scores/$saraUid').set({...entry(), 'uid': saraUid}),
      ),
      isTrue,
      reason: 'a field the rules do not know',
    );
  });

  testWidgets('7. the moderator publishes, and every reader sees the week',
      (tester) async {
    journey.setUser(null);
    await tester.runAsync(() async {
      await FirebaseAuth.instance.signOut();
      await AuthService.instance.signUpWithEmail(
        email: moderatorEmail,
        password: password,
        displayName: 'مراجع $stamp',
      );
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
      const MaterialApp(home: Scaffold(body: WeeklyBoardPage())),
    );
    await wait(tester, 2500);
    for (final reader in [noor, abuAhmad, sara]) {
      expect(find.text(reader.nick), findsWidgets, reason: reader.nick);
    }
    final publish = find.text('نشر اللوحة').last;
    await tester.ensureVisible(publish);
    await tester.tap(publish);
    await wait(tester, 600);
    await tester.tap(find.widgetWithText(FilledButton, 'نشر'));
    await until(
      tester,
      () async =>
          (await db.doc('settings/weeklyBoard').get()).data()?['points'] !=
          null,
      what: 'the published board',
    );
    final published = (await doc(tester, 'settings/weeklyBoard'))!;
    final names = [
      for (final row in published['points'] as List) (row as Map)['name'],
    ];
    expect(names, containsAll([noor.nick, abuAhmad.nick, sara.nick]));
    expect(names.first, noor.nick, reason: 'نور has the most points');
    expect(published.toString(), isNot(contains(uids[noor.nick]!)),
        reason: 'the published board holds no uid');

    for (final reader in [noor, abuAhmad, sara]) {
      await signIn(tester, reader.email);
      await tester.pumpWidget(app(const WeeklyBoardScreen()));
      await wait(tester, 2500);
      for (final other in [noor, abuAhmad, sara]) {
        expect(find.text(other.nick), findsOneWidget, reason: other.nick);
      }
      expect(find.textContaining('«${reader.nick}»'), findsOneWidget,
          reason: 'the reader sees the name they are under');
      expect(find.text(kAnonymousName), findsNothing);
      expect(find.textContaining('مركز'), findsNothing, reason: 'no rank');
    }
  });

  testWidgets('8. سارة renames from the board, and the database follows',
      (tester) async {
    // Signed in as سارة, on the board screen.
    await tester.pumpWidget(app(const WeeklyBoardScreen()));
    await wait(tester, 2500);
    await tester.scrollUntilVisible(
      find.text('غيّر الاسم'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await wait(tester, 300);
    await tester.tap(find.text('غيّر الاسم'));
    await wait(tester, 900);
    expect(find.text('اسمك في اللوحة'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'www.site');
    await tester.tap(find.text('احفظ'));
    await wait(tester, 400);
    expect(find.text('لا روابط في الاسم.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'سارة القارئة');
    await tester.tap(find.text('احفظ'));
    final uid = uids[sara.nick]!;
    await until(
      tester,
      () async =>
          (await db.doc('scores/$uid').get()).data()?['name'] == 'سارة القارئة',
      what: 'the new name',
    );
    // The database can answer before the screen has drawn its next frame.
    await until(
      tester,
      () async => find.textContaining('«سارة القارئة»').evaluate().isNotEmpty,
      what: 'the new name on the board screen',
    );
    expect(find.textContaining('«سارة القارئة»'), findsOneWidget);
  });

  testWidgets('9. leaving takes a reader off; deleting سارة leaves nothing',
      (tester) async {
    await signIn(tester, abuAhmad.email);
    expect(board.membership.value?.name, abuAhmad.nick);
    board.leave();
    final abuUid = uids[abuAhmad.nick]!;
    await until(
      tester,
      () async => !(await db.doc('scores/$abuUid').get()).exists,
      what: 'أبو أحمد off the board',
    );

    await signIn(tester, sara.email);
    final saraUid = uids[sara.nick]!;
    final steps = <String>[];
    await tester.runAsync(
      () => AccountDeletionService().deleteAccount(onProgress: steps.add),
    );
    journey.setUser(null);
    expect(steps, isNotEmpty);
    for (final path in [
      'users/$saraUid/journey/state',
      'users/$saraUid/journeyYears/${year()}',
      'scores/$saraUid',
      'users/$saraUid',
    ]) {
      expect(
        await tester.runAsync(() => admin('GET', path)),
        404,
        reason: '$path should be gone',
      );
    }
    // The others are untouched.
    expect(
      await tester.runAsync(
        () => admin('GET', 'users/${uids[noor.nick]}/journey/state'),
      ),
      200,
    );
    expect(
      await tester.runAsync(() => admin('GET', 'scores/${uids[noor.nick]}')),
      200,
    );
  });
}
