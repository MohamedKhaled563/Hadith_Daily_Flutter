/// Points, personal records and the Friday harvest, all worked out from the
/// reader's day log, like everything else in the journey. Nothing here is
/// stored, so no number can drift between two phones.
///
/// Points measure activity in the app. They never claim to measure reward.
library;

import 'dart:math' as math;

import 'journey_engine.dart';
import 'journey_models.dart';

/// What each action is worth, and how often a day it counts.
class PointRules {
  const PointRules._();

  static const message = 2;

  /// Today's set is at most ten messages long — see DailyTipService.
  static const messagesPerDay = 10;

  static const community = 1;
  static const communityPerDay = 3;

  static const hadith = 10;
  static const hadithsPerDay = 2;

  static const share = 2;
  static const sharesPerDay = 1;

  /// A message a moderator approved. The only points the phone cannot give
  /// itself, so the only ones allowed past [deviceWeekCap].
  static const approved = 15;
  static const approvedPerWeek = 3;

  /// The most a week's reading on the phone can be worth. An honest, active
  /// reader reaches it, so a modified app gains no lead by claiming it.
  static const deviceWeekCap = 300;
}

/// Seconds as the minutes the reader is shown, rounded the way the week bar
/// rounds them, so one week never shows two different numbers.
int minutesOf(int seconds) => (seconds / 60).round();

/// Points earned on one reading day, before the weekly cap.
int dayPoints(JourneyDay day) =>
    math.min(day.messages.length, PointRules.messagesPerDay) *
        PointRules.message +
    math.min(day.community.length, PointRules.communityPerDay) *
        PointRules.community +
    math.min(day.hadiths.length, PointRules.hadithsPerDay) * PointRules.hadith +
    math.min(day.shared, PointRules.sharesPerDay) * PointRules.share;

/// One week's points.
class WeekPoints {
  const WeekPoints({required this.device, required this.approved});

  /// From reading and sharing on the phone, capped.
  final int device;

  /// From approved messages, on top of the cap.
  final int approved;

  int get total => device + approved;
}

/// The points of the week starting [weekStart] (a Saturday). [approvedOn] is
/// the reading day each of the reader's messages was approved on.
WeekPoints weekPoints(
  JourneyData data,
  String weekStart, {
  Iterable<String> approvedOn = const [],
}) {
  var device = 0;
  for (var i = 0; i < 7; i++) {
    final day = data.days[dayKeyPlus(weekStart, i)];
    if (day != null) device += dayPoints(day);
  }
  final weekEnd = dayKeyPlus(weekStart, 6);
  final approvals = approvedOn
      .where((d) => d.compareTo(weekStart) >= 0 && d.compareTo(weekEnd) <= 0)
      .length;
  return WeekPoints(
    device: math.min(device, PointRules.deviceWeekCap),
    approved:
        math.min(approvals, PointRules.approvedPerWeek) * PointRules.approved,
  );
}

/// The reader's eight personal records, in the order the completion sheet
/// looks for one that was just broken.
enum JourneyRecord {
  streak('أطول سلسلة', 'أطول سلسلة لك حتى الآن'),
  weekMinutes('أكثر دقائق في أسبوع', 'أكثر أسبوع قراءةً لك حتى الآن'),
  weekHadiths('أكثر أحاديث في أسبوع', 'أكثر أحاديث قرأتها في أسبوع'),
  weekDays('أكثر أيام في أسبوع', 'أكثر أيام قرأت فيها في أسبوع'),
  dayMinutes('أطول قراءة في يوم', 'أطول قراءة لك في يوم واحد'),
  dayHadiths('أكثر أحاديث في يوم', 'أكثر أحاديث قرأتها في يوم واحد'),
  weekPoints('أعلى نقاط في أسبوع', 'أعلى نقاط لك في أسبوع'),
  weekWrote('أكثر رسائل في أسبوع', 'أكثر رسائل كتبتها في أسبوع');

  const JourneyRecord(this.label, this.brokenLine);

  /// What the records card calls it.
  final String label;

  /// What the completion sheet says the moment it is beaten.
  final String brokenLine;
}

/// Where the reader stands on one record: the best of the days or weeks
/// before the current one, and the current one so far.
class RecordStanding {
  const RecordStanding({required this.past, required this.current});

  final int past;
  final int current;

  int get best => math.max(past, current);
}

/// Every record, split into earlier periods and the current one. Day records
/// treat [today] as current, week records the week holding it. The streak has
/// no earlier part here: its best already counts the current run.
Map<JourneyRecord, RecordStanding> recordStandings(
  JourneyData data, {
  required String today,
  Iterable<String> approvedOn = const [],
}) {
  final past = {for (final record in JourneyRecord.values) record: 0};
  final current = {for (final record in JourneyRecord.values) record: 0};
  final thisWeek = weekStartKey(today);
  void keep(JourneyRecord record, int value, {required bool isCurrent}) {
    final into = isCurrent ? current : past;
    if (value > into[record]!) into[record] = value;
  }

  final weeks = <String>{};
  for (final entry in data.days.entries) {
    final day = entry.value;
    final isToday = entry.key == today;
    keep(JourneyRecord.dayMinutes, minutesOf(day.seconds), isCurrent: isToday);
    keep(JourneyRecord.dayHadiths, day.hadiths.length, isCurrent: isToday);
    weeks.add(weekStartKey(entry.key));
  }

  for (final start in weeks) {
    var seconds = 0, hadiths = 0, present = 0, wrote = 0;
    for (var i = 0; i < 7; i++) {
      final day = data.days[dayKeyPlus(start, i)];
      if (day == null) continue;
      seconds += day.seconds;
      hadiths += day.hadiths.length;
      wrote += day.wrote;
      if (day.isPresent) present++;
    }
    final isCurrent = start == thisWeek;
    keep(JourneyRecord.weekMinutes, minutesOf(seconds), isCurrent: isCurrent);
    keep(JourneyRecord.weekHadiths, hadiths, isCurrent: isCurrent);
    keep(JourneyRecord.weekDays, present, isCurrent: isCurrent);
    keep(JourneyRecord.weekWrote, wrote, isCurrent: isCurrent);
    keep(
      JourneyRecord.weekPoints,
      weekPoints(data, start, approvedOn: approvedOn).total,
      isCurrent: isCurrent,
    );
  }

  keep(
    JourneyRecord.streak,
    computeStreak(data.days, today, storedBest: data.bestStreak).best,
    isCurrent: true,
  );
  return {
    for (final record in JourneyRecord.values)
      record: RecordStanding(past: past[record]!, current: current[record]!),
  };
}

/// Every record, worked out from the days on file.
Map<JourneyRecord, int> journeyRecords(
  JourneyData data, {
  required String today,
  Iterable<String> approvedOn = const [],
}) =>
    recordStandings(data, today: today, approvedOn: approvedOn)
        .map((record, standing) => MapEntry(record, standing.best));

/// The record a reading just beat, or null. It is beaten once: the moment
/// today or this week passes the best of the earlier ones. Adding to a week
/// that already holds the record is not news again, and a record that stood
/// at zero was never really held. The streak is the completion sheet's own
/// business (ReadingOutcome.newBest), so it is not looked at here.
JourneyRecord? brokenRecord(
  Map<JourneyRecord, RecordStanding> before,
  Map<JourneyRecord, RecordStanding> after,
) {
  for (final record in JourneyRecord.values) {
    if (record == JourneyRecord.streak) continue;
    final was = before[record];
    final now = after[record];
    if (was == null || now == null) continue;
    final toBeat = was.past;
    if (toBeat > 0 && was.current <= toBeat && now.current > toBeat) {
      return record;
    }
  }
  return null;
}

/// What the Friday harvest reports: the week so far, Saturday to [friday].
class Harvest {
  const Harvest({
    required this.days,
    required this.minutes,
    required this.lastWeekMinutes,
  });

  final int days;
  final int minutes;
  final int lastWeekMinutes;
}

Harvest harvestFor(JourneyData data, String friday) {
  final start = weekStartKey(friday);
  var days = 0, seconds = 0;
  for (var day = start; day.compareTo(friday) <= 0; day = dayKeyPlus(day, 1)) {
    final entry = data.days[day];
    if (entry == null) continue;
    seconds += entry.seconds;
    if (entry.isPresent) days++;
  }
  var lastSeconds = 0;
  for (var i = 0; i < 7; i++) {
    lastSeconds += data.days[dayKeyPlus(start, i - 7)]?.seconds ?? 0;
  }
  return Harvest(
    days: days,
    minutes: minutesOf(seconds),
    lastWeekMinutes: minutesOf(lastSeconds),
  );
}
