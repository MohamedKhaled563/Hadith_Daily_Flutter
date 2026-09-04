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
    required this.order,
  });

  final String id;
  final String sourceCollection; // 'dailyMessages' | 'communityMessages'
  final String text;
  final int hadithNumber;
  final String category;
  final int order;

  /// The card UI (DailyMessageScreen) speaks `Insight`, not this — keeps the
  /// screen itself unaware of where a tip came from.
  Insight toInsight() => Insight(
    hadithNumber: hadithNumber,
    arabic: text,
    english: '',
    category: category,
  );
}

/// The client-driven "tip of the day" engine — see the roadmap doc, §4.
///
/// Each device keeps its own seen-ids list and picks once per local day from
/// whatever it hasn't shown yet, reshuffling once the pool is exhausted.
/// There's no server-side scheduler: the only shared state is
/// `settings/deliveryMode` (manual walks the pool in `order`; random draws
/// uniformly), and every pick fires a narrow `timesShown` increment back to
/// whichever doc was chosen, both permitted by firestore.rules for any
/// signed-in device.
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
      order: 0, // never read back — order only matters at pick time
    );
  }

  Future<DailyTip?> _pickNewTip(SharedPreferences prefs, String today) async {
    final pool = await _loadPool();
    if (pool.isEmpty) return null;

    var seenIds = (prefs.getStringList(_seenIdsKey) ?? const []).toSet();
    var unseen = pool.where((t) => !seenIds.contains(t.id)).toList();

    // Every message has had a turn — start a fresh cycle. A message
    // approved mid-cycle was never added to seenIds, so it would already
    // have surfaced in `unseen` above before this branch is ever reached.
    if (unseen.isEmpty) {
      seenIds = {};
      unseen = pool;
    }

    final mode = await _deliveryMode();
    final DailyTip chosen;
    if (mode == 'manual') {
      unseen.sort((a, b) => a.order.compareTo(b.order));
      chosen = unseen.first;
    } else {
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

  Future<String> _deliveryMode() async {
    try {
      final doc = await _db.collection('settings').doc('deliveryMode').get();
      return doc.data()?['mode'] == 'manual' ? 'manual' : 'random';
    } catch (_) {
      return 'random';
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
            order: (data['order'] as num?)?.toInt() ?? 0,
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
            // No order yet from a moderator dashboard (phase 6) — sorts
            // after every deliberately-ordered dailyMessages entry rather
            // than colliding with them at 0.
            order: (data['order'] as num?)?.toInt() ?? (1 << 30),
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
