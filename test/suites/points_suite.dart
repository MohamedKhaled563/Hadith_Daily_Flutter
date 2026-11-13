import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hadith_app/data/journey/journey_copy.dart';
import 'package:hadith_app/data/journey/journey_engine.dart';
import 'package:hadith_app/data/journey/journey_models.dart';
import 'package:hadith_app/data/journey/journey_points.dart';
import 'package:hadith_app/data/journey/journey_repository.dart';
import 'package:hadith_app/data/journey/journey_store.dart';
import 'package:hadith_app/data/services/notification_planner.dart';
import 'package:hadith_app/data/services/submission_approval_watcher.dart';
import 'package:hadith_app/features/community/my_submissions_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSubmissions implements SubmissionDataSource {
  List<ApprovedSubmission> approved = [];

  @override
  Future<List<ApprovedSubmission>> loadApproved(String uid) async => approved;

  @override
  Stream<void> pendingDecided(String uid) => const Stream.empty();
}

/// Phase 3: points, records, the Friday harvest and a writer's reach. Pure
/// logic and the repository on an in-memory store, so it runs the same on the
/// host and on a device.
void pointsSuite() {
  // A Saturday, so a week is the seven days from here.
  const saturday = '2026-11-07';
  String day(int offset) => dayKeyPlus(saturday, offset);

  JourneyDay reading({
    int messages = 0,
    int community = 0,
    int hadiths = 0,
    int shared = 0,
    int seconds = 0,
    int wrote = 0,
  }) =>
      JourneyDay(
        messages: [for (var i = 0; i < messages; i++) 'm$i'],
        community: [for (var i = 0; i < community; i++) 'c$i'],
        hadiths: [for (var i = 1; i <= hadiths; i++) i],
        shared: shared,
        seconds: seconds,
        wrote: wrote,
      );

  group('points for a day', () {
    test('each action is worth what the plan says', () {
      expect(dayPoints(reading(messages: 1)), 2);
      expect(dayPoints(reading(community: 1)), 1);
      expect(dayPoints(reading(hadiths: 1)), 10);
      expect(dayPoints(reading(shared: 1)), 2);
    });

    test('community reads stop counting after three a day', () {
      expect(dayPoints(reading(community: 3)), 3);
      expect(dayPoints(reading(community: 9)), 3);
    });

    test('hadiths stop counting after two a day', () {
      expect(dayPoints(reading(hadiths: 5)), 20);
    });

    test('shares count once a day', () {
      expect(dayPoints(reading(shared: 4)), 2);
    });

    test('nothing done is worth nothing', () {
      expect(dayPoints(const JourneyDay()), 0);
    });

    test('writing earns nothing until a moderator approves it', () {
      expect(dayPoints(reading(wrote: 3)), 0);
    });
  });

  group('points for a week', () {
    JourneyData week(Map<int, JourneyDay> days) =>
        JourneyData(days: {for (final e in days.entries) day(e.key): e.value});

    test('adds up the seven days from Saturday', () {
      final data = week({
        0: reading(messages: 1, hadiths: 1),
        6: reading(messages: 1),
        7: reading(hadiths: 2), // next Saturday, next week
      });

      expect(weekPoints(data, saturday).total, 14);
    });

    test('the phone can give at most 300 a week', () {
      final data = week({
        for (var i = 0; i < 7; i++)
          i: reading(messages: 10, community: 3, hadiths: 2, shared: 1),
      });

      expect(weekPoints(data, saturday).device, 300);
    });

    test('approved messages sit on top of the cap, three at most', () {
      final data = week({
        for (var i = 0; i < 7; i++)
          i: reading(messages: 10, community: 3, hadiths: 2, shared: 1),
      });

      final points = weekPoints(
        data,
        saturday,
        approvedOn: [day(1), day(2), day(3), day(4)],
      );

      expect(points.device, 300);
      expect(points.approved, 45);
      expect(points.total, 345);
    });

    test('an approval in another week does not count in this one', () {
      final points = weekPoints(
        JourneyData.empty,
        saturday,
        approvedOn: [day(-1), day(7)],
      );

      expect(points.approved, 0);
    });
  });

  group('the harvest numbers', () {
    test('the best run in a week counts only days in a row', () {
      final data = JourneyData(days: {
        day(0): reading(messages: 1),
        day(1): reading(hadiths: 1),
        // day(2) missed
        day(3): reading(messages: 1),
        day(4): reading(messages: 1),
        day(5): reading(messages: 1),
        // Writing alone does not count a day.
        day(6): reading(wrote: 1),
      });
      expect(bestRunInWeek(data, saturday, day(6)), 3);
      expect(bestRunInWeek(data, saturday, day(1)), 2,
          reason: 'only up to today');
      expect(bestRunInWeek(data, day(7), day(7)), 0, reason: 'a new week');
    });

    test('a run from last week does not carry into this one', () {
      final data = JourneyData(days: {
        for (var i = -5; i <= 1; i++) day(i): reading(messages: 1),
      });
      expect(bestRunInWeek(data, saturday, day(1)), 2);
    });

    test('all points add each week, each capped like the board', () {
      final data = JourneyData(days: {
        day(0): reading(messages: 1, hadiths: 1),
        day(7): reading(messages: 2),
        // A heavy week: 45 a day for seven days is 315, capped at 300.
        for (var i = 14; i < 21; i++)
          day(i): reading(messages: 10, hadiths: 2, shared: 1, community: 3),
      });
      expect(totalPoints(data), 12 + 4 + PointRules.deviceWeekCap);
    });

    test('approved messages add on top, three a week at most', () {
      final data = JourneyData(days: {day(0): reading(messages: 1)});
      final approvedOn = [day(1), day(2), day(3), day(4), day(8)];
      expect(
        totalPoints(data, approvedOn: approvedOn),
        2 + 3 * PointRules.approved + PointRules.approved,
      );
    });

    test('nothing read is nothing earned', () {
      expect(totalPoints(JourneyData.empty), 0);
      expect(bestRunInWeek(JourneyData.empty, saturday, day(3)), 0);
    });
  });

  group('personal records', () {
    test('each one is read from the days on file', () {
      final data = JourneyData(days: {
        day(0): reading(messages: 1, hadiths: 2, seconds: 600, wrote: 1),
        day(1): reading(messages: 1, hadiths: 1, seconds: 300),
        day(7): reading(messages: 1, seconds: 1200),
      });

      final records = journeyRecords(data, today: day(7));

      expect(records[JourneyRecord.weekMinutes], 20);
      expect(records[JourneyRecord.weekHadiths], 3);
      expect(records[JourneyRecord.weekDays], 2);
      expect(records[JourneyRecord.dayMinutes], 20);
      expect(records[JourneyRecord.dayHadiths], 2);
      expect(records[JourneyRecord.weekWrote], 1);
      // 2 + 20 on Saturday, 2 + 10 on Sunday.
      expect(records[JourneyRecord.weekPoints], 34);
      expect(records[JourneyRecord.streak], 2);
    });

    test('minutes are rounded as the week bar rounds them', () {
      final data =
          JourneyData(days: {day(0): reading(messages: 1, seconds: 150)});

      final records = journeyRecords(data, today: day(0));
      final week = WeekCompare.of(data, day(0));

      expect(records[JourneyRecord.weekMinutes], week.thisWeek);
      expect(records[JourneyRecord.dayMinutes], 3);
    });

    test('there are eight of them', () {
      expect(JourneyRecord.values, hasLength(8));
    });

    Map<JourneyRecord, RecordStanding> standing(
      JourneyRecord record, {
      required int past,
      required int current,
    }) =>
        {record: RecordStanding(past: past, current: current)};

    test('passing an earlier best is news', () {
      expect(
        brokenRecord(
          standing(JourneyRecord.weekMinutes, past: 10, current: 10),
          standing(JourneyRecord.weekMinutes, past: 10, current: 11),
        ),
        JourneyRecord.weekMinutes,
      );
    });

    test('a first week has nothing to beat', () {
      expect(
        brokenRecord(
          standing(JourneyRecord.weekMinutes, past: 0, current: 5),
          standing(JourneyRecord.weekMinutes, past: 0, current: 10),
        ),
        isNull,
      );
    });

    test('a week already ahead is not announced again', () {
      expect(
        brokenRecord(
          standing(JourneyRecord.weekMinutes, past: 10, current: 12),
          standing(JourneyRecord.weekMinutes, past: 10, current: 15),
        ),
        isNull,
      );
    });

    test('matching a record is not beating it', () {
      expect(
        brokenRecord(
          standing(JourneyRecord.weekHadiths, past: 3, current: 2),
          standing(JourneyRecord.weekHadiths, past: 3, current: 3),
        ),
        isNull,
      );
    });

    test('the streak is left to the longest-streak line', () {
      expect(
        brokenRecord(
          standing(JourneyRecord.streak, past: 0, current: 3),
          standing(JourneyRecord.streak, past: 0, current: 4),
        ),
        isNull,
      );
    });

    test('earlier weeks and this week are kept apart', () {
      final data = JourneyData(days: {
        day(0): reading(hadiths: 2, seconds: 600),
        day(7): reading(hadiths: 1, seconds: 120),
      });

      final standings = recordStandings(data, today: day(7));

      expect(standings[JourneyRecord.weekHadiths]!.past, 2);
      expect(standings[JourneyRecord.weekHadiths]!.current, 1);
      expect(standings[JourneyRecord.dayMinutes]!.past, 10);
      expect(standings[JourneyRecord.dayMinutes]!.current, 2);
    });
  });

  group('the Friday harvest', () {
    const friday = '2026-11-13';

    test('sums the week so far and last week', () {
      final data = JourneyData(days: {
        '2026-11-07': reading(messages: 1, seconds: 600),
        '2026-11-10': reading(hadiths: 1, seconds: 780),
        '2026-11-14': reading(messages: 1, seconds: 999), // after Friday
        '2026-11-01': reading(messages: 1, seconds: 1080), // last week
      });

      final harvest = harvestFor(data, friday);

      expect(harvest.days, 2);
      expect(harvest.minutes, 23);
      expect(harvest.lastWeekMinutes, 18);
    });

    test('carries the three numbers رحلتي shows for the week', () {
      final data = JourneyData(days: {
        '2026-11-11': reading(messages: 1),
        '2026-11-12': reading(messages: 1, hadiths: 1),
        '2026-11-13': reading(messages: 1),
      });

      final harvest = harvestFor(data, friday, approvedOn: ['2026-11-12']);

      expect(harvest.streak, 3);
      expect(harvest.bestRun, 3);
      expect(harvest.points, 2 + 12 + 2 + PointRules.approved);
      expect(
        JourneyCopy.harvestCaption(harvest, null),
        startsWith('هذا الأسبوع: استمرارية ٣ أيام، و٣١ نقطة'),
      );
    });

    ReminderFacts facts(JourneyData data) => ReminderFacts(
          signedIn: true,
          data: data,
          hadithTitle: (number) => 'الحديث $number',
          hadithMinutes: (_) => 2,
        );

    final week = JourneyData(days: {
      '2026-11-08': reading(messages: 1, seconds: 600),
      '2026-11-09': reading(messages: 1, seconds: 600),
      '2026-11-10': reading(messages: 1, seconds: 600),
      '2026-11-12': reading(messages: 1, seconds: 180),
      '2026-11-01': reading(messages: 1, seconds: 1080),
    });

    test('Friday morning carries it, with a tap to the journey', () {
      final reminder = planReminder(
        facts(week),
        at: DateTime(2026, 11, 13, 8, 30),
        slot: ReminderSlot.morning,
      )!;

      expect(reminder.title, 'حصاد الأسبوع');
      expect(reminder.body,
          '٤ أيام و٣٣ دقيقة مع الحديث. الأسبوع الماضي كانت ١٨ دقيقة.');
      expect(reminder.payload, harvestPayload);
    });

    test('Friday evening is unchanged', () {
      final reminder = planReminder(
        facts(week),
        at: DateTime(2026, 11, 13, 20),
        slot: ReminderSlot.evening,
      );

      expect(reminder?.title, isNot('حصاد الأسبوع'));
    });

    test('other mornings are unchanged', () {
      final reminder = planReminder(
        facts(week),
        at: DateTime(2026, 11, 12, 8, 30),
        slot: ReminderSlot.morning,
      );

      expect(reminder?.title, isNot('حصاد الأسبوع'));
    });

    test('a week with no reading gets no harvest', () {
      final reminder = planReminder(
        facts(JourneyData(days: {'2026-11-06': reading(messages: 1)})),
        at: DateTime(2026, 11, 13, 8, 30),
        slot: ReminderSlot.morning,
      );

      expect(reminder?.title, isNot('حصاد الأسبوع'));
    });

    test('a guest gets no harvest', () {
      final reminder = planReminder(
        ReminderFacts(
          signedIn: false,
          data: week,
          hadithTitle: (_) => 'x',
          hadithMinutes: (_) => 2,
        ),
        at: DateTime(2026, 11, 13, 8, 30),
        slot: ReminderSlot.morning,
      );

      expect(reminder, isNull);
    });
  });

  group('the day log', () {
    test('community reads and shares survive a round trip', () {
      final day = reading(community: 2, shared: 1);
      final back = JourneyDay.fromJson(day.toJson());

      expect(back.community, ['c0', 'c1']);
      expect(back.shared, 1);
    });

    test('a community post read twice counts once', () {
      final data = JourneyData.empty
          .apply(const JourneyEvent(dayKey: saturday, communityId: 'p'))
          .apply(const JourneyEvent(dayKey: saturday, communityId: 'p'));

      expect(data.days[saturday]!.community, ['p']);
    });

    test('reading a community post does not keep the streak on its own', () {
      final data = JourneyData.empty
          .apply(const JourneyEvent(dayKey: saturday, communityId: 'p'));

      expect(data.days[saturday]!.isPresent, isFalse);
    });
  });

  group('the repository', () {
    final journey = JourneyRepository();
    late InMemoryJourneyStore store;
    var now = DateTime(2026, 11, 7, 12);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = InMemoryJourneyStore();
      now = DateTime(2026, 11, 7, 12);
      await journey.debugReset(store: store, clock: () => now);
      journey.setUser('reader');
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });

    tearDown(journey.debugReset);

    test('records a community read once per post and day', () async {
      journey.recordCommunityRead('p');
      journey.recordCommunityRead('p');
      journey.recordCommunityRead('q');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(store.dataOf('reader').days[saturday]!.community, ['p', 'q']);
    });

    test('records a share', () async {
      journey.recordShared();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(store.dataOf('reader').days[saturday]!.shared, 1);
      expect(journey.thisWeekPoints.total, 2);
    });

    test('approvals count for this reader only', () {
      journey.setApprovedOn('someone-else', [saturday]);
      expect(journey.thisWeekPoints.approved, 0);

      journey.setApprovedOn('reader', [saturday]);
      expect(journey.thisWeekPoints.approved, 15);
    });

    test('last week is kept apart from this one', () async {
      now = DateTime(2026, 11, 6, 12);
      journey.recordMessageRead('old', hadithNumber: 1);
      now = DateTime(2026, 11, 7, 12);
      journey.recordMessageRead('new', hadithNumber: 2);

      expect(journey.thisWeekPoints.total, 2);
      expect(journey.lastWeekPoints.total, 2);
    });

    test('a record is announced the reading that beats it, and only then', () {
      // Last week: one hadith, ten minutes.
      journey.recordFullRead(1, seconds: 600);
      now = DateTime(2026, 11, 14, 12);

      // This week matches it, then passes it.
      expect(journey.recordFullRead(2, seconds: 60).record, isNull);
      expect(
        journey.recordFullRead(3, seconds: 60).record,
        JourneyRecord.weekHadiths,
      );
      // Already ahead: nothing more to announce.
      expect(journey.recordFullRead(4, seconds: 60).record, isNull);
    });

    test('a first week beats nothing', () {
      journey.recordFullRead(1, seconds: 600);
      final outcome = journey.recordFullRead(2, seconds: 10);

      expect(outcome.record, isNull);
    });
  });

  group('a writer\'s reach', () {
    test('is said in words that fit the number', () {
      expect(
        reachLine(timesShown: 0, likeCount: 0),
        'لم تصل إلى أحد بعد، وستأخذ دورها بين الرسائل',
      );
      expect(reachLine(timesShown: 1, likeCount: 0), 'وصلت إلى قارئ واحد');
      expect(
        reachLine(timesShown: 120, likeCount: 7),
        'وصلت إلى ١٢٠ قارئ · أعجبت ٧',
      );
    });

    test('a first check sets the baseline without announcing', () {
      const old = ApprovedSubmission(id: 'a', message: 'x', timesShown: 500);

      expect(newlyReached([old], null, milestone: 100), isEmpty);
    });

    test('passing 100 readers is announced once', () {
      const passed = ApprovedSubmission(id: 'a', message: 'x', timesShown: 101);
      const under = ApprovedSubmission(id: 'b', message: 'y', timesShown: 99);

      expect(
        newlyReached([passed, under], const [], milestone: 100)
            .map((s) => s.id),
        ['a'],
      );
      expect(newlyReached([passed], const ['a'], milestone: 100), isEmpty);
    });

    test('the watcher announces reach and hands approvals to points', () async {
      SharedPreferences.setMockInitialValues({
        'submissionApprovals.seen.reader': ['a'],
        'submissionReach.announced.reader': <String>[],
      });
      final submissions = _FakeSubmissions()
        ..approved = [
          ApprovedSubmission(
            id: 'a',
            message: 'x',
            timesShown: 150,
            reviewedAt: DateTime(2026, 11, 8, 10),
          ),
        ];
      var reachNotices = 0;
      List<String>? approvedDays;
      final auth = StreamController<String?>.broadcast();
      final watcher = SubmissionApprovalWatcher(
        dataSource: submissions,
        uidChanges: () => auth.stream,
        notify: (_) async {},
        notifyReach: () async => reachNotices++,
        onApproved: (uid, approved) => approvedDays = [
          for (final s in approved) journeyDayKey(s.reviewedAt!),
        ],
      )..start();
      addTearDown(() {
        watcher.dispose();
        auth.close();
      });

      auth.add('reader');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await watcher.check();

      expect(reachNotices, 1);
      expect(approvedDays, ['2026-11-08']);
    });
  });
}
