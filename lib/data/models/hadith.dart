class Hadith {
  final int number;
  final String title;
  final String text;
  final String? source;
  final String reference;
  final String explanation;
  final List<String> keyLessons;

  /// Biography of the companion who narrated the hadith, from the source
  /// workbook. Empty when unavailable.
  final String narratorBio;

  final bool isFavorite;

  const Hadith({
    required this.number,
    required this.title,
    required this.text,
    this.source,
    String? reference,
    required this.explanation,
    this.keyLessons = const [],
    this.narratorBio = '',
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
      keyLessons: lessonsList,
      narratorBio: json['narratorBio'] as String? ?? '',
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
      'keyLessons': keyLessons,
      'narratorBio': narratorBio,
      'isFavorite': isFavorite,
    };
  }
}
