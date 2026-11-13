import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/data/journey/board_service.dart';
import 'package:hadith_app/data/journey/journey_copy.dart';
import 'package:hadith_app/data/journey/journey_engine.dart';
import 'package:hadith_app/data/journey/journey_models.dart';
import 'package:hadith_app/data/journey/journey_points.dart';
import 'package:hadith_app/data/journey/journey_repository.dart';
import 'package:hadith_app/data/journey/journey_store.dart';
import 'package:hadith_app/data/journey/memorization.dart';
import 'package:hadith_app/data/journey/weekly_board.dart';
import 'package:hadith_app/data/models/hadith.dart';
import 'package:hadith_app/data/repositories/hadith_repository.dart';
import 'package:hadith_app/data/services/notification_planner.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 5: memorizing and reviewing. The plan's numbers checked against
/// the real hadith texts, the review schedule step by step, points, the
/// repository, the review reminder and the board's memorization list.
void memoSuite() {
  final hadiths = HadithRepository();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await hadiths.load();
  });

  int words(String text) => text.trim().split(RegExp(r'\s+')).length;

  group('the hadiths as sessions', () {
    test('the six longest are learned in parts, the rest in one sitting', () {
      final split = [
        for (final hadith in hadiths.getAll())
          if (memoParts(hadith.text).length > 1) hadith.number,
      ]..sort();

      expect(split, [2, 4, 19, 24, 29, 36]);
      expect(
        hadiths.getAll().where((h) => words(h.text) <= 40),
        hasLength(26),
      );
    });

    test('no session is much longer than the limit', () {
      for (final hadith in hadiths.getAll()) {
        for (final part in memoParts(hadith.text)) {
          expect(words(part.join(' ')), lessThanOrEqualTo(90),
              reason: 'hadith ${hadith.number}');
        }
      }
    });

    test('no word is lost or moved between the parts', () {
      for (final hadith in hadiths.getAll()) {
        final rejoined = [
          for (final part in memoParts(hadith.text)) ...part,
        ].join(' ');
        expect(
          rejoined.split(RegExp(r'\s+')),
          hadith.text.trim().split(RegExp(r'\s+')),
          reason: 'hadith ${hadith.number}',
        );
      }
    });

    test('a sentence is never a lone word or two', () {
      for (final hadith in hadiths.getAll()) {
        final sentences = memoSentences(hadith.text);
        if (sentences.length == 1) continue;
        for (final sentence in sentences) {
          expect(words(sentence), greaterThanOrEqualTo(3),
              reason: 'hadith ${hadith.number}: $sentence');
        }
      }
    });

    test('a hadith with no punctuation is one sentence', () {
      expect(memoSentences('لا يؤمن أحدكم حتى يحب لأخيه'), hasLength(1));
    });
  });

  group('the narrator and the source are learned with it', () {
    List<String> wordsOf(List<MemoSentence> sentences) => [
          for (final s in sentences) ...s.text.trim().split(RegExp(r'\s+')),
        ];

    test('every hadith has both to learn', () {
      for (final hadith in hadiths.getAll()) {
        expect(hadith.isnad.trim(), isNotEmpty, reason: '${hadith.number}');
        expect(hadith.mukhrij.trim(), isNotEmpty, reason: '${hadith.number}');
      }
    });

    test('a hadith takes as many sessions as before', () {
      for (final hadith in hadiths.getAll()) {
        expect(
          memoPassage(hadith).length,
          memoParts(hadith.text).length,
          reason: 'hadith ${hadith.number}',
        );
      }
    });

    test('the narrator opens the first part, the source closes the last', () {
      for (final hadith in hadiths.getAll()) {
        final parts = memoPassage(hadith);
        final reason = 'hadith ${hadith.number}';

        expect(parts.first.first.line, MemoLine.narrator, reason: reason);
        expect(
          parts.last.last,
          MemoSentence('رواه ${hadith.mukhrij.trim()}', MemoLine.source),
          reason: reason,
        );
        for (final part in parts.skip(1)) {
          expect(part.map((s) => s.line), isNot(contains(MemoLine.narrator)),
              reason: reason);
        }
        for (final part in parts.take(parts.length - 1)) {
          expect(part.map((s) => s.line), isNot(contains(MemoLine.source)),
              reason: reason);
        }
      }
    });

    test('every word is there once, in reading order', () {
      for (final hadith in hadiths.getAll()) {
        final all = [for (final part in memoPassage(hadith)) ...part];
        expect(
          wordsOf(all),
          [
            ...hadith.isnad.trim().split(RegExp(r'\s+')),
            ...hadith.text.trim().split(RegExp(r'\s+')),
            'رواه',
            ...hadith.mukhrij.trim().split(RegExp(r'\s+')),
          ],
          reason: 'hadith ${hadith.number}',
        );
      }
    });

    test('a session stays a session with them', () {
      for (final hadith in hadiths.getAll()) {
        for (final part in memoPassage(hadith)) {
          expect(wordsOf(part).length, lessThanOrEqualTo(110),
              reason: 'hadith ${hadith.number}');
        }
      }
    });

    test('a hadith with neither is its text alone', () {
      const bare = Hadith(
        number: 99,
        title: 't',
        text: 'إنما الأعمال بالنيات، وإنما لكل امرئ ما نوى.',
        explanation: '',
      );
      expect(memoPassage(bare), [
        [
          for (final s in memoSentences(bare.text))
            MemoSentence(s, MemoLine.matn),
        ],
      ]);
    });
  });

  group('the review load the plan promises', () {
    // A new hadith every three days, every review remembered.
    final load = simulateReviewLoad();

    test('never more than two reviews a day', () {
      expect(load.reduce((a, b) => a > b ? a : b), 2);
    });

    test('a review on 142 of the first 180 days', () {
      expect(load.take(180).where((n) => n > 0), hasLength(142));
    });

    test('the last review falls on day 275', () {
      expect(load.lastIndexWhere((n) => n > 0), 275);
    });
  });

  group('one hadith, from learning to kept', () {
    const day = '2026-11-07';

    test('parts are counted until the last one memorizes it', () {
      var memo = const MemoProgress();
      memo = afterPartLearned(memo, totalParts: 3, today: day);
      expect(memo.isLearning, isTrue);
      expect(memo.parts, 1);
      expect(memo.due, isNull);

      memo = afterPartLearned(memo, totalParts: 3, today: day);
      memo = afterPartLearned(memo, totalParts: 3, today: day);
      expect(memo.isMemorized, isTrue);
      expect(memo.box, 0);
      expect(memo.due, '2026-11-08');
      expect(memo.memorizedOn, day);
    });

    test('remembered every time: reviews after 1, 3, 7, 16, 35, 90 days', () {
      var memo = afterPartLearned(
        const MemoProgress(),
        totalParts: 1,
        today: day,
      );
      final dues = <String>[];
      while (!memo.isKept) {
        dues.add(memo.due!);
        memo = afterReview(memo, remembered: true, today: memo.due!);
      }

      expect(dues, [
        '2026-11-08',
        '2026-11-11',
        '2026-11-18',
        '2026-12-04',
        '2027-01-08',
        '2027-04-08',
      ]);
      expect(memo.due, isNull);
      expect(memo.misses, 0);
    });

    test('forgetting steps back one, never below the first', () {
      const atThree = MemoProgress(parts: 1, box: 3, due: day);
      final back = afterReview(atThree, remembered: false, today: day);
      expect(back.box, 2);
      expect(back.due, dayKeyPlus(day, kReviewIntervals[2]));
      expect(back.misses, 1);

      const atFirst = MemoProgress(parts: 1, box: 0, due: day);
      expect(afterReview(atFirst, remembered: false, today: day).box, 0);
    });

    test('a kept hadith and one still learning are left alone', () {
      const kept = MemoProgress(parts: 1, box: 6);
      expect(afterReview(kept, remembered: false, today: day), kept);
      const learning = MemoProgress(parts: 1);
      expect(afterReview(learning, remembered: true, today: day), learning);
    });

    test('the longest waiting is reviewed first', () {
      final due = dueReviews({
        5: const MemoProgress(box: 1, due: '2026-11-06'),
        3: const MemoProgress(box: 1, due: '2026-11-07'),
        9: const MemoProgress(box: 1, due: '2026-11-05'),
        1: const MemoProgress(box: 1, due: '2026-11-08'),
        2: const MemoProgress(parts: 1),
      }, day);
      expect(due, [9, 5, 3]);
    });

    test('words are hidden a third, then two thirds, then all', () {
      expect(hiddenWords(6, 0), everyElement(isFalse));
      expect(hiddenWords(6, 1), [false, true, false, false, true, false]);
      expect(hiddenWords(6, 2), [false, true, true, false, true, true]);
      expect(hiddenWords(6, 3), everyElement(isTrue));
    });
  });

  group('stored as facts', () {
    test('memorization survives a round trip', () {
      const memo = MemoProgress(
        parts: 2,
        box: 3,
        due: '2026-12-01',
        misses: 1,
        memorizedOn: '2026-11-07',
      );
      expect(MemoProgress.fromJson(memo.toJson()), memo);

      final data = JourneyData.fromDocs({
        'memo': {'7': memo.toJson()},
      }, const []);
      expect(data.memoOf(7), memo);
      expect(data.memorizedCount, 1);
    });

    test('the day keeps parts, new hadiths and reviews', () {
      const day = JourneyDay(memoParts: [2], memorized: [13], reviewed: [5]);
      final back = JourneyDay.fromJson(day.toJson());
      expect(back.memoParts, [2]);
      expect(back.memorized, [13]);
      expect(back.reviewed, [5]);
    });

    test('memorizing or reviewing keeps the streak', () {
      expect(const JourneyDay(memoParts: [2]).isPresent, isTrue);
      expect(const JourneyDay(reviewed: [5]).isPresent, isTrue);
    });
  });

  group('points', () {
    test('a new hadith is 15, once a day', () {
      expect(dayPoints(const JourneyDay(memorized: [1])), 15);
      expect(dayPoints(const JourneyDay(memorized: [1, 2])), 15);
    });

    test('a due review is 3, five a day', () {
      expect(dayPoints(const JourneyDay(reviewed: [1])), 3);
      expect(dayPoints(const JourneyDay(reviewed: [1, 2, 3, 4, 5, 6])), 15);
    });

    test('learning a part earns nothing until the hadith is memorized', () {
      expect(dayPoints(const JourneyDay(memoParts: [2])), 0);
    });

    test('a week of memorizing is 210 at most', () {
      final data = JourneyData(days: {
        for (var i = 0; i < 7; i++)
          dayKeyPlus('2026-11-07', i): const JourneyDay(
            memorized: [1],
            reviewed: [1, 2, 3, 4, 5, 6, 7],
          ),
      });
      expect(weekMemoPoints(data, '2026-11-07'), PointRules.memoWeekCap);
      expect(PointRules.memoWeekCap, 210);
    });
  });

  group('the repository', () {
    final journey = JourneyRepository();
    late InMemoryJourneyStore store;
    late DateTime now;

    int partsOf(int number) =>
        memoParts(hadiths.getByNumber(number)!.text).length;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = InMemoryJourneyStore();
      now = DateTime(2026, 11, 7, 12);
      await journey.debugReset(store: store, clock: () => now);
      journey.setUser('reader');
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });

    tearDown(journey.debugReset);

    test('a short hadith is memorized in one session', () async {
      final outcome = journey.learnPart(13, totalParts: partsOf(13));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(outcome.memorized, isTrue);
      expect(outcome.milestone, 1);
      final saved = store.dataOf('reader');
      expect(saved.memoOf(13).due, '2026-11-08');
      expect(saved.days['2026-11-07']!.memorized, [13]);
      expect(saved.seen, contains(memoMilestoneId(1)));
      expect(journey.thisWeekPoints.total, 15);
      expect(journey.streak.current, 1);
    });

    test('the fifth and tenth hadith memorized bring their messages', () {
      final short = [
        for (var n = 1; n <= 42; n++)
          if (partsOf(n) == 1) n,
      ].take(10).toList();
      final milestones = [
        for (final n in short) journey.learnPart(n, totalParts: 1).milestone,
      ];
      expect(milestones, [1, null, null, null, 5, null, null, null, null, 10]);
      expect(journey.data.memorizedCount, 10);
    });

    test('a long one is learned part by part', () {
      expect(partsOf(2), 3);
      final first = journey.learnPart(2, totalParts: 3);
      expect(first.memorized, isFalse);
      expect(first.progress.parts, 1);
      expect(journey.data.days['2026-11-07']!.memoParts, [2]);
      expect(journey.thisWeekPoints.total, 0);

      now = DateTime(2026, 11, 8, 12);
      journey.learnPart(2, totalParts: 3);
      final last = journey.learnPart(2, totalParts: 3);
      expect(last.memorized, isTrue);
      expect(journey.data.memoOf(2).due, '2026-11-09');
    });

    test('the first-hadith milestone comes once', () {
      journey.learnPart(13, totalParts: 1);
      final second = journey.learnPart(1, totalParts: partsOf(1));
      expect(second.milestone, isNull);
    });

    test('a hadith already memorized is not learned again', () {
      journey.learnPart(13, totalParts: 1);
      final again = journey.learnPart(13, totalParts: 1);
      expect(again.progress, journey.data.memoOf(13));
      expect(journey.data.days['2026-11-07']!.memorized, [13]);
    });

    test('a review that is not due is practice and changes nothing', () {
      journey.learnPart(13, totalParts: 1);
      final early = journey.review(13, remembered: true);
      expect(early.counted, isFalse);
      expect(journey.data.memoOf(13).box, 0);
      expect(journey.data.days['2026-11-07']!.reviewed, isEmpty);
    });

    test('a due review moves it on and earns 3', () {
      journey.learnPart(13, totalParts: 1);
      now = DateTime(2026, 11, 8, 12);
      expect(journey.dueReviews, [13]);

      final outcome = journey.review(13, remembered: true);
      expect(outcome.counted, isTrue);
      expect(outcome.progress.box, 1);
      expect(outcome.progress.due, '2026-11-11');
      expect(journey.dueReviews, isEmpty);
      expect(journey.data.days['2026-11-08']!.reviewed, [13]);
      expect(journey.thisWeekPoints.total, 15 + 3);
    });

    test('saying it was forgotten still earns the review', () {
      journey.learnPart(13, totalParts: 1);
      now = DateTime(2026, 11, 8, 12);
      final outcome = journey.review(13, remembered: false);
      expect(outcome.counted, isTrue);
      expect(outcome.progress.misses, 1);
      expect(outcome.progress.due, '2026-11-09');
      expect(journey.thisWeekPoints.total, 15 + 3);
    });

    test('five memorized is a milestone', () {
      for (final n in [13, 1, 7, 9, 15]) {
        final outcome = journey.learnPart(n, totalParts: partsOf(n));
        if (n == 15) expect(outcome.milestone, 5);
      }
      expect(journey.data.memorizedCount, 5);
    });

    test('a guest\'s memorization joins the account at sign-in', () async {
      journey.setUser(null);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      journey.learnPart(13, totalParts: 1);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      journey.setUser('reader-2');
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(journey.data.memoOf(13).isMemorized, isTrue);
      expect(store.dataOf('reader-2').memoOf(13).isMemorized, isTrue);
    });
  });

  group('the review reminder', () {
    ReminderFacts facts(JourneyData data) => ReminderFacts(
          signedIn: true,
          data: data,
          hadithTitle: (n) => hadiths.getByNumber(n)?.title,
          hadithMinutes: (_) => 2,
        );

    const reading = JourneyData(
      days: {
        '2026-11-07': JourneyDay(messages: ['m'])
      },
      memo: {13: MemoProgress(parts: 1, box: 0, due: '2026-11-08')},
    );

    test('a morning with a review due asks for it, and opens it', () {
      final reminder = planReminder(
        facts(reading),
        at: DateTime(2026, 11, 8, 8, 30),
        slot: ReminderSlot.morning,
      )!;
      final title = hadiths.getByNumber(13)!.title;

      expect(reminder.title, 'مراجعة قصيرة');
      expect(reminder.body, JourneyCopy.reviewDue(title).body);
      expect(reminder.payload, reviewPayload(13));
      expect(reviewOfPayload(reminder.payload), 13);
      expect(hadithOfPayload(reminder.payload), isNull);
    });

    test('the evening is unchanged', () {
      final reminder = planReminder(
        facts(reading),
        at: DateTime(2026, 11, 8, 20),
        slot: ReminderSlot.evening,
      );
      expect(reminder?.title, isNot('مراجعة قصيرة'));
    });

    test('a morning with nothing due is the ordinary one', () {
      final reminder = planReminder(
        facts(reading),
        at: DateTime(2026, 11, 7, 8, 30),
        slot: ReminderSlot.morning,
      );
      expect(reminder?.title, isNot('مراجعة قصيرة'));
    });

    test('the plan is rebuilt when a review date moves', () {
      final moved = JourneyData(
        days: reading.days,
        memo: {13: const MemoProgress(parts: 1, box: 1, due: '2026-11-11')},
      );
      expect(
        reminderPlanKey(facts(reading), '2026-11-07'),
        isNot(reminderPlanKey(facts(moved), '2026-11-07')),
      );
    });
  });

  group('the board\'s memorization list', () {
    const week = 3000;

    test('an entry carries memorization points only once there are some', () {
      const none = ScoreEntry(uid: 'a', week: 1, device: 10, name: 'n');
      const some =
          ScoreEntry(uid: 'a', week: 1, device: 10, name: 'n', memo: 18);
      expect(none.toJson().containsKey('memo'), isFalse);
      expect(ScoreEntry.fromJson('a', some.toJson()), some);
    });

    test('it is ranked by memorization and publishes names only', () {
      final ranked = rankCandidates(week: week, scores: [
        const ScoreEntry(uid: 'a', week: week, device: 300, name: 'سارة'),
        const ScoreEntry(
            uid: 'b', week: week, device: 40, name: 'نور', memo: 30),
        const ScoreEntry(
            uid: 'c', week: week, device: 60, name: 'فاعل خير', memo: 45),
        const ScoreEntry(
            uid: 'd', week: week, device: 60, name: 'مخفي', memo: 90),
      ]);
      final board = publishBoard(week: week, ranked: ranked, hidden: {'d'});

      expect(board.memo.map((r) => r.name), ['فاعل خير', 'نور']);
      expect(board.memo.map((r) => r.value), everyElement(0));
      expect(WeeklyBoard.fromJson(board.toJson()).memo, board.memo);
    });

    test('the phone sends this week\'s memorization points', () async {
      final journey = JourneyRepository();
      final service = WeeklyBoardService();
      final board = InMemoryBoardStore();
      SharedPreferences.setMockInitialValues({});
      await journey.debugReset(
        store: InMemoryJourneyStore(),
        clock: () => DateTime(2026, 11, 7, 12),
      );
      await service.debugReset(
        store: board,
        displayName: () => null,
        settle: const Duration(milliseconds: 10),
      );
      service.start();
      addTearDown(() async {
        await service.debugReset();
        await journey.debugReset();
      });
      journey.setUser('reader');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      service.join(useName: false);
      journey.learnPart(13, totalParts: 1);
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(board.scores['reader']!.memo, 15);
      expect(board.scores['reader']!.device, 15);
    });
  });
}
