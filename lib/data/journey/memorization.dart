/// Memorizing a hadith, and keeping it: how the text is split for learning,
/// and when each memorized hadith comes back for review.
///
/// Built from the hadith as it is already stored: its narrator, its text and
/// who recorded it, so it needs no new content. Nothing here is a quiz: no
/// choices to pick from and no words to put in order, since a wrong option
/// would set invented words beside the Prophet's ﷺ. The reader recites from
/// memory and says honestly whether they had it.
///
/// Pure Dart, no Flutter or Firestore, like the rest of the journey's logic.
library;

import 'dart:math' as math;

import '../models/hadith.dart';
import 'journey_engine.dart';

/// Days until the next review, by how many reviews in a row went well. A
/// review that went well moves one step on; one that did not moves one step
/// back. After the last step the hadith is kept, with no review planned.
const kReviewIntervals = [1, 3, 7, 16, 35, 90];

/// How many days either side of its due day each step's review may move,
/// to the day with the fewest other reviews. Hadiths memorized close
/// together would otherwise come back together at every step. The first
/// two steps stay exact: they are too short to move.
const kReviewSpread = [0, 0, 1, 2, 3, 5];

/// How many other reviews a day may already hold before a review due on it
/// looks for a lighter day nearby (see [spreadDue]). Two a day is the most
/// the intervals give a reader who starts a hadith every few days, so that
/// steady pace is never moved.
const kReviewsAtEase = 2;
/// How many new hadiths a reader may start memorizing in one reading day.
/// Hadiths started together come back together, and one a day keeps the
/// reviews light. Going on with a hadith already started is never held.
const kNewMemoPerDay = 1;

/// The most of the hadith's own words a learning session asks for, before
/// its narrator and source (see [memoPassage]). 26 of the 42 hadiths are
/// shorter than 40 words and fit one session; the six longest (84 to 179
/// words) are learned in parts over several days.
const kWordsPerSession = 80;

/// How many memorized hadiths a milestone is shown at.
const kMemoMilestones = [1, 5, 10, 20, 42];

String memoMilestoneId(int count) => 'memo$count';

/// The milestones [memorizedCount] has passed that this reader has not
/// seen, lowest first.
List<int> newMemoMilestones(int memorizedCount, Set<String> seen) => [
      for (final milestone in kMemoMilestones)
        if (memorizedCount >= milestone &&
            !seen.contains(memoMilestoneId(milestone)))
          milestone,
    ];

/// Where a reader stands with memorizing one hadith.
class MemoProgress {
  const MemoProgress({
    this.parts = 0,
    this.box,
    this.due,
    this.misses = 0,
    this.memorizedOn,
    this.startedOn,
  });

  factory MemoProgress.fromJson(Object? raw) {
    if (raw is! Map) return const MemoProgress();
    return MemoProgress(
      parts: (raw['parts'] as num?)?.toInt() ?? 0,
      box: (raw['box'] as num?)?.toInt(),
      due: raw['due'] as String?,
      misses: (raw['misses'] as num?)?.toInt() ?? 0,
      memorizedOn: raw['on'] as String?,
      startedOn: raw['st'] as String?,
    );
  }

  /// Parts learned so far, while still learning.
  final int parts;

  /// Null while learning. Then the step in [kReviewIntervals] the hadith has
  /// reached, and `kReviewIntervals.length` once it is kept.
  final int? box;

  /// The reading day the next review is due, or null when none is planned.
  final String? due;

  /// How many reviews did not go well, for the reader's own record.
  final int misses;

  /// The reading day the last part was learned.
  final String? memorizedOn;

  /// The reading day the first part was learned. Null for hadiths started
  /// before this was recorded.
  final String? startedOn;

  bool get isMemorized => box != null;
  bool get isLearning => box == null && parts > 0;
  bool get isKept => (box ?? 0) >= kReviewIntervals.length;
  bool isDue(String today) => due != null && due!.compareTo(today) <= 0;

  Map<String, dynamic> toJson() => {
        if (parts > 0) 'parts': parts,
        if (box != null) 'box': box,
        if (due != null) 'due': due,
        if (misses > 0) 'misses': misses,
        if (memorizedOn != null) 'on': memorizedOn,
        if (startedOn != null) 'st': startedOn,
      };

  @override
  bool operator ==(Object other) =>
      other is MemoProgress &&
      other.parts == parts &&
      other.box == box &&
      other.due == due &&
      other.misses == misses &&
      other.memorizedOn == memorizedOn &&
      other.startedOn == startedOn;

  @override
  int get hashCode =>
      Object.hash(parts, box, due, misses, memorizedOn, startedOn);
}

/// After learning one more part of a hadith of [totalParts] parts on
/// [today]. The last part makes it memorized, due for review tomorrow.
MemoProgress afterPartLearned(
  MemoProgress progress, {
  required int totalParts,
  required String today,
}) {
  if (progress.isMemorized) return progress;
  final startedOn = progress.parts == 0 ? today : progress.startedOn;
  final parts = math.min(progress.parts + 1, totalParts);
  if (parts < totalParts) {
    return MemoProgress(parts: parts, startedOn: startedOn);
  }
  return MemoProgress(
    parts: totalParts,
    box: 0,
    due: dayKeyPlus(today, kReviewIntervals.first),
    memorizedOn: today,
    startedOn: startedOn,
  );
}

/// After a review on [today]. Remembered moves one step on, and past the
/// last step the hadith is kept. Not remembered moves one step back.
///
/// [load] is how many other hadiths are due on each day (see [reviewLoad]);
/// the next review moves within its step's [kReviewSpread] to the lightest
/// of those days.
MemoProgress afterReview(
  MemoProgress progress, {
  required bool remembered,
  required String today,
  Map<String, int> load = const {},
}) {
  final box = progress.box;
  if (box == null || progress.isKept) return progress;
  if (remembered) {
    final next = box + 1;
    return MemoProgress(
      parts: progress.parts,
      box: next,
      due: next >= kReviewIntervals.length
          ? null
          : spreadDue(today, next, load),
      misses: progress.misses,
      memorizedOn: progress.memorizedOn,
      startedOn: progress.startedOn,
    );
  }
  final back = math.max(0, box - 1);
  return MemoProgress(
    parts: progress.parts,
    box: back,
    due: spreadDue(today, back, load),
    misses: progress.misses + 1,
    memorizedOn: progress.memorizedOn,
    startedOn: progress.startedOn,
  );
}

/// How many hadiths are due on each day, leaving out [except]: what
/// [afterReview] weighs when it places that hadith's next review.
Map<String, int> reviewLoad(Map<int, MemoProgress> memo, {int? except}) {
  final load = <String, int>{};
  for (final entry in memo.entries) {
    final due = entry.value.due;
    if (due == null || entry.key == except) continue;
    load[due] = (load[due] ?? 0) + 1;
  }
  return load;
}

/// The day a review at [step] lands, counted from [today]: its interval,
/// unless that day already holds [kReviewsAtEase] others in [load]. Then it
/// moves up to [kReviewSpread] days either way to the day with the fewest.
/// On a tie the day nearest the interval wins, then the earlier one.
///
/// A day with room is never left: the first two steps cannot move, and a
/// review moved early onto an empty day could meet those of hadiths not
/// memorized yet.
String spreadDue(String today, int step, Map<String, int> load) {
  final interval = kReviewIntervals[step];
  var best = dayKeyPlus(today, interval);
  var bestLoad = load[best] ?? 0;
  if (bestLoad < kReviewsAtEase) return best;
  for (var off = 1; off <= kReviewSpread[step]; off++) {
    for (final days in [interval - off, interval + off]) {
      final day = dayKeyPlus(today, days);
      final count = load[day] ?? 0;
      if (count < bestLoad) {
        best = day;
        bestLoad = count;
      }
    }
  }
  return best;
}

/// Whether the reader may begin memorizing [number] on [today]. A hadith
/// already started or memorized may always go on; a new one waits once
/// [kNewMemoPerDay] others were started today.
bool canStartMemo(Map<int, MemoProgress> memo, int number, String today) {
  final progress = memo[number] ?? const MemoProgress();
  if (progress.isMemorized || progress.parts > 0) return true;
  final startedToday = memo.values.where((m) => m.startedOn == today).length;
  return startedToday < kNewMemoPerDay;
}

/// The hadiths due for review on [today], the longest waiting first.
List<int> dueReviews(Map<int, MemoProgress> memo, String today) {
  final due = [
    for (final entry in memo.entries)
      if (entry.value.isDue(today)) entry,
  ]..sort((a, b) {
      final byDue = a.value.due!.compareTo(b.value.due!);
      return byDue != 0 ? byDue : a.key.compareTo(b.key);
    });
  return [for (final entry in due) entry.key];
}

int _wordCount(String text) =>
    text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;

/// The hadith in sentences, for reading one at a time: split after Arabic
/// and Latin punctuation, with very short pieces joined to the next so a
/// lone «قال:» is never a sentence of its own.
List<String> memoSentences(String text) {
  final pieces = <String>[];
  final buffer = StringBuffer();
  for (final rune in text.trim().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(char);
    if ('،,.؛;:؟?!'.contains(char)) {
      final piece = buffer.toString().trim();
      if (piece.isNotEmpty) pieces.add(piece);
      buffer.clear();
    }
  }
  final rest = buffer.toString().trim();
  if (rest.isNotEmpty) pieces.add(rest);

  final sentences = <String>[];
  var carry = '';
  for (final piece in pieces) {
    final joined = carry.isEmpty ? piece : '$carry $piece';
    if (_wordCount(joined) < 3) {
      carry = joined;
    } else {
      sentences.add(joined);
      carry = '';
    }
  }
  if (carry.isNotEmpty) {
    if (sentences.isEmpty) {
      sentences.add(carry);
    } else {
      sentences[sentences.length - 1] = '${sentences.last} $carry';
    }
  }
  return sentences;
}

/// The hadith in learning sessions: whole sentences, as even in length as
/// they can be, none much past [kWordsPerSession] words.
List<List<String>> memoParts(String text) {
  final sentences = memoSentences(text);
  final total = sentences.fold(0, (sum, s) => sum + _wordCount(s));
  final count = math.max(1, (total / kWordsPerSession).ceil());
  if (count == 1) return [sentences];

  final target = total / count;
  final parts = <List<String>>[[]];
  var inPart = 0;
  for (final sentence in sentences) {
    final size = _wordCount(sentence);
    // A sentence goes to the next part when most of it would overflow this
    // one's share. The last part takes whatever remains.
    if (parts.last.isNotEmpty &&
        parts.length < count &&
        inPart + size / 2 > target) {
      parts.add([]);
      inPart = 0;
    }
    parts.last.add(sentence);
    inPart += size;
  }
  return parts;
}

/// Where a sentence of the memorized passage comes from.
enum MemoLine {
  /// The chain that opens the hadith: «عن أبي هريرة رضي الله عنه قال: …».
  narrator,

  /// The hadith itself.
  matn,

  /// Who recorded it: «رواه البخاري ومسلم».
  source,
}

/// One sentence of the memorized passage, and where it comes from.
class MemoSentence {
  const MemoSentence(this.text, this.line);

  final String text;
  final MemoLine line;

  @override
  bool operator ==(Object other) =>
      other is MemoSentence && other.text == text && other.line == line;

  @override
  int get hashCode => Object.hash(text, line);

  @override
  String toString() => '${line.name}: $text';
}

/// The hadith as it is learned by heart, part by part: its narrator before
/// it and who recorded it after it, the way the Forty are memorized.
///
/// The parts are those [memoParts] makes of the hadith text alone, with the
/// narrator opening the first and the source closing the last. So a hadith
/// takes as many sessions as it did before, and a reader's saved count of
/// parts keeps its meaning.
List<List<MemoSentence>> memoPassage(Hadith hadith) {
  final parts = [
    for (final part in memoParts(hadith.text))
      [for (final sentence in part) MemoSentence(sentence, MemoLine.matn)],
  ];
  final narrator = hadith.isnad.trim();
  if (narrator.isNotEmpty) {
    parts.first.insertAll(0, [
      for (final sentence in memoSentences(narrator))
        MemoSentence(sentence, MemoLine.narrator),
    ]);
  }
  final source = hadith.mukhrij.trim();
  if (source.isNotEmpty) {
    // One line, never split at its commas: «رواه مسلم» is two words and
    // would otherwise be joined onto the last sentence of the hadith.
    parts.last.add(MemoSentence('رواه $source', MemoLine.source));
  }
  return parts;
}

/// Which words of a [length]-word passage are hidden at [level]: none at 0,
/// one in three at 1, two in three at 2, all at 3. The first word of the
/// passage stays at 1 and 2, so the reader always has somewhere to start.
List<bool> hiddenWords(int length, int level) => [
      for (var i = 0; i < length; i++)
        switch (level) {
          <= 0 => false,
          1 => i % 3 == 1,
          2 => i % 3 != 0,
          _ => true,
        },
    ];

/// How many reviews fall on each day when a reader memorizes a new hadith
/// every [newEvery] days (or [perDay] of them each such day) and reviews
/// every one on its day and remembers it, for checking the review load the
/// intervals and their spread make. Day 0 is the first hadith.
List<int> simulateReviewLoad({
  int hadiths = 42,
  int newEvery = 3,
  int perDay = 1,
  int days = 400,
}) {
  const start = '2026-01-01';
  final load = List<int>.filled(days, 0);
  final memo = <int, MemoProgress>{};
  var started = 0;
  for (var d = 0; d < days; d++) {
    final today = dayKeyPlus(start, d);
    for (final number in dueReviews(memo, today)) {
      load[d]++;
      memo[number] = afterReview(
        memo[number]!,
        remembered: true,
        today: today,
        load: reviewLoad(memo, except: number),
      );
    }
    if (d % newEvery == 0) {
      for (var i = 0; i < perDay && started < hadiths; i++) {
        memo[started] = afterPartLearned(
          const MemoProgress(),
          totalParts: 1,
          today: today,
        );
        started++;
      }
    }
  }
  return load;
}
