import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/data/journey/board_service.dart';
import 'package:hadith_app/data/journey/weekly_board.dart';
import 'package:hadith_app/features/dashboard/weekly_board_page.dart';
import 'package:hadith_app/firebase_options.dart';
import 'package:integration_test/integration_test.dart';

/// The weekly board through the real SDK and the real firestore.rules,
/// against the local Firebase emulators, never the live project.
///
///     firebase emulators:exec --only firestore,auth --project demo-journey \
///       "flutter test integration_test/board_firestore_test.dart -d <device>"
///
/// A moderator is made by writing their role with the emulator's own admin
/// token, which skips the rules. Only the emulator accepts it.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const host = '10.0.2.2';
  const project = 'demo-journey';
  late FirebaseFirestore db;

  /// The week the server is in now, as firestore.rules count it.
  int serverWeek() =>
      ((DateTime.now().toUtc().millisecondsSinceEpoch - 172800000) / 604800000)
          .floor();

  Future<String> signInNew() async {
    await FirebaseAuth.instance.signOut();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final credential =
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: 'board-$stamp@example.test',
      password: 'test-only-$stamp',
    );
    return credential.user!.uid;
  }

  Future<void> makeModerator(String uid) async {
    final client = HttpClient();
    try {
      // The project the SDK really talks to inside the emulator. On Android
      // the default app is already set up natively from google-services.json,
      // so the id passed to initializeApp may not be the one in use.
      final inUse = db.app.options.projectId;
      final request = await client.patchUrl(Uri.parse(
        'http://$host:8080/v1/projects/$inUse/databases/(default)/documents/'
        'users/$uid?updateMask.fieldPaths=role',
      ));
      request.headers
        ..set('Authorization', 'Bearer owner')
        ..contentType = ContentType.json;
      request.write(jsonEncode({
        'fields': {
          'role': {'stringValue': 'moderator'},
        },
      }));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      expect(response.statusCode, 200, reason: body);
    } finally {
      client.close();
    }
    // The rules look the role up with get(), so it has to be readable back
    // through the SDK, as the moderator, before anything relies on it.
    final mine = await db.collection('users').doc(uid).get();
    expect(mine.data()?['role'], 'moderator',
        reason: 'signed in as ${FirebaseAuth.instance.currentUser?.uid}');
  }

  Future<void> refused(Future<void> Function() write) async {
    await expectLater(
      write().timeout(const Duration(seconds: 15)),
      throwsA(
        isA<FirebaseException>()
            .having((e) => e.code, 'code', 'permission-denied'),
      ),
    );
  }

  DocumentReference<Map<String, dynamic>> score(String uid) =>
      db.collection('scores').doc(uid);

  Map<String, dynamic> valid({int? week, int device = 120, String? name}) => {
        'week': week ?? serverWeek(),
        'device': device,
        'name': name ?? kAnonymousName,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  setUpAll(() async {
    final options = DefaultFirebaseOptions.currentPlatform;
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: options.apiKey,
        appId: options.appId,
        messagingSenderId: options.messagingSenderId,
        projectId: project,
      ),
    );
    db = FirebaseFirestore.instance;
    db.useFirestoreEmulator(host, 8080);
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  });

  group('a reader', () {
    late String uid;
    setUp(() async => uid = await signInNew());

    test('joins, updates and leaves through the app\'s own store', () async {
      final store = FirestoreBoardStore(db);
      final entry = ScoreEntry(
        uid: uid,
        week: serverWeek(),
        device: 140,
        name: 'سارة',
      );

      await store.saveScore(entry);
      expect(await store.ownScore(uid), entry);

      await store.saveScore(
        ScoreEntry(uid: uid, week: entry.week, device: 300, name: 'سارة'),
      );
      expect((await store.ownScore(uid))!.device, 300);

      await store.removeScore(uid);
      expect(await store.ownScore(uid), isNull);
    });

    test('may send a week either side of the server\'s', () async {
      await score(uid).set(valid(week: serverWeek() - 1));
      await score(uid).set(valid(week: serverWeek() + 1));
    });

    test('may send memorization points, up to a full week of them', () async {
      await score(uid).set({...valid(), 'memo': 210});
      final store = FirestoreBoardStore(db);
      expect((await store.ownScore(uid))!.memo, 210);
      await refused(() => score(uid).set({...valid(), 'memo': 211}));
      await refused(() => score(uid).set({...valid(), 'memo': '5'}));
    });

    test('cannot claim more than 300 from the phone', () async {
      await refused(() => score(uid).set(valid(device: 301)));
    });

    test('cannot send a week long past or far ahead', () async {
      await refused(() => score(uid).set(valid(week: serverWeek() - 3)));
      await refused(() => score(uid).set(valid(week: serverWeek() + 3)));
    });

    test('cannot award itself approved messages', () async {
      await refused(
        () => score(uid).set({...valid(), 'approved': 3}),
      );
    });

    test('cannot backdate the entry or leave a field out', () async {
      await refused(
        () => score(uid).set({...valid(), 'updatedAt': Timestamp.now()}),
      );
      await refused(() => score(uid).set({
            'week': serverWeek(),
            'device': 10,
            'updatedAt': FieldValue.serverTimestamp(),
          }));
    });

    test('cannot use an empty or overlong name', () async {
      await refused(() => score(uid).set(valid(name: '')));
      await refused(() => score(uid).set(valid(name: 'ا' * 41)));
    });

    test("cannot write or read another reader's entry", () async {
      final other = uid;
      await score(other).set(valid());
      await signInNew();

      await refused(() => score(other).set(valid()));
      await refused(() => score(other).get());
      await refused(() => score(other).delete());
    });

    test('cannot publish a board', () async {
      await refused(
        () => FirestoreBoardModeration(db).publish(
          const WeeklyBoard(week: 1, points: [], sharing: []),
        ),
      );
    });
  });

  group('a moderator', () {
    test('ranks the week and publishes it for everyone to read', () async {
      final week = serverWeek();
      final readers = <String>[];
      for (final device in [90, 250]) {
        final uid = await signInNew();
        await score(uid).set(valid(device: device, name: 'r$device'));
        readers.add(uid);
      }

      final moderatorUid = await signInNew();
      await makeModerator(moderatorUid);
      final moderation = FirestoreBoardModeration(db);

      final scores = await moderation.scores(week);
      expect(
        scores.where((s) => readers.contains(s.uid)).map((s) => s.device),
        unorderedEquals([90, 250]),
      );

      final board = publishBoard(
        week: week,
        ranked: rankCandidates(week: week, scores: scores),
      );
      await moderation.publish(board);

      await FirebaseAuth.instance.signOut();
      final read = await FirestoreBoardStore(db).published();
      expect(read!.week, week);
      expect(
          read.points.map((r) => r.name), containsAllInOrder(['r250', 'r90']));
      expect(read.publishedAt, isNotNull);
    });

    test('publishes a memorization list of names, ten at most', () async {
      final uid = await signInNew();
      await makeModerator(uid);
      final moderation = FirestoreBoardModeration(db);

      await moderation.publish(WeeklyBoard(
        week: serverWeek(),
        points: const [],
        sharing: const [],
        memo: [for (var i = 0; i < 10; i++) BoardRow(name: 'm$i', value: 0)],
      ));
      expect((await moderation.published())!.memo, hasLength(10));

      await refused(() => moderation.publish(WeeklyBoard(
            week: serverWeek(),
            points: const [],
            sharing: const [],
            memo: [
              for (var i = 0; i < 11; i++) BoardRow(name: 'm$i', value: 0),
            ],
          )));
    });

    test('cannot publish more than ten names a list', () async {
      final uid = await signInNew();
      await makeModerator(uid);

      await refused(
        () => FirestoreBoardModeration(db).publish(
          WeeklyBoard(
            week: serverWeek(),
            points: [
              for (var i = 0; i < 11; i++) BoardRow(name: 'n$i', value: 1),
            ],
            sharing: const [],
          ),
        ),
      );
    });

    test('can remove an entry that should not be there', () async {
      final reader = await signInNew();
      await score(reader).set(valid());

      final uid = await signInNew();
      await makeModerator(uid);
      await score(reader).delete();

      final snap = await score(reader).get();
      expect(snap.exists, isFalse);
    });
  });
}
