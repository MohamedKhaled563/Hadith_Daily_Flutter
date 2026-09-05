import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
    await Future.wait([loadHadiths(), _loadInsights()]);
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

  final Set<int> _favoriteHadithNumbers = {1, 2, 12};
  // Seeded empty: the previous demo entries referenced sample messages that
  // no longer exist now that the content comes from the workbook.
  final Set<String> _favoriteInsightTexts = <String>{};

  Set<int> get favoriteHadithNumbers => _favoriteHadithNumbers;
  Set<String> get favoriteInsightTexts => _favoriteInsightTexts;

  bool isHadithFavorite(int number) => _favoriteHadithNumbers.contains(number);

  void toggleFavoriteHadith(int number) {
    if (_favoriteHadithNumbers.contains(number)) {
      _favoriteHadithNumbers.remove(number);
    } else {
      _favoriteHadithNumbers.add(number);
    }
  }

  // Keyed by hadithNumber+text rather than text alone: the source workbook
  // has no per-insight id, and two distinct entries under different hadiths
  // sharing identical text (a plausible generic reminder) would otherwise
  // collide — favoriting/liking one would silently favorite/like both.
  String _insightKey(Insight insight) => '${insight.hadithNumber}::${insight.message}';

  bool isInsightFavorite(Insight insight) =>
      _favoriteInsightTexts.contains(_insightKey(insight));

  void toggleFavoriteInsight(Insight insight) {
    final key = _insightKey(insight);
    if (_favoriteInsightTexts.contains(key)) {
      _favoriteInsightTexts.remove(key);
    } else {
      _favoriteInsightTexts.add(key);
    }
  }

  List<Insight> getFavoriteInsights() {
    return _insights
        .where((i) => _favoriteInsightTexts.contains(_insightKey(i)))
        .toList();
  }

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

  // Insight likes, keyed by message text like the favorites above. Starts at
  // zero rather than a seeded number — an honest count for this session
  // beats a number that looks real but isn't.
  final Set<String> _likedInsightTexts = <String>{};
  final Map<String, int> _insightLikeCounts = <String, int>{};

  bool isInsightLiked(Insight insight) =>
      _likedInsightTexts.contains(_insightKey(insight));

  int insightLikeCount(Insight insight) =>
      _insightLikeCounts[_insightKey(insight)] ?? 0;

  void toggleInsightLike(Insight insight) {
    final key = _insightKey(insight);
    final liked = _likedInsightTexts.contains(key);
    if (liked) {
      _likedInsightTexts.remove(key);
      _insightLikeCounts[key] = ((_insightLikeCounts[key] ?? 0) - 1).clamp(0, 1 << 30);
    } else {
      _likedInsightTexts.add(key);
      _insightLikeCounts[key] = (_insightLikeCounts[key] ?? 0) + 1;
    }
  }
}
