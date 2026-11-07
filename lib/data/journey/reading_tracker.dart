/// Decides when a paragraph counts as read, by the time it stayed on screen.
///
/// No app can prove reading. This only makes skimming not count while never
/// slowing a real reader: the time asked of each paragraph is set by a speed
/// faster than careful reading. Published adult Arabic reading speeds are
/// about 138 to 166 words a minute, with a measured top of 252, so 260 stays
/// out of a real reader's way.
library;

import 'dart:math' as math;

import '../models/hadith.dart';

class ReadingRule {
  const ReadingRule._();

  static const wordsPerMinute = 260;

  /// The least a paragraph can ask for, however short.
  static const minimumPerParagraph = Duration(milliseconds: 2500);

  /// The least the hadith text or its summary can ask for.
  static const minimumPerSection = Duration(seconds: 3);

  /// The speed a reader is told to expect, as opposed to [wordsPerMinute],
  /// which is the fastest that still counts.
  static const usualWordsPerMinute = 150;

  static int wordCount(String text) =>
      text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;

  /// Roughly how long [hadith] takes to read in full.
  static int minutesFor(Hadith hadith) {
    final words = wordCount(
      '${hadith.isnad} ${hadith.text} ${hadith.shortExplanation} '
      '${hadith.explanation}',
    );
    return (words / usualWordsPerMinute).ceil();
  }

  static Duration _atSpeed(int words) =>
      Duration(milliseconds: (words * 60000 / wordsPerMinute).round());

  /// How long a paragraph of [words] must stay on screen.
  static Duration neededFor(int words) {
    final needed = _atSpeed(words);
    return needed > minimumPerParagraph ? needed : minimumPerParagraph;
  }

  /// How long the hadith page must stay open for its text and summary to
  /// count, from the word count of each.
  static Duration neededForSections(Iterable<int> sectionWords) {
    var total = Duration.zero;
    for (final words in sectionWords) {
      final needed = _atSpeed(words);
      total += needed > minimumPerSection ? needed : minimumPerSection;
    }
    return total;
  }

  /// Blank-line-separated paragraphs, falling back to the whole text when
  /// the source has no breaks in it — some entries in the workbook are a
  /// single run, and an empty list would render a blank card.
  static List<String> paragraphs(String text) {
    final parts = text
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    return parts.isEmpty ? [text.trim()] : parts;
  }
}

class ReadingTracker {
  ReadingTracker(Iterable<int> paragraphWords)
      : _needed = [
          for (final words in paragraphWords)
            ReadingRule.neededFor(words).inMilliseconds,
        ],
        _spent = List<int>.filled(paragraphWords.length, 0);

  final List<int> _needed;
  final List<int> _spent;
  var _activeMilliseconds = 0;

  int get length => _needed.length;

  /// Careful reading time so far. Only ticks that had something on screen
  /// count, and the screen stops ticking while the reader is idle.
  int get activeSeconds => (_activeMilliseconds / 1000).round();

  /// How much of paragraph [index] has been read, from 0 to 1.
  double progressOf(int index) =>
      math.min(1, _spent[index] / _needed[index]).toDouble();

  bool isRead(int index) => _spent[index] >= _needed[index];

  bool get isComplete =>
      [for (var i = 0; i < length; i++) isRead(i)].every((read) => read);

  /// The first paragraph still waiting, for the finish button to scroll to.
  int? get firstUnread {
    for (var i = 0; i < length; i++) {
      if (!isRead(i)) return i;
    }
    return null;
  }

  /// Spends [elapsed] on the paragraphs in [onScreen], in reading order.
  ///
  /// Only the first unread one takes the time, with anything left over
  /// passing to the next. Crediting every visible paragraph at once would let
  /// a screenful of short paragraphs finish in the time of the longest.
  void tick(Duration elapsed, Iterable<int> onScreen) {
    final visible = onScreen.toList()..sort();
    if (visible.isEmpty) return;
    _activeMilliseconds += elapsed.inMilliseconds;

    var remaining = elapsed.inMilliseconds;
    for (final index in visible) {
      if (remaining <= 0) break;
      final missing = _needed[index] - _spent[index];
      if (missing <= 0) continue;
      final spent = math.min(missing, remaining);
      _spent[index] += spent;
      remaining -= spent;
    }
  }

  /// Marks everything read, for a screen reader, where text is heard rather
  /// than scrolled through and the time on screen means nothing.
  void markAllRead() {
    for (var i = 0; i < length; i++) {
      _spent[i] = _needed[i];
    }
  }
}
