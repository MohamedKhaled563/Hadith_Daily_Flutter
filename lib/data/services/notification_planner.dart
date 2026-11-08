/// Decides what each reminder says, from what the reader has actually done.
///
/// Reading needs the app open, and every open rebuilds the schedule. So a
/// future slot only has to be written for the case where the reader does not
/// come back: if they do, it gets replaced. That single idea is what gives
/// personal reminders with no server, and they work offline.
///
/// Pure Dart, so every state can be tested without a device.
library;

import '../journey/journey_copy.dart';
import '../journey/journey_engine.dart';
import '../journey/journey_models.dart';
import '../journey/journey_points.dart';
import '../journey/memorization.dart';

/// The day's two reminders.
enum ReminderSlot { morning, evening }

/// A reminder with words of its own. Null from [planReminder] means the slot
/// keeps its message from the shared pool.
class PlannedReminder {
  const PlannedReminder({
    required this.title,
    required this.body,
    required this.payload,
  });

  final String title;
  final String body;

  /// Where a tap leads — see [hadithPayload].
  final String payload;
}

/// What the planner needs to know about the reader.
class ReminderFacts {
  const ReminderFacts({
    required this.signedIn,
    required this.data,
    required this.hadithTitle,
    required this.hadithMinutes,
  });

  /// A guest always gets the pool: their reading stays on one phone, and a
  /// shared phone must not put someone's progress on the lock screen.
  final bool signedIn;
  final JourneyData data;
  final String? Function(int number) hadithTitle;
  final int Function(int number) hadithMinutes;
}

const _hadithPrefix = 'hadith:';

/// The payload of the Friday harvest, which opens the journey tab.
const harvestPayload = 'harvest';

const _reviewPrefix = 'review:';

/// The payload of a reminder that opens the review of hadith [number].
String reviewPayload(int number) => '$_reviewPrefix$number';

/// The hadith whose review [payload] opens, or null.
int? reviewOfPayload(String? payload) {
  if (payload == null || !payload.startsWith(_reviewPrefix)) return null;
  return int.tryParse(payload.substring(_reviewPrefix.length));
}

/// The payload of a reminder that opens hadith [number].
String hadithPayload(int number) => '$_hadithPrefix$number';

/// The hadith [payload] opens, or null for a reminder that opens today's
/// message. A pool message's payload is its document id, which never starts
/// with this prefix.
int? hadithOfPayload(String? payload) {
  if (payload == null || !payload.startsWith(_hadithPrefix)) return null;
  return int.tryParse(payload.substring(_hadithPrefix.length));
}

/// How long a reader can be gone before the reminders stop mentioning their
/// reading. Past this it is pressure, not an invitation.
const kGentleAwayDays = 7;

/// The latest day with a reading, up to and including [day].
String? _lastPresent(JourneyData data, String day) {
  String? last;
  for (final entry in data.days.entries) {
    if (!entry.value.isPresent || entry.key.compareTo(day) > 0) continue;
    if (last == null || entry.key.compareTo(last) > 0) last = entry.key;
  }
  return last;
}

/// Whole days with no reading between the last reading and [day]. Zero when
/// the reader read yesterday, which makes today an ordinary day.
int _missedBefore(String lastPresent, String day) {
  var missed = 0;
  for (var next = dayKeyPlus(lastPresent, 1);
      next.compareTo(day) < 0;
      next = dayKeyPlus(next, 1)) {
    missed++;
  }
  return missed;
}

PlannedReminder? _forHadith(
  ReminderFacts facts,
  String day,
  JourneyMessage Function(String title, int number) message,
) {
  final number = nextHadith(facts.data, day);
  if (number == null) return null;
  final title = facts.hadithTitle(number);
  if (title == null) return null;
  final words = message(title, number);
  return PlannedReminder(
    title: words.title,
    body: words.body,
    payload: hadithPayload(number),
  );
}

/// What the [slot] reminder firing at [at] should say, or null for the pool.
///
/// Four situations: an ordinary day, a streak worth keeping, a short absence,
/// and a long one, which goes quiet about progress altogether.
PlannedReminder? planReminder(
  ReminderFacts facts, {
  required DateTime at,
  required ReminderSlot slot,
}) {
  if (!facts.signedIn) return null;
  final data = facts.data;
  final day = journeyDayKey(at);

  // Today already counts, so there is nothing to ask for.
  if (data.days[day]?.isPresent ?? false) return null;

  final last = _lastPresent(data, day);
  if (last == null) return null;
  final missed = _missedBefore(last, day);

  // Friday morning sums up the week, if there is a week to sum up. Fridays
  // ahead are planned from what is known now, so a reader who stops before
  // one gets the ordinary lines instead of an empty harvest.
  if (slot == ReminderSlot.morning && _isFriday(day) &&
      missed <= kGentleAwayDays) {
    final harvest = harvestFor(data, day);
    if (harvest.days > 0) {
      final words = JourneyCopy.harvest(
        days: harvest.days,
        minutes: harvest.minutes,
        lastWeekMinutes: harvest.lastWeekMinutes,
      );
      return PlannedReminder(
        title: words.title,
        body: words.body,
        payload: harvestPayload,
      );
    }
  }

  if (missed == 0) {
    // A review due that day comes first in the morning: it is short, and it
    // is what keeps a memorized hadith.
    if (slot == ReminderSlot.morning) {
      final review = _review(facts, day);
      if (review != null) return review;
    }
    return switch (slot) {
      ReminderSlot.morning => _forHadith(
          facts,
          day,
          (title, number) =>
              JourneyCopy.todaysHadith(title, facts.hadithMinutes(number)),
        ),
      ReminderSlot.evening => _eveningStreak(facts, day),
    };
  }

  if (slot == ReminderSlot.evening || missed > kGentleAwayDays) return null;
  if (missed != 1 && missed != 3 && missed != kGentleAwayDays) return null;

  final streak = computeStreak(data.days, day);
  if (missed == 1 && streak.current > 0) {
    return _forHadith(facts, day, (_, __) => JourneyCopy.graceUsed);
  }
  return _forHadith(facts, day, (title, _) => JourneyCopy.placeKept(title));
}

PlannedReminder? _review(ReminderFacts facts, String day) {
  for (final number in dueReviews(facts.data.memo, day)) {
    final title = facts.hadithTitle(number);
    if (title == null) continue;
    final words = JourneyCopy.reviewDue(title);
    return PlannedReminder(
      title: words.title,
      body: words.body,
      payload: reviewPayload(number),
    );
  }
  return null;
}

bool _isFriday(String day) {
  final parts = day.split('-').map(int.parse).toList();
  return DateTime.utc(parts[0], parts[1], parts[2]).weekday == DateTime.friday;
}

PlannedReminder? _eveningStreak(ReminderFacts facts, String day) {
  final streak = computeStreak(facts.data.days, day).current;
  if (streak < 3) return null;
  return _forHadith(facts, day, (_, __) => JourneyCopy.eveningStreak(streak));
}

/// Changes exactly when a reminder's words could change, so the schedule is
/// rebuilt after a reading that matters and left alone otherwise.
String reminderPlanKey(ReminderFacts facts, String today) {
  if (!facts.signedIn) return 'guest';
  final data = facts.data;
  return [
    today,
    _lastPresent(data, today) ?? '-',
    nextHadith(data, today) ?? '-',
    computeStreak(data.days, today).current,
    // When the next review falls, which decides a morning's words.
    [
      for (final entry in data.memo.entries)
        if (entry.value.due != null) '${entry.key}@${entry.value.due}',
    ].join(','),
  ].join('|');
}
