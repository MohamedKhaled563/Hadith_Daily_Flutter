/// What a reader has done, as plain data with no Flutter or Firestore in it,
/// so everything worked out from it can be tested on its own.
///
/// Only facts are stored: which days had which readings. The streak, the
/// grace days and the tree are all calculated from those facts (see
/// journey_engine.dart), so there is no counter that can drift between two
/// phones.
library;

/// How far a reader has got with one hadith.
class HadithProgress {
  const HadithProgress({this.textOn, this.fullOn, this.reads = 0});

  factory HadithProgress.fromJson(Object? raw) {
    if (raw is! Map) return const HadithProgress();
    return HadithProgress(
      textOn: raw['text'] as String?,
      fullOn: raw['full'] as String?,
      reads: (raw['reads'] as num?)?.toInt() ?? 0,
    );
  }

  /// The reading day the hadith text and summary were read.
  final String? textOn;

  /// The reading day the full explanation was first finished.
  final String? fullOn;

  /// How many times the explanation has been finished, re-reads included.
  final int reads;

  bool get isComplete => fullOn != null;

  Map<String, dynamic> toJson() => {
        if (textOn != null) 'text': textOn,
        if (fullOn != null) 'full': fullOn,
        if (reads > 0) 'reads': reads,
      };

  HadithProgress copyWith({String? textOn, String? fullOn, int? reads}) =>
      HadithProgress(
        textOn: textOn ?? this.textOn,
        fullOn: fullOn ?? this.fullOn,
        reads: reads ?? this.reads,
      );
}

/// One reading day. A day runs from 03:00 to 03:00 — see [journeyDayKey].
class JourneyDay {
  const JourneyDay({
    this.messages = const [],
    this.messageHadith,
    this.hadiths = const [],
    this.seconds = 0,
    this.wrote = 0,
  });

  factory JourneyDay.fromJson(Object? raw) {
    if (raw is! Map) return const JourneyDay();
    return JourneyDay(
      messages: [
        for (final id in raw['m'] as List? ?? const []) id.toString(),
      ],
      messageHadith: (raw['mh'] as num?)?.toInt(),
      hadiths: [
        for (final n in raw['h'] as List? ?? const [])
          if (n is num) n.toInt(),
      ],
      seconds: (raw['s'] as num?)?.toInt() ?? 0,
      wrote: (raw['w'] as num?)?.toInt() ?? 0,
    );
  }

  /// Ids of the messages read this day.
  final List<String> messages;

  /// The hadith behind the day's latest message, which becomes the day's
  /// hadith step.
  final int? messageHadith;

  /// Hadiths whose full explanation was finished this day.
  final List<int> hadiths;

  /// Careful reading time. Time with the phone left on the table is not in
  /// here — see [ReadingTracker].
  final int seconds;

  /// How many messages the reader sent to the community this day.
  final int wrote;

  /// Whether this day keeps the streak alive.
  bool get isPresent => messages.isNotEmpty || hadiths.isNotEmpty;

  Map<String, dynamic> toJson() => {
        if (messages.isNotEmpty) 'm': messages,
        if (messageHadith != null) 'mh': messageHadith,
        if (hadiths.isNotEmpty) 'h': hadiths,
        if (seconds > 0) 's': seconds,
        if (wrote > 0) 'w': wrote,
      };
}

/// One thing that just happened. The same event updates the screen at once
/// and goes to the store, so the two cannot disagree about what it means.
class JourneyEvent {
  const JourneyEvent({
    required this.dayKey,
    this.messageId,
    this.messageHadith,
    this.textHadith,
    this.fullHadith,
    this.seconds = 0,
    this.wrote = 0,
    this.seen = const [],
    this.bestStreak,
    this.startedOn,
  });

  final String dayKey;
  final String? messageId;
  final int? messageHadith;

  /// A hadith whose text and summary were just read.
  final int? textHadith;

  /// A hadith whose full explanation was just finished.
  final int? fullHadith;
  final int seconds;
  final int wrote;

  /// Milestones to remember as shown, so another phone does not repeat them.
  final List<String> seen;

  /// Set when this event beat the reader's longest streak.
  final int? bestStreak;

  /// Set on the reader's very first event.
  final String? startedOn;

  JourneyEvent copyWith({
    List<String>? seen,
    int? bestStreak,
    String? startedOn,
  }) =>
      JourneyEvent(
        dayKey: dayKey,
        messageId: messageId,
        messageHadith: messageHadith,
        textHadith: textHadith,
        fullHadith: fullHadith,
        seconds: seconds,
        wrote: wrote,
        seen: seen ?? this.seen,
        bestStreak: bestStreak ?? this.bestStreak,
        startedOn: startedOn ?? this.startedOn,
      );
}

/// Everything known about one reader.
class JourneyData {
  const JourneyData({
    this.startedOn,
    this.hadith = const {},
    this.days = const {},
    this.seen = const {},
    this.bestStreak = 0,
  });

  /// Rebuilds a reader from `journey/state` and their `journeyYears` docs.
  factory JourneyData.fromDocs(
    Map<String, dynamic> state,
    Iterable<Map<String, dynamic>> years,
  ) {
    final hadith = <int, HadithProgress>{};
    final rawHadith = state['hadith'];
    if (rawHadith is Map) {
      for (final entry in rawHadith.entries) {
        final number = int.tryParse(entry.key.toString());
        if (number != null) {
          hadith[number] = HadithProgress.fromJson(entry.value);
        }
      }
    }

    final days = <String, JourneyDay>{};
    for (final year in years) {
      final rawDays = year['days'];
      if (rawDays is! Map) continue;
      for (final entry in rawDays.entries) {
        days[entry.key.toString()] = JourneyDay.fromJson(entry.value);
      }
    }

    final records = state['records'];
    return JourneyData(
      startedOn: state['startedOn'] as String?,
      hadith: hadith,
      days: days,
      seen: {for (final id in state['seen'] as List? ?? const []) id.toString()},
      bestStreak: records is Map
          ? (records['bestStreak'] as num?)?.toInt() ?? 0
          : 0,
    );
  }

  /// The guest copy kept on the phone: both docs folded into one map.
  factory JourneyData.fromJson(Map<String, dynamic> json) =>
      JourneyData.fromDocs(json, [json]);

  static const empty = JourneyData();

  final String? startedOn;
  final Map<int, HadithProgress> hadith;
  final Map<String, JourneyDay> days;

  /// Milestones already shown to this reader.
  final Set<String> seen;

  /// The longest streak on record. Kept as well as calculated, because only
  /// the current and previous year's days are loaded.
  final int bestStreak;

  bool get isEmpty => startedOn == null && hadith.isEmpty && days.isEmpty;

  int get completeCount => hadith.values.where((h) => h.isComplete).length;

  HadithProgress progressOf(int number) =>
      hadith[number] ?? const HadithProgress();

  Map<String, dynamic> toJson() => {
        if (startedOn != null) 'startedOn': startedOn,
        'hadith': {
          for (final entry in hadith.entries)
            '${entry.key}': entry.value.toJson(),
        },
        'days': {
          for (final entry in days.entries) entry.key: entry.value.toJson(),
        },
        'seen': seen.toList(),
        'records': {'bestStreak': bestStreak},
      };

  /// This reader after [event]. Safe to apply twice: a message or hadith
  /// already in the day is not added again.
  JourneyData apply(JourneyEvent event) {
    final nextHadith = Map<int, HadithProgress>.of(hadith);
    final text = event.textHadith;
    if (text != null) {
      final current = progressOf(text);
      if (current.textOn == null) {
        nextHadith[text] = current.copyWith(textOn: event.dayKey);
      }
    }
    final full = event.fullHadith;
    if (full != null) {
      final current = nextHadith[full] ?? const HadithProgress();
      nextHadith[full] = current.copyWith(
        textOn: current.textOn ?? event.dayKey,
        fullOn: current.fullOn ?? event.dayKey,
        reads: current.reads + 1,
      );
    }

    final day = days[event.dayKey] ?? const JourneyDay();
    final id = event.messageId;
    final nextDay = JourneyDay(
      messages: id == null || day.messages.contains(id)
          ? day.messages
          : [...day.messages, id],
      messageHadith: event.messageHadith ?? day.messageHadith,
      hadiths: full == null || day.hadiths.contains(full)
          ? day.hadiths
          : [...day.hadiths, full],
      seconds: day.seconds + event.seconds,
      wrote: day.wrote + event.wrote,
    );

    return JourneyData(
      startedOn: startedOn ?? event.startedOn,
      hadith: nextHadith,
      days: {...days, event.dayKey: nextDay},
      seen: {...seen, ...event.seen},
      bestStreak: (event.bestStreak ?? 0) > bestStreak
          ? event.bestStreak!
          : bestStreak,
    );
  }
}
