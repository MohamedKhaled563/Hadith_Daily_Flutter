/// Everything worked out from a reader's facts: the reading day, the streak,
/// grace days, the day's three steps, the week's minutes, and milestones.
///
/// All of it is calculated, none of it stored — see journey_models.dart. No
/// Flutter and no Firestore here, so it runs in any test without a device.
library;

import 'dart:math' as math;

import '../services/notification_schedule.dart' show notificationDateKey;
import 'journey_models.dart';

/// The hadiths a milestone is shown at.
const kJourneyMilestones = [5, 10, 20, 30, 42];

/// How many grace days can wait in reserve.
const kMaxGraceDays = 2;

/// Counted days it takes to earn one grace day.
const kDaysPerGrace = 7;

/// The reading day [now] belongs to. It turns over at 03:00, so reading late
/// at night counts for the evening the reader is still living in rather than
/// for a date they would call tomorrow.
String journeyDayKey(DateTime now) =>
    notificationDateKey(now.subtract(const Duration(hours: 3)));

DateTime _dateOf(String dayKey) {
  final parts = dayKey.split('-');
  return DateTime.utc(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

/// [dayKey] moved by [days]. Works on calendar dates in UTC, so a clock
/// change can never make a day repeat or go missing.
String dayKeyPlus(String dayKey, int days) =>
    notificationDateKey(_dateOf(dayKey).add(Duration(days: days)));

/// The Saturday that starts [dayKey]'s week.
String weekStartKey(String dayKey) {
  final date = _dateOf(dayKey);
  final daysSinceSaturday = (date.weekday + 1) % 7;
  return dayKeyPlus(dayKey, -daysSinceSaturday);
}

/// A reader's streak as of one day.
class StreakResult {
  const StreakResult({
    required this.current,
    required this.best,
    required this.graceBanked,
    required this.presentToday,
  });

  final int current;
  final int best;

  /// Grace days waiting to cover a missed day.
  final int graceBanked;

  /// Whether today already counts. False means today can still be saved.
  final bool presentToday;
}

/// Walks the reader's days in order. A missed day uses a grace day if one is
/// banked, and only otherwise ends the streak. Today is never a miss: it is
/// still open.
StreakResult computeStreak(
  Map<String, JourneyDay> days,
  String today, {
  int storedBest = 0,
}) {
  final present = {
    for (final entry in days.entries)
      if (entry.value.isPresent) entry.key,
  };
  if (present.isEmpty) {
    return StreakResult(
      current: 0,
      best: storedBest,
      graceBanked: 0,
      presentToday: false,
    );
  }

  final first = present.reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
  var streak = 0;
  var best = storedBest;
  var grace = 0;
  var counted = 0;

  for (var day = first;
      day.compareTo(today) <= 0;
      day = dayKeyPlus(day, 1)) {
    if (present.contains(day)) {
      streak++;
      counted++;
      best = math.max(best, streak);
      if (counted % kDaysPerGrace == 0) {
        grace = math.min(kMaxGraceDays, grace + 1);
      }
    } else if (day == today) {
      continue;
    } else if (grace > 0) {
      grace--;
    } else {
      streak = 0;
      counted = 0;
    }
  }

  return StreakResult(
    current: streak,
    best: best,
    graceBanked: grace,
    presentToday: present.contains(today),
  );
}

/// The day's three steps, which the ring on Home shows.
class DaySteps {
  const DaySteps({
    required this.message,
    required this.hadith,
    required this.wrote,
  });

  factory DaySteps.of(JourneyData data, String today) {
    final day = data.days[today] ?? const JourneyDay();
    return DaySteps(
      message: day.messages.isNotEmpty,
      hadith: day.hadiths.isNotEmpty,
      wrote: day.wrote > 0,
    );
  }

  final bool message;
  final bool hadith;
  final bool wrote;

  int get done => [message, hadith, wrote].where((step) => step).length;
}

/// The hadith to read next: the one behind today's message if it is unread,
/// otherwise the first unread one. Null once all [total] are read.
int? nextHadith(JourneyData data, String today, {int total = 42}) {
  final fromMessage = data.days[today]?.messageHadith;
  if (fromMessage != null &&
      fromMessage >= 1 &&
      fromMessage <= total &&
      !data.progressOf(fromMessage).isComplete) {
    return fromMessage;
  }
  for (var number = 1; number <= total; number++) {
    if (!data.progressOf(number).isComplete) return number;
  }
  return null;
}

/// Careful reading this week against last week, in minutes.
class WeekCompare {
  const WeekCompare({required this.thisWeek, required this.lastWeek});

  factory WeekCompare.of(JourneyData data, String today) {
    final start = weekStartKey(today);
    int minutes(String from) {
      var seconds = 0;
      for (var i = 0; i < 7; i++) {
        seconds += data.days[dayKeyPlus(from, i)]?.seconds ?? 0;
      }
      return (seconds / 60).round();
    }

    return WeekCompare(
      thisWeek: minutes(start),
      lastWeek: minutes(dayKeyPlus(start, -7)),
    );
  }

  final int thisWeek;
  final int lastWeek;
}

/// The milestones [completeCount] has passed that this reader has not seen,
/// lowest first. Usually one; more only after a guest's reading joins their
/// account, when just the last is worth showing.
List<int> newMilestones(int completeCount, Set<String> seen) => [
      for (final milestone in kJourneyMilestones)
        if (completeCount >= milestone && !seen.contains(milestoneId(milestone)))
          milestone,
    ];

String milestoneId(int milestone) => 'read$milestone';
