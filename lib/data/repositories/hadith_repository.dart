import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/hadith.dart';
import '../models/insight.dart';
import '../services/favorites_store.dart';

class HadithRepository {
  static final HadithRepository _instance = HadithRepository._internal();
  factory HadithRepository() => _instance;
  HadithRepository._internal();

  List<Hadith> _hadiths = [];
  List<Insight> _insights = [];

  List<Hadith> get hadiths => _hadiths;
  List<Hadith> getAll() => _hadiths;
  List<Insight> get insights => _insights;

  /// Loads the bundled content. Both files are generated from
  /// `assets/data/الأربعون_النووية_رسائل_يومية.xlsx` by
  /// `tool/import_hadiths_v2.py` and `tool/import_daily_messages_v2.py` —
  /// re-run those scripts rather than editing the JSON by hand.
  Future<void> load() async {
    await Future.wait(
        [loadHadiths(), _loadInsights(), _clearLegacyFavorites()]);
  }

  Future<void> _loadInsights() async {
    if (_insights.isNotEmpty) return;
    try {
      final jsonString =
          await rootBundle.loadString('assets/data/insights.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      _insights = jsonList
          .map((e) => Insight.fromJson(e as Map<String, dynamic>))
          .where((i) => i.arabic.isNotEmpty)
          .toList();
    } catch (error, stackTrace) {
      assert(() {
        debugPrint(
          'HadithRepository: failed to load assets/data/insights.json. '
          'Error: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
        return true;
      }());
      _insights = const [];
    }
  }

  Future<void> loadHadiths() async {
    if (_hadiths.isNotEmpty) return;
    try {
      final String jsonString =
          await rootBundle.loadString('assets/data/hadiths.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      _hadiths = jsonList
          .map((e) => Hadith.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (error, stackTrace) {
      // Should not happen in a normal build — assets/data/hadiths.json is
      // bundled (see pubspec.yaml) and ships all 42 hadiths. This is a
      // last-resort fallback so a corrupt/missing asset degrades to 1 hadith
      // instead of crashing. This used to be `catch (_) {}`, which hid the
      // failure completely. Keep it loud so a real regression isn't missed.
      assert(() {
        debugPrint(
          'HadithRepository: failed to load assets/data/hadiths.json — '
          'falling back to a single sample hadith. Error: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
        return true;
      }());

      _hadiths = [
        const Hadith(
          number: 1,
          title: 'إنما الأعمال بالنيات',
          text:
              'إنما الأعمال بالنيات، وإنما لكل امرئ ما نوى، فمن كانت هجرته إلى الله ورسوله فهجرته إلى الله ورسوله...',
          reference: 'متفق عليه (البخاري ومسلم)',
          explanation:
              'هذا الحديث أصل عظيم من أصول الإسلام وقاعدة تدور عليها جميع تصرفات العبد، حيث يُربط قبول العمل بصلاح النية وإخلاصها لله تعالى.',
          keyLessons: [
            'النية هي الميزان الحقيقي لصحة الأعمال وقبولها.',
            'تحويل العادات اليومية إلى عبادات عظيمة باستحضار النية الصالحة.',
            'ضرورة مراقبة القلب والإخلاص لله في السر والعلن.',
          ],
        ),
      ];
    }
  }

  // ------------------------------------------------------- favourites ----
  //
  // Per account, in Firestore — see [FavoritesStore]. A guest has none and
  // cannot add any; the UI asks them to sign in first (requireSignIn).
  //
  // They used to live in SharedPreferences, seeded with hadiths 1, 2 and 12
  // "so a first launch doesn't look empty". The seed was meant to be replaced
  // by the stored list, but a fresh install has no stored list, so every new
  // install on every platform opened with three favourites nobody chose.

  /// The SharedPreferences keys favourites used to live under. Cleared on
  /// load so a phone that had them does not keep them around forever.
  static const _legacyPrefsKeys = [
    'favoriteHadithNumbers',
    'favoriteInsightTexts'
  ];

  FavoritesStore? _storeOverride;
  FavoritesStore? _defaultStore;
  FavoritesStore get _store =>
      _storeOverride ?? (_defaultStore ??= FirestoreFavoritesStore());

  String? Function() _currentUid = () => FirebaseAuth.instance.currentUser?.uid;

  /// Swaps Firestore and FirebaseAuth out for tests.
  @visibleForTesting
  void debugOverrideFavorites({
    required FavoritesStore store,
    required String? Function() currentUid,
  }) {
    _storeOverride = store;
    _currentUid = currentUid;
    _bindUser(currentUid());
  }

  String? _uid;
  StreamSubscription<List<Map<String, dynamic>>>? _favoritesSub;

  Set<int> _favoriteHadithNumbers = <int>{};

  // Keyed on hadithNumber + text (see [_insightKey]), storing the Insight
  // itself: a message that came from a reader's community submission is not
  // in the bundled insights.json, so the list has to carry its own copy.
  Map<String, Insight> _favoriteInsights = <String, Insight>{};

  final ValueNotifier<int> _favoritesRevision = ValueNotifier<int>(0);

  /// Fires whenever the favourites change — a toggle here, the account's
  /// list arriving after sign-in, or it clearing on sign-out.
  Listenable get favoritesListenable => _favoritesRevision;

  /// Whether favourites currently belong to a signed-in account. Guests have
  /// none and cannot add any.
  bool get hasFavoritesAccount => _uid != null;

  Future<void> _clearLegacyFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _legacyPrefsKeys) {
      if (prefs.containsKey(key)) await prefs.remove(key);
    }
  }

  /// Points favourites at [uid]'s list, or clears them for a guest.
  /// [AppStateController] calls this on every auth change.
  void setUser(String? uid) {
    if (uid == _uid) return;
    _bindUser(uid);
  }

  void _bindUser(String? uid) {
    _uid = uid;
    _favoritesSub?.cancel();
    _favoritesSub = null;
    _favoriteHadithNumbers = <int>{};
    _favoriteInsights = <String, Insight>{};
    _favoritesRevision.value++;

    if (uid == null) return;
    _favoritesSub = _store.watch(uid).listen(
      (docs) {
        if (_uid != uid) return;
        _applyFavoriteDocs(docs);
      },
      onError: (Object error) {
        debugPrint('HadithRepository: favourites for $uid failed: $error');
      },
    );
  }

  /// The signed-in uid, catching up if auth changed before
  /// [AppStateController]'s listener got to [setUser] — which is exactly the
  /// case right after the sign-in sheet closes and the reader's save goes
  /// through.
  String? _resolveUid() {
    final uid = _currentUid();
    if (uid != _uid) setUser(uid);
    return uid;
  }

  void _applyFavoriteDocs(List<Map<String, dynamic>> docs) {
    // Oldest first; a pending write (no server timestamp yet) is newest.
    int order(Map<String, dynamic> d) {
      final t = d['createdAt'];
      if (t is Timestamp) return t.millisecondsSinceEpoch;
      if (t is num) return t.toInt();
      return 1 << 52;
    }

    final sorted = [...docs]..sort((a, b) => order(a).compareTo(order(b)));
    final hadiths = <int>{};
    final insights = <String, Insight>{};
    for (final doc in sorted) {
      try {
        switch (doc['kind']) {
          case 'hadith':
            hadiths.add(doc['hadithNumber'] as int);
          case 'insight':
            final insight = Insight.fromJson(doc);
            insights[_insightKey(insight)] = insight;
        }
      } catch (_) {
        // A malformed doc shouldn't take the rest of the list down with it.
      }
    }
    _favoriteHadithNumbers = hadiths;
    _favoriteInsights = insights;
    _favoritesRevision.value++;
  }

  Set<int> get favoriteHadithNumbers => _favoriteHadithNumbers;
  Set<String> get favoriteInsightTexts => _favoriteInsights.keys.toSet();

  bool isHadithFavorite(int number) => _favoriteHadithNumbers.contains(number);

  /// Throws [StateError] for a guest — gate the control with requireSignIn.
  void toggleFavoriteHadith(int number) {
    final uid = _requireUid();
    final docId = 'hadith-$number';
    if (_favoriteHadithNumbers.contains(number)) {
      _favoriteHadithNumbers.remove(number);
      _write(_store.remove(uid, docId));
    } else {
      _favoriteHadithNumbers.add(number);
      _write(
          _store.put(uid, docId, {'kind': 'hadith', 'hadithNumber': number}));
    }
    _favoritesRevision.value++;
  }

  // Keyed by hadithNumber+text rather than text alone: the source workbook
  // has no per-insight id, and two distinct entries under different hadiths
  // sharing identical text (a plausible generic reminder) would otherwise
  // collide — favoriting/liking one would silently favorite/like both.
  String _insightKey(Insight insight) =>
      '${insight.hadithNumber}::${insight.message}';

  /// A Firestore doc id for an insight key. The key can run to thousands of
  /// bytes of Arabic, past the doc-id limit, so it is hashed: two FNV-1a
  /// passes with different seeds, 64 bits between them, in arithmetic that
  /// stays exact on the web too.
  static String _insightDocId(String key) {
    int fnv(int seed) {
      var h = seed;
      for (final unit in key.codeUnits) {
        h = (h ^ unit) & 0xFFFFFFFF;
        // h * 16777619 mod 2^32, where 16777619 = 2^24 + 403.
        h = (h * 403 + (h & 0xFF) * 16777216) % 4294967296;
      }
      return h;
    }

    String hex(int v) => v.toRadixString(16).padLeft(8, '0');
    return 'insight-${hex(fnv(0x811C9DC5))}${hex(fnv(0x01000193))}';
  }

  bool isInsightFavorite(Insight insight) =>
      _favoriteInsights.containsKey(_insightKey(insight));

  /// Throws [StateError] for a guest — gate the control with requireSignIn.
  void toggleFavoriteInsight(Insight insight) {
    final uid = _requireUid();
    final key = _insightKey(insight);
    final docId = _insightDocId(key);
    if (_favoriteInsights.containsKey(key)) {
      _favoriteInsights.remove(key);
      _write(_store.remove(uid, docId));
    } else {
      _favoriteInsights[key] = insight;
      _write(_store.put(uid, docId, {
        'kind': 'insight',
        'hadithNumber': insight.hadithNumber,
        'arabic': insight.arabic,
        'english': insight.english,
        'category': insight.category,
        'themes': insight.themes,
        'keywords': insight.keywords,
        'id': insight.id,
        'sourceCollection': insight.sourceCollection,
      }));
    }
    _favoritesRevision.value++;
  }

  String _requireUid() {
    final uid = _resolveUid();
    if (uid == null) {
      throw StateError('Must be signed in to save favourites.');
    }
    return uid;
  }

  /// Writes are fire-and-forget: the local state has already changed, and
  /// Firestore queues the write while offline. A write the rules reject is
  /// corrected by the next snapshot, which will not carry it.
  void _write(Future<void> write) {
    unawaited(write.catchError((Object error) {
      debugPrint('HadithRepository: favourite write failed: $error');
    }));
  }

  List<Insight> getFavoriteInsights() => _favoriteInsights.values.toList();

  List<Hadith> getFavoriteHadiths() {
    return _hadiths
        .where((h) => _favoriteHadithNumbers.contains(h.number))
        .toList();
  }

  Hadith? getByNumber(int number) {
    try {
      return _hadiths.firstWhere((h) => h.number == number);
    } catch (_) {
      return null;
    }
  }

  /// A random daily message, or null when none are loaded.
  Insight? getRandomInsight() {
    if (_insights.isEmpty) return null;
    return _insights[Random().nextInt(_insights.length)];
  }

  /// Messages attached to a given hadith.
  List<Insight> getInsightsForHadith(int hadithNumber) {
    return _insights.where((i) => i.hadithNumber == hadithNumber).toList();
  }
}
