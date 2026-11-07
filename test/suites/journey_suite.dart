import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/data/journey/journey_copy.dart';
import 'package:hadith_app/data/journey/journey_engine.dart';
import 'package:hadith_app/data/journey/journey_models.dart';
import 'package:hadith_app/data/journey/journey_repository.dart';
import 'package:hadith_app/data/journey/journey_store.dart';
import 'package:hadith_app/data/journey/reading_tracker.dart';
import 'package:hadith_app/data/models/hadith.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared between the host and device entry points, like the notification
/// suites: `flutter test` cannot run on the main development machine.
JourneyDay _present() => const JourneyDay(messages: ['m']);

Map<String, JourneyDay> _run(String from, int length) => {
      for (var i = 0; i < length; i++) dayKeyPlus(from, i): _present(),
    };

void journeySuite() {
  group('reading day', () {
    test('turns over at 03:00, not midnight', () {
      expect(journeyDayKey(DateTime(2026, 11, 7, 2, 59)), '2026-11-06');
      expect(journeyDayKey(DateTime(2026, 11, 7, 3)), '2026-11-07');
    });

    test('dayKeyPlus crosses months and years', () {
      expect(dayKeyPlus('2026-12-31', 1), '2027-01-01');
      expect(dayKeyPlus('2027-01-01', -1), '2026-12-31');
      expect(dayKeyPlus('2028-02-28', 1), '2028-02-29');
    });

    test('a week starts on Saturday', () {
      expect(weekStartKey('2026-11-07'), '2026-11-07', reason: 'a Saturday');
      expect(weekStartKey('2026-11-06'), '2026-10-31', reason: 'a Friday');
      expect(weekStartKey('2026-11-08'), '2026-11-07', reason: 'a Sunday');
    });
  });

  group('streak', () {
    test('no days is no streak', () {
      final s = computeStreak(const {}, '2026-11-06');
      expect(s.current, 0);
      expect(s.presentToday, isFalse);
    });

    test('counts consecutive days up to today', () {
      final s = computeStreak(_run('2026-11-02', 5), '2026-11-06');
      expect(s.current, 5);
      expect(s.best, 5);
      expect(s.presentToday, isTrue);
    });

    test('today not read yet is not a miss', () {
      final s = computeStreak(_run('2026-11-01', 5), '2026-11-06');
      expect(s.current, 5);
      expect(s.presentToday, isFalse);
    });

    test('a miss with no grace day ends the streak but keeps the best', () {
      final days = {..._run('2026-11-01', 3), '2026-11-05': _present()};
      final s = computeStreak(days, '2026-11-05');
      expect(s.current, 1);
      expect(s.best, 3);
    });

    test('a grace day is earned at 7 and covers one miss', () {
      final days = {
        ..._run('2026-11-01', 7),
        // The 8th is missed.
        '2026-11-09': _present(),
      };
      final s = computeStreak(days, '2026-11-09');
      expect(s.current, 8,
          reason: 'the covered day adds nothing, the 9th does');
      expect(s.graceBanked, 0);
    });

    test('a second miss with the grace day spent ends it', () {
      final days = {
        ..._run('2026-11-01', 7),
        '2026-11-10': _present(),
      };
      final s = computeStreak(days, '2026-11-10');
      expect(s.current, 1);
    });

    test('no more than two grace days wait in reserve', () {
      final s = computeStreak(_run('2026-10-01', 30), '2026-10-30');
      expect(s.graceBanked, kMaxGraceDays);
    });

    test('a reading day needs a message or a hadith', () {
      final days = {'2026-11-06': const JourneyDay(seconds: 90)};
      expect(computeStreak(days, '2026-11-06').current, 0);
    });

    test('a stored best from older years is kept', () {
      final s =
          computeStreak(_run('2026-11-05', 2), '2026-11-06', storedBest: 40);
      expect(s.best, 40);
    });
  });

  group('day steps and next hadith', () {
    test('the three steps come from the day', () {
      const day = JourneyDay(messages: ['a'], hadiths: [3]);
      const data = JourneyData(days: {'2026-11-06': day});
      final steps = DaySteps.of(data, '2026-11-06');
      expect(steps.message, isTrue);
      expect(steps.hadith, isTrue);
      expect(steps.wrote, isFalse);
      expect(steps.done, 2);
    });

    test("today's message picks the hadith while it is unread", () {
      const data = JourneyData(days: {
        '2026-11-06': JourneyDay(messages: ['a'], messageHadith: 13),
      });
      expect(nextHadith(data, '2026-11-06'), 13);
    });

    test('a finished hadith moves on to the first unread one', () {
      const data = JourneyData(
        hadith: {
          1: HadithProgress(fullOn: '2026-11-05'),
          13: HadithProgress(fullOn: '2026-11-06'),
        },
        days: {
          '2026-11-06': JourneyDay(messages: ['a'], messageHadith: 13),
        },
      );
      expect(nextHadith(data, '2026-11-06'), 2);
    });

    test('nothing is next once every hadith is read', () {
      final data = JourneyData(hadith: {
        for (var n = 1; n <= 42; n++)
          n: const HadithProgress(fullOn: '2026-11-06'),
      });
      expect(nextHadith(data, '2026-11-06'), isNull);
    });
  });

  group('week against week', () {
    test('adds up each Saturday-to-Friday week in minutes', () {
      const data = JourneyData(days: {
        '2026-11-07': JourneyDay(seconds: 120),
        '2026-11-13': JourneyDay(seconds: 180),
        '2026-11-06': JourneyDay(seconds: 60),
        '2026-10-30': JourneyDay(seconds: 9999),
      });
      final weeks = WeekCompare.of(data, '2026-11-10');
      expect(weeks.thisWeek, 5);
      expect(weeks.lastWeek, 1);
    });
  });

  group('milestones', () {
    test('fire once at each mark', () {
      expect(newMilestones(4, const {}), isEmpty);
      expect(newMilestones(5, const {}), [5]);
      expect(newMilestones(5, const {'read5'}), isEmpty);
      expect(newMilestones(10, const {'read5'}), [10]);
    });

    test('a jump after joining an account lists every one passed', () {
      expect(newMilestones(21, const {}), [5, 10, 20]);
    });
  });

  group('words', () {
    test('counted days take the right Arabic form', () {
      expect(arabicDayCount(1), 'يوم واحد');
      expect(arabicDayCount(2), 'يومين');
      expect(arabicDayCount(3), '٣ أيام');
      expect(arabicDayCount(10), '١٠ أيام');
      expect(arabicDayCount(11), '١١ يوماً');
      expect(arabicDayCount(42), '٤٢ يوماً');
      expect(arabicDayCount(100), '١٠٠ يوم');
      expect(arabicDayCount(12, consecutive: true), '١٢ يوماً متتالية');
    });

    test('every milestone has a message and uses its details', () {
      for (final mark in kJourneyMilestones) {
        final text =
            JourneyCopy.milestone(mark, lastTitle: 'لا تغضب', days: 42);
        expect(text.title, isNotEmpty);
        expect(text.body, isNot(contains('!')));
      }
      expect(
        JourneyCopy.milestone(10, lastTitle: 'لا تغضب', days: 9).body,
        contains('لا تغضب'),
      );
      expect(
        JourneyCopy.milestone(42, lastTitle: 'x', days: 42).body,
        contains('٤٢ يوماً'),
      );
    });
  });

  group('reading rule', () {
    test('asks for the speed limit, with a floor for short paragraphs', () {
      expect(ReadingRule.neededFor(260), const Duration(minutes: 1));
      expect(ReadingRule.neededFor(2), ReadingRule.minimumPerParagraph);
    });

    test('splits on blank lines and falls back to the whole text', () {
      expect(ReadingRule.paragraphs('أ\n\nب\n \nج'), ['أ', 'ب', 'ج']);
      expect(ReadingRule.paragraphs('سطر واحد'), ['سطر واحد']);
    });

    test('counts words on any whitespace', () {
      expect(ReadingRule.wordCount(' أ  ب\nج '), 3);
      expect(ReadingRule.wordCount('  '), 0);
    });
  });

  group('ReadingTracker', () {
    test('time goes to the first unread paragraph in reading order', () {
      final tracker = ReadingTracker([260, 260]);
      tracker.tick(const Duration(seconds: 30), [1, 0]);
      expect(tracker.progressOf(0), closeTo(0.5, 0.001));
      expect(tracker.progressOf(1), 0);
    });

    test('leftover time passes to the next paragraph', () {
      final tracker = ReadingTracker([26, 260]);
      tracker.tick(const Duration(seconds: 12), [0, 1]);
      expect(tracker.isRead(0), isTrue);
      expect(tracker.progressOf(1), closeTo(0.1, 0.001));
    });

    test('a skimmed paragraph stays unread and is the one to return to', () {
      final tracker = ReadingTracker([260, 260, 260]);
      tracker.tick(const Duration(minutes: 1), [0]);
      tracker.tick(const Duration(minutes: 1), [2]);
      expect(tracker.isComplete, isFalse);
      expect(tracker.firstUnread, 1);
    });

    test('a page section asks at least three seconds', () {
      final tracker = ReadingTracker.sections([2, 260]);
      expect(tracker.neededAt(0), ReadingRule.minimumPerSection);
      expect(tracker.neededAt(1), const Duration(minutes: 1));
      tracker.tick(const Duration(milliseconds: 2900), [0]);
      expect(tracker.isRead(0), isFalse);
    });

    test('the page counts the hadith and its short explanation only', () {
      const hadith = Hadith(
        number: 99,
        title: 't',
        isnad: 'عن أبي',
        text: 'نص الحديث هنا',
        shortExplanation: 'خلاصة من أربع كلمات',
        explanation: 'شرح طويل جداً لا يحسب في الوقت المطلوب',
      );
      expect(ReadingRule.pageSections(hadith), [5, 4]);
      expect(ReadingRule.minutesFor(hadith), 1);
    });

    test('a hadith with no short explanation asks for its text alone', () {
      const hadith = Hadith(
        number: 98,
        title: 't',
        text: 'نص',
        explanation: 'شرح',
      );
      expect(ReadingRule.pageSections(hadith), [1]);
    });

    test('completes once every paragraph has had its time', () {
      final tracker = ReadingTracker([26, 26]);
      tracker.tick(const Duration(seconds: 12), [0, 1]);
      expect(tracker.isComplete, isTrue);
      expect(tracker.firstUnread, isNull);
    });

    test('nothing on screen adds no time', () {
      final tracker = ReadingTracker([26]);
      tracker.tick(const Duration(minutes: 5), const []);
      expect(tracker.activeSeconds, 0);
      expect(tracker.isComplete, isFalse);
    });

    test('a screen reader can be marked read outright', () {
      final tracker = ReadingTracker([260, 260])..markAllRead();
      expect(tracker.isComplete, isTrue);
    });
  });

  group('JourneyData', () {
    test('applying a message twice counts it once', () {
      const event = JourneyEvent(dayKey: '2026-11-06', messageId: 'a');
      final data = JourneyData.empty.apply(event).apply(event);
      expect(data.days['2026-11-06']!.messages, ['a']);
    });

    test('a re-read keeps the first date and adds a read', () {
      final data = JourneyData.empty
          .apply(const JourneyEvent(dayKey: '2026-11-01', fullHadith: 7))
          .apply(const JourneyEvent(dayKey: '2026-11-06', fullHadith: 7));
      expect(data.progressOf(7).fullOn, '2026-11-01');
      expect(data.progressOf(7).reads, 2);
      expect(data.completeCount, 1);
    });

    test('survives a trip through JSON', () {
      final data = JourneyData.empty.apply(const JourneyEvent(
        dayKey: '2026-11-06',
        messageId: 'a',
        messageHadith: 5,
        fullHadith: 7,
        seconds: 90,
        seen: ['read5'],
        bestStreak: 4,
        startedOn: '2026-11-06',
      ));
      final back = JourneyData.fromJson(data.toJson());
      expect(back.startedOn, '2026-11-06');
      expect(back.progressOf(7).isComplete, isTrue);
      expect(back.days['2026-11-06']!.messageHadith, 5);
      expect(back.days['2026-11-06']!.seconds, 90);
      expect(back.seen, {'read5'});
      expect(back.bestStreak, 4);
    });

    test('malformed docs read as nothing rather than throwing', () {
      final data = JourneyData.fromDocs(
        {'hadith': 'oops', 'seen': null, 'records': 3},
        [
          {'days': 7},
        ],
      );
      expect(data.isEmpty, isTrue);
    });
  });

  group('JourneyRepository', () {
    late InMemoryJourneyStore store;
    late JourneyRepository repo;
    var now = DateTime(2026, 11, 6, 12);

    Future<void> signIn(String? uid) async {
      repo.setUser(uid);
      await pumpEventQueue();
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = InMemoryJourneyStore();
      repo = JourneyRepository();
      now = DateTime(2026, 11, 6, 12);
      await repo.debugReset(store: store, clock: () => now);
    });

    test('a guest keeps reading on the phone, across restarts', () async {
      repo.recordFullRead(1, seconds: 60);
      await pumpEventQueue();

      await repo.debugReset(store: store, clock: () => now);
      await pumpEventQueue();
      expect(repo.data.completeCount, 1);
    });

    test('a corrupt guest copy does not stop the app', () async {
      SharedPreferences.setMockInitialValues({'journey.guest': '{not json'});
      await repo.debugReset(store: store, clock: () => now);
      expect(repo.data.isEmpty, isTrue);
    });

    test('signing in moves a guest reading into the account, once', () async {
      repo.recordFullRead(1, seconds: 60);
      await pumpEventQueue();

      await signIn('a');
      expect(repo.data.completeCount, 1);
      expect(store.dataOf('a').completeCount, 1);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('journey.guest'), isNull);
    });

    test('reading while signed in lands in that account', () async {
      await signIn('a');
      repo.recordFullRead(3, seconds: 60);
      await pumpEventQueue();
      expect(store.dataOf('a').progressOf(3).isComplete, isTrue);
      expect(store.dataOf('a').startedOn, '2026-11-06');
    });

    test('two accounts on one phone never see each other', () async {
      await signIn('a');
      repo.recordFullRead(3, seconds: 60);
      await pumpEventQueue();

      await signIn('b');
      expect(repo.data.completeCount, 0);

      await signIn('a');
      expect(repo.data.completeCount, 1);
    });

    test('signing out leaves nothing of the account on screen', () async {
      await signIn('a');
      repo.recordFullRead(3, seconds: 60);
      await pumpEventQueue();

      await signIn(null);
      expect(repo.data.isEmpty, isTrue);
    });

    test('a new phone sees the same journey', () async {
      await signIn('a');
      repo.recordFullRead(3, seconds: 60);
      await pumpEventQueue();

      // Same store, fresh repository state: what a second phone starts from.
      await repo.debugReset(store: store, clock: () => now);
      await signIn('a');
      expect(repo.data.progressOf(3).isComplete, isTrue);
    });

    test('reading a message keeps the streak without growing the tree',
        () async {
      repo.recordMessageRead('m1', hadithNumber: 13);
      expect(repo.streak.current, 1);
      expect(repo.todaySteps.message, isTrue);
      expect(repo.data.completeCount, 0);
      expect(repo.nextHadithNumber, 13);
    });

    test('the same message twice in a day writes once', () async {
      await signIn('a');
      repo.recordMessageRead('m1', hadithNumber: 13);
      repo.recordMessageRead('m1', hadithNumber: 13);
      await pumpEventQueue();
      expect(store.dataOf('a').days['2026-11-06']!.messages, ['m1']);
    });

    test('the outcome reports a first read, then a re-read', () {
      final first = repo.recordFullRead(1, seconds: 60);
      final again = repo.recordFullRead(1, seconds: 60);
      expect(first.firstTime, isTrue);
      expect(again.firstTime, isFalse);
      expect(again.completeCount, 1);
    });

    test('a milestone shows once, even from another phone', () async {
      await signIn('a');
      for (var n = 1; n <= 4; n++) {
        expect(repo.recordFullRead(n, seconds: 1).milestone, isNull);
      }
      expect(repo.recordFullRead(5, seconds: 1).milestone, 5);
      await pumpEventQueue();

      await repo.debugReset(store: store, clock: () => now);
      await signIn('a');
      expect(repo.recordFullRead(5, seconds: 1).milestone, isNull);
      expect(repo.recordFullRead(6, seconds: 1).milestone, isNull);
    });

    test('a longer streak is stored and flagged as a new best', () async {
      await signIn('a');
      repo.recordMessageRead('m1', hadithNumber: 1);
      now = now.add(const Duration(days: 1));
      final outcome = repo.recordFullRead(1, seconds: 60);
      await pumpEventQueue();
      expect(outcome.streak.current, 2);
      expect(outcome.newBest, isTrue);
      expect(store.dataOf('a').bestStreak, 2);
    });

    test('sending a message fills the last step of the day', () {
      repo.recordWrote();
      expect(repo.todaySteps.wrote, isTrue);
    });
  });
}
