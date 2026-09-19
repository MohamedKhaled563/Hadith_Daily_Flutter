import 'dart:async';
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
}

/// The client-driven "tip of the day" engine — see the roadmap doc, §4.
///
/// Each device keeps its own seen-ids list and picks once per local day from
/// whatever it hasn't shown yet, reshuffling once the pool is exhausted.
/// There's no server-side scheduler: the only shared state is
/// `settings/dailyMessageSchedule`'s `days` map (see
/// DailyMessageSchedulePage), keyed by yyyy-MM-dd — if today's key is in
/// there, every device shows that message regardless of its own
/// seen-history; otherwise each device draws uniformly at random from
/// whatever it hasn't shown yet. Every pick fires a narrow `timesShown`
/// increment back to whichever doc was chosen, permitted by
/// firestore.rules for any signed-in device.
class DailyTipService {
  DailyTipService._internal();
  static final DailyTipService instance = DailyTipService._internal();
  factory DailyTipService() => instance;

  static const _seenIdsKey = 'dailyTip.seenIds';
  static const _todayIdKey = 'dailyTip.todayId';
  static const _todaySourceKey = 'dailyTip.todaySource';
  static const _todayTextKey = 'dailyTip.todayText';
  static const _todayHadithNumberKey = 'dailyTip.todayHadithNumber';
  static const _todayCategoryKey = 'dailyTip.todayCategory';
  static const _pickedOnDateKey = 'dailyTip.pickedOnDate';

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Random _random = Random();

  /// Today's tip — the same one on every call within the same local day,
  /// a freshly picked one the first call after the day rolls over. Null
  /// only if the pool itself is empty (e.g. no connectivity on first ever
  /// launch, before anything is cached).
  Future<DailyTip?> getTodayTip() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString();

    if (prefs.getString(_pickedOnDateKey) == today) {
      final cached = _readCached(prefs);
      if (cached != null) return cached;
    }

    return _pickNewTip(prefs, today);
  }

  DailyTip? _readCached(SharedPreferences prefs) {
    final id = prefs.getString(_todayIdKey);
    final text = prefs.getString(_todayTextKey);
    if (id == null || text == null) return null;

    return DailyTip(
      id: id,
      sourceCollection: prefs.getString(_todaySourceKey) ?? 'dailyMessages',
      text: text,
      hadithNumber: prefs.getInt(_todayHadithNumberKey) ?? 0,
      category: prefs.getString(_todayCategoryKey) ?? 'رسالة اليوم',
    );
  }

  Future<DailyTip?> _pickNewTip(SharedPreferences prefs, String today) async {
    final pool = await _loadPool();
    if (pool.isEmpty) return null;

    var seenIds = (prefs.getStringList(_seenIdsKey) ?? const []).toSet();

    final scheduled = await _scheduledTipFor(today, pool);
    final DailyTip chosen;
    if (scheduled != null) {
      chosen = scheduled;
    } else {
      var unseen = pool.where((t) => !seenIds.contains(t.id)).toList();

      // Every message has had a turn — start a fresh cycle. A message
      // approved mid-cycle was never added to seenIds, so it would already
      // have surfaced in `unseen` above before this branch is ever reached.
      if (unseen.isEmpty) {
        seenIds = {};
        unseen = pool;
      }

      chosen = unseen[_random.nextInt(unseen.length)];
    }

    seenIds.add(chosen.id);
    await Future.wait([
      prefs.setStringList(_seenIdsKey, seenIds.toList()),
      prefs.setString(_todayIdKey, chosen.id),
      prefs.setString(_todaySourceKey, chosen.sourceCollection),
      prefs.setString(_todayTextKey, chosen.text),
      prefs.setInt(_todayHadithNumberKey, chosen.hadithNumber),
      prefs.setString(_todayCategoryKey, chosen.category),
      prefs.setString(_pickedOnDateKey, today),
    ]);

    // Fire-and-forget: the pick already succeeded from the reader's point of
    // view, and a failed counter update (offline, etc.) shouldn't block it.
    unawaited(_recordShown(chosen));

    return chosen;
  }

  /// Today's pinned message, if the dashboard scheduled one for `today` —
  /// see DailyMessageSchedulePage. Falls through to the normal random pick
  /// if there's no schedule doc, no entry for today, or the pinned message
  /// was since deleted from the pool.
  Future<DailyTip?> _scheduledTipFor(String today, List<DailyTip> pool) async {
    try {
      final doc =
          await _db.collection('settings').doc('dailyMessageSchedule').get();
      final days = doc.data()?['days'] as Map<String, dynamic>?;
      final entry = days?[today] as Map<String, dynamic>?;
      final messageId = entry?['messageId'] as String?;
      if (messageId == null) return null;
      for (final tip in pool) {
        if (tip.id == messageId) return tip;
      }
      return null;
    } catch (_) {
      return null;
    }
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
