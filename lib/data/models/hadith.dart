class Hadith {
  final int number;
  final String title;
  final String text;
  final String? source;
  final String reference;
  final String explanation;

  /// Brief, one-paragraph summary of [explanation], from the source
  /// workbook. Empty when unavailable.
  final String shortExplanation;

  final List<String> keyLessons;

  /// Biography of the companion who narrated the hadith, from the source
  /// workbook. Empty when unavailable.
  final String narratorBio;

  /// Name of the companion who narrated the hadith (الراوي), e.g. "عمر بن
  /// الخطاب رضي الله عنه". Empty when unavailable.
  final String narrator;

  /// The isnad/ananah phrase that introduces the hadith text (عنعنة), e.g.
  /// "عَنْ عُمَرَ رَضِيَ اللهُ عَنْهُ قَالَ...". Empty when unavailable.
  final String isnad;

  final bool isFavorite;

  const Hadith({
    required this.number,
    required this.title,
    required this.text,
    this.source,
    String? reference,
    required this.explanation,
    this.shortExplanation = '',
    this.keyLessons = const [],
    this.narratorBio = '',
    this.narrator = '',
    this.isnad = '',
    this.isFavorite = false,
  }) : reference = reference ?? (source ?? 'من الأربعين النووية');

  factory Hadith.fromJson(Map<String, dynamic> json) {
    final rawLessons = json['keyLessons'];
    List<String> lessonsList = [];
    if (rawLessons is List) {
      lessonsList = rawLessons.map((e) => e.toString()).toList();
    }

    return Hadith(
      number: json['number'] as int,
      title: json['title'] as String,
      text: json['text'] as String,
      source: json['source'] as String?,
      reference: (json['reference'] ?? json['source']) as String?,
      explanation: json['explanation'] as String? ?? '',
      shortExplanation: json['shortExplanation'] as String? ?? '',
      keyLessons: lessonsList,
      narratorBio: json['narratorBio'] as String? ?? '',
      narrator: json['narrator'] as String? ?? '',
      isnad: json['isnad'] as String? ?? '',
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'title': title,
      'text': text,
      'source': source,
      'reference': reference,
      'explanation': explanation,
      'shortExplanation': shortExplanation,
      'keyLessons': keyLessons,
      'narratorBio': narratorBio,
      'narrator': narrator,
      'isnad': isnad,
      'isFavorite': isFavorite,
    };
  }
}
