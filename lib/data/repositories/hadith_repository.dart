import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/hadith.dart';
import '../models/insight.dart';

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
    await Future.wait([loadHadiths(), _loadInsights(), _loadFavorites()]);
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
      final String jsonString = await rootBundle.loadString('assets/data/hadiths.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      _hadiths = jsonList.map((e) => Hadith.fromJson(e as Map<String, dynamic>)).toList();
    } catch (error, stackTrace) {
      // assets/data/hadiths.json is currently absent from the bundle, so this
      // path is the one that actually runs — the app ships with 1 of the 42
      // hadiths. This used to be `catch (_) {}`, which hid the failure
      // completely. Keep it loud until the real data file is added.
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
          text: 'إنما الأعمال بالنيات، وإنما لكل امرئ ما نوى، فمن كانت هجرته إلى الله ورسوله فهجرته إلى الله ورسوله...',
          reference: 'متفق عليه (البخاري ومسلم)',
          explanation: 'هذا الحديث أصل عظيم من أصول الإسلام وقاعدة تدور عليها جميع تصرفات العبد، حيث يُربط قبول العمل بصلاح النية وإخلاصها لله تعالى.',
          keyLessons: [
            'النية هي الميزان الحقيقي لصحة الأعمال وقبولها.',
            'تحويل العادات اليومية إلى عبادات عظيمة باستحضار النية الصالحة.',
            'ضرورة مراقبة القلب والإخلاص لله في السر والعلن.',
          ],
        ),
      ];
    }
  }

  static const _favoriteHadithsPrefsKey = 'favoriteHadithNumbers';
  static const _favoriteInsightsPrefsKey = 'favoriteInsightTexts';

  // Seeded with a few favorites so a first-ever launch doesn't look empty;
  // overwritten by whatever's in SharedPreferences as soon as _loadFavorites
  // resolves, so this default only ever shows for an instant on first run.
  Set<int> _favoriteHadithNumbers = {1, 2, 12};

  // Keyed the same way as before, but stores the actual Insight rather than
  // just its key. Storing only the key worked fine for *checking* favorite
  // state, but `getFavoriteInsights()` used to reconstruct the list by
  // filtering the bundled `_insights` (the 246 entries shipped in
  // insights.json) — so a daily message whose text came from a *reader's*
  // community submission rather than the moderator-curated bundle matched no
  // key was still marked, but it could never appear in the reader's own
  // Favorites list. Keeping the Insight itself fixes that regardless of
  // where the message originated.
  Map<String, Insight> _favoriteInsights = <String, Insight>{};

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final storedHadiths = prefs.getStringList(_favoriteHadithsPrefsKey);
    if (storedHadiths != null) {
      _favoriteHadithNumbers = storedHadiths.map(int.parse).toSet();
    }

    final storedInsights = prefs.getStringList(_favoriteInsightsPrefsKey);
    if (storedInsights != null) {
      final restored = <String, Insight>{};
      for (final entry in storedInsights) {
        try {
          final insight = Insight.fromJson(
            json.decode(entry) as Map<String, dynamic>,
          );
          restored[_insightKey(insight)] = insight;
        } catch (_) {
          // A malformed entry shouldn't take the rest of the list down with
          // it — just drop that one favorite.
        }
      }
      _favoriteInsights = restored;
    }
  }

  Future<void> _persistFavoriteHadiths() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _favoriteHadithsPrefsKey,
      _favoriteHadithNumbers.map((n) => n.toString()).toList(),
    );
  }

  Future<void> _persistFavoriteInsights() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _favoriteInsightsPrefsKey,
      _favoriteInsights.values
          .map(
            (i) => json.encode({
              'hadithNumber': i.hadithNumber,
              'arabic': i.arabic,
              'english': i.english,
              'category': i.category,
              'themes': i.themes,
              'keywords': i.keywords,
              'id': i.id,
              'sourceCollection': i.sourceCollection,
            }),
          )
          .toList(),
    );
  }

  Set<int> get favoriteHadithNumbers => _favoriteHadithNumbers;
  Set<String> get favoriteInsightTexts => _favoriteInsights.keys.toSet();

  bool isHadithFavorite(int number) => _favoriteHadithNumbers.contains(number);

  void toggleFavoriteHadith(int number) {
    if (_favoriteHadithNumbers.contains(number)) {
      _favoriteHadithNumbers.remove(number);
    } else {
      _favoriteHadithNumbers.add(number);
    }
    unawaited(_persistFavoriteHadiths());
  }

  // Keyed by hadithNumber+text rather than text alone: the source workbook
  // has no per-insight id, and two distinct entries under different hadiths
  // sharing identical text (a plausible generic reminder) would otherwise
  // collide — favoriting/liking one would silently favorite/like both.
  String _insightKey(Insight insight) => '${insight.hadithNumber}::${insight.message}';

  bool isInsightFavorite(Insight insight) =>
      _favoriteInsights.containsKey(_insightKey(insight));

  void toggleFavoriteInsight(Insight insight) {
    final key = _insightKey(insight);
    if (_favoriteInsights.containsKey(key)) {
      _favoriteInsights.remove(key);
    } else {
      _favoriteInsights[key] = insight;
    }
    unawaited(_persistFavoriteInsights());
  }

  List<Insight> getFavoriteInsights() => _favoriteInsights.values.toList();

  List<Hadith> getFavoriteHadiths() {
    return _hadiths.where((h) => _favoriteHadithNumbers.contains(h.number)).toList();
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
