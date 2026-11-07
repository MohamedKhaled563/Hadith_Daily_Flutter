import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/data/journey/board_service.dart';
import 'package:hadith_app/data/journey/journey_copy.dart';
import 'package:hadith_app/data/journey/journey_engine.dart';
import 'package:hadith_app/data/journey/journey_repository.dart';
import 'package:hadith_app/data/journey/journey_store.dart';
import 'package:hadith_app/data/journey/weekly_board.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FlakyBoardStore extends InMemoryBoardStore {
  int failuresLeft = 1;

  @override
  Future<void> saveScore(ScoreEntry entry) async {
    if (failuresLeft > 0) {
      failuresLeft--;
      throw StateError('offline');
    }
    await super.saveScore(entry);
  }
}

/// Phase 4: the weekly board. The week count the app and the rules share,
/// names, ranking and publishing, and the service that keeps a reader's
/// entry in step with their reading only while they are on the board.
void boardSuite() {
  group('the board week', () {
    test('counts Saturdays from the first one after the epoch', () {
      expect(boardWeekOf('1970-01-03'), 0);
      expect(boardWeekOf('1970-01-10'), 1);
      expect(boardWeekOf('2026-11-14') - boardWeekOf('2026-11-07'), 1);
    });

    test('is the same count the rules make from the server clock', () {
      // firestore.rules: floor((ms - 172800000) / 604800000).
      int rules(DateTime utc) =>
          ((utc.millisecondsSinceEpoch - 172800000) / 604800000).floor();

      expect(boardWeekOf('2026-11-07'), rules(DateTime.utc(2026, 11, 7)));
      expect(
        boardWeekOf('2026-11-07'),
        rules(DateTime.utc(2026, 11, 13, 23, 59)),
      );
      expect(
        boardWeekOf('2026-11-14'),
        rules(DateTime.utc(2026, 11, 14, 0, 1)),
      );
    });

    test('turns back into its Saturday, all year round', () {
      var saturday = '2026-01-03';
      for (var i = 0; i < 60; i++) {
        expect(boardWeekStart(boardWeekOf(saturday)), saturday);
        saturday = dayKeyPlus(saturday, 7);
      }
    });

    test('follows the reading day, so Friday night is still Friday', () {
      final fridayNight = journeyDayKey(DateTime(2026, 11, 14, 2));
      expect(fridayNight, '2026-11-13');
      expect(boardWeekOfDay(fridayNight), boardWeekOf('2026-11-07'));
      expect(
        boardWeekOfDay(journeyDayKey(DateTime(2026, 11, 14, 4))),
        boardWeekOf('2026-11-14'),
      );
    });

    test('is shown as the days it covers', () {
      expect(JourneyCopy.boardWeek('2026-11-07'), '٧ – ١٣ نوفمبر');
      expect(JourneyCopy.boardWeek('2026-11-28'), '٢٨ نوفمبر – ٤ ديسمبر');
      expect(JourneyCopy.boardWeek('2026-12-26'), '٢٦ ديسمبر – ١ يناير');
    });
  });

  group('names', () {
    test('a reader is «فاعل خير» unless they choose their own name', () {
      expect(boardName(useName: false, displayName: 'سارة'), kAnonymousName);
      expect(boardName(useName: true, displayName: '  سارة '), 'سارة');
    });

    test('no name to use means «فاعل خير»', () {
      expect(boardName(useName: true), kAnonymousName);
      expect(boardName(useName: true, displayName: '   '), kAnonymousName);
    });

    test('a long name is cut to what the rules allow', () {
      expect(boardName(useName: true, displayName: 'ا' * 60).length, 40);
    });

    test('messages are counted in the form the number takes', () {
      expect(arabicMessageCount(1), 'رسالة واحدة');
      expect(arabicMessageCount(2), 'رسالتان');
      expect(arabicMessageCount(3), '٣ رسائل');
      expect(arabicMessageCount(11), '١١ رسالة');
    });
  });

  group('ranking', () {
    const week = 3000;
    ScoreEntry entry(String uid, int device, {int week = week}) =>
        ScoreEntry(uid: uid, week: week, device: device, name: 'n-$uid');

    test('only this week, highest first', () {
      final ranked = rankCandidates(
        week: week,
        scores: [
          entry('a', 120),
          entry('b', 250),
          entry('c', 290, week: week - 1),
        ],
      );

      expect(ranked.map((c) => c.uid), ['b', 'a']);
    });

    test('the phone counts for 300 at most', () {
      final ranked = rankCandidates(week: week, scores: [entry('a', 900)]);

      expect(ranked.single.device, 300);
      expect(ranked.single.score, 300);
    });

    test('approved messages add 15 each, three at most', () {
      final ranked = rankCandidates(
        week: week,
        scores: [entry('a', 300), entry('b', 300)],
        approvals: {'a': 5, 'b': 1},
      );

      expect(ranked.first.uid, 'a');
      expect(ranked.first.score, 345);
      expect(ranked.first.approved, 5, reason: 'the sharing list sees all');
      expect(ranked.last.score, 315);
    });

    test('a tie is settled the same way on every screen', () {
      final once = rankCandidates(
        week: week,
        scores: [entry('z', 100), entry('m', 100), entry('a', 100)],
      );
      final again = rankCandidates(
        week: week,
        scores: [entry('a', 100), entry('z', 100), entry('m', 100)],
      );

      expect(once.map((c) => c.uid), again.map((c) => c.uid));
    });

    test('approvals count by the reading day they happened on', () {
      final saturday = DateTime(2026, 11, 7, 12);
      final counts = approvalsInWeek(
        [
          (authorUid: 'a', reviewedAt: saturday),
          (authorUid: 'a', reviewedAt: DateTime(2026, 11, 13, 22)),
          // 02:00 on Saturday is still Friday's reading day.
          (authorUid: 'b', reviewedAt: DateTime(2026, 11, 7, 2)),
          (authorUid: 'b', reviewedAt: DateTime(2026, 11, 14, 4)),
        ],
        boardWeekOf('2026-11-07'),
      );

      expect(counts, {'a': 2});
    });
  });

  group('publishing', () {
    const week = 3000;
    BoardCandidate candidate(String uid, int device, {int approved = 0}) =>
        BoardCandidate(
          uid: uid,
          name: 'n-$uid',
          device: device,
          approved: approved,
        );

    test('the first ten, without the hidden ones', () {
      final ranked = [
        for (var i = 0; i < 14; i++) candidate('u$i', 300 - i),
      ];

      final board = publishBoard(week: week, ranked: ranked, hidden: {'u1'});

      expect(board.points, hasLength(kBoardSize));
      expect(board.points.first, const BoardRow(name: 'n-u0', value: 300));
      expect(board.points.map((r) => r.name), isNot(contains('n-u1')));
      expect(board.points.last.name, 'n-u10');
    });

    test('nobody is listed for zero points', () {
      final board = publishBoard(
        week: week,
        ranked: [candidate('a', 40), candidate('b', 0)],
      );

      expect(board.points.map((r) => r.name), ['n-a']);
    });

    test('the sharing list counts approved messages', () {
      final board = publishBoard(
        week: week,
        ranked: [
          candidate('a', 300, approved: 1),
          candidate('b', 10, approved: 4),
          candidate('c', 200),
          candidate('d', 5, approved: 2),
        ],
        hidden: {'d'},
      );

      expect(board.sharing, const [
        BoardRow(name: 'n-b', value: 4),
        BoardRow(name: 'n-a', value: 1),
      ]);
    });

    test('what is published holds names and numbers, never a uid', () {
      final board = publishBoard(
        week: week,
        ranked: [
          const BoardCandidate(
            uid: 'secret-uid',
            name: 'سارة',
            device: 100,
            approved: 1,
          ),
        ],
      );
      final json = board.toJson();

      expect(json.toString(), isNot(contains('secret-uid')));
      final back = WeeklyBoard.fromJson(json);
      expect(back.week, week);
      expect(back.points, board.points);
      expect(back.sharing, board.sharing);
    });

    test('a reader entry survives a round trip', () {
      const entry = ScoreEntry(uid: 'a', week: 9, device: 120, name: 'سارة');
      expect(ScoreEntry.fromJson('a', entry.toJson()), entry);
      expect(entry.toJson().keys, ['week', 'device', 'name']);
    });
  });

  group('the reader\'s entry', () {
    final journey = JourneyRepository();
    final service = WeeklyBoardService();
    late InMemoryBoardStore board;
    late DateTime now;
    String? name;

    Future<void> settle([int ms = 60]) =>
        Future<void>.delayed(Duration(milliseconds: ms));

    Future<void> signIn(String uid) async {
      journey.setUser(uid);
      await settle();
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      now = DateTime(2026, 11, 7, 12);
      name = 'سارة';
      board = InMemoryBoardStore();
      await journey.debugReset(store: InMemoryJourneyStore(), clock: () => now);
      await service.debugReset(
        store: board,
        displayName: () => name,
        settle: const Duration(milliseconds: 20),
      );
      service.start();
    });

    tearDown(() async {
      await service.debugReset();
      await journey.debugReset();
    });

    test('a guest cannot join, and nothing is sent', () async {
      expect(service.join(useName: false), isFalse);
      journey.recordFullRead(1, seconds: 60);
      await settle();

      expect(board.writes, 0);
      expect(service.membership.value, isNull);
    });

    test('a reader who has not joined sends nothing', () async {
      await signIn('reader');
      journey.recordFullRead(1, seconds: 60);
      journey.recordMessageRead('m', hadithNumber: 1);
      await settle();

      expect(board.writes, 0);
      expect(board.scores, isEmpty);
    });

    test('joining sends this week, as «فاعل خير» by default', () async {
      await signIn('reader');
      journey.recordFullRead(1, seconds: 60);

      expect(service.join(useName: false), isTrue);
      await settle();

      expect(
        board.scores['reader'],
        ScoreEntry(
          uid: 'reader',
          week: boardWeekOf('2026-11-07'),
          device: 10,
          name: kAnonymousName,
        ),
      );
    });

    test('a reader can choose to show their own name', () async {
      await signIn('reader');
      service.join(useName: true);
      await settle();

      expect(board.scores['reader']!.name, 'سارة');
      expect(service.membership.value!.anonymous, isFalse);
    });

    test('readings after joining are sent once they settle', () async {
      await signIn('reader');
      service.join(useName: false);
      await settle();
      final before = board.writes;

      journey.recordMessageRead('a', hadithNumber: 1);
      journey.recordMessageRead('b', hadithNumber: 1);
      journey.recordFullRead(2, seconds: 60);
      await settle();

      expect(board.writes, before + 1, reason: 'a burst is one write');
      expect(board.scores['reader']!.device, 14);
    });

    test('nothing is sent when nothing changed', () async {
      await signIn('reader');
      service.join(useName: false);
      await settle();
      final before = board.writes;

      await service.syncNow();
      await service.syncNow();

      expect(board.writes, before);
    });

    test('leaving removes the entry and stops sending', () async {
      await signIn('reader');
      service.join(useName: false);
      await settle();

      service.leave();
      await settle();
      final before = board.writes;
      journey.recordFullRead(3, seconds: 60);
      await settle();

      expect(board.scores, isEmpty);
      expect(board.writes, before);
      expect(service.membership.value, isNull);
    });

    test('a reader who joined on another phone is found on sign-in', () async {
      board.scores['reader'] = ScoreEntry(
        uid: 'reader',
        week: boardWeekOf('2026-11-07'),
        device: 0,
        name: 'سارة',
      );

      await signIn('reader');

      expect(service.membership.value?.name, 'سارة');
    });

    test('another account on the same phone starts off the board', () async {
      await signIn('reader-a');
      service.join(useName: true);
      await settle();

      await signIn('reader-b');

      expect(service.membership.value, isNull);
      journey.recordFullRead(1, seconds: 60);
      await settle();
      expect(board.scores.keys, ['reader-a']);
    });

    test('a new week starts the entry again from nothing', () async {
      await signIn('reader');
      journey.recordFullRead(1, seconds: 60);
      service.join(useName: false);
      await settle();

      now = DateTime(2026, 11, 14, 9);
      await service.syncNow();

      expect(board.scores['reader']!.week, boardWeekOf('2026-11-14'));
      expect(board.scores['reader']!.device, 0);
    });

    test('a write that failed is tried again on the next change', () async {
      final flaky = _FlakyBoardStore();
      await service.debugReset(
        store: flaky,
        displayName: () => name,
        settle: const Duration(milliseconds: 20),
      );
      service.start();
      await signIn('reader');

      service.join(useName: false);
      await settle();
      expect(flaky.scores, isEmpty);

      await service.syncNow();
      expect(flaky.scores['reader'], isNotNull);
    });

    test('the published board is fetched when asked for', () async {
      board.board = const WeeklyBoard(
        week: 3000,
        points: [BoardRow(name: 'سارة', value: 210)],
        sharing: [],
      );

      final fetched = await service.loadBoard();

      expect(fetched?.points.single.name, 'سارة');
      expect(service.board.value, same(fetched));
    });
  });
}
