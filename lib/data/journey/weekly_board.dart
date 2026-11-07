/// The weekly board: what a reader sends (`scores/{uid}`), how a moderator
/// ranks it on Friday, and what everyone reads back (`settings/weeklyBoard`).
///
/// Pure Dart, shared by the app and the dashboard, so both rank the same way.
/// Joining is optional, and the board only ever shows the first ten.
library;

import 'dart:math' as math;

import 'journey_engine.dart';
import 'journey_points.dart';

/// The name a reader appears under when they would rather not use their own.
const kAnonymousName = 'فاعل خير';

/// How many names a published list holds. Everyone else sees only their own
/// points against last week, never a rank.
const kBoardSize = 10;

/// How many readers a week needs before a board looks like a board.
const kBoardReadyAt = 50;

/// 1970-01-03 was a Saturday, two days after the epoch.
const _firstSaturdayMs = 2 * Duration.millisecondsPerDay;
const _weekMs = 7 * Duration.millisecondsPerDay;

/// The week number of the reading week that starts on [saturday]
/// (`yyyy-MM-dd`). The same count firestore.rules makes from the server
/// clock, so the two can be compared.
int boardWeekOf(String saturday) {
  final parts = saturday.split('-').map(int.parse).toList();
  final ms = DateTime.utc(parts[0], parts[1], parts[2]).millisecondsSinceEpoch;
  return ((ms - _firstSaturdayMs) / _weekMs).floor();
}

/// The Saturday that starts week [week].
String boardWeekStart(int week) {
  final day = DateTime.fromMillisecondsSinceEpoch(
    _firstSaturdayMs + week * _weekMs,
    isUtc: true,
  );
  String two(int n) => n.toString().padLeft(2, '0');
  return '${day.year}-${two(day.month)}-${two(day.day)}';
}

/// The week a reading [day] belongs to.
int boardWeekOfDay(String day) => boardWeekOf(weekStartKey(day));

/// The name to publish: the reader's own, or [kAnonymousName].
String boardName({required bool useName, String? displayName}) {
  final own = displayName?.trim() ?? '';
  if (!useName || own.isEmpty) return kAnonymousName;
  return own.length > 40 ? own.substring(0, 40) : own;
}

/// What a reader's phone keeps in `scores/{uid}`: this week's points from
/// the phone, capped, and the name to show. Approved messages are not here:
/// the moderator counts those when publishing, from the messages themselves.
class ScoreEntry {
  const ScoreEntry({
    required this.uid,
    required this.week,
    required this.device,
    required this.name,
    this.memo = 0,
  });

  factory ScoreEntry.fromJson(String uid, Map<String, dynamic> json) =>
      ScoreEntry(
        uid: uid,
        week: (json['week'] as num?)?.toInt() ?? -1,
        device: (json['device'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? kAnonymousName,
        memo: (json['memo'] as num?)?.toInt() ?? 0,
      );

  final String uid;
  final int week;
  final int device;
  final String name;

  /// This week's points from memorizing and reviewing, already in [device]
  /// and sent apart only to rank the memorization list.
  final int memo;

  bool get anonymous => name == kAnonymousName;

  /// Without `updatedAt`, which the store stamps with the server time. No
  /// `memo` until there is some, so an entry stays the shape it always was.
  Map<String, dynamic> toJson() => {
        'week': week,
        'device': device,
        'name': name,
        if (memo > 0) 'memo': memo,
      };

  @override
  bool operator ==(Object other) =>
      other is ScoreEntry &&
      other.uid == uid &&
      other.week == week &&
      other.device == device &&
      other.name == name &&
      other.memo == memo;

  @override
  int get hashCode => Object.hash(uid, week, device, name, memo);
}

/// One reader as the moderator sees them before publishing.
class BoardCandidate {
  const BoardCandidate({
    required this.uid,
    required this.name,
    required this.device,
    required this.approved,
    this.memo = 0,
  });

  final String uid;
  final String name;

  /// Points from the phone, already capped.
  final int device;

  /// Messages approved this week, uncapped (the sharing list counts them all).
  final int approved;

  /// Memorization points this week, for the memorization list's order.
  final int memo;

  int get score =>
      device +
      math.min(approved, PointRules.approvedPerWeek) * PointRules.approved;
}

/// How many of each author's messages were approved in week [week], counted
/// by the reading day of the approval, as the app counts them.
Map<String, int> approvalsInWeek(
  Iterable<({String authorUid, DateTime reviewedAt})> approved,
  int week,
) {
  final counts = <String, int>{};
  for (final message in approved) {
    if (boardWeekOfDay(journeyDayKey(message.reviewedAt)) != week) continue;
    counts[message.authorUid] = (counts[message.authorUid] ?? 0) + 1;
  }
  return counts;
}

/// Everyone who joined for [week], ranked by score. Only readers who joined
/// appear, even on the sharing list: an approved message alone never puts a
/// name on the board.
List<BoardCandidate> rankCandidates({
  required int week,
  required Iterable<ScoreEntry> scores,
  Map<String, int> approvals = const {},
}) {
  final candidates = [
    for (final entry in scores)
      if (entry.week == week)
        BoardCandidate(
          uid: entry.uid,
          name: entry.name,
          device: entry.device.clamp(0, PointRules.deviceWeekCap),
          approved: approvals[entry.uid] ?? 0,
          memo: entry.memo.clamp(0, PointRules.memoWeekCap),
        ),
  ];
  candidates.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.uid.compareTo(b.uid);
  });
  return candidates;
}

/// One line of a published list.
class BoardRow {
  const BoardRow({required this.name, required this.value});

  factory BoardRow.fromJson(Map<String, dynamic> json) => BoardRow(
        name: json['name'] as String? ?? kAnonymousName,
        value: (json['value'] as num?)?.toInt() ?? 0,
      );

  final String name;

  /// Points on the points list, approved messages on the sharing list.
  final int value;

  Map<String, dynamic> toJson() => {'name': name, 'value': value};

  @override
  bool operator ==(Object other) =>
      other is BoardRow && other.name == name && other.value == value;

  @override
  int get hashCode => Object.hash(name, value);
}

/// What `settings/weeklyBoard` holds once a moderator publishes. Names only:
/// no uid leaves the moderator's screen.
class WeeklyBoard {
  const WeeklyBoard({
    required this.week,
    required this.points,
    required this.sharing,
    this.memo = const [],
    this.publishedAt,
  });

  factory WeeklyBoard.fromJson(Map<String, dynamic> json) {
    List<BoardRow> rows(Object? list) => [
          for (final row in (list as List?) ?? const [])
            if (row is Map) BoardRow.fromJson(Map<String, dynamic>.from(row)),
        ];
    final published = json['publishedAt'];
    return WeeklyBoard(
      week: (json['week'] as num?)?.toInt() ?? -1,
      points: rows(json['points']),
      sharing: rows(json['sharing']),
      memo: rows(json['memo']),
      // The store turns Firestore's Timestamp into a DateTime first.
      publishedAt: published is DateTime ? published : null,
    );
  }

  final int week;
  final List<BoardRow> points;
  final List<BoardRow> sharing;

  /// Names in order only: how much someone memorized is between them and
  /// their Lord, so no number is published for this list.
  final List<BoardRow> memo;
  final DateTime? publishedAt;

  String get weekStart => boardWeekStart(week);

  /// Without `publishedAt`, which the dashboard stamps with the server time.
  Map<String, dynamic> toJson() => {
        'week': week,
        'points': [for (final row in points) row.toJson()],
        'sharing': [for (final row in sharing) row.toJson()],
        'memo': [for (final row in memo) row.toJson()],
      };
}

/// The board a moderator publishes from [ranked], leaving out [hidden].
WeeklyBoard publishBoard({
  required int week,
  required List<BoardCandidate> ranked,
  Set<String> hidden = const {},
  int size = kBoardSize,
}) {
  final shown = [
    for (final c in ranked)
      if (!hidden.contains(c.uid)) c,
  ];
  final sharing = [
    for (final c in shown)
      if (c.approved > 0) c,
  ]..sort((a, b) {
      final byCount = b.approved.compareTo(a.approved);
      return byCount != 0 ? byCount : a.uid.compareTo(b.uid);
    });
  final memorizing = [
    for (final c in shown)
      if (c.memo > 0) c,
  ]..sort((a, b) {
      final byMemo = b.memo.compareTo(a.memo);
      return byMemo != 0 ? byMemo : a.uid.compareTo(b.uid);
    });
  return WeeklyBoard(
    week: week,
    memo: [
      for (final c in memorizing.take(size)) BoardRow(name: c.name, value: 0),
    ],
    points: [
      for (final c in shown.where((c) => c.score > 0).take(size))
        BoardRow(name: c.name, value: c.score),
    ],
    sharing: [
      for (final c in sharing.take(size))
        BoardRow(name: c.name, value: c.approved),
    ],
  );
}
