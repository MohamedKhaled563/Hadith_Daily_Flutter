import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/data/journey/journey_models.dart';
import 'package:hadith_app/data/journey/journey_store.dart';
import 'package:hadith_app/data/journey/memorization.dart';
import 'package:hadith_app/firebase_options.dart';
import 'package:integration_test/integration_test.dart';

/// [FirestoreJourneyStore] through the real SDK and the real firestore.rules,
/// against the local Firebase emulators, never the live project.
///
///     firebase emulators:start --only firestore,auth --project demo-journey
///     flutter test integration_test/journey_firestore_test.dart -d <device>
///
/// firebase-tools needs Java 21 or newer. If the default JDK is older, point
/// JAVA_HOME at Android Studio's `jbr` for the first command. 10.0.2.2 is the
/// host machine as an Android emulator sees it.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const host = '10.0.2.2';
  late FirebaseFirestore db;
  late FirestoreJourneyStore store;
  late String uid;

  Future<String> newAccount() async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final credential =
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: 'journey-$stamp@example.test',
      password: 'test-only-$stamp',
    );
    return credential.user!.uid;
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
    store = FirestoreJourneyStore(db);
  });

  setUp(() async => uid = await newAccount());

  Future<JourneyData> readBack(String who) =>
      store.watch(who, 2026).first.timeout(const Duration(seconds: 15));

  test('reminder settings go through the rules and leave the rest alone',
      () async {
    const prefs = ReminderPrefs(
      morningOn: true,
      morning: '07:15',
      eveningOn: false,
      evening: '21:30',
    );
    await store.record(
      uid,
      const JourneyEvent(
        dayKey: '2026-11-06',
        messageId: 'msg-1',
        startedOn: '2026-11-06',
      ),
    );

    await store.savePrefs(uid, prefs);

    final data = await readBack(uid);
    expect(data.prefs, prefs);
    expect(data.startedOn, '2026-11-06');
    expect(data.days['2026-11-06']!.messages, ['msg-1']);
  });

  test('a reading goes through the rules and comes back the same', () async {
    await store.record(
      uid,
      const JourneyEvent(
        dayKey: '2026-11-06',
        messageId: 'msg-1',
        messageHadith: 13,
        startedOn: '2026-11-06',
      ),
    );
    await store.record(
      uid,
      const JourneyEvent(
        dayKey: '2026-11-06',
        fullHadith: 13,
        seconds: 95,
        seen: ['read5'],
        bestStreak: 3,
      ),
    );

    final data = await readBack(uid);
    expect(data.startedOn, '2026-11-06');
    expect(data.progressOf(13).isComplete, isTrue);
    expect(data.progressOf(13).reads, 1);
    expect(data.days['2026-11-06']!.messages, ['msg-1']);
    expect(data.days['2026-11-06']!.messageHadith, 13);
    expect(data.days['2026-11-06']!.hadiths, [13]);
    expect(data.days['2026-11-06']!.seconds, 95);
    expect(data.seen, {'read5'});
    expect(data.bestStreak, 3);
  });

  test('two writes on one day merge rather than replace', () async {
    await store.record(
      uid,
      const JourneyEvent(dayKey: '2026-11-06', fullHadith: 1, seconds: 10),
    );
    await store.record(
      uid,
      const JourneyEvent(dayKey: '2026-11-06', fullHadith: 2, seconds: 20),
    );
    await store.record(
      uid,
      const JourneyEvent(dayKey: '2026-11-06', messageId: 'a'),
    );

    final day = (await readBack(uid)).days['2026-11-06']!;
    expect(day.hadiths, unorderedEquals([1, 2]));
    expect(day.seconds, 30);
    expect(day.messages, ['a']);
  });

  test('community reads and shares go through the rules and add up', () async {
    for (final post in ['post-1', 'post-2', 'post-1']) {
      await store.record(
        uid,
        JourneyEvent(dayKey: '2026-11-07', communityId: post),
      );
    }
    for (var i = 0; i < 2; i++) {
      await store.record(
        uid,
        const JourneyEvent(dayKey: '2026-11-07', shared: 1),
      );
    }

    final day = (await readBack(uid)).days['2026-11-07']!;
    expect(day.community, unorderedEquals(['post-1', 'post-2']));
    expect(day.shared, 2);
  });

  test('memorizing goes through the rules, and a kept hadith loses its date',
      () async {
    const learning = MemoProgress(parts: 1);
    await store.record(
      uid,
      const JourneyEvent(
        dayKey: '2026-11-07',
        memoHadith: 2,
        memo: learning,
        memoPart: true,
      ),
    );
    const memorized = MemoProgress(
      parts: 1,
      box: 0,
      due: '2026-11-08',
      memorizedOn: '2026-11-07',
    );
    await store.record(
      uid,
      const JourneyEvent(
        dayKey: '2026-11-07',
        memoHadith: 13,
        memo: memorized,
        memorized: true,
      ),
    );
    await store.record(
      uid,
      const JourneyEvent(
        dayKey: '2026-11-08',
        memoHadith: 13,
        memo: MemoProgress(
            parts: 1, box: 1, due: '2026-11-11', memorizedOn: '2026-11-07'),
        reviewed: true,
      ),
    );

    var data = await readBack(uid);
    expect(data.memoOf(2), learning);
    expect(data.memoOf(13).due, '2026-11-11');
    expect(data.days['2026-11-07']!.memoParts, [2]);
    expect(data.days['2026-11-07']!.memorized, [13]);
    expect(data.days['2026-11-08']!.reviewed, [13]);

    await store.record(
      uid,
      const JourneyEvent(
        dayKey: '2026-11-11',
        memoHadith: 13,
        memo: MemoProgress(parts: 1, box: 6, memorizedOn: '2026-11-07'),
        reviewed: true,
      ),
    );
    data = await readBack(uid);
    expect(data.memoOf(13).isKept, isTrue);
    expect(data.memoOf(13).due, isNull, reason: 'the old date is deleted');
  });

  test('a guest reading joins the account without replacing it', () async {
    await store.record(
      uid,
      const JourneyEvent(
        dayKey: '2026-11-01',
        fullHadith: 1,
        startedOn: '2026-11-01',
      ),
    );

    final guest = JourneyData.empty
        .apply(const JourneyEvent(
          dayKey: '2026-11-06',
          fullHadith: 1,
          startedOn: '2026-11-06',
        ))
        .apply(const JourneyEvent(
          dayKey: '2026-11-06',
          fullHadith: 2,
          seconds: 40,
          seen: ['read5'],
        ))
        .apply(const JourneyEvent(
          dayKey: '2026-11-06',
          communityId: 'post-9',
        ))
        .apply(const JourneyEvent(dayKey: '2026-11-06', shared: 1));
    await store.absorb(uid, guest);

    final data = await readBack(uid);
    expect(data.startedOn, '2026-11-01', reason: 'the older date stands');
    expect(data.progressOf(1).fullOn, '2026-11-01');
    expect(data.progressOf(2).isComplete, isTrue);
    expect(data.seen, {'read5'});
    expect(data.days.keys, containsAll(['2026-11-01', '2026-11-06']));
    expect(data.days['2026-11-06']!.community, ['post-9']);
    expect(data.days['2026-11-06']!.shared, 1);
  });

  test("another reader cannot read or write someone's journey", () async {
    await store.record(
      uid,
      const JourneyEvent(dayKey: '2026-11-06', fullHadith: 1),
    );

    final stranger = await newAccount();
    expect(stranger, isNot(uid));

    final theirState =
        db.collection('users').doc(uid).collection('journey').doc('state');
    final theirYear =
        db.collection('users').doc(uid).collection('journeyYears').doc('2026');

    await expectLater(
      theirState.get(const GetOptions(source: Source.server)),
      throwsA(isA<FirebaseException>()
          .having((e) => e.code, 'code', 'permission-denied')),
    );
    await expectLater(
      theirYear.set({'days': {}}, SetOptions(merge: true)),
      throwsA(isA<FirebaseException>()
          .having((e) => e.code, 'code', 'permission-denied')),
    );
  });

  test('the rules refuse a doc outside the agreed shape', () async {
    final state =
        db.collection('users').doc(uid).collection('journey').doc('state');
    final deniedError = throwsA(isA<FirebaseException>()
        .having((e) => e.code, 'code', 'permission-denied'));

    await expectLater(
      state.set({
        'updatedAt': FieldValue.serverTimestamp(),
        'hacked': true,
      }),
      deniedError,
      reason: 'an unknown field',
    );
    await expectLater(
      db
          .collection('users')
          .doc(uid)
          .collection('journey')
          .doc('other')
          .set({'updatedAt': FieldValue.serverTimestamp()}),
      deniedError,
      reason: 'a doc other than state',
    );
    await expectLater(
      db
          .collection('users')
          .doc(uid)
          .collection('journeyYears')
          .doc('not-a-year')
          .set({'days': {}}),
      deniedError,
      reason: 'a bad year id',
    );
    await expectLater(
      state.set({
        'updatedAt': FieldValue.serverTimestamp(),
        'hadith': {for (var n = 1; n <= 43; n++) '$n': {}},
      }),
      deniedError,
      reason: 'more hadiths than exist',
    );
  });

  test('the owner can delete it all, as account deletion must', () async {
    await store.record(
      uid,
      const JourneyEvent(dayKey: '2026-11-06', fullHadith: 1),
    );

    final user = db.collection('users').doc(uid);
    for (final name in ['journey', 'journeyYears']) {
      final docs = await user.collection(name).get();
      expect(docs.docs, isNotEmpty);
      for (final doc in docs.docs) {
        await doc.reference.delete();
      }
      expect((await user.collection(name).get()).docs, isEmpty);
    }
  });
}
