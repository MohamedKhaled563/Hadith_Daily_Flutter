import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/insight.dart';

/// One candidate from the delivery pool — either an admin-seeded
/// `dailyMessages` doc or an approved `communityMessages` submission.
class DailyTip {
  const DailyTip({
    required this.id,
    required this.sourceCollection,
    required this.text,
    required this.hadithNumber,
    required this.category,
  });

  final String id;
  final String sourceCollection; // 'dailyMessages' | 'communityMessages'
  final String text;
  final int hadithNumber;
  final String category;

  /// The card UI (DailyMessageScreen) speaks `Insight`, not this — keeps the
  /// screen itself unaware of where a tip came from.
  Insight toInsight() => Insight(
    hadithNumber: hadithNumber,
    arabic: text,
    english: '',
    category: category,
    id: id,
    sourceCollection: sourceCollection,
  );

  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'source': sourceCollection,
    'text': text,
    'hadithNumber': hadithNumber,
    'category': category,
  };

  static DailyTip? fromCacheJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'] as String?;
    final text = raw['text'] as String?;
    if (id == null || id.isEmpty || text == null || text.isEmpty) return null;

    return DailyTip(
      id: id,
      sourceCollection: raw['source'] as String? ?? 'dailyMessages',
      text: text,
      hadithNumber: (raw['hadithNumber'] as num?)?.toInt() ?? 0,
      category: raw['category'] as String? ?? 'رسالة اليوم',
    );
  }
}

/// The client-driven "tips of the day" engine — see the roadmap doc, §4.
///
/// How many messages a day carries is admin-controlled:
/// `settings/dailyMessageConfig.messagesPerDay` (default 1, capped at
/// [maxMessagesPerDay]). The value is mirrored into SharedPreferences so an
/// offline launch keeps using the last known count instead of silently
/// dropping back to one.
///
/// For a given local day the set is drawn once and then frozen — every later
/// call that day returns the same messages in the same order. Two sources
/// feed a draw, in this order:
///
///   1. `settings/dailyMessageSchedule`'s `days` map, keyed by yyyy-MM-dd
///      (see DailyMessageSchedulePage). An admin can pin anywhere from zero
///      up to `messagesPerDay` messages to a date; those are identical on
///      every device.
///   2. Whatever slots are left over are filled per-device at random from
///      the pool this device hasn't shown yet (`seenIds`), reshuffling once
///      the pool is exhausted, and never repeating a message already in the
///      same day's set.
///
/// Raising `messagesPerDay` mid-day tops today's set up straight away;
/// lowering it never takes a message away from a day already in progress —
/// the smaller count simply applies from the next draw.
///
/// Every newly drawn message fires a narrow `timesShown` increment back to
/// whichever doc was chosen, permitted by firestore.rules for any signed-in
/// device.
class DailyTipService {
  DailyTipService._internal();
  static final DailyTipService instance = DailyTipService._internal();
  factory DailyTipService() => instance;

  /// A sanity ceiling on the admin-set count — a mistyped `30` in the
  /// dashboard should not drain the whole pool in a single day. Mirrored by
  /// `validDailyMessageConfig()` in firestore.rules, which rejects an
  /// out-of-range write server-side; keep the two numbers in step.
  static const maxMessagesPerDay = 10;

  static const _seenIdsKey = 'dailyTip.seenIds';
  static const _todaySetKey = 'dailyTip.todaySet';
  static const _pickedOnDateKey = 'dailyTip.pickedOnDate';
  static const _messagesPerDayKey = 'dailyTip.messagesPerDay';

  // How far into today's set the reader has actually opened. Separate from
  // _todaySetKey because the two answer different questions: that one is
  // which messages today holds, this one is how many of them have been
  // revealed. Dated, so a new day starts back at one message shown.
  static const _revealedCountKey = 'dailyTip.revealedCount';
  static const _revealedOnDateKey = 'dailyTip.revealedOnDate';

  // Superseded by the single JSON list in _todaySetKey. Still read once, so
  // an install upgrading mid-day keeps the message it was already showing,
  // then cleared on the first write of the new format.
  static const _legacyTodayIdKey = 'dailyTip.todayId';
  static const _legacyTodaySourceKey = 'dailyTip.todaySource';
  static const _legacyTodayTextKey = 'dailyTip.todayText';
  static const _legacyTodayHadithNumberKey = 'dailyTip.todayHadithNumber';
  static const _legacyTodayCategoryKey = 'dailyTip.todayCategory';

  // Resolved lazily rather than at construction, the same way
  // FirestoreNotificationDataSource does it and for the same reason: merely
  // touching this singleton must not require Firebase to be up.
  //
  // Not all of this service needs a backend. revealedCount/saveRevealedCount
  // are pure SharedPreferences, and the message screen calls them on every
  // reveal — with an eagerly initialised field, that tap threw
  // [core/no-app] anywhere Firebase had not been initialised, which is every
  // widget test of the screen.
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  final Random _random = Random();

  /// Today's messages, in display order — the same set on every call within
  /// the same local day, a freshly drawn one the first call after the day
  /// rolls over. Empty only if the pool itself is empty (e.g. no
  /// connectivity on first ever launch, before anything is cached).
  Future<List<DailyTip>> getTodayTips() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString();
    final target = await _messagesPerDay(prefs);

    final cached = prefs.getString(_pickedOnDateKey) == today
        ? _readCachedSet(prefs)
        : const <DailyTip>[];

    // Already drawn today and still big enough — including the case where
    // the admin has since lowered the count, which must not shrink a day
    // that is already running.
    if (cached.isNotEmpty && cached.length >= target) return cached;

    return _drawTips(prefs, today, target, cached);
  }

  /// Convenience for callers that only ever show one card — the notification
  /// deep links land on the first message of the day.
  Future<DailyTip?> getTodayTip() async {
    final tips = await getTodayTips();
    return tips.isEmpty ? null : tips.first;
  }

  /// How many of today's messages the reader has opened so far, at least 1.
  ///
  /// The message screen reveals one card at a time rather than letting the
  /// reader swipe through the whole set, so this is what lets it pick up
  /// where they left off: close the app on the third of five and it reopens
  /// on the third, not back at the first and not at "you're done". Resets
  /// with the day, like the set itself.
  Future<int> revealedCount() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_revealedOnDateKey) != _todayString()) return 1;
    final stored = prefs.getInt(_revealedCountKey) ?? 1;
    return stored < 1 ? 1 : stored;
  }

  /// Records that [count] of today's messages have now been revealed. Only
  /// ever moves forward within a day — a caller re-entering the screen and
  /// reporting a smaller number must not un-reveal what was already read.
  Future<void> saveRevealedCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    final isToday = prefs.getString(_revealedOnDateKey) == _todayString();
    final previous = isToday ? (prefs.getInt(_revealedCountKey) ?? 1) : 0;
    if (count <= previous) return;
    await prefs.setString(_revealedOnDateKey, _todayString());
    await prefs.setInt(_revealedCountKey, count);
  }

  /// How many messages today should carry. Falls back to the last value this
  /// device saw, then to 1, so a failed fetch never changes what the reader
  /// gets.
  Future<int> _messagesPerDay(SharedPreferences prefs) async {
    try {
      final doc =
          await _db.collection('settings').doc('dailyMessageConfig').get();
      final value = (doc.data()?['messagesPerDay'] as num?)?.toInt();
      if (value != null && value >= 1) {
        final clamped = value > maxMessagesPerDay ? maxMessagesPerDay : value;
        await prefs.setInt(_messagesPerDayKey, clamped);
        return clamped;
      }
    } catch (_) {
      // Offline, or the config doc does not exist yet — the cached value
      // below covers both.
    }

    final cached = prefs.getInt(_messagesPerDayKey) ?? 1;
    return cached < 1 ? 1 : cached;
  }

  List<DailyTip> _readCachedSet(SharedPreferences prefs) {
    final raw = prefs.getString(_todaySetKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final tips = <DailyTip>[];
          for (final item in decoded) {
            final tip = DailyTip.fromCacheJson(item);
            if (tip != null) tips.add(tip);
          }
          return tips;
        }
      } catch (_) {
        // Corrupt cache — fall through and redraw rather than crash.
      }
    }

    final legacy = DailyTip.fromCacheJson({
      'id': prefs.getString(_legacyTodayIdKey),
      'source': prefs.getString(_legacyTodaySourceKey),
      'text': prefs.getString(_legacyTodayTextKey),
      'hadithNumber': prefs.getInt(_legacyTodayHadithNumberKey),
      'category': prefs.getString(_legacyTodayCategoryKey),
    });
    return legacy == null ? const [] : [legacy];
  }

  /// Fills [existing] up to [target] messages. Anything already drawn today
  /// is kept exactly as it is — it may already be on screen — so this only
  /// ever appends.
  Future<List<DailyTip>> _drawTips(
    SharedPreferences prefs,
    String today,
    int target,
    List<DailyTip> existing,
  ) async {
    final pool = await _loadPool();
    // Nothing to draw from: hand back whatever the day already had rather
    // than wiping it.
    if (pool.isEmpty) return existing;

    final chosen = [...existing];
    final chosenIds = {for (final tip in chosen) tip.id};

    // 1. The admin's pins for today, in the order they were scheduled.
    for (final pinned in await _scheduledTipsFor(today, pool)) {
      if (chosen.length >= target) break;
      if (chosenIds.add(pinned.id)) chosen.add(pinned);
    }

    // 2. Random fill for whatever is still unfilled.
    var seenIds = (prefs.getStringList(_seenIdsKey) ?? const []).toSet();
    while (chosen.length < target) {
      var unseen = pool
          .where((t) => !seenIds.contains(t.id) && !chosenIds.contains(t.id))
          .toList();

      // Every message has had a turn — start a fresh cycle. A message
      // approved mid-cycle was never added to seenIds, so it would already
      // have surfaced in `unseen` above before this branch is ever reached.
      if (unseen.isEmpty) {
        seenIds = {};
        unseen = pool.where((t) => !chosenIds.contains(t.id)).toList();
        // The whole pool is already in today's set — a pool smaller than
        // messagesPerDay. Better a short day than a repeated message.
        if (unseen.isEmpty) break;
      }

      final pick = unseen[_random.nextInt(unseen.length)];
      chosen.add(pick);
      chosenIds.add(pick.id);
    }

    if (chosen.isEmpty) return chosen;

    seenIds.addAll(chosenIds);
    await Future.wait([
      prefs.setStringList(_seenIdsKey, seenIds.toList()),
      prefs.setString(
        _todaySetKey,
        jsonEncode([for (final tip in chosen) tip.toCacheJson()]),
      ),
      prefs.setString(_pickedOnDateKey, today),
      prefs.remove(_legacyTodayIdKey),
      prefs.remove(_legacyTodaySourceKey),
      prefs.remove(_legacyTodayTextKey),
      prefs.remove(_legacyTodayHadithNumberKey),
      prefs.remove(_legacyTodayCategoryKey),
    ]);

    // Fire-and-forget, and only for what this draw actually added: the pick
    // already succeeded from the reader's point of view, and a failed
    // counter update (offline, etc.) should not block it.
    for (final tip in chosen.skip(existing.length)) {
      unawaited(_recordShown(tip));
    }

    return chosen;
  }

  /// Today's pinned messages, if the dashboard scheduled any for `today` —
  /// see DailyMessageSchedulePage. Returns an empty list if there is no
  /// schedule doc, no entry for today, or the pinned messages were since
  /// deleted from the pool.
  Future<List<DailyTip>> _scheduledTipsFor(
    String today,
    List<DailyTip> pool,
  ) async {
    try {
      final doc =
          await _db.collection('settings').doc('dailyMessageSchedule').get();
      final days = doc.data()?['days'] as Map<String, dynamic>?;
      final entries = normaliseScheduledDay(days?[today]);

      final tips = <DailyTip>[];
      for (final entry in entries) {
        final messageId = entry['messageId'] as String?;
        if (messageId == null) continue;
        for (final tip in pool) {
          if (tip.id == messageId) {
            tips.add(tip);
            break;
          }
        }
      }
      return tips;
    } catch (_) {
      return const [];
    }
  }

  /// `days.<date>` held a single pin object before multi-message days; it
  /// holds a list now. Both shapes have to keep reading, since dates pinned
  /// under the old dashboard are still sitting in the live schedule doc.
  /// Shared with DailyMessageSchedulePage so the two never disagree on the
  /// shape.
  /// Always hands back a *growable* list, including for a date with nothing
  /// pinned yet: DailyMessageSchedulePage adds to and removes from the
  /// result in place, and a `const []` here made pinning the very first
  /// message of a date throw "Cannot add to an unmodifiable list" — which
  /// on web surfaces only as an opaque "Dart exception thrown from
  /// converted Future".
  static List<Map<String, dynamic>> normaliseScheduledDay(Object? raw) {
    if (raw is Map) return [Map<String, dynamic>.from(raw)];
    if (raw is List) {
      return [
        for (final item in raw)
          if (item is Map) Map<String, dynamic>.from(item),
      ];
    }
    return <Map<String, dynamic>>[];
  }

  Future<List<DailyTip>> _loadPool() async {
    final pool = <DailyTip>[];

    try {
      final snapshot = await _db.collection('dailyMessages').get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final text = (data['arabic'] as String?)?.trim() ?? '';
        if (text.isEmpty) continue;

        final category = (data['category'] as String?)?.trim();
        pool.add(
          DailyTip(
            id: doc.id,
            sourceCollection: 'dailyMessages',
            text: text,
            hadithNumber: data['hadithNumber'] as int? ?? 0,
            category: (category == null || category.isEmpty)
                ? 'رسالة اليوم'
                : category,
          ),
        );
      }
    } catch (_) {
      // Offline on first-ever launch, before anything is cached — the
      // community half below still gets a chance to contribute.
    }

    try {
      final snapshot = await _db
          .collection('communityMessages')
          .where('status', isEqualTo: 'approved')
          .get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final text = (data['message'] as String?)?.trim() ?? '';
        if (text.isEmpty) continue;

        pool.add(
          DailyTip(
            id: doc.id,
            sourceCollection: 'communityMessages',
            text: text,
            hadithNumber: data['hadithNumber'] as int? ?? 0,
            category: 'من مجتمع الحديث',
          ),
        );
      }
    } catch (_) {}

    return pool;
  }

  Future<void> _recordShown(DailyTip tip) async {
    try {
      await _db.collection(tip.sourceCollection).doc(tip.id).update({
        'timesShown': FieldValue.increment(1),
        'lastShownAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Offline, or the doc was removed since the pool was loaded — the
      // counter is informational, not worth surfacing an error for.
    }
  }

  String _todayString() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }
}
