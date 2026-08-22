import 'dart:convert';
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

  final List<Insight> _insights = const [
    Insight(
      hadithNumber: 1,
      arabic: 'قد يكون العمل نفسه عبادة عند شخص... وعادة عند آخر. والفرق يبدأ من النية.',
      english: 'The intention transforms daily habits into beloved acts of worship.',
    ),
    Insight(
      hadithNumber: 2,
      arabic: 'الإحسان أن تعبد الله كأنك تراه؛ استشعار قربه يملأ القلب سكينة وخشوعاً.',
      english: 'Excellence is to live with the conscious awareness of the Creator.',
    ),
    Insight(
      hadithNumber: 11,
      arabic: 'دع ما يريبك إلى ما لا يريبك؛ راحة الضمير وطمأنينة القلب أثمن ما تملكه.',
      english: 'Leave that which causes you doubt for that which brings clarity and peace.',
    ),
    Insight(
      hadithNumber: 12,
      arabic: 'سلامة قلبك تبدأ عندما تترك ما لا يعنيك، وتنشغل بما يصلح حالك ويقربك من ربك.',
      english: 'True mindfulness begins by letting go of matters that do not concern you.',
    ),
    Insight(
      hadithNumber: 13,
      arabic: 'اتساع قلبك لمحبة الخير للناس علامة اكتمال إيمانك ونقاء سريرتك.',
      english: 'Loving for others what you love for yourself is the essence of faith.',
    ),
    Insight(
      hadithNumber: 15,
      arabic: 'الكلمة الطيبة صدقة، والصمت عن الأذى سلامة لك ولمن حولك.',
      english: 'Speak good or remain silent; gentle words mend hearts.',
    ),
    Insight(
      hadithNumber: 16,
      arabic: 'لا تغضب؛ وصية نبوية جامعة تحفظ بها هدوءك وعلاقاتك وصفاء روحك.',
      english: 'Do not be overcome by anger; tranquility is the hallmark of strength.',
    ),
    Insight(
      hadithNumber: 18,
      arabic: 'اتق الله حيثما كنت، وأتبع السيئة الحسنة تمحها، وخالق الناس بخلق حسن.',
      english: 'Consciousness of God and beautiful character adorn every action.',
    ),
  ];

  List<Hadith> get hadiths => _hadiths;
  List<Hadith> getAll() => _hadiths;
  List<Insight> get insights => _insights;
  List<CommunityPost> get communityPosts => _communityPosts;

  Future<void> loadHadiths() async {
    if (_hadiths.isNotEmpty) return;
    try {
      final String jsonString = await rootBundle.loadString('assets/data/hadiths.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      _hadiths = jsonList.map((e) => Hadith.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      // Fallback default sample if json asset is missing
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

  Hadith? getByNumber(int number) {
    try {
      return _hadiths.firstWhere((h) => h.number == number);
    } catch (_) {
      return null;
    }
  }

  Insight getRandomInsight() {
    final list = List<Insight>.from(_insights);
    list.shuffle();
    return list.first;
  }

  Insight getInsightForHadith(int hadithNumber) {
    return _insights.firstWhere(
      (i) => i.hadithNumber == hadithNumber,
      orElse: () => _insights.first,
    );
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
}
