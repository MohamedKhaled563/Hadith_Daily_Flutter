import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/core/theme/app_state_controller.dart';
import 'package:hadith_app/core/theme/app_theme.dart';
import 'package:hadith_app/data/repositories/hadith_repository.dart';
import 'package:hadith_app/data/services/community_service.dart';
import 'package:hadith_app/features/share/add_message_screen.dart';
import 'package:hadith_app/firebase_options.dart';
import 'package:integration_test/integration_test.dart';

/// The whole of «شارك رسالتك», through the real screen, the real SDK and the
/// real firestore.rules, against the local Firebase emulators and never the
/// live project.
///
///     firebase emulators:start --only firestore,auth --project demo-journey
///     flutter test integration_test/send_message_test.dart -d <device>
///
/// Turning Firestore's network off stands in for a phone that cannot reach
/// the server, which looks the same to the app: no answer and no error.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const host = '10.0.2.2';
  const sentText = 'تم إرسال رسالتك للمراجعة، وستظهر بعد موافقة المشرفين';
  const queuedText = 'الاتصال ضعيف الآن، فحفظنا رسالتك وسنرسلها وحدها عند عودته، '
      'فلا داعي لكتابتها مرة أخرى';
  const failedText =
      'تعذّر إرسال رسالتك، تحقق من اتصالك بالإنترنت وحاول مرة أخرى';

  late FirebaseFirestore db;
  late String uid;

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
    await HadithRepository().load();
    await AppStateController().init();
  });

  setUp(() async {
    await db.enableNetwork();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final credential =
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: 'writer-$stamp@example.test',
      password: 'test-only-$stamp',
    );
    uid = credential.user!.uid;
    // AppStateController hears about the sign-in through its own listener.
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });

  tearDown(() async {
    await db.enableNetwork();
    await FirebaseAuth.instance.signOut();
  });

  Future<List<Map<String, dynamic>>> onServer() async {
    final snapshot = await db
        .collection('communityMessages')
        .where('authorUid', isEqualTo: uid)
        .get(const GetOptions(source: Source.server));
    return [for (final doc in snapshot.docs) doc.data()];
  }

  Future<void> openForm(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Scaffold(body: SafeArea(child: AddMessageScreen())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> fillIn(WidgetTester tester, String message) async {
    await tester.tap(find.byWidgetPredicate((w) => w is DropdownButton));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.textContaining('الحديث ١:').last);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField).last, message);
    await tester.pump(const Duration(milliseconds: 200));
  }

  /// Presses send and pumps real time until the overlay is gone, failing if
  /// it outlasts [limit]. Returns how long the reader waited.
  Future<Duration> send(
    WidgetTester tester, {
    Duration limit = const Duration(seconds: 16),
  }) async {
    final clock = Stopwatch()..start();
    await tester.tap(find.text('إرسال الرسالة'));
    await tester.pump(const Duration(milliseconds: 100));
    while (find.text('جارٍ الإرسال…').evaluate().isNotEmpty) {
      expect(
        clock.elapsed < limit,
        isTrue,
        reason: 'the send overlay was still up after $limit',
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 300));
    return clock.elapsed;
  }

  String? fieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField).last).controller?.text;

  testWidgets('with a working connection the message reaches the server',
      (tester) async {
    await openForm(tester);
    await fillIn(tester, 'رسالة وصلت من أول مرة');

    final waited = await send(tester);

    expect(waited, lessThan(CommunityService.sendBudget));
    expect(find.text(sentText), findsOneWidget);
    expect(fieldText(tester), isEmpty);

    final stored = await onServer();
    expect(stored, hasLength(1));
    expect(stored.single['message'], 'رسالة وصلت من أول مرة');
    expect(stored.single['status'], 'pending');
    expect(stored.single['hadithNumber'], 1);
  });

  testWidgets('with no answer from the server the reader is let go',
      (tester) async {
    await openForm(tester);
    await fillIn(tester, 'رسالة كُتبت والاتصال مقطوع');
    await db.disableNetwork();

    final waited = await send(tester);

    expect(waited, greaterThanOrEqualTo(CommunityService.sendBudget));
    expect(find.text(queuedText), findsOneWidget);
    expect(find.text(failedText), findsNothing);
    expect(fieldText(tester), isEmpty, reason: 'it would be sent twice');

    await db.enableNetwork();
    await db.waitForPendingWrites().timeout(const Duration(seconds: 15));

    final stored = await onServer();
    expect(stored, hasLength(1), reason: 'delivered once, by the queue');
    expect(stored.single['message'], 'رسالة كُتبت والاتصال مقطوع');
  });

  testWidgets('a message the rules refuse says so and keeps the text',
      (tester) async {
    final tooLong = 'س' * 2001;
    await openForm(tester);
    await fillIn(tester, tooLong);

    await send(tester);

    expect(find.text(failedText), findsOneWidget);
    expect(fieldText(tester), tooLong);
    expect(await onServer(), isEmpty);
  });
}
