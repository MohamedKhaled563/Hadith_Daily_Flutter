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
  final List<CommunityPost> _communityPosts = [
    CommunityPost(
      id: '1',
      authorName: 'سارة عبد الله',
      message: 'النية الصادقة تحول أدق تفاصيل يومك وأعمالك المعتادة إلى أجور عظيمة وقربات مباركة.',
      hadithNumber: 1,
      likes: 128,
    ),
    CommunityPost(
      id: '2',
      authorName: 'عمر خالد',
      message: 'الإحسان ليس فقط في العبادة، بل أن تعامل خلق الله كأنك تراه سبحانه.',
      hadithNumber: 2,
      likes: 94,
    ),
    CommunityPost(
      id: '3',
      authorName: 'فاطمة الزهراء',
      message: 'من حسن إسلام المرء تركه ما لا يعنيه.. راحة قلبية وعقلية لا تقدر بثمن.',
      hadithNumber: 12,
      likes: 87,
    ),
    CommunityPost(
      id: '4',
      authorName: 'عبد الرحمن أحمد',
      message: 'لا يؤمن أحدكم حتى يحب لأخيه ما يحب لنفسه.. أصل سلامة الصدر والمحبة بين الناس.',
      hadithNumber: 13,
      likes: 76,
    ),
    CommunityPost(
      id: '5',
      authorName: 'مريم محمود',
      message: 'قل خيراً أو اصمت.. قاعدة ذهبية تحفظ اللسان وتصون العلاقات وتورث الطمأنينة.',
      hadithNumber: 15,
      likes: 65,
    ),
  ];

  List<Insight> _insights = [];

  List<Hadith> get hadiths => _hadiths;
  List<Hadith> getAll() => _hadiths;
  List<Insight> get insights => _insights;
  List<CommunityPost> get communityPosts => _communityPosts;

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

  bool isInsightFavorite(String text) => _favoriteInsightTexts.contains(text);

  void toggleFavoriteInsight(String text) {
    if (_favoriteInsightTexts.contains(text)) {
      _favoriteInsightTexts.remove(text);
    } else {
      _favoriteInsightTexts.add(text);
    }
  }

  List<Insight> getFavoriteInsights() {
    return _insights.where((i) => _favoriteInsightTexts.contains(i.message)).toList();
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

  /// Messages attached to a given hadith. The workbook currently supplies
  /// these for hadiths 1-22 only, so this is empty for the rest.
  List<Insight> getInsightsForHadith(int hadithNumber) {
    return _insights.where((i) => i.hadithNumber == hadithNumber).toList();
  }

  void addCommunityPost(CommunityPost post) {
    _communityPosts.insert(0, post);
  }

  void togglePostLike(String id) {
    final index = _communityPosts.indexWhere((p) => p.id == id);
    if (index != -1) {
      final post = _communityPosts[index];
      post.isLiked = !post.isLiked;
      post.likes += post.isLiked ? 1 : -1;
    }
  }

  // Insight likes, keyed by message text like the favorites above. Starts at
  // zero rather than a seeded number — an honest count for this session
  // beats a number that looks real but isn't.
  final Set<String> _likedInsightTexts = <String>{};
  final Map<String, int> _insightLikeCounts = <String, int>{};

  bool isInsightLiked(String text) => _likedInsightTexts.contains(text);

  int insightLikeCount(String text) => _insightLikeCounts[text] ?? 0;

  void toggleInsightLike(String text) {
    final liked = _likedInsightTexts.contains(text);
    if (liked) {
      _likedInsightTexts.remove(text);
      _insightLikeCounts[text] = (insightLikeCount(text) - 1).clamp(0, 1 << 30);
    } else {
      _likedInsightTexts.add(text);
      _insightLikeCounts[text] = insightLikeCount(text) + 1;
    }
  }
}
