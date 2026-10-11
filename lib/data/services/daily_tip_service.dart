import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
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
  ///
  /// Concurrent callers share one draw: the home screen's emblem and a
  /// reminder tap can both ask at once, and two overlapping draws would each
  /// append to seenIds and bump timesShown for messages only one of them
  /// keeps.
  Future<List<DailyTip>> getTodayTips() =>
      _inFlight ??= _getTodayTips().whenComplete(() => _inFlight = null);

  Future<List<DailyTip>>? _inFlight;

  Future<List<DailyTip>> _getTodayTips() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString();

    final cached = prefs.getString(_pickedOnDateKey) == today
        ? _readCachedSet(prefs)
        : const <DailyTip>[];

    // Already drawn today and still big enough — including the case where
    // the admin has since lowered the count, which must not shrink a day
    // that is already running.
    //
    // Answered from the device alone. This used to await a server read of
    // dailyMessageConfig first, on every call, so even a day that was fully
    // drawn and sitting in SharedPreferences showed the loading overlay for
    // a round trip — and for a good deal longer than that on a weak signal.
    // The config is refreshed behind the answer instead; a raised count
    // tops the day up on the next call.
    if (cached.isNotEmpty && cached.length >= _knownMessagesPerDay(prefs)) {
      unawaited(_messagesPerDay(prefs));
      return cached;
    }

    final prepared = await _prepare(today);
    final tips = await _drawTips(prefs, today, prepared, cached);
    // Spent: a later top-up the same day should see a fresh pool and count.
    if (identical(_prepared, prepared)) _prepared = null;
    return tips;
  }

  /// Fetches everything a draw needs — the count, the pool and today's pins
  /// — without drawing, so pressing the emblem afterwards is local work
  /// only. SplashScreen calls this while its quote is on screen, and the app
  /// again on resume in case the day rolled over in the background.
  ///
  /// Deliberately stops short of drawing: a draw marks messages as seen and
  /// bumps their timesShown, and a reader who opens the app without pressing
  /// طيّب قلبك has not been shown anything.
  ///
  /// Never throws.
  Future<void> warmUp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _todayString();
      final drawn = prefs.getString(_pickedOnDateKey) == today &&
          _readCachedSet(prefs).length >= _knownMessagesPerDay(prefs);
      if (drawn) {
        await _messagesPerDay(prefs);
      } else {
        await _prepare(today);
      }
    } catch (_) {
      // Best effort — getTodayTips() fetches for itself if this did not.
    }
  }

  _PreparedDraw? _prepared;
  Future<_PreparedDraw>? _preparing;

  /// One fetch for a day, shared: a warm-up still in flight when the emblem
  /// is pressed is joined rather than started again.
  Future<_PreparedDraw> _prepare(String today) {
    final ready = _prepared;
    if (ready != null && ready.day == today) return Future.value(ready);
    return _preparing ??= _fetchDraw(today).then((draw) {
      // An empty pool is a failed fetch, not a result worth keeping.
      if (draw.pool.isNotEmpty) _prepared = draw;
      return draw;
    }).whenComplete(() => _preparing = null);
  }

  /// The reads a draw needs, in parallel — they used to run one after
  /// another, four round trips counting the pool's two halves, which is most
  /// of why the first message of the day took seconds to appear.
  Future<_PreparedDraw> _fetchDraw(String today) async {
    final prefs = await SharedPreferences.getInstance();
    final results = await Future.wait<Object>([
      _messagesPerDay(prefs),
      _loadPool(),
      _scheduledIdsFor(today),
    ]);
    return _PreparedDraw(
      day: today,
      target: results[0] as int,
      pool: results[1] as List<DailyTip>,
      pinnedIds: results[2] as List<String>,
    );
  }

  /// Convenience for callers that only ever show one card — the notification
  /// deep links land on the first message of the day.
  Future<DailyTip?> getTodayTip() async {
    final tips = await getTodayTips();
    return tips.isEmpty ? null : tips.first;
  }

  /// How many of today's messages the reader has opened so far.
  ///
  /// **Zero means they have not opened today's message yet** — the home
  /// screen is still showing the emblem waiting to be pressed. One or more
  /// means the message is out, and home shows it instead of the emblem for
  /// the rest of the day.
  ///
  /// That is the whole point of persisting it: pressing طيّب قلبك is a
  /// once-a-day act. Having done it, closing the app and coming back must
  /// return the reader to their message, not to an emblem that makes them
  /// ask for it again. Resets with the day, like the set itself.
  Future<int> revealedCount() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_revealedOnDateKey) != _todayString()) return 0;
    final stored = prefs.getInt(_revealedCountKey) ?? 0;
    return stored < 0 ? 0 : stored;
  }

  /// Records that [count] of today's messages have now been revealed. Only
  /// ever moves forward within a day — a caller reporting a smaller number
  /// must not un-reveal what was already read.
  Future<void> saveRevealedCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    final isToday = prefs.getString(_revealedOnDateKey) == _todayString();
    final previous = isToday ? (prefs.getInt(_revealedCountKey) ?? 0) : 0;
    if (count <= previous) return;
    await prefs.setString(_revealedOnDateKey, _todayString());
    await prefs.setInt(_revealedCountKey, count);
  }

  /// Marks today's message as opened if it was not already, and reports how
  /// many are now revealed. Used by the paths that arrive at the message
  /// without the reader having pressed the emblem — tapping a reminder,
  /// most obviously, which should land on the message rather than on an
  /// emblem waiting to be asked.
  Future<int> ensureOpenedToday() async {
    final current = await revealedCount();
    if (current >= 1) return current;
    await saveRevealedCount(1);
    return 1;
  }

  /// Test seam: pins how many messages a day carries.
  ///
  /// Without it a widget test that seeds a two-message day is not testing a
  /// two-message day at all — [_messagesPerDay] asks Firestore first, and on
  /// a device with a network that answer wins and the seeded day gets topped
  /// up from the live pool. The test then passes or fails on whether the
  /// machine happened to be online, which is how three of these tests came
  /// to pass on a phone with no signal and fail on an emulator with one.
  @visibleForTesting
  static int? debugMessagesPerDay;

  /// How many messages today should carry. Falls back to the last value this
  /// device saw, then to 1, so a failed fetch never changes what the reader
  /// gets.
  Future<int> _messagesPerDay(SharedPreferences prefs) async {
    final pinned = debugMessagesPerDay;
    if (pinned != null) return pinned;
    try {
      final doc = await _getDoc(
        _db.collection('settings').doc('dailyMessageConfig'),
      );
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

    return _knownMessagesPerDay(prefs);
  }

  /// The last count this device saw, without asking anyone.
  int _knownMessagesPerDay(SharedPreferences prefs) {
    final pinned = debugMessagesPerDay;
    if (pinned != null) return pinned;
    final cached = prefs.getInt(_messagesPerDayKey) ?? 1;
    return cached < 1 ? 1 : cached;
  }

  /// How long a read waits on the server before settling for Firestore's
  /// local cache. A plain `get()` prefers the server, and on a weak or
  /// dropping connection it can hold out for many seconds before falling
  /// back — all of it spent behind the loading overlay.
  static const _serverBudget = Duration(seconds: 3);

  Future<DocumentSnapshot<Map<String, dynamic>>> _getDoc(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      return await ref.get().timeout(_serverBudget);
    } on TimeoutException {
      return ref.get(const GetOptions(source: Source.cache));
    }
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _getQuery(
    Query<Map<String, dynamic>> query,
  ) async {
    try {
      return await query.get().timeout(_serverBudget);
    } on TimeoutException {
      return query.get(const GetOptions(source: Source.cache));
    }
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
    _PreparedDraw prepared,
    List<DailyTip> existing,
  ) async {
    final pool = prepared.pool;
    final target = prepared.target;
    // Nothing to draw from: hand back whatever the day already had rather
    // than wiping it.
    if (pool.isEmpty) return existing;

    final chosen = [...existing];
    final chosenIds = {for (final tip in chosen) tip.id};

    // 1. The admin's pins for today, in the order they were scheduled.
    for (final pinned in _pinnedTips(prepared.pinnedIds, pool)) {
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
  Future<List<String>> _scheduledIdsFor(String today) async {
    try {
      final doc = await _getDoc(
        _db.collection('settings').doc('dailyMessageSchedule'),
      );
      final days = doc.data()?['days'] as Map<String, dynamic>?;
      return [
        for (final entry in normaliseScheduledDay(days?[today]))
          if (entry['messageId'] is String) entry['messageId'] as String,
      ];
    } catch (_) {
      return const [];
    }
  }

  List<DailyTip> _pinnedTips(List<String> ids, List<DailyTip> pool) {
    final byId = {for (final tip in pool) tip.id: tip};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
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
    final halves = await Future.wait([_loadSeeded(), _loadCommunity()]);
    return [...halves[0], ...halves[1]];
  }

  Future<List<DailyTip>> _loadSeeded() async {
    final pool = <DailyTip>[];

    try {
      final snapshot = await _getQuery(_db.collection('dailyMessages'));
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
      // community half still gets a chance to contribute.
    }
    return pool;
  }

  Future<List<DailyTip>> _loadCommunity() async {
    final pool = <DailyTip>[];

    try {
      final snapshot = await _getQuery(
        _db
            .collection('communityMessages')
            .where('status', isEqualTo: 'approved'),
      );
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

/// What [DailyTipService.warmUp] fetches ahead of a draw, for one local day.
class _PreparedDraw {
  const _PreparedDraw({
    required this.day,
    required this.target,
    required this.pool,
    required this.pinnedIds,
  });

  final String day;
  final int target;
  final List<DailyTip> pool;
  final List<String> pinnedIds;
}
